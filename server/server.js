const http = require('http');
const fs = require('fs');
const crypto = require('crypto');
const os = require('os');
const { URL } = require('url');
const { WebSocketServer } = require('ws');
const QRCode = require('qrcode');
const { start: startTunnel, getUrl: getTunnelUrl, stop: stopTunnel } = require('./cloudflared');

const PORT = 4090;
const path = require('path');

// ── Persistent identity ────────────────────────────────────────────────────────

const ID_FILE = path.join(os.homedir(), '.claude', 'mobile-server-identity.json');

function loadOrCreateIdentity() {
  try {
    const data = JSON.parse(fs.readFileSync(ID_FILE, 'utf8'));
    if (data.serverId && data.token) return data;
  } catch {}
  const identity = { serverId: crypto.randomUUID(), token: crypto.randomUUID() };
  fs.mkdirSync(path.dirname(ID_FILE), { recursive: true });
  fs.writeFileSync(ID_FILE, JSON.stringify(identity, null, 2));
  return identity;
}

const identity = loadOrCreateIdentity();

// ── State ──────────────────────────────────────────────────────────────────────

const state = {
  token: identity.token,
  tunnelUrl: null,
  sessions: new Map(),          // session_id → {project_dir, transcript_path, registered_at}
  phoneWs: null,                // single connected phone WebSocket
  pendingMessages: new Map(),   // session_id → [messages]
  pendingPermissions: new Map(),// request_id → {resolve, reject, timeout, session_id}
  autoAllowTools: new Set(),    // tool names that are auto-approved
  usage: null,                  // latest usage data from statusLine
};

// ── Helpers ────────────────────────────────────────────────────────────────────

function isLocalhost(req) {
  const addr = req.socket.remoteAddress;
  return addr === '127.0.0.1' || addr === '::1' || addr === '::ffff:127.0.0.1';
}

function checkAuth(req) {
  if (isLocalhost(req)) return true;
  const url = new URL(req.url, `http://${req.headers.host}`);
  const qToken = url.searchParams.get('token');
  if (qToken === state.token) return true;
  const authHeader = req.headers['authorization'];
  if (authHeader && authHeader.startsWith('Bearer ') && authHeader.slice(7) === state.token) return true;
  return false;
}

function jsonResponse(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) });
  res.end(body);
}

function htmlResponse(res, status, html) {
  res.writeHead(status, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(html);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end', () => {
      try { resolve(JSON.parse(Buffer.concat(chunks).toString())); }
      catch (e) { reject(e); }
    });
    req.on('error', reject);
  });
}

function sendToPhone(data) {
  if (state.phoneWs && state.phoneWs.readyState === 1) {
    state.phoneWs.send(JSON.stringify(data));
    return true;
  }
  return false;
}

// ── Transcript Parsing ─────────────────────────────────────────────────────────

function extractLastAssistantMessage(transcriptPath) {
  try {
    const text = fs.readFileSync(transcriptPath, 'utf8').trim();
    if (!text) return null;
    const lines = text.split('\n');
    for (let i = lines.length - 1; i >= 0; i--) {
      try {
        const entry = JSON.parse(lines[i]);
        if (entry.type === 'assistant' && entry.message?.content) {
          const content = entry.message.content;
          if (typeof content === 'string') return content;
          if (Array.isArray(content)) {
            const textParts = content.filter(b => b.type === 'text').map(b => b.text);
            return textParts.length > 0 ? textParts.join('\n') : null;
          }
        }
      } catch {}
    }
  } catch (e) {
    console.error('Failed to read transcript:', e.message);
  }
  return null;
}

// ── HTTP Routes ────────────────────────────────────────────────────────────────

async function handleRequest(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const path = url.pathname;

  // ── Health ──
  if (path === '/health' && req.method === 'GET') {
    return jsonResponse(res, 200, {
      ok: true,
      sessions: state.sessions.size,
      phone: !!(state.phoneWs && state.phoneWs.readyState === 1),
    });
  }

  // ── Pair (QR code page) ──
  if (path === '/pair' && req.method === 'GET') {
    if (!isLocalhost(req)) return jsonResponse(res, 403, { error: 'localhost only' });

    const tunnelUrl = state.tunnelUrl || getTunnelUrl();
    if (!tunnelUrl) {
      return htmlResponse(res, 200, `
        <html><head><meta charset="utf-8"><title>Claude Mobile Pair</title>
        <style>body{font-family:system-ui;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;background:#1a1a2e;color:#e0e0e0}
        .card{text-align:center;padding:2rem;background:#16213e;border-radius:16px;box-shadow:0 8px 32px rgba(0,0,0,.3)}
        </style><meta http-equiv="refresh" content="3"></head>
        <body><div class="card"><h2>Waiting for tunnel...</h2><p>This page will refresh automatically.</p></div></body></html>`);
    }

    const payload = JSON.stringify({ url: tunnelUrl, token: state.token, name: os.hostname(), serverId: identity.serverId });
    const qrDataUrl = await QRCode.toDataURL(payload, { width: 400, margin: 2, color: { dark: '#e0e0e0', light: '#16213e' } });

    return htmlResponse(res, 200, `
      <html><head><meta charset="utf-8"><title>Claude Mobile Pair</title>
      <style>
        body{font-family:system-ui;display:flex;justify-content:center;align-items:center;min-height:100vh;margin:0;background:#1a1a2e;color:#e0e0e0}
        .card{text-align:center;padding:2rem;background:#16213e;border-radius:16px;box-shadow:0 8px 32px rgba(0,0,0,.3);max-width:500px}
        img{border-radius:8px;margin:1rem 0}
        .token{font-family:monospace;font-size:.85rem;color:#888;word-break:break-all;margin-top:1rem;padding:.5rem;background:#0f3460;border-radius:8px}
        h1{color:#e94560;margin:0 0 .5rem}
        .url{color:#0ea5e9;font-size:.85rem;word-break:break-all}
      </style></head>
      <body><div class="card">
        <h1>Claude Mobile</h1>
        <p>Scan this QR code with the Claude Mobile app</p>
        <img src="${qrDataUrl}" alt="QR Code" />
        <div class="url">${tunnelUrl}</div>
        <div class="token">Token: ${state.token}</div>
      </div></body></html>`);
  }

  // ── Sessions list ──
  if (path === '/sessions' && req.method === 'GET') {
    if (!checkAuth(req)) return jsonResponse(res, 401, { error: 'unauthorized' });
    const sessions = [];
    for (const [id, data] of state.sessions) {
      sessions.push({ id, ...data });
    }
    return jsonResponse(res, 200, { sessions });
  }

  // ── Register session ──
  if (path === '/register' && req.method === 'POST') {
    if (!isLocalhost(req)) return jsonResponse(res, 403, { error: 'localhost only' });
    try {
      const body = await readBody(req);
      const { session_id, project_dir } = body;
      if (!session_id) return jsonResponse(res, 400, { error: 'session_id required' });
      state.sessions.set(session_id, {
        project_dir: project_dir || null,
        transcript_path: body.transcript_path || null,
        registered_at: new Date().toISOString(),
      });
      console.log(`Session registered: ${session_id} (${project_dir || 'unknown'})`);
      sendToPhone({ type: 'sessions', sessions: getSessionsList() });
      return jsonResponse(res, 200, { ok: true });
    } catch (e) {
      return jsonResponse(res, 400, { error: e.message });
    }
  }

  // ── Permission request from hook ──
  if (path === '/permission' && req.method === 'POST') {
    if (!isLocalhost(req)) return jsonResponse(res, 403, { error: 'localhost only' });
    try {
      const body = await readBody(req);
      const requestId = crypto.randomUUID();
      const sessionId = body.session_id || 'unknown';
      const toolName = body.tool_name || body.hookEventName || 'unknown';
      const toolInput = body.tool_input || body.input || body;

      // Update session transcript path if provided
      if (body.session_id && body.transcript_path) {
        const session = state.sessions.get(body.session_id);
        if (session) session.transcript_path = body.transcript_path;
      }

      console.log(`Permission request: ${requestId} (${toolName}) for session ${sessionId}`);

      // Check auto-allow
      if (state.autoAllowTools.has(toolName)) {
        console.log(`Auto-allowing ${toolName} (previously approved)`);
        return jsonResponse(res, 200, { hookSpecificOutput: { hookEventName: 'PermissionRequest', decision: { behavior: 'allow' } } });
      }

      // Forward to phone
      const sent = sendToPhone({
        type: 'permission_request',
        request_id: requestId,
        session_id: sessionId,
        tool_name: toolName,
        tool_input: toolInput,
      });

      if (!sent) {
        // No phone connected — allow by default (don't block Claude)
        console.log('No phone connected, auto-allowing permission request');
        return jsonResponse(res, 200, {});
      }

      // Hold the request open until phone responds or timeout
      const result = await new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
          state.pendingPermissions.delete(requestId);
          sendToPhone({ type: 'permission_timeout', request_id: requestId });
          console.log(`Permission timeout: ${requestId}`);
          // On timeout, deny
          resolve({ hookSpecificOutput: { hookEventName: 'PermissionRequest', decision: { behavior: 'deny', message: 'Phone approval timed out' } } });
        }, 300000); // 5 minutes

        state.pendingPermissions.set(requestId, { resolve, reject, timeout, session_id: sessionId, tool_name: toolName });
      });

      return jsonResponse(res, 200, result);
    } catch (e) {
      return jsonResponse(res, 400, { error: e.message });
    }
  }

  // ── Stop hook endpoint (non-blocking) — reads transcript, sends last response to phone ──
  if (path === '/stop' && req.method === 'POST') {
    if (!isLocalhost(req)) return jsonResponse(res, 403, { error: 'localhost only' });
    try {
      const body = await readBody(req);
      const { session_id, transcript_path } = body;

      if (!session_id) return jsonResponse(res, 400, { error: 'session_id required' });

      // the following logic, which reads transcript and send it to the server as part of the Stop hook, is technically a bug
      // we decided to embrace as a feature - it sends the last message, if one was sent after an update to the server -
      // keeping it as it's nice to have
      if (transcript_path) {
        const lastMsg = extractLastAssistantMessage(transcript_path);
        if (lastMsg) {
          sendToPhone({
            type: 'message',
            session_id,
            text: lastMsg,
            from: 'assistant',
          });
        }
      }

      return jsonResponse(res, 200, { ok: true });
    } catch (e) {
      return jsonResponse(res, 400, { error: e.message });
    }
  }

  // ── Poll for phone messages (used by Monitor) ──
  if (path === '/poll' && req.method === 'GET') {
    if (!isLocalhost(req)) return jsonResponse(res, 403, { error: 'localhost only' });
    const allMessages = [];
    for (const [sessionId, pending] of state.pendingMessages) {
      if (pending.length > 0) {
        const messages = pending.splice(0);
        allMessages.push({ session_id: sessionId, messages: messages.map(m => m.text) });
      }
    }
    // Clean up empty queues
    for (const [k, v] of state.pendingMessages) {
      if (v.length === 0) state.pendingMessages.delete(k);
    }
    if (allMessages.length > 0) {
      return jsonResponse(res, 200, { messages: allMessages });
    }
    res.writeHead(204);
    return res.end();
  }

  // ── Drain messages (for inject hook) ──
  if (path === '/drain-messages' && req.method === 'GET') {
    if (!isLocalhost(req)) return jsonResponse(res, 403, { error: 'localhost only' });
    const sessionId = url.searchParams.get('session_id');
    if (!sessionId) return jsonResponse(res, 400, { error: 'session_id required' });

    const pending = state.pendingMessages.get(sessionId);
    if (pending && pending.length > 0) {
      const messages = pending.splice(0);
      state.pendingMessages.delete(sessionId);
      const combinedText = messages.map(m => m.text).join('\n\n');
      return jsonResponse(res, 200, {
        hookSpecificOutput: {
          additionalContext: `[Phone messages]\n${combinedText}`,
        },
      });
    }

    // No messages
    res.writeHead(204);
    return res.end();
  }

  // ── Usage update from statusLine ──
  if (path === '/usage-update' && req.method === 'POST') {
    if (!isLocalhost(req)) return jsonResponse(res, 403, { error: 'localhost only' });
    try {
      const body = await readBody(req);
      state.usage = { ...body, updated_at: Date.now() };
      sendToPhone({ type: 'usage', ...state.usage });
      return jsonResponse(res, 200, { ok: true });
    } catch (e) {
      return jsonResponse(res, 400, { error: e.message });
    }
  }

  // ── Get current usage ──
  if (path === '/usage' && req.method === 'GET') {
    if (!checkAuth(req)) return jsonResponse(res, 401, { error: 'unauthorized' });
    return jsonResponse(res, 200, state.usage || { error: 'no usage data yet' });
  }

  // ── Ack delivered (called when Claude reads the message) ──
  if (path === '/ack-delivered' && req.method === 'POST') {
    if (!isLocalhost(req)) return jsonResponse(res, 403, { error: 'localhost only' });
    try {
      const body = await readBody(req);
      const { msg_id } = body;
      if (msg_id) {
        sendToPhone({ type: 'msg_ack', msg_id, status: 'delivered' });
      }
      return jsonResponse(res, 200, { ok: true });
    } catch (e) {
      return jsonResponse(res, 400, { error: e.message });
    }
  }

  // ── Activity status ──
  if (path === '/activity' && req.method === 'POST') {
    if (!isLocalhost(req)) return jsonResponse(res, 403, { error: 'localhost only' });
    try {
      const body = await readBody(req);
      const { session_id, activity, tool_name } = body;
      if (session_id && activity) {
        // Ignore stale "idle" if "thinking" was sent recently (within 3s)
        const now = Date.now();
        const key = `activity_${session_id}`;
        if (activity === 'idle' && state[key] && (now - state[key]) < 3000) {
          return jsonResponse(res, 200, { ok: true, skipped: true });
        }
        if (activity === 'thinking' || activity === 'coding') {
          state[key] = now;
        }
        sendToPhone({ type: 'activity', session_id, activity, tool_name: tool_name || null });
      }
      return jsonResponse(res, 200, { ok: true });
    } catch (e) {
      return jsonResponse(res, 400, { error: e.message });
    }
  }

  // ── Send message to phone ──
  if (path === '/send' && req.method === 'POST') {
    if (!isLocalhost(req)) return jsonResponse(res, 403, { error: 'localhost only' });
    try {
      const body = await readBody(req);
      const { session_id, text } = body;
      if (!text) return jsonResponse(res, 400, { error: 'text required' });
      const sent = sendToPhone({
        type: 'message',
        session_id: session_id || 'unknown',
        text,
        from: 'assistant',
      });
      return jsonResponse(res, 200, { ok: true, delivered: sent });
    } catch (e) {
      return jsonResponse(res, 400, { error: e.message });
    }
  }

  // ── 404 ──
  jsonResponse(res, 404, { error: 'not found' });
}

// ── Helpers ────────────────────────────────────────────────────────────────────

function getSessionsList() {
  const sessions = [];
  for (const [id, data] of state.sessions) {
    sessions.push({ id, ...data });
  }
  return sessions;
}

function deliverMessageToSession(sessionId, text, msgId) {
  if (!state.pendingMessages.has(sessionId)) {
    state.pendingMessages.set(sessionId, []);
  }
  state.pendingMessages.get(sessionId).push({ text, timestamp: Date.now() });
  // Ack: message received by server (single check)
  sendToPhone({ type: 'msg_ack', msg_id: msgId, status: 'server' });
  const payload = JSON.stringify({session_id: sessionId, text, msg_id: msgId});
  const maxLen = 450;
  if (payload.length <= maxLen) {
    console.log(`PHONE_MSG:${payload}`);
  } else {
    // Split into chunks so Monitor doesn't truncate
    const chunks = [];
    for (let i = 0; i < payload.length; i += maxLen) {
      chunks.push(payload.substring(i, i + maxLen));
    }
    console.log(`PHONE_MSG_START:${chunks.length}`);
    for (const chunk of chunks) {
      console.log(`PHONE_MSG_CHUNK:${chunk}`);
    }
    console.log('PHONE_MSG_END');
  }
}

// ── WebSocket ──────────────────────────────────────────────────────────────────

function handleWebSocket(wss, server) {
  server.on('upgrade', (req, socket, head) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    if (url.pathname !== '/ws') {
      socket.destroy();
      return;
    }

    // Auth check
    const qToken = url.searchParams.get('token');
    if (qToken !== state.token) {
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
      return;
    }

    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit('connection', ws, req);
    });
  });

  wss.on('connection', (ws) => {
    console.log('Phone connected via WebSocket');

    // Replace any existing connection
    if (state.phoneWs && state.phoneWs.readyState === 1) {
      state.phoneWs.close(1000, 'replaced');
    }
    state.phoneWs = ws;

    // Send current sessions list
    ws.send(JSON.stringify({ type: 'sessions', sessions: getSessionsList() }));

    ws.on('message', (data) => {
      try {
        const msg = JSON.parse(data.toString());
        handlePhoneMessage(msg);
      } catch (e) {
        console.error('Bad WS message:', e.message);
      }
    });

    ws.on('close', () => {
      console.log('Phone disconnected');
      if (state.phoneWs === ws) state.phoneWs = null;
    });

    ws.on('error', (e) => {
      console.error('WS error:', e.message);
    });
  });
}

function handlePhoneMessage(msg) {
  switch (msg.type) {
    case 'message': {
      const { session_id, text, msg_id } = msg;
      if (!session_id || !text) return;

      // Handle /usage command directly
      if (text.trim() === '/usage') {
        sendToPhone({ type: 'msg_ack', msg_id, status: 'delivered' });
        if (state.usage) {
          const u = state.usage;
          const fiveReset = u.five_hour_resets ? new Date(u.five_hour_resets * 1000).toLocaleTimeString() : '?';
          const sevenReset = u.seven_day_resets ? new Date(u.seven_day_resets * 1000).toLocaleDateString() : '?';
          const bar = (pct) => {
            const filled = Math.round(pct / 5);
            return '\u2588'.repeat(filled) + '\u2591'.repeat(20 - filled) + ` ${pct}%`;
          };
          sendToPhone({
            type: 'message', session_id, from: 'assistant',
            text: `**Usage**\n\n5-hour:  ${bar(u.five_hour_pct)}\nResets: ${fiveReset}\n\n7-day:   ${bar(u.seven_day_pct)}\nResets: ${sevenReset}\n\nContext: ${u.context_pct || 0}%`,
          });
        } else {
          sendToPhone({ type: 'message', session_id, from: 'assistant', text: 'No usage data yet. Wait for the status line to refresh.' });
        }
        return;
      }

      deliverMessageToSession(session_id, text, msg_id);
      break;
    }

    case 'permission_response': {
      const { request_id, decision } = msg;
      const pending = state.pendingPermissions.get(request_id);
      if (!pending) return;

      clearTimeout(pending.timeout);
      state.pendingPermissions.delete(request_id);

      console.log(`Permission ${request_id}: ${decision}`);

      if (decision === 'allow' || decision === 'allow_always') {
        if (decision === 'allow_always') {
          const toolName = pending.tool_name;
          if (toolName) {
            state.autoAllowTools.add(toolName);
            console.log(`Auto-allow added for: ${toolName}`);
            sendToPhone({ type: 'auto_allow_added', tool_name: toolName });
          }
        }
        pending.resolve({ hookSpecificOutput: { hookEventName: 'PermissionRequest', decision: { behavior: 'allow' } } });
      } else {
        pending.resolve({ hookSpecificOutput: { hookEventName: 'PermissionRequest', decision: { behavior: 'deny', message: 'Denied from phone' } } });
      }
      break;
    }

    case 'list_sessions': {
      sendToPhone({ type: 'sessions', sessions: getSessionsList() });
      break;
    }

    case 'ping': {
      sendToPhone({ type: 'pong' });
      break;
    }
  }
}

// ── Main ───────────────────────────────────────────────────────────────────────

async function main() {
  const server = http.createServer(handleRequest);
  const wss = new WebSocketServer({ noServer: true });

  handleWebSocket(wss, server);

  server.listen(PORT, () => {
    console.log(`Claude Mobile Server listening on http://localhost:${PORT}`);
    console.log(`Token: ${state.token}`);
    console.log(`Pair URL: http://localhost:${PORT}/pair`);
    console.log(`Health: http://localhost:${PORT}/health`);
  });

  // Use custom URL if provided, otherwise start cloudflare quick tunnel
  // Check env, CLI arg, or config file for custom tunnel URL
  let customUrl = process.env.TUNNEL_URL || process.argv.find(a => a.startsWith('--url='))?.split('=')[1];
  if (!customUrl) {
    try {
      const cfg = JSON.parse(fs.readFileSync(path.join(os.homedir(), '.claude', 'mobile-server-config.json'), 'utf8'));
      if (cfg.tunnelUrl) customUrl = cfg.tunnelUrl;
    } catch {}
  }
  if (customUrl) {
    state.tunnelUrl = customUrl;
    console.log(`Using custom URL: ${customUrl}`);
  } else {
    try {
      console.log('Starting Cloudflare tunnel...');
      const tunnelUrl = await startTunnel(PORT);
      state.tunnelUrl = tunnelUrl;
      console.log(`Tunnel URL: ${tunnelUrl}`);
    } catch (e) {
      console.error('Failed to start tunnel:', e.message);
      console.log('Server running in local-only mode. Use /pair on localhost to get QR code once tunnel is ready.');
    }
  }

  // Graceful shutdown
  const shutdown = () => {
    console.log('\nShutting down...');
    stopTunnel();

    for (const [, perm] of state.pendingPermissions) {
      clearTimeout(perm.timeout);
      perm.resolve({});
    }

    wss.close();
    server.close();
    process.exit(0);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((e) => {
  console.error('Fatal:', e);
  process.exit(1);
});

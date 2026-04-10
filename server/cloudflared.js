const { execFile, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const https = require('https');
const os = require('os');

const BIN_DIR = path.join(os.homedir(), '.claude', 'bin');
const DOWNLOAD_BASE = 'https://github.com/cloudflare/cloudflared/releases/latest/download';

let tunnelProcess = null;
let tunnelUrl = null;

function getBinaryInfo() {
  const platform = os.platform();
  const arch = os.arch();

  if (platform === 'win32') {
    return { filename: 'cloudflared.exe', downloadName: 'cloudflared-windows-amd64.exe' };
  } else if (platform === 'darwin') {
    const dlName = arch === 'arm64' ? 'cloudflared-darwin-arm64.tgz' : 'cloudflared-darwin-amd64.tgz';
    return { filename: 'cloudflared', downloadName: dlName, isTar: true };
  } else {
    // Linux
    const dlName = arch === 'arm64' ? 'cloudflared-linux-arm64' : 'cloudflared-linux-amd64';
    return { filename: 'cloudflared', downloadName: dlName };
  }
}

function getBinaryPath() {
  const { filename } = getBinaryInfo();
  return path.join(BIN_DIR, filename);
}

function isInstalled() {
  return fs.existsSync(getBinaryPath());
}

function download(url, dest) {
  return new Promise((resolve, reject) => {
    const follow = (url, redirects = 0) => {
      if (redirects > 5) return reject(new Error('Too many redirects'));
      https.get(url, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          return follow(res.headers.location, redirects + 1);
        }
        if (res.statusCode !== 200) {
          return reject(new Error(`Download failed: HTTP ${res.statusCode}`));
        }
        const file = fs.createWriteStream(dest);
        res.pipe(file);
        file.on('finish', () => file.close(resolve));
        file.on('error', reject);
      }).on('error', reject);
    };
    follow(url);
  });
}

async function install() {
  const info = getBinaryInfo();
  const downloadUrl = `${DOWNLOAD_BASE}/${info.downloadName}`;

  fs.mkdirSync(BIN_DIR, { recursive: true });

  const destPath = getBinaryPath();
  console.log(`Downloading cloudflared from ${downloadUrl}...`);

  if (info.isTar) {
    // macOS: download tar, extract
    const tarPath = path.join(BIN_DIR, info.downloadName);
    await download(downloadUrl, tarPath);
    await new Promise((resolve, reject) => {
      execFile('tar', ['-xzf', tarPath, '-C', BIN_DIR], (err) => {
        if (err) reject(err); else resolve();
      });
    });
    fs.unlinkSync(tarPath);
  } else {
    await download(downloadUrl, destPath);
  }

  // Make executable on non-Windows
  if (os.platform() !== 'win32') {
    fs.chmodSync(destPath, 0o755);
  }

  console.log(`cloudflared installed to ${destPath}`);
}

function start(port) {
  return new Promise(async (resolve, reject) => {
    if (!isInstalled()) {
      try {
        await install();
      } catch (e) {
        return reject(new Error(`Failed to install cloudflared: ${e.message}`));
      }
    }

    const binPath = getBinaryPath();
    const args = ['tunnel', '--url', `http://localhost:${port}`, '--no-autoupdate'];

    console.log(`Spawning: ${binPath} ${args.join(' ')}`);
    tunnelProcess = spawn(binPath, args, { stdio: ['ignore', 'pipe', 'pipe'] });

    let resolved = false;
    const timeout = setTimeout(() => {
      if (!resolved) {
        resolved = true;
        reject(new Error('Tunnel startup timed out (30s)'));
      }
    }, 30000);

    const handleOutput = (data) => {
      const line = data.toString();
      // cloudflared prints the URL to stderr
      const match = line.match(/(https:\/\/[a-z0-9-]+\.trycloudflare\.com)/);
      if (match && !resolved) {
        resolved = true;
        clearTimeout(timeout);
        tunnelUrl = match[1];
        resolve(tunnelUrl);
      }
    };

    tunnelProcess.stdout.on('data', handleOutput);
    tunnelProcess.stderr.on('data', handleOutput);

    tunnelProcess.on('error', (err) => {
      if (!resolved) {
        resolved = true;
        clearTimeout(timeout);
        reject(err);
      }
    });

    tunnelProcess.on('exit', (code) => {
      console.log(`cloudflared exited with code ${code}`);
      tunnelProcess = null;
      if (!resolved) {
        resolved = true;
        clearTimeout(timeout);
        reject(new Error(`cloudflared exited with code ${code}`));
      }
    });
  });
}

function getUrl() {
  return tunnelUrl;
}

function stop() {
  if (tunnelProcess) {
    tunnelProcess.kill();
    tunnelProcess = null;
  }
  tunnelUrl = null;
}

module.exports = { start, getUrl, stop, getBinaryPath, isInstalled };

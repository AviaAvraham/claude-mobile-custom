import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/server_config.dart';
import '../providers/server_provider.dart';
import '../providers/permission_provider.dart';
import '../providers/chat_provider.dart';
import '../services/websocket_service.dart' show WsConnectionState;
import '../widgets/context_menu.dart';
import 'chat_screen.dart';

class SessionsScreen extends StatelessWidget {
  final ServerConfig server;

  const SessionsScreen({super.key, required this.server});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(server.displayName),
        actions: [
          Consumer<PermissionProvider>(
            builder: (_, permProvider, __) {
              final count = permProvider.pendingRequests.length;
              return Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: IconButton(
                  icon: const Icon(Icons.security),
                  onPressed: count > 0 ? () => _showPermissions(context) : null,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ServerProvider>().refreshSessions(server);
            },
          ),
        ],
      ),
      body: Consumer3<ServerProvider, PermissionProvider, ChatProvider>(
        builder: (context, provider, permProvider, chatProvider, _) {
          final connState = provider.getConnectionState(server);
          final sessions = provider.getSessionsForServer(server);

          if (connState == WsConnectionState.connecting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (connState != WsConnectionState.connected) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  const Text('Disconnected'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => provider.connectTo(server),
                    child: const Text('Reconnect'),
                  ),
                ],
              ),
            );
          }

          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.terminal, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'No active sessions',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a Claude Code session on your laptop\nand run /mobile connect',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final permCount = permProvider
                  .getRequestsForSession(session.id)
                  .length;
              final unread = chatProvider.getUnread(session.id);

              Offset longPressPosition = Offset.zero;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onLongPressStart: (d) => longPressPosition = d.globalPosition,
                  child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: session.isWaiting
                        ? Colors.green.shade700
                        : theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      session.isWaiting ? Icons.pause_circle : Icons.terminal,
                      color: session.isWaiting
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(session.displayName),
                  subtitle: () {
                    final lastMsg = chatProvider.getLastMessage(session.id);
                    return Text(
                      lastMsg != null
                          ? '${lastMsg.isFromUser ? 'You: ' : ''}${lastMsg.text}'
                          : session.projectDir ?? session.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  }(),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (permCount > 0)
                        Badge(
                          label: Text('$permCount'),
                          child: const Icon(Icons.security),
                        ),
                      if (unread > 0) ...[
                        if (permCount > 0) const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: theme.colorScheme.primary,
                          child: Text('$unread', style: const TextStyle(fontSize: 11, color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(session: session),
                      ),
                    ).then((_) {
                      chatProvider.setActiveSession(null);
                    });
                  },
                  onLongPress: () => _showSessionMenu(context, longPressPosition, provider, session),
                ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showSessionMenu(BuildContext context, Offset position, ServerProvider provider, session) {
    showContextMenu(
      context: context,
      globalPosition: position,
      items: [
        MenuItem(
          icon: Icons.edit,
          label: 'Rename',
          onTap: () => _showRenameSessionDialog(context, provider, session),
        ),
        MenuItem(
          icon: Icons.link_off,
          label: 'Disconnect',
          color: Colors.red,
          onTap: () => _showDisconnectDialog(context, provider, session),
        ),
      ],
    );
  }

  void _showRenameSessionDialog(BuildContext context, ServerProvider provider, session) {
    final controller = TextEditingController(text: session.customName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename session'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Custom name',
            helperText: 'Leave empty to reset to folder name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.renameSession(server, session, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDisconnectDialog(BuildContext context, ServerProvider provider, session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect session?'),
        content: Text('Remove "${session.displayName}" from the server\'s connected sessions? The terminal will no longer appear here until it re-registers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.disconnectSession(server, session);
              Navigator.pop(ctx);
            },
            child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPermissions(BuildContext context) {
    final provider = context.read<PermissionProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Consumer<PermissionProvider>(
          builder: (_, permProvider, __) {
            final requests = permProvider.pendingRequests;
            if (requests.isEmpty) {
              return const Center(child: Text('No pending permissions'));
            }
            return ListView.builder(
              controller: controller,
              itemCount: requests.length,
              itemBuilder: (_, i) {
                final req = requests[i];
                return ListTile(
                  title: Text(req.toolName),
                  subtitle: Text('Session: ${req.sessionId.substring(0, 8)}...'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: Theme.of(context).colorScheme.error),
                        onPressed: () => provider.deny(req.requestId),
                      ),
                      IconButton(
                        icon: Icon(Icons.check, color: Colors.green.shade700),
                        onPressed: () => provider.approve(req.requestId),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

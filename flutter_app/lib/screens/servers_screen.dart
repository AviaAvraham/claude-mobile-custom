import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';
import '../services/websocket_service.dart' show WsConnectionState;
import '../widgets/context_menu.dart';
import 'pair_screen.dart';
import 'sessions_screen.dart';

class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Claude Mobile'),
        centerTitle: true,
      ),
      body: Consumer<ServerProvider>(
        builder: (context, provider, _) {
          if (provider.savedServers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.computer, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'No servers connected',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan a QR code from your laptop\nto get started',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _navigateToPair(context),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR Code'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.savedServers.length,
            itemBuilder: (context, index) {
              final server = provider.savedServers[index];
              final connState = provider.getConnectionState(server);
              final isConnected = connState == WsConnectionState.connected;
              final isConnecting = connState == WsConnectionState.connecting;
              final sessionCount = provider.getSessionsForServer(server).length;

              Offset longPressPosition = Offset.zero;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onLongPressStart: (d) => longPressPosition = d.globalPosition,
                  child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isConnected
                        ? Colors.green.shade700
                        : theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.computer,
                      color: isConnected
                          ? Colors.white
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(server.displayName),
                  subtitle: Text(
                    isConnected
                        ? 'Connected - $sessionCount session(s)'
                        : isConnecting
                            ? 'Connecting...'
                            : 'Disconnected',
                    style: TextStyle(
                      color: isConnected
                          ? Colors.green.shade700
                          : isConnecting
                              ? theme.colorScheme.onSurfaceVariant
                              : Colors.red,
                    ),
                  ),
                  trailing: isConnected
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => provider.disconnectFrom(server),
                        )
                      : null,
                  onTap: () {
                    if (isConnected) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SessionsScreen(server: server),
                        ),
                      );
                    } else {
                      provider.connectTo(server);
                    }
                  },
                  onLongPress: () => _showServerMenu(context, longPressPosition, provider, server),
                ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToPair(context),
        child: const Icon(Icons.qr_code_scanner),
      ),
    );
  }

  void _navigateToPair(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PairScreen()),
    );
  }

  void _showServerMenu(BuildContext context, Offset position, ServerProvider provider, server) {
    showContextMenu(
      context: context,
      globalPosition: position,
      items: [
        MenuItem(
          icon: Icons.edit,
          label: 'Rename',
          onTap: () => _showRenameDialog(context, provider, server),
        ),
        MenuItem(
          icon: Icons.delete_outline,
          label: 'Forget server',
          color: Colors.red,
          onTap: () => _showDeleteDialog(context, provider, server),
        ),
      ],
    );
  }

  void _showRenameDialog(BuildContext context, ServerProvider provider, server) {
    final controller = TextEditingController(text: server.displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename server'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: server.name,
            helperText: 'Leave empty to reset to hostname',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.renameServer(server, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ServerProvider provider, server) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove server?'),
        content: Text('Remove ${server.displayName} from saved servers?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.removeServer(server);
              Navigator.pop(ctx);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

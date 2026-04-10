import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/server_provider.dart';
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
              final isActive = provider.activeServer == server;
              final isConnected = isActive && provider.isConnected;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
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
                  title: Text(server.name),
                  subtitle: Text(
                    isConnected
                        ? 'Connected - ${provider.sessions.length} session(s)'
                        : isActive
                            ? 'Connecting...'
                            : 'Tap to connect',
                    style: TextStyle(
                      color: isConnected
                          ? Colors.green.shade700
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: isActive
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: provider.disconnect,
                        )
                      : null,
                  onTap: () {
                    if (isConnected) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SessionsScreen(),
                        ),
                      );
                    } else {
                      provider.connectTo(server);
                    }
                  },
                  onLongPress: () => _showDeleteDialog(context, provider, server),
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

  void _showDeleteDialog(BuildContext context, ServerProvider provider, server) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove server?'),
        content: Text('Remove ${server.name} from saved servers?'),
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

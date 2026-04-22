import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/server_config.dart';
import '../models/session.dart';
import '../services/websocket_service.dart';
import '../services/storage_service.dart';

class ServerProvider extends ChangeNotifier with WidgetsBindingObserver {
  final WebSocketService _ws;
  final StorageService _storage;

  List<ServerConfig> _savedServers = [];
  // Per-server state
  final Map<String, WsConnectionState> _connectionStates = {};
  final Map<String, List<Session>> _serverSessions = {}; // serverUrl -> sessions

  ServerProvider(this._ws, this._storage) {
    _savedServers = _storage.getSavedServers();

    _ws.connectionStates.listen((event) {
      _connectionStates[event.serverUrl] = event.state;
      notifyListeners();
    });

    _ws.messages.listen((msg) {
      final serverUrl = msg['_serverUrl'] as String?;
      if (msg['type'] == 'sessions') {
        final sessions = (msg['sessions'] as List)
            .map((s) => Session.fromJson(s as Map<String, dynamic>))
            .toList();
        if (serverUrl != null) {
          _applyCustomSessionNames(serverUrl, sessions);
          _serverSessions[serverUrl] = sessions;
        }
        notifyListeners();
      } else if (msg['type'] == 'session_waiting') {
        final sessionId = msg['session_id'] as String;
        if (serverUrl != null) {
          final sessions = _serverSessions[serverUrl] ?? [];
          final session = sessions.firstWhere(
            (s) => s.id == sessionId,
            orElse: () {
              final s = Session(id: sessionId, isWaiting: true);
              sessions.add(s);
              return s;
            },
          );
          session.isWaiting = true;
          _serverSessions[serverUrl] = sessions;
        }
        notifyListeners();
      }
    });

    // Auto-connect to all saved servers
    for (final server in _savedServers) {
      _ws.connect(server.wsUrl);
    }

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconnect any disconnected servers when app comes to foreground
      for (final server in _savedServers) {
        if (getConnectionState(server) == WsConnectionState.disconnected) {
          _ws.connect(server.wsUrl);
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<ServerConfig> get savedServers => _savedServers;

  WsConnectionState getConnectionState(ServerConfig config) {
    return _connectionStates[config.wsUrl] ?? WsConnectionState.disconnected;
  }

  bool isServerConnected(ServerConfig config) {
    return getConnectionState(config) == WsConnectionState.connected;
  }

  // For backwards compat — checks if any server is connected
  bool get isConnected => _connectionStates.values.any((s) => s == WsConnectionState.connected);

  List<Session> getSessionsForServer(ServerConfig config) {
    return _serverSessions[config.wsUrl] ?? [];
  }

  // All sessions across all servers
  List<Session> get allSessions {
    return _serverSessions.values.expand((s) => s).toList();
  }

  String? getServerUrlForSession(String sessionId) {
    for (final entry in _serverSessions.entries) {
      if (entry.value.any((s) => s.id == sessionId)) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> addServer(ServerConfig config) async {
    await _storage.saveServer(config);
    _savedServers = _storage.getSavedServers();
    _ws.connect(config.wsUrl);
    notifyListeners();
  }

  Future<void> removeServer(ServerConfig config) async {
    _ws.disconnect(config.wsUrl);
    await _storage.removeServer(config);
    _savedServers = _storage.getSavedServers();
    _serverSessions.remove(config.wsUrl);
    _connectionStates.remove(config.wsUrl);
    notifyListeners();
  }

  void connectTo(ServerConfig config) {
    if (getConnectionState(config) != WsConnectionState.disconnected) return;
    _ws.connect(config.wsUrl);
    notifyListeners();
  }

  void disconnectFrom(ServerConfig config) {
    _ws.disconnect(config.wsUrl);
    _serverSessions.remove(config.wsUrl);
    notifyListeners();
  }

  void refreshSessions(ServerConfig config) {
    _ws.sendTo(config.wsUrl, {'type': 'list_sessions'});
  }

  Future<void> renameServer(ServerConfig config, String? newName) async {
    final updated = config.copyWith(customName: newName?.trim().isEmpty == true ? null : newName?.trim());
    await _storage.saveServer(updated);
    _savedServers = _storage.getSavedServers();
    notifyListeners();
  }

  ServerConfig? _serverByUrl(String wsUrl) {
    for (final s in _savedServers) {
      if (s.wsUrl == wsUrl) return s;
    }
    return null;
  }

  void _applyCustomSessionNames(String wsUrl, List<Session> sessions) {
    final server = _serverByUrl(wsUrl);
    if (server == null) return;
    final names = _storage.getSessionNames(server.serverId);
    for (final s in sessions) {
      final n = names[s.id];
      if (n != null) s.customName = n;
    }
  }

  Future<void> renameSession(ServerConfig server, Session session, String? newName) async {
    final trimmed = newName?.trim();
    await _storage.setSessionName(
      server.serverId,
      session.id,
      (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );
    session.customName = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    notifyListeners();
  }

  void disconnectSession(ServerConfig server, Session session) {
    _ws.sendTo(server.wsUrl, {
      'type': 'disconnect_session',
      'session_id': session.id,
    });
  }
}

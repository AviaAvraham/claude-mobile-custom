import 'package:flutter/foundation.dart';
import '../models/server_config.dart';
import '../models/session.dart';
import '../services/websocket_service.dart';
import '../services/storage_service.dart';

class ServerProvider extends ChangeNotifier {
  final WebSocketService _ws;
  final StorageService _storage;

  List<ServerConfig> _savedServers = [];
  ServerConfig? _activeServer;
  WsConnectionState _connectionState = WsConnectionState.disconnected;
  List<Session> _sessions = [];

  ServerProvider(this._ws, this._storage) {
    _savedServers = _storage.getSavedServers();

    _ws.connectionState.listen((state) {
      _connectionState = state;
      notifyListeners();
    });

    _ws.messages.listen((msg) {
      if (msg['type'] == 'sessions') {
        _sessions = (msg['sessions'] as List)
            .map((s) => Session.fromJson(s as Map<String, dynamic>))
            .toList();
        notifyListeners();
      } else if (msg['type'] == 'session_waiting') {
        final sessionId = msg['session_id'] as String;
        final session = _sessions.firstWhere(
          (s) => s.id == sessionId,
          orElse: () => Session(id: sessionId, isWaiting: true),
        );
        session.isWaiting = true;
        if (!_sessions.any((s) => s.id == sessionId)) {
          _sessions.add(session);
        }
        notifyListeners();
      }
    });
  }

  List<ServerConfig> get savedServers => _savedServers;
  ServerConfig? get activeServer => _activeServer;
  WsConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == WsConnectionState.connected;
  List<Session> get sessions => _sessions;

  Future<void> addServer(ServerConfig config) async {
    await _storage.saveServer(config);
    _savedServers = _storage.getSavedServers();
    notifyListeners();
  }

  Future<void> removeServer(ServerConfig config) async {
    if (_activeServer == config) disconnect();
    await _storage.removeServer(config);
    _savedServers = _storage.getSavedServers();
    notifyListeners();
  }

  void connectTo(ServerConfig config) {
    _activeServer = config;
    _storage.setLastServer(config);
    _ws.connect(config.wsUrl);
    notifyListeners();
  }

  void disconnect() {
    _ws.disconnect();
    _activeServer = null;
    _sessions = [];
    notifyListeners();
  }

  void refreshSessions() {
    _ws.send({'type': 'list_sessions'});
  }
}

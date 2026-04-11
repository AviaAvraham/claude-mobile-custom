import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WsConnectionState { disconnected, connecting, connected }

class _Connection {
  WebSocketChannel? channel;
  WsConnectionState state = WsConnectionState.disconnected;
  Timer? reconnectTimer;
  Timer? pingTimer;
  int reconnectAttempts = 0;
  bool disposed = false;
  final String url;

  _Connection(this.url);
}

/// Manages multiple WebSocket connections keyed by server URL.
class WebSocketService {
  final Map<String, _Connection> _connections = {};

  // Merged stream of all messages, tagged with serverUrl
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<({String serverUrl, WsConnectionState state})>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<({String serverUrl, WsConnectionState state})> get connectionStates => _stateController.stream;

  WsConnectionState getState(String serverUrl) {
    return _connections[serverUrl]?.state ?? WsConnectionState.disconnected;
  }

  void connect(String wsUrl) {
    if (_connections.containsKey(wsUrl)) {
      disconnect(wsUrl);
    }
    final conn = _Connection(wsUrl);
    _connections[wsUrl] = conn;
    _doConnect(conn);
  }

  Future<void> _doConnect(_Connection conn) async {
    if (conn.disposed) return;
    _setState(conn, WsConnectionState.connecting);

    try {
      conn.channel = WebSocketChannel.connect(Uri.parse(conn.url));
      await conn.channel!.ready;

      conn.channel!.stream.listen(
        (data) {
          conn.reconnectAttempts = 0;
          try {
            final msg = json.decode(data as String) as Map<String, dynamic>;
            msg['_serverUrl'] = conn.url;
            _messageController.add(msg);
          } catch (_) {}
        },
        onDone: () {
          _setState(conn, WsConnectionState.disconnected);
          _scheduleReconnect(conn);
        },
        onError: (error) {
          _setState(conn, WsConnectionState.disconnected);
          _scheduleReconnect(conn);
        },
      );

      _setState(conn, WsConnectionState.connected);
      _startPing(conn);
    } catch (e) {
      _setState(conn, WsConnectionState.disconnected);
      _scheduleReconnect(conn);
    }
  }

  void _setState(_Connection conn, WsConnectionState newState) {
    if (conn.disposed) return;
    conn.state = newState;
    _stateController.add((serverUrl: conn.url, state: newState));
  }

  void _scheduleReconnect(_Connection conn) {
    if (conn.disposed) return;
    _stopPing(conn);
    conn.reconnectTimer?.cancel();
    final delay = Duration(
      seconds: conn.reconnectAttempts < 5
          ? (1 << conn.reconnectAttempts)
          : 16,
    );
    conn.reconnectAttempts++;
    conn.reconnectTimer = Timer(delay, () => _doConnect(conn));
  }

  void _startPing(_Connection conn) {
    conn.pingTimer?.cancel();
    conn.pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      sendTo(conn.url, {'type': 'ping'});
    });
  }

  void _stopPing(_Connection conn) {
    conn.pingTimer?.cancel();
    conn.pingTimer = null;
  }

  void sendTo(String serverUrl, Map<String, dynamic> data) {
    final conn = _connections[serverUrl];
    if (conn != null && conn.channel != null && conn.state == WsConnectionState.connected) {
      conn.channel!.sink.add(json.encode(data));
    }
  }

  /// Send to all connected servers
  void sendAll(Map<String, dynamic> data) {
    for (final conn in _connections.values) {
      if (conn.channel != null && conn.state == WsConnectionState.connected) {
        conn.channel!.sink.add(json.encode(data));
      }
    }
  }

  void disconnect(String serverUrl) {
    final conn = _connections.remove(serverUrl);
    if (conn == null) return;
    conn.disposed = true;
    conn.reconnectTimer?.cancel();
    _stopPing(conn);
    conn.channel?.sink.close();
    _stateController.add((serverUrl: serverUrl, state: WsConnectionState.disconnected));
  }

  void disconnectAll() {
    for (final url in _connections.keys.toList()) {
      disconnect(url);
    }
  }

  void dispose() {
    disconnectAll();
    _messageController.close();
    _stateController.close();
  }
}

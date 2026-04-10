import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WsConnectionState { disconnected, connecting, connected }

class WebSocketService {
  WebSocketChannel? _channel;
  WsConnectionState _state = WsConnectionState.disconnected;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  String? _url;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<WsConnectionState>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<WsConnectionState> get connectionState => _stateController.stream;
  WsConnectionState get currentState => _state;

  void connect(String wsUrl) {
    _url = wsUrl;
    _reconnectAttempts = 0;
    _doConnect();
  }

  void _doConnect() {
    if (_url == null) return;
    _setState(WsConnectionState.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url!));

      _channel!.stream.listen(
        (data) {
          _reconnectAttempts = 0;
          try {
            final msg = json.decode(data as String) as Map<String, dynamic>;
            _messageController.add(msg);
          } catch (_) {}
        },
        onDone: () {
          _setState(WsConnectionState.disconnected);
          _scheduleReconnect();
        },
        onError: (error) {
          _setState(WsConnectionState.disconnected);
          _scheduleReconnect();
        },
      );

      _setState(WsConnectionState.connected);
      _startPing();
    } catch (e) {
      _setState(WsConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  void _setState(WsConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void _scheduleReconnect() {
    _stopPing();
    _reconnectTimer?.cancel();
    final delay = Duration(
      seconds: _reconnectAttempts < 5
          ? (1 << _reconnectAttempts) // 1, 2, 4, 8, 16
          : 30,
    );
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, _doConnect);
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      send({'type': 'ping'});
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void send(Map<String, dynamic> data) {
    if (_channel != null && _state == WsConnectionState.connected) {
      _channel!.sink.add(json.encode(data));
    }
  }

  void disconnect() {
    _url = null;
    _reconnectTimer?.cancel();
    _stopPing();
    _channel?.sink.close();
    _channel = null;
    _setState(WsConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _stateController.close();
  }
}

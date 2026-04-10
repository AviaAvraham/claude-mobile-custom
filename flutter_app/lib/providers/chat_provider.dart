import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/websocket_service.dart';

class ChatProvider extends ChangeNotifier {
  final WebSocketService _ws;
  int _msgCounter = 0;

  // session_id -> messages
  final Map<String, List<ChatMessage>> _messages = {};

  // Activity status per session
  final Map<String, String> _activityStatus = {}; // session_id -> 'thinking'|'coding'|'idle'

  // Draft text per session
  final Map<String, String> _drafts = {};

  // Unread count per session
  final Map<String, int> _unread = {};

  // Currently viewed session (set by chat screen)
  String? _activeSessionId;

  ChatProvider(this._ws) {
    _ws.messages.listen((msg) {
      final type = msg['type'] as String?;

      if (type == 'message' && msg['from'] == 'assistant') {
        final sessionId = msg['session_id'] as String;
        final text = msg['text'] as String? ?? '';
        if (text.isEmpty) return;

        _getOrCreateMessages(sessionId).add(ChatMessage(
          text: text,
          from: 'assistant',
          timestamp: DateTime.now(),
          deliveryStatus: DeliveryStatus.delivered,
        ));
        if (_activeSessionId != sessionId) {
          _unread[sessionId] = (_unread[sessionId] ?? 0) + 1;
        }
        notifyListeners();
      } else if (type == 'msg_ack') {
        final msgId = msg['msg_id'] as String?;
        final status = msg['status'] as String?;
        if (msgId == null) return;

        for (final messages in _messages.values) {
          for (final m in messages) {
            if (m.msgId == msgId) {
              m.deliveryStatus = status == 'delivered'
                  ? DeliveryStatus.delivered
                  : DeliveryStatus.server;
              notifyListeners();
              return;
            }
          }
        }
      } else if (type == 'activity') {
        final sessionId = msg['session_id'] as String?;
        final activity = msg['activity'] as String?;
        if (sessionId != null && activity != null) {
          _activityStatus[sessionId] = activity;
          notifyListeners();
        }
      }
    });
  }

  List<ChatMessage> getMessages(String sessionId) {
    return _getOrCreateMessages(sessionId);
  }

  String getActivity(String sessionId) {
    return _activityStatus[sessionId] ?? 'idle';
  }

  String getDraft(String sessionId) => _drafts[sessionId] ?? '';
  void setDraft(String sessionId, String text) => _drafts[sessionId] = text;

  int getUnread(String sessionId) => _unread[sessionId] ?? 0;
  int get totalUnread => _unread.values.fold(0, (a, b) => a + b);

  void setActiveSession(String? sessionId) {
    _activeSessionId = sessionId;
    if (sessionId != null) {
      _unread.remove(sessionId);
      notifyListeners();
    }
  }

  List<ChatMessage> _getOrCreateMessages(String sessionId) {
    return _messages.putIfAbsent(sessionId, () => []);
  }

  void sendMessage(String sessionId, String text) {
    if (text.trim().isEmpty) return;

    final msgId = 'msg_${++_msgCounter}_${DateTime.now().millisecondsSinceEpoch}';

    _getOrCreateMessages(sessionId).add(ChatMessage(
      text: text,
      from: 'user',
      timestamp: DateTime.now(),
      msgId: msgId,
      deliveryStatus: DeliveryStatus.sending,
    ));

    _ws.send({
      'type': 'message',
      'session_id': sessionId,
      'text': text,
      'msg_id': msgId,
    });

    notifyListeners();
  }
}

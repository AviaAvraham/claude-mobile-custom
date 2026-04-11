import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/websocket_service.dart';
import '../services/storage_service.dart';

class ChatProvider extends ChangeNotifier {
  final WebSocketService _ws;
  final StorageService _storage;
  int _msgCounter = 0;

  // session_id -> messages
  final Map<String, List<ChatMessage>> _messages = {};

  // session_id -> serverUrl (learned from incoming messages)
  final Map<String, String> _sessionServer = {};

  // Activity status per session
  final Map<String, String> _activityStatus = {};

  // Draft text per session
  final Map<String, String> _drafts = {};

  // Unread count per session
  final Map<String, int> _unread = {};

  // Currently viewed session
  String? _activeSessionId;

  ChatProvider(this._ws, this._storage) {
    // Retry unsent messages on any server reconnect
    _ws.connectionStates.listen((event) {
      if (event.state == WsConnectionState.connected) {
        _retryUnsentForServer(event.serverUrl);
      }
    });

    _ws.messages.listen((msg) {
      final type = msg['type'] as String?;
      final serverUrl = msg['_serverUrl'] as String?;

      if (type == 'message' && msg['from'] == 'assistant') {
        final sessionId = msg['session_id'] as String;
        final text = msg['text'] as String? ?? '';
        if (text.isEmpty) return;

        if (serverUrl != null) _sessionServer[sessionId] = serverUrl;

        _getOrCreateMessages(sessionId).add(ChatMessage(
          text: text,
          from: 'assistant',
          timestamp: DateTime.now(),
          deliveryStatus: DeliveryStatus.delivered,
        ));
        if (_activeSessionId != sessionId) {
          _unread[sessionId] = (_unread[sessionId] ?? 0) + 1;
        }
        _persist(sessionId);
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
          if (serverUrl != null) _sessionServer[sessionId] = serverUrl;
          _activityStatus[sessionId] = activity;
          notifyListeners();
        }
      } else if (type == 'sessions' && serverUrl != null) {
        // Learn session -> server mappings
        final sessions = msg['sessions'] as List?;
        if (sessions != null) {
          for (final s in sessions) {
            if (s is Map<String, dynamic>) {
              final id = s['id'] as String?;
              if (id != null) _sessionServer[id] = serverUrl;
            }
          }
        }
      }
    });
  }

  List<ChatMessage> getMessages(String sessionId) {
    return _getOrCreateMessages(sessionId);
  }

  ChatMessage? getLastMessage(String sessionId) {
    // Use in-memory if already loaded
    final msgs = _messages[sessionId];
    if (msgs != null && msgs.isNotEmpty) return msgs.last;
    // Peek from storage without loading into memory
    final stored = _storage.getMessages(sessionId);
    return stored.isNotEmpty ? stored.last : null;
  }

  String getActivity(String sessionId) {
    return _activityStatus[sessionId] ?? 'idle';
  }

  String getDraft(String sessionId) => _drafts[sessionId] ?? '';
  void setDraft(String sessionId, String text) => _drafts[sessionId] = text;

  int getUnread(String sessionId) => _unread[sessionId] ?? 0;
  int get totalUnread => _unread.values.fold(0, (a, b) => a + b);

  void setActiveSession(String? sessionId) {
    if (sessionId != null) {
      _unread.remove(sessionId);
    }
    _activeSessionId = sessionId;
    notifyListeners();
  }

  List<ChatMessage> _getOrCreateMessages(String sessionId) {
    return _messages.putIfAbsent(sessionId, () => _storage.getMessages(sessionId));
  }

  void clearMessages(String sessionId) {
    _messages[sessionId]?.clear();
    _persist(sessionId);
    notifyListeners();
  }

  void _persist(String sessionId) {
    final messages = _messages[sessionId];
    if (messages != null) {
      _storage.saveMessages(sessionId, messages);
    }
  }

  void _retryUnsentForServer(String serverUrl) {
    for (final entry in _messages.entries) {
      final sessionServerUrl = _sessionServer[entry.key];
      if (sessionServerUrl == serverUrl) {
        retryUnsent(entry.key);
      }
    }
  }

  void retryUnsent(String sessionId) {
    final messages = _messages[sessionId];
    if (messages == null) return;
    final serverUrl = _sessionServer[sessionId];
    if (serverUrl == null) return;
    for (final msg in messages) {
      if (msg.isFromUser && msg.deliveryStatus == DeliveryStatus.sending && msg.msgId != null) {
        _ws.sendTo(serverUrl, {
          'type': 'message',
          'session_id': sessionId,
          'text': msg.text,
          'msg_id': msg.msgId,
        });
      }
    }
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

    final serverUrl = _sessionServer[sessionId];
    if (serverUrl != null) {
      _ws.sendTo(serverUrl, {
        'type': 'message',
        'session_id': sessionId,
        'text': text,
        'msg_id': msgId,
      });
    }

    _persist(sessionId);
    notifyListeners();
  }
}

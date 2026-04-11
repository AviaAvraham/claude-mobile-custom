import 'package:flutter/foundation.dart';
import '../models/permission_request.dart';
import '../services/websocket_service.dart';
import '../services/notification_service.dart';

class PermissionProvider extends ChangeNotifier {
  final WebSocketService _ws;
  final NotificationService _notifications;

  final List<PermissionRequest> _requests = [];
  final Map<String, String> _requestServer = {}; // requestId -> serverUrl

  PermissionProvider(this._ws, this._notifications) {
    _ws.messages.listen((msg) {
      final serverUrl = msg['_serverUrl'] as String?;
      if (msg['type'] == 'permission_request') {
        final request = PermissionRequest.fromJson(msg);
        _requests.add(request);
        if (serverUrl != null) _requestServer[request.requestId] = serverUrl;
        _notifications.showPermissionRequest(
          toolName: request.toolName,
          sessionId: request.sessionId,
        );
        notifyListeners();
      } else if (msg['type'] == 'permission_timeout') {
        final requestId = msg['request_id'] as String;
        _requests.removeWhere((r) => r.requestId == requestId);
        _requestServer.remove(requestId);
        notifyListeners();
      }
    });
  }

  List<PermissionRequest> get pendingRequests =>
      _requests.where((r) => !r.resolved).toList();

  List<PermissionRequest> getRequestsForSession(String sessionId) =>
      _requests.where((r) => r.sessionId == sessionId && !r.resolved).toList();

  void approve(String requestId) {
    _respond(requestId, 'allow');
  }

  void approveAlways(String requestId) {
    _respond(requestId, 'allow_always');
  }

  void deny(String requestId) {
    _respond(requestId, 'deny');
  }

  void _respond(String requestId, String decision) {
    final request = _requests.firstWhere(
      (r) => r.requestId == requestId,
      orElse: () => throw StateError('Request not found'),
    );

    request.resolved = true;

    final serverUrl = _requestServer[requestId];
    final data = {
      'type': 'permission_response',
      'request_id': requestId,
      'decision': decision,
    };

    if (serverUrl != null) {
      _ws.sendTo(serverUrl, data);
    } else {
      _ws.sendAll(data);
    }

    notifyListeners();
  }
}

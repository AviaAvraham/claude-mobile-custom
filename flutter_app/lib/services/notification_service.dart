import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> showPermissionRequest({
    required String toolName,
    required String sessionId,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'permission_requests',
      'Permission Requests',
      channelDescription: 'Claude Code permission requests requiring approval',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      toolName.hashCode,
      'Permission Request',
      '$toolName needs approval (session: ${sessionId.substring(0, 8)}...)',
      details,
    );
  }
}

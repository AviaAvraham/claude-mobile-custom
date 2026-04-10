import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/websocket_service.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'providers/server_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/permission_provider.dart';
import 'screens/servers_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await StorageService.init();
  final wsService = WebSocketService();
  final notificationService = NotificationService();
  await notificationService.init();

  runApp(ClaudeMobileApp(
    storage: storage,
    wsService: wsService,
    notificationService: notificationService,
  ));
}

class ClaudeMobileApp extends StatelessWidget {
  final StorageService storage;
  final WebSocketService wsService;
  final NotificationService notificationService;

  const ClaudeMobileApp({
    super.key,
    required this.storage,
    required this.wsService,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ServerProvider(wsService, storage),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(wsService),
        ),
        ChangeNotifierProvider(
          create: (_) => PermissionProvider(wsService, notificationService),
        ),
      ],
      child: MaterialApp(
        title: 'Claude Mobile',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFD97706),
            brightness: Brightness.dark,
            surface: const Color(0xFF1C1C1E),
            onSurface: const Color(0xFFE5E5E7),
          ),
          scaffoldBackgroundColor: const Color(0xFF000000),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1C1C1E),
            elevation: 0,
          ),
          useMaterial3: true,
        ),
        home: const ServersScreen(),
      ),
    );
  }
}

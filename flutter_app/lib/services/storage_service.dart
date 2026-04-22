import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_config.dart';
import '../models/chat_message.dart';

class StorageService {
  static const _serversKey = 'saved_servers';
  static const _lastServerKey = 'last_server';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  List<ServerConfig> getSavedServers() {
    final jsonStr = _prefs.getString(_serversKey);
    if (jsonStr == null) return [];
    final list = json.decode(jsonStr) as List;
    return list.map((e) => ServerConfig.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveServer(ServerConfig config) async {
    final servers = getSavedServers();
    // Replace existing with same serverId (same machine), or add new
    final index = servers.indexWhere((s) => s.serverId == config.serverId);
    if (index >= 0) {
      servers[index] = config;
    } else {
      servers.add(config);
    }
    await _prefs.setString(_serversKey, json.encode(servers.map((s) => s.toJson()).toList()));
  }

  Future<void> removeServer(ServerConfig config) async {
    final servers = getSavedServers();
    servers.removeWhere((s) => s.url == config.url);
    await _prefs.setString(_serversKey, json.encode(servers.map((s) => s.toJson()).toList()));
  }

  Future<void> setLastServer(ServerConfig config) async {
    await _prefs.setString(_lastServerKey, json.encode(config.toJson()));
  }

  ServerConfig? getLastServer() {
    final jsonStr = _prefs.getString(_lastServerKey);
    if (jsonStr == null) return null;
    return ServerConfig.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
  }

  // ── Session custom names (per server) ──

  String _sessionNamesKey(String serverId) => 'session_names_$serverId';

  Map<String, String> getSessionNames(String serverId) {
    final jsonStr = _prefs.getString(_sessionNamesKey(serverId));
    if (jsonStr == null) return {};
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as String));
  }

  Future<void> setSessionName(String serverId, String sessionId, String? name) async {
    final names = getSessionNames(serverId);
    if (name == null || name.isEmpty) {
      names.remove(sessionId);
    } else {
      names[sessionId] = name;
    }
    await _prefs.setString(_sessionNamesKey(serverId), json.encode(names));
  }

  // ── Chat message persistence ──

  String _messagesKey(String sessionId) => 'messages_$sessionId';

  List<ChatMessage> getMessages(String sessionId) {
    final jsonStr = _prefs.getString(_messagesKey(sessionId));
    if (jsonStr == null) return [];
    final list = json.decode(jsonStr) as List;
    return list.map((e) {
      final map = e as Map<String, dynamic>;
      return ChatMessage(
        text: map['text'] as String,
        from: map['from'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        msgId: map['msgId'] as String?,
        deliveryStatus: DeliveryStatus.delivered,
      );
    }).toList();
  }

  Future<void> saveMessages(String sessionId, List<ChatMessage> messages) async {
    final list = messages.map((m) => {
      'text': m.text,
      'from': m.from,
      'timestamp': m.timestamp.millisecondsSinceEpoch,
      'msgId': m.msgId,
    }).toList();
    await _prefs.setString(_messagesKey(sessionId), json.encode(list));
  }
}

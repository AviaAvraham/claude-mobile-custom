import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server_config.dart';

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
    // Replace existing with same URL, or add new
    final index = servers.indexWhere((s) => s.url == config.url);
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
}

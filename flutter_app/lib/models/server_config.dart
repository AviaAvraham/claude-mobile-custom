import 'dart:convert';

class ServerConfig {
  final String name;
  final String url;
  final String token;
  final String serverId;

  const ServerConfig({
    required this.name,
    required this.url,
    required this.token,
    required this.serverId,
  });

  factory ServerConfig.fromQrJson(String jsonStr) {
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    return ServerConfig(
      name: map['name'] as String? ?? 'Unknown',
      url: map['url'] as String,
      token: map['token'] as String,
      serverId: map['serverId'] as String? ?? map['name'] as String? ?? 'unknown',
    );
  }

  factory ServerConfig.fromJson(Map<String, dynamic> map) {
    return ServerConfig(
      name: map['name'] as String,
      url: map['url'] as String,
      token: map['token'] as String,
      serverId: map['serverId'] as String? ?? map['name'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'token': token,
        'serverId': serverId,
      };

  String get wsUrl {
    final uri = Uri.parse(url);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$wsScheme://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/ws?token=$token';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerConfig && serverId == other.serverId;

  @override
  int get hashCode => serverId.hashCode;
}

class PermissionRequest {
  final String requestId;
  final String sessionId;
  final String toolName;
  final dynamic toolInput;
  final DateTime receivedAt;
  bool resolved;

  PermissionRequest({
    required this.requestId,
    required this.sessionId,
    required this.toolName,
    required this.toolInput,
    DateTime? receivedAt,
    this.resolved = false,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory PermissionRequest.fromJson(Map<String, dynamic> map) {
    return PermissionRequest(
      requestId: map['request_id'] as String,
      sessionId: map['session_id'] as String,
      toolName: map['tool_name'] as String? ?? 'unknown',
      toolInput: map['tool_input'],
    );
  }
}

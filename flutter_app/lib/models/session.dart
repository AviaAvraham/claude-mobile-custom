class Session {
  final String id;
  final String? projectDir;
  final String? transcriptPath;
  final String? registeredAt;
  bool isWaiting;
  String? customName;

  Session({
    required this.id,
    this.projectDir,
    this.transcriptPath,
    this.registeredAt,
    this.isWaiting = false,
    this.customName,
  });

  factory Session.fromJson(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as String,
      projectDir: map['project_dir'] as String?,
      transcriptPath: map['transcript_path'] as String?,
      registeredAt: map['registered_at'] as String?,
    );
  }

  String get displayName {
    if (customName != null && customName!.isNotEmpty) return customName!;
    if (projectDir != null && projectDir!.isNotEmpty) {
      final parts = projectDir!.replaceAll('\\', '/').split('/');
      final folder = parts.last;
      return folder
          .split(RegExp(r'[-_]'))
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');
    }
    return id.length > 8 ? '${id.substring(0, 8)}...' : id;
  }
}

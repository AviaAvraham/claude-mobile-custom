import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/permission_request.dart';

class PermissionCard extends StatefulWidget {
  final PermissionRequest request;
  final VoidCallback onApprove;
  final VoidCallback onDeny;
  final VoidCallback onAlwaysAllow;

  const PermissionCard({
    super.key,
    required this.request,
    required this.onApprove,
    required this.onDeny,
    required this.onAlwaysAllow,
  });

  @override
  State<PermissionCard> createState() => _PermissionCardState();
}

class _PermissionCardState extends State<PermissionCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  List<_DiffLine> _parseDiffLines() {
    final lines = <_DiffLine>[];
    try {
      final input = widget.request.toolInput;
      if (input is Map) {
        // Check for old_string/new_string (Edit tool)
        final oldStr = input['old_string']?.toString();
        final newStr = input['new_string']?.toString();
        if (oldStr != null && newStr != null) {
          for (final line in oldStr.split('\n')) {
            lines.add(_DiffLine('- $line', _DiffType.removed));
          }
          for (final line in newStr.split('\n')) {
            lines.add(_DiffLine('+ $line', _DiffType.added));
          }
          final file = input['file_path']?.toString();
          if (file != null) {
            lines.insert(0, _DiffLine(file.split('/').last, _DiffType.header));
          }
          return lines;
        }
        // Check for command (Bash tool)
        final cmd = input['command']?.toString();
        if (cmd != null) {
          lines.add(_DiffLine('\$ $cmd', _DiffType.command));
          return lines;
        }
        // Check for content (Write tool)
        final content = input['content']?.toString();
        if (content != null) {
          final file = input['file_path']?.toString();
          if (file != null) {
            lines.add(_DiffLine(file.split('/').last, _DiffType.header));
          }
          for (final line in content.split('\n').take(20)) {
            lines.add(_DiffLine('+ $line', _DiffType.added));
          }
          return lines;
        }
      }
      // Fallback: raw JSON
      const encoder = JsonEncoder.withIndent('  ');
      final raw = input is Map || input is List
          ? encoder.convert(input)
          : input.toString();
      for (final line in raw.split('\n')) {
        lines.add(_DiffLine(line, _DiffType.plain));
      }
    } catch (_) {
      lines.add(_DiffLine(widget.request.toolInput.toString(), _DiffType.plain));
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.amber.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Permission Request',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.amber.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.request.toolName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                if (!_expanded) FocusScope.of(context).unfocus();
                setState(() => _expanded = !_expanded);
              },
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _expanded ? 'Hide details' : 'Show details',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _parseDiffLines().map((dl) {
                    Color bg;
                    Color fg;
                    switch (dl.type) {
                      case _DiffType.added:
                        bg = Colors.green.withValues(alpha: 0.15);
                        fg = Colors.green.shade300;
                      case _DiffType.removed:
                        bg = Colors.red.withValues(alpha: 0.15);
                        fg = Colors.red.shade300;
                      case _DiffType.header:
                        bg = Colors.transparent;
                        fg = Colors.amber.shade400;
                      case _DiffType.command:
                        bg = Colors.transparent;
                        fg = Colors.cyan.shade300;
                      case _DiffType.plain:
                        bg = Colors.transparent;
                        fg = theme.colorScheme.onSurface;
                    }
                    return Container(
                      width: double.infinity,
                      color: bg,
                      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
                      child: Text(
                        dl.text,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: fg,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Allow'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onAlwaysAllow,
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Always'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onDeny,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Deny'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DiffType { added, removed, header, command, plain }

class _DiffLine {
  final String text;
  final _DiffType type;
  const _DiffLine(this.text, this.type);
}

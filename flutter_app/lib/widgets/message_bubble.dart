import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  String _formatTime() {
    final h = message.timestamp.hour.toString().padLeft(2, '0');
    final m = message.timestamp.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildFooter(ThemeData theme) {
    final timeText = Text(
      _formatTime(),
      style: TextStyle(
        fontSize: 11,
        color: message.isFromUser
            ? Colors.white70
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );

    if (message.isFromUser) {
      IconData icon;
      Color color;
      switch (message.deliveryStatus) {
        case DeliveryStatus.sending:
          icon = Icons.schedule;
          color = Colors.white;
        case DeliveryStatus.server:
          icon = Icons.check;
          color = Colors.white;
        case DeliveryStatus.delivered:
          icon = Icons.done_all;
          color = Colors.white;
      }
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            timeText,
            const SizedBox(width: 4),
            Icon(icon, size: 15, color: color),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: timeText,
      );
    }
  }

  String _prepareMarkdown(String text) {
    // Ensure blank lines before list starts and headings so markdown parses them correctly
    final lines = text.split('\n');
    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final prevLine = i > 0 ? lines[i - 1] : '';
      // Add blank line before numbered/bulleted list if previous line isn't empty or a list item
      if (prevLine.isNotEmpty &&
          !RegExp(r'^\s*(\d+\.|[-*])').hasMatch(prevLine) &&
          RegExp(r'^\s*(\d+\.|[-*])\s').hasMatch(line)) {
        buffer.writeln();
      }
      buffer.writeln(line);
    }
    return buffer.toString().trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            message.isFromAssistant
                ? MarkdownBody(
                    data: _prepareMarkdown(message.text),
                    softLineBreak: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                      code: TextStyle(
                        backgroundColor: theme.colorScheme.surface,
                        color: theme.colorScheme.primary,
                        fontSize: 13,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    selectable: true,
                  )
                : Text(
                    message.text,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 15,
                    ),
                  ),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }
}

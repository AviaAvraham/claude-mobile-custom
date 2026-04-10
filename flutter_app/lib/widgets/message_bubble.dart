import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  Widget _buildCheckmarks() {
    if (!message.isFromUser) return const SizedBox.shrink();

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
          Icon(icon, size: 17, color: color),
        ],
      ),
    );
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
                    data: message.text,
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
            _buildCheckmarks(),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../providers/chat_provider.dart';
import '../providers/permission_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/permission_card.dart';

class ChatScreen extends StatefulWidget {
  final Session session;

  const ChatScreen({super.key, required this.session});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final draft = context.read<ChatProvider>().getDraft(widget.session.id);
    if (draft.isNotEmpty) {
      _textController.text = draft;
    }
    _textController.addListener(_saveDraft);
    context.read<ChatProvider>().setActiveSession(widget.session.id);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _saveDraft() {
    context.read<ChatProvider>().setDraft(widget.session.id, _textController.text);
  }

  @override
  void dispose() {
    context.read<ChatProvider>().setActiveSession(null);
    _textController.removeListener(_saveDraft);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    context.read<ChatProvider>().sendMessage(widget.session.id, text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Consumer<ChatProvider>(
          builder: (_, chatProvider, __) {
            final activity = chatProvider.getActivity(widget.session.id);
            String? statusText;
            Color? statusColor;
            if (activity == 'thinking') {
              statusText = 'Thinking...';
              statusColor = Colors.amber.shade400;
            } else if (activity == 'coding') {
              statusText = 'Writing code...';
              statusColor = Colors.cyan.shade400;
            } else if (activity == 'idle') {
              statusText = 'Idle';
              statusColor = Colors.grey;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.session.displayName, style: const TextStyle(fontSize: 16)),
                if (statusText != null)
                  Text(
                    statusText,
                    style: TextStyle(fontSize: 12, color: statusColor),
                  ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          // Permission requests banner
          Consumer<PermissionProvider>(
            builder: (_, permProvider, __) {
              final requests = permProvider.getRequestsForSession(widget.session.id);
              if (requests.isEmpty) return const SizedBox.shrink();
              return Column(
                children: requests.map((req) => PermissionCard(
                  request: req,
                  onApprove: () => permProvider.approve(req.requestId),
                  onDeny: () => permProvider.deny(req.requestId),
                  onAlwaysAllow: () => permProvider.approveAlways(req.requestId),
                )).toList(),
              );
            },
          ),

          // Messages list
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (_, chatProvider, __) {
                final messages = chatProvider.getMessages(widget.session.id);

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Send a message to Claude',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (widget.session.isWaiting) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Session is idle and ready for input',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                // Auto-scroll on new messages
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (_, index) => MessageBubble(message: messages[index]),
                );
              },
            ),
          ),

          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: 8 + MediaQuery.of(context).viewPadding.bottom,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Message Claude...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.newline,
                    maxLines: 6,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

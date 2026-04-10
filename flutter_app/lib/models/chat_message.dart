enum DeliveryStatus { sending, server, delivered }

class ChatMessage {
  final String text;
  final String from; // 'assistant' or 'user'
  final DateTime timestamp;
  final String? msgId;
  DeliveryStatus deliveryStatus;

  ChatMessage({
    required this.text,
    required this.from,
    required this.timestamp,
    this.msgId,
    this.deliveryStatus = DeliveryStatus.sending,
  });

  bool get isFromUser => from == 'user';
  bool get isFromAssistant => from == 'assistant';
}

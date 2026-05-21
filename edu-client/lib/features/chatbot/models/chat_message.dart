enum ChatSender {
  user,
  ai;
}

class ChatMessage {
  final ChatSender sender;
  final String text;
  final DateTime timestamp;
  final String? referencedLaw;

  const ChatMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
    this.referencedLaw,
  });

  factory ChatMessage.user(String text, {String? referencedLaw}) {
    return ChatMessage(
      sender: ChatSender.user,
      text: text,
      timestamp: DateTime.now(),
      referencedLaw: referencedLaw,
    );
  }

  factory ChatMessage.ai(String text, {String? referencedLaw}) {
    return ChatMessage(
      sender: ChatSender.ai,
      text: text,
      timestamp: DateTime.now(),
      referencedLaw: referencedLaw,
    );
  }
}

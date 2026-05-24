class QuizItem {
  final String id;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;
  final String lawReference;

  const QuizItem({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.lawReference,
  });

  factory QuizItem.fromJson(Map<String, dynamic> json) {
    return QuizItem(
      id: json['id'] as String,
      question: json['question'] as String,
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'] as String,
      explanation: json['explanation'] as String,
      lawReference: json['lawReference'] as String,
    );
  }
}

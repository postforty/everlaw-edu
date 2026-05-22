import 'dart:convert';

class IncorrectNote {
  final String id;
  final String quizId;
  final String question;
  final List<String> options;
  final int answerIndex;
  final int selectedIndex;
  final String explanation;
  final String lawReference;
  final String incorrectAt;
  final bool isArchived;
  final bool isSynced;

  IncorrectNote({
    required this.id,
    required this.quizId,
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.selectedIndex,
    required this.explanation,
    required this.lawReference,
    required this.incorrectAt,
    this.isArchived = false,
    this.isSynced = false,
  });

  IncorrectNote copyWith({
    String? id,
    String? quizId,
    String? question,
    List<String>? options,
    int? answerIndex,
    int? selectedIndex,
    String? explanation,
    String? lawReference,
    String? incorrectAt,
    bool? isArchived,
    bool? isSynced,
  }) {
    return IncorrectNote(
      id: id ?? this.id,
      quizId: quizId ?? this.quizId,
      question: question ?? this.question,
      options: options ?? this.options,
      answerIndex: answerIndex ?? this.answerIndex,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      explanation: explanation ?? this.explanation,
      lawReference: lawReference ?? this.lawReference,
      incorrectAt: incorrectAt ?? this.incorrectAt,
      isArchived: isArchived ?? this.isArchived,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quizId': quizId,
      'question': question,
      'options': options,
      'answerIndex': answerIndex,
      'selectedIndex': selectedIndex,
      'explanation': explanation,
      'lawReference': lawReference,
      'incorrectAt': incorrectAt,
      'isArchived': isArchived,
      'isSynced': isSynced,
    };
  }

  factory IncorrectNote.fromMap(Map<String, dynamic> map) {
    return IncorrectNote(
      id: map['id'] ?? '',
      quizId: map['quizId'] ?? '',
      question: map['question'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      answerIndex: map['answerIndex']?.toInt() ?? 0,
      selectedIndex: map['selectedIndex']?.toInt() ?? 0,
      explanation: map['explanation'] ?? '',
      lawReference: map['lawReference'] ?? '',
      incorrectAt: map['incorrectAt'] ?? '',
      isArchived: map['isArchived'] ?? false,
      isSynced: map['isSynced'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory IncorrectNote.fromJson(String source) => IncorrectNote.fromMap(json.decode(source));
}

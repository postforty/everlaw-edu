import 'dart:convert';

enum SyncStatus { synced, pendingDelete, pendingAdd }

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
  final SyncStatus syncStatus;

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
    this.syncStatus = SyncStatus.synced,
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
    SyncStatus? syncStatus,
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
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quizId': quizId,
      'question': question,
      'options': jsonEncode(options), // SQLite requires string for lists
      'answerIndex': answerIndex,
      'selectedIndex': selectedIndex,
      'explanation': explanation,
      'lawReference': lawReference,
      'incorrectAt': incorrectAt,
      'isArchived': isArchived ? 1 : 0, // SQLite doesn't support bool directly
      'syncStatus': syncStatus.name,
    };
  }

  factory IncorrectNote.fromMap(Map<String, dynamic> map) {
    // Handle SQLite options parsing
    List<String> parsedOptions = [];
    if (map['options'] is String) {
      parsedOptions = List<String>.from(jsonDecode(map['options']));
    } else {
      parsedOptions = List<String>.from(map['options'] ?? []);
    }

    return IncorrectNote(
      id: map['id']?.toString() ?? '',
      quizId: map['quizId']?.toString() ?? '',
      question: map['question'] ?? '',
      options: parsedOptions,
      answerIndex: map['answerIndex']?.toInt() ?? 0,
      selectedIndex: map['selectedIndex']?.toInt() ?? 0,
      explanation: map['explanation'] ?? '',
      lawReference: map['lawReference'] ?? '',
      incorrectAt: map['incorrectAt'] ?? '',
      isArchived: map['isArchived'] == 1 || map['isArchived'] == true,
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == map['syncStatus'],
        orElse: () => SyncStatus.synced,
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory IncorrectNote.fromJson(String source) => IncorrectNote.fromMap(json.decode(source));
}

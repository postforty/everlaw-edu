class SourceLaw {
  final String lawId;
  final String lawName;
  final String article;
  final String content;

  const SourceLaw({
    required this.lawId,
    required this.lawName,
    required this.article,
    required this.content,
  });

  factory SourceLaw.fromJson(Map<String, dynamic> json) {
    return SourceLaw(
      lawId: json['lawId'] as String? ?? '',
      lawName: json['lawName'] as String? ?? '',
      article: json['article'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }
}

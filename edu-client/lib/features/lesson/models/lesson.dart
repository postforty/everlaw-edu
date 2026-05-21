class Curriculum {
  final int id;
  final String title;
  final String description;
  final String category;
  final String targetJobCategory;

  const Curriculum({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.targetJobCategory,
  });

  factory Curriculum.fromJson(Map<String, dynamic> json) {
    return Curriculum(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'N/A',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'GENERAL',
      targetJobCategory: json['targetJobCategory'] as String? ?? 'ALL',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'targetJobCategory': targetJobCategory,
    };
  }
}

class Lesson {
  final int id;
  final Curriculum curriculum;
  final String title;
  final String contentMarkdown;
  final String associatedLawReference;
  final DateTime createdAt;
  final bool isRecentlyRevised;
  final int revisionNumber;

  const Lesson({
    required this.id,
    required this.curriculum,
    required this.title,
    required this.contentMarkdown,
    required this.associatedLawReference,
    required this.createdAt,
    this.isRecentlyRevised = false,
    this.revisionNumber = 1,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'] as int,
      curriculum: Curriculum.fromJson(json['curriculum'] as Map<String, dynamic>),
      title: json['title'] as String? ?? 'N/A',
      contentMarkdown: json['contentMarkdown'] as String? ?? '',
      associatedLawReference: json['associatedLawReference'] as String? ?? 'N/A',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : DateTime.now(),
      isRecentlyRevised: json['isRecentlyRevised'] as bool? ?? false,
      revisionNumber: json['revisionNumber'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'curriculum': curriculum.toJson(),
      'title': title,
      'contentMarkdown': contentMarkdown,
      'associatedLawReference': associatedLawReference,
      'createdAt': createdAt.toIso8601String(),
      'isRecentlyRevised': isRecentlyRevised,
      'revisionNumber': revisionNumber,
    };
  }
}

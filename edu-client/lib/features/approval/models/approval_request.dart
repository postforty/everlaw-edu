class ApprovalRequest {
  final int id;
  final String title;
  final String lawReference;
  final String aiGeneratedMarkdown;
  final String validationDetails;
  final double hallucinationScore;
  final String status; // PENDING, APPROVED, REJECTED
  final DateTime createdAt;

  const ApprovalRequest({
    required this.id,
    required this.title,
    required this.lawReference,
    required this.aiGeneratedMarkdown,
    required this.validationDetails,
    required this.hallucinationScore,
    required this.status,
    required this.createdAt,
  });

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'N/A',
      lawReference: json['lawReference'] as String? ?? 'N/A',
      aiGeneratedMarkdown: json['aiGeneratedMarkdown'] as String? ?? '',
      validationDetails: json['validationDetails'] as String? ?? '',
      hallucinationScore: (json['hallucinationScore'] as num? ?? 0.0).toDouble(),
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'lawReference': lawReference,
      'aiGeneratedMarkdown': aiGeneratedMarkdown,
      'validationDetails': validationDetails,
      'hallucinationScore': hallucinationScore,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  ApprovalRequest copyWith({
    int? id,
    String? title,
    String? lawReference,
    String? aiGeneratedMarkdown,
    String? validationDetails,
    double? hallucinationScore,
    String? status,
    DateTime? createdAt,
  }) {
    return ApprovalRequest(
      id: id ?? this.id,
      title: title ?? this.title,
      lawReference: lawReference ?? this.lawReference,
      aiGeneratedMarkdown: aiGeneratedMarkdown ?? this.aiGeneratedMarkdown,
      validationDetails: validationDetails ?? this.validationDetails,
      hallucinationScore: hallucinationScore ?? this.hallucinationScore,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

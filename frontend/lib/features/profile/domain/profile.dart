class ProfileField {
  final String id;
  final String section;
  final String fieldKey;
  final String value;
  final String dataType;
  final String visibility;
  final double confidence;

  ProfileField({
    required this.id,
    required this.section,
    required this.fieldKey,
    required this.value,
    required this.dataType,
    required this.visibility,
    this.confidence = 100.0,
  });

  factory ProfileField.fromJson(Map<String, dynamic> json) {
    return ProfileField(
      id: json['id'] as String? ?? '',
      section: json['section'] as String,
      fieldKey: json['fieldKey'] as String,
      value: json['value'] as String? ?? '',
      dataType: json['dataType'] as String? ?? 'string',
      visibility: json['visibility'] as String? ?? 'PRIVATE',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 100.0,
    );
  }
}

class UserProfile {
  final String id;
  final int completenessScore;
  final int documentCount;
  final Map<String, List<ProfileField>> sections;

  UserProfile({
    required this.id,
    required this.completenessScore,
    required this.documentCount,
    required this.sections,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as Map<String, dynamic>? ?? {};
    final Map<String, List<ProfileField>> sectionsMap = {};
    
    rawSections.forEach((key, val) {
      if (val is List) {
        sectionsMap[key] = val.map((item) => ProfileField.fromJson(item as Map<String, dynamic>)).toList();
      }
    });

    return UserProfile(
      id: json['id'] as String,
      completenessScore: json['completenessScore'] as int? ?? 0,
      documentCount: json['documentCount'] as int? ?? 0,
      sections: sectionsMap,
    );
  }
}

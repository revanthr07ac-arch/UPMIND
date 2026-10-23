class SkillModel {
  final String id;
  final String name;
  final String category;
  final String? description;

  const SkillModel({
    required this.id,
    required this.name,
    required this.category,
    this.description,
  });

  factory SkillModel.fromJson(Map<String, dynamic> json) {
    return SkillModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'General',
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
    };
  }
}

class UserSkillModel {
  final String id;
  final String userId;
  final String skillId;
  final String skillName;
  final String skillCategory;
  final String intent; // 'teaching' | 'learning'
  final String experienceLevel; // 'beginner' | 'intermediate' | 'advanced'
  final String? description;

  const UserSkillModel({
    required this.id,
    required this.userId,
    required this.skillId,
    required this.skillName,
    required this.skillCategory,
    required this.intent,
    required this.experienceLevel,
    this.description,
  });

  bool get isTeaching => intent == 'teaching';
  bool get isLearning => intent == 'learning';

  factory UserSkillModel.fromJson(Map<String, dynamic> json) {
    final skillData = json['skills'] as Map<String, dynamic>?;
    return UserSkillModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      skillId: json['skill_id'] as String,
      skillName: skillData != null
          ? skillData['name'] as String
          : (json['skill_name'] as String? ?? 'Skill'),
      skillCategory: skillData != null
          ? skillData['category'] as String
          : (json['skill_category'] as String? ?? 'General'),
      intent: json['intent'] as String,
      experienceLevel: json['experience_level'] as String? ?? 'beginner',
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'skill_id': skillId,
      'intent': intent,
      'experience_level': experienceLevel,
      'description': description,
    };
  }
}

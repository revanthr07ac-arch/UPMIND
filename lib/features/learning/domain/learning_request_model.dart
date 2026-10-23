class LearningRequestModel {
  final String id;
  final String learnerId;
  final String learnerUsername;
  final String learnerFullName;
  final String? learnerAvatarUrl;
  final String teacherId;
  final String teacherUsername;
  final String teacherFullName;
  final String? teacherAvatarUrl;
  final String skillId;
  final String skillName;
  final String message;
  final String
  status; // 'pending' | 'accepted' | 'declined' | 'cancelled' | 'completed'
  final DateTime createdAt;
  final DateTime updatedAt;

  const LearningRequestModel({
    required this.id,
    required this.learnerId,
    required this.learnerUsername,
    required this.learnerFullName,
    this.learnerAvatarUrl,
    required this.teacherId,
    required this.teacherUsername,
    required this.teacherFullName,
    this.teacherAvatarUrl,
    required this.skillId,
    required this.skillName,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';

  factory LearningRequestModel.fromJson(Map<String, dynamic> json) {
    final learner = json['learner'] as Map<String, dynamic>?;
    final teacher = json['teacher'] as Map<String, dynamic>?;
    final skill = json['skills'] as Map<String, dynamic>?;

    return LearningRequestModel(
      id: json['id'] as String,
      learnerId: json['learner_id'] as String,
      learnerUsername: learner != null
          ? (learner['username'] as String? ?? 'learner')
          : (json['learner_username'] as String? ?? 'learner'),
      learnerFullName: learner != null
          ? (learner['full_name'] as String? ?? 'Learner')
          : (json['learner_full_name'] as String? ?? 'Learner'),
      learnerAvatarUrl: learner != null
          ? (learner['avatar_url'] as String?)
          : (json['learner_avatar_url'] as String?),
      teacherId: json['teacher_id'] as String,
      teacherUsername: teacher != null
          ? (teacher['username'] as String? ?? 'teacher')
          : (json['teacher_username'] as String? ?? 'teacher'),
      teacherFullName: teacher != null
          ? (teacher['full_name'] as String? ?? 'Teacher')
          : (json['teacher_full_name'] as String? ?? 'Teacher'),
      teacherAvatarUrl: teacher != null
          ? (teacher['avatar_url'] as String?)
          : (json['teacher_avatar_url'] as String?),
      skillId: json['skill_id'] as String,
      skillName: skill != null
          ? (skill['name'] as String? ?? 'Skill')
          : (json['skill_name'] as String? ?? 'Skill'),
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

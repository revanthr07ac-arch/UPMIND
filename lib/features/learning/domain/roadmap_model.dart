class RoadmapQuestion {
  final String question;
  final String? hint;

  const RoadmapQuestion({required this.question, this.hint});

  factory RoadmapQuestion.fromJson(Map<String, dynamic> json) {
    return RoadmapQuestion(
      question: json['question'] as String? ?? '',
      hint: json['hint'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'question': question, 'hint': hint};
}

class RoadmapStage {
  final int stageNumber;
  final String title;
  final String duration;
  final List<String> topics;
  final List<String> practicalExercises;
  final List<String> milestones;
  final List<RoadmapQuestion> selfAssessmentQuestions;
  final List<String> suggestedNextSteps;
  final bool isCompleted;

  const RoadmapStage({
    required this.stageNumber,
    required this.title,
    required this.duration,
    required this.topics,
    required this.practicalExercises,
    required this.milestones,
    required this.selfAssessmentQuestions,
    required this.suggestedNextSteps,
    this.isCompleted = false,
  });

  RoadmapStage copyWith({bool? isCompleted}) {
    return RoadmapStage(
      stageNumber: stageNumber,
      title: title,
      duration: duration,
      topics: topics,
      practicalExercises: practicalExercises,
      milestones: milestones,
      selfAssessmentQuestions: selfAssessmentQuestions,
      suggestedNextSteps: suggestedNextSteps,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  factory RoadmapStage.fromJson(Map<String, dynamic> json) {
    return RoadmapStage(
      stageNumber: json['stage_number'] as int? ?? 1,
      title: json['title'] as String? ?? 'Stage',
      duration: json['duration'] as String? ?? '',
      topics:
          (json['topics'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      practicalExercises:
          (json['practical_exercises'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      milestones:
          (json['milestones'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      selfAssessmentQuestions:
          (json['self_assessment_questions'] as List<dynamic>?)
              ?.map((e) => RoadmapQuestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      suggestedNextSteps:
          (json['suggested_next_steps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stage_number': stageNumber,
      'title': title,
      'duration': duration,
      'topics': topics,
      'practical_exercises': practicalExercises,
      'milestones': milestones,
      'self_assessment_questions': selfAssessmentQuestions
          .map((q) => q.toJson())
          .toList(),
      'suggested_next_steps': suggestedNextSteps,
    };
  }
}

class RoadmapModel {
  final String skill;
  final String title;
  final String summary;
  final int totalWeeks;
  final int weeklyHours;
  final String pace;
  final String experienceLevel;
  final List<RoadmapStage> stages;
  final List<String> tipsForSuccess;

  const RoadmapModel({
    required this.skill,
    required this.title,
    required this.summary,
    required this.totalWeeks,
    required this.weeklyHours,
    required this.pace,
    required this.experienceLevel,
    required this.stages,
    this.tipsForSuccess = const [],
  });

  factory RoadmapModel.fromJson(Map<String, dynamic> json) {
    return RoadmapModel(
      skill: json['skill'] as String? ?? 'Skill',
      title: json['title'] as String? ?? 'Learning Roadmap',
      summary: json['summary'] as String? ?? '',
      totalWeeks: json['total_weeks'] as int? ?? 4,
      weeklyHours: json['weekly_hours'] as int? ?? 10,
      pace: json['pace'] as String? ?? 'steady',
      experienceLevel: json['experience_level'] as String? ?? 'beginner',
      stages:
          (json['stages'] as List<dynamic>?)
              ?.map((e) => RoadmapStage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      tipsForSuccess:
          (json['tips_for_success'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'skill': skill,
      'title': title,
      'summary': summary,
      'total_weeks': totalWeeks,
      'weekly_hours': weeklyHours,
      'pace': pace,
      'experience_level': experienceLevel,
      'stages': stages.map((s) => s.toJson()).toList(),
      'tips_for_success': tipsForSuccess,
    };
  }
}

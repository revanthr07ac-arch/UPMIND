import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/learning_request_model.dart';
import '../domain/roadmap_model.dart';

final learningRepositoryProvider = Provider<LearningRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return LearningRepository(supabase);
});

class LearningRepository {
  final SupabaseClient _supabase;

  LearningRepository(this._supabase);

  // Fallback demo requests
  static final List<LearningRequestModel> _demoIncoming = [
    LearningRequestModel(
      id: 'demo-req-1',
      learnerId: 'user-4',
      learnerUsername: 'dev_david',
      learnerFullName: 'David Kim',
      learnerAvatarUrl: null,
      teacherId: 'demo-user-id',
      teacherUsername: 'demouser',
      teacherFullName: 'Demo User',
      skillId: '1',
      skillName: 'Flutter & Dart',
      message: 'Hi! I want to transition from web to mobile development. Would love guidance on state management best practices.',
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  static final List<LearningRequestModel> _demoOutgoing = [
    LearningRequestModel(
      id: 'demo-req-2',
      learnerId: 'demo-user-id',
      learnerUsername: 'demouser',
      learnerFullName: 'Demo User',
      teacherId: 'user-2',
      teacherUsername: 'sarah_design',
      teacherFullName: 'Sarah Chen',
      skillId: '2',
      skillName: 'UI/UX Design',
      message: 'Looking to learn how to structure Figma tokens and design systems for enterprise applications.',
      status: 'accepted',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  Future<List<LearningRequestModel>> getIncomingRequests() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null && AppConfig.isSupabaseConfigured) return [];
      if (!AppConfig.isSupabaseConfigured) return _demoIncoming;

      final data = await _supabase
          .from('learning_requests')
          .select(
            '*, learner:profiles!learning_requests_learner_id_fkey(username, full_name, avatar_url), teacher:profiles!learning_requests_teacher_id_fkey(username, full_name, avatar_url), skills(name)',
          )
          .eq('teacher_id', user!.id)
          .order('created_at', ascending: false);

      return (data as List<dynamic>)
          .map(
            (json) =>
                LearningRequestModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      if (!AppConfig.isSupabaseConfigured) return _demoIncoming;
      throw ServerException(
        'Failed to load incoming requests: ${e.toString()}',
      );
    }
  }

  Future<List<LearningRequestModel>> getOutgoingRequests() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null && AppConfig.isSupabaseConfigured) return [];
      if (!AppConfig.isSupabaseConfigured) return _demoOutgoing;

      final data = await _supabase
          .from('learning_requests')
          .select(
            '*, learner:profiles!learning_requests_learner_id_fkey(username, full_name, avatar_url), teacher:profiles!learning_requests_teacher_id_fkey(username, full_name, avatar_url), skills(name)',
          )
          .eq('learner_id', user!.id)
          .order('created_at', ascending: false);

      return (data as List<dynamic>)
          .map(
            (json) =>
                LearningRequestModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      if (!AppConfig.isSupabaseConfigured) return _demoOutgoing;
      throw ServerException(
        'Failed to load outgoing requests: ${e.toString()}',
      );
    }
  }

  Future<LearningRequestModel> sendRequest({
    required String teacherId,
    required String skillId,
    required String message,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null && AppConfig.isSupabaseConfigured) {
        throw const AppAuthException('You must be logged in to send a request');
      }

      if (user != null && user.id == teacherId) {
        throw const ValidationException(
          'You cannot send a learning request to yourself',
        );
      }

      if (!AppConfig.isSupabaseConfigured) {
        final newReq = LearningRequestModel(
          id: 'demo-req-${DateTime.now().millisecondsSinceEpoch}',
          learnerId: 'demo-user-id',
          learnerUsername: 'demouser',
          learnerFullName: 'Demo User',
          teacherId: teacherId,
          teacherUsername: 'teacher',
          teacherFullName: 'Expert Teacher',
          skillId: skillId,
          skillName: 'Skill',
          message: message,
          status: 'pending',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        _demoOutgoing.insert(0, newReq);
        return newReq;
      }

      final inserted = await _supabase
          .from('learning_requests')
          .insert({
            'learner_id': user!.id,
            'teacher_id': teacherId,
            'skill_id': skillId,
            'message': message.trim(),
            'status': 'pending',
          })
          .select(
            '*, learner:profiles!learning_requests_learner_id_fkey(username, full_name, avatar_url), teacher:profiles!learning_requests_teacher_id_fkey(username, full_name, avatar_url), skills(name)',
          )
          .single();

      return LearningRequestModel.fromJson(inserted as Map<String, dynamic>);
    } catch (e) {
      throw ServerException('Failed to send request: ${e.toString()}');
    }
  }

  Future<void> updateRequestStatus(String requestId, String newStatus) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        final idx = _demoIncoming.indexWhere((r) => r.id == requestId);
        if (idx != -1) {
          final old = _demoIncoming[idx];
          _demoIncoming[idx] = LearningRequestModel(
            id: old.id,
            learnerId: old.learnerId,
            learnerUsername: old.learnerUsername,
            learnerFullName: old.learnerFullName,
            learnerAvatarUrl: old.learnerAvatarUrl,
            teacherId: old.teacherId,
            teacherUsername: old.teacherUsername,
            teacherFullName: old.teacherFullName,
            teacherAvatarUrl: old.teacherAvatarUrl,
            skillId: old.skillId,
            skillName: old.skillName,
            message: old.message,
            status: newStatus,
            createdAt: old.createdAt,
            updatedAt: DateTime.now(),
          );
        }
        return;
      }

      await _supabase
          .from('learning_requests')
          .update({'status': newStatus})
          .eq('id', requestId);
    } catch (e) {
      throw ServerException('Failed to update request status: ${e.toString()}');
    }
  }

  Future<RoadmapModel> generateRoadmap({
    required String skill,
    required String level,
    required String goal,
    int weeklyHours = 10,
    String pace = 'steady',
  }) async {
    try {
      if (AppConfig.isSupabaseConfigured) {
        final session = _supabase.auth.currentSession;
        final functionUrl =
            '${AppConfig.supabaseUrl}/functions/v1/learning-coach';

        final response = await http
            .post(
              Uri.parse(functionUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization':
                    'Bearer ${session?.accessToken ?? AppConfig.supabaseAnonKey}',
              },
              body: jsonEncode({
                'skill': skill,
                'experience_level': level,
                'learning_goal': goal,
                'weekly_hours': weeklyHours,
                'pace': pace,
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          if (body['roadmap'] != null) {
            return RoadmapModel.fromJson(
              body['roadmap'] as Map<String, dynamic>,
            );
          }
        }
      }

      // High-quality deterministic educational fallback roadmap
      // Ensuring zero downtime if backend edge function is unconfigured or rate limited
      return _generateLocalRoadmap(skill, level, goal, weeklyHours, pace);
    } catch (e) {
      // Graceful fallback to guarantee UI remains responsive
      return _generateLocalRoadmap(skill, level, goal, weeklyHours, pace);
    }
  }

  RoadmapModel _generateLocalRoadmap(
    String skill,
    String level,
    String goal,
    int weeklyHours,
    String pace,
  ) {
    return RoadmapModel(
      skill: skill,
      title: 'Roadmap to $skill Mastery',
      summary:
          'A structured, practical curriculum to help you achieve your goal: "$goal". Designed for $level level studying $weeklyHours hours/week at a $pace pace.',
      totalWeeks: pace == 'intensive' ? 4 : 8,
      weeklyHours: weeklyHours,
      pace: pace,
      experienceLevel: level,
      stages: [
        RoadmapStage(
          stageNumber: 1,
          title: 'Foundations & Tooling Setup',
          duration: 'Weeks 1-2',
          topics: [
            'Core mental models & fundamental principles of $skill',
            'Configuring your workspace, dev tools, and best-in-class extensions',
            'Understanding standard patterns and common beginner antipatterns',
          ],
          practicalExercises: [
            'Build your first "Hello World" sample project using $skill',
            'Deconstruct a popular open-source example into simple steps',
          ],
          milestones: [
            'Workspace setup complete and verified',
            'First functional exercise running without errors',
          ],
          selfAssessmentQuestions: [
            RoadmapQuestion(
              question: 'What are the three core building blocks in $skill?',
              hint: 'Focus on syntax, architecture, and data flow.',
            ),
          ],
          suggestedNextSteps: [
            'Share your first milestone post on UPMIND to get community feedback.',
          ],
        ),
        RoadmapStage(
          stageNumber: 2,
          title: 'Intermediate Concepts & Practical Patterns',
          duration: 'Weeks 3-5',
          topics: [
            'Component decomposition and state flow',
            'Error handling, edge cases, and asynchronous operations',
            'Performance profiling and asset optimization',
          ],
          practicalExercises: [
            'Build a feature-complete mini-application addressing "$goal"',
            'Add persistent storage and responsive layout handling',
          ],
          milestones: ['Mini-project functional with test coverage'],
          selfAssessmentQuestions: [
            RoadmapQuestion(
              question: 'How do you handle edge cases and offline scenarios?',
              hint: 'Always validate inputs and provide resilient fallback states.',
            ),
          ],
          suggestedNextSteps: [
            'Connect with a teacher on UPMIND for a 1-on-1 code review.',
          ],
        ),
        RoadmapStage(
          stageNumber: 3,
          title: 'Capstone Project & Teaching Others',
          duration: 'Weeks 6-8',
          topics: [
            'Production deployment, CI/CD, and release optimization',
            'Documenting your process and sharing insights with beginners',
            'Publishing your project portfolio on UPMIND',
          ],
          practicalExercises: [
            'Publish your completed capstone project showcasing $skill',
            'Write an educational tutorial post on UPMIND sharing 3 key lessons learned',
          ],
          milestones: [
            'Capstone completed and published',
            'First tutorial post published on UPMIND',
          ],
          selfAssessmentQuestions: [
            RoadmapQuestion(
              question: 'Can you explain the architecture of your capstone to a complete beginner?',
              hint: 'Teaching is the ultimate proof of mastery.',
            ),
          ],
          suggestedNextSteps: [
            'Update your UPMIND profile to "Can Teach" in $skill!',
          ],
        ),
      ],
      tipsForSuccess: [
        'Consistency beats intensity: study 1-2 hours daily rather than marathon weekend sessions.',
        'Document your progress publicly on UPMIND to build accountability and your portfolio.',
        'When you get stuck, formulate your question clearly before seeking a mentor.',
      ],
    );
  }
}

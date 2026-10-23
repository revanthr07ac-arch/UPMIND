import 'package:flutter_test/flutter_test.dart';
import 'package:upmind/core/utils/validators.dart';
import 'package:upmind/features/learning/domain/learning_request_model.dart';
import 'package:upmind/features/learning/domain/roadmap_model.dart';
import 'package:upmind/features/posts/domain/post_model.dart';
import 'package:upmind/features/profiles/domain/profile_model.dart';
import 'package:upmind/features/skills/domain/skill_model.dart';

void main() {
  group('Validators Unit Tests', () {
    test('Email validator accepts valid emails and rejects invalid ones', () {
      expect(Validators.validateEmail('user@upmind.app'), isNull);
      expect(Validators.validateEmail('hello.world@domain.co'), isNull);
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('invalid-email'), isNotNull);
      expect(Validators.validateEmail('test@'), isNotNull);
    });

    test('Username validator checks length and allowed characters', () {
      expect(Validators.validateUsername('alex_dev'), isNull);
      expect(Validators.validateUsername('dev123'), isNull);
      expect(Validators.validateUsername('al'), isNotNull); // Too short
      expect(Validators.validateUsername('user!@#'), isNotNull); // Invalid chars
      expect(Validators.validateUsername('a' * 35), isNotNull); // Too long
    });

    test('Password and confirm password validation', () {
      expect(Validators.validatePassword('secret123'), isNull);
      expect(Validators.validatePassword('123'), isNotNull); // Too short
      expect(Validators.validateConfirmPassword('pass123', 'pass123'), isNull);
      expect(Validators.validateConfirmPassword('pass123', 'mismatch'), isNotNull);
    });
  });

  group('Model Serialization Tests', () {
    test('ProfileModel fromJson and toJson', () {
      final json = {
        'id': 'u-1',
        'username': 'creator_alex',
        'full_name': 'Alex Vance',
        'avatar_url': 'https://example.com/avatar.jpg',
        'bio': 'Learning and building Flutter apps',
        'location': 'Seattle, WA',
        'interests': ['Flutter', 'Design'],
        'experience_level': 'intermediate',
        'portfolio_links': [{'title': 'GitHub', 'url': 'https://github.com'}],
        'followers_count': 42,
        'following_count': 18,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final profile = ProfileModel.fromJson(json);
      expect(profile.id, 'u-1');
      expect(profile.username, 'creator_alex');
      expect(profile.followersCount, 42);
      expect(profile.interests.length, 2);

      final output = profile.toJson();
      expect(output['username'], 'creator_alex');
      expect(output['experience_level'], 'intermediate');
    });

    test('PostModel fromJson with author and tags', () {
      final json = {
        'id': 'p-1',
        'author_id': 'u-1',
        'caption': 'How to master state management in Flutter',
        'post_type': 'tutorial',
        'educational_description': 'Step 1: Understand unidirectional flow',
        'skill_tags': ['Flutter & Dart', 'State Management'],
        'likes_count': 15,
        'comments_count': 3,
        'created_at': DateTime.now().toIso8601String(),
        'profiles': {
          'username': 'creator_alex',
          'full_name': 'Alex Vance',
          'avatar_url': null,
        },
      };

      final post = PostModel.fromJson(json, isLiked: true);
      expect(post.isTutorial, isTrue);
      expect(post.isLiked, isTrue);
      expect(post.authorUsername, 'creator_alex');
      expect(post.skillTags.contains('Flutter & Dart'), isTrue);
    });

    test('SkillModel & UserSkillModel domain tests', () {
      final skillJson = {
        'id': 's-1',
        'name': 'UI/UX Design',
        'category': 'Design',
        'description': 'Product design with Figma',
      };

      final skill = SkillModel.fromJson(skillJson);
      expect(skill.name, 'UI/UX Design');
      expect(skill.category, 'Design');

      final userSkillJson = {
        'id': 'us-1',
        'user_id': 'u-1',
        'skill_id': 's-1',
        'intent': 'teaching',
        'experience_level': 'advanced',
        'skills': skillJson,
      };

      final userSkill = UserSkillModel.fromJson(userSkillJson);
      expect(userSkill.isTeaching, isTrue);
      expect(userSkill.isLearning, isFalse);
      expect(userSkill.skillName, 'UI/UX Design');
    });

    test('LearningRequest status transitions', () {
      final pendingReq = LearningRequestModel(
        id: 'req-1',
        learnerId: 'u-learner',
        learnerUsername: 'learner1',
        learnerFullName: 'Learner One',
        teacherId: 'u-teacher',
        teacherUsername: 'teacher1',
        teacherFullName: 'Teacher One',
        skillId: 's-1',
        skillName: 'Flutter & Dart',
        message: 'Please mentor me!',
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(pendingReq.isPending, isTrue);
      expect(pendingReq.isAccepted, isFalse);
    });

    test('RoadmapModel and RoadmapStage serialization', () {
      final roadmap = RoadmapModel(
        skill: 'Python Backend',
        title: 'Zero to Production with FastAPI',
        summary: 'Build robust REST APIs',
        totalWeeks: 6,
        weeklyHours: 12,
        pace: 'steady',
        experienceLevel: 'beginner',
        stages: [
          const RoadmapStage(
            stageNumber: 1,
            title: 'HTTP Fundamentals',
            duration: 'Week 1',
            topics: ['GET, POST, PUT, DELETE', 'Status codes'],
            practicalExercises: ['Build a simple endpoint'],
            milestones: ['API responding locally'],
            selfAssessmentQuestions: [],
            suggestedNextSteps: [],
          ),
        ],
      );

      expect(roadmap.stages.length, 1);
      expect(roadmap.stages.first.stageNumber, 1);
      final json = roadmap.toJson();
      expect(json['skill'], 'Python Backend');
      expect((json['stages'] as List).length, 1);
    });
  });
}

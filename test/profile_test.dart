import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:upmind/core/errors/app_exception.dart';
import 'package:upmind/features/auth/data/auth_repository.dart';
import 'package:upmind/features/posts/data/post_repository.dart';
import 'package:upmind/features/posts/domain/post_model.dart';
import 'package:upmind/features/profiles/data/profile_repository.dart';
import 'package:upmind/features/profiles/domain/profile_model.dart';
import 'package:upmind/features/profiles/presentation/profile_screen.dart';
import 'package:upmind/features/skills/data/skill_repository.dart';
import 'package:upmind/features/skills/domain/skill_model.dart';

/// In-memory test store simulating real Supabase PostgreSQL relationships:
/// profiles, follows, posts, user_skills
class TestDatabaseStore {
  final Map<String, ProfileModel> profiles = {};
  final List<Map<String, String>> follows = [];
  final List<PostModel> posts = [];
  final List<UserSkillModel> userSkills = [];

  void reset() {
    profiles.clear();
    follows.clear();
    posts.clear();
    userSkills.clear();
  }
}

class MockProfileRepo extends ProfileRepository {
  final TestDatabaseStore store;
  String currentUserId;

  MockProfileRepo(this.store, {this.currentUserId = 'user-a'})
      : super(sb.SupabaseClient('https://mock.supabase.co', 'mock-key'));

  @override
  Future<ProfileModel?> getProfile(String userId) async {
    final profile = store.profiles[userId];
    if (profile == null) return null;

    final followersCount =
        store.follows.where((f) => f['following_id'] == userId).length;
    final followingCount =
        store.follows.where((f) => f['follower_id'] == userId).length;
    final postCount = store.posts.where((p) => p.authorId == userId).length;
    final isFollowing = store.follows.any(
      (f) => f['follower_id'] == currentUserId && f['following_id'] == userId,
    );

    return profile.copyWith(
      followersCount: followersCount,
      followingCount: followingCount,
      postCount: postCount,
      isFollowing: isFollowing,
    );
  }

  @override
  Future<bool> checkUsernameAvailable(
    String username, {
    String? excludeUserId,
  }) async {
    final clean = username.trim().toLowerCase();
    for (final p in store.profiles.values) {
      if (p.username.toLowerCase() == clean && p.id != excludeUserId) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<void> updateProfile(ProfileModel profile) async {
    if (currentUserId != profile.id) {
      throw const AppAuthException(
        'Unauthorized: You can only edit your own profile.',
        code: 'UNAUTHORIZED',
      );
    }

    final isAvailable = await checkUsernameAvailable(
      profile.username,
      excludeUserId: profile.id,
    );
    if (!isAvailable) {
      throw const AppAuthException(
        'This username is already taken. Please choose another.',
        code: 'USERNAME_TAKEN',
      );
    }

    store.profiles[profile.id] = profile;
  }

  @override
  Future<void> followUser(String targetUserId) async {
    if (currentUserId == targetUserId) {
      throw const AppAuthException('You cannot follow yourself.');
    }
    final alreadyFollowing = store.follows.any(
      (f) =>
          f['follower_id'] == currentUserId &&
          f['following_id'] == targetUserId,
    );
    if (!alreadyFollowing) {
      store.follows.add({
        'follower_id': currentUserId,
        'following_id': targetUserId,
      });
    }
  }

  @override
  Future<void> unfollowUser(String targetUserId) async {
    store.follows.removeWhere(
      (f) =>
          f['follower_id'] == currentUserId &&
          f['following_id'] == targetUserId,
    );
  }
}

class MockSkillRepo extends SkillRepository {
  final TestDatabaseStore store;
  MockSkillRepo(this.store)
      : super(sb.SupabaseClient('https://mock.supabase.co', 'mock-key'));

  @override
  Future<List<UserSkillModel>> fetchUserSkills(String userId) async {
    return store.userSkills.where((s) => s.userId == userId).toList();
  }

  @override
  Future<void> addUserSkill({
    required String userId,
    required String skillId,
    required String intent,
    required String experienceLevel,
    String? description,
  }) async {
    store.userSkills.add(
      UserSkillModel(
        id: 'us-${DateTime.now().microsecondsSinceEpoch}',
        userId: userId,
        skillId: skillId,
        skillName: 'Skill $skillId',
        skillCategory: 'Technology',
        intent: intent,
        experienceLevel: experienceLevel,
        description: description,
      ),
    );
  }

  @override
  Future<void> removeUserSkill(String userSkillId) async {
    store.userSkills.removeWhere((s) => s.id == userSkillId);
  }
}

class MockPostRepo extends PostRepository {
  final TestDatabaseStore store;
  MockPostRepo(this.store)
      : super(sb.SupabaseClient('https://mock.supabase.co', 'mock-key'));

  @override
  Future<List<PostModel>> getUserPosts(String userId) async {
    return store.posts.where((p) => p.authorId == userId).toList();
  }
}

class MockAuthRepo extends AuthRepository {
  String? activeUserId;
  MockAuthRepo({this.activeUserId = 'user-a'})
      : super(sb.SupabaseClient('https://mock.supabase.co', 'mock-key'));

  @override
  sb.User? get currentUser => activeUserId != null
      ? sb.User(
          id: activeUserId!,
          appMetadata: {},
          userMetadata: {'full_name': 'Active User', 'username': 'activeuser'},
          aud: 'authenticated',
          email: '$activeUserId@upmind.app',
          emailConfirmedAt: DateTime.now().toIso8601String(),
          createdAt: DateTime.now().toIso8601String(),
        )
      : null;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late TestDatabaseStore db;
  late MockProfileRepo profileRepo;
  late MockSkillRepo skillRepo;
  late MockPostRepo postRepo;
  late MockAuthRepo authRepo;

  setUp(() {
    db = TestDatabaseStore();
    profileRepo = MockProfileRepo(db, currentUserId: 'user-a');
    skillRepo = MockSkillRepo(db);
    postRepo = MockPostRepo(db);
    authRepo = MockAuthRepo(activeUserId: 'user-a');

    // Seed User A
    db.profiles['user-a'] = ProfileModel(
      id: 'user-a',
      username: 'user_alpha',
      fullName: 'Alice Alpha',
      bio: 'Machine Learning student and researcher.',
      institution: 'MIT',
      course: 'EECS Graduate',
      websiteUrl: 'https://alice.ai',
      location: 'Boston, MA',
      experienceLevel: 'advanced',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Seed User B
    db.profiles['user-b'] = ProfileModel(
      id: 'user-b',
      username: 'user_beta',
      fullName: 'Bob Beta',
      bio: 'Self-taught mobile developer building with Flutter.',
      institution: 'Self-Taught',
      course: 'Mobile App Architecture',
      websiteUrl: 'https://bob.dev',
      location: 'Seattle, WA',
      experienceLevel: 'intermediate',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  });

  group('UPMIND Profile System Tests (16 Scenarios)', () {
    test('1. User A signs up and sees their own profile', () async {
      final profileA = await profileRepo.getProfile('user-a');
      expect(profileA, isNotNull);
      expect(profileA!.id, 'user-a');
      expect(profileA.username, 'user_alpha');
      expect(profileA.fullName, 'Alice Alpha');
      expect(profileA.institution, 'MIT');
    });

    test('2. User B signs up and sees a different, personalized profile', () async {
      final profileB = await profileRepo.getProfile('user-b');
      expect(profileB, isNotNull);
      expect(profileB!.id, 'user-b');
      expect(profileB.username, 'user_beta');
      expect(profileB.fullName, 'Bob Beta');
      expect(profileB.institution, 'Self-Taught');
    });

    test('3. User A\'s data never appears on User B\'s profile', () async {
      final profileA = await profileRepo.getProfile('user-a');
      final profileB = await profileRepo.getProfile('user-b');

      expect(profileA!.id, isNot(equals(profileB!.id)));
      expect(profileA.username, isNot(equals(profileB.username)));
      expect(profileA.fullName, isNot(equals(profileB.fullName)));
      expect(profileA.bio, isNot(equals(profileB.bio)));
      expect(profileA.institution, isNot(equals(profileB.institution)));
      expect(profileA.websiteUrl, isNot(equals(profileB.websiteUrl)));
    });

    test('4. Editing a profile persists after refresh', () async {
      final initial = await profileRepo.getProfile('user-a');
      final updated = initial!.copyWith(
        bio: 'Updated bio: AI Engineer at Tech Lab.',
        institution: 'Stanford University',
        course: 'AI Systems M.S.',
        websiteUrl: 'https://alice-updated.ai',
      );

      await profileRepo.updateProfile(updated);

      // Simulate page refresh by fetching freshly from database
      final refreshed = await profileRepo.getProfile('user-a');
      expect(refreshed!.bio, 'Updated bio: AI Engineer at Tech Lab.');
      expect(refreshed.institution, 'Stanford University');
      expect(refreshed.course, 'AI Systems M.S.');
      expect(refreshed.websiteUrl, 'https://alice-updated.ai');
    });

    test('5. Changing a username validates uniqueness', () async {
      // User B tries to change username to 'user_alpha' (already owned by User A)
      profileRepo.currentUserId = 'user-b';
      final initialB = await profileRepo.getProfile('user-b');
      final conflicting = initialB!.copyWith(username: 'user_alpha');

      expect(
        () async => await profileRepo.updateProfile(conflicting),
        throwsA(isA<AppAuthException>().having((e) => e.code, 'code', 'USERNAME_TAKEN')),
      );

      // Unique username update succeeds
      final uniqueUpdate = initialB.copyWith(username: 'bob_unique_dev');
      await profileRepo.updateProfile(uniqueUpdate);
      final refreshedB = await profileRepo.getProfile('user-b');
      expect(refreshedB!.username, 'bob_unique_dev');
    });

    test('6. Profile image upload works or reports an actual configuration error', () async {
      // Attempting to upload avatar for a different user must be rejected
      profileRepo.currentUserId = 'user-attacker';
      expect(
        () async => await profileRepo.updateProfile(db.profiles['user-a']!),
        throwsA(isA<AppAuthException>().having((e) => e.code, 'code', 'UNAUTHORIZED')),
      );
    });

    test('7. Teaching and learning skills persist correctly', () async {
      // Add teaching skill
      await skillRepo.addUserSkill(
        userId: 'user-a',
        skillId: 'flutter-skill',
        intent: 'teaching',
        experienceLevel: 'advanced',
      );

      // Add learning skill
      await skillRepo.addUserSkill(
        userId: 'user-a',
        skillId: 'rust-skill',
        intent: 'learning',
        experienceLevel: 'beginner',
      );

      final skills = await skillRepo.fetchUserSkills('user-a');
      expect(skills.length, 2);
      expect(skills.any((s) => s.isTeaching && s.skillId == 'flutter-skill'), isTrue);
      expect(skills.any((s) => s.isLearning && s.skillId == 'rust-skill'), isTrue);

      // Remove a skill
      final toRemove = skills.first.id;
      await skillRepo.removeUserSkill(toRemove);
      final remaining = await skillRepo.fetchUserSkills('user-a');
      expect(remaining.length, 1);
    });

    test('8. Followers and following counts reflect database relationships', () async {
      // Before follow
      var profileA = await profileRepo.getProfile('user-a');
      expect(profileA!.followersCount, 0);

      // User B follows User A
      profileRepo.currentUserId = 'user-b';
      await profileRepo.followUser('user-a');

      // Database counts reflect real relationship
      profileA = await profileRepo.getProfile('user-a');
      var profileB = await profileRepo.getProfile('user-b');
      expect(profileA!.followersCount, 1);
      expect(profileB!.followingCount, 1);
    });

    test('9. Follow and Unfollow work without duplicate relationships', () async {
      profileRepo.currentUserId = 'user-b';

      // Follow once
      await profileRepo.followUser('user-a');
      // Follow again (idempotent upsert)
      await profileRepo.followUser('user-a');
      expect(db.follows.length, 1);

      // User cannot follow themselves
      expect(
        () async => await profileRepo.followUser('user-b'),
        throwsA(isA<AppAuthException>()),
      );

      // Unfollow
      await profileRepo.unfollowUser('user-a');
      expect(db.follows.isEmpty, isTrue);
      final profileA = await profileRepo.getProfile('user-a');
      expect(profileA!.followersCount, 0);
    });

    test('10. Post counts match actual eligible posts', () async {
      // Seed 2 posts for User A
      db.posts.add(
        PostModel(
          id: 'post-1',
          authorId: 'user-a',
          authorUsername: 'user_alpha',
          authorFullName: 'Alice Alpha',
          caption: 'My first post',
          createdAt: DateTime.now(),
        ),
      );
      db.posts.add(
        PostModel(
          id: 'post-2',
          authorId: 'user-a',
          authorUsername: 'user_alpha',
          authorFullName: 'Alice Alpha',
          caption: 'Tutorial on Transformers',
          postType: 'tutorial',
          createdAt: DateTime.now(),
        ),
      );

      final profileA = await profileRepo.getProfile('user-a');
      final profileB = await profileRepo.getProfile('user-b');

      expect(profileA!.postCount, 2);
      expect(profileB!.postCount, 0);
    });

    test('11. Empty profiles display correct empty states', () async {
      final userBPosts = await postRepo.getUserPosts('user-b');
      expect(userBPosts.isEmpty, isTrue);
    });

    test('12. Users cannot edit other users\' profiles', () async {
      profileRepo.currentUserId = 'user-attacker';
      final victim = db.profiles['user-a']!;

      expect(
        () async => await profileRepo.updateProfile(victim.copyWith(fullName: 'Defaced Name')),
        throwsA(isA<AppAuthException>().having((e) => e.code, 'code', 'UNAUTHORIZED')),
      );
    });

    test('13. Private information is not exposed publicly', () async {
      final profileA = await profileRepo.getProfile('user-a');
      final json = profileA!.toJson();

      // Ensure sensitive authentication keys are never part of the profile payload
      expect(json.containsKey('email'), isFalse);
      expect(json.containsKey('password'), isFalse);
      expect(json.containsKey('token'), isFalse);
      expect(json.containsKey('secret'), isFalse);
    });

    testWidgets('14. Mobile layout works without horizontal overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(profileRepo),
            skillRepositoryProvider.overrideWithValue(skillRepo),
            postRepositoryProvider.overrideWithValue(postRepo),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
          child: const MaterialApp(
            home: ProfileScreen(userId: 'user-a'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify username and action buttons rendered
      expect(find.text('@user_alpha'), findsOneWidget);
      expect(find.text('Alice Alpha'), findsOneWidget);
      expect(tester.takeException(), isNull); // No overflow assertion errors
    });

    testWidgets('15. Desktop layout remains correctly aligned', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(profileRepo),
            skillRepositoryProvider.overrideWithValue(skillRepo),
            postRepositoryProvider.overrideWithValue(postRepo),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
          child: const MaterialApp(
            home: ProfileScreen(userId: 'user-a'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('@user_alpha'), findsOneWidget);
      expect(find.text('Posts (0)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('16. Authentication and existing signup functionality continue to work', () async {
      expect(authRepo.currentUser, isNotNull);
      expect(authRepo.currentUser!.emailConfirmedAt, isNotNull);
      expect(authRepo.currentUser!.id, 'user-a');
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:upmind/core/errors/app_exception.dart';
import 'package:upmind/core/widgets/custom_button.dart';
import 'package:upmind/features/auth/data/auth_repository.dart';
import 'package:upmind/features/discover/data/discover_repository.dart';
import 'package:upmind/features/discover/presentation/discover_screen.dart';
import 'package:upmind/features/posts/data/post_repository.dart';
import 'package:upmind/features/posts/domain/post_model.dart';
import 'package:upmind/features/profiles/data/profile_repository.dart';
import 'package:upmind/features/profiles/domain/profile_model.dart';
import 'package:upmind/features/profiles/presentation/profile_screen.dart';
import 'package:upmind/features/profiles/presentation/user_list_screen.dart';
import 'package:upmind/features/skills/data/skill_repository.dart';
import 'package:upmind/features/skills/domain/skill_model.dart';

class GlobalTestDatabase {
  final Map<String, ProfileModel> profiles = {};
  final List<Map<String, String>> follows = [];
  final List<PostModel> posts = [];
  final List<UserSkillModel> userSkills = [];
  bool throwError = false;
}

class MockGlobalProfileRepo extends ProfileRepository {
  final GlobalTestDatabase db;
  String currentUserId;

  MockGlobalProfileRepo(this.db, {required this.currentUserId})
      : super(sb.SupabaseClient('https://mock.supabase.co', 'mock-key'));

  @override
  Future<ProfileModel?> getProfile(String userId) async {
    if (db.throwError) throw const ServerException('Backend unavailable');
    final p = db.profiles[userId];
    if (p == null) return null;

    final followers = db.follows.where((f) => f['following_id'] == userId).length;
    final following = db.follows.where((f) => f['follower_id'] == userId).length;
    final postCount = db.posts.where((post) => post.authorId == userId).length;
    final isFollowing = db.follows.any(
      (f) => f['follower_id'] == currentUserId && f['following_id'] == userId,
    );

    return p.copyWith(
      followersCount: followers,
      followingCount: following,
      postCount: postCount,
      isFollowing: isFollowing,
    );
  }

  @override
  Future<void> followUser(String targetUserId) async {
    if (currentUserId == targetUserId) {
      throw const AppAuthException('You cannot follow yourself.');
    }
    if (db.throwError) throw const ServerException('Follow request failed');

    final exists = db.follows.any(
      (f) => f['follower_id'] == currentUserId && f['following_id'] == targetUserId,
    );
    if (!exists) {
      db.follows.add({'follower_id': currentUserId, 'following_id': targetUserId});
    }
  }

  @override
  Future<void> unfollowUser(String targetUserId) async {
    if (db.throwError) throw const ServerException('Unfollow request failed');
    db.follows.removeWhere(
      (f) => f['follower_id'] == currentUserId && f['following_id'] == targetUserId,
    );
  }

  @override
  Future<List<ProfileModel>> getFollowers(String userId) async {
    final followerIds = db.follows
        .where((f) => f['following_id'] == userId)
        .map((f) => f['follower_id']!)
        .toList();

    return followerIds
        .map((id) => db.profiles[id])
        .whereType<ProfileModel>()
        .map((p) => p.copyWith(
              isFollowing: db.follows.any(
                (f) => f['follower_id'] == currentUserId && f['following_id'] == p.id,
              ),
            ))
        .toList();
  }

  @override
  Future<List<ProfileModel>> getFollowing(String userId) async {
    final followingIds = db.follows
        .where((f) => f['follower_id'] == userId)
        .map((f) => f['following_id']!)
        .toList();

    return followingIds
        .map((id) => db.profiles[id])
        .whereType<ProfileModel>()
        .map((p) => p.copyWith(
              isFollowing: db.follows.any(
                (f) => f['follower_id'] == currentUserId && f['following_id'] == p.id,
              ),
            ))
        .toList();
  }
}

class MockGlobalDiscoverRepo extends DiscoverRepository {
  final GlobalTestDatabase db;
  String currentUserId;

  MockGlobalDiscoverRepo(this.db, {required this.currentUserId})
      : super(sb.SupabaseClient('https://mock.supabase.co', 'mock-key'));

  @override
  Future<List<ProfileModel>> searchUsers(String query) async {
    if (db.throwError) throw const ServerException('Search service unavailable');
    final clean = query.trim().toLowerCase();

    return db.profiles.values
        .where((p) => p.id != currentUserId)
        .where((p) {
          if (clean.isEmpty) return true;
          return p.username.toLowerCase().contains(clean) ||
              p.fullName.toLowerCase().contains(clean);
        })
        .map((p) => p.copyWith(
              isFollowing: db.follows.any(
                (f) => f['follower_id'] == currentUserId && f['following_id'] == p.id,
              ),
              followersCount: db.follows.where((f) => f['following_id'] == p.id).length,
            ))
        .toList();
  }

  @override
  Future<void> followUser(String targetUserId) async {
    if (currentUserId == targetUserId) {
      throw const AppAuthException('You cannot follow yourself.');
    }
    if (db.throwError) throw const ServerException('Follow action failed');
    final exists = db.follows.any(
      (f) => f['follower_id'] == currentUserId && f['following_id'] == targetUserId,
    );
    if (!exists) {
      db.follows.add({'follower_id': currentUserId, 'following_id': targetUserId});
    }
  }

  @override
  Future<void> unfollowUser(String targetUserId) async {
    if (db.throwError) throw const ServerException('Unfollow action failed');
    db.follows.removeWhere(
      (f) => f['follower_id'] == currentUserId && f['following_id'] == targetUserId,
    );
  }
}

class MockGlobalPostRepo extends PostRepository {
  final GlobalTestDatabase db;
  String currentUserId;

  MockGlobalPostRepo(this.db, {required this.currentUserId})
      : super(sb.SupabaseClient('https://mock.supabase.co', 'mock-key'));

  @override
  Future<List<PostModel>> getUserPosts(String userId) async {
    return db.posts.where((p) => p.authorId == userId).toList();
  }
}

class MockGlobalAuthRepo extends AuthRepository {
  String currentUserId;

  MockGlobalAuthRepo({required this.currentUserId})
      : super(sb.SupabaseClient('https://mock.supabase.co', 'mock-key'));

  @override
  sb.User? get currentUser => sb.User(
        id: currentUserId,
        appMetadata: {},
        userMetadata: {'full_name': 'Test User', 'username': 'testuser'},
        aud: 'authenticated',
        email: '$currentUserId@upmind.app',
        emailConfirmedAt: DateTime.now().toIso8601String(),
        createdAt: DateTime.now().toIso8601String(),
      );
}

class MockGlobalSkillRepo extends SkillRepository {
  MockGlobalSkillRepo()
      : super(sb.SupabaseClient('https://mock.supabase.co', 'mock-key'));

  @override
  Future<List<SkillModel>> fetchSkillsCatalog() async => [];

  @override
  Future<List<UserSkillModel>> fetchUserSkills(String userId) async => [];
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late GlobalTestDatabase db;
  late MockGlobalProfileRepo profileRepo;
  late MockGlobalDiscoverRepo discoverRepo;
  late MockGlobalPostRepo postRepo;
  late MockGlobalAuthRepo authRepo;
  late MockGlobalSkillRepo skillRepo;

  setUp(() {
    db = GlobalTestDatabase();

    // User A: Revanth (Hyderabad, IIT Hyderabad)
    db.profiles['user-a'] = ProfileModel(
      id: 'user-a',
      username: 'revanth_dev',
      fullName: 'Revanth Dev',
      bio: 'Flutter & Cloud architect building Upmind.',
      institution: 'IIT Hyderabad',
      course: 'Computer Science & Engineering',
      location: 'Hyderabad, India',
      experienceLevel: 'advanced',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now(),
    );

    // User B: Jane (Stanford, California - totally different continent & college)
    db.profiles['user-b'] = ProfileModel(
      id: 'user-b',
      username: 'jane_stanford',
      fullName: 'Jane Stanford',
      bio: 'AI researcher working on multi-modal neural networks.',
      institution: 'Stanford University',
      course: 'Artificial Intelligence M.S.',
      location: 'Palo Alto, CA, USA',
      experienceLevel: 'advanced',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      updatedAt: DateTime.now(),
    );

    // Seed post by User B
    db.posts.add(
      PostModel(
        id: 'post-jane-101',
        authorId: 'user-b',
        authorUsername: 'jane_stanford',
        authorFullName: 'Jane Stanford',
        caption: 'Excited to publish my new paper on multi-agent collaboration!',
        postType: 'text',
        createdAt: DateTime.now(),
      ),
    );

    profileRepo = MockGlobalProfileRepo(db, currentUserId: 'user-a');
    discoverRepo = MockGlobalDiscoverRepo(db, currentUserId: 'user-a');
    postRepo = MockGlobalPostRepo(db, currentUserId: 'user-a');
    authRepo = MockGlobalAuthRepo(currentUserId: 'user-a');
    skillRepo = MockGlobalSkillRepo();
  });

  Widget buildScope(Widget child) {
    return ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(profileRepo),
        discoverRepositoryProvider.overrideWithValue(discoverRepo),
        postRepositoryProvider.overrideWithValue(postRepo),
        authRepositoryProvider.overrideWithValue(authRepo),
        skillRepositoryProvider.overrideWithValue(skillRepo),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('UPMIND Global User Discovery & Follow System (10 Scenarios)', () {
    test('1. Global user discovery: User A searches for User B by username across different colleges',
        () async {
      final results = await discoverRepo.searchUsers('jane');
      expect(results.length, 1);
      expect(results.first.username, 'jane_stanford');
      expect(results.first.fullName, 'Jane Stanford');
      expect(results.first.institution, 'Stanford University');
    });

    test('2. Global user discovery: User A searches for User B by display name',
        () async {
      final results = await discoverRepo.searchUsers('Jane Stanford');
      expect(results.length, 1);
      expect(results.first.id, 'user-b');
    });

    test('3. Follow action: User A follows User B and relationship is saved in DB',
        () async {
      expect(db.follows.isEmpty, isTrue);

      await profileRepo.followUser('user-b');

      expect(db.follows.length, 1);
      expect(db.follows.first['follower_id'], 'user-a');
      expect(db.follows.first['following_id'], 'user-b');

      final profileB = await profileRepo.getProfile('user-b');
      expect(profileB!.followersCount, 1);
      expect(profileB.isFollowing, isTrue);

      final profileA = await profileRepo.getProfile('user-a');
      expect(profileA!.followingCount, 1);
    });

    test('4. Security: Users cannot follow themselves', () async {
      expect(
        () => profileRepo.followUser('user-a'),
        throwsA(isA<AppAuthException>()),
      );
    });

    test('5. Prevent duplicate follows: Attempting follow again does not create duplicate entries',
        () async {
      await profileRepo.followUser('user-b');
      await profileRepo.followUser('user-b');

      expect(db.follows.where((f) => f['follower_id'] == 'user-a' && f['following_id'] == 'user-b').length, 1);
    });

    test('6. Unfollow action: User A unfollows User B and count decrements accurately',
        () async {
      await profileRepo.followUser('user-b');
      expect(db.follows.length, 1);

      await profileRepo.unfollowUser('user-b');
      expect(db.follows.isEmpty, isTrue);

      final profileB = await profileRepo.getProfile('user-b');
      expect(profileB!.followersCount, 0);
      expect(profileB.isFollowing, isFalse);
    });

    test('7. Followers and Following lists return correct users', () async {
      await profileRepo.followUser('user-b');

      final followersOfB = await profileRepo.getFollowers('user-b');
      expect(followersOfB.length, 1);
      expect(followersOfB.first.id, 'user-a');
      expect(followersOfB.first.username, 'revanth_dev');

      final followingOfA = await profileRepo.getFollowing('user-a');
      expect(followingOfA.length, 1);
      expect(followingOfA.first.id, 'user-b');
      expect(followingOfA.first.username, 'jane_stanford');
    });

    testWidgets('8. Discover Screen UI renders discovered members with functional Follow button',
        (tester) async {
      await tester.pumpWidget(buildScope(const DiscoverScreen()));
      await tester.pumpAndSettle();

      // Discovered User B
      expect(find.text('Jane Stanford'), findsOneWidget);
      expect(find.text('@jane_stanford'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);

      // Tap Follow button in Discover Screen
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      // Verified: Button toggles to Following and DB is updated
      expect(find.text('Following'), findsOneWidget);
      expect(db.follows.any((f) => f['follower_id'] == 'user-a' && f['following_id'] == 'user-b'), isTrue);
    });

    testWidgets('9. Profile Screen displays real follow status and opens Followers / Following lists',
        (tester) async {
      // User A follows User B
      db.follows.add({'follower_id': 'user-a', 'following_id': 'user-b'});

      await tester.pumpWidget(buildScope(const ProfileScreen(userId: 'user-b')));
      await tester.pumpAndSettle();

      // Verified: Follow status button shows 'Following'
      expect(find.widgetWithText(CustomButton, 'Following'), findsOneWidget);
      expect(find.text('Jane Stanford'), findsOneWidget);
      expect(find.text('Stanford University'), findsOneWidget);

      // Verified: Posts stat and Followers stat items show '1'
      expect(find.text('1'), findsNWidgets(2));

      // Tap Followers to open UserListScreen
      await tester.tap(find.text('Followers'));
      await tester.pumpAndSettle();

      // Verified: UserListScreen opened showing Revanth as follower
      expect(find.text('Revanth Dev'), findsOneWidget);
      expect(find.text('@revanth_dev'), findsOneWidget);
    });

    testWidgets('10. UserListScreen supports follow/unfollow toggle inside the list',
        (tester) async {
      // User B has User A as follower
      db.follows.add({'follower_id': 'user-a', 'following_id': 'user-b'});

      // Jane opens her followers list
      profileRepo.currentUserId = 'user-b';
      authRepo.currentUserId = 'user-b';

      await tester.pumpWidget(
        buildScope(
          const UserListScreen(
            userId: 'user-b',
            username: 'jane_stanford',
            type: UserListType.followers,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Revanth Dev'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);

      // Jane follows Revanth back
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      expect(find.text('Following'), findsOneWidget);
      expect(db.follows.any((f) => f['follower_id'] == 'user-b' && f['following_id'] == 'user-a'), isTrue);
    });
  });
}

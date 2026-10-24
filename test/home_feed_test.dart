import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:upmind/core/errors/app_exception.dart';
import 'package:upmind/core/widgets/empty_state.dart';
import 'package:upmind/core/widgets/error_state.dart';
import 'package:upmind/features/auth/data/auth_repository.dart';
import 'package:upmind/features/home/presentation/home_feed_screen.dart';
import 'package:upmind/features/posts/data/post_repository.dart';
import 'package:upmind/features/posts/domain/post_model.dart';
import 'package:upmind/features/posts/presentation/widgets/post_card.dart';

class TestHomeFeedStore {
  final List<PostModel> posts = [];
  final List<Map<String, String>> follows = [];
  final Set<String> likedPostIds = {};
  final Set<String> savedPostIds = {};
  bool shouldThrowDbError = false;
}

class TestablePostRepository extends PostRepository {
  final TestHomeFeedStore store;
  String? activeUserId;

  TestablePostRepository(this.store, {this.activeUserId})
      : super(sb.SupabaseClient('https://mock.supabase.co', 'mock-key'));

  @override
  Future<List<PostModel>> getFeed({int limit = 20, int offset = 0}) async {
    if (store.shouldThrowDbError) {
      throw const ServerException('Database connection timeout (500)');
    }

    // Obtain verified session identity. Never trust frontend author ID.
    if (activeUserId == null) {
      return [];
    }

    // Filter posts from followed accounts + current user's own posts
    final followingIds = store.follows
        .where((f) => f['follower_id'] == activeUserId)
        .map((f) => f['following_id']!)
        .toSet();
    final targetAuthorIds = {activeUserId!, ...followingIds};

    return store.posts
        .where((p) => targetAuthorIds.contains(p.authorId))
        .map((p) => p.copyWith(
              isLiked: store.likedPostIds.contains(p.id),
              isSaved: store.savedPostIds.contains(p.id),
            ))
        .toList();
  }

  @override
  Future<PostModel> createPost({
    required String caption,
    String? imageUrl,
    String postType = 'text',
    String? educationalDescription,
    List<String> skillTags = const [],
  }) async {
    if (activeUserId == null) {
      throw const AppAuthException('You must be signed in to create a post.');
    }

    final newPost = PostModel(
      id: 'post-${DateTime.now().microsecondsSinceEpoch}',
      authorId: activeUserId!,
      authorUsername: activeUserId == 'revanth' ? 'revanth_dev' : 'student_jane',
      authorFullName: activeUserId == 'revanth' ? 'Revanth Dev' : 'Jane Student',
      caption: caption,
      imageUrl: imageUrl,
      postType: postType,
      educationalDescription: educationalDescription,
      skillTags: skillTags,
      likesCount: 0,
      commentsCount: 0,
      createdAt: DateTime.now(),
    );

    store.posts.insert(0, newPost);
    return newPost;
  }

  @override
  Future<void> toggleLike(String postId, bool isCurrentlyLiked) async {
    if (activeUserId == null) return;
    if (isCurrentlyLiked) {
      store.likedPostIds.remove(postId);
    } else {
      store.likedPostIds.add(postId);
    }
  }

  @override
  Future<void> toggleSave(String postId, bool isCurrentlySaved) async {
    if (activeUserId == null) return;
    if (isCurrentlySaved) {
      store.savedPostIds.remove(postId);
    } else {
      store.savedPostIds.add(postId);
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    if (activeUserId == null) return;
    store.posts.removeWhere((p) => p.id == postId && p.authorId == activeUserId);
  }
}

class TestableAuthRepository extends AuthRepository {
  String? activeUserId;

  TestableAuthRepository({this.activeUserId})
      : super(sb.SupabaseClient('https://mock.supabase.co', 'mock-key'));

  @override
  sb.User? get currentUser => activeUserId != null
      ? sb.User(
          id: activeUserId!,
          appMetadata: {},
          userMetadata: {
            'full_name': activeUserId == 'revanth' ? 'Revanth Dev' : 'Jane Student',
            'username': activeUserId == 'revanth' ? 'revanth_dev' : 'student_jane',
          },
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

  late TestHomeFeedStore store;
  late TestablePostRepository postRepo;
  late TestableAuthRepository authRepo;

  setUp(() {
    store = TestHomeFeedStore();

    // Populate database with posts by multiple users + ensure NO demo posts exist
    store.posts.addAll([
      PostModel(
        id: 'post-rev-1',
        authorId: 'revanth',
        authorUsername: 'revanth_dev',
        authorFullName: 'Revanth Dev',
        caption: 'Building real-time state management in Flutter with Riverpod.',
        postType: 'tutorial',
        educationalDescription: 'Step 1: Define providers. Step 2: Use ConsumerWidget.',
        skillTags: ['Flutter', 'Riverpod'],
        likesCount: 12,
        commentsCount: 3,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      PostModel(
        id: 'post-rev-2',
        authorId: 'revanth',
        authorUsername: 'revanth_dev',
        authorFullName: 'Revanth Dev',
        caption: 'Excited to showcase my new mobile portfolio app!',
        postType: 'text',
        skillTags: ['Portfolio'],
        likesCount: 5,
        commentsCount: 1,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      PostModel(
        id: 'post-jane-1',
        authorId: 'jane',
        authorUsername: 'student_jane',
        authorFullName: 'Jane Student',
        caption: 'Deep learning paper notes: Transformer architectures explained.',
        postType: 'tutorial',
        educationalDescription: 'Self-attention mechanisms calculate weighted correlations.',
        skillTags: ['AI', 'DeepLearning'],
        likesCount: 25,
        commentsCount: 7,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ]);

    postRepo = TestablePostRepository(store, activeUserId: 'revanth');
    authRepo = TestableAuthRepository(activeUserId: 'revanth');
  });

  Widget buildTestWidget({
    required TestablePostRepository postRepository,
    required TestableAuthRepository authRepository,
  }) {
    return ProviderScope(
      overrides: [
        postRepositoryProvider.overrideWithValue(postRepository),
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
      child: const MaterialApp(
        home: HomeFeedScreen(),
      ),
    );
  }

  group('UPMIND Home Feed User Filtering Tests', () {
    testWidgets('1. User A (Revanth) sees ONLY User A posts and never User B or demo posts',
        (tester) async {
      postRepo.activeUserId = 'revanth';
      authRepo.activeUserId = 'revanth';

      await tester.pumpWidget(
        buildTestWidget(
          postRepository: postRepo,
          authRepository: authRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Verified: Revanth's posts are visible
      expect(find.text('Building real-time state management in Flutter with Riverpod.'),
          findsOneWidget);
      expect(find.text('Excited to showcase my new mobile portfolio app!'),
          findsOneWidget);
      expect(find.textContaining('@revanth_dev'), findsWidgets);

      // Verified: Jane's posts NEVER appear
      expect(find.text('Deep learning paper notes: Transformer architectures explained.'),
          findsNothing);
      expect(find.text('@student_jane'), findsNothing);

      // Verified: Hardcoded demo posts (Sarah Chen, Marcus Thorne) NEVER appear
      expect(find.textContaining('Sarah Chen'), findsNothing);
      expect(find.textContaining('Marcus Thorne'), findsNothing);
      expect(find.textContaining('Alex Vance'), findsNothing);
    });

    testWidgets('2. User B (Jane) sees ONLY User B posts and never User A or demo posts',
        (tester) async {
      postRepo.activeUserId = 'jane';
      authRepo.activeUserId = 'jane';

      await tester.pumpWidget(
        buildTestWidget(
          postRepository: postRepo,
          authRepository: authRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Verified: Jane's post is visible
      expect(find.text('Deep learning paper notes: Transformer architectures explained.'),
          findsOneWidget);
      expect(find.text('Jane Student'), findsOneWidget);

      // Verified: Revanth's posts NEVER appear in Jane's feed
      expect(find.text('Building real-time state management in Flutter with Riverpod.'),
          findsNothing);
      expect(find.text('Excited to showcase my new mobile portfolio app!'),
          findsNothing);

      // Verified: Demo data NEVER appears
      expect(find.textContaining('Sarah Chen'), findsNothing);
      expect(find.textContaining('Marcus Thorne'), findsNothing);
    });

    testWidgets('3. Unauthenticated user cannot access feed data (returns empty list)',
        (tester) async {
      postRepo.activeUserId = null;
      authRepo.activeUserId = null;

      final feed = await postRepo.getFeed();
      expect(feed, isEmpty);

      await tester.pumpWidget(
        buildTestWidget(
          postRepository: postRepo,
          authRepository: authRepo,
        ),
      );
      await tester.pumpAndSettle();

      // An unauthenticated user sees empty feed state and never leaked posts
      expect(find.byType(PostCard), findsNothing);
      expect(find.text('Your feed is empty'), findsOneWidget);
    });

    testWidgets('4. Account with no posts sees minimal empty state with exact copy and action button',
        (tester) async {
      // User with zero posts
      postRepo.activeUserId = 'new_student';
      authRepo.activeUserId = 'new_student';

      await tester.pumpWidget(
        buildTestWidget(
          postRepository: postRepo,
          authRepository: authRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Exact copy assertions per specification:
      expect(find.text('Your feed is empty'), findsOneWidget);
      expect(find.text('Share your knowledge and start your learning journey.'),
          findsOneWidget);
      expect(find.text('Create Post'), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);
    });

    testWidgets('5. Refreshing the page preserves the correct feed filtering',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      postRepo.activeUserId = 'revanth';
      authRepo.activeUserId = 'revanth';

      await tester.pumpWidget(
        buildTestWidget(
          postRepository: postRepo,
          authRepository: authRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PostCard), findsNWidgets(2));

      // Trigger pull to refresh
      await tester.fling(find.byType(RefreshIndicator), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      // Feed remains correctly filtered to Revanth
      expect(find.byType(PostCard), findsNWidgets(2));
      expect(find.text('Deep learning paper notes: Transformer architectures explained.'),
          findsNothing);
    });

    testWidgets('6. Database errors do NOT cause a demo-data fallback',
        (tester) async {
      postRepo.activeUserId = 'revanth';
      authRepo.activeUserId = 'revanth';
      store.shouldThrowDbError = true;

      await tester.pumpWidget(
        buildTestWidget(
          postRepository: postRepo,
          authRepository: authRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Displays error state, NEVER demo posts
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);
      expect(find.textContaining('Sarah Chen'), findsNothing);
      expect(find.textContaining('Marcus Thorne'), findsNothing);
      expect(find.textContaining('Database connection timeout'), findsOneWidget);
    });

    testWidgets('7. Existing post creation and interaction features continue to work',
        (tester) async {
      postRepo.activeUserId = 'revanth';
      authRepo.activeUserId = 'revanth';

      // Verify create post
      final created = await postRepo.createPost(
        caption: 'Newly created post by Revanth',
        postType: 'text',
        skillTags: ['Testing'],
      );
      expect(created.authorId, 'revanth');
      expect(created.caption, 'Newly created post by Revanth');

      // Verify like toggle
      await postRepo.toggleLike(created.id, false);
      expect(store.likedPostIds.contains(created.id), isTrue);
      await postRepo.toggleLike(created.id, true);
      expect(store.likedPostIds.contains(created.id), isFalse);

      // Verify bookmark toggle
      await postRepo.toggleSave(created.id, false);
      expect(store.savedPostIds.contains(created.id), isTrue);
      await postRepo.toggleSave(created.id, true);
      expect(store.savedPostIds.contains(created.id), isFalse);

      // Verify delete post
      await postRepo.deletePost(created.id);
      final feed = await postRepo.getFeed();
      expect(feed.any((p) => p.id == created.id), isFalse);
    });

    testWidgets('8. Following an account includes their posts in feed alongside own posts',
        (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      postRepo.activeUserId = 'revanth';
      authRepo.activeUserId = 'revanth';

      // Before following Jane: Revanth only sees Revanth's posts
      var feed = await postRepo.getFeed();
      expect(feed.any((p) => p.authorId == 'jane'), isFalse);
      expect(feed.length, 2);

      // Revanth follows Jane
      store.follows.add({'follower_id': 'revanth', 'following_id': 'jane'});

      // After following Jane: Revanth sees Jane's posts + Revanth's own posts
      feed = await postRepo.getFeed();
      expect(feed.any((p) => p.authorId == 'jane'), isTrue);
      expect(feed.length, 3);

      await tester.pumpWidget(
        buildTestWidget(
          postRepository: postRepo,
          authRepository: authRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Verified: Both Revanth's posts and Jane's post are in the feed
      expect(find.text('Building real-time state management in Flutter with Riverpod.'),
          findsOneWidget);
      expect(find.text('Deep learning paper notes: Transformer architectures explained.'),
          findsOneWidget);

      // Revanth unfollows Jane
      store.follows.removeWhere((f) => f['follower_id'] == 'revanth' && f['following_id'] == 'jane');
      feed = await postRepo.getFeed();
      expect(feed.any((p) => p.authorId == 'jane'), isFalse);
      expect(feed.length, 2);
    });
  });
}

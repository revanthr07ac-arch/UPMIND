import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/comment_model.dart';
import '../domain/post_model.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return PostRepository(supabase);
});

class PostRepository {
  final SupabaseClient _supabase;

  PostRepository(this._supabase);

  // Fallback demo posts when unconfigured
  static final List<PostModel> _demoPosts = [
    PostModel(
      id: 'demo-post-1',
      authorId: 'user-2',
      authorUsername: 'sarah_design',
      authorFullName: 'Sarah Chen',
      authorAvatarUrl: null,
      caption: '🚀 Master the 8pt Grid System in UI Design! Consistent rhythm and spacing makes your Flutter & Web interfaces feel world-class. Here is a quick tutorial breakdown.',
      postType: 'tutorial',
      educationalDescription: 'Step 1: Set base unit = 8px.\nStep 2: Use 8, 16, 24, 32, 48, 64 for paddings.\nStep 3: Line heights should snap to multiples of 4 or 8.',
      skillTags: ['UI/UX Design', 'Design Systems'],
      likesCount: 38,
      commentsCount: 6,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    PostModel(
      id: 'demo-post-2',
      authorId: 'user-3',
      authorUsername: 'marcus_code',
      authorFullName: 'Marcus Thorne',
      authorAvatarUrl: null,
      caption: 'Just published my open-source Riverpod 2.0 template with GoRouter and clean feature-first architecture! Check out the state caching tips.',
      postType: 'text',
      skillTags: ['Flutter & Dart', 'State Management'],
      likesCount: 52,
      commentsCount: 14,
      createdAt: DateTime.now().subtract(const Duration(hours: 7)),
    ),
  ];

  Future<List<PostModel>> getFeed({int limit = 15, int offset = 0}) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        return _demoPosts;
      }

      final currentUid = _supabase.auth.currentUser?.id;

      final data = await _supabase
          .from('posts')
          .select('*, profiles(username, full_name, avatar_url)')
          .eq('visibility', 'public')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> list = data as List<dynamic>;
      if (list.isEmpty) return [];

      final postIds = list.map((p) => p['id'] as String).toList();

      Set<String> likedPostIds = {};
      Set<String> savedPostIds = {};

      if (currentUid != null) {
        final likesData = await _supabase
            .from('likes')
            .select('post_id')
            .eq('user_id', currentUid)
            .filter('post_id', 'in', '(${postIds.join(",")})');

        likedPostIds = (likesData as List<dynamic>)
            .map((l) => l['post_id'] as String)
            .toSet();

        final savesData = await _supabase
            .from('saved_posts')
            .select('post_id')
            .eq('user_id', currentUid)
            .filter('post_id', 'in', '(${postIds.join(",")})');

        savedPostIds = (savesData as List<dynamic>)
            .map((s) => s['post_id'] as String)
            .toSet();
      }

      return list.map((json) {
        final id = json['id'] as String;
        return PostModel.fromJson(
          json as Map<String, dynamic>,
          isLiked: likedPostIds.contains(id),
          isSaved: savedPostIds.contains(id),
        );
      }).toList();
    } catch (e) {
      if (!AppConfig.isSupabaseConfigured) return _demoPosts;
      throw ServerException('Failed to load feed: ${e.toString()}');
    }
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return [];

      final data = await _supabase
          .from('posts')
          .select('*, profiles(username, full_name, avatar_url)')
          .eq('author_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> list = data as List<dynamic>;
      return list
          .map((json) => PostModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<PostModel> createPost({
    required String caption,
    String? imageUrl,
    String postType = 'text',
    String? educationalDescription,
    List<String> skillTags = const [],
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null && AppConfig.isSupabaseConfigured) {
        throw const AppAuthException('You must be logged in to create a post');
      }

      if (!AppConfig.isSupabaseConfigured) {
        final newPost = PostModel(
          id: 'demo-new-${DateTime.now().millisecondsSinceEpoch}',
          authorId: 'demo-user-id',
          authorUsername: 'demouser',
          authorFullName: 'Demo User',
          caption: caption,
          imageUrl: imageUrl,
          postType: postType,
          educationalDescription: educationalDescription,
          skillTags: skillTags,
          createdAt: DateTime.now(),
        );
        _demoPosts.insert(0, newPost);
        return newPost;
      }

      final inserted = await _supabase
          .from('posts')
          .insert({
            'author_id': user!.id,
            'caption': caption.trim(),
            'image_url': imageUrl,
            'post_type': postType,
            'educational_description': educationalDescription?.trim(),
            'skill_tags': skillTags,
            'visibility': 'public',
          })
          .select('*, profiles(username, full_name, avatar_url)')
          .single();

      return PostModel.fromJson(inserted as Map<String, dynamic>);
    } catch (e) {
      throw ServerException('Failed to create post: ${e.toString()}');
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        _demoPosts.removeWhere((p) => p.id == postId);
        return;
      }

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('posts').delete().match({
        'id': postId,
        'author_id': user.id,
      });
    } catch (e) {
      throw ServerException('Failed to delete post: ${e.toString()}');
    }
  }

  Future<void> toggleLike(String postId, bool isCurrentlyLiked) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null && AppConfig.isSupabaseConfigured) return;
      if (!AppConfig.isSupabaseConfigured) return;

      if (isCurrentlyLiked) {
        await _supabase.from('likes').delete().match({
          'user_id': user!.id,
          'post_id': postId,
        });
      } else {
        await _supabase.from('likes').insert({
          'user_id': user!.id,
          'post_id': postId,
        });
      }
    } catch (e) {
      throw ServerException('Failed to toggle like: ${e.toString()}');
    }
  }

  Future<void> toggleSave(String postId, bool isCurrentlySaved) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null && AppConfig.isSupabaseConfigured) return;
      if (!AppConfig.isSupabaseConfigured) return;

      if (isCurrentlySaved) {
        await _supabase.from('saved_posts').delete().match({
          'user_id': user!.id,
          'post_id': postId,
        });
      } else {
        await _supabase.from('saved_posts').insert({
          'user_id': user!.id,
          'post_id': postId,
        });
      }
    } catch (e) {
      throw ServerException('Failed to toggle bookmark: ${e.toString()}');
    }
  }

  Future<List<CommentModel>> getComments(String postId) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return [];

      final data = await _supabase
          .from('comments')
          .select('*, profiles(username, full_name, avatar_url)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return (data as List<dynamic>)
          .map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<CommentModel> addComment(String postId, String content) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null && AppConfig.isSupabaseConfigured) {
        throw const AppAuthException('You must be logged in to comment');
      }

      if (!AppConfig.isSupabaseConfigured) {
        return CommentModel(
          id: 'demo-comment-${DateTime.now().millisecondsSinceEpoch}',
          postId: postId,
          authorId: 'demo-user-id',
          authorUsername: 'demouser',
          authorFullName: 'Demo User',
          content: content,
          createdAt: DateTime.now(),
        );
      }

      final inserted = await _supabase
          .from('comments')
          .insert({
            'post_id': postId,
            'author_id': user!.id,
            'content': content.trim(),
          })
          .select('*, profiles(username, full_name, avatar_url)')
          .single();

      return CommentModel.fromJson(inserted as Map<String, dynamic>);
    } catch (e) {
      throw ServerException('Failed to add comment: ${e.toString()}');
    }
  }

  Future<String> uploadPostImage(File file) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null && AppConfig.isSupabaseConfigured) return '';
      if (!AppConfig.isSupabaseConfigured) return '';

      final ext = file.path.split('.').last.toLowerCase();
      final path =
          '${user!.id}/post_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage
          .from('post_images')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));

      return _supabase.storage.from('post_images').getPublicUrl(path);
    } catch (e) {
      throw ServerException('Failed to upload post image: ${e.toString()}');
    }
  }

  Future<void> reportPost(String postId, String reason, String? details) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null && AppConfig.isSupabaseConfigured) return;
      if (!AppConfig.isSupabaseConfigured) return;

      await _supabase.from('reports').insert({
        'reporter_id': user!.id,
        'reported_post_id': postId,
        'reason': reason,
        'details': details,
      });
    } catch (e) {
      throw ServerException('Failed to submit report: ${e.toString()}');
    }
  }
}

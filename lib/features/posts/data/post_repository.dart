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

  /// Retrieves the authenticated user's global social feed.
  /// Shows posts from the authenticated user's followed accounts,
  /// with the logged-in user's own posts included.
  /// Never returns hardcoded demo data, Sarah Chen, or Marcus Thorne posts.
  Future<List<PostModel>> getFeed({int limit = 20, int offset = 0}) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        return [];
      }

      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return [];
      }
      final currentUid = currentUser.id;

      // 1. Fetch IDs of accounts the current user follows
      final followingRes = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUid);

      final List<String> targetAuthorIds = [currentUid];
      for (final item in followingRes) {
        final fid = item['following_id']?.toString();
        if (fid != null && fid.isNotEmpty && !targetAuthorIds.contains(fid)) {
          targetAuthorIds.add(fid);
        }
      }

      // 2. Query database for posts from followed accounts + own posts
      final data = await _supabase
          .from('posts')
          .select('*, profiles(username, full_name, avatar_url)')
          .filter('author_id', 'in', '(${targetAuthorIds.join(",")})')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> list = data as List<dynamic>;
      if (list.isEmpty) return [];

      final postIds = list.map((p) => p['id'] as String).toList();

      Set<String> likedPostIds = {};
      Set<String> savedPostIds = {};

      try {
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
      } catch (_) {
        // Continue if engagement subqueries fail
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
      throw ServerException('Failed to load feed: ${e.toString()}');
    }
  }

  /// Retrieves posts authored by a specific user ID.
  Future<List<PostModel>> getUserPosts(String userId) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return [];

      final currentUid = _supabase.auth.currentUser?.id;

      final data = await _supabase
          .from('posts')
          .select('*, profiles(username, full_name, avatar_url)')
          .eq('author_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> list = data as List<dynamic>;
      if (list.isEmpty) return [];

      Set<String> likedPostIds = {};
      Set<String> savedPostIds = {};

      if (currentUid != null) {
        final postIds = list.map((p) => p['id'] as String).toList();
        try {
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
        } catch (_) {}
      }

      return list
          .map(
            (json) => PostModel.fromJson(
              json as Map<String, dynamic>,
              isLiked: likedPostIds.contains(json['id']),
              isSaved: savedPostIds.contains(json['id']),
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Creates a new post authored by the authenticated user.
  Future<PostModel> createPost({
    required String caption,
    String? imageUrl,
    String postType = 'text',
    String? educationalDescription,
    List<String> skillTags = const [],
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw const AppAuthException('You must be signed in to create a post.');
      }
      if (!AppConfig.isSupabaseConfigured) {
        throw const AppAuthException('Supabase is not configured.');
      }

      final inserted = await _supabase
          .from('posts')
          .insert({
            'author_id': user.id,
            'caption': caption.trim(),
            'image_url': imageUrl,
            'post_type': postType,
            'educational_description': educationalDescription?.trim(),
            'skill_tags': skillTags,
            'visibility': 'public',
          })
          .select('*, profiles(username, full_name, avatar_url)')
          .single();

      return PostModel.fromJson(inserted);
    } on AppAuthException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to create post: ${e.toString()}');
    }
  }

  /// Deletes a post owned by the authenticated user.
  Future<void> deletePost(String postId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      if (!AppConfig.isSupabaseConfigured) return;

      await _supabase.from('posts').delete().match({
        'id': postId,
        'author_id': user.id,
      });
    } catch (e) {
      throw ServerException('Failed to delete post: ${e.toString()}');
    }
  }

  /// Toggles like status on a post.
  Future<void> toggleLike(String postId, bool isCurrentlyLiked) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      if (!AppConfig.isSupabaseConfigured) return;

      if (isCurrentlyLiked) {
        await _supabase.from('likes').delete().match({
          'user_id': user.id,
          'post_id': postId,
        });
      } else {
        await _supabase.from('likes').insert({
          'user_id': user.id,
          'post_id': postId,
        });
      }
    } catch (e) {
      throw ServerException('Failed to toggle like: ${e.toString()}');
    }
  }

  /// Toggles saved / bookmark status on a post.
  Future<void> toggleSave(String postId, bool isCurrentlySaved) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      if (!AppConfig.isSupabaseConfigured) return;

      if (isCurrentlySaved) {
        await _supabase.from('saved_posts').delete().match({
          'user_id': user.id,
          'post_id': postId,
        });
      } else {
        await _supabase.from('saved_posts').insert({
          'user_id': user.id,
          'post_id': postId,
        });
      }
    } catch (e) {
      throw ServerException('Failed to toggle bookmark: ${e.toString()}');
    }
  }

  /// Fetches comments for a specific post.
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

  /// Adds a comment to a post from the authenticated user.
  Future<CommentModel> addComment(String postId, String content) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw const AppAuthException('You must be signed in to comment.');
      }
      if (!AppConfig.isSupabaseConfigured) {
        throw const AppAuthException('Supabase is not configured.');
      }

      final inserted = await _supabase
          .from('comments')
          .insert({
            'post_id': postId,
            'author_id': user.id,
            'content': content.trim(),
          })
          .select('*, profiles(username, full_name, avatar_url)')
          .single();

      return CommentModel.fromJson(inserted);
    } on AppAuthException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to add comment: ${e.toString()}');
    }
  }

  /// Uploads a post image to Supabase Storage.
  Future<String> uploadPostImage(File file) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return '';
      if (!AppConfig.isSupabaseConfigured) return '';

      final ext = file.path.split('.').last.toLowerCase();
      final path =
          '${user.id}/post_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage.from('post_images').upload(path, file);
      return _supabase.storage.from('post_images').getPublicUrl(path);
    } catch (e) {
      throw ServerException('Image upload failed: ${e.toString()}');
    }
  }

  /// Reports a post for moderation review.
  Future<void> reportPost(String postId, String reason, String? notes) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || !AppConfig.isSupabaseConfigured) return;

      await _supabase.from('reports').insert({
        'reporter_id': user.id,
        'reported_post_id': postId,
        'reason': reason,
        'details': notes,
      });
    } catch (e) {
      throw ServerException('Failed to report post: ${e.toString()}');
    }
  }
}

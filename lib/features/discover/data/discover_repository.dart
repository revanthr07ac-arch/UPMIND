import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/supabase_client.dart';
import '../../posts/domain/post_model.dart';
import '../../profiles/domain/profile_model.dart';

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return DiscoverRepository(supabase);
});

class DiscoverRepository {
  final SupabaseClient _supabase;

  DiscoverRepository(this._supabase);

  /// Searches for registered users across the entire platform globally.
  /// When [query] is empty, returns recently joined and active members.
  /// When [query] is provided, matches against username or full name.
  /// Accurately populates [isFollowing] status relative to the authenticated user.
  Future<List<ProfileModel>> searchUsers(String query) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        return [];
      }

      final currentUid = _supabase.auth.currentUser?.id;
      final clean = query.trim().replaceAll(RegExp(r'[,()"\\]'), '');

      List<dynamic> rawList;
      if (clean.isEmpty) {
        // Global discovery: show registered community members
        final res = await _supabase
            .from('profiles')
            .select()
            .order('created_at', ascending: false)
            .limit(30);
        rawList = res as List<dynamic>;
      } else {
        final res = await _supabase
            .from('profiles')
            .select()
            .or('username.ilike.%$clean%,full_name.ilike.%$clean%')
            .limit(30);
        rawList = res as List<dynamic>;
      }

      if (rawList.isEmpty) return [];

      final candidates = rawList
          .map((json) => ProfileModel.fromJson(json as Map<String, dynamic>))
          .where((p) => p.id != currentUid)
          .toList();

      if (candidates.isEmpty) return [];

      // Batch check which discovered users are followed by current user
      Set<String> followedIds = {};
      if (currentUid != null) {
        try {
          final targetIds = candidates.map((c) => c.id).toList();
          final followsRes = await _supabase
              .from('follows')
              .select('following_id')
              .eq('follower_id', currentUid)
              .filter('following_id', 'in', '(${targetIds.join(",")})');

          followedIds = (followsRes as List<dynamic>)
              .map((row) => row['following_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
        } catch (_) {
          // If batch check fails, continue with default false
        }
      }

      return candidates.map((p) {
        return p.copyWith(isFollowing: followedIds.contains(p.id));
      }).toList();
    } catch (e) {
      throw ServerException('Failed to search users: ${e.toString()}');
    }
  }

  /// Follows another user from the discovery screen.
  Future<void> followUser(String targetUserId) async {
    try {
      final currentUid = _supabase.auth.currentUser?.id;
      if (currentUid == null) {
        throw const AppAuthException('You must be signed in to follow users.');
      }
      if (currentUid == targetUserId) {
        throw const AppAuthException('You cannot follow yourself.');
      }
      if (!AppConfig.isSupabaseConfigured) return;

      await _supabase.from('follows').upsert({
        'follower_id': currentUid,
        'following_id': targetUserId,
      }, onConflict: 'follower_id,following_id');
    } on AppAuthException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to follow user: ${e.toString()}');
    }
  }

  /// Unfollows another user from the discovery screen.
  Future<void> unfollowUser(String targetUserId) async {
    try {
      final currentUid = _supabase.auth.currentUser?.id;
      if (currentUid == null) return;
      if (!AppConfig.isSupabaseConfigured) return;

      await _supabase.from('follows').delete().match({
        'follower_id': currentUid,
        'following_id': targetUserId,
      });
    } catch (e) {
      throw ServerException('Failed to unfollow user: ${e.toString()}');
    }
  }

  /// Retrieves teachers who registered teaching intent for a specific skill.
  Future<List<ProfileModel>> getTeachersForSkill(String skillId) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return [];

      final currentUid = _supabase.auth.currentUser?.id;

      final data = await _supabase
          .from('user_skills')
          .select('*, profiles(*)')
          .eq('skill_id', skillId)
          .eq('intent', 'teaching')
          .limit(25);

      final list = (data as List<dynamic>);
      return list
          .map((item) {
            final profileJson = item['profiles'] as Map<String, dynamic>?;
            if (profileJson == null) return null;
            return ProfileModel.fromJson(profileJson);
          })
          .whereType<ProfileModel>()
          .where((p) => p.id != currentUid)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Retrieves educational posts for a skill tag.
  Future<List<PostModel>> getEducationalPostsBySkill(String skillTag) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return [];

      final data = await _supabase
          .from('posts')
          .select('*, profiles(username, full_name, avatar_url)')
          .contains('skill_tags', [skillTag])
          .order('likes_count', ascending: false)
          .limit(20);

      return (data as List<dynamic>)
          .map((json) => PostModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

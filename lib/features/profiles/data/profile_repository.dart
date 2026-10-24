import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ProfileRepository(supabase);
});

final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) {
    return null;
  }
  return await repo.getProfile(user.id);
});

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository(this._supabase);

  /// Retrieves a real user's profile with computed social statistics.
  /// Never returns hardcoded demo data. Returns null if profile is not found.
  Future<ProfileModel?> getProfile(String userId) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        return null;
      }

      final currentUid = _supabase.auth.currentUser?.id;

      // 1. Fetch base profile record
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) {
        // If current authenticated user profile doesn't exist yet, initialize it idempotently
        if (currentUid != null && currentUid == userId) {
          final currentUser = _supabase.auth.currentUser;
          if (currentUser != null) {
            return await ensureProfileExists(currentUser);
          }
        }
        return null;
      }

      // 2. Compute real social counts directly from database relationships
      int realFollowersCount = data['followers_count'] as int? ?? 0;
      int realFollowingCount = data['following_count'] as int? ?? 0;
      int realPostCount = 0;

      try {
        final followersRes = await _supabase
            .from('follows')
            .select('id')
            .eq('following_id', userId);
        final List<dynamic> followersList = followersRes as List<dynamic>;
        realFollowersCount = followersList.length;

        final followingRes = await _supabase
            .from('follows')
            .select('id')
            .eq('follower_id', userId);
        final List<dynamic> followingList = followingRes as List<dynamic>;
        realFollowingCount = followingList.length;

        final postsRes = await _supabase
            .from('posts')
            .select('id')
            .eq('author_id', userId);
        final List<dynamic> postsList = postsRes as List<dynamic>;
        realPostCount = postsList.length;
      } catch (_) {
        // Fallback to cached trigger counters if subqueries are restricted
      }

      // 3. Check follow relationship
      bool isFollowing = false;
      if (currentUid != null && currentUid != userId) {
        final followRes = await _supabase
            .from('follows')
            .select('id')
            .eq('follower_id', currentUid)
            .eq('following_id', userId)
            .maybeSingle();
        isFollowing = followRes != null;
      }

      return ProfileModel.fromJson(
        data,
        isFollowing: isFollowing,
        postCount: realPostCount,
        followersCount: realFollowersCount,
        followingCount: realFollowingCount,
      );
    } catch (e) {
      throw ServerException('Failed to load profile: ${e.toString()}');
    }
  }

  /// Ensures a user has a personalized profile initialized from registration data.
  /// This operation is completely idempotent and safe against retries.
  Future<ProfileModel?> ensureProfileExists(User user) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return null;

      final existing = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (existing != null) {
        return ProfileModel.fromJson(existing);
      }

      final meta = user.userMetadata ?? {};
      final rawUsername = meta['username']?.toString() ?? '';
      final rawFullName = meta['full_name']?.toString() ?? '';

      final cleanUsername = rawUsername.isNotEmpty
          ? rawUsername.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
          : 'user_${user.id.replaceAll('-', '').substring(0, 8)}';

      final cleanFullName = rawFullName.isNotEmpty ? rawFullName : 'UPMIND Member';

      await _supabase.from('profiles').upsert({
        'id': user.id,
        'username': cleanUsername,
        'full_name': cleanFullName,
        'followers_count': 0,
        'following_count': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'id');

      final created = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      return created != null ? ProfileModel.fromJson(created) : null;
    } catch (e) {
      throw ServerException('Failed to initialize profile: ${e.toString()}');
    }
  }

  /// Checks if a username is unique and not claimed by another user.
  Future<bool> checkUsernameAvailable(
    String username, {
    String? excludeUserId,
  }) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return true;
      final clean = username.trim().toLowerCase();

      var query = _supabase
          .from('profiles')
          .select('id')
          .eq('username', clean);

      if (excludeUserId != null) {
        query = query.neq('id', excludeUserId);
      }

      final result = await query.maybeSingle();
      return result == null;
    } catch (e) {
      return false;
    }
  }

  /// Updates the authenticated user's real profile information.
  /// Server and client ownership is strictly verified.
  Future<void> updateProfile(ProfileModel profile) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return;

      final currentUid = _supabase.auth.currentUser?.id;
      if (currentUid == null || currentUid != profile.id) {
        throw const AppAuthException(
          'Unauthorized: You can only edit your own profile.',
          code: 'UNAUTHORIZED',
        );
      }

      // Check username uniqueness if changed
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

      await _supabase
          .from('profiles')
          .update({
            'full_name': profile.fullName.trim(),
            'username': profile.username.trim().toLowerCase(),
            'bio': profile.bio?.trim(),
            'location': profile.location?.trim(),
            'institution': profile.institution?.trim(),
            'course': profile.course?.trim(),
            'website_url': profile.websiteUrl?.trim(),
            'experience_level': profile.experienceLevel,
            'interests': profile.interests,
            'portfolio_links': profile.portfolioLinks,
            if (profile.avatarUrl != null) 'avatar_url': profile.avatarUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', profile.id);
    } on AppAuthException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to update profile: ${e.toString()}');
    }
  }

  /// Uploads an avatar image to Supabase Storage for the user.
  Future<String> uploadAvatar(String userId, File file) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return '';

      final currentUid = _supabase.auth.currentUser?.id;
      if (currentUid == null || currentUid != userId) {
        throw const AppAuthException(
          'Unauthorized: Cannot upload avatar for another user.',
          code: 'UNAUTHORIZED',
        );
      }

      final ext = file.path.split('.').last.toLowerCase();
      final path =
          '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage
          .from('avatars')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);

      await _supabase
          .from('profiles')
          .update({
            'avatar_url': publicUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);

      return publicUrl;
    } on AppAuthException {
      rethrow;
    } catch (e) {
      throw ServerException('Avatar upload failed: ${e.toString()}');
    }
  }

  /// Follows another user. Prevents self-following.
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

  /// Unfollows another user.
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

  /// Blocks another user.
  Future<void> blockUser(String targetUserId) async {
    try {
      final currentUid = _supabase.auth.currentUser?.id;
      if (currentUid == null || currentUid == targetUserId) return;
      if (!AppConfig.isSupabaseConfigured) return;

      await _supabase.from('blocks').upsert({
        'blocker_id': currentUid,
        'blocked_id': targetUserId,
      }, onConflict: 'blocker_id,blocked_id');
    } catch (e) {
      throw ServerException('Failed to block user: ${e.toString()}');
    }
  }

  /// Unblocks another user.
  Future<void> unblockUser(String targetUserId) async {
    try {
      final currentUid = _supabase.auth.currentUser?.id;
      if (currentUid == null) return;
      if (!AppConfig.isSupabaseConfigured) return;

      await _supabase.from('blocks').delete().match({
        'blocker_id': currentUid,
        'blocked_id': targetUserId,
      });
    } catch (e) {
      throw ServerException('Failed to unblock user: ${e.toString()}');
    }
  }

  /// Retrieves the list of profiles that follow [userId].
  Future<List<ProfileModel>> getFollowers(String userId) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return [];

      final currentUid = _supabase.auth.currentUser?.id;

      final followsData = await _supabase
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> list = followsData as List<dynamic>;
      if (list.isEmpty) return [];

      final followerIds = list
          .map((row) => row['follower_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (followerIds.isEmpty) return [];

      final profilesData = await _supabase
          .from('profiles')
          .select()
          .filter('id', 'in', '(${followerIds.join(",")})');

      final List<dynamic> profilesList = profilesData as List<dynamic>;
      final profileMap = {
        for (final json in profilesList)
          (json as Map<String, dynamic>)['id'] as String: ProfileModel.fromJson(json),
      };

      Set<String> myFollowing = {};
      if (currentUid != null) {
        try {
          final myFollowsData = await _supabase
              .from('follows')
              .select('following_id')
              .eq('follower_id', currentUid)
              .filter('following_id', 'in', '(${followerIds.join(",")})');
          myFollowing = (myFollowsData as List<dynamic>)
              .map((row) => row['following_id']?.toString() ?? '')
              .toSet();
        } catch (_) {}
      }

      final result = <ProfileModel>[];
      for (final fid in followerIds) {
        final p = profileMap[fid];
        if (p != null) {
          result.add(p.copyWith(isFollowing: myFollowing.contains(p.id)));
        }
      }
      return result;
    } catch (e) {
      throw ServerException('Failed to load followers: ${e.toString()}');
    }
  }

  /// Retrieves the list of profiles that [userId] is following.
  Future<List<ProfileModel>> getFollowing(String userId) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return [];

      final currentUid = _supabase.auth.currentUser?.id;

      final followsData = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> list = followsData as List<dynamic>;
      if (list.isEmpty) return [];

      final followingIds = list
          .map((row) => row['following_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      if (followingIds.isEmpty) return [];

      final profilesData = await _supabase
          .from('profiles')
          .select()
          .filter('id', 'in', '(${followingIds.join(",")})');

      final List<dynamic> profilesList = profilesData as List<dynamic>;
      final profileMap = {
        for (final json in profilesList)
          (json as Map<String, dynamic>)['id'] as String: ProfileModel.fromJson(json),
      };

      Set<String> myFollowing = {};
      if (currentUid != null) {
        try {
          final myFollowsData = await _supabase
              .from('follows')
              .select('following_id')
              .eq('follower_id', currentUid)
              .filter('following_id', 'in', '(${followingIds.join(",")})');
          myFollowing = (myFollowsData as List<dynamic>)
              .map((row) => row['following_id']?.toString() ?? '')
              .toSet();
        } catch (_) {}
      }

      final result = <ProfileModel>[];
      for (final fid in followingIds) {
        final p = profileMap[fid];
        if (p != null) {
          result.add(p.copyWith(isFollowing: myFollowing.contains(p.id)));
        }
      }
      return result;
    } catch (e) {
      throw ServerException('Failed to load following accounts: ${e.toString()}');
    }
  }
}

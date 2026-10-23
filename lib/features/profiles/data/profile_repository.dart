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
    if (!AppConfig.isSupabaseConfigured) {
      return ProfileRepository.demoProfile;
    }
    return null;
  }
  return await repo.getProfile(user.id);
});

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository(this._supabase);

  static final ProfileModel demoProfile = ProfileModel(
    id: 'demo-user-id',
    username: 'alex_creator',
    fullName: 'Alex Vance',
    avatarUrl: null,
    bio: 'Mobile architect & Flutter enthusiast. Passionate about teaching UI craft.',
    location: 'San Francisco, CA',
    interests: ['Mobile Dev', 'UI Design', 'AI Engineering'],
    experienceLevel: 'advanced',
    followersCount: 128,
    followingCount: 42,
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
    updatedAt: DateTime.now(),
  );

  Future<ProfileModel?> getProfile(String userId) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        return demoProfile;
      }

      final currentUid = _supabase.auth.currentUser?.id;

      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;

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

      return ProfileModel.fromJson(data, isFollowing: isFollowing);
    } catch (e) {
      if (!AppConfig.isSupabaseConfigured) return demoProfile;
      throw ServerException('Failed to load profile: ${e.toString()}');
    }
  }

  Future<void> updateProfile(ProfileModel profile) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return;

      await _supabase
          .from('profiles')
          .update({
            'full_name': profile.fullName.trim(),
            'bio': profile.bio?.trim(),
            'location': profile.location?.trim(),
            'experience_level': profile.experienceLevel,
            'interests': profile.interests,
            'portfolio_links': profile.portfolioLinks,
            if (profile.avatarUrl != null) 'avatar_url': profile.avatarUrl,
          })
          .eq('id', profile.id);
    } catch (e) {
      throw ServerException('Failed to update profile: ${e.toString()}');
    }
  }

  Future<String> uploadAvatar(String userId, File file) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return '';

      final ext = file.path.split('.').last.toLowerCase();
      final path =
          '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage
          .from('avatars')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));

      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);

      await _supabase
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', userId);

      return publicUrl;
    } catch (e) {
      throw ServerException('Avatar upload failed: ${e.toString()}');
    }
  }

  Future<void> followUser(String targetUserId) async {
    try {
      final currentUid = _supabase.auth.currentUser?.id;
      if (currentUid == null || currentUid == targetUserId) return;
      if (!AppConfig.isSupabaseConfigured) return;

      await _supabase.from('follows').insert({
        'follower_id': currentUid,
        'following_id': targetUserId,
      });
    } catch (e) {
      throw ServerException('Failed to follow user: ${e.toString()}');
    }
  }

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

  Future<void> blockUser(String targetUserId) async {
    try {
      final currentUid = _supabase.auth.currentUser?.id;
      if (currentUid == null || currentUid == targetUserId) return;
      if (!AppConfig.isSupabaseConfigured) return;

      await _supabase.from('blocks').insert({
        'blocker_id': currentUid,
        'blocked_id': targetUserId,
      });
    } catch (e) {
      throw ServerException('Failed to block user: ${e.toString()}');
    }
  }

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
}

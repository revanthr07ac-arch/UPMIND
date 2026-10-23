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

  static final List<ProfileModel> _demoTeachers = [
    ProfileModel(
      id: 'user-2',
      username: 'sarah_design',
      fullName: 'Sarah Chen',
      avatarUrl: null,
      bio: 'Design Director & Figma Mentor. Teaching UI/UX and Design Systems.',
      location: 'New York, NY',
      interests: ['UI/UX Design', 'Design Systems', 'Typography'],
      experienceLevel: 'advanced',
      followersCount: 540,
      followingCount: 112,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
      updatedAt: DateTime.now(),
    ),
    ProfileModel(
      id: 'user-3',
      username: 'marcus_code',
      fullName: 'Marcus Thorne',
      avatarUrl: null,
      bio: 'Staff Flutter Engineer. Teaching reactive architecture and Dart performance.',
      location: 'London, UK',
      interests: ['Flutter & Dart', 'Mobile Dev', 'Clean Code'],
      experienceLevel: 'advanced',
      followersCount: 820,
      followingCount: 95,
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
      updatedAt: DateTime.now(),
    ),
  ];

  Future<List<ProfileModel>> searchUsers(String query) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        return _demoTeachers
            .where(
              (u) =>
                  u.username.toLowerCase().contains(query.toLowerCase()) ||
                  u.fullName.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }

      final currentUid = _supabase.auth.currentUser?.id;

      final data = await _supabase
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,full_name.ilike.%$query%')
          .limit(20);

      return (data as List<dynamic>)
          .map((json) => ProfileModel.fromJson(json as Map<String, dynamic>))
          .where((p) => p.id != currentUid)
          .toList();
    } catch (e) {
      if (!AppConfig.isSupabaseConfigured) return _demoTeachers;
      throw ServerException('Failed to search users: ${e.toString()}');
    }
  }

  Future<List<ProfileModel>> getTeachersForSkill(String skillId) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return _demoTeachers;

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
      if (!AppConfig.isSupabaseConfigured) return _demoTeachers;
      return [];
    }
  }

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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/skill_model.dart';

final skillRepositoryProvider = Provider<SkillRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return SkillRepository(supabase);
});

class SkillRepository {
  final SupabaseClient _supabase;

  SkillRepository(this._supabase);

  // In-memory demo fallback for unconfigured environment
  static final List<SkillModel> _demoSkills = [
    const SkillModel(
      id: '1',
      name: 'Flutter & Dart',
      category: 'Mobile Development',
      description: 'Cross-platform app development',
    ),
    const SkillModel(
      id: '2',
      name: 'UI/UX Design',
      category: 'Design',
      description: 'Figma and product design',
    ),
    const SkillModel(
      id: '3',
      name: 'Python Programming',
      category: 'Programming',
      description: 'Backend and scripting',
    ),
    const SkillModel(
      id: '4',
      name: 'Graphic Design',
      category: 'Design',
      description: 'Visual branding and typography',
    ),
    const SkillModel(
      id: '5',
      name: 'Video Editing',
      category: 'Video & Audio',
      description: 'Premiere Pro and DaVinci',
    ),
    const SkillModel(
      id: '6',
      name: 'Portrait Photography',
      category: 'Photography',
      description: 'Lighting and composition',
    ),
    const SkillModel(
      id: '7',
      name: 'Prompt Engineering & AI',
      category: 'Artificial Intelligence',
      description: 'Generative AI workflows',
    ),
    const SkillModel(
      id: '8',
      name: 'Data Analysis & SQL',
      category: 'Data Science',
      description: 'Querying and visualization',
    ),
  ];

  Future<List<SkillModel>> fetchSkillsCatalog() async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        return _demoSkills;
      }

      final response = await _supabase
          .from('skills')
          .select()
          .order('name', ascending: true);

      return (response as List<dynamic>)
          .map((json) => SkillModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (!AppConfig.isSupabaseConfigured) return _demoSkills;
      throw ServerException('Failed to fetch skills catalog: ${e.toString()}');
    }
  }

  Future<List<SkillModel>> searchSkills(String query) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        return _demoSkills
            .where(
              (s) =>
                  s.name.toLowerCase().contains(query.toLowerCase()) ||
                  s.category.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }

      final response = await _supabase
          .from('skills')
          .select()
          .ilike('name', '%$query%')
          .limit(20);

      return (response as List<dynamic>)
          .map((json) => SkillModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<UserSkillModel>> fetchUserSkills(String userId) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        return [];
      }

      final response = await _supabase
          .from('user_skills')
          .select('*, skills(id, name, category, description)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((json) => UserSkillModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> addUserSkill({
    required String userId,
    required String skillId,
    required String intent,
    required String experienceLevel,
    String? description,
  }) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return;

      await _supabase.from('user_skills').upsert({
        'user_id': userId,
        'skill_id': skillId,
        'intent': intent,
        'experience_level': experienceLevel,
        'description': description,
      }, onConflict: 'user_id, skill_id, intent');
    } catch (e) {
      throw ServerException('Failed to add skill: ${e.toString()}');
    }
  }

  Future<void> removeUserSkill(String userSkillId) async {
    try {
      if (!AppConfig.isSupabaseConfigured) return;
      await _supabase.from('user_skills').delete().eq('id', userSkillId);
    } catch (e) {
      throw ServerException('Failed to remove skill: ${e.toString()}');
    }
  }
}

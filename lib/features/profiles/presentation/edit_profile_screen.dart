import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/skill_chip.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../../skills/data/skill_repository.dart';
import '../../skills/domain/skill_model.dart';
import '../data/profile_repository.dart';
import '../domain/profile_model.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();

  String _experienceLevel = 'beginner';
  File? _newAvatarFile;
  ProfileModel? _currentProfile;
  List<UserSkillModel> _userSkills = [];
  List<SkillModel> _allSkills = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid =
        ref.read(authRepositoryProvider).currentUser?.id ?? 'demo-user-id';
    final profile = await ref.read(profileRepositoryProvider).getProfile(uid);
    final userSkills = await ref
        .read(skillRepositoryProvider)
        .fetchUserSkills(uid);
    final allSkills = await ref
        .read(skillRepositoryProvider)
        .fetchSkillsCatalog();

    if (mounted && profile != null) {
      setState(() {
        _currentProfile = profile;
        _fullNameController.text = profile.fullName;
        _bioController.text = profile.bio ?? '';
        _locationController.text = profile.location ?? '';
        _experienceLevel = profile.experienceLevel;
        _userSkills = userSkills;
        _allSkills = allSkills;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _newAvatarFile = File(picked.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to select image: $e')));
    }
  }

  Future<void> _addSkillDialog(String intent) async {
    String? selectedSkillId = _allSkills.isNotEmpty
        ? _allSkills.first.id
        : null;
    String skillLevel = 'beginner';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            intent == 'teaching' ? 'Add Teaching Skill' : 'Add Learning Skill',
            style: AppTypography.h3,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedSkillId,
                dropdownColor: AppColors.cardElevated,
                items: _allSkills
                    .map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    )
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedSkillId = val),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: skillLevel,
                dropdownColor: AppColors.cardElevated,
                items: const [
                  DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                  DropdownMenuItem(
                    value: 'intermediate',
                    child: Text('Intermediate'),
                  ),
                  DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                ],
                onChanged: (val) =>
                    setDialogState(() => skillLevel = val ?? 'beginner'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedSkillId == null) return;
                Navigator.pop(ctx);
                final uid =
                    ref.read(authRepositoryProvider).currentUser?.id ??
                    'demo-user-id';
                await ref
                    .read(skillRepositoryProvider)
                    .addUserSkill(
                      userId: uid,
                      skillId: selectedSkillId!,
                      intent: intent,
                      experienceLevel: skillLevel,
                    );
                final refreshed = await ref
                    .read(skillRepositoryProvider)
                    .fetchUserSkills(uid);
                if (mounted) setState(() => _userSkills = refreshed);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_currentProfile == null) return;
    setState(() => _isSaving = true);

    try {
      final uid =
          ref.read(authRepositoryProvider).currentUser?.id ?? 'demo-user-id';
      String? avatarUrl = _currentProfile!.avatarUrl;

      if (_newAvatarFile != null) {
        avatarUrl = await ref
            .read(profileRepositoryProvider)
            .uploadAvatar(uid, _newAvatarFile!);
      }

      final updated = _currentProfile!.copyWith(
        fullName: _fullNameController.text.trim(),
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        experienceLevel: _experienceLevel,
        avatarUrl: avatarUrl,
      );

      await ref.read(profileRepositoryProvider).updateProfile(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingIndicator());
    }

    final teachingSkills = _userSkills.where((s) => s.isTeaching).toList();
    final learningSkills = _userSkills.where((s) => s.isLearning).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile', style: AppTypography.h3),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CustomButton(
              text: 'Save',
              isLoading: _isSaving,
              onPressed: _handleSave,
              width: 80,
              height: 38,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar Selector
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  if (_newAvatarFile != null)
                    CircleAvatar(
                      radius: 46,
                      backgroundImage: FileImage(_newAvatarFile!),
                    )
                  else
                    UserAvatar(
                      name: _fullNameController.text,
                      imageUrl: _currentProfile?.avatarUrl,
                      radius: 46,
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('Tap to change profile picture', style: AppTypography.caption),
            const SizedBox(height: 24),

            // Form Fields
            CustomTextField(
              controller: _fullNameController,
              label: 'Full Name',
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _bioController,
              label: 'Bio / About You',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _locationController,
              label: 'Location (Optional)',
              hintText: 'e.g. San Francisco, CA',
            ),
            const SizedBox(height: 20),

            // Teaching Skills Section
            CustomCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Skills You Can Teach',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.primaryBlue,
                          size: 20,
                        ),
                        onPressed: () => _addSkillDialog('teaching'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (teachingSkills.isEmpty)
                    Text(
                      'No teaching skills added yet. Add skills to help beginners!',
                      style: AppTypography.caption,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: teachingSkills
                          .map(
                            (s) => SkillChip(
                              label: s.skillName,
                              intent: SkillIntent.teach,
                              level: s.experienceLevel,
                              onDeleted: () async {
                                await ref
                                    .read(skillRepositoryProvider)
                                    .removeUserSkill(s.id);
                                _loadData();
                              },
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Learning Interests Section
            CustomCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Skills You Want to Learn',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryViolet,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.secondaryViolet,
                          size: 20,
                        ),
                        onPressed: () => _addSkillDialog('learning'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (learningSkills.isEmpty)
                    Text(
                      'No learning goals listed. Add skills you want to learn!',
                      style: AppTypography.caption,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: learningSkills
                          .map(
                            (s) => SkillChip(
                              label: s.skillName,
                              intent: SkillIntent.learn,
                              level: s.experienceLevel,
                              onDeleted: () async {
                                await ref
                                    .read(skillRepositoryProvider)
                                    .removeUserSkill(s.id);
                                _loadData();
                              },
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

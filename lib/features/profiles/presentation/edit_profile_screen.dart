import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/loading_indicator.dart';
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
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _institutionController = TextEditingController();
  final _courseController = TextEditingController();
  final _websiteUrlController = TextEditingController();
  final _locationController = TextEditingController();

  String _experienceLevel = 'beginner';
  File? _newAvatarFile;
  ProfileModel? _currentProfile;
  List<UserSkillModel> _userSkills = [];
  List<SkillModel> _allSkills = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _saveErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    final profile = await ref.read(profileRepositoryProvider).getProfile(user.id);
    final userSkills = await ref
        .read(skillRepositoryProvider)
        .fetchUserSkills(user.id);
    final allSkills = await ref
        .read(skillRepositoryProvider)
        .fetchSkillsCatalog();

    if (mounted) {
      setState(() {
        _currentProfile = profile;
        if (profile != null) {
          _fullNameController.text = profile.fullName;
          _usernameController.text = profile.username;
          _bioController.text = profile.bio ?? '';
          _institutionController.text = profile.institution ?? '';
          _courseController.text = profile.course ?? '';
          _websiteUrlController.text = profile.websiteUrl ?? '';
          _locationController.text = profile.location ?? '';
          _experienceLevel = profile.experienceLevel;
        } else {
          // Fallback to user metadata if profile row is pending
          final meta = user.userMetadata ?? {};
          _fullNameController.text = meta['full_name']?.toString() ?? '';
          _usernameController.text = meta['username']?.toString() ?? '';
        }
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
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked != null) {
        setState(() => _newAvatarFile = File(picked.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _addSkillDialog(String intent) async {
    if (_allSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading skills catalog... please retry.')),
      );
      return;
    }

    String selectedSkillId = _allSkills.first.id;
    String skillLevel = 'beginner';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            intent == 'teaching' ? 'Add Teaching Skill' : 'Add Learning Skill',
            style: AppTypography.h3,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Skill', style: AppTypography.caption),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedSkillId,
                dropdownColor: AppColors.cardElevated,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.cardElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                items: _allSkills
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name, style: AppTypography.bodyMedium),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedSkillId = val);
                },
              ),
              const SizedBox(height: 16),
              Text('Proficiency Level', style: AppTypography.caption),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: skillLevel,
                dropdownColor: AppColors.cardElevated,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.cardElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                  DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
                  DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => skillLevel = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: intent == 'teaching'
                    ? AppColors.primaryBlue
                    : AppColors.secondaryViolet,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final user = ref.read(authRepositoryProvider).currentUser;
                if (user == null) return;

                await ref.read(skillRepositoryProvider).addUserSkill(
                      userId: user.id,
                      skillId: selectedSkillId,
                      intent: intent,
                      experienceLevel: skillLevel,
                    );
                final refreshed = await ref
                    .read(skillRepositoryProvider)
                    .fetchUserSkills(user.id);
                if (mounted) setState(() => _userSkills = refreshed);
              },
              child: const Text('Add Skill', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeSkill(String userSkillId) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    try {
      await ref.read(skillRepositoryProvider).removeUserSkill(userSkillId);
      final refreshed =
          await ref.read(skillRepositoryProvider).fetchUserSkills(user.id);
      if (mounted) setState(() => _userSkills = refreshed);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove skill: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
    });

    try {
      final uid = user.id;
      String? avatarUrl = _currentProfile?.avatarUrl;

      // 1. Upload new avatar if picked
      if (_newAvatarFile != null) {
        avatarUrl = await ref
            .read(profileRepositoryProvider)
            .uploadAvatar(uid, _newAvatarFile!);
      }

      // 2. Validate username uniqueness
      final desiredUsername = _usernameController.text.trim().toLowerCase();
      final isAvailable = await ref
          .read(profileRepositoryProvider)
          .checkUsernameAvailable(desiredUsername, excludeUserId: uid);

      if (!isAvailable) {
        setState(() {
          _isSaving = false;
          _saveErrorMessage = 'Username "@$desiredUsername" is already taken. Please choose another.';
        });
        return;
      }

      // 3. Construct updated profile model
      final updated = (_currentProfile ??
              ProfileModel(
                id: uid,
                username: desiredUsername,
                fullName: _fullNameController.text.trim(),
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ))
          .copyWith(
        fullName: _fullNameController.text.trim(),
        username: desiredUsername,
        bio: _bioController.text.trim(),
        institution: _institutionController.text.trim(),
        course: _courseController.text.trim(),
        websiteUrl: _websiteUrlController.text.trim(),
        location: _locationController.text.trim(),
        experienceLevel: _experienceLevel,
        avatarUrl: avatarUrl,
        updatedAt: DateTime.now(),
      );

      // 4. Save to real database
      await ref.read(profileRepositoryProvider).updateProfile(updated);

      // 5. Invalidate current profile provider to trigger fresh reload
      ref.invalidate(currentProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveErrorMessage = e.toString().replaceAll('Exception: ', '');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_saveErrorMessage ?? 'Failed to update profile.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
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
    _usernameController.dispose();
    _bioController.dispose();
    _institutionController.dispose();
    _courseController.dispose();
    _websiteUrlController.dispose();
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
        title: const Text('Edit Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _isSaving
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _handleSave,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_saveErrorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _saveErrorMessage!,
                            style: AppTypography.caption.copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Avatar Change Section
                Center(
                  child: Stack(
                    children: [
                      _newAvatarFile != null
                          ? CircleAvatar(
                              radius: 46,
                              backgroundImage: FileImage(_newAvatarFile!),
                            )
                          : UserAvatar(
                              name: _fullNameController.text.isNotEmpty
                                  ? _fullNameController.text
                                  : 'User',
                              imageUrl: _currentProfile?.avatarUrl,
                              radius: 46,
                            ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _pickAvatar,
                    child: const Text(
                      'Change Profile Photo',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Core Identity Fields
                CustomTextField(
                  controller: _fullNameController,
                  label: 'Full Name *',
                  hintText: 'Enter your full name',
                  validator: Validators.validateFullName,
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.textMuted, size: 20),
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _usernameController,
                  label: 'Username *',
                  hintText: 'e.g. johndoe',
                  validator: Validators.validateUsername,
                  prefixIcon: const Icon(Icons.alternate_email, color: AppColors.textMuted, size: 20),
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _bioController,
                  label: 'Biography',
                  hintText: 'Tell the Upmind community about your skills and goals...',
                  maxLines: 3,
                ),
                const SizedBox(height: 14),

                // Student & Background Fields
                CustomTextField(
                  controller: _institutionController,
                  label: 'College or Institution (Optional)',
                  hintText: 'e.g. Stanford University / Tech Academy',
                  prefixIcon: const Icon(Icons.school_outlined, color: AppColors.textMuted, size: 20),
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _courseController,
                  label: 'Course or Professional Background (Optional)',
                  hintText: 'e.g. Computer Science B.S. / Self-Taught Developer',
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textMuted, size: 20),
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _websiteUrlController,
                  label: 'Website or Portfolio Link (Optional)',
                  hintText: 'e.g. https://myportfolio.dev',
                  prefixIcon: const Icon(Icons.link, color: AppColors.textMuted, size: 20),
                ),
                const SizedBox(height: 14),

                CustomTextField(
                  controller: _locationController,
                  label: 'Location (Optional)',
                  hintText: 'e.g. Austin, TX / London, UK',
                  prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.textMuted, size: 20),
                ),
                const SizedBox(height: 14),

                // Experience Level
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overall Experience Level', style: AppTypography.caption),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _experienceLevel,
                      dropdownColor: AppColors.cardElevated,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                        DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
                        DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _experienceLevel = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Teaching Skills Section
                CustomCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.school, color: AppColors.primaryBlue, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Skills You Can Teach',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: AppColors.primaryBlue),
                            tooltip: 'Add Teaching Skill',
                            onPressed: () => _addSkillDialog('teaching'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (teachingSkills.isEmpty)
                        Text(
                          'No teaching skills added yet. Tap + to add skills you can mentor others in.',
                          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: teachingSkills
                              .map(
                                (s) => Chip(
                                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                                  side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                                  label: Text(
                                    '${s.skillName} • ${s.experienceLevel}',
                                    style: const TextStyle(color: AppColors.primaryBlue, fontSize: 12),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primaryBlue),
                                  onDeleted: () => _removeSkill(s.id),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Learning Skills Section
                CustomCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lightbulb_outline, color: AppColors.secondaryViolet, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Skills You Want to Learn',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondaryViolet,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: AppColors.secondaryViolet),
                            tooltip: 'Add Learning Skill',
                            onPressed: () => _addSkillDialog('learning'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (learningSkills.isEmpty)
                        Text(
                          'No learning skills added yet. Tap + to specify skills you wish to learn.',
                          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: learningSkills
                              .map(
                                (s) => Chip(
                                  backgroundColor: AppColors.secondaryViolet.withValues(alpha: 0.15),
                                  side: BorderSide(color: AppColors.secondaryViolet.withValues(alpha: 0.3)),
                                  label: Text(
                                    '${s.skillName} • ${s.experienceLevel}',
                                    style: const TextStyle(color: AppColors.secondaryViolet, fontSize: 12),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.secondaryViolet),
                                  onDeleted: () => _removeSkill(s.id),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Save Button
                CustomButton(
                  text: 'Save Changes',
                  isLoading: _isSaving,
                  onPressed: _handleSave,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

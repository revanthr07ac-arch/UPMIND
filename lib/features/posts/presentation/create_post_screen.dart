import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/skill_chip.dart';
import '../../skills/data/skill_repository.dart';
import '../../skills/domain/skill_model.dart';
import '../data/post_repository.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _captionController = TextEditingController();
  final _educationalController = TextEditingController();
  final _tagInputController = TextEditingController();

  String _postType = 'text'; // 'text' | 'image' | 'tutorial'
  File? _selectedImage;
  final List<String> _selectedTags = [];
  bool _isPublishing = false;
  List<SkillModel> _availableSkills = [];

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    final skills = await ref.read(skillRepositoryProvider).fetchSkillsCatalog();
    if (mounted) setState(() => _availableSkills = skills);
  }

  @override
  void dispose() {
    _captionController.dispose();
    _educationalController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          if (_postType == 'text') _postType = 'image';
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  void _addTag(String tag) {
    final clean = tag.trim();
    if (clean.isNotEmpty && !_selectedTags.contains(clean)) {
      setState(() {
        _selectedTags.add(clean);
        _tagInputController.clear();
      });
    }
  }

  Future<void> _handlePublish() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a caption for your post')),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      String? uploadedImageUrl;
      if (_selectedImage != null) {
        uploadedImageUrl = await ref
            .read(postRepositoryProvider)
            .uploadPostImage(_selectedImage!);
      }

      await ref
          .read(postRepositoryProvider)
          .createPost(
            caption: caption,
            imageUrl: uploadedImageUrl,
            postType: _postType,
            educationalDescription: _postType == 'tutorial'
                ? _educationalController.text.trim()
                : null,
            skillTags: _selectedTags,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post published successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Post', style: AppTypography.h3),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CustomButton(
              text: 'Publish',
              isLoading: _isPublishing,
              onPressed: _handlePublish,
              width: 90,
              height: 38,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Type Toggle
            Text(
              'POST TYPE',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTypeOption(
                  'text',
                  'Text & Thoughts',
                  Icons.text_fields_rounded,
                ),
                const SizedBox(width: 8),
                _buildTypeOption(
                  'tutorial',
                  'Tutorial 🎓',
                  Icons.menu_book_rounded,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Caption
            CustomTextField(
              controller: _captionController,
              hintText: _postType == 'tutorial'
                  ? 'What skill or technique are you teaching today? Summarize your lesson...'
                  : 'Share insights, ask questions, or showcase your recent work...',
              maxLines: 5,
            ),
            const SizedBox(height: 16),

            // Educational Breakdown for Tutorial
            if (_postType == 'tutorial') ...[
              Text(
                'STEP-BY-STEP BREAKDOWN',
                style: AppTypography.caption.copyWith(
                  color: AppColors.secondaryViolet,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _educationalController,
                hintText: 'Step 1: Setup...\nStep 2: Core workflow...\nStep 3: Tips & practical mistakes to avoid...',
                maxLines: 6,
              ),
              const SizedBox(height: 16),
            ],

            // Image Preview or Add Image
            if (_selectedImage != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withOpacity(0.7),
                      radius: 16,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => setState(() => _selectedImage = null),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else ...[
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.border,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Attach Image or Work Showcase',
                        style: AppTypography.button.copyWith(
                          color: AppColors.primaryBlue,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Skill Tags
            Text(
              'SKILL TAGS',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedTags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedTags
                    .map(
                      (tag) => SkillChip(
                        label: tag,
                        onDeleted: () =>
                            setState(() => _selectedTags.remove(tag)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Quick add popular skills
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _availableSkills.take(8).map((s) {
                final isAdded = _selectedTags.contains(s.name);
                return ActionChip(
                  label: Text('+ ${s.name}'),
                  backgroundColor: isAdded
                      ? AppColors.primaryBlue.withOpacity(0.2)
                      : AppColors.cardElevated,
                  onPressed: isAdded ? null : () => _addTag(s.name),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(String type, String label, IconData icon) {
    final isSelected = _postType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _postType = type),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (type == 'tutorial'
                      ? AppColors.secondaryViolet.withOpacity(0.2)
                      : AppColors.primaryBlue.withOpacity(0.2))
                : AppColors.cardElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (type == 'tutorial'
                        ? AppColors.secondaryViolet
                        : AppColors.primaryBlue)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? (type == 'tutorial'
                          ? AppColors.secondaryViolet
                          : AppColors.primaryBlue)
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

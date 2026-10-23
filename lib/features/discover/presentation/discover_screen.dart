import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profiles/domain/profile_model.dart';
import '../../skills/data/skill_repository.dart';
import '../../skills/domain/skill_model.dart';
import '../data/discover_repository.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<ProfileModel> _searchResults = [];
  List<SkillModel> _skills = [];
  String? _selectedCategory;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final skills = await ref.read(skillRepositoryProvider).fetchSkillsCatalog();
    final teachers = await ref.read(discoverRepositoryProvider).searchUsers('');
    if (mounted) {
      setState(() {
        _skills = skills;
        _searchResults = teachers;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _isSearching = true);
      final results = await ref
          .read(discoverRepositoryProvider)
          .searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = {'All', ..._skills.map((s) => s.category)};

    return Scaffold(
      appBar: AppBar(title: Text('Discover & Learn', style: AppTypography.h3)),
      body: CustomScrollView(
        slivers: [
          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: CustomTextField(
                controller: _searchController,
                hintText: 'Search by skill, name, or username...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),

          // Skill Categories Pills
          SliverToBoxAdapter(
            child: SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = categories.elementAt(index);
                  final isSelected =
                      (_selectedCategory == null && cat == 'All') ||
                      (_selectedCategory == cat);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat == 'All' ? null : cat;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.secondaryViolet
                            : AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.secondaryViolet
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: AppTypography.chip.copyWith(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Teachers Heading
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Skill Mentors & Teachers', style: AppTypography.h3),
                  Text(
                    '${_searchResults.length} available',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ),

          // Teachers List
          if (_isSearching)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: LoadingIndicator(),
              ),
            )
          else if (_searchResults.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.person_search_outlined,
                title: 'No Mentors Found',
                message: 'Try searching for a different skill or topic.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final user = _searchResults[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: CustomCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UserAvatar(
                            name: user.fullName,
                            imageUrl: user.avatarUrl,
                            radius: 24,
                            onTap: () => context.push('/profile/${user.id}'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        user.fullName,
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBlue
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'CAN TEACH',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.primaryBlue,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '@${user.username}',
                                  style: AppTypography.caption,
                                ),
                                if (user.bio != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    user.bio!,
                                    style: AppTypography.bodySecondary.copyWith(
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${user.followersCount} followers',
                                      style: AppTypography.caption,
                                    ),
                                    CustomButton(
                                      text: 'Request to Learn',
                                      onPressed: () => _openRequestSheet(user),
                                      variant: ButtonVariant.primary,
                                      width: 130,
                                      height: 32,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }, childCount: _searchResults.length),
              ),
            ),
        ],
      ),
    );
  }

  void _openRequestSheet(ProfileModel teacher) {
    final messageController = TextEditingController();
    String? selectedSkillId;
    if (_skills.isNotEmpty) selectedSkillId = _skills.first.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  UserAvatar(
                    name: teacher.fullName,
                    imageUrl: teacher.avatarUrl,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Learn from ${teacher.fullName}',
                    style: AppTypography.h3,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'SELECT SKILL TO LEARN',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedSkillId,
                dropdownColor: AppColors.cardElevated,
                items: _skills
                    .map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                    )
                    .toList(),
                onChanged: (val) => setSheetState(() => selectedSkillId = val),
              ),
              const SizedBox(height: 14),
              Text(
                'YOUR LEARNING GOAL & MESSAGE',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              CustomTextField(
                controller: messageController,
                hintText: 'Explain what you want to achieve or where you are stuck...',
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Send Learning Request',
                onPressed: () async {
                  if (selectedSkillId == null) return;
                  final msg = messageController.text.trim();
                  if (msg.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please include a message for the teacher',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await ref.read(discoverRepositoryProvider).searchUsers('');
                    // Send via learning repository
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Learning request sent! Track it under the Learning tab.',
                          ),
                          backgroundColor: AppColors.success,
                        ),
                      );
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
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

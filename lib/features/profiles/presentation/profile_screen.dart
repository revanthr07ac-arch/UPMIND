import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/skill_chip.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../../posts/data/post_repository.dart';
import '../../posts/domain/post_model.dart';
import '../../posts/presentation/widgets/post_card.dart';
import '../../skills/data/skill_repository.dart';
import '../../skills/domain/skill_model.dart';
import '../data/profile_repository.dart';
import '../domain/profile_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId; // If null, displays own profile

  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ProfileModel? _profile;
  List<UserSkillModel> _userSkills = [];
  List<PostModel> _userPosts = [];
  bool _isLoading = true;
  bool _isFollowing = false;

  bool get _isOwnProfile {
    final currentUid = ref.read(authRepositoryProvider).currentUser?.id;
    return widget.userId == null ||
        widget.userId == currentUid ||
        widget.userId == 'demo-user-id';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final targetId =
        widget.userId ??
        ref.read(authRepositoryProvider).currentUser?.id ??
        'demo-user-id';

    final profile = await ref
        .read(profileRepositoryProvider)
        .getProfile(targetId);
    final skills = await ref
        .read(skillRepositoryProvider)
        .fetchUserSkills(targetId);
    final posts = await ref.read(postRepositoryProvider).getUserPosts(targetId);

    if (mounted) {
      setState(() {
        _profile = profile;
        _userSkills = skills;
        _userPosts = posts;
        _isFollowing = profile?.isFollowing ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null) return;
    final next = !_isFollowing;
    setState(() => _isFollowing = next);

    try {
      if (next) {
        await ref.read(profileRepositoryProvider).followUser(_profile!.id);
      } else {
        await ref.read(profileRepositoryProvider).unfollowUser(_profile!.id);
      }
    } catch (_) {
      if (mounted) setState(() => _isFollowing = !next);
    }
  }

  void _showMoreMenu() {
    if (_profile == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block_outlined, color: AppColors.error),
              title: const Text(
                'Block User',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await ref
                    .read(profileRepositoryProvider)
                    .blockUser(_profile!.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User blocked.')),
                  );
                  context.pop();
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.flag_outlined,
                color: AppColors.warning,
              ),
              title: const Text(
                'Report User',
                style: TextStyle(color: AppColors.warning),
              ),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted for review.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingIndicator());
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Profile Not Found',
          message: 'This user account does not exist or has been deactivated.',
        ),
      );
    }

    final teachingSkills = _userSkills.where((s) => s.isTeaching).toList();
    final learningSkills = _userSkills.where((s) => s.isLearning).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('@${_profile!.username}', style: AppTypography.h3),
        actions: [
          if (_isOwnProfile)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
            )
          else
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showMoreMenu,
            ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar & Stats Row
                    Row(
                      children: [
                        UserAvatar(
                          name: _profile!.fullName,
                          imageUrl: _profile!.avatarUrl,
                          radius: 36,
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('Posts', '${_userPosts.length}'),
                              _buildStatItem(
                                'Followers',
                                '${_profile!.followersCount}',
                              ),
                              _buildStatItem(
                                'Following',
                                '${_profile!.followingCount}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Name, Level & Bio
                    Row(
                      children: [
                        Text(_profile!.fullName, style: AppTypography.h3),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _profile!.experienceLevel.toUpperCase(),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primaryBlue,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_profile!.bio != null) ...[
                      const SizedBox(height: 6),
                      Text(_profile!.bio!, style: AppTypography.bodySecondary),
                    ],
                    if (_profile!.location != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _profile!.location!,
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Action Button (Edit Profile or Follow/Message)
                    if (_isOwnProfile)
                      CustomButton(
                        text: 'Edit Profile & Portfolio',
                        variant: ButtonVariant.outline,
                        height: 38,
                        onPressed: () async {
                          await context.push('/edit-profile');
                          _loadProfileData();
                        },
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: _isFollowing ? 'Following' : 'Follow',
                              variant: _isFollowing
                                  ? ButtonVariant.outline
                                  : ButtonVariant.primary,
                              height: 38,
                              onPressed: _toggleFollow,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // Skills Overview Section
                    CustomCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SKILLS & PORTFOLIO',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (teachingSkills.isNotEmpty) ...[
                            Text(
                              'Can Teach:',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primaryBlue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: teachingSkills
                                  .map(
                                    (s) => SkillChip(
                                      label: s.skillName,
                                      intent: SkillIntent.teach,
                                      level: s.experienceLevel,
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (learningSkills.isNotEmpty) ...[
                            Text(
                              'Want to Learn:',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.secondaryViolet,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: learningSkills
                                  .map(
                                    (s) => SkillChip(
                                      label: s.skillName,
                                      intent: SkillIntent.learn,
                                      level: s.experienceLevel,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primaryBlue,
                  labelColor: AppColors.primaryBlue,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: const [
                    Tab(text: 'Posts & Tutorials'),
                    Tab(text: 'About & Links'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Posts
            _userPosts.isEmpty
                ? const EmptyState(
                    icon: Icons.article_outlined,
                    title: 'No Posts Yet',
                    message: 'Published posts and tutorials will appear here.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _userPosts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) =>
                        PostCard(post: _userPosts[index]),
                  ),

            // Tab 2: About & Links
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Member Information', style: AppTypography.h3),
                  const SizedBox(height: 12),
                  Text(
                    'Experience Level: ${_profile!.experienceLevel.toUpperCase()}',
                    style: AppTypography.bodySecondary,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Interests: ${_profile!.interests.isEmpty ? "None listed" : _profile!.interests.join(", ")}',
                    style: AppTypography.bodySecondary,
                  ),
                  const SizedBox(height: 16),
                  Text('Portfolio & External Links', style: AppTypography.h3),
                  const SizedBox(height: 8),
                  if (_profile!.portfolioLinks.isEmpty)
                    Text(
                      'No portfolio links added yet.',
                      style: AppTypography.caption,
                    )
                  else
                    ..._profile!.portfolioLinks.map(
                      (l) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.link,
                              size: 16,
                              color: AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l['title'] ?? 'Link',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTypography.h3),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.background, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

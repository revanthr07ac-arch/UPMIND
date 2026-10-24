import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'user_list_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId; // If null, displays authenticated user's own profile

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
  int _followersCount = 0;
  bool _isGridView = true;

  bool get _isOwnProfile {
    final currentUid = ref.read(authRepositoryProvider).currentUser?.id;
    return widget.userId == null || widget.userId == currentUid;
  }

  @override
  void initState() {
    super.initState();
    // 3 Content Tabs: Posts (All), Tutorials, Projects
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final currentUid = ref.read(authRepositoryProvider).currentUser?.id;
    final targetId = widget.userId ?? currentUid;

    if (targetId == null) {
      if (mounted) {
        setState(() {
          _profile = null;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final profile =
          await ref.read(profileRepositoryProvider).getProfile(targetId);
      final skills =
          await ref.read(skillRepositoryProvider).fetchUserSkills(targetId);
      final posts =
          await ref.read(postRepositoryProvider).getUserPosts(targetId);

      if (mounted) {
        setState(() {
          _profile = profile;
          _userSkills = skills;
          _userPosts = posts;
          _isFollowing = profile?.isFollowing ?? false;
          _followersCount = profile?.followersCount ?? 0;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null) return;
    final next = !_isFollowing;
    setState(() {
      _isFollowing = next;
      _followersCount = next ? _followersCount + 1 : (_followersCount > 0 ? _followersCount - 1 : 0);
    });

    try {
      if (next) {
        await ref.read(profileRepositoryProvider).followUser(_profile!.id);
      } else {
        await ref.read(profileRepositoryProvider).unfollowUser(_profile!.id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFollowing = !next;
          _followersCount = !next ? _followersCount + 1 : (_followersCount > 0 ? _followersCount - 1 : 0);
        });
      }
    }
  }

  Future<void> _shareProfile() async {
    if (_profile == null) return;
    final url = 'https://upmind.app/@${_profile!.username}';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile link copied: $url'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
              leading: const Icon(Icons.share_outlined, color: AppColors.textPrimary),
              title: const Text('Share Profile', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _shareProfile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined, color: AppColors.error),
              title: const Text('Block User', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(profileRepositoryProvider).blockUser(_profile!.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User blocked.')),
                  );
                  context.pop();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppColors.warning),
              title: const Text('Report User', style: TextStyle(color: AppColors.warning)),
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
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Profile Not Found',
          message: _isOwnProfile
              ? 'Please sign in to view your profile.'
              : 'This user account does not exist or has been deactivated.',
          actionText: _isOwnProfile ? 'Sign In' : null,
          onAction: _isOwnProfile ? () => context.go('/login') : null,
        ),
      );
    }

    final teachingSkills = _userSkills.where((s) => s.isTeaching).toList();
    final learningSkills = _userSkills.where((s) => s.isLearning).toList();

    // Filter posts for the 3 tabs
    final allPosts = _userPosts;
    final tutorialPosts = _userPosts.where((p) => p.postType == 'tutorial').toList();
    final projectPosts = _userPosts.where((p) => p.postType == 'image').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('@${_profile!.username}', style: AppTypography.h3),
        actions: [
          if (_isOwnProfile) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Profile',
              onPressed: () async {
                final updated = await context.push<bool>('/edit-profile');
                if (updated == true) _loadProfileData();
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: _shareProfile,
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Options',
              onPressed: _showMoreMenu,
            ),
          ],
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 700;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 960 : double.infinity),
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Profile Header: Avatar & Stats
                            _buildHeaderRow(isDesktop),
                            const SizedBox(height: 14),

                            // 2. User Info: Name, Badge, Bio, Education & Links
                            _buildUserInfoSection(),
                            const SizedBox(height: 14),

                            // 3. Profile Actions (Edit Profile / Follow / Share)
                            _buildActionButtons(),
                            const SizedBox(height: 16),

                            // 4. Skills Section (Can Teach & Want to Learn)
                            _buildSkillsSection(teachingSkills, learningSkills),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // 5. Content Tabs Header (Posts, Tutorials, Projects)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ProfileTabBarDelegate(
                        TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          indicatorColor: AppColors.primaryBlue,
                          indicatorWeight: 2,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                          labelColor: AppColors.primaryBlue,
                          unselectedLabelColor: AppColors.textMuted,
                          labelStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.bold),
                          tabs: [
                            Tab(text: 'Posts (${allPosts.length})'),
                            Tab(text: 'Tutorials (${tutorialPosts.length})'),
                            Tab(text: 'Projects (${projectPosts.length})'),
                          ],
                        ),
                        isGridView: _isGridView,
                        onToggleView: () => setState(() => _isGridView = !_isGridView),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: All Posts
                    _buildContentTab(
                      posts: allPosts,
                      emptyTitle: 'No Posts Yet',
                      emptyMessage: _isOwnProfile
                          ? 'Share your first skill showcase or lesson with the Upmind community!'
                          : 'This member has not published any posts yet.',
                      isDesktop: isDesktop,
                    ),

                    // Tab 2: Tutorials
                    _buildContentTab(
                      posts: tutorialPosts,
                      emptyTitle: 'No Tutorials Yet',
                      emptyMessage: _isOwnProfile
                          ? 'Break down a skill into step-by-step guidance for aspiring learners!'
                          : 'This member has not published any tutorials yet.',
                      isDesktop: isDesktop,
                    ),

                    // Tab 3: Projects
                    _buildContentTab(
                      posts: projectPosts,
                      emptyTitle: 'No Projects Showcased',
                      emptyMessage: _isOwnProfile
                          ? 'Upload visual portfolio projects to demonstrate your practical craft!'
                          : 'This member has not showcased any portfolio projects yet.',
                      isDesktop: isDesktop,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Subcomponents ---

  Widget _buildHeaderRow(bool isDesktop) {
    return Row(
      children: [
        UserAvatar(
          name: _profile!.fullName,
          imageUrl: _profile!.avatarUrl,
          radius: isDesktop ? 48 : 36,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem('Posts', '${_userPosts.length}'),
              ),
              Expanded(
                child: _buildStatItem(
                  'Followers',
                  '$_followersCount',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserListScreen(
                          userId: _profile!.id,
                          username: _profile!.username,
                          type: UserListType.followers,
                        ),
                      ),
                    );
                    if (mounted) _loadProfileData();
                  },
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Following',
                  '${_profile!.followingCount}',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserListScreen(
                          userId: _profile!.id,
                          username: _profile!.username,
                          type: UserListType.following,
                        ),
                      ),
                    );
                    if (mounted) _loadProfileData();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            maxLines: 1,
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      ),
    );
  }

  Widget _buildUserInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name & Experience Level Badge
        Row(
          children: [
            Flexible(
              child: Text(
                _profile!.fullName,
                style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _profile!.experienceLevel.toUpperCase(),
                style: AppTypography.caption.copyWith(
                  color: AppColors.primaryBlue,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        // Biography
        if (_profile!.bio != null && _profile!.bio!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _profile!.bio!,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          ),
        ],

        // College or Institution
        if (_profile!.institution != null && _profile!.institution!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.school_outlined, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _profile!.institution!,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],

        // Course or Professional Background
        if (_profile!.course != null && _profile!.course!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.badge_outlined, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _profile!.course!,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],

        // Location
        if (_profile!.location != null && _profile!.location!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _profile!.location!,
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],

        // Website or Portfolio Link
        if (_profile!.websiteUrl != null && _profile!.websiteUrl!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: _profile!.websiteUrl!));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied link: ${_profile!.websiteUrl!}'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Row(
              children: [
                const Icon(Icons.link, size: 15, color: AppColors.primaryBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _profile!.websiteUrl!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primaryBlue,
                      decoration: TextDecoration.underline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_isOwnProfile) {
      return Row(
        children: [
          Expanded(
            child: CustomButton(
              text: 'Edit Profile',
              variant: ButtonVariant.outline,
              height: 38,
              onPressed: () async {
                final updated = await context.push<bool>('/edit-profile');
                if (updated == true) _loadProfileData();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: CustomButton(
              text: 'Share Profile',
              variant: ButtonVariant.secondary,
              height: 38,
              onPressed: _shareProfile,
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: CustomButton(
              text: _isFollowing ? 'Following' : 'Follow',
              variant: _isFollowing ? ButtonVariant.outline : ButtonVariant.primary,
              height: 38,
              onPressed: _toggleFollow,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: CustomButton(
              text: 'Share Profile',
              variant: ButtonVariant.secondary,
              height: 38,
              onPressed: _shareProfile,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildSkillsSection(
    List<UserSkillModel> teachingSkills,
    List<UserSkillModel> learningSkills,
  ) {
    if (teachingSkills.isEmpty && learningSkills.isEmpty) {
      if (_isOwnProfile) {
        return CustomCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.school_outlined, color: AppColors.primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Highlight Your Skills',
                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Add skills you can teach or want to learn to connect with mentors.',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              CustomButton(
                text: 'Add Skills',
                height: 34,
                variant: ButtonVariant.secondary,
                onPressed: () async {
                  final updated = await context.push<bool>('/edit-profile');
                  if (updated == true) _loadProfileData();
                },
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return CustomCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SKILLS & PORTFOLIO',
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: AppColors.textMuted,
            ),
          ),
          if (teachingSkills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.school, size: 14, color: AppColors.primaryBlue),
                const SizedBox(width: 6),
                Text(
                  'Can Teach:',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
          ],
          if (learningSkills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 14, color: AppColors.secondaryViolet),
                const SizedBox(width: 6),
                Text(
                  'Want to Learn:',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryViolet,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
    );
  }

  Widget _buildContentTab({
    required List<PostModel> posts,
    required String emptyTitle,
    required String emptyMessage,
    required bool isDesktop,
  }) {
    if (posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.article_outlined,
            title: emptyTitle,
            message: emptyMessage,
            actionText: _isOwnProfile ? 'Create Post' : null,
            onAction: _isOwnProfile ? () => context.push('/create-post') : null,
          ),
        ),
      );
    }

    if (_isGridView) {
      // Instagram-style compact 3-column square grid
      final crossAxisCount = isDesktop ? 4 : 3;

      return GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
          childAspectRatio: 1.0,
        ),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return _buildGridPostTile(post);
        },
      );
    } else {
      // Linear list view of full post cards
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) => PostCard(post: posts[index]),
      );
    }
  }

  Widget _buildGridPostTile(PostModel post) {
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Container(
        color: AppColors.card,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image or Text snippet
            if (post.imageUrl != null)
              Image.network(
                post.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildTextGridPlaceholder(post),
              )
            else
              _buildTextGridPlaceholder(post),

            // Tutorial / Educational badge overlay
            if (post.postType == 'tutorial')
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.menu_book,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),

            // Likes counter overlay on hover/corner
            Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, size: 10, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(
                      '${post.likesCount}',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextGridPlaceholder(PostModel post) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            post.postType == 'tutorial'
                ? Icons.menu_book_outlined
                : Icons.article_outlined,
            size: 18,
            color: post.postType == 'tutorial'
                ? AppColors.primaryBlue
                : AppColors.textMuted,
          ),
          const SizedBox(height: 4),
          Text(
            post.caption,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.2,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final bool isGridView;
  final VoidCallback onToggleView;

  _ProfileTabBarDelegate(
    this.tabBar, {
    required this.isGridView,
    required this.onToggleView,
  });

  @override
  double get minExtent => 48.0;
  @override
  double get maxExtent => 48.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: 48.0,
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(child: tabBar),
          IconButton(
            icon: Icon(
              isGridView ? Icons.view_agenda_outlined : Icons.grid_on,
              size: 20,
              color: AppColors.textSecondary,
            ),
            tooltip: isGridView ? 'Switch to list view' : 'Switch to grid view',
            onPressed: onToggleView,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_ProfileTabBarDelegate oldDelegate) {
    return oldDelegate.isGridView != isGridView;
  }
}

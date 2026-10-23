import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/upmind_logo.dart';
import '../../posts/data/post_repository.dart';
import '../../posts/domain/post_model.dart';
import '../../posts/presentation/widgets/post_card.dart';

enum FeedFilter { all, tutorials }

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  FeedFilter _selectedFilter = FeedFilter.all;
  List<PostModel> _posts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final posts = await ref.read(postRepositoryProvider).getFeed();
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<PostModel> get _filteredPosts {
    if (_selectedFilter == FeedFilter.tutorials) {
      return _posts.where((p) => p.isTutorial).toList();
    }
    return _posts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const UpmindLogo(
          size: 32,
          showTagline: false,
          isHorizontal: true,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => context.push('/notifications'),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip('All Posts', FeedFilter.all),
                const SizedBox(width: 8),
                _buildFilterChip('Tutorials 🎓', FeedFilter.tutorials),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primaryBlue,
        backgroundColor: AppColors.card,
        onRefresh: _loadFeed,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildFilterChip(String label, FeedFilter filter) {
    final isSelected = _selectedFilter == filter;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filter),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : AppColors.cardElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.chip.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SkeletonBox(width: 40, height: 40, borderRadius: 20),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 120, height: 14),
                      SizedBox(height: 6),
                      SkeletonBox(width: 80, height: 10),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              SkeletonBox(width: double.infinity, height: 14),
              SizedBox(height: 8),
              SkeletonBox(width: 220, height: 14),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return ErrorState(message: _errorMessage!, onRetry: _loadFeed);
    }

    final filtered = _filteredPosts;

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.dynamic_feed_rounded,
        title: _selectedFilter == FeedFilter.tutorials
            ? 'No Tutorials Yet'
            : 'Your Feed is Empty',
        message: 'Share your skills, publish a tutorial, or discover creators to follow!',
        actionText: 'Create a Post',
        onAction: () => context.push('/create-post'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final post = filtered[index];
        return PostCard(post: post, onPostDeleted: () => _loadFeed());
      },
    );
  }
}

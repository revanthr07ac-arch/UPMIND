import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../domain/profile_model.dart';

enum UserListType { followers, following }

class UserListScreen extends ConsumerStatefulWidget {
  final String userId;
  final String username;
  final UserListType type;

  const UserListScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.type,
  });

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen> {
  List<ProfileModel> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _followingIds = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(profileRepositoryProvider);
      final list = widget.type == UserListType.followers
          ? await repo.getFollowers(widget.userId)
          : await repo.getFollowing(widget.userId);

      if (mounted) {
        setState(() {
          _users = list;
          _followingIds.clear();
          for (final u in list) {
            if (u.isFollowing) _followingIds.add(u.id);
          }
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

  Future<void> _toggleFollow(ProfileModel user) async {
    final currentUserId = ref.read(authRepositoryProvider).currentUser?.id;
    if (currentUserId == null || currentUserId == user.id) return;

    final isCurrentlyFollowing = _followingIds.contains(user.id);
    setState(() {
      if (isCurrentlyFollowing) {
        _followingIds.remove(user.id);
      } else {
        _followingIds.add(user.id);
      }
    });

    try {
      final repo = ref.read(profileRepositoryProvider);
      if (isCurrentlyFollowing) {
        await repo.unfollowUser(user.id);
      } else {
        await repo.followUser(user.id);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          if (isCurrentlyFollowing) {
            _followingIds.add(user.id);
          } else {
            _followingIds.remove(user.id);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == UserListType.followers ? 'Followers' : 'Following';
    final currentUserId = ref.read(authRepositoryProvider).currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${widget.username}', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
            Text(title, style: AppTypography.h3),
          ],
        ),
      ),
      body: _buildBody(currentUserId),
    );
  }

  Widget _buildBody(String? currentUserId) {
    if (_isLoading) {
      return const Center(child: LoadingIndicator());
    }

    if (_errorMessage != null) {
      return ErrorState(message: _errorMessage!, onRetry: _loadUsers);
    }

    if (_users.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline,
        title: widget.type == UserListType.followers ? 'No Followers Yet' : 'Not Following Anyone',
        message: widget.type == UserListType.followers
            ? 'When other students follow this account, they will appear here.'
            : 'Explore the global community and connect with peers and mentors.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryBlue,
      backgroundColor: AppColors.card,
      onRefresh: _loadUsers,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final user = _users[index];
          final isFollowing = _followingIds.contains(user.id);
          final isSelf = currentUserId == user.id;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: UserAvatar(
              name: user.fullName,
              imageUrl: user.avatarUrl,
              radius: 22,
              onTap: () => context.push('/profile/${user.id}'),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    user.fullName,
                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (user.institution != null && user.institution!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    '• ${user.institution}',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
            subtitle: Text(
              '@${user.username}',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
            trailing: isSelf
                ? null
                : CustomButton(
                    text: isFollowing ? 'Following' : 'Follow',
                    variant: isFollowing ? ButtonVariant.outline : ButtonVariant.primary,
                    width: 96,
                    height: 32,
                    onPressed: () => _toggleFollow(user),
                  ),
            onTap: () => context.push('/profile/${user.id}'),
          );
        },
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../../core/widgets/skill_chip.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/post_repository.dart';
import '../../domain/post_model.dart';

class PostCard extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback? onPostDeleted;
  final VoidCallback? onCommentPressed;

  const PostCard({
    super.key,
    required this.post,
    this.onPostDeleted,
    this.onCommentPressed,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late bool _isLiked;
  late int _likesCount;
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
    _isSaved = widget.post.isSaved;
  }

  Future<void> _handleLikeToggle() async {
    final nextState = !_isLiked;
    setState(() {
      _isLiked = nextState;
      _likesCount = nextState
          ? _likesCount + 1
          : (_likesCount > 0 ? _likesCount - 1 : 0);
    });

    try {
      await ref
          .read(postRepositoryProvider)
          .toggleLike(widget.post.id, !nextState);
    } catch (_) {
      // Revert if request fails
      if (mounted) {
        setState(() {
          _isLiked = !nextState;
          _likesCount = widget.post.likesCount;
        });
      }
    }
  }

  Future<void> _handleSaveToggle() async {
    final nextState = !_isSaved;
    setState(() {
      _isSaved = nextState;
    });

    try {
      await ref
          .read(postRepositoryProvider)
          .toggleSave(widget.post.id, !nextState);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextState
                  ? 'Post saved to bookmarks'
                  : 'Post removed from bookmarks',
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaved = !nextState;
        });
      }
    }
  }

  void _showPostOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Report Post',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportDialog();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.share_outlined,
                  color: AppColors.textPrimary,
                ),
                title: const Text(
                  'Share Link',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post link copied to clipboard'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog() {
    final reasons = [
      'Spam',
      'Harassment or Hate Speech',
      'Misleading Content',
      'Inappropriate Skill Advice',
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Report Post', style: AppTypography.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map(
                (r) => ListTile(
                  title: Text(r, style: AppTypography.bodyMedium),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref
                        .read(postRepositoryProvider)
                        .reportPost(widget.post.id, r, null);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thank you. Post reported for review.'),
                        ),
                      );
                    }
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Author Info & Options
          Row(
            children: [
              UserAvatar(
                name: widget.post.authorFullName,
                imageUrl: widget.post.authorAvatarUrl,
                radius: 20,
                onTap: () => context.push('/profile/${widget.post.authorId}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/profile/${widget.post.authorId}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.post.authorFullName,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.post.isTutorial) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryViolet.withOpacity(
                                  0.18,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.secondaryViolet.withOpacity(
                                    0.4,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'TUTORIAL',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.secondaryViolet,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '@${widget.post.authorUsername} • ${DateFormatter.timeAgo(widget.post.createdAt)}',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.more_horiz,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                onPressed: _showPostOptions,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Caption
          GestureDetector(
            onTap: () => context.push('/post/${widget.post.id}'),
            child: Text(
              widget.post.caption,
              style: AppTypography.bodyMedium.copyWith(height: 1.45),
            ),
          ),

          // Educational Description (for tutorials)
          if (widget.post.isTutorial &&
              widget.post.educationalDescription != null) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  title: Row(
                    children: [
                      const Icon(
                        Icons.menu_book_outlined,
                        size: 16,
                        color: AppColors.secondaryViolet,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Educational Lesson Breakdown',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.secondaryViolet,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Text(
                        widget.post.educationalDescription!,
                        style: AppTypography.bodySecondary.copyWith(
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Post Image Attachment
          if (widget.post.hasImage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: widget.post.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: AppColors.cardElevated,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 120,
                  color: AppColors.cardElevated,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],

          // Skill Tags
          if (widget.post.skillTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: widget.post.skillTags.map((tag) {
                return SkillChip(label: tag, intent: SkillIntent.neutral);
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 4),

          // Engagement Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Like Button
              InkWell(
                onTap: _handleLikeToggle,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isLiked
                            ? Icons.favorite
                            : Icons.favorite_border_rounded,
                        color: _isLiked
                            ? AppColors.error
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_likesCount',
                        style: AppTypography.caption.copyWith(
                          color: _isLiked
                              ? AppColors.error
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Comment Button
              InkWell(
                onTap:
                    widget.onCommentPressed ??
                    () => context.push('/post/${widget.post.id}'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppColors.textSecondary,
                        size: 19,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.post.commentsCount}',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Save / Bookmark
              InkWell(
                onTap: _handleSaveToggle,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Icon(
                    _isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: _isSaved
                        ? AppColors.primaryBlue
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

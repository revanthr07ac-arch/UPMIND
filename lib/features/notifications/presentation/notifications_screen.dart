import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/custom_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/notification_repository.dart';
import '../domain/notification_model.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final list = await ref
        .read(notificationRepositoryProvider)
        .getNotifications();
    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    await ref.read(notificationRepositoryProvider).markAllAsRead();
    _loadNotifications();
  }

  void _handleTap(NotificationModel notif) async {
    if (!notif.isRead) {
      await ref.read(notificationRepositoryProvider).markAsRead(notif.id);
    }

    if (!mounted) return;

    if (notif.type.startsWith('learning_request')) {
      context.go('/learning');
    } else if (notif.type == 'follow' && notif.actorId != null) {
      context.push('/profile/${notif.actorId}');
    } else if (notif.relatedEntityId != null) {
      context.push('/post/${notif.relatedEntityId}');
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'follow':
        return Icons.person_add_alt_1_rounded;
      case 'comment':
        return Icons.chat_bubble_outline_rounded;
      case 'like':
        return Icons.favorite_rounded;
      case 'learning_request_new':
        return Icons.school_outlined;
      case 'learning_request_accepted':
        return Icons.check_circle_outline_rounded;
      case 'learning_request_declined':
        return Icons.cancel_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'follow':
        return AppColors.primaryBlue;
      case 'comment':
        return AppColors.info;
      case 'like':
        return AppColors.error;
      case 'learning_request_new':
        return AppColors.secondaryViolet;
      case 'learning_request_accepted':
        return AppColors.success;
      case 'learning_request_declined':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: AppTypography.h3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : _notifications.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No Notifications Yet',
              message: 'When members follow you, interact with your tutorials, or send learning requests, they will show up here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                return CustomCard(
                  padding: const EdgeInsets.all(12),
                  backgroundColor: notif.isRead
                      ? AppColors.card
                      : AppColors.cardElevated,
                  onTap: () => _handleTap(notif),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          UserAvatar(
                            name: notif.actorFullName,
                            imageUrl: notif.actorAvatarUrl,
                            radius: 20,
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: CircleAvatar(
                              radius: 9,
                              backgroundColor: AppColors.card,
                              child: Icon(
                                _iconForType(notif.type),
                                size: 11,
                                color: _colorForType(notif.type),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif.title,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: notif.isRead
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormatter.timeAgo(notif.createdAt),
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

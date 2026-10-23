import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/notification_model.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return NotificationRepository(supabase);
});

class NotificationRepository {
  final SupabaseClient _supabase;

  NotificationRepository(this._supabase);

  // Fallback demo notifications
  static final List<NotificationModel> _demoNotifications = [
    NotificationModel(
      id: 'demo-notif-1',
      recipientId: 'demo-user-id',
      actorId: 'user-2',
      actorUsername: 'sarah_design',
      actorFullName: 'Sarah Chen',
      type: 'learning_request_accepted',
      relatedEntityId: 'demo-req-2',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    NotificationModel(
      id: 'demo-notif-2',
      recipientId: 'demo-user-id',
      actorId: 'user-4',
      actorUsername: 'dev_david',
      actorFullName: 'David Kim',
      type: 'learning_request_new',
      relatedEntityId: 'demo-req-1',
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    NotificationModel(
      id: 'demo-notif-3',
      recipientId: 'demo-user-id',
      actorId: 'user-3',
      actorUsername: 'marcus_code',
      actorFullName: 'Marcus Thorne',
      type: 'follow',
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  Future<List<NotificationModel>> getNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null && AppConfig.isSupabaseConfigured) return [];
      if (!AppConfig.isSupabaseConfigured) return _demoNotifications;

      final data = await _supabase
          .from('notifications')
          .select(
            '*, actor:profiles!notifications_actor_id_fkey(username, full_name, avatar_url)',
          )
          .eq('recipient_id', user!.id)
          .order('created_at', ascending: false)
          .limit(50);

      return (data as List<dynamic>)
          .map(
            (json) => NotificationModel.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      if (!AppConfig.isSupabaseConfigured) return _demoNotifications;
      throw ServerException('Failed to load notifications: ${e.toString()}');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      if (!AppConfig.isSupabaseConfigured) {
        final idx = _demoNotifications.indexWhere(
          (n) => n.id == notificationId,
        );
        if (idx != -1) {
          final old = _demoNotifications[idx];
          _demoNotifications[idx] = NotificationModel(
            id: old.id,
            recipientId: old.recipientId,
            actorId: old.actorId,
            actorUsername: old.actorUsername,
            actorFullName: old.actorFullName,
            actorAvatarUrl: old.actorAvatarUrl,
            type: old.type,
            relatedEntityId: old.relatedEntityId,
            isRead: true,
            createdAt: old.createdAt,
          );
        }
        return;
      }

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      throw ServerException(
        'Failed to mark notification as read: ${e.toString()}',
      );
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null && AppConfig.isSupabaseConfigured) return;
      if (!AppConfig.isSupabaseConfigured) {
        for (var i = 0; i < _demoNotifications.length; i++) {
          final old = _demoNotifications[i];
          _demoNotifications[i] = NotificationModel(
            id: old.id,
            recipientId: old.recipientId,
            actorId: old.actorId,
            actorUsername: old.actorUsername,
            actorFullName: old.actorFullName,
            actorAvatarUrl: old.actorAvatarUrl,
            type: old.type,
            relatedEntityId: old.relatedEntityId,
            isRead: true,
            createdAt: old.createdAt,
          );
        }
        return;
      }

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('recipient_id', user!.id)
          .eq('is_read', false);
    } catch (e) {
      throw ServerException(
        'Failed to mark all notifications as read: ${e.toString()}',
      );
    }
  }
}

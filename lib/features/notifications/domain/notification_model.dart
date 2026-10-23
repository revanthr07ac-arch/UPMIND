class NotificationModel {
  final String id;
  final String recipientId;
  final String? actorId;
  final String actorUsername;
  final String actorFullName;
  final String? actorAvatarUrl;
  final String type; // 'follow' | 'comment' | 'like' | 'learning_request_new' | 'learning_request_accepted' | 'learning_request_declined'
  final String? relatedEntityId;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.recipientId,
    this.actorId,
    required this.actorUsername,
    required this.actorFullName,
    this.actorAvatarUrl,
    required this.type,
    this.relatedEntityId,
    this.isRead = false,
    required this.createdAt,
  });

  String get title {
    switch (type) {
      case 'follow':
        return '$actorFullName started following you';
      case 'comment':
        return '$actorFullName commented on your post';
      case 'like':
        return '$actorFullName liked your post';
      case 'learning_request_new':
        return '$actorFullName sent you a learning request';
      case 'learning_request_accepted':
        return '$actorFullName accepted your learning request!';
      case 'learning_request_declined':
        return '$actorFullName declined your learning request';
      default:
        return 'New notification';
    }
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    return NotificationModel(
      id: json['id'] as String,
      recipientId: json['recipient_id'] as String,
      actorId: json['actor_id'] as String?,
      actorUsername: actor != null
          ? (actor['username'] as String? ?? 'user')
          : (json['actor_username'] as String? ?? 'user'),
      actorFullName: actor != null
          ? (actor['full_name'] as String? ?? 'Member')
          : (json['actor_full_name'] as String? ?? 'Member'),
      actorAvatarUrl: actor != null
          ? (actor['avatar_url'] as String?)
          : (json['actor_avatar_url'] as String?),
      type: json['type'] as String? ?? 'general',
      relatedEntityId: json['related_entity_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

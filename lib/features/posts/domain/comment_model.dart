class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String authorUsername;
  final String authorFullName;
  final String? authorAvatarUrl;
  final String content;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorUsername,
    required this.authorFullName,
    this.authorAvatarUrl,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final author = json['profiles'] as Map<String, dynamic>?;
    return CommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorId: json['author_id'] as String,
      authorUsername: author != null
          ? (author['username'] as String? ?? 'user')
          : (json['author_username'] as String? ?? 'user'),
      authorFullName: author != null
          ? (author['full_name'] as String? ?? 'Member')
          : (json['author_full_name'] as String? ?? 'Member'),
      authorAvatarUrl: author != null
          ? (author['avatar_url'] as String?)
          : (json['author_avatar_url'] as String?),
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

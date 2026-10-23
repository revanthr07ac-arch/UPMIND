class PostModel {
  final String id;
  final String authorId;
  final String authorUsername;
  final String authorFullName;
  final String? authorAvatarUrl;
  final String caption;
  final String? imageUrl;
  final String postType; // 'text' | 'image' | 'tutorial'
  final String? educationalDescription;
  final List<String> skillTags;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isSaved;
  final DateTime createdAt;

  const PostModel({
    required this.id,
    required this.authorId,
    required this.authorUsername,
    required this.authorFullName,
    this.authorAvatarUrl,
    required this.caption,
    this.imageUrl,
    this.postType = 'text',
    this.educationalDescription,
    this.skillTags = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    required this.createdAt,
  });

  bool get isTutorial => postType == 'tutorial';
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  factory PostModel.fromJson(
    Map<String, dynamic> json, {
    bool isLiked = false,
    bool isSaved = false,
  }) {
    final author = json['profiles'] as Map<String, dynamic>?;
    return PostModel(
      id: json['id'] as String,
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
      caption: json['caption'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      postType: json['post_type'] as String? ?? 'text',
      educationalDescription: json['educational_description'] as String?,
      skillTags:
          (json['skill_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      isLiked: isLiked,
      isSaved: isSaved,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  PostModel copyWith({
    String? id,
    String? authorId,
    String? authorUsername,
    String? authorFullName,
    String? authorAvatarUrl,
    String? caption,
    String? imageUrl,
    String? postType,
    String? educationalDescription,
    List<String>? skillTags,
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    bool? isSaved,
    DateTime? createdAt,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      authorFullName: authorFullName ?? this.authorFullName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      caption: caption ?? this.caption,
      imageUrl: imageUrl ?? this.imageUrl,
      postType: postType ?? this.postType,
      educationalDescription:
          educationalDescription ?? this.educationalDescription,
      skillTags: skillTags ?? this.skillTags,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

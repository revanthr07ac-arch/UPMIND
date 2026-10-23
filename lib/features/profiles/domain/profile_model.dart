class ProfileModel {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final List<String> interests;
  final String experienceLevel;
  final List<Map<String, dynamic>> portfolioLinks;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.bio,
    this.location,
    this.interests = const [],
    this.experienceLevel = 'beginner',
    this.portfolioLinks = const [],
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProfileModel.fromJson(
    Map<String, dynamic> json, {
    bool isFollowing = false,
  }) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'user',
      fullName: json['full_name'] as String? ?? 'Member',
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      interests:
          (json['interests'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      experienceLevel: json['experience_level'] as String? ?? 'beginner',
      portfolioLinks:
          (json['portfolio_links'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      isFollowing: isFollowing,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'location': location,
      'interests': interests,
      'experience_level': experienceLevel,
      'portfolio_links': portfolioLinks,
      'followers_count': followersCount,
      'following_count': followingCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProfileModel copyWith({
    String? id,
    String? username,
    String? fullName,
    String? avatarUrl,
    String? bio,
    String? location,
    List<String>? interests,
    String? experienceLevel,
    List<Map<String, dynamic>>? portfolioLinks,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      interests: interests ?? this.interests,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      portfolioLinks: portfolioLinks ?? this.portfolioLinks,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Program {
  final String slug;
  final String title;
  final String subtitle;
  final String summary;
  final String type;
  final String level;
  final String gender;
  final String frequency;
  final int weeksCount;
  final String coverImage;
  final List<String> tariffs;
  final bool guestAccess;
  final String authorName;
  final String authorRole;
  final String authorAvatar;

  Program({
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.type,
    required this.level,
    required this.gender,
    required this.frequency,
    required this.weeksCount,
    required this.coverImage,
    required this.tariffs,
    required this.guestAccess,
    required this.authorName,
    required this.authorRole,
    required this.authorAvatar,
  });

  factory Program.fromJson(Map<String, dynamic> json) {
    return Program(
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      level: (json['level'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      frequency: (json['frequency'] ?? '').toString(),
      weeksCount: (json['weeksCount'] ?? 0) is int
          ? json['weeksCount']
          : int.tryParse((json['weeksCount'] ?? '0').toString()) ?? 0,
      coverImage: (json['coverImage'] ?? '').toString(),
      tariffs: (json['tariffs'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      guestAccess: json['guestAccess'] == true,
      authorName: (json['authorName'] ?? '').toString(),
      authorRole: (json['authorRole'] ?? '').toString(),
      authorAvatar: (json['authorAvatar'] ?? '').toString(),
    );
  }
}

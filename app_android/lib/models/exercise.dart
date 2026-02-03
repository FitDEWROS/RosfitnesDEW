class Exercise {
  final int id;
  final String title;
  final String description;
  final String? details;
  final String? videoUrl;
  final String type;
  final List<String> muscles;
  final bool guestAccess;
  final String? crossfitType;

  Exercise({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.muscles,
    required this.guestAccess,
    this.details,
    this.videoUrl,
    this.crossfitType,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    final musclesRaw = json['muscles'];
    final muscle = json['muscle'];
    final list = <String>[];
    if (musclesRaw is List) {
      for (final item in musclesRaw) {
        if (item is String && item.trim().isNotEmpty) {
          list.add(item.trim());
        }
      }
    } else if (muscle is String && muscle.trim().isNotEmpty) {
      list.add(muscle.trim());
    }

    return Exercise(
      id: (json['id'] is int) ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      details: json['details']?.toString(),
      videoUrl: json['videoUrl']?.toString(),
      type: (json['type'] ?? 'gym').toString(),
      muscles: list,
      guestAccess: json['guestAccess'] == true,
      crossfitType: json['crossfitType']?.toString(),
    );
  }
}

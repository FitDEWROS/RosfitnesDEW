class Program {
  final String slug;
  final String title;
  final String subtitle;
  final String summary;
  final String description;
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
  final List<ProgramWeek> weeks;

  Program({
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.description,
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
    required this.weeks,
  });

  factory Program.fromJson(Map<String, dynamic> json) {
    return Program(
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      level: (json['level'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      frequency: (json['frequency'] ?? '').toString(),
      weeksCount: _asInt(json['weeksCount']),
      coverImage: (json['coverImage'] ?? '').toString(),
      tariffs: (json['tariffs'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      guestAccess: json['guestAccess'] == true,
      authorName: (json['authorName'] ?? '').toString(),
      authorRole: (json['authorRole'] ?? '').toString(),
      authorAvatar: (json['authorAvatar'] ?? '').toString(),
      weeks: (json['weeks'] as List?)
              ?.map((e) => ProgramWeek.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse((value ?? '0').toString()) ?? 0;
}

class ProgramWeek {
  final int index;
  final String title;
  final List<ProgramWorkout> workouts;

  ProgramWeek({
    required this.index,
    required this.title,
    required this.workouts,
  });

  factory ProgramWeek.fromJson(Map<String, dynamic> json) {
    return ProgramWeek(
      index: _asInt(json['index']),
      title: (json['title'] ?? '').toString(),
      workouts: (json['workouts'] as List?)
              ?.map((e) => ProgramWorkout.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class ProgramWorkout {
  final String id;
  final int index;
  final String title;
  final String description;
  final List<ProgramExercise> exercises;

  ProgramWorkout({
    required this.id,
    required this.index,
    required this.title,
    required this.description,
    required this.exercises,
  });

  factory ProgramWorkout.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    return ProgramWorkout(
      id: rawId == null ? '' : rawId.toString(),
      index: _asInt(json['index']),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      exercises: (json['exercises'] as List?)
              ?.map((e) => ProgramExercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class ProgramExercise {
  final int order;
  final String label;
  final String title;
  final String details;
  final String description;
  final String videoUrl;

  ProgramExercise({
    required this.order,
    required this.label,
    required this.title,
    required this.details,
    required this.description,
    required this.videoUrl,
  });

  factory ProgramExercise.fromJson(Map<String, dynamic> json) {
    return ProgramExercise(
      order: _asInt(json['order']),
      label: (json['label'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      details: (json['details'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      videoUrl: (json['videoUrl'] ?? '').toString(),
    );
  }
}

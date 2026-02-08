import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/program.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'program_week_screen.dart';

class ProgramDetailScreen extends StatefulWidget {
  const ProgramDetailScreen({super.key});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  final _api = ApiService();
  Future<Program?>? _future;
  String? _slug;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    String? slug;
    if (args is String) {
      slug = args;
    } else if (args is Map) {
      final raw = args['slug'];
      slug = raw == null ? null : raw.toString();
    }
    if (slug != _slug) {
      _slug = slug;
      _future = _load(slug);
    }
  }

  Future<Program?> _load(String? slug) async {
    if (slug == null || slug.isEmpty) return null;
    return _api.fetchProgramDetail(slug);
  }

  String _weeksLabel(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'недель';
    if (mod10 == 1) return 'неделя';
    if (mod10 >= 2 && mod10 <= 4) return 'недели';
    return 'недель';
  }

  String _workoutsLabel(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'тренировок';
    if (mod10 == 1) return 'тренировка';
    if (mod10 >= 2 && mod10 <= 4) return 'тренировки';
    return 'тренировок';
  }

  int _effectiveWeeksCount(Program program) {
    if (program.weeksCount > 0) return program.weeksCount;
    return program.weeks.length;
  }

  String _programTitle(Program program) {
    return program.title.isNotEmpty ? program.title : 'Программа';
  }

  String _programSubtitle(Program program) {
    if (program.subtitle.isNotEmpty) return program.subtitle;
    return program.summary;
  }

  String _programDescription(Program program) {
    if (program.description.isNotEmpty) return program.description;
    if (program.summary.isNotEmpty) return program.summary;
    return 'Описание скоро появится.';
  }

  String _typeLabel(Program program) {
    return program.type == 'crossfit' ? 'КРОССФИТ' : 'ЗАЛ';
  }

  String _coachName(Program program) {
    return program.authorName.isNotEmpty ? program.authorName : 'Команда Fit Dew';
  }

  String _coachRole(Program program) {
    return program.authorRole.isNotEmpty ? program.authorRole : 'Куратор Fit Dew';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Program?>(
          future: _future,
          builder: (context, snapshot) {
            if (_slug == null || _slug!.isEmpty) {
              return _EmptyState(
                title: 'Нет программы',
                subtitle: 'Ссылка на программу не найдена.',
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return _EmptyState(
                title: 'Не удалось загрузить программу',
                subtitle: 'Проверьте соединение и попробуйте ещё раз.',
              );
            }
            final program = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              children: [
                const SizedBox.shrink(),
                _PageHeader(
                  eyebrow: 'Программа',
                  title: _programTitle(program),
                  subtitle: _programSubtitle(program),
                ),
                const SizedBox(height: 16),
                _HeroCard(
                  title: _programTitle(program),
                  subtitle: _programSubtitle(program),
                  typeLabel: _typeLabel(program),
                  level: program.level,
                  gender: program.gender,
                  frequency: program.frequency,
                  weeksCount: _effectiveWeeksCount(program),
                  coverImage: program.coverImage,
                  coachName: _coachName(program),
                  coachRole: _coachRole(program),
                  coachAvatar: program.authorAvatar,
                  description: _programDescription(program),
                  weeksLabel: _weeksLabel,
                ),
                const SizedBox(height: 18),
                _PlanSection(
                  program: program,
                  weeks: program.weeks,
                  weeksCount: _effectiveWeeksCount(program),
                  weeksLabel: _weeksLabel,
                  workoutsLabel: _workoutsLabel,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  const _PageHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 2.6,
                color: AppTheme.mutedColor(context),
              ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(letterSpacing: 1.4),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.mutedColor(context)),
          ),
        ],
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String typeLabel;
  final String level;
  final String gender;
  final String frequency;
  final int weeksCount;
  final String coverImage;
  final String coachName;
  final String coachRole;
  final String coachAvatar;
  final String description;
  final String Function(int) weeksLabel;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.typeLabel,
    required this.level,
    required this.gender,
    required this.frequency,
    required this.weeksCount,
    required this.coverImage,
    required this.coachName,
    required this.coachRole,
    required this.coachAvatar,
    required this.description,
    required this.weeksLabel,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0]);
    final value = initials.join().toUpperCase();
    return value.isEmpty ? 'FD' : value;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final shadowColor = isDark ? Colors.black54 : Colors.black12;
    final tags = [
      typeLabel,
      if (level.isNotEmpty) level,
      if (gender.isNotEmpty) gender,
    ];
    final stats = [
      if (frequency.isNotEmpty) frequency,
      if (weeksCount > 0) '$weeksCount ${weeksLabel(weeksCount)}',
      if (level.isNotEmpty) level,
    ];
    final hasCover = coverImage.isNotEmpty;
    final titleColor = hasCover ? Colors.white : AppTheme.textColor(context);
    final subtitleColor = hasCover
        ? Colors.white70
        : AppTheme.textColor(context).withOpacity(0.75);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppTheme.cardColor(context),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 24,
            offset: Offset(0, 12),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasCover)
                    CachedNetworkImage(
                      imageUrl: coverImage,
                      fit: BoxFit.cover,
                      placeholder: (context, _) => Container(
                        color: AppTheme.cardColor(context),
                      ),
                      errorWidget: (context, _, __) => Container(
                        color: AppTheme.cardColor(context),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.accentColor(context).withOpacity(0.25),
                            AppTheme.cardColor(context),
                          ],
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.12),
                          Colors.black.withOpacity(isDark ? 0.75 : 0.55),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (tags.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in tags)
                                _TagChip(label: tag.toUpperCase()),
                            ],
                          ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(letterSpacing: 1.2, color: titleColor),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: subtitleColor),
                          ),
                        ],
                        if (stats.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final stat in stats)
                                _StatChip(label: stat.toUpperCase()),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _CoachAvatar(
                initials: _initials(coachName),
                avatarUrl: coachAvatar,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coachName,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      coachRole,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.mutedColor(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'О программе',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  letterSpacing: 2,
                  color: AppTheme.mutedColor(context),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.mutedColor(context), height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PlanSection extends StatelessWidget {
  final Program program;
  final List<ProgramWeek> weeks;
  final int weeksCount;
  final String Function(int) weeksLabel;
  final String Function(int) workoutsLabel;

  const _PlanSection({
    required this.program,
    required this.weeks,
    required this.weeksCount,
    required this.weeksLabel,
    required this.workoutsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppTheme.cardColor(context),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Тренировочный план',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(letterSpacing: 1.1),
              ),
              const Spacer(),
              if (weeksCount > 0)
                Text(
                  '$weeksCount ${weeksLabel(weeksCount)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.mutedColor(context)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (weeks.isEmpty)
            Text(
              'План скоро появится.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.mutedColor(context)),
            )
          else
            Column(
              children: [
                for (var i = 0; i < weeks.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WeekCard(
                      title: weeks[i].title.isNotEmpty
                          ? weeks[i].title
                          : 'Неделя ${weeks[i].index > 0 ? weeks[i].index : i + 1}',
                      subtitle: weeks[i].workouts.isNotEmpty
                          ? '${weeks[i].workouts.length} ${workoutsLabel(weeks[i].workouts.length)}'
                          : 'Планируется',
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/program_week',
                        arguments: ProgramWeekArgs(
                          program: program,
                          weekIndex: i,
                        ),
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

class _WeekCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _WeekCard({
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final tileColor =
        isDark ? Colors.white10 : AppTheme.cardColor(context).withOpacity(0.95);
    final iconBg =
        isDark ? Colors.white12 : Colors.black12.withOpacity(0.12);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: tileColor,
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.mutedColor(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBg,
              ),
              child: Icon(
                Icons.chevron_right,
                color: AppTheme.mutedColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final chipBg = Colors.black.withOpacity(isDark ? 0.55 : 0.45);
    final chipBorder = Colors.transparent;
    final chipText = Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: chipBg,
        border: Border.all(color: chipBorder),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(letterSpacing: 1.1, color: chipText),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  const _StatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final chipBg = Colors.black.withOpacity(isDark ? 0.45 : 0.35);
    final chipBorder = Colors.transparent;
    final chipText = Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: chipBg,
        border: Border.all(color: chipBorder),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(letterSpacing: 1.1, color: chipText),
      ),
    );
  }
}

class _CoachAvatar extends StatelessWidget {
  final String initials;
  final String avatarUrl;
  const _CoachAvatar({required this.initials, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    if (avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          placeholder: (context, _) => Container(
            width: 44,
            height: 44,
            color: AppTheme.cardColor(context),
          ),
          errorWidget: (context, _, __) => Container(
            width: 44,
            height: 44,
            color: AppTheme.cardColor(context),
          ),
        ),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.accentColor(context)),
        color: isDark ? Colors.black26 : Colors.white,
      ),
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: AppTheme.accentColor(context)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(letterSpacing: 0.8),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.mutedColor(context)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/program.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  late Future<List<Program>> _future;
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _future = _api.fetchPrograms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Program>>(
          future: _future,
          builder: (context, snapshot) {
            final programs = snapshot.data ?? const <Program>[];
            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const SizedBox.shrink(),
                const SizedBox(height: 12),
                _HeaderCard(),
                const SizedBox(height: 20),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator()),
                if (snapshot.hasError)
                  _EmptyState(
                    title: 'Не удалось загрузить программы',
                    subtitle: 'Проверьте соединение и повторите попытку.',
                  ),
                if (snapshot.connectionState == ConnectionState.done &&
                    programs.isEmpty)
                  _EmptyState(
                    title: 'Пока нет программ',
                    subtitle: 'Скоро появятся новые планы.',
                  ),
                for (final program in programs) _ProgramCard(program: program),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Программы',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(
                  letterSpacing: 2.6,
                  color: AppTheme.mutedColor(context),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Планы тренировок',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(letterSpacing: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Выбери формат и стартуй сегодня.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.mutedColor(context)),
          ),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final Program program;
  const _ProgramCard({required this.program});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final shadowColor = isDark ? Colors.black54 : Colors.black12;
    final tags = [
      program.type.isNotEmpty
          ? (program.type == 'gym' ? 'ЗАЛ' : 'КРОССФИТ')
          : 'ПРОГРАММА',
      if (program.level.isNotEmpty) program.level,
      if (program.gender.isNotEmpty) program.gender,
    ];
    final stats = [
      if (program.frequency.isNotEmpty) program.frequency,
      if (program.weeksCount > 0) '${program.weeksCount} неделя',
      if (program.level.isNotEmpty) program.level,
    ];

    final canOpen = program.slug.isNotEmpty;
    final hasCover = program.coverImage.isNotEmpty;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          letterSpacing: 1.2,
          color: hasCover ? Colors.white : null,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: hasCover ? Colors.white70 : AppTheme.mutedColor(context),
        );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              _Chip(label: tag.toUpperCase(), onMedia: hasCover),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          program.title.isNotEmpty ? program.title : 'Программа',
          style: titleStyle,
        ),
        const SizedBox(height: 6),
        Text(
          program.subtitle.isNotEmpty ? program.subtitle : program.summary,
          style: subtitleStyle,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final stat in stats)
              _Chip(label: stat.toUpperCase(), onMedia: hasCover),
          ],
        ),
      ],
    );
    return InkWell(
      onTap: canOpen
          ? () =>
              Navigator.pushNamed(context, '/program', arguments: program.slug)
          : null,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: hasCover ? EdgeInsets.zero : const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
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
        child: hasCover
            ? ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl: program.coverImage,
                        fit: BoxFit.cover,
                        placeholder: (context, _) => Container(
                          color: AppTheme.cardColor(context),
                        ),
                        errorWidget: (context, _, __) => Container(
                          color: AppTheme.cardColor(context),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
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
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: content,
                    ),
                  ],
                ),
              )
            : content,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool onMedia;
  const _Chip({required this.label, this.onMedia = false});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final onMediaBg = Colors.black.withOpacity(isDark ? 0.55 : 0.45);
    final onMediaText = Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: onMedia
            ? onMediaBg
            : (isDark ? Colors.white10 : Colors.black12.withOpacity(0.08)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(letterSpacing: 1.2, color: onMedia ? onMediaText : null),
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
    final isDark = AppTheme.isDark(context);
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, style: BorderStyle.solid),
        color: AppTheme.cardColor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.mutedColor(context)),
          ),
        ],
      ),
    );
  }
}

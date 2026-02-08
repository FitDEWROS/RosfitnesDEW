import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import '../models/program.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../services/video_cache_service.dart';

class ProgramWeekScreen extends StatefulWidget {
  const ProgramWeekScreen({super.key});

  @override
  State<ProgramWeekScreen> createState() => _ProgramWeekScreenState();
}

class _ProgramWeekScreenState extends State<ProgramWeekScreen> {
  final _api = ApiService();
  Program? _program;
  int _weekIndex = 0;
  int _selectedWorkoutIndex = 0;
  bool _loading = true;
  String? _slug;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    Program? program;
    int? weekIndex;
    String? slug;
    if (args is Map) {
      final rawProgram = args['program'];
      if (rawProgram is Program) program = rawProgram;
      final rawWeek = args['weekIndex'];
      if (rawWeek is int) weekIndex = rawWeek;
      if (rawWeek is String) weekIndex = int.tryParse(rawWeek);
      final rawSlug = args['slug'];
      if (rawSlug != null) slug = rawSlug.toString();
    }
    if (args is ProgramWeekArgs) {
      program = args.program;
      weekIndex = args.weekIndex;
      slug = args.slug;
    }

    weekIndex ??= 0;
    if (weekIndex != _weekIndex) {
      _weekIndex = weekIndex;
    }

    if (program != null) {
      _program = program;
      _loading = false;
      _selectedWorkoutIndex = 0;
      return;
    }
    if (slug != null && slug != _slug) {
      _slug = slug;
      _load(slug);
    }
  }

  Future<void> _load(String slug) async {
    setState(() => _loading = true);
    try {
      final program = await _api.fetchProgramDetail(slug);
      if (!mounted) return;
      setState(() {
        _program = program;
        _loading = false;
        _selectedWorkoutIndex = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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

  String _programLine(Program program, ProgramWeek week) {
    final weekNumber = week.index > 0 ? week.index : _weekIndex + 1;
    final pieces = <String>[
      'Неделя $weekNumber',
      program.title.isNotEmpty ? program.title : 'Программа',
    ];
    if (program.level.isNotEmpty) {
      pieces.add(program.level);
    } else if (program.type.isNotEmpty) {
      pieces.add(program.type == 'crossfit' ? 'Кроссфит' : 'Зал');
    }
    return pieces.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _program == null
                ? _EmptyState(
                    title: 'Не удалось загрузить план',
                    subtitle: 'Попробуйте позже.',
                  )
                : _buildContent(context, _program!),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Program program) {
    if (program.weeks.isEmpty) {
      return _EmptyState(
        title: 'План пока недоступен',
        subtitle: 'Тренировочная программа появится позже.',
      );
    }
    final week = _weekIndex >= 0 && _weekIndex < program.weeks.length
        ? program.weeks[_weekIndex]
        : program.weeks.first;
    final workouts = week.workouts;
    final selectedIndex = _selectedWorkoutIndex.clamp(
      0,
      workouts.isEmpty ? 0 : workouts.length - 1,
    );
    final selectedWorkout =
        workouts.isEmpty ? null : workouts[selectedIndex];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        const SizedBox.shrink(),
        Center(
          child: Text(
            workouts.isEmpty ? 'ТРЕНИРОВКА' : 'ДЕНЬ ${selectedIndex + 1}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(letterSpacing: 2),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _programLine(program, week),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.mutedColor(context)),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Тренировочный план',
          trailing: week.workouts.isNotEmpty
              ? '${week.workouts.length} ${_workoutsLabel(week.workouts.length)}'
              : null,
          child: workouts.isEmpty
              ? Text(
                  'Тренировки пока не добавлены.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.mutedColor(context)),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: workouts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.25,
                  ),
                  itemBuilder: (context, index) {
                    final workout = workouts[index];
                    final isActive = index == selectedIndex;
                    return _WorkoutTile(
                      index: index + 1,
                      title: workout.title.isNotEmpty
                          ? workout.title
                          : 'Тренировка ${index + 1}',
                      subtitle: workout.exercises.isNotEmpty
                          ? '${workout.exercises.length} ${_workoutsLabel(workout.exercises.length)}'
                          : 'Планируется',
                      isActive: isActive,
                      onTap: () => setState(
                        () => _selectedWorkoutIndex = index,
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        if (selectedWorkout != null)
          _SectionCard(
            title: 'Тренировочный процесс',
            child: selectedWorkout.exercises.isEmpty
                ? Text(
                    'Упражнения появятся позже.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.mutedColor(context)),
                  )
                : Column(
                    children: [
                      for (final ex in selectedWorkout.exercises)
                        _ExerciseTile(
                          exercise: ex,
                          index: ex.order > 0
                              ? ex.order
                              : selectedWorkout.exercises.indexOf(ex) + 1,
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}

class ProgramWeekArgs {
  final Program? program;
  final String? slug;
  final int weekIndex;
  const ProgramWeekArgs({
    this.program,
    this.slug,
    required this.weekIndex,
  });
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
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
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(letterSpacing: 1.1),
              ),
              const Spacer(),
              if (trailing != null)
                Text(
                  trailing!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.mutedColor(context)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;
  const _WorkoutTile({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final activeBg =
        isDark ? Colors.black45 : AppTheme.accentColor(context).withOpacity(0.18);
    final tileBg =
        isDark ? Colors.white10 : AppTheme.cardColor(context).withOpacity(0.95);
    final badgeBg = isDark ? Colors.white12 : Colors.black12.withOpacity(0.12);
    final badgeBorder = isDark ? Colors.white24 : Colors.black26;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isActive ? activeBg : tileBg,
          border: Border.all(
            color: isActive ? AppTheme.accentColor(context) : borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: badgeBg,
                border: Border.all(color: badgeBorder),
              ),
              child: Text(
                index.toString().padLeft(2, '0'),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(letterSpacing: 1.1),
              ),
            ),
            const Spacer(),
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
    );
  }
}

class _ExerciseTile extends StatefulWidget {
  final ProgramExercise exercise;
  final int index;
  const _ExerciseTile({required this.exercise, required this.index});

  @override
  State<_ExerciseTile> createState() => _ExerciseTileState();
}

class _ExerciseTileState extends State<_ExerciseTile> {
  final _api = ApiService();
  bool _expanded = false;
  bool _showVideo = false;
  bool _done = false;
  bool _loadingVideo = false;
  VideoPlayerController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool get _hasVideo {
    return widget.exercise.videoUrl.isNotEmpty;
  }

  String get _title {
    if (widget.exercise.title.isNotEmpty) return widget.exercise.title;
    if (widget.exercise.label.isNotEmpty) return widget.exercise.label;
    return 'Упражнение';
  }

  String get _details {
    if (widget.exercise.details.isNotEmpty) return widget.exercise.details;
    return '';
  }

  String get _description {
    if (widget.exercise.description.isNotEmpty) return widget.exercise.description;
    return widget.exercise.details;
  }

  Future<void> _initVideo() async {
    if (_loadingVideo || !_hasVideo) return;
    setState(() => _loadingVideo = true);
    try {
      final cached =
          await VideoCacheService.instance.getCachedFile(widget.exercise.videoUrl);
      VideoPlayerController controller;
      if (cached != null) {
        controller = VideoPlayerController.file(File(cached.path));
      } else {
        final resolved =
            await _api.resolveVideoUrl(widget.exercise.videoUrl) ??
                _api.normalizeVideoUrl(widget.exercise.videoUrl);
        final safe = _api.safeVideoUrl(resolved);
        controller = VideoPlayerController.networkUrl(Uri.parse(safe));
      }
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller?.dispose();
        _controller = controller;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _controller?.dispose();
        _controller = null;
      });
    } finally {
      if (mounted) setState(() => _loadingVideo = false);
    }
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  void _toggleVideo() {
    if (!_hasVideo) return;
    setState(() => _showVideo = !_showVideo);
    if (_showVideo && _controller == null) {
      _initVideo();
    } else if (!_showVideo) {
      _controller?.pause();
    }
  }

  void _toggleDone() {
    setState(() => _done = !_done);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final tileBg =
        isDark ? Colors.white10 : AppTheme.cardColor(context).withOpacity(0.95);
    final chipBorder = isDark ? Colors.white24 : Colors.black26;
    final buttonBg = isDark
        ? Colors.white12
        : AppTheme.accentColor(context).withOpacity(0.9);
    final buttonText = isDark ? Colors.white : Colors.black;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: tileBg,
        border: Border.all(
          color: _done ? AppTheme.green.withOpacity(0.6) : borderColor,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: chipBorder),
                  ),
                  child: Text(
                    widget.index.toString(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_details.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _details,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.mutedColor(context)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: AppTheme.mutedColor(context),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            crossFadeState:
                _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_description.isNotEmpty)
                    Text(
                      _description,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.mutedColor(context), height: 1.5),
                    )
                  else
                    Text(
                      'Описание появится позже.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.mutedColor(context)),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      InkWell(
                        onTap: _toggleVideo,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 38,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: _hasVideo ? buttonBg : tileBg,
                            border: Border.all(
                              color: _hasVideo ? chipBorder : borderColor,
                            ),
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: _hasVideo
                                ? AppTheme.mutedColor(context)
                                : (isDark ? Colors.white38 : Colors.black45),
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _toggleDone,
                        style: TextButton.styleFrom(
                          backgroundColor: buttonBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          _done ? 'Готово' : 'Выполнил',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(letterSpacing: 1.1, color: buttonText),
                        ),
                      ),
                    ],
                  ),
                  if (_showVideo) ...[
                    const SizedBox(height: 12),
                    _VideoPanel(
                      controller: _controller,
                      loading: _loadingVideo,
                      enabled: _hasVideo,
                      onTogglePlay: () {
                        if (_controller == null) return;
                        setState(() {
                          if (_controller!.value.isPlaying) {
                            _controller!.pause();
                          } else {
                            _controller!.play();
                          }
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _VideoPanel extends StatelessWidget {
  final VideoPlayerController? controller;
  final bool loading;
  final bool enabled;
  final VoidCallback onTogglePlay;
  const _VideoPanel({
    required this.controller,
    required this.loading,
    required this.enabled,
    required this.onTogglePlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : !enabled
                ? Center(
                    child: Text(
                      'Видео пока не добавлено.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  )
                : controller != null && controller!.value.isInitialized
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: AspectRatio(
                              aspectRatio: controller!.value.aspectRatio,
                              child: VideoPlayer(controller!),
                            ),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: IconButton(
                                iconSize: 48,
                                color: Colors.white70,
                                icon: Icon(
                                  controller!.value.isPlaying
                                      ? Icons.pause_circle
                                      : Icons.play_circle,
                                ),
                                onPressed: onTogglePlay,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 48,
                          color: Colors.white54,
                        ),
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

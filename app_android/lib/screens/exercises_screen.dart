import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';
import '../theme.dart';
import '../models/exercise.dart';
import '../services/api_service.dart';
import 'exercise_detail_screen.dart';

enum GymViewMode { silhouette, list }
enum BodySide { front, back }

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final _api = ApiService();
  GymViewMode _mode = GymViewMode.list;
  BodySide _side = BodySide.front;
  final TextEditingController _searchController = TextEditingController();
  int _cols = 2;
  List<Exercise> _all = [];
  List<Exercise> _filtered = [];
  bool _loading = true;

  SvgMuscleData? _frontData;
  SvgMuscleData? _backData;
  String? _selectedGroup;
  List<Exercise> _groupExercises = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadSvg();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _api.fetchExercises(type: 'gym');
      if (!mounted) return;
      setState(() {
        _all = data;
        _filtered = data;
        _loading = false;
      });
      _refreshGroupExercises();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadSvg() async {
    final front = await _parseSvg('assets/front.svg');
    final back = await _parseSvg('assets/back.svg');
    if (!mounted) return;
    setState(() {
      _frontData = front;
      _backData = back;
    });
  }

  Future<SvgMuscleData?> _parseSvg(String assetPath) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final doc = XmlDocument.parse(raw);
      final svg = doc.rootElement;
      final viewBox = svg.getAttribute('viewBox') ?? '';
      final parts = viewBox.split(RegExp(r'[ ,]+')).where((e) => e.isNotEmpty).toList();
      if (parts.length < 4) return null;
      final vbX = double.tryParse(parts[0]) ?? 0;
      final vbY = double.tryParse(parts[1]) ?? 0;
      final vbW = double.tryParse(parts[2]) ?? 1;
      final vbH = double.tryParse(parts[3]) ?? 1;

      final paths = <MusclePath>[];
      for (final node in svg.descendants.whereType<XmlElement>()) {
        if (node.name.local != 'path') continue;
        final cls = node.getAttribute('class') ?? '';
        if (!cls.split(' ').contains('muscle')) continue;
        final id = node.getAttribute('id') ?? '';
        final d = node.getAttribute('d') ?? '';
        if (d.isEmpty) continue;
        final path = parseSvgPathData(d);
        final group = findGroup(id) ?? id;
        paths.add(MusclePath(id: id, group: group, path: path));
      }

      return SvgMuscleData(
        viewBox: Rect.fromLTWH(vbX, vbY, vbW, vbH),
        paths: paths,
      );
    } catch (_) {
      return null;
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() => _filtered = _all);
      return;
    }
    setState(() {
      _filtered = _all.where((ex) {
        final hay = '${ex.title} ${ex.description} ${ex.details ?? ''}'.toLowerCase();
        return hay.contains(query);
      }).toList();
    });
  }

  void _refreshGroupExercises() {
    final group = _selectedGroup;
    if (group == null) return;
    final name = humanName(group).toLowerCase();
    final nameNorm = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    final direct = _all.where((ex) {
      final muscles = ex.muscles.map((m) => m.toLowerCase()).toList();
      return muscles.any((m) => m == nameNorm);
    }).toList();

    if (direct.isNotEmpty) {
      setState(() => _groupExercises = direct);
      return;
    }

    final keywords = muscleKeywords[group] ?? [];
    if (keywords.isEmpty) {
      setState(() => _groupExercises = []);
      return;
    }

    final matches = _all.where((ex) {
      final hay = '${ex.title} ${ex.description}'.toLowerCase();
      return keywords.any((k) => hay.contains(k));
    }).toList();
    setState(() => _groupExercises = matches);
  }

  void _handleTap(Offset localPos, Size size) {
    final data = _side == BodySide.front ? _frontData : _backData;
    if (data == null) return;
    final vb = data.viewBox;
    final scale = math.min(size.width / vb.width, size.height / vb.height);
    final dx = (size.width - vb.width * scale) / 2;
    final dy = (size.height - vb.height * scale) / 2;
    final sx = (localPos.dx - dx) / scale + vb.left;
    final sy = (localPos.dy - dy) / scale + vb.top;
    final point = Offset(sx, sy);

    for (final p in data.paths) {
      if (p.path.contains(point)) {
        setState(() => _selectedGroup = p.group);
        _refreshGroupExercises();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _side == BodySide.front ? _frontData : _backData;
    final screenWidth = MediaQuery.of(context).size.width;
    final gridPadding = 36.0;
    final tileWidth =
        (screenWidth - gridPadding - 14 * (_cols - 1)) / _cols;
    final thumbMaxWidth =
        (tileWidth * MediaQuery.of(context).devicePixelRatio).round();
    final previewHeight = _cols == 1 ? 150.0 : 160.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppTheme.backgroundGradient(context),
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox.shrink()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: AppTheme.cardColor(context),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      letterSpacing: 2.6,
                                      color: AppTheme.mutedColor(context),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(letterSpacing: 1.2),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ' ',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      letterSpacing: 1.8,
                                      color: AppTheme.mutedColor(context),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        _TogglePill(
                          left: '',
                          right: '',
                          isRightActive: _mode == GymViewMode.list,
                          onLeft: () => setState(() => _mode = GymViewMode.silhouette),
                          onRight: () => setState(() => _mode = GymViewMode.list),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_mode == GymViewMode.list) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor(context),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search,
                                    size: 18,
                                    color: AppTheme.mutedColor(context)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: ' ',
                                      hintStyle: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppTheme.mutedColor(context),
                                          ),
                                      border: InputBorder.none,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: AppTheme.textColor(context)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _CircleBadge(
                          value: '$_cols',
                          onTap: () => setState(() => _cols = _cols == 2 ? 1 : 2),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _filtered[index];
                          return _ExerciseCard(
                            title: item.title,
                            subtitle: '\u041E\u0422\u041A\u0420\u042B\u0422\u042C\n\u041E\u041F\u0418\u0421\u0410\u041D\u0418\u0415',
                            hasVideo: (item.videoUrl ?? '').isNotEmpty,
                            videoUrl: item.videoUrl,
                            thumbMaxWidth: thumbMaxWidth,
                            previewHeight: previewHeight,
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                child: ExerciseDetailScreen(exercise: item, asModal: true),
                              ),
                            ),
                          );
                        },
                        childCount: _filtered.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _cols,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: _cols == 1 ? 0.9 : 0.6,
                      ),
                    ),
                  ),
              ] else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: _TogglePill(
                      left: ' ',
                      right: ' ',
                      isRightActive: _side == BodySide.back,
                      onLeft: () => setState(() => _side = BodySide.front),
                      onRight: () => setState(() => _side = BodySide.back),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boxSize = Size(constraints.maxWidth, 520);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) =>
                              _handleTap(details.localPosition, boxSize),
                          child: Stack(
                            children: [
                              SizedBox(
                                height: boxSize.height,
                                width: boxSize.width,
                                child: data == null
                                    ? const Center(child: CircularProgressIndicator())
                                    : SvgPicture.asset(
                                        _side == BodySide.front
                                            ? 'assets/front.svg'
                                            : 'assets/back.svg',
                                        fit: BoxFit.contain,
                                      ),
                              ),
                              if (data != null && _selectedGroup != null)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: MuscleHighlightPainter(
                                        data: data,
                                        selectedGroup: _selectedGroup!,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: AppTheme.cardColor(context),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedGroup != null
                                ? humanName(_selectedGroup!)
                                : ' ',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(letterSpacing: 1.1),
                          ),
                          const SizedBox(height: 10),
                          if (_selectedGroup == null)
                            Text(
                              '   ,   .',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppTheme.mutedColor(context)),
                            )
                          else if (_groupExercises.isEmpty)
                            Text(
                              '    .',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppTheme.mutedColor(context)),
                            )
                          else
                            Column(
                              children: _groupExercises.take(3).map((ex) {
                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: Colors.black12,
                                  ),
                                  child: Text(
                                    ex.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.white70),
                                  ),
                                );
                              }).toList(),
                            )
                        ],
                      ),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

class MusclePath {
  final String id;
  final String group;
  final Path path;
  MusclePath({required this.id, required this.group, required this.path});
}

class SvgMuscleData {
  final Rect viewBox;
  final List<MusclePath> paths;
  SvgMuscleData({required this.viewBox, required this.paths});
}

class MuscleHighlightPainter extends CustomPainter {
  final SvgMuscleData data;
  final String selectedGroup;
  MuscleHighlightPainter({required this.data, required this.selectedGroup});

  @override
  void paint(Canvas canvas, Size size) {
    final vb = data.viewBox;
    final scale = math.min(size.width / vb.width, size.height / vb.height);
    final dx = (size.width - vb.width * scale) / 2;
    final dy = (size.height - vb.height * scale) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = const Color(0xCC8B5CF6)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFFB993FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 / scale;
    for (final p in data.paths.where((p) => p.group == selectedGroup)) {
      canvas.drawPath(p.path, paint);
      canvas.drawPath(p.path, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

String? findGroup(String id) {
  for (final entry in muscleGroups.entries) {
    if (entry.value.contains(id)) return entry.key;
  }
  return null;
}

String humanName(String key) {
  return muscleNames[key] ?? key;
}

final Map<String, List<String>> muscleGroups = {
  'traps': ['traps-left', 'traps-left1', 'traps-right', 'traps-right1'],
  'chest': ['chest-left', 'chest-right'],
  'delts': ['delts-left', 'delts-left1', 'delts-right', 'delts-right1'],
  'biceps': ['biceps-left', 'biceps-right'],
  'forearm': [
    'forearm-left-1',
    'forearm-left-2',
    'forearm-left-3',
    'forearm-left-4',
    'forearm-left-5',
    'forearm-left-6',
    'forearm-left-7',
    'forearm-right-1',
    'forearm-right-2',
    'forearm-right-3',
    'forearm-right-4',
    'forearm-right-5',
    'forearm-right-6',
    'forearm-right-7'
  ],
  'abs': ['abs-1', 'abs-2', 'abs-3', 'abs-4', 'abs-5', 'abs-6', 'abs-7', 'abs-8'],
  'quads': ['quads-left-1', 'quads-left-2', 'quads-right-1', 'quads-right-2'],
  'adductors': [
    'adductors-left-1',
    'adductors-left-2',
    'adductors-right-1',
    'adductors-right-2'
  ],
  'tibialis': [
    'tibialis-left-1',
    'tibialis-left-2',
    'tibialis-left-3',
    'tibialis-right-1',
    'tibialis-right-2',
    'tibialis-right-3'
  ],
  'upperBack': [
    'upper-back-left-1',
    'upper-back-left-2',
    'upper-back-left-3',
    'upper-back-right-1',
    'upper-back-right-2',
    'upper-back-right-3'
  ],
  'triceps': [
    'triceps-left-1',
    'triceps-left-2',
    'triceps-left-3',
    'triceps-right-1',
    'triceps-right-2',
    'triceps-right-3'
  ],
  'lats': ['lats-left', 'lats-left-1', 'lats-right', 'lats-right-1'],
  'erectors': ['lower-back-left', 'lower-back-right'],
  'glutes': ['glutes-left', 'glutes-right'],
  'hams': ['hams-left', 'hams-right'],
  'calves': ['calves-left-1', 'calves-left-2', 'calves-right-1', 'calves-right-2'],
};

final Map<String, String> muscleNames = {
  'traps': ' ',
  'chest': '  ',
  'delts': ' ',
  'biceps': '   ()',
  'forearm': ' ',
  'abs': '  ',
  'quads': ' ',
  'adductors': ' ',
  'tibialis': '   ',
  'upperBack': '  ',
  'triceps': '   ()',
  'lats': '  ',
  'erectors': '  ',
  'glutes': '  ',
  'hams': ' (  )',
  'calves': ' ',
};

final Map<String, List<String>> muscleKeywords = {
  'traps': ['', '', ''],
  'chest': ['', '', '', ''],
  'delts': ['', '', '', ''],
  'biceps': ['', '', '', ''],
  'forearm': ['', '', ''],
  'abs': ['', '', '', ''],
  'quads': ['', '', '', ' '],
  'adductors': ['', '', ''],
  'tibialis': ['', '', ''],
  'upperBack': [' ', '', '', ' ', ' '],
  'triceps': ['', '', ''],
  'lats': ['', '', ' ', '  '],
  'erectors': ['', ' ', '', ''],
  'glutes': ['', '', ''],
  'hams': ['', ' ', '', ''],
  'calves': ['', ''],
};

class _TogglePill extends StatelessWidget {
  final String left;
  final String right;
  final bool isRightActive;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  const _TogglePill({
    required this.left,
    required this.right,
    required this.isRightActive,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppTheme.cardColor(context),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onLeft,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: isRightActive
                    ? Colors.transparent
                    : AppTheme.accentColor(context),
              ),
              child: Text(
                left,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.6,
                      color: isRightActive ? Colors.white70 : Colors.black,
                    ),
              ),
            ),
          ),
          InkWell(
            onTap: onRight,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: isRightActive
                    ? AppTheme.accentColor(context)
                    : Colors.transparent,
              ),
              child: Text(
                right,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.6,
                      color: isRightActive ? Colors.black : Colors.white70,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBadge extends StatelessWidget {
  final String value;
  final VoidCallback? onTap;
  const _CircleBadge({required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.accentColor(context),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentColor(context).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Center(
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.black, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool hasVideo;
  final String? videoUrl;
  final int thumbMaxWidth;
  final double previewHeight;
  final VoidCallback onTap;
  const _ExerciseCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.hasVideo,
    required this.videoUrl,
    required this.thumbMaxWidth,
    required this.previewHeight,
  });

  @override
  Widget build(BuildContext context) {
    final previewHeightPx =
        (previewHeight * MediaQuery.of(context).devicePixelRatio).round();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppTheme.cardColor(context),
          border: Border.all(color: Colors.white10),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 16,
              offset: Offset(0, 8),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: previewHeight,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasVideo && (videoUrl ?? '').isNotEmpty)
                      _VideoThumb(
                        key: ValueKey('${videoUrl}_${thumbMaxWidth}_${previewHeightPx}'),
                        url: videoUrl!,
                        maxWidth: thumbMaxWidth,
                        maxHeight: previewHeightPx,
                      )
                    else
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF2B2B2F),
                              Color(0xFF111214),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(letterSpacing: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          letterSpacing: 1.6,
                          color: AppTheme.mutedColor(context),
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}




class _VideoThumb extends StatefulWidget {
  final String url;
  final int maxWidth;
  final int maxHeight;
  const _VideoThumb({
    super.key,
    required this.url,
    required this.maxWidth,
    required this.maxHeight,
  });

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  static final Map<String, Uint8List> _memCache = {};
  static final Set<String> _failed = {};
  static Future<Directory>? _dirFuture;
  final _api = ApiService();
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _VideoThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.maxHeight != widget.maxHeight) {
      _bytes = null;
      _load();
    }
  }

  String _cacheKey(String url) {
    return md5
        .convert(utf8.encode('$url|${widget.maxWidth}|${widget.maxHeight}'))
        .toString();
  }

  Future<File> _cacheFile(String key) async {
    _dirFuture ??= getTemporaryDirectory();
    final dir = await _dirFuture!;
    return File('${dir.path}\\thumb_$key.jpg');
  }

  Future<void> _load() async {
    try {
      final normalized = _api.normalizeVideoUrl(widget.url);
      if (normalized.isEmpty) return;
      final key = _cacheKey(normalized);
      if (_failed.contains(key)) return;

      final mem = _memCache[key];
      if (mem != null) {
        if (mounted) setState(() => _bytes = mem);
        return;
      }

      final file = await _cacheFile(key);
      if (await file.exists()) {
        final data = await file.readAsBytes();
        if (data.isNotEmpty) {
          _memCache[key] = data;
          if (mounted) setState(() => _bytes = data);
          return;
        }
      }

      final safeUrl = _api.safeVideoUrl(widget.url);
      final data = await VideoThumbnail.thumbnailData(
        video: safeUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
        quality: 40,
        timeMs: 200,
      );
      if (!mounted) return;
      if (data == null) {
        _failed.add(key);
        return;
      }
      _memCache[key] = data;
      _bytes = data;
      setState(() {});
      try {
        await file.writeAsBytes(data, flush: true);
      } catch (_) {}
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2B2B2F),
              Color(0xFF111214),
            ],
          ),
        ),
      );
    }
    return Image.memory(_bytes!, fit: BoxFit.cover);
  }
}

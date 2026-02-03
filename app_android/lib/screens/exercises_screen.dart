import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _ExercisesScreenState extends State<ExercisesScreen>
    with TickerProviderStateMixin {
  final _api = ApiService();
  GymViewMode _mode = GymViewMode.list;
  BodySide _side = BodySide.front;
  final TextEditingController _searchController = TextEditingController();
  int _cols = 2;
  List<Exercise> _all = [];
  List<Exercise> _filtered = [];
  bool _loading = true;
  late final AnimationController _pulseController;
  late final Animation<double> _pulse;
  late final AnimationController _headerController;
  late final Animation<double> _headerShift;

  SvgMuscleData? _frontData;
  SvgMuscleData? _backData;
  String? _selectedGroup;
  List<Exercise> _groupExercises = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat(reverse: true);
    _headerShift =
        CurvedAnimation(parent: _headerController, curve: Curves.easeInOut);
    _loadPrefs();
    _load();
    _loadSvg();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _headerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildHeaderCard(BuildContext context, Widget child) {
    final radius = BorderRadius.circular(20);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: AppTheme.cardColor(context)),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _headerShift,
                builder: (context, _) {
                  final t = _headerShift.value;
                  final isLight =
                      Theme.of(context).brightness == Brightness.light;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.1 + 2.2 * t, -0.7),
                        end: Alignment(1.1 - 2.2 * t, 0.85),
                        colors: [
                          const Color(0xFFC9A76A)
                              .withOpacity(isLight ? 0.24 : 0.18),
                          AppTheme.accentColor(context)
                              .withOpacity(isLight ? 0.18 : 0.12),
                          const Color(0xFF6A5B3D)
                              .withOpacity(isLight ? 0.18 : 0.14),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _headerShift,
                builder: (context, _) {
                  final t = _headerShift.value;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0.3 + 0.5 * t, 1.1),
                        radius: 1.1,
                        colors: [
                          AppTheme.accentColor(context).withOpacity(0.16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: child,
            ),
          ],
        ),
      ),
    );
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

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final mode = prefs.getString('gym_view_mode');
      if (mode == 'silhouette') _mode = GymViewMode.silhouette;
      if (mode == 'list') _mode = GymViewMode.list;
      final side = prefs.getString('gym_body_side');
      if (side == 'back') _side = BodySide.back;
      if (side == 'front') _side = BodySide.front;
      final cols = prefs.getInt('gym_cols');
      if (cols == 1 || cols == 2) _cols = cols ?? _cols;
    });
  }

  Future<void> _persistView({
    GymViewMode? mode,
    BodySide? side,
    int? cols,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (mode != null) {
      await prefs.setString(
        'gym_view_mode',
        mode == GymViewMode.silhouette ? 'silhouette' : 'list',
      );
    }
    if (side != null) {
      await prefs.setString(
        'gym_body_side',
        side == BodySide.back ? 'back' : 'front',
      );
    }
    if (cols != null) {
      await prefs.setInt('gym_cols', cols);
    }
  }

  void _setMode(GymViewMode mode) {
    setState(() => _mode = mode);
    _persistView(mode: mode);
  }

  void _setSide(BodySide side) {
    setState(() => _side = side);
    _persistView(side: side);
  }

  void _setCols(int cols) {
    setState(() => _cols = cols);
    _persistView(cols: cols);
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
    final raw = await rootBundle.loadString(assetPath);
    try {
      return _parseSvgXml(raw);
    } catch (_) {
      // Fallback to regex parser if XML parsing fails.
      return _parseSvgRegex(raw);
    }
  }

  SvgMuscleData? _parseSvgXml(String raw) {
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
  }

  SvgMuscleData? _parseSvgRegex(String raw) {
    final vbMatch = RegExp(r'viewBox="([^"]+)"').firstMatch(raw);
    final vb = vbMatch?.group(1) ?? '0 0 915.2 1759.1';
    final parts = vb.split(RegExp(r'[ ,]+')).where((e) => e.isNotEmpty).toList();
    final vbX = double.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final vbY = double.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final vbW = double.tryParse(parts.length > 2 ? parts[2] : '915.2') ?? 915.2;
    final vbH = double.tryParse(parts.length > 3 ? parts[3] : '1759.1') ?? 1759.1;

    final pathRe = RegExp(r'<path[^>]*class="[^"]*muscle[^"]*"[^>]*>', dotAll: true);
    final dRe = RegExp(r'd="([^"]+)"', dotAll: true);
    final idRe = RegExp(r'id="([^"]+)"');
    final paths = <MusclePath>[];
    for (final match in pathRe.allMatches(raw)) {
      final tag = match.group(0) ?? '';
      final dMatch = dRe.firstMatch(tag);
      final d = dMatch?.group(1) ?? '';
      if (d.isEmpty) continue;
      final idMatch = idRe.firstMatch(tag);
      final id = idMatch?.group(1) ?? '';
      final path = parseSvgPathData(d);
      final group = findGroup(id) ?? id;
      paths.add(MusclePath(id: id, group: group, path: path));
    }

    return SvgMuscleData(
      viewBox: Rect.fromLTWH(vbX, vbY, vbW, vbH),
      paths: paths,
    );
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
    if (_selectedGroup != null) {
      setState(() {
        _selectedGroup = null;
        _groupExercises = [];
      });
    }
  }

  void _openExercise(Exercise ex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ExerciseDetailScreen(exercise: ex, asModal: true),
      ),
    );
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
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppTheme.backgroundGradient(context),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: NoisePainter(opacity: 0.015),
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
              const SliverToBoxAdapter(child: SizedBox.shrink()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  child: _buildHeaderCard(
                    context,
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\u0423\u041f\u0420\u0410\u0416\u041d\u0415\u041d\u0418\u042f',
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
                                '\u0417\u0410\u041b',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(letterSpacing: 1.2),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '\u041a\u0410\u0422\u0410\u041b\u041e\u0413 \u0423\u041f\u0420\u0410\u0416\u041d\u0415\u041d\u0418\u0419',
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
                          left: '\u0421\u0418\u041b\u0423\u042d\u0422',
                          right: '\u0421\u041f\u0418\u0421\u041e\u041a',
                          isRightActive: _mode == GymViewMode.list,
                          onLeft: () => _setMode(GymViewMode.silhouette),
                          onRight: () => _setMode(GymViewMode.list),
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
                                      hintText: '\u041f\u043e\u0438\u0441\u043a \u0443\u043f\u0440\u0430\u0436\u043d\u0435\u043d\u0438\u044f',
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
                          onTap: () => _setCols(_cols == 2 ? 1 : 2),
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
                else if (_cols == 1)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = _filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 520),
                                child: _ExerciseCard(
                                  title: item.title,
                                  subtitle:
                                      '\u041E\u0422\u041A\u0420\u042B\u0422\u042C\n\u041E\u041F\u0418\u0421\u0410\u041D\u0418\u0415',
                                  hasVideo: (item.videoUrl ?? '').isNotEmpty,
                                  videoUrl: item.videoUrl,
                                  thumbMaxWidth: thumbMaxWidth,
                                  previewHeight: 190,
                                  onTap: () => _openExercise(item),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: _filtered.length,
                      ),
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
                            onTap: () => _openExercise(item),
                          );
                        },
                        childCount: _filtered.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _cols,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.6,
                      ),
                    ),
                  ),
              ] else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: _TogglePill(
                      left: '\u0412\u0418\u0414 \u0421\u041f\u0415\u0420\u0415\u0414\u0418',
                      right: '\u0412\u0418\u0414 \u0421\u0417\u0410\u0414\u0418',
                      isRightActive: _side == BodySide.back,
                      onLeft: () => _setSide(BodySide.front),
                      onRight: () => _setSide(BodySide.back),
                      expand: true,
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
                              Positioned.fill(
                                child: AnimatedBuilder(
                                  animation: _pulse,
                                  builder: (context, child) {
                                    final t = _pulse.value;
                                    final glow =
                                        AppTheme.accentColor(context).withOpacity(
                                      0.06 + 0.04 * t,
                                    );
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          center: const Alignment(0, -0.15),
                                          radius: 0.9,
                                          colors: [
                                            glow,
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
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
                              if (data != null)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: AnimatedBuilder(
                                      animation: _pulse,
                                      builder: (context, child) {
                                        return CustomPaint(
                                          painter: MuscleHighlightPainter(
                                            data: data,
                                            selectedGroup: _selectedGroup,
                                            pulse: _pulse.value,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: 44,
                                left: 0,
                                right: 0,
                                child: AnimatedOpacity(
                                  opacity: _selectedGroup == null ? 1 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(999),
                                        border:
                                            Border.all(color: Colors.white10),
                                      ),
                                      child: Text(
                                        '\u0412\u044b\u0431\u0435\u0440\u0438 \u043c\u044b\u0448\u0446\u0443',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              letterSpacing: 1.4,
                                              color:
                                                  AppTheme.mutedColor(context),
                                            ),
                                      ),
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
                if (_selectedGroup != null)
                SliverToBoxAdapter(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    reverseDuration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      );
                      return FadeTransition(
                        opacity: curved,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(curved),
                          child: child,
                        ),
                      );
                    },
                    child: _selectedGroup == null
                        ? const SizedBox.shrink(key: ValueKey('empty'))
                        : Padding(
                            key: ValueKey(_selectedGroup),
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
                                    humanName(_selectedGroup!),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(letterSpacing: 1.1),
                                  ),
                                  const SizedBox(height: 10),
                                  if (_groupExercises.isEmpty)
                                    Text(
                                      '    .',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: AppTheme.mutedColor(context)),
                                    )
                                  else
                                    Column(
                                      children: _groupExercises.take(6).map((ex) {
                                        return InkWell(
                                          onTap: () => _openExercise(ex),
                                          borderRadius: BorderRadius.circular(14),
                                          child: Container(
                                            width: double.infinity,
                                            margin: const EdgeInsets.only(bottom: 10),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(14),
                                              color: Colors.black12,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    ex.title,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(color: Colors.white70),
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.chevron_right,
                                                  color: Colors.white54,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    )
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ],
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
  final String? selectedGroup;
  final double pulse;
  MuscleHighlightPainter({
    required this.data,
    required this.selectedGroup,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final vb = data.viewBox;
    final scale = math.min(size.width / vb.width, size.height / vb.height);
    final dx = (size.width - vb.width * scale) / 2;
    final dy = (size.height - vb.height * scale) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);
    if (selectedGroup != null) {
      final glow = Paint()
        ..color = const Color(0xFF8B5CF6).withOpacity(0.15 + 0.1 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (18 + 8 * pulse) / scale
        ..maskFilter = ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          (16 + 8 * pulse) / scale,
        );
      final paint = Paint()
        ..color = const Color(0xB38B5CF6)
        ..style = PaintingStyle.fill;
      final stroke = Paint()
        ..color = const Color(0xFF8B5CF6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 / scale;
      for (final p in data.paths.where((p) => p.group == selectedGroup)) {
        canvas.drawPath(p.path, glow);
        canvas.drawPath(p.path, paint);
        canvas.drawPath(p.path, stroke);
      }
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
  'traps': '\u0422\u0440\u0430\u043f\u0435\u0446\u0438\u0438',
  'chest': '\u0413\u0440\u0443\u0434\u043d\u044b\u0435',
  'delts': '\u0414\u0435\u043b\u044c\u0442\u044b',
  'biceps': '\u0411\u0438\u0446\u0435\u043f\u0441',
  'forearm': '\u041f\u0440\u0435\u0434\u043f\u043b\u0435\u0447\u044c\u044f',
  'abs': '\u041f\u0440\u0435\u0441\u0441',
  'quads': '\u041a\u0432\u0430\u0434\u0440\u0438\u0446\u0435\u043f\u0441',
  'adductors': '\u041f\u0440\u0438\u0432\u043e\u0434\u044f\u0449\u0438\u0435',
  'tibialis': '\u041f\u0435\u0440\u0435\u0434\u043d\u044f\u044f \u0433\u043e\u043b\u0435\u043d\u044c',
  'upperBack': '\u0412\u0435\u0440\u0445 \u0441\u043f\u0438\u043d\u044b',
  'triceps': '\u0422\u0440\u0438\u0446\u0435\u043f\u0441',
  'lats': '\u0428\u0438\u0440\u043e\u0447\u0430\u0439\u0448\u0438\u0435',
  'erectors': '\u041f\u043e\u044f\u0441\u043d\u0438\u0446\u0430',
  'glutes': '\u042f\u0433\u043e\u0434\u0438\u0446\u044b',
  'hams': '\u0411\u0438\u0446\u0435\u043f\u0441 \u0431\u0435\u0434\u0440\u0430',
  'calves': '\u0418\u043a\u0440\u044b',
};

final Map<String, List<String>> muscleKeywords = {
  'traps': ['\u0442\u0440\u0430\u043f\u0435\u0446', '\u0448\u0440\u0430\u0433'],
  'chest': ['\u0433\u0440\u0443\u0434', '\u0436\u0438\u043c', '\u043e\u0442\u0436\u0438\u043c'],
  'delts': ['\u0434\u0435\u043b\u044c\u0442', '\u043f\u043b\u0435\u0447'],
  'biceps': ['\u0431\u0438\u0446\u0435\u043f', '\u0441\u0433\u0438\u0431'],
  'forearm': ['\u043f\u0440\u0435\u0434\u043f\u043b\u0435\u0447', '\u043a\u0438\u0441\u0442', '\u0445\u0432\u0430\u0442'],
  'abs': ['\u043f\u0440\u0435\u0441\u0441', '\u0441\u043a\u0440\u0443\u0447', '\u043a\u043e\u0440'],
  'quads': ['\u043a\u0432\u0430\u0434\u0440\u0438\u0446', '\u043f\u0440\u0438\u0441\u0435\u0434', '\u0432\u044b\u043f\u0430\u0434'],
  'adductors': ['\u043f\u0440\u0438\u0432\u043e\u0434', '\u0432\u043d\u0443\u0442\u0440\u0435\u043d'],
  'tibialis': ['\u0433\u043e\u043b\u0435\u043d', '\u0442\u0438\u0431\u0438\u0430\u043b'],
  'upperBack': ['\u0432\u0435\u0440\u0445 \u0441\u043f\u0438\u043d\u044b', '\u0440\u043e\u043c\u0431', '\u043b\u043e\u043f\u0430\u0442'],
  'triceps': ['\u0442\u0440\u0438\u0446\u0435\u043f', '\u0440\u0430\u0437\u0433\u0438\u0431'],
  'lats': ['\u0448\u0438\u0440\u043e\u0447', '\u0442\u044f\u0433\u0430', '\u043f\u043e\u0434\u0442\u044f\u0433'],
  'erectors': ['\u043f\u043e\u044f\u0441\u043d\u0438\u0446', '\u0440\u0430\u0437\u0433\u0438\u0431\u0430\u0442', '\u0441\u043f\u0438\u043d\u044b'],
  'glutes': ['\u044f\u0433\u043e\u0434', '\u0433\u043b\u044e\u0442'],
  'hams': ['\u0431\u0438\u0446\u0435\u043f\u0441 \u0431\u0435\u0434\u0440\u0430', '\u0445\u0430\u043c\u0441\u0442\u0440', '\u0437\u0430\u0434\u043d'],
  'calves': ['\u0438\u043a\u0440', '\u043a\u0430\u043c\u0431\u0430\u043b'],
};

class _TogglePill extends StatelessWidget {
  final String left;
  final String right;
  final bool isRightActive;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final bool expand;
  const _TogglePill({
    required this.left,
    required this.right,
    required this.isRightActive,
    required this.onLeft,
    required this.onRight,
    this.expand = false,
  });

  Widget _buildItem({
    required BuildContext context,
    required String label,
    required bool active,
    required VoidCallback onTap,
    required bool expand,
  }) {
    final isDark = AppTheme.isDark(context);
    final content = Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: active ? AppTheme.accentColor(context) : Colors.transparent,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.6,
              color: active
                  ? Colors.black
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
      ),
    );
    final ink = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: content,
    );
    return expand ? Expanded(child: ink) : ink;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppTheme.cardColor(context),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _buildItem(
            context: context,
            label: left,
            active: !isRightActive,
            onTap: onLeft,
            expand: expand,
          ),
          _buildItem(
            context: context,
            label: right,
            active: isRightActive,
            onTap: onRight,
            expand: expand,
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

class NoisePainter extends CustomPainter {
  final double opacity;
  final int seed;
  const NoisePainter({this.opacity = 0.015, this.seed = 1337});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = math.Random(seed);
    final light = Paint()..color = Colors.white.withOpacity(opacity);
    final dark = Paint()..color = Colors.black.withOpacity(opacity * 0.7);
    const step = 6.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        final r = rand.nextDouble();
        if (r < 0.35) {
          final paint = r < 0.17 ? dark : light;
          canvas.drawRect(Rect.fromLTWH(x, y, 1.2, 1.2), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant NoisePainter oldDelegate) => false;
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

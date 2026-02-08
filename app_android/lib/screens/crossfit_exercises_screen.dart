import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../theme.dart';
import '../models/exercise.dart';
import '../services/api_service.dart';
import 'exercise_detail_screen.dart';

class CrossfitExercisesScreen extends StatefulWidget {
  const CrossfitExercisesScreen({super.key});

  @override
  State<CrossfitExercisesScreen> createState() => _CrossfitExercisesScreenState();
}

class _CrossfitExercisesScreenState extends State<CrossfitExercisesScreen> {
  final _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  static const List<String> _filterKeys = [
    'dumbbells',
    'barbell',
    'kettlebells',
    'free',
  ];
  static const Map<String, String> _filterLabels = {
    'dumbbells': 'Гантели',
    'barbell': 'Штанга',
    'kettlebells': 'Гири',
    'free': 'Свободные',
  };
  int _cols = 2;
  List<Exercise> _all = [];
  List<Exercise> _filtered = [];
  bool _loading = true;
  bool _showFilters = false;
  late Set<String> _activeFilters;
  @override
  void initState() {
    super.initState();
    _activeFilters = _filterKeys.toSet();
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildHeaderCard(BuildContext context, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: child,
    );
  }

  Future<void> _load() async {
    try {
      final data = await _api.fetchExercises(type: 'crossfit');
      if (!mounted) return;
      setState(() {
        _all = data;
        _loading = false;
      });
      _applyFilter();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    if (!mounted) return;
    final query = _searchController.text.toLowerCase().trim();
    final showAll = _activeFilters.isEmpty ||
        _activeFilters.length == _filterKeys.length;
    final filteredByType = showAll
        ? _all
        : _all
            .where((ex) =>
                ex.crossfitType != null &&
                _activeFilters.contains(ex.crossfitType))
            .toList();
    if (query.isEmpty) {
      setState(() => _filtered = filteredByType);
      return;
    }
    setState(() {
      _filtered = filteredByType.where((ex) {
        final hay = '${ex.title} ${ex.description} ${ex.details ?? ''}'.toLowerCase();
        return hay.contains(query);
      }).toList();
    });
  }

  void _toggleFilter(String key) {
    if (_activeFilters.contains(key)) {
      _activeFilters.remove(key);
    } else {
      _activeFilters.add(key);
    }
    _applyFilter();
  }

  @override
  Widget build(BuildContext context) {
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
            cacheExtent: 800,
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
                                'УПРАЖНЕНИЯ',
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
                                'КРОССФИТ',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(letterSpacing: 1.2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _CircleIcon(
                            icon: Icons.tune,
                            onTap: () =>
                                setState(() => _showFilters = !_showFilters),
                          ),
                          const SizedBox(width: 12),
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
                                        hintText: 'Поиск упражнения',
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
                                          ?.copyWith(
                                              color: AppTheme.textColor(context)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _CircleBadge(
                            value: '$_cols',
                            onTap: () =>
                                setState(() => _cols = _cols == 2 ? 1 : 2),
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: _showFilters
                            ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _filterKeys.map((key) {
                                      return _FilterChip(
                                        label: _filterLabels[key] ?? key,
                                        isActive: _activeFilters.contains(key),
                                        onTap: () => _toggleFilter(key),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
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
                                onTap: () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(24)),
                                    child: ExerciseDetailScreen(
                                      exercise: item,
                                      asModal: true,
                                    ),
                                  ),
                                ),
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
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => ClipRRect(
                              borderRadius:
                                  const BorderRadius.vertical(top: Radius.circular(24)),
                              child: ExerciseDetailScreen(
                                exercise: item,
                                asModal: true,
                              ),
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
                      childAspectRatio: 0.6,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: AppTheme.mutedColor(context)),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentColor(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? accent : AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? accent.withOpacity(0.8) : Colors.white10,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.black : AppTheme.mutedColor(context),
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
    return RepaintBoundary(
      child: InkWell(
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
                  clipBehavior: Clip.hardEdge,
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
    return Image.memory(
      _bytes!,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
    );
  }
}

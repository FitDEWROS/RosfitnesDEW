import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../theme.dart';
import '../models/exercise.dart';
import '../services/api_service.dart';
import '../services/video_cache_service.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise? exercise;
  final bool asModal;
  const ExerciseDetailScreen({super.key, this.exercise, this.asModal = false});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final _api = ApiService();
  VideoPlayerController? _controller;
  bool _loadingVideo = false;
  String? _resolvedUrl;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initVideo(String url) async {
    if (_loadingVideo) return;
    setState(() => _loadingVideo = true);
    try {
      final cached = await VideoCacheService.instance.getCachedFile(url);
      VideoPlayerController controller;
      if (cached != null) {
        _resolvedUrl = cached.path;
        controller = VideoPlayerController.file(File(cached.path));
      } else {
        final resolved = await _api.resolveVideoUrl(url) ?? _api.normalizeVideoUrl(url);
        _resolvedUrl = resolved;
        final safeUrl = _api.safeVideoUrl(resolved);
        controller = VideoPlayerController.networkUrl(Uri.parse(safeUrl));
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

  Map<String, String> _splitDescription(String raw) {
    final text = raw.replaceAll('\r\n', '\n').trim();
    if (text.isEmpty) return {'how': '', 'tip': ''};
    final tipMatch = RegExp(r'(?:^|\n)\s*Совет\s*:', caseSensitive: false)
        .firstMatch(text);
    String how = text;
    String tip = '';
    if (tipMatch != null) {
      how = text.substring(0, tipMatch.start).trim();
      tip = text.substring(tipMatch.end).trim();
    }
    how = how.replaceAll(RegExp(r'Как\s+выполнять\s*:', caseSensitive: false), '').trim();
    tip = tip.replaceAll(RegExp(r'^Совет\s*:', caseSensitive: false), '').trim();
    return {'how': how, 'tip': tip};
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final exercise = widget.exercise ?? (args is Exercise
        ? args
        : Exercise(
            id: 0,
            title: 'Упражнение',
            description: '',
            type: 'gym',
            muscles: const [],
            guestAccess: true,
          ));

    final desc = _splitDescription(exercise.description);
    final hasVideo = (exercise.videoUrl ?? '').isNotEmpty;

    if (hasVideo && _controller == null && !_loadingVideo) {
      _initVideo(exercise.videoUrl!);
    }

    final body = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.backgroundGradient(context),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Упражнение', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.black,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _controller != null
                    ? Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: IconButton(
                                iconSize: 56,
                                color: Colors.white70,
                                icon: Icon(
                                  _controller!.value.isPlaying
                                      ? Icons.pause_circle
                                      : Icons.play_circle,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_controller!.value.isPlaying) {
                                      _controller!.pause();
                                    } else {
                                      _controller!.play();
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: IconButton(
                              icon: const Icon(Icons.fullscreen, color: Colors.white70),
                              onPressed: () async {
                                if (_controller == null) return;
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => _FullscreenVideo(controller: _controller!),
                                  ),
                                );
                              },
                            ),
                          )
                        ],
                      )
                    : Center(
                        child: _loadingVideo
                            ? const CircularProgressIndicator()
                            : Icon(
                                hasVideo ? Icons.play_circle : Icons.play_disabled,
                                size: 48,
                                color: Colors.white54,
                              ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(exercise.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              'КАК ВЫПОЛНЯТЬ:',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 2.0,
                    color: AppTheme.mutedColor(context),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              desc['how'] ?? '',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.mutedColor(context)),
            ),
            const SizedBox(height: 14),
            Text(
              'СОВЕТ:',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 2.0,
                    color: AppTheme.mutedColor(context),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              (desc['tip'] ?? '').isNotEmpty ? desc['tip']! : '-',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.mutedColor(context)),
            ),
            // No external link fallback
          ],
        ),
      ),
    );
    return widget.asModal ? body : Scaffold(body: body);
  }
}

class _FullscreenVideo extends StatefulWidget {
  final VideoPlayerController controller;
  const _FullscreenVideo({required this.controller});

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: widget.controller.value.aspectRatio,
          child: VideoPlayer(widget.controller),
        ),
      ),
    );
  }
}

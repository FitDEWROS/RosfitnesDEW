import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';

class VideoCacheService {
  VideoCacheService._();

  static final VideoCacheService instance = VideoCacheService._();

  final ApiService _api = ApiService();
  final Map<String, Future<File?>> _inflight = {};

  Future<File?> getCachedFile(String url) async {
    if (url.isEmpty) return null;
    final resolved = await _api.resolveVideoUrl(url) ?? _api.normalizeVideoUrl(url);
    final safeUrl = _api.safeVideoUrl(resolved);
    if (_inflight.containsKey(safeUrl)) {
      return _inflight[safeUrl];
    }
    final future = _getOrDownload(safeUrl);
    _inflight[safeUrl] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(safeUrl);
    }
  }

  Future<File?> _getOrDownload(String safeUrl) async {
    final dir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${dir.path}/video_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final key = sha1.convert(utf8.encode(safeUrl)).toString();
    final file = File('${cacheDir.path}/$key.mp4');
    if (await file.exists()) {
      final size = await file.length();
      if (size > 0) return file;
    }

    final uri = Uri.parse(safeUrl);
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final sink = file.openWrite();
      await response.pipe(sink);
      await sink.close();
      return file;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

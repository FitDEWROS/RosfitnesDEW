import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/program.dart';
import '../models/exercise.dart';

class ApiService {
  Future<List<Program>> fetchPrograms() async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/programs');
    final res = await http.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['programs'] as List? ?? const [])
        .map((e) => Program.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<List<Exercise>> fetchExercises({
    required String type,
    bool guestOnly = false,
    String? tariff,
  }) async {
    final query = <String, String>{};
    if (type.isNotEmpty) query['type'] = type;
    if (guestOnly) query['guest'] = '1';
    if (tariff != null && tariff.trim().isNotEmpty) {
      query['tariff'] = tariff.trim();
    }
    final uri = Uri.parse('${AppConfig.apiBase}/api/exercises')
        .replace(queryParameters: query.isEmpty ? null : query);
    final res = await http.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['exercises'] as List? ?? const [])
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }


  String normalizeVideoUrl(String url) {
    var value = url.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('//')) {
      value = 'https:' + value;
    }
    if (value.startsWith('http://')) {
      value = 'https://' + value.substring(7);
    }
    if (value.startsWith('/')) {
      value = AppConfig.apiBase + value;
    }
    if (!value.contains('://')) {
      value = 'https://' + value;
    }
    return value;
  }

  String safeVideoUrl(String url) {
    final normalized = normalizeVideoUrl(url);
    if (normalized.isEmpty) return normalized;
    final needsEncoding =
        normalized.contains(' ') || normalized.runes.any((r) => r > 127);
    return needsEncoding ? Uri.encodeFull(normalized) : normalized;
  }

  Future<String?> resolveVideoUrl(String url) async {
    if (url.isEmpty) return null;
    final normalized = normalizeVideoUrl(url);
    if (!_isYandexPublicLink(normalized)) return normalized;
    final uri = Uri.parse('${AppConfig.apiBase}/api/yadisk/resolve')
        .replace(queryParameters: {'publicUrl': normalized});
    final res = await http.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return null;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] == true && data['href'] != null) {
      return data['href'].toString();
    }
    return null;
  }

  bool _isYandexPublicLink(String url) {
    try {
      final host = Uri.parse(url).host;
      return host == 'disk.yandex.ru' ||
          host == 'yadi.sk' ||
          host.endsWith('.yandex.ru');
    } catch (_) {
      return false;
    }
  }
}

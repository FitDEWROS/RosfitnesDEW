import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/program.dart';
import '../models/exercise.dart';
import '../models/nutrition.dart';
import 'auth_service.dart';

class ApiService {
  final AuthService _auth = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth.getToken();
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

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

  Future<NutritionDay> fetchNutritionDay({String? date}) async {
    final query = <String, String>{};
    if (date != null && date.isNotEmpty) query['date'] = date;
    final uri = Uri.parse('${AppConfig.apiBase}/api/nutrition')
        .replace(queryParameters: query.isEmpty ? null : query);
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception('bad_response');
    }
    return NutritionDay.fromJson(data);
  }

  Future<List<NutritionHistoryDay>> fetchNutritionHistory({
    String? from,
    String? to,
    int days = 7,
  }) async {
    final query = <String, String>{};
    if (from != null && from.isNotEmpty) query['from'] = from;
    if (to != null && to.isNotEmpty) query['to'] = to;
    query['days'] = days.toString();
    final uri = Uri.parse('${AppConfig.apiBase}/api/nutrition/history')
        .replace(queryParameters: query);
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['entries'] as List? ?? const [])
        .map((e) => NutritionHistoryDay.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<List<NutritionProduct>> searchFood({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/food/search').replace(
      queryParameters: {
        'query': query,
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (data['items'] as List? ?? const [])
        .map((e) => NutritionProduct.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<NutritionProduct?> fetchFoodByBarcode(String barcode) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/food/barcode')
        .replace(queryParameters: {'barcode': barcode});
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['product'] == null) return null;
    return NutritionProduct.fromJson(data['product'] as Map<String, dynamic>);
  }

  Future<NutritionItem> addNutritionItem({
    required String date,
    required String meal,
    required double grams,
    NutritionProduct? product,
    String? title,
    String? brand,
  }) async {
    final payload = <String, dynamic>{
      'date': date,
      'meal': meal,
      'grams': grams,
    };
    if (product?.id != null) payload['productId'] = product!.id;
    if (product?.barcode != null) payload['barcode'] = product!.barcode;
    if (product != null) {
      payload['title'] = product.title;
      payload['brand'] = product.brand;
      payload['kcal100'] = product.kcal100;
      payload['protein100'] = product.protein100;
      payload['fat100'] = product.fat100;
      payload['carb100'] = product.carb100;
    } else if (title != null && title.isNotEmpty) {
      payload['title'] = title;
      payload['brand'] = brand;
    }
    final uri = Uri.parse('${AppConfig.apiBase}/api/nutrition/item');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...await _authHeaders(),
      },
      body: jsonEncode(payload),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return NutritionItem.fromJson(data['item'] as Map<String, dynamic>);
  }

  Future<void> deleteNutritionItem(int id) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/nutrition/item/delete');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...await _authHeaders(),
      },
      body: jsonEncode({'id': id}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
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

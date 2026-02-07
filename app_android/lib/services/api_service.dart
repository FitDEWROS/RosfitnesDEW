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

  Map<String, dynamic> _decodeJson(http.Response res) {
    final body = utf8.decode(res.bodyBytes);
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<List<Program>> fetchPrograms() async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/programs');
    final res = await http.get(uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final data = _decodeJson(res);
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
    final data = _decodeJson(res);
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
    final data = _decodeJson(res);
    if (data['ok'] != true) {
      throw Exception('bad_response');
    }
    return NutritionDay.fromJson(data);
  }

  Future<Map<String, dynamic>?> fetchUserProfile() async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/user');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return null;
    }
    final data = _decodeJson(res);
    if (data['ok'] != true) return null;
    final profileRaw = data['profile'];
    if (profileRaw is! Map) return null;
    final profile = Map<String, dynamic>.from(profileRaw as Map);
    final user = data['user'];
    if (user is Map) {
      profile['tgId'] ??= user['id'];
      profile['username'] ??= user['username'];
      profile['photoUrl'] ??= user['photo_url'];
      profile['firstName'] ??= user['first_name'];
      profile['lastName'] ??= user['last_name'];
    }
    return profile;
  }

  Future<Map<String, dynamic>> updateProfile({
    int? heightCm,
    double? weightKg,
    int? age,
    int? timezoneOffsetMin,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/profile');
    final payload = <String, dynamic>{
      'heightCm': heightCm,
      'weightKg': weightKg,
      'age': age,
      if (timezoneOffsetMin != null) 'timezoneOffsetMin': timezoneOffsetMin,
    };
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...await _authHeaders(),
      },
      body: jsonEncode(payload),
    );
    Map<String, dynamic> data;
    try {
      data = _decodeJson(res);
    } catch (_) {
      data = {'ok': false};
    }
    return data;
  }

  Future<Map<String, dynamic>> updateTrainingMode({required String mode}) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/mode');
    final payload = <String, dynamic>{'mode': mode};
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...await _authHeaders(),
      },
      body: jsonEncode(payload),
    );
    Map<String, dynamic> data;
    try {
      data = _decodeJson(res);
    } catch (_) {
      data = {'ok': false};
    }
    return data;
  }

  Future<Map<String, dynamic>> fetchWeightHistory({int weeks = 12}) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/weight/history')
        .replace(queryParameters: {'weeks': weeks.toString()});
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return _decodeJson(res);
  }

  Future<Map<String, dynamic>> fetchMeasurementsHistory({int months = 12}) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/measurements/history')
        .replace(queryParameters: {'months': months.toString()});
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return _decodeJson(res);
  }

  Future<Map<String, dynamic>> postWeight({
    required double weightKg,
    required String weekStart,
    int? timezoneOffsetMin,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/weight');
    final payload = {
      'weightKg': weightKg,
      'weekStart': weekStart,
      if (timezoneOffsetMin != null) 'timezoneOffsetMin': timezoneOffsetMin,
    };
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...await _authHeaders(),
      },
      body: jsonEncode(payload),
    );
    Map<String, dynamic> data;
    try {
      data = _decodeJson(res);
    } catch (_) {
      data = {'ok': false};
    }
    return data;
  }

  Future<Map<String, dynamic>> postSteps({
    required int steps,
    String? date,
    int? timezoneOffsetMin,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/steps');
    final payload = <String, dynamic>{
      'steps': steps,
    };
    if (date != null && date.isNotEmpty) payload['date'] = date;
    if (timezoneOffsetMin != null) {
      payload['timezoneOffsetMin'] = timezoneOffsetMin;
    }
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
    return _decodeJson(res);
  }

  Future<Map<String, dynamic>> fetchSteps({
    String? date,
    int? timezoneOffsetMin,
  }) async {
    final query = <String, String>{};
    if (date != null && date.isNotEmpty) query['date'] = date;
    if (timezoneOffsetMin != null) {
      query['timezoneOffsetMin'] = timezoneOffsetMin.toString();
    }
    final uri = Uri.parse('${AppConfig.apiBase}/api/steps')
        .replace(queryParameters: query.isEmpty ? null : query);
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return _decodeJson(res);
  }

  Future<Map<String, dynamic>> createPayment({required String tariffCode}) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/payments/create');
    final payload = {'tariff': tariffCode};
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
    return _decodeJson(res);
  }

  Future<Map<String, dynamic>> confirmPayment({required String paymentId}) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/payments/confirm');
    final payload = {'paymentId': paymentId};
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
    return _decodeJson(res);
  }

  Future<Map<String, dynamic>> fetchAppUpdateInfo() async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/app/version');
    final res = await http.get(uri);
    Map<String, dynamic> data;
    try {
      data = _decodeJson(res);
    } catch (_) {
      data = {'ok': false};
    }
    return data;
  }

  Future<Map<String, dynamic>> fetchChatMessages({
    int? afterId,
    bool markRead = true,
    bool includeLast = false,
  }) async {
    final query = <String, String>{};
    if (afterId != null) query['afterId'] = afterId.toString();
    if (!markRead) query['markRead'] = '0';
    if (includeLast) query['includeLast'] = '1';
    final uri = Uri.parse('${AppConfig.apiBase}/api/chat/messages')
        .replace(queryParameters: query.isEmpty ? null : query);
    final res = await http.get(uri, headers: await _authHeaders());
    Map<String, dynamic> data;
    try {
      data = _decodeJson(res);
    } catch (_) {
      data = {'ok': false};
    }
    return data;
  }

  Future<Map<String, dynamic>> fetchChatUnreadCount() async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/chat/unread-count');
    final res = await http.get(uri, headers: await _authHeaders());
    Map<String, dynamic> data;
    try {
      data = _decodeJson(res);
    } catch (_) {
      data = {'ok': false};
    }
    return data;
  }

  Future<Map<String, dynamic>> fetchNotifications({
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    final query = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (unreadOnly) query['unreadOnly'] = '1';
    final uri = Uri.parse('${AppConfig.apiBase}/api/notifications')
        .replace(queryParameters: query);
    final res = await http.get(uri, headers: await _authHeaders());
    Map<String, dynamic> data;
    try {
      data = _decodeJson(res);
    } catch (_) {
      data = {'ok': false};
    }
    return data;
  }

  Future<Map<String, dynamic>> markNotificationsRead({
    List<int>? ids,
    bool all = false,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/notifications/read');
    final payload = <String, dynamic>{};
    if (ids != null && ids.isNotEmpty) payload['ids'] = ids;
    if (all) payload['all'] = true;
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...await _authHeaders(),
      },
      body: jsonEncode(payload),
    );
    Map<String, dynamic> data;
    try {
      data = _decodeJson(res);
    } catch (_) {
      data = {'ok': false};
    }
    return data;
  }

  Future<Map<String, dynamic>> createChatUploadUrl({
    required String fileName,
    required String contentType,
    required int size,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/chat/upload-url');
    final payload = {
      'fileName': fileName,
      'contentType': contentType,
      'size': size,
    };
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...await _authHeaders(),
      },
      body: jsonEncode(payload),
    );
    Map<String, dynamic> data;
    try {
      data = _decodeJson(res);
    } catch (_) {
      data = {'ok': false};
    }
    return data;
  }

  Future<Map<String, dynamic>> sendChatMessage({
    String? text,
    String? mediaKey,
    String? mediaType,
    String? mediaName,
    int? mediaSize,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/chat/messages');
    final payload = <String, dynamic>{};
    if (text != null && text.trim().isNotEmpty) {
      payload['text'] = text.trim();
    }
    if (mediaKey != null) payload['mediaKey'] = mediaKey;
    if (mediaType != null) payload['mediaType'] = mediaType;
    if (mediaName != null) payload['mediaName'] = mediaName;
    if (mediaSize != null) payload['mediaSize'] = mediaSize;
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...await _authHeaders(),
      },
      body: jsonEncode(payload),
    );
    Map<String, dynamic> data;
    try {
      data = _decodeJson(res);
    } catch (_) {
      data = {'ok': false};
    }
    return data;
  }

  Future<Map<String, dynamic>> postMeasurementsMetrics({
    double? waistCm,
    double? chestCm,
    double? hipsCm,
    required String monthStart,
    int? timezoneOffsetMin,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/measurements/metrics');
    final payload = <String, dynamic>{
      'monthStart': monthStart,
      if (timezoneOffsetMin != null) 'timezoneOffsetMin': timezoneOffsetMin,
    };
    if (waistCm != null) payload['waistCm'] = waistCm;
    if (chestCm != null) payload['chestCm'] = chestCm;
    if (hipsCm != null) payload['hipsCm'] = hipsCm;
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...await _authHeaders(),
      },
      body: jsonEncode(payload),
    );
    Map<String, dynamic> data;
    try {
      data = _decodeJson(res);
    } catch (_) {
      data = {'ok': false};
    }
    return data;
  }

  Future<Map<String, dynamic>?> getMeasurementsUploadUrl({
    required String side,
    required String fileName,
    required String contentType,
    required int size,
    required String monthStart,
    int? timezoneOffsetMin,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/measurements/upload-url');
    final payload = {
      'side': side,
      'fileName': fileName,
      'contentType': contentType,
      'size': size,
      'monthStart': monthStart,
      if (timezoneOffsetMin != null) 'timezoneOffsetMin': timezoneOffsetMin,
    };
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...await _authHeaders(),
      },
      body: jsonEncode(payload),
    );
    Map<String, dynamic> data;
    try {
      data = _decodeJson(res);
    } catch (_) {
      return null;
    }
    return data;
  }

  Future<Map<String, dynamic>> postMeasurement({
    required String side,
    required String objectKey,
    required String monthStart,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/measurements');
    final payload = {
      'side': side,
      'objectKey': objectKey,
      'monthStart': monthStart,
    };
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...await _authHeaders(),
      },
      body: jsonEncode(payload),
    );
    Map<String, dynamic> data;
    try {
      data = _decodeJson(res);
    } catch (_) {
      data = {'ok': false};
    }
    return data;
  }

  Future<Map<String, dynamic>> deleteMeasurement({
    required String side,
    required String monthStart,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBase}/api/measurements/delete');
    final payload = {
      'side': side,
      'monthStart': monthStart,
    };
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...await _authHeaders(),
      },
      body: jsonEncode(payload),
    );
    Map<String, dynamic> data;
    try {
      data = _decodeJson(res);
    } catch (_) {
      data = {'ok': false};
    }
    return data;
  }

  Future<bool> putUpload(String url, List<int> bytes, {required String contentType}) async {
    final res = await http.put(
      Uri.parse(url),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    return res.statusCode >= 200 && res.statusCode < 300;
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
    final data = _decodeJson(res);
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
    final data = _decodeJson(res);
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
    final data = _decodeJson(res);
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
    final data = _decodeJson(res);
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

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/program.dart';

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
}

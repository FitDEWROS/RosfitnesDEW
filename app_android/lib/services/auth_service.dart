import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _photoUrlKey = 'profile_photo_url';
  static const _firstNameKey = 'profile_first_name';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> setProfilePhotoUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_photoUrlKey, url);
  }

  Future<void> setFirstName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_firstNameKey, name);
  }

  Future<String?> getProfilePhotoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_photoUrlKey);
  }

  Future<String?> getFirstName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_firstNameKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_photoUrlKey);
    await prefs.remove(_firstNameKey);
    await prefs.remove('tariff_name');
    await prefs.remove('training_mode');
    await prefs.remove('profile_height_cm');
    await prefs.remove('profile_weight_kg');
    await prefs.remove('profile_age');
    await prefs.remove('pending_payment_id');
    await prefs.remove('pending_tariff_code');
    await prefs.remove('pending_training_mode');
    await prefs.remove('has_curator');
  }

  Future<String?> handleAuthUri(Uri uri) async {
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return null;
    await setToken(token);
    final photoUrl = uri.queryParameters['photo_url'];
    if (photoUrl != null && photoUrl.isNotEmpty) {
      await setProfilePhotoUrl(photoUrl);
    }
    final firstName = uri.queryParameters['first_name'];
    if (firstName != null && firstName.isNotEmpty) {
      await setFirstName(firstName);
    }
    return token;
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  String? _avatarUrl;
  String _name = '\u041c\u0410\u041a\u0421\u0418\u041c';
  String _username = '@maksim_nazarkin';
  String _tariff = '\u0412\u041b\u0410\u0414\u0415\u041b\u0415\u0426';
  String _userId = '354538028';

  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightEntryController = TextEditingController();
  final _waistController = TextEditingController();
  final _chestController = TextEditingController();
  final _hipController = TextEditingController();
  String _currentWeekKey = '';
  String _currentMonthKey = '';
  String _currentWeekLabel = '';
  bool _weightProgressLoaded = false;
  bool _weightProgressLoading = false;
  bool _photosLocked = false;
  Map<String, dynamic> _currentPhotos = {};
  bool _isGuestUser = false;
  bool _profileEditable = true;
  bool _profileSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _weightEntryController.dispose();
    _waistController.dispose();
    _chestController.dispose();
    _hipController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final auth = AuthService();
    final prefs = await SharedPreferences.getInstance();
    final cachedTariff = prefs.getString('tariff_name');
    final cachedHeight = prefs.getString('profile_height_cm');
    final cachedWeight = prefs.getString('profile_weight_kg');
    final cachedAge = prefs.getString('profile_age');
    final cachedPhoto = await auth.getProfilePhotoUrl();
    final cachedFirstName = await auth.getFirstName();
    Map<String, dynamic>? profile;
    try {
      profile = await _api.fetchUserProfile();
    } catch (_) {
      profile = null;
    }
    if (!mounted) return;
    final rawTariff = profile?['tariffName']?.toString();
    final role = profile?['role']?.toString();
    final isCurator = profile?['isCurator'] == true || role == 'curator';
    final isStaff = role == 'admin' || role == 'sadmin' || isCurator;
    final tariffBase = (rawTariff != null && rawTariff.trim().isNotEmpty)
        ? rawTariff.trim()
        : (cachedTariff ?? '');
    final isGuest = !isStaff && _isGuestTariff(tariffBase);
    final displayTariff = _displayTariff(tariffBase, role, isCurator);
    if (tariffBase.isNotEmpty) {
      await prefs.setString('tariff_name', tariffBase);
    }
    final firstName = (profile?['firstName'] ??
            profile?['first_name'] ??
            cachedFirstName)
        ?.toString();
    final username = profile?['username']?.toString();
    final photoUrl = (profile?['photoUrl'] ?? profile?['photo_url'])?.toString();
    final tgId = profile?['tgId'] ?? profile?['tg_id'] ?? profile?['telegramId'];
    final profileLoaded = profile != null;
    final heightCm = profile?['heightCm'];
    final weightKg = profile?['weightKg'];
    final age = profile?['age'];
    final heightText = _formatNumber(heightCm);
    final weightText = _formatNumber(weightKg);
    final ageText = _formatNumber(age);
    String resolveField(String fromProfile, String? cachedValue, String current) {
      if (profileLoaded) return fromProfile;
      final cached = (cachedValue ?? '').trim();
      if (cached.isNotEmpty) return cached;
      return current;
    }
    if (profileLoaded) {
      if (heightText.isNotEmpty) {
        prefs.setString('profile_height_cm', heightText);
      } else {
        prefs.remove('profile_height_cm');
      }
      if (weightText.isNotEmpty) {
        prefs.setString('profile_weight_kg', weightText);
      } else {
        prefs.remove('profile_weight_kg');
      }
      if (ageText.isNotEmpty) {
        prefs.setString('profile_age', ageText);
      } else {
        prefs.remove('profile_age');
      }
    }
    setState(() {
      _avatarUrl = (photoUrl != null && photoUrl.trim().isNotEmpty)
          ? photoUrl
          : cachedPhoto;
      if (firstName != null && firstName.trim().isNotEmpty) {
        _name = firstName.trim().toUpperCase();
      }
      _username = _formatUsername(username, firstName);
      if (tgId != null) {
        _userId = tgId.toString();
      }
      _tariff = displayTariff.toUpperCase();
      _profileEditable = !isGuest;
      _isGuestUser = isGuest;
      _heightController.text = resolveField(
        heightText,
        cachedHeight,
        _heightController.text,
      );
      _weightController.text = resolveField(
        weightText,
        cachedWeight,
        _weightController.text,
      );
      _ageController.text = resolveField(
        ageText,
        cachedAge,
        _ageController.text,
      );
    });
  }

  Future<void> _logout(BuildContext context) async {
    final auth = AuthService();
    await auth.clearToken();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _showStub(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '';
    if (value is num) {
      if (value == value.roundToDouble()) return value.toInt().toString();
      return value.toString();
    }
    final text = value.toString();
    return text == 'null' ? '' : text;
  }

  String _formatUsername(String? username, String? firstName) {
    final raw = (username ?? '').trim();
    if (raw.isNotEmpty) return raw.startsWith('@') ? raw : '@$raw';
    final base = (firstName ?? '').trim();
    if (base.isNotEmpty) return '@${base.toLowerCase()}';
    return '@user';
  }

  String _normalizeTariff(String? tariff) {
    final value = (tariff ?? '').toLowerCase();
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _compactTariff(String? tariff) {
    return _normalizeTariff(tariff).replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
  }

  bool _isGuestTariff(String? tariff) {
    final normalized = _normalizeTariff(tariff);
    if (normalized.isEmpty) return true;
    if (normalized.contains('\u0433\u043e\u0441\u0442')) return true;
    final compact = _compactTariff(tariff);
    return compact.contains('\u0431\u0435\u0437\u0442\u0430\u0440\u0438\u0444');
  }

  String _displayTariff(String tariff, String? role, bool isCurator) {
    if (role == 'sadmin') return '\u0412\u043b\u0430\u0434\u0435\u043b\u0435\u0446';
    if (role == 'admin') return '\u0410\u0434\u043c\u0438\u043d';
    if (role == 'curator' || isCurator) return '\u041a\u0443\u0440\u0430\u0442\u043e\u0440';
    if (_isGuestTariff(tariff)) return '\u0413\u043e\u0441\u0442\u0435\u0432\u043e\u0439';
    return tariff.isNotEmpty ? tariff : '\u0411\u0435\u0437 \u0442\u0430\u0440\u0438\u0444\u0430';
  }

  double? _parseDoubleValue(String value) {
    final raw = value.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  int? _parseIntValue(String value) {
    final parsed = _parseDoubleValue(value);
    return parsed == null ? null : parsed.round();
  }

  Future<void> _saveProfile() async {
    if (_profileSaving) return;
    if (_isGuestUser) {
      _showStub(
        context,
        '\u0420\u0435\u0434\u0430\u043a\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u0438\u0435 \u043f\u0440\u043e\u0444\u0438\u043b\u044f \u043d\u0435\u0434\u043e\u0441\u0442\u0443\u043f\u043d\u043e \u0432 \u0433\u043e\u0441\u0442\u0435\u0432\u043e\u043c \u0434\u043e\u0441\u0442\u0443\u043f\u0435.',
      );
      return;
    }
    setState(() => _profileSaving = true);
    try {
      final height = _parseIntValue(_heightController.text);
      final weight = _parseDoubleValue(_weightController.text);
      final age = _parseIntValue(_ageController.text);
      final res = await _api.updateProfile(
        heightCm: height,
        weightKg: weight,
        age: age,
        timezoneOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
      );
      if (res['ok'] != true) {
        _showStub(context, '\u041e\u0448\u0438\u0431\u043a\u0430 \u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u0438\u044f');
        return;
      }
      final profile = res['profile'];
      if (profile is Map) {
        _heightController.text = _formatNumber(profile['heightCm']);
        _weightController.text = _formatNumber(profile['weightKg']);
        _ageController.text = _formatNumber(profile['age']);
      }
      _showStub(context, '\u0421\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u043e');
    } catch (_) {
      _showStub(context, '\u041e\u0448\u0438\u0431\u043a\u0430 \u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u0438\u044f');
    } finally {
      if (mounted) {
        setState(() => _profileSaving = false);
      }
    }
  }

  void _openWeightDynamics(BuildContext context) {
    final now = DateTime.now();
    _currentWeekKey = _getWeekStartKey(now);
    _currentMonthKey = _getMonthStartKey(now);
    _currentWeekLabel = _formatWeekRangeNumeric(_currentWeekKey);
    _weightProgressLoaded = false;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF26282E), Color(0xFF1B1C22)]
                    : const [Color(0xFFF7F1E6), Color(0xFFE8DDCC)],
              ),
              border: Border.all(color: Colors.white10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 26,
                  offset: Offset(0, 14),
                )
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -60,
                  right: -40,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.accentColor(context).withOpacity(0.25),
                          Colors.transparent
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -40,
                  bottom: -60,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          (isDark
                                  ? const Color(0xFF5A5144)
                                  : const Color(0xFFD5C4A3))
                              .withOpacity(0.18),
                          Colors.transparent
                        ],
                      ),
                    ),
                  ),
                ),
                StatefulBuilder(
                  builder: (context, setModalState) {
                    if (!_weightProgressLoaded && !_weightProgressLoading) {
                      _loadWeightProgress(setModalState);
                    }
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '\u0414\u0418\u041d\u0410\u041c\u0418\u041a\u0410 \u0412\u0415\u0421\u0410',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(letterSpacing: 1.4),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _currentWeekLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppTheme.mutedColor(context),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(999),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.close, size: 18),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _InlineField(
                                  hint: '\u0412\u0435\u0441, \u043a\u0433',
                                  controller: _weightEntryController,
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentColor(context),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                onPressed: _weightProgressLoading
                                    ? null
                                    : () => _saveWeight(setModalState),
                                child: Text(
                                  '\u0421\u041e\u0425\u0420\u0410\u041d\u0418\u0422\u042c',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        letterSpacing: 1.0,
                                        color: Colors.black,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '\u0417\u0410\u041c\u0415\u0420\u042b, \u0421\u041c',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  letterSpacing: 2,
                                  color: AppTheme.mutedColor(context),
                                ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _InlineField(
                                  hint: '\u0422\u0430\u043b\u0438\u044f, \u0441\u043c',
                                  controller: _waistController,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _InlineField(
                                  hint: '\u0413\u0440\u0443\u0434\u044c, \u0441\u043c',
                                  controller: _chestController,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _InlineField(
                                  hint: '\u0411\u0435\u0434\u0440\u0430, \u0441\u043c',
                                  controller: _hipController,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentColor(context),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              onPressed: _weightProgressLoading
                                  ? null
                                  : () => _saveMeasurements(setModalState),
                              child: Text(
                                '\u0421\u041e\u0425\u0420\u0410\u041d\u0418\u0422\u042c \u0417\u0410\u041c\u0415\u0420\u042b',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      letterSpacing: 0.8,
                                      color: Colors.black,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _WeightPhotoCard(
                                  title: '\u0421\u041f\u0415\u0420\u0415\u0414\u0418',
                                  imageUrl:
                                      _currentPhotos['frontUrl']?.toString(),
                                  locked: _photosLocked,
                                  onUpload: _photosLocked
                                      ? null
                                      : () => _pickAndUpload(
                                            'front',
                                            setModalState,
                                          ),
                                  onDelete: _photosLocked
                                      ? null
                                      : () => _deleteMeasurement(
                                            'front',
                                            setModalState,
                                          ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _WeightPhotoCard(
                                  title: '\u0421\u0411\u041e\u041a\u0423',
                                  imageUrl:
                                      _currentPhotos['sideUrl']?.toString(),
                                  locked: _photosLocked,
                                  onUpload: _photosLocked
                                      ? null
                                      : () => _pickAndUpload(
                                            'side',
                                            setModalState,
                                          ),
                                  onDelete: _photosLocked
                                      ? null
                                      : () => _deleteMeasurement(
                                            'side',
                                            setModalState,
                                          ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _WeightPhotoCard(
                            title: '\u0421\u0417\u0410\u0414\u0418',
                            imageUrl: _currentPhotos['backUrl']?.toString(),
                            locked: _photosLocked,
                            onUpload: _photosLocked
                                ? null
                                : () => _pickAndUpload('back', setModalState),
                            onDelete: _photosLocked
                                ? null
                                : () => _deleteMeasurement('back', setModalState),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.black12,
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _formatMonthRangeNumeric(_currentMonthKey),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppTheme.mutedColor(context),
                                        ),
                                  ),
                                ),
                                Text(
                                  _weightController.text.isEmpty
                                      ? '\u2014'
                                      : '${_weightController.text} \u043a\u0433',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppTheme.mutedColor(context),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadWeightProgress(StateSetter setModalState) async {
    if (_weightProgressLoading) return;
    _weightProgressLoading = true;
    setModalState(() {});
    try {
      final weight = await _api.fetchWeightHistory(weeks: 12);
      final measures = await _api.fetchMeasurementsHistory(months: 12);
      final logs = (weight['logs'] as List? ?? const []).cast<Map<String, dynamic>>();
      final items = (measures['items'] as List? ?? const []).cast<Map<String, dynamic>>();
      final logMap = <String, Map<String, dynamic>>{};
      for (final log in logs) {
        final key = log['weekStart']?.toString() ?? '';
        if (key.isNotEmpty) logMap[key] = log;
      }
      final photoMap = <String, Map<String, dynamic>>{};
      for (final item in items) {
        final key = item['weekStart']?.toString() ?? '';
        if (key.isNotEmpty) photoMap[key] = item;
      }
      final currentLog = logMap[_currentWeekKey];
      if (currentLog != null && currentLog['weightKg'] != null) {
        _weightEntryController.text = '${currentLog['weightKg']}';
        _weightController.text = '${currentLog['weightKg']}';
      }
      final currentPhotos = photoMap[_currentMonthKey] ?? {};
      _currentPhotos = currentPhotos;
      _photosLocked = currentPhotos['locked'] == true;
      _waistController.text = currentPhotos['waistCm'] != null
          ? '${currentPhotos['waistCm']}'
          : '';
      _chestController.text = currentPhotos['chestCm'] != null
          ? '${currentPhotos['chestCm']}'
          : '';
      _hipController.text = currentPhotos['hipsCm'] != null
          ? '${currentPhotos['hipsCm']}'
          : '';
    } finally {
      _weightProgressLoaded = true;
      _weightProgressLoading = false;
      setModalState(() {});
    }
  }

  Future<void> _saveWeight(StateSetter setModalState) async {
    final value = double.tryParse(_weightEntryController.text.replaceAll(',', '.'));
    if (value == null) {
      _showStub(context, '\u0412\u0432\u0435\u0434\u0438\u0442\u0435 \u0432\u0435\u0441');
      return;
    }
    if (_isGuestUser) {
      _showStub(
        context,
        '\u0420\u0435\u0434\u0430\u043a\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u0438\u0435 \u043d\u0435\u0434\u043e\u0441\u0442\u0443\u043f\u043d\u043e \u0432 \u0433\u043e\u0441\u0442\u0435\u0432\u043e\u043c \u0434\u043e\u0441\u0442\u0443\u043f\u0435.',
      );
      return;
    }
    try {
      final res = await _api.postWeight(
        weightKg: value,
        weekStart: _currentWeekKey,
        timezoneOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
      );
      if (res['error'] == 'locked') {
        _showStub(
          context,
          '\u0412\u0435\u0441 \u043c\u043e\u0436\u043d\u043e \u043c\u0435\u043d\u044f\u0442\u044c \u0442\u043e\u043b\u044c\u043a\u043e \u0432 \u0442\u0435\u0447\u0435\u043d\u0438\u0435 24 \u0447\u0430\u0441\u043e\u0432 \u043f\u043e\u0441\u043b\u0435 \u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u0438\u044f.',
        );
        return;
      }
      if (res['ok'] != true) {
        _showStub(context, '\u041e\u0448\u0438\u0431\u043a\u0430 \u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u0438\u044f');
        return;
      }
      await _loadWeightProgress(setModalState);
    } catch (_) {
      _showStub(context, '\u041e\u0448\u0438\u0431\u043a\u0430 \u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u0438\u044f');
    }
  }

  Future<void> _saveMeasurements(StateSetter setModalState) async {
    final waist = double.tryParse(_waistController.text.replaceAll(',', '.'));
    final chest = double.tryParse(_chestController.text.replaceAll(',', '.'));
    final hips = double.tryParse(_hipController.text.replaceAll(',', '.'));
    if (waist == null && chest == null && hips == null) {
      _showStub(context, '\u0412\u0432\u0435\u0434\u0438\u0442\u0435 \u0445\u043e\u0442\u044f \u0431\u044b \u043e\u0434\u0438\u043d \u0437\u0430\u043c\u0435\u0440');
      return;
    }
    if (_isGuestUser) {
      _showStub(
        context,
        '\u0420\u0435\u0434\u0430\u043a\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u0438\u0435 \u043d\u0435\u0434\u043e\u0441\u0442\u0443\u043f\u043d\u043e \u0432 \u0433\u043e\u0441\u0442\u0435\u0432\u043e\u043c \u0434\u043e\u0441\u0442\u0443\u043f\u0435.',
      );
      return;
    }
    try {
      final res = await _api.postMeasurementsMetrics(
        waistCm: waist,
        chestCm: chest,
        hipsCm: hips,
        monthStart: _currentMonthKey,
        timezoneOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
      );
      if (res['error'] == 'locked') {
        _showStub(
          context,
          '\u0417\u0430\u043c\u0435\u0440\u044b \u043c\u043e\u0436\u043d\u043e \u043c\u0435\u043d\u044f\u0442\u044c \u0442\u043e\u043b\u044c\u043a\u043e \u0432 \u0442\u0435\u0447\u0435\u043d\u0438\u0435 3 \u0434\u043d\u0435\u0439 \u043f\u043e\u0441\u043b\u0435 \u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u0438\u044f.',
        );
        return;
      }
      if (res['ok'] != true) {
        _showStub(context, '\u041e\u0448\u0438\u0431\u043a\u0430 \u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u0438\u044f');
        return;
      }
      await _loadWeightProgress(setModalState);
    } catch (_) {
      _showStub(context, '\u041e\u0448\u0438\u0431\u043a\u0430 \u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u0438\u044f');
    }
  }

  Future<void> _pickAndUpload(String side, StateSetter setModalState) async {
    if (_isGuestUser) {
      _showStub(
        context,
        '\u0420\u0435\u0434\u0430\u043a\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u0438\u0435 \u043d\u0435\u0434\u043e\u0441\u0442\u0443\u043f\u043d\u043e \u0432 \u0433\u043e\u0441\u0442\u0435\u0432\u043e\u043c \u0434\u043e\u0441\u0442\u0443\u043f\u0435.',
      );
      return;
    }
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final upload = await _api.getMeasurementsUploadUrl(
      side: side,
      fileName: file.name,
      contentType: file.mimeType ?? 'image/jpeg',
      size: bytes.length,
      monthStart: _currentMonthKey,
      timezoneOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
    );
    if (upload == null) {
      _showStub(context, '\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438');
      return;
    }
    if (upload['error'] == 'locked') {
      _showStub(
        context,
        '\u0424\u043e\u0442\u043e \u043c\u043e\u0436\u043d\u043e \u043c\u0435\u043d\u044f\u0442\u044c \u0438\u043b\u0438 \u0443\u0434\u0430\u043b\u044f\u0442\u044c \u0442\u043e\u043b\u044c\u043a\u043e \u0432 \u0442\u0435\u0447\u0435\u043d\u0438\u0435 3 \u0434\u043d\u0435\u0439 \u043f\u043e\u0441\u043b\u0435 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438.',
      );
      return;
    }
    if (upload['ok'] != true || upload['uploadUrl'] == null || upload['objectKey'] == null) {
      _showStub(context, '\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438');
      return;
    }
    final ok = await _api.putUpload(upload['uploadUrl'] as String, bytes,
        contentType: file.mimeType ?? 'image/jpeg');
    if (!ok) {
      _showStub(context, '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044c');
      return;
    }
    final saved = await _api.postMeasurement(
      side: side,
      objectKey: upload['objectKey'] as String,
      monthStart: _currentMonthKey,
    );
    if (saved['error'] == 'locked') {
      _showStub(
        context,
        '\u0424\u043e\u0442\u043e \u043c\u043e\u0436\u043d\u043e \u043c\u0435\u043d\u044f\u0442\u044c \u0438\u043b\u0438 \u0443\u0434\u0430\u043b\u044f\u0442\u044c \u0442\u043e\u043b\u044c\u043a\u043e \u0432 \u0442\u0435\u0447\u0435\u043d\u0438\u0435 3 \u0434\u043d\u0435\u0439 \u043f\u043e\u0441\u043b\u0435 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438.',
      );
      return;
    }
    if (saved['ok'] != true) {
      _showStub(context, '\u041e\u0448\u0438\u0431\u043a\u0430 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438');
      return;
    }
    await _loadWeightProgress(setModalState);
  }

  Future<void> _deleteMeasurement(String side, StateSetter setModalState) async {
    if (_isGuestUser) {
      _showStub(
        context,
        '\u0420\u0435\u0434\u0430\u043a\u0442\u0438\u0440\u043e\u0432\u0430\u043d\u0438\u0435 \u043d\u0435\u0434\u043e\u0441\u0442\u0443\u043f\u043d\u043e \u0432 \u0433\u043e\u0441\u0442\u0435\u0432\u043e\u043c \u0434\u043e\u0441\u0442\u0443\u043f\u0435.',
      );
      return;
    }
    final res = await _api.deleteMeasurement(side: side, monthStart: _currentMonthKey);
    if (res['error'] == 'locked') {
      _showStub(
        context,
        '\u0424\u043e\u0442\u043e \u043c\u043e\u0436\u043d\u043e \u043c\u0435\u043d\u044f\u0442\u044c \u0438\u043b\u0438 \u0443\u0434\u0430\u043b\u044f\u0442\u044c \u0442\u043e\u043b\u044c\u043a\u043e \u0432 \u0442\u0435\u0447\u0435\u043d\u0438\u0435 3 \u0434\u043d\u0435\u0439 \u043f\u043e\u0441\u043b\u0435 \u0437\u0430\u0433\u0440\u0443\u0437\u043a\u0438.',
      );
      return;
    }
    if (res['ok'] != true) {
      _showStub(context, '\u041e\u0448\u0438\u0431\u043a\u0430 \u0443\u0434\u0430\u043b\u0435\u043d\u0438\u044f');
      return;
    }
    await _loadWeightProgress(setModalState);
  }

  String _getWeekStartKey(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final day = (d.weekday + 6) % 7;
    final start = d.subtract(Duration(days: day));
    return _toYmd(start);
  }

  String _getMonthStartKey(DateTime date) {
    final d = DateTime.utc(date.year, date.month, 1);
    return _toYmd(d);
  }

  String _toYmd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatWeekRangeNumeric(String weekStart) {
    if (weekStart.isEmpty) return '';
    final start = DateTime.parse('${weekStart}T00:00:00Z').toLocal();
    final end = start.add(const Duration(days: 6));
    return '${_formatDateShort(start)} - ${_formatDateShort(end)}';
  }

  String _formatMonthRangeNumeric(String monthStart) {
    if (monthStart.isEmpty) return '';
    final start = DateTime.parse('${monthStart}T00:00:00Z').toLocal();
    final end = DateTime(start.year, start.month + 1, 0);
    return '${_formatDateShort(start)} - ${_formatDateShort(end)}';
  }

  String _formatDateShort(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d.$m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final heightText = _heightController.text.trim();
    final weightText = _weightController.text.trim();
    final ageText = _ageController.text.trim();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: AppTheme.cardColor(context),
                  border: Border.all(color: Colors.white10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: isDark
                              ? const Color(0xFF2A2B2F)
                              : Colors.black12,
                          backgroundImage: (_avatarUrl != null &&
                                  _avatarUrl!.isNotEmpty)
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                              ? Text(
                                  _name.isNotEmpty ? _name[0] : '\u041c',
                                  style: TextStyle(
                                    color: AppTheme.accentColor(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(letterSpacing: 1.1),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _username,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppTheme.mutedColor(context)),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(999),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoChip(text: 'ID: $_userId'),
                        _InfoChip(text: '\u0422\u0410\u0420\u0418\u0424: $_tariff'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _StatCard(
                          title: '\u0420\u041e\u0421\u0422',
                          value: heightText.isEmpty
                              ? '\u2014'
                              : '$heightText \u0441\u043c',
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          title: '\u0412\u0415\u0421',
                          value: weightText.isEmpty
                              ? '\u2014'
                              : '$weightText \u043a\u0433',
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          title: '\u0412\u041e\u0417\u0420\u0410\u0421\u0422',
                          value: ageText.isEmpty ? '\u2014' : '$ageText \u043b\u0435\u0442',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _ActionRow(
                      title: '\u0414\u0418\u041d\u0410\u041c\u0418\u041a\u0410 \u0412\u0415\u0421\u0410',
                      buttonText: '\u041e\u0422\u041a\u0420\u042b\u0422\u042c',
                      onTap: () => _openWeightDynamics(context),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.black12,
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\u0420\u0415\u0414\u0410\u041a\u0422\u041e\u0420 \u041f\u0420\u041e\u0424\u0418\u041b\u042f',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  letterSpacing: 2,
                                  color: AppTheme.mutedColor(context),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                                Expanded(
                                  child: _FieldBlock(
                                    label: '\u0420\u041e\u0421\u0422 (\u0421\u041c)',
                                    controller: _heightController,
                                    enabled: _profileEditable,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _FieldBlock(
                                    label: '\u0412\u0415\u0421 (\u041a\u0413)',
                                    controller: _weightController,
                                    enabled: _profileEditable,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _FieldBlock(
                                    label: '\u0412\u041e\u0417\u0420\u0410\u0421\u0422',
                                    controller: _ageController,
                                    enabled: _profileEditable,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: 160,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentColor(context),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onPressed: _profileSaving ? null : _saveProfile,
                                child: const Text('\u0421\u041e\u0425\u0420\u0410\u041d\u0418\u0422\u042c'),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () => _logout(context),
                        child: const Text('\u0412\u042b\u0419\u0422\u0418'),
                      ),
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

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black12,
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.black12,
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(letterSpacing: 1.6, color: AppTheme.mutedColor(context)),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String title;
  final String buttonText;
  final VoidCallback onTap;
  const _ActionRow({
    required this.title,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black12,
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(letterSpacing: 1.6),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor(context),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: onTap,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  const _FieldBlock({
    required this.label,
    required this.controller,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(letterSpacing: 1.4, color: AppTheme.mutedColor(context)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          enabled: enabled,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black12,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _InlineField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  const _InlineField({required this.hint, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppTheme.cardColor(context).withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _WeightPhotoCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final VoidCallback? onUpload;
  final VoidCallback? onDelete;
  final bool locked;
  const _WeightPhotoCard({
    required this.title,
    this.imageUrl,
    this.onUpload,
    this.onDelete,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppTheme.cardColor(context).withOpacity(0.55),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(letterSpacing: 1.6, color: AppTheme.mutedColor(context)),
          ),
          const SizedBox(height: 10),
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppTheme.cardColor(context).withOpacity(0.5),
              border: Border.all(color: Colors.white10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: (imageUrl != null && imageUrl!.isNotEmpty)
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _photoPlaceholder(context),
                    )
                  : _photoPlaceholder(context),
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              TextButton(
                onPressed: locked ? null : onUpload,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textColor(context),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
                child: Text(
                  '\u0417\u0410\u0413\u0420\u0423\u0417\u0418\u0422\u042c',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(letterSpacing: 1.4),
                ),
              ),
              const SizedBox(height: 2),
              TextButton(
                onPressed: locked ? null : onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textColor(context),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
                child: Text(
                  '\u0423\u0414\u0410\u041b\u0418\u0422\u042c',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(letterSpacing: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder(BuildContext context) {
    return Center(
      child: Text(
        '\u0424\u043e\u0442\u043e \u0435\u0449\u0435 \u043d\u0435 \u0437\u0430\u0433\u0440\u0443\u0436\u0435\u043d\u043e',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AppTheme.mutedColor(context)),
        textAlign: TextAlign.center,
      ),
    );
  }
}

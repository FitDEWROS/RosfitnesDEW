import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../app.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/steps_service.dart';

enum TrainingMode { gym, crossfit }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  TrainingMode _mode = TrainingMode.crossfit;
  bool _chatAllowed = false;
  String? _trainerName;
  String? _avatarUrl;
  String? _firstName;
  String _tariffName = '\u0412\u043b\u0430\u0434\u0435\u043b\u0435\u0446';
  String _tariffLabel = '\u0412\u043b\u0430\u0434\u0435\u043b\u0435\u0446';
  bool _isStaffUser = false;
  bool _updateChecked = false;
  static const String _pendingModeKey = 'pending_training_mode';
  static const String _pendingTariffKey = 'pending_tariff_code';
  double? _profileWeightKg;
  static const String _pendingPaymentKey = 'pending_payment_id';
  final ApiService _api = ApiService();
  final StepsService _stepsService = StepsService();
  StreamSubscription<int>? _stepsSub;
  int? _steps;
  bool _stepsAvailable = true;
  DateTime? _lastStepsSentAt;
  int _lastStepsSentValue = -1;
  final ScrollController _scrollController = ScrollController();
  final _metricsKey = GlobalKey();
  final _workoutsKey = GlobalKey();
  int _activeNav = 0;
  double _scrollOffset = 0;
  late final AnimationController _glowController;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleScroll);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _glowController, curve: Curves.easeInOut);
    _loadPrefs();
    _initSteps();
    _checkPendingPayment();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _glowController.dispose();
    _stepsSub?.cancel();
    _stepsService.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final modeRaw = prefs.getString('training_mode');
    final tariffName = prefs.getString('tariff_name');
    final auth = AuthService();
    final avatarUrl = await auth.getProfilePhotoUrl();
    final firstName = await auth.getFirstName();
    final profile = await _api.fetchUserProfile();

    if (!mounted) return;
    setState(() {
      _avatarUrl = avatarUrl;
      _firstName = firstName;
      final profileTariff = profile?['tariffName']?.toString();
      final role = profile?['role']?.toString() ?? 'user';
      final isCurator = profile?['isCurator'] == true || role == 'curator';
      _isStaffUser = role == 'admin' || role == 'sadmin' || isCurator;
      final weightRaw = profile?['weightKg'];
      if (weightRaw is num) {
        _profileWeightKg = weightRaw.toDouble();
      } else if (weightRaw is String) {
        _profileWeightKg = double.tryParse(weightRaw.replaceAll(',', '.'));
      } else {
        _profileWeightKg = null;
      }
      final rawTariff = (profileTariff != null && profileTariff.trim().isNotEmpty)
          ? profileTariff.trim()
          : (tariffName != null ? tariffName.trim() : '');
      _tariffName = rawTariff;
      if (rawTariff.isNotEmpty) {
        prefs.setString('tariff_name', _tariffName);
      }
      _tariffLabel = _displayTariff(rawTariff, role, isCurator);
      final trainer = profile?['trainer'];
      String? trainerName;
      bool hasCurator = false;
      if (trainer is Map) {
        final name = trainer['name']?.toString().trim();
        final username = trainer['username']?.toString().trim();
        if (name != null && name.isNotEmpty) {
          trainerName = name;
        } else if (username != null && username.isNotEmpty) {
          trainerName = username;
        }
        hasCurator = trainer['id'] != null;
      }
      final chatTariff = _isChatTariff(rawTariff);
      _chatAllowed = role == 'user' && !isCurator && chatTariff && hasCurator;
      _trainerName = trainerName;
      final profileMode = profile?['trainingMode']?.toString();
      if (profileMode == 'gym' || profileMode == 'crossfit') {
        _mode = profileMode == 'gym' ? TrainingMode.gym : TrainingMode.crossfit;
        prefs.setString('training_mode', profileMode!);
      } else if (modeRaw == 'gym') {
        _mode = TrainingMode.gym;
      } else {
        _mode = TrainingMode.crossfit;
      }
    });
  }

  Future<void> _initSteps() async {
    final cached = await _stepsService.loadCachedSteps();
    if (cached != null && mounted) {
      setState(() => _steps = cached);
    }

    final allowed = await _stepsService.ensurePermission();
    if (!allowed) {
      if (mounted) {
        setState(() => _stepsAvailable = false);
      }
      return;
    }

    await _stepsService.start();
    _stepsSub = _stepsService.stepsStream.listen(
      (value) {
        if (!mounted) return;
        setState(() {
          _steps = value;
          _stepsAvailable = true;
        });
        _sendStepsThrottled(value);
      },
      onError: (_) {
        if (mounted) setState(() => _stepsAvailable = false);
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingPayment();
    }
  }

  Future<void> _checkPendingPayment() async {
    final prefs = await SharedPreferences.getInstance();
    final paymentId = prefs.getString(_pendingPaymentKey);
    if (paymentId == null || paymentId.isEmpty) return;
    try {
      final res = await _api.confirmPayment(paymentId: paymentId);
      final paid = res['paid'] == true;
      if (paid) {
        final pendingTariff = prefs.getString(_pendingTariffKey);
        final pendingMode = prefs.getString(_pendingModeKey);
        final tariffCode = res['tariff']?.toString();
        if ((tariffCode == 'base' || pendingTariff == 'base') && pendingMode != null) {
          try {
            final modeRes = await _api.updateTrainingMode(mode: pendingMode);
            if (modeRes['ok'] == true) {
              await prefs.setString('training_mode', pendingMode);
              if (mounted) {
                setState(() {
                  _mode = pendingMode == 'gym' ? TrainingMode.gym : TrainingMode.crossfit;
                });
              }
            }
          } catch (_) {}
        }
        await prefs.remove(_pendingPaymentKey);
        await prefs.remove(_pendingTariffKey);
        await prefs.remove(_pendingModeKey);
        if (!mounted) return;
        await _loadPrefs();
        _showStub(context, 'Платеж подтвержден. Тариф активирован.');
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _sendStepsThrottled(int steps) async {
    final now = DateTime.now();
    if (_lastStepsSentAt != null) {
      final diff = now.difference(_lastStepsSentAt!);
      if (steps == _lastStepsSentValue && diff.inMinutes < 5) return;
      if (diff.inSeconds < 30) return;
    }
    _lastStepsSentAt = now;
    _lastStepsSentValue = steps;
    try {
      await _api.postSteps(
        steps: steps,
        timezoneOffsetMin: now.timeZoneOffset.inMinutes,
      );
    } catch (_) {}
  }

  Future<void> _saveMode(TrainingMode value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'training_mode',
      value == TrainingMode.gym ? 'gym' : 'crossfit',
    );
    try {
      await _api.updateTrainingMode(
        mode: value == TrainingMode.gym ? 'gym' : 'crossfit',
      );
    } catch (_) {}
  }

  void _handleScroll() {
    final metrics = _sectionOffset(_metricsKey);
    final workouts = _sectionOffset(_workoutsKey);
    final offset = _scrollController.offset;

    int next = 0;
    if (workouts != null && offset >= workouts - 120) {
      next = 2;
    } else if (metrics != null && offset >= metrics - 120) {
      next = 1;
    }

    if (next != _activeNav) {
      setState(() => _activeNav = next);
    }
    if ((offset - _scrollOffset).abs() > 1) {
      setState(() => _scrollOffset = offset);
    }
  }

  double? _sectionOffset(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final position = box.localToGlobal(Offset.zero);
    final top = position.dy + _scrollController.offset;
    return top;
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final target = _sectionOffset(key);
    if (target == null) return;
    await _scrollController.animateTo(
      target - 90,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _showStub(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Future<void> _checkForUpdate() async {
    if (_updateChecked) return;
    _updateChecked = true;
    Map<String, dynamic> data;
    try {
      data = await _api.fetchAppUpdateInfo();
    } catch (_) {
      return;
    }
    if (data['ok'] != true) return;
    final latestCode = _toInt(data['versionCode']);
    final minCode = _toInt(data['minVersionCode']);
    final url = data['url']?.toString();
    final versionName = data['versionName']?.toString();
    if (latestCode == null || url == null || url.isEmpty) return;

    PackageInfo pkg;
    try {
      pkg = await PackageInfo.fromPlatform();
    } catch (_) {
      return;
    }
    final currentCode = int.tryParse(pkg.buildNumber) ?? 0;
    if (latestCode <= currentCode) return;
    if (!mounted) return;

    final forceUpdate = minCode != null && currentCode < minCode;
    await showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) {
        return AlertDialog(
          title: const Text('Доступно обновление'),
          content: Text(
            versionName != null && versionName.isNotEmpty
                ? 'Новая версия: $versionName'
                : 'Доступна новая версия приложения.',
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Позже'),
              ),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Обновить'),
            ),
          ],
        );
      },
    );
  }

  String _normalizeTariff(String? tariff) {
    final value = (tariff ?? '').toLowerCase();
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _compactTariff(String? tariff) {
    return _normalizeTariff(tariff).replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
  }

  bool _isBasicTariff(String? tariff) {
    final compact = _compactTariff(tariff);
    return compact.contains('\u0431\u0430\u0437\u043e\u0432');
  }

  bool _isGuestTariff(String? tariff) {
    final normalized = _normalizeTariff(tariff);
    if (normalized.isEmpty) return true;
    if (normalized.contains('\u0433\u043e\u0441\u0442')) return true;
    final compact = _compactTariff(tariff);
    return compact.contains('\u0431\u0435\u0437\u0442\u0430\u0440\u0438\u0444');
  }

  bool _isChatTariff(String? tariff) {
    final value = (tariff ?? '').toLowerCase();
    return value.contains('\u043e\u043f\u0442\u0438\u043c') || value.contains('\u043c\u0430\u043a\u0441');
  }

  String _displayTariff(String tariff, String? role, bool isCurator) {
    if (role == 'sadmin') return '\u0412\u043b\u0430\u0434\u0435\u043b\u0435\u0446';
    if (role == 'admin') return '\u0410\u0434\u043c\u0438\u043d';
    if (role == 'curator' || isCurator) return '\u041a\u0443\u0440\u0430\u0442\u043e\u0440';
    if (_isGuestTariff(tariff)) return '\u0413\u043e\u0441\u0442\u0435\u0432\u043e\u0439';
    return tariff.isNotEmpty ? tariff : '\u0411\u0435\u0437 \u0442\u0430\u0440\u0438\u0444\u0430';
  }

  String _formatSimple(num? value) {
    if (value == null) return '-';
    final rounded = (value * 10).round() / 10;
    return rounded % 1 == 0 ? rounded.toStringAsFixed(0) : rounded.toStringAsFixed(1);
  }

  void _openTariffModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TariffModal(
        current: _tariffName,
        onBuy: (name) => _startPayment(context, name),
      ),
    );
  }

  String? _tariffCodeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('баз')) return 'base';
    if (lower.contains('оптим')) return 'optimal';
    if (lower.contains('макс')) return 'maximum';
    return null;
  }

  Future<String?> _selectBasicMode(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = AppTheme.isDark(sheetContext);
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1B1E) : const Color(0xFFF6EBD3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Выберите режим',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleMedium
                    ?.copyWith(letterSpacing: 1.2),
              ),
              const SizedBox(height: 6),
              Text(
                'Для базового тарифа переключение будет недоступно.',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.mutedColor(sheetContext)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, 'gym'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor(sheetContext),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('ЗАЛ'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, 'crossfit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textColor(sheetContext),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('КРОССФИТ'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Отмена'),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _startPayment(BuildContext context, String tariffName) async {
    Navigator.pop(context);
    final code = _tariffCodeFromName(tariffName);
    if (code == null) {
      _showStub(context, 'Не удалось определить тариф.');
      return;
    }
    String? pendingMode;
    if (code == 'base') {
      pendingMode = await _selectBasicMode(context);
      if (pendingMode == null) return;
    }
    try {
      final res = await _api.createPayment(tariffCode: code);
      final url = res['confirmationUrl']?.toString() ?? '';
      final paymentId = res['paymentId']?.toString() ?? '';
      if (url.isEmpty || paymentId.isEmpty) {
        _showStub(context, 'Ошибка создания платежа.');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingPaymentKey, paymentId);
      await prefs.setString(_pendingTariffKey, code);
      if (pendingMode != null) {
        await prefs.setString(_pendingModeKey, pendingMode);
      }
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showStub(context, 'Не удалось открыть оплату.');
      }
    } catch (_) {
      _showStub(context, 'Не удалось создать платеж.');
    }
  }

  void _openChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatSheet(counterpartName: _trainerName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final parallax = (_scrollOffset * 0.02).clamp(-4.0, 4.0);
    final stepsValue = _steps != null ? _steps.toString() : '—';
    final stepsStatus =
        (_stepsAvailable && _steps != null) ? 'СЕГОДНЯ' : 'НЕТ ДАННЫХ';
    final isBasic = _isBasicTariff(_tariffName);
    final isGuest = _isGuestTariff(_tariffName);
    final nutritionLocked = !_isStaffUser && (isBasic || isGuest);
    final metricsLocked = !_isStaffUser && isGuest;
    final modeLocked = !_isStaffUser && isBasic;
    final weightValue = _formatSimple(_profileWeightKg);
    final weightStatus = _profileWeightKg != null ? 'ПРОФИЛЬ' : 'НЕТ ДАННЫХ';

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 140),
              cacheExtent: 800,
              children: [
              const SizedBox(height: 12),
              Text(
                'ПРИВЕТ',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 2.6,
                      color: AppTheme.mutedColor(context),
                    ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 118,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_firstName ?? 'МАКСИМ').toUpperCase(),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(letterSpacing: 1.2),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                            child: InkWell(
                              onTap: () => _openTariffModal(context),
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  _tariffLabel.toUpperCase(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(letterSpacing: 1.2),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Transform.translate(
                          offset: Offset(0, parallax * -0.6),
                          child: SizedBox(
                            width: 110,
                            height: 118,
                            child: Image.asset(
                              'assets/emblem.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Transform.translate(
                        offset: Offset(0, parallax * -0.6),
                        child: SizedBox(
                          width: 96,
                          height: 86,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (_chatAllowed)
                                Positioned(
                                  right: 58,
                                  top: 0,
                                  child: _IconBubble(
                                    icon: Icons.chat_bubble_outline,
                                    onTap: () => _openChat(context),
                                    backgroundColor: AppTheme.accentColor(context),
                                    iconColor: Colors.black,
                                  ),
                                ),
                              Positioned(
                                left: 0,
                                top: 38,
                                child: Stack(
                                  children: [
                                    _IconBubble(
                                      icon: Icons.notifications_none,
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        '/notifications',
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentColor(context),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '0',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 30,
                                top: 0,
                                child: _IconBubble(
                                  icon: AppScope.of(context).mode == ThemeMode.dark
                                      ? Icons.nights_stay_outlined
                                      : Icons.wb_sunny_outlined,
                                  onTap: () => AppScope.of(context).toggle(),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 38,
                                child: InkWell(
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    '/profile',
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: isDark
                                        ? const Color(0xFF2A2B2F)
                                        : Colors.black12,
                                    backgroundImage: (_avatarUrl != null &&
                                            _avatarUrl!.isNotEmpty)
                                        ? NetworkImage(_avatarUrl!)
                                        : null,
                                    child: (_avatarUrl == null ||
                                            _avatarUrl!.isEmpty)
                                        ? Text(
                                            _firstName != null &&
                                                    _firstName!.trim().isNotEmpty
                                                ? _firstName!.trim()[0].toUpperCase()
                                                : 'М',
                                            style: TextStyle(
                                              color: AppTheme.accentColor(context),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _StatsCard(
                pulse: _glow,
                sheen: _scrollOffset,
                locked: nutritionLocked,
                onTap: () => Navigator.pushNamed(context, '/diary'),
                onLockedTap: () => _showStub(
                  context,
                  '\u0414\u043d\u0435\u0432\u043d\u0438\u043a \u043f\u0438\u0442\u0430\u043d\u0438\u044f \u043d\u0435\u0434\u043e\u0441\u0442\u0443\u043f\u0435\u043d \u043d\u0430 \u0431\u0430\u0437\u043e\u0432\u043e\u043c \u0442\u0430\u0440\u0438\u0444\u0435.',
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ПОКАЗАТЕЛИ',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 2.4,
                          color: AppTheme.mutedColor(context),
                        ),
                  ),
                  Text(
                    'ПОДРОБНЕЕ',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 2.0,
                          color: AppTheme.mutedColor(context),
                        ),
                  )
                ],
              ),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: _metricsKey,
                child: Column(
                  children: [
                    _MetricPill(
                      title: 'Вес',
                      value: weightValue,
                      unit: 'кг',
                      status: weightStatus,
                      color: Color(0xFFCBE7BA),
                      pulse: _glow,
                      sheen: _scrollOffset,
                      locked: metricsLocked,
                    ),
                    const SizedBox(height: 10),
                    _MetricPill(
                      title: 'Шаги',
                      value: stepsValue,
                      unit: 'шаг',
                      status: stepsStatus,
                      color: Color(0xFFC7E7F7),
                      pulse: _glow,
                      sheen: _scrollOffset,
                      locked: metricsLocked,
                    ),
                    const SizedBox(height: 10),
                    _MetricPill(
                      title: 'Приемы пищи',
                      value: '0',
                      unit: 'раз',
                      status: 'НЕТ ДАННЫХ',
                      color: Color(0xFFF2D88D),
                      pulse: _glow,
                      sheen: _scrollOffset,
                      highlightSheen: true,
                      locked: nutritionLocked,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'УПРАЖНЕНИЯ',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 2.4,
                      color: AppTheme.mutedColor(context),
                    ),
              ),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: _workoutsKey,
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        title: 'УПРАЖНЕНИЯ',
                        subtitle: 'База упражнений: зал и кроссфит.',
                        accent: true,
                        onTap: () => Navigator.pushNamed(
                          context,
                          _mode == TrainingMode.crossfit
                              ? '/exercises_crossfit'
                              : '/exercises',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        title: 'ПРОГРАММЫ',
                        subtitle: 'Готовые планы и расписания.',
                        accent: false,
                        onTap: () => Navigator.pushNamed(context, '/programs'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _UsefulCard(
                onTap: () => Navigator.pushNamed(context, '/programs'),
              ),
            ],
          ),
        ),
      ],
    ),
      bottomNavigationBar: _BottomShell(
        mode: _mode,
        onModeChanged: (value) {
          setState(() => _mode = value);
          _saveMode(value);
        },
        modeLocked: modeLocked,
        onModeLocked: () => _showStub(
          context,
          '\u041f\u0435\u0440\u0435\u043a\u043b\u044e\u0447\u0435\u043d\u0438\u0435 \u0434\u043e\u0441\u0442\u0443\u043f\u043d\u043e \u043d\u0430 \u0442\u0430\u0440\u0438\u0444\u0430\u0445 \u041e\u043f\u0442\u0438\u043c\u0430\u043b\u044c\u043d\u044b\u0439 \u0438 \u041c\u0430\u043a\u0441\u0438\u043c\u0443\u043c.',
        ),
        child: _BottomBar(
          activeIndex: _activeNav,
          onHome: () {
            setState(() => _activeNav = 0);
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
            );
          },
          onWorkouts: () {
            setState(() => _activeNav = 2);
            _scrollTo(_workoutsKey);
          },
          onMetrics: () {
            setState(() => _activeNav = 1);
            _scrollTo(_metricsKey);
          },
          onProfile: () {
            setState(() => _activeNav = 3);
            Navigator.of(context).pushNamed('/profile');
          },
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;
  const _IconBubble({
    required this.icon,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: backgroundColor ?? (isDark ? Colors.white10 : Colors.black12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          icon,
          color: iconColor ?? (isDark ? Colors.white70 : Colors.black87),
          size: 20,
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final Animation<double> pulse;
  final double sheen;
  final bool locked;
  final VoidCallback? onTap;
  final VoidCallback? onLockedTap;
  const _StatsCard({
    required this.pulse,
    required this.sheen,
    this.locked = false,
    this.onTap,
    this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final shift = (sheen * 0.002) % 1.0;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final glow = 0.22 + 0.08 * pulse.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentColor(context).withOpacity(glow),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.accentColor(context),
                  AppTheme.accentStrongColor(context),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 24,
                  offset: Offset(0, 12),
                )
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Opacity(
                      opacity: 0.18,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1.2 + 2.4 * shift, -1),
                            end: Alignment(-0.2 + 2.4 * shift, 1),
                            colors: const [
                              Color(0x80FFFFFF),
                              Color(0x00FFFFFF),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -10,
                  child: SizedBox(
                    height: 28,
                    child: CustomPaint(
                      painter: _WavePainter(
                        color: Colors.black.withOpacity(0.15),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '0',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(
                              color: Colors.black, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ККАЛ',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.black54, letterSpacing: 2),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        _SmallStat(title: 'Б', value: '0'),
                        SizedBox(width: 12),
                        _SmallStat(title: 'Ж', value: '0'),
                        SizedBox(width: 12),
                        _SmallStat(title: 'У', value: '0'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: locked ? onLockedTap : onTap,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.black.withOpacity(0.15),
                        ),
                        child: Text(
                          'ДНЕВНИК ПИТАНИЯ',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  letterSpacing: 1.6, color: Colors.black87),
                        ),
                      ),
                    )
                  ],
                ),
                if (locked)
                  Positioned.fill(
                    child: _LockOverlay(
                      borderRadius: BorderRadius.circular(28),
                      compact: false,
                      message:
                          '\u0414\u043d\u0435\u0432\u043d\u0438\u043a \u043f\u0438\u0442\u0430\u043d\u0438\u044f \u043d\u0435\u0434\u043e\u0441\u0442\u0443\u043f\u0435\u043d \u043d\u0430 \u0431\u0430\u0437\u043e\u0432\u043e\u043c \u0442\u0430\u0440\u0438\u0444\u0435.',
                      onTap: onLockedTap,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String title;
  final String value;
  const _SmallStat({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withOpacity(0.12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.black54, letterSpacing: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.black, fontWeight: FontWeight.w700),
          )
        ],
      ),
    );
  }
}

class _LockOverlay extends StatelessWidget {
  final BorderRadius borderRadius;
  final bool compact;
  final String? message;
  final VoidCallback? onTap;
  const _LockOverlay({
    required this.borderRadius,
    this.compact = false,
    this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final overlayColor = isDark
        ? Colors.black.withOpacity(0.35)
        : Colors.white.withOpacity(0.55);
    final iconColor = isDark ? Colors.white70 : Colors.black54;
    final textColor = isDark ? Colors.white : Colors.black87;
    return ClipRRect(
      borderRadius: borderRadius,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? () {},
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: overlayColor,
            child: Center(
              child: compact
                  ? Icon(Icons.lock, color: iconColor, size: 20)
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: iconColor, size: 24),
                          const SizedBox(height: 8),
                          Text(
                            message ?? '',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: textColor, letterSpacing: 1.1),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TariffCard extends StatelessWidget {
  final String current;
  final VoidCallback onBuy;
  const _TariffCard({required this.current, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppTheme.cardColor(context),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '\u041d\u0410\u0428 \u0422\u0410\u0420\u0418\u0424',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(letterSpacing: 2.2, color: AppTheme.mutedColor(context)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onBuy,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      current,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(letterSpacing: 1.1),
                    ),
                  ),
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
                onPressed: onBuy,
                child: const Text('\u0422\u0410\u0420\u0418\u0424\u042b'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TariffChip(
                label: '\u0411\u0410\u0417\u041e\u0412\u042b\u0419',
                active: current.toLowerCase().contains('\u0431\u0430\u0437'),
              ),
              const _TariffChip(label: '\u041e\u041f\u0422\u0418\u041c\u0410\u041b\u042c\u041d\u042b\u0419'),
              _TariffChip(
                label: '\u041c\u0410\u041a\u0421\u0418\u041c\u0423\u041c',
                active: current.toLowerCase().contains('\u043c\u0430\u043a\u0441'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '\u0414\u043e\u0441\u0442\u0443\u043f\u043d\u043e \u0434\u043b\u044f \u043f\u043e\u043a\u0443\u043f\u043a\u0438',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedColor(context),
                ),
          ),
        ],
      ),
    );
  }
}

class _TariffModal extends StatefulWidget {
  final String current;
  final ValueChanged<String> onBuy;
  const _TariffModal({required this.current, required this.onBuy});

  @override
  State<_TariffModal> createState() => _TariffModalState();
}

class _TariffModalState extends State<_TariffModal> {
  int _selected = 0;
  final List<_TariffOption> _options = const [
    _TariffOption(
      name: '\u0411\u0430\u0437\u043e\u0432\u044b\u0439',
      desc:
          '\u0414\u043e\u0441\u0442\u0443\u043f \u043a \u0442\u0440\u0435\u043d\u0438\u0440\u043e\u0432\u043a\u0430\u043c \u0438 \u0431\u0430\u0437\u043e\u0432\u044b\u043c \u0440\u0430\u0437\u0434\u0435\u043b\u0430\u043c.',
    ),
    _TariffOption(
      name: '\u041e\u043f\u0442\u0438\u043c\u0430\u043b\u044c\u043d\u044b\u0439',
      desc:
          '\u0422\u0440\u0435\u043d\u0438\u0440\u043e\u0432\u043a\u0438 \u043f\u043b\u044e\u0441 \u0440\u0430\u0441\u0448\u0438\u0440\u0435\u043d\u043d\u044b\u0435 \u0441\u0446\u0435\u043d\u0430\u0440\u0438\u0438 \u0438 \u043a\u0443\u0440\u0430\u0442\u043e\u0440.',
    ),
    _TariffOption(
      name: '\u041c\u0430\u043a\u0441\u0438\u043c\u0443\u043c',
      desc:
          '\u0412\u0435\u0441\u044c \u0444\u0443\u043d\u043a\u0446\u0438\u043e\u043d\u0430\u043b, \u0434\u043e\u043f. \u043c\u0430\u0442\u0435\u0440\u0438\u0430\u043b\u044b \u0438 \u043f\u0440\u043e\u0434\u0432\u0438\u043d\u0443\u0442\u044b\u0439 \u043f\u043b\u0430\u043d.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final idx = _options.indexWhere(
      (o) => widget.current.toLowerCase().contains(o.name.toLowerCase()),
    );
    if (idx >= 0) _selected = idx;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 40),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isDark
                    ? const Color(0xFF1C1B1E).withOpacity(0.96)
                    : const Color(0xFFF6EBD3).withOpacity(0.96),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '\u0422\u0410\u0420\u0418\u0424\u042b',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(letterSpacing: 1.4),
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
                  const SizedBox(height: 12),
                  ..._options.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final opt = entry.value;
                    final active = idx == _selected;
                    return InkWell(
                      onTap: () => setState(() => _selected = idx),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: active
                              ? AppTheme.accentColor(context)
                                  .withOpacity(isDark ? 0.28 : 0.22)
                              : (isDark ? Colors.white10 : Colors.black12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              opt.desc,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.mutedColor(context)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor(context),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => widget.onBuy(_options[_selected].name),
                      child: const Text('\u041a\u0423\u041f\u0418\u0422\u042c'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TariffOption {
  final String name;
  final String desc;
  const _TariffOption({required this.name, required this.desc});
}

class _TariffChip extends StatelessWidget {
  final String label;
  final bool active;
  const _TariffChip({required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: active ? AppTheme.accentColor(context) : Colors.transparent,
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.4,
              color: active
                  ? Colors.black
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String status;
  final Color color;
  final Animation<double> pulse;
  final double sheen;
  final bool highlightSheen;
  final bool locked;
  const _MetricPill({
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.color,
    required this.pulse,
    required this.sheen,
    this.highlightSheen = false,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final shift = (sheen * 0.002) % 1.0;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final glow = 0.16 + 0.06 * pulse.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(glow),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color,
                        Color.lerp(color, Colors.white, 0.2)!,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: Colors.black),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              status,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Colors.black.withOpacity(0.6),
                                    letterSpacing: 1.8,
                                  ),
                            )
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text(
                                value,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                unit,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: Colors.black.withOpacity(0.65),
                                      letterSpacing: 1.2,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                if (highlightSheen)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.18,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-1.2 + 2.4 * shift, -1),
                            end: Alignment(-0.2 + 2.4 * shift, 1),
                            colors: const [
                              Color(0x80FFFFFF),
                              Color(0x00FFFFFF),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (locked)
                  Positioned.fill(
                    child: _LockOverlay(
                      borderRadius: BorderRadius.circular(24),
                      compact: true,
                      onTap: null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool accent;
  final VoidCallback onTap;
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final cardColor = accent ? null : AppTheme.cardColor(context);
    final titleColor =
        accent ? Colors.black : (isDark ? Colors.white : Colors.black);
    final subColor = accent
        ? Colors.black.withOpacity(0.65)
        : (isDark ? AppTheme.mutedColor(context) : Colors.black54);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 170,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: accent ? null : Colors.transparent,
          gradient: accent
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentColor(context),
                    AppTheme.accentStrongColor(context),
                  ],
                )
              : null,
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 6),
            )
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: SizedBox(
                height: 24,
                child: CustomPaint(
                  painter: _WavePainter(
                    color: accent
                        ? Colors.black.withOpacity(0.15)
                        : (isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(letterSpacing: 1.6, color: titleColor),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: subColor),
                ),
              ],
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: _ArrowButton(accent: accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsefulCard extends StatelessWidget {
  final VoidCallback onTap;
  const _UsefulCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.transparent,
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ПОЛЕЗНАЯ\nИНФОРМАЦИЯ',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(letterSpacing: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Гайды, подсказки и ответы на вопросы.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppTheme.mutedColor(context)),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accentColor(context),
                    AppTheme.accentStrongColor(context),
                  ],
                ),
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(24),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 18,
                    child: SizedBox(
                      height: 22,
                      child: CustomPaint(
                        painter: _WavePainter(
                          color: Colors.black.withOpacity(0.18),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: _ArrowButton(accent: true),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final bool accent;
  const _ArrowButton({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: accent ? Colors.black : Colors.white10,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.arrow_forward,
        size: 18,
        color: accent ? Colors.white : Colors.white70,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color color;
  _WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.cubicTo(
      size.width * 0.25,
      size.height * 0.2,
      size.width * 0.45,
      size.height * 1.0,
      size.width * 0.7,
      size.height * 0.55,
    );
    path.cubicTo(
      size.width * 0.85,
      size.height * 0.3,
      size.width * 0.95,
      size.height * 0.6,
      size.width,
      size.height * 0.45,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NoisePainter extends CustomPainter {
  final double opacity;
  final int seed;
  const _NoisePainter({this.opacity = 0.015, this.seed = 1337});

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
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => false;
}

class _ModeToggle extends StatelessWidget {
  final TrainingMode value;
  final ValueChanged<TrainingMode> onChanged;
  final bool locked;
  final VoidCallback? onLockedTap;
  const _ModeToggle({
    required this.value,
    required this.onChanged,
    this.locked = false,
    this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final isGym = value == TrainingMode.gym;

    return Container(
      width: 220,
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isDark ? const Color(0xFF1A1A1D) : Colors.white,
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: isGym ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: SizedBox(
              width: 104,
              height: 28,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentColor(context),
                            AppTheme.accentStrongColor(context),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentColor(context).withOpacity(0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: locked ? onLockedTap : () => onChanged(TrainingMode.gym),
                  borderRadius: BorderRadius.circular(999),
                  child: Center(
                    child: Text(
                      'ЗАЛ',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 2.0,
                            color: isGym
                                ? Colors.black
                                : (isDark
                                    ? Colors.white70
                                    : Colors.black54),
                          ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: locked
                      ? onLockedTap
                      : () => onChanged(TrainingMode.crossfit),
                  borderRadius: BorderRadius.circular(999),
                  child: Center(
                    child: Text(
                      'КРОССФИТ',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            letterSpacing: 2.0,
                            color: !isGym
                                ? Colors.black
                                : (isDark
                                    ? Colors.white70
                                    : Colors.black54),
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (locked)
            Positioned.fill(
              child: _LockOverlay(
                borderRadius: BorderRadius.circular(999),
                compact: true,
                onTap: onLockedTap,
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomShell extends StatelessWidget {
  final TrainingMode mode;
  final ValueChanged<TrainingMode> onModeChanged;
  final bool modeLocked;
  final VoidCallback? onModeLocked;
  final Widget child;
  const _BottomShell({
    required this.mode,
    required this.onModeChanged,
    required this.modeLocked,
    this.onModeLocked,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModeToggle(
              value: mode,
              onChanged: onModeChanged,
              locked: modeLocked,
              onLockedTap: onModeLocked,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF17181B) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int activeIndex;
  final VoidCallback onHome;
  final VoidCallback onWorkouts;
  final VoidCallback onMetrics;
  final VoidCallback onProfile;
  const _BottomBar({
    required this.activeIndex,
    required this.onHome,
    required this.onMetrics,
    required this.onWorkouts,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _BottomItem(icon: Icons.home, active: activeIndex == 0, onTap: onHome),
        _BottomItem(
          icon: Icons.fitness_center,
          active: activeIndex == 2,
          onTap: onWorkouts,
        ),
        _BottomItem(
          icon: Icons.bar_chart,
          active: activeIndex == 1,
          onTap: onMetrics,
        ),
        _BottomItem(icon: Icons.person, active: false, onTap: onProfile),
      ],
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _BottomItem({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? AppTheme.accentColor(context) : Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppTheme.accentColor(context).withOpacity(0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: active
              ? Colors.black
              : (isDark ? Colors.white70 : Colors.black54),
          size: 20,
        ),
      ),
    );
  }
}

enum _ChatMediaKind { image, video }

class _ChatMedia {
  final String url;
  final String? type;
  final String? name;
  final int? size;
  const _ChatMedia({
    required this.url,
    this.type,
    this.name,
    this.size,
  });

  factory _ChatMedia.fromJson(Map<String, dynamic> json) {
    return _ChatMedia(
      url: json['url']?.toString() ?? '',
      type: json['type']?.toString(),
      name: json['name']?.toString(),
      size: json['size'] is num ? (json['size'] as num).toInt() : null,
    );
  }
}

class _ChatMessage {
  final int? id;
  final String? text;
  final DateTime? createdAt;
  final DateTime? readAt;
  final bool isMine;
  final _ChatMedia? media;

  const _ChatMessage({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.readAt,
    required this.isMine,
    required this.media,
  });

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    final mediaRaw = json['media'];
    _ChatMedia? media;
    if (mediaRaw is Map && mediaRaw['url'] != null) {
      media = _ChatMedia.fromJson(Map<String, dynamic>.from(mediaRaw));
    }
    return _ChatMessage(
      id: json['id'] is num ? (json['id'] as num).toInt() : null,
      text: json['text']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      readAt: DateTime.tryParse(json['readAt']?.toString() ?? ''),
      isMine: json['isMine'] == true,
      media: media,
    );
  }
}

class _ChatSheet extends StatefulWidget {
  final String? counterpartName;
  const _ChatSheet({this.counterpartName});

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  static const int _maxUploadBytes = 50 * 1024 * 1024;
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _controller = TextEditingController();
  final Map<int, _ChatMessage> _messageMap = {};
  List<_ChatMessage> _messages = [];
  ScrollController? _scrollController;
  Timer? _pollTimer;
  bool _loading = true;
  bool _sending = false;
  String _subtitle = 'Онлайн консультация';
  int _lastId = 0;

  @override
  void initState() {
    super.initState();
    final name = widget.counterpartName?.trim();
    if (name != null && name.isNotEmpty) {
      _subtitle = 'Куратор: $name';
    }
    _loadInitial();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isNearBottom() {
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return true;
    final distance = controller.position.maxScrollExtent - controller.position.pixels;
    return distance < 80;
  }

  void _scrollToBottom() {
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    final data = await _api.fetchChatMessages(markRead: true);
    if (!mounted) return;
    _applyChatPayload(data, scrollToBottom: true);
    if (mounted) setState(() => _loading = false);
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      if (_loading) return;
      _pollMessages();
    });
  }

  Future<void> _pollMessages() async {
    final shouldScroll = _isNearBottom();
    final data = await _api.fetchChatMessages(
      afterId: _lastId > 0 ? _lastId : null,
      includeLast: true,
    );
    if (!mounted) return;
    _applyChatPayload(data, scrollToBottom: shouldScroll);
  }

  bool _applyChatPayload(Map<String, dynamic> data, {bool scrollToBottom = false}) {
    if (data['ok'] != true) return false;
    final prevLastId = _lastId;
    final counterpart = data['counterpart'];
    if (counterpart is Map) {
      final name = counterpart['name']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        _subtitle = 'Куратор: $name';
      }
    }

    final items = data['messages'];
    if (items is List) {
      for (final raw in items) {
        if (raw is! Map) continue;
        final msg = _ChatMessage.fromJson(Map<String, dynamic>.from(raw));
        final id = msg.id;
        if (id != null) {
          _messageMap[id] = msg;
          if (id > _lastId) _lastId = id;
        }
      }
    }

    _messages = _messageMap.values.toList()
      ..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    if (mounted) setState(() {});

    final hasNew = _lastId > prevLastId;
    if (scrollToBottom && hasNew) {
      _scrollToBottom();
    }
    return hasNew;
  }

  String _formatTimestamp(DateTime? date) {
    if (date == null) return '';
    final pad = (int value) => value.toString().padLeft(2, '0');
    return '${pad(date.day)}.${pad(date.month)}.${date.year} ${pad(date.hour)}:${pad(date.minute)}';
  }

  Future<void> _sendText() async {
    if (_sending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() => _sending = true);
    final data = await _api.sendChatMessage(text: text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (data['ok'] == true && data['message'] is Map) {
      _applyChatPayload({
        'ok': true,
        'messages': [data['message']]
      }, scrollToBottom: true);
      _scrollToBottom();
      return;
    }
    _showMessage('Не удалось отправить сообщение.');
  }

  Future<void> _pickAndSendMedia() async {
    if (_sending) return;
    final kind = await showModalBottomSheet<_ChatMediaKind>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Фото'),
                onTap: () => Navigator.pop(context, _ChatMediaKind.image),
              ),
              ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: const Text('Видео'),
                onTap: () => Navigator.pop(context, _ChatMediaKind.video),
              ),
            ],
          ),
        );
      },
    );
    if (kind == null) return;
    XFile? picked;
    if (kind == _ChatMediaKind.image) {
      picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    } else {
      picked = await _picker.pickVideo(source: ImageSource.gallery);
    }
    if (picked == null) return;
    await _uploadAndSendFile(picked);
  }

  String? _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    return null;
  }

  Future<void> _uploadAndSendFile(XFile picked) async {
    setState(() => _sending = true);
    try {
      final file = File(picked.path);
      final size = await file.length();
      if (size <= 0) {
        _showMessage('Файл пустой.');
        return;
      }
      if (size > _maxUploadBytes) {
        _showMessage('Файл больше 50 МБ. Выберите файл поменьше.');
        return;
      }
      final mime = picked.mimeType ?? _guessMimeType(picked.path);
      if (mime == null || (!mime.startsWith('image/') && !mime.startsWith('video/'))) {
        _showMessage('Можно отправлять только фото или видео.');
        return;
      }
      final fileName = picked.name.isNotEmpty ? picked.name : picked.path.split('/').last;
      final upload = await _api.createChatUploadUrl(
        fileName: fileName,
        contentType: mime,
        size: size,
      );
      if (upload['ok'] != true) {
        _showMessage('Не удалось загрузить файл.');
        return;
      }
      final uploadUrl = upload['uploadUrl']?.toString();
      final objectKey = upload['objectKey']?.toString();
      if (uploadUrl == null || objectKey == null) {
        _showMessage('Не удалось получить ссылку для загрузки.');
        return;
      }
      final bytes = await file.readAsBytes();
      final putRes = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': mime,
          'Content-Length': size.toString(),
        },
        body: bytes,
      );
      if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
        _showMessage('Ошибка загрузки файла.');
        return;
      }
      final send = await _api.sendChatMessage(
        mediaKey: objectKey,
        mediaType: mime,
        mediaName: fileName,
        mediaSize: size,
      );
      if (send['ok'] == true && send['message'] is Map) {
        _applyChatPayload({
          'ok': true,
          'messages': [send['message']]
        }, scrollToBottom: true);
        _scrollToBottom();
      } else {
        _showMessage('Не удалось отправить файл.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openMediaUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('Не удалось открыть файл.');
    }
  }

  Widget _buildMedia(_ChatMedia media, bool isMine, bool isDark) {
    final type = media.type ?? '';
    if (type.startsWith('image/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          media.url,
          width: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }
    return InkWell(
      onTap: () => _openMediaUrl(media.url),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMine ? Colors.black.withOpacity(0.1) : (isDark ? Colors.white10 : Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_fill),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                media.name ?? 'Видео',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(_ChatMessage message, bool isDark) {
    final mine = message.isMine;
    final bubbleColor = mine
        ? LinearGradient(
            colors: [
              AppTheme.accentColor(context),
              AppTheme.accentStrongColor(context),
            ],
          )
        : null;
    final textColor = mine ? Colors.black : AppTheme.textColor(context);
    final metaColor = mine ? Colors.black54 : AppTheme.mutedColor(context);
    final timeText = _formatTimestamp(message.createdAt);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: mine ? null : (isDark ? Colors.white10 : Colors.black12),
          gradient: bubbleColor,
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.media != null) _buildMedia(message.media!, mine, isDark),
            if (message.media != null && (message.text?.isNotEmpty ?? false))
              const SizedBox(height: 8),
            if (message.text != null && message.text!.isNotEmpty)
              Text(
                message.text!,
                style:
                    Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
              ),
            if (timeText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeText,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: metaColor),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 6),
                    Icon(
                      message.readAt != null ? Icons.done_all : Icons.check,
                      size: 14,
                      color: metaColor,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final sheetColor = AppTheme.cardColor(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        _scrollController = scrollController;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Чат с куратором',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.mutedColor(context)),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              'Сообщений пока нет',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.mutedColor(context)),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              return _buildBubble(message, isDark);
                            },
                          ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  InkWell(
                    onTap: _sending ? null : _pickAndSendMedia,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(Icons.attach_file, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Напишите сообщение...',
                        hintStyle:
                            TextStyle(color: AppTheme.mutedColor(context)),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.black12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onSubmitted: (_) => _sendText(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _sending ? null : _sendText,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor(context),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text('Отправить'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

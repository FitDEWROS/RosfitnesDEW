import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../app.dart';
import '../services/auth_service.dart';

enum TrainingMode { gym, crossfit }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  TrainingMode _mode = TrainingMode.crossfit;
  bool _chatAllowed = false;
  String? _avatarUrl;
  String? _firstName;
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
    _scrollController.addListener(_handleScroll);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _glowController, curve: Curves.easeInOut);
    _loadPrefs();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final modeRaw = prefs.getString('training_mode');
    final hasCurator = prefs.getBool('has_curator') ?? false;
    final auth = AuthService();
    final avatarUrl = await auth.getProfilePhotoUrl();
    final firstName = await auth.getFirstName();

    if (!mounted) return;
    setState(() {
      _chatAllowed = hasCurator;
      _avatarUrl = avatarUrl;
      _firstName = firstName;
      if (modeRaw == 'gym') {
        _mode = TrainingMode.gym;
      } else {
        _mode = TrainingMode.crossfit;
      }
    });
  }

  Future<void> _saveMode(TrainingMode value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'training_mode',
      value == TrainingMode.gym ? 'gym' : 'crossfit',
    );
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

  void _openChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChatSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final parallax = (_scrollOffset * 0.02).clamp(-4.0, 4.0);

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
                            child: Text(
                              'ВЛАДЕЛЕЦ',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(letterSpacing: 1.2),
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
              _StatsCard(pulse: _glow, sheen: _scrollOffset),
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
                      value: '91',
                      unit: 'кг',
                      status: 'ПРОФИЛЬ',
                      color: Color(0xFFCBE7BA),
                      pulse: _glow,
                      sheen: _scrollOffset,
                    ),
                    const SizedBox(height: 10),
                    _MetricPill(
                      title: 'Вода',
                      value: '0',
                      unit: 'л',
                      status: 'НЕТ ДАННЫХ',
                      color: Color(0xFFC7E7F7),
                      pulse: _glow,
                      sheen: _scrollOffset,
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
  const _StatsCard({required this.pulse, required this.sheen});

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
                      onTap: () => Navigator.pushNamed(context, '/diary'),
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

class _MetricPill extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String status;
  final Color color;
  final Animation<double> pulse;
  final double sheen;
  final bool highlightSheen;
  const _MetricPill({
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.color,
    required this.pulse,
    required this.sheen,
    this.highlightSheen = false,
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
  const _ModeToggle({required this.value, required this.onChanged});

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
                  onTap: () => onChanged(TrainingMode.gym),
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
                  onTap: () => onChanged(TrainingMode.crossfit),
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
        ],
      ),
    );
  }
}

class _BottomShell extends StatelessWidget {
  final TrainingMode mode;
  final ValueChanged<TrainingMode> onModeChanged;
  final Widget child;
  const _BottomShell({
    required this.mode,
    required this.onModeChanged,
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
            _ModeToggle(value: mode, onChanged: onModeChanged),
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

class _ChatSheet extends StatefulWidget {
  const _ChatSheet();

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final List<String> _messages = [
    'Привет! Я куратор, чем помочь?',
    'Хочу план на неделю.',
  ];
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _messages.add(text));
    _controller.clear();
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
                        'Онлайн консультация',
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
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final mine = index % 2 == 1;
                    final bubbleColor = mine
                        ? LinearGradient(
                            colors: [
                              AppTheme.accentColor(context),
                              AppTheme.accentStrongColor(context),
                            ],
                          )
                        : null;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: mine
                              ? null
                              : (isDark ? Colors.white10 : Colors.black12),
                          gradient: bubbleColor,
                        ),
                        child: Text(
                          _messages[index],
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: mine
                                    ? Colors.black
                                    : AppTheme.textColor(context),
                              ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Icon(Icons.attach_file, size: 18),
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
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _send,
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
                    child: const Text('Отправить'),
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

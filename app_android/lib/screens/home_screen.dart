import 'package:flutter/material.dart';
import '../theme.dart';
import '../app.dart';

enum TrainingMode { gym, crossfit }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TrainingMode _mode = TrainingMode.crossfit;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      body: Container(
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
                  Text('Fit dew', style: Theme.of(context).textTheme.titleLarge),
                  Row(
                    children: [
                      _IconBubble(
                        icon: Icons.chat_bubble_outline,
                        onTap: () => Navigator.pushNamed(context, '/chat'),
                        backgroundColor: AppTheme.accentColor(context),
                        iconColor: Colors.black,
                      ),
                      const SizedBox(width: 8),
                      _IconBubble(
                        icon: AppScope.of(context).mode == ThemeMode.dark
                            ? Icons.nights_stay_outlined
                            : Icons.wb_sunny_outlined,
                        onTap: () => AppScope.of(context).toggle(),
                      ),
                      const SizedBox(width: 8),
                      Stack(
                        children: [
                          _IconBubble(
                            icon: Icons.notifications_none,
                            onTap: () =>
                                Navigator.pushNamed(context, '/notifications'),
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
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                        borderRadius: BorderRadius.circular(999),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: isDark
                              ? const Color(0xFF2A2B2F)
                              : Colors.black12,
                          child: Text(
                            'М',
                            style: TextStyle(
                              color: AppTheme.accentColor(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'ПРИВЕТ',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 2.6,
                      color: AppTheme.mutedColor(context),
                    ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'МАКСИМ',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(letterSpacing: 1.2),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white10,
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
              const SizedBox(height: 16),
              _StatsCard(),
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
              _MetricPill(
                title: 'Вес',
                value: '91',
                unit: 'кг',
                status: 'ПРОФИЛЬ',
                color: const Color(0xFFCBE7BA),
              ),
              const SizedBox(height: 10),
              _MetricPill(
                title: 'Вода',
                value: '0',
                unit: 'л',
                status: 'НЕТ ДАННЫХ',
                color: const Color(0xFFC7E7F7),
              ),
              const SizedBox(height: 10),
              _MetricPill(
                title: 'Приемы пищи',
                value: '0',
                unit: 'раз',
                status: 'НЕТ ДАННЫХ',
                color: const Color(0xFFF2D88D),
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
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      title: 'УПРАЖНЕНИЯ',
                      subtitle: 'База упражнений: зал и кроссфит.',
                      accent: true,
                      onTap: () => Navigator.pushNamed(context, '/exercises'),
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
              const SizedBox(height: 14),
              _UsefulCard(
                onTap: () => Navigator.pushNamed(context, '/programs'),
              ),
              const SizedBox(height: 16),
              Center(
                child: _ModeToggle(
                  value: _mode,
                  onChanged: (value) {
                    setState(() => _mode = value);
                  },
                ),
              ),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(
        onHome: () {},
        onPrograms: () => Navigator.of(context).pushNamed('/programs'),
        onDiary: () => Navigator.of(context).pushNamed('/diary'),
        onMetrics: () => Navigator.of(context).pushNamed('/metrics'),
        onProfile: () => Navigator.of(context).pushNamed('/profile'),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white10,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, color: iconColor ?? Colors.white70, size: 20),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: AppTheme.accentColor(context),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, 12),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '0',
            style: Theme.of(context)
                .textTheme
                .headlineLarge
                ?.copyWith(color: Colors.black, fontWeight: FontWeight.w700),
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.black.withOpacity(0.15),
            ),
            child: Text(
              'ДНЕВНИК ПИТАНИЯ',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(letterSpacing: 1.6, color: Colors.black87),
            ),
          )
        ],
      ),
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
      width: 70,
      padding: const EdgeInsets.all(12),
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
  const _MetricPill({
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: color,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.black)),
                const SizedBox(height: 10),
                Text(
                  status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    unit,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
    final cardColor =
        accent ? AppTheme.accentColor(context) : AppTheme.cardColor(context);
    final titleColor = accent ? Colors.black : Colors.white;
    final subColor = accent
        ? Colors.black.withOpacity(0.65)
        : AppTheme.mutedColor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 170,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: cardColor,
          border: Border.all(color: Colors.white10),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 16,
              offset: Offset(0, 8),
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
                        : Colors.white12,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: AppTheme.cardColor(context),
          border: Border.all(color: Colors.white10),
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
                color: AppTheme.accentColor(context),
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
            child: Container(
              width: 100,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentColor(context),
                    AppTheme.accentStrongColor(context),
                  ],
                ),
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

class _BottomBar extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onPrograms;
  final VoidCallback onDiary;
  final VoidCallback onMetrics;
  final VoidCallback onProfile;
  const _BottomBar({
    required this.onHome,
    required this.onPrograms,
    required this.onDiary,
    required this.onMetrics,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgSoftColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BottomItem(icon: Icons.home, active: true, onTap: onHome),
          _BottomItem(
            icon: Icons.fitness_center,
            active: false,
            onTap: onPrograms,
          ),
          _BottomItem(icon: Icons.bar_chart, active: false, onTap: onMetrics),
          _BottomItem(icon: Icons.person, active: false, onTap: onProfile),
        ],
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: active ? AppTheme.accentColor(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: active ? Colors.black : Colors.white70),
      ),
    );
  }
}

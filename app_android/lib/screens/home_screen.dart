import 'package:flutter/material.dart';
import '../theme.dart';
import '../app.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                          backgroundColor: AppTheme.isDark(context)
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
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(
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
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          letterSpacing: 2.4,
                          color: AppTheme.mutedColor(context),
                        ),
                  ),
                  Text(
                    'ПОДРОБНЕЕ',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          letterSpacing: 2.0,
                          color: AppTheme.mutedColor(context),
                        ),
                  )
                ],
              ),
              const SizedBox(height: 12),
              _MetricsCard(),
              const SizedBox(height: 18),
              Text(
                'УПРАЖНЕНИЯ',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(
                      letterSpacing: 2.4,
                      color: AppTheme.mutedColor(context),
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickCard(
                      title: 'УПРАЖНЕНИЯ',
                      subtitle: 'База упражнений для кроссфита',
                      highlight: true,
                      onTap: () => Navigator.pushNamed(context, '/exercises'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickCard(
                      title: 'ПРОГРАММЫ',
                      subtitle: 'Готовые планы и прогрессии',
                      highlight: false,
                      onTap: () => Navigator.pushNamed(context, '/programs'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _InfoCard(),
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
            children: [
              _SmallStat(title: 'Б', value: '0'),
              const SizedBox(width: 12),
              _SmallStat(title: 'Ж', value: '0'),
              const SizedBox(width: 12),
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

class _MetricsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppTheme.cardColor(context),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 6),
              Text('Вес', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    _Toggle(label: 'ЗАЛ', active: false),
                    const SizedBox(width: 6),
                    _Toggle(label: 'КРОССФИТ', active: true),
                  ],
                ),
              ),
              Text(
                '91 кг',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppTheme.mutedColor(context)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MetricRow(label: 'Вода', value: '0 л'),
          const SizedBox(height: 10),
          _MetricRow(label: 'Приемы пищи', value: '0 раз'),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppTheme.mutedColor(context)),
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool active;
  const _Toggle({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: active ? AppTheme.accentColor(context) : Colors.white10,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: active ? Colors.black : Colors.white70,
              letterSpacing: 1.2,
            ),
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

class _QuickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool highlight;
  final VoidCallback onTap;
  const _QuickCard({
    required this.title,
    required this.subtitle,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: highlight
              ? AppTheme.accentColor(context)
              : AppTheme.cardColor(context),
          border: Border.all(
            color: highlight ? Colors.transparent : Colors.white10,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: highlight ? Colors.black : Colors.white,
                    letterSpacing: 1.4,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: highlight
                        ? Colors.black87
                        : AppTheme.mutedColor(context),
                  ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: highlight ? Colors.black12 : Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: highlight ? Colors.black : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppTheme.cardColor(context),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ПОЛЕЗНАЯ\nИНФОРМАЦИЯ',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(letterSpacing: 1.6),
                ),
                const SizedBox(height: 8),
                Text(
                  'Питание, техника и новости.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.mutedColor(context)),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.accentColor(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.article, color: Colors.black),
          ),
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

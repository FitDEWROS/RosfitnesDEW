import 'package:flutter/material.dart';
import '../theme.dart';

class MetricsScreen extends StatelessWidget {
  const MetricsScreen({super.key});

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
              Text('Fit dew', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _Header(
                title: 'Показатели',
                subtitle: 'Отслеживай прогресс и историю.',
              ),
              const SizedBox(height: 16),
              _MetricTile(title: 'Вес', value: '91 кг'),
              _MetricTile(title: 'Жир', value: '0 %'),
              _MetricTile(title: 'Тренировки', value: '0 за неделю'),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(current: 2),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: AppTheme.isDark(context)
            ? const LinearGradient(colors: [Color(0xFF1F1F22), Color(0xFF121214)])
            : const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF3EBDD)]),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor(context))),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  const _MetricTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppTheme.cardColor(context),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedColor(context))),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int current;
  const _BottomBar({required this.current});

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
          _NavItem(icon: Icons.home, active: current == 0, onTap: () => Navigator.pushNamed(context, '/home')),
          _NavItem(icon: Icons.fitness_center, active: current == 1, onTap: () => Navigator.pushNamed(context, '/programs')),
          _NavItem(icon: Icons.bar_chart, active: current == 2, onTap: () {}),
          _NavItem(icon: Icons.person, active: current == 3, onTap: () => Navigator.pushNamed(context, '/profile')),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.active, required this.onTap});

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

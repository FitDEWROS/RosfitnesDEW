import 'package:flutter/material.dart';
import '../theme.dart';

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.bg, Color(0xFF151518), Color(0xFF0C0C0D)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text('Fit dew', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _Header(title: '??????? ???????', subtitle: '???????? ?????? ???? ? ????? ?? ????.'),
              const SizedBox(height: 16),
              _StatRow(),
              const SizedBox(height: 16),
              _MealCard(title: '???????', time: '08:30', kcal: '0'),
              _MealCard(title: '????', time: '13:00', kcal: '0'),
              _MealCard(title: '????', time: '19:00', kcal: '0'),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(current: 1),
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
        gradient: const LinearGradient(colors: [Color(0xFF1F1F22), Color(0xFF121214)]),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.muted)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppTheme.accent,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SmallStat(label: '????', value: '0'),
          _SmallStat(label: '?', value: '0'),
          _SmallStat(label: '?', value: '0'),
          _SmallStat(label: '?', value: '0'),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  const _SmallStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black)),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black54, letterSpacing: 1.2)),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final String title;
  final String time;
  final String kcal;
  const _MealCard({required this.title, required this.time, required this.kcal});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1B1B1F),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.restaurant, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.muted)),
              ],
            ),
          ),
          Text('$kcal ????', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.muted)),
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
        color: const Color(0xFF15161A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavItem(icon: Icons.home, active: current == 0, onTap: () => Navigator.pushNamed(context, '/home')),
          _NavItem(icon: Icons.restaurant, active: current == 1, onTap: () {}),
          _NavItem(icon: Icons.bar_chart, active: current == 2, onTap: () => Navigator.pushNamed(context, '/metrics')),
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
          color: active ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: active ? Colors.black : Colors.white70),
      ),
    );
  }
}

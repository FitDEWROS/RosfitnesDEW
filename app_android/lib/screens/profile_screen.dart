import 'package:flutter/material.dart';
import '../theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
              Text('???????', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  const CircleAvatar(radius: 28, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=5')),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('??????', style: Theme.of(context).textTheme.titleMedium),
                      Text('????????', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.muted)),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 16),
              _Tile(title: '?????', value: '???????'),
              _Tile(title: '?????????', value: '????, ???????????'),
              _Tile(title: '?????', value: ''),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(current: 3),
    );
  }
}

class _Tile extends StatelessWidget {
  final String title;
  final String value;
  const _Tile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF1B1B1F),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.muted)),
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
          _NavItem(icon: Icons.restaurant, active: current == 1, onTap: () => Navigator.pushNamed(context, '/diary')),
          _NavItem(icon: Icons.bar_chart, active: current == 2, onTap: () => Navigator.pushNamed(context, '/metrics')),
          _NavItem(icon: Icons.person, active: current == 3, onTap: () {}),
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

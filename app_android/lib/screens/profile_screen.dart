import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final auth = AuthService();
    await auth.clearToken();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

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
              Text('Профиль', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.isDark(context)
                        ? const Color(0xFF2A2B2F)
                        : Colors.black12,
                    child: Text(
                      'М',
                      style: TextStyle(
                        color: AppTheme.accentColor(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Максим', style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        'Владелец',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.mutedColor(context)),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 16),
              _Tile(title: 'Цель', value: 'Рельеф'),
              _Tile(title: 'Программа', value: 'Код Атлета'),
              _Tile(title: 'Подписка', value: 'Активна'),
              const SizedBox(height: 12),
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
                  child: const Text('Выйти'),
                ),
              ),
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
        color: AppTheme.cardColor(context),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.mutedColor(context)),
          ),
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
          color: active ? AppTheme.accentColor(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: active ? Colors.black : Colors.white70),
      ),
    );
  }
}

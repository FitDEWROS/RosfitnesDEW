import 'package:flutter/material.dart';
import '../theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.bg,
              Color(0xFF151518),
              Color(0xFF0C0C0D),
            ],
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
                      _IconBubble(icon: Icons.chat_bubble_outline, onTap: () => Navigator.pushNamed(context, '/chat')),
                      const SizedBox(width: 8),
                      _IconBubble(icon: Icons.nights_stay_outlined, onTap: () {}),
                      const SizedBox(width: 8),
                      Stack(
                        children: [
                          _IconBubble(icon: Icons.notifications_none, onTap: () => Navigator.pushNamed(context, '/notifications')),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text('0', style: TextStyle(color: Colors.black, fontSize: 10)),
                              ),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(width: 8),
                      const CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=5'),
                      )
                    ],
                  )
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '??????',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(letterSpacing: 2.6, color: AppTheme.muted),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '??????',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(letterSpacing: 1.2),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: Colors.white10,
                    ),
                    child: Text(
                      '????????',
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
                    '??????????',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(letterSpacing: 2.4, color: AppTheme.muted),
                  ),
                  Text(
                    '?????????',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(letterSpacing: 2.0, color: AppTheme.muted),
                  )
                ],
              ),
              const SizedBox(height: 12),
              _MetricsCard(),
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
  const _IconBubble({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
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
        color: AppTheme.accent,
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
            '????',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.black54, letterSpacing: 2),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _SmallStat(title: '?', value: '0'),
              const SizedBox(width: 12),
              _SmallStat(title: '?', value: '0'),
              const SizedBox(width: 12),
              _SmallStat(title: '?', value: '0'),
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
              '??????? ???????',
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
        color: const Color(0xFF1B1B1F),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.home, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('???', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _Toggle(label: '???', active: false),
                    const SizedBox(width: 6),
                    _Toggle(label: '????????', active: true),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '91 ??',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppTheme.muted),
          ),
        ],
      ),
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
        color: active ? AppTheme.accent : Colors.white10,
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
  const _BottomBar({required this.onHome, required this.onPrograms, required this.onDiary, required this.onMetrics, required this.onProfile});

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
          _BottomItem(icon: Icons.home, active: true, onTap: onHome),
          _BottomItem(icon: Icons.bar_chart, active: false, onTap: onMetrics),
          _BottomItem(icon: Icons.widgets, active: false, onTap: onDiary),
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
  const _BottomItem({required this.icon, required this.active, required this.onTap});

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

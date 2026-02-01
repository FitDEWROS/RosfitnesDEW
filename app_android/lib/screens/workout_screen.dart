import 'package:flutter/material.dart';
import '../theme.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final exercises = [
      {
        'title': '?????? ?? ????????',
        'sub': '60 ??????',
        'done': true,
      },
      {
        'title': '??????-??????',
        'sub': '12 ????????',
        'done': false,
      },
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text('Fit dew', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppTheme.accent,
                  ),
                  child: Text(
                    '?????',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          color: Colors.black,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '???? 1',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(letterSpacing: 2),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '?????? 1 | ??? ?????? | ??????? ? ?',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.muted),
            ),
            const SizedBox(height: 18),
            Text(
              '????????????? ???????',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            for (final ex in exercises)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF1A1A1D),
                  border: Border.all(
                    color: ex['done'] == true
                        ? AppTheme.green.withOpacity(0.6)
                        : Colors.white12,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        '${exercises.indexOf(ex) + 1}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ex['title'] as String,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ex['sub'] as String,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),
                    if (ex['done'] == true)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6CE68A), Color(0xFF2AA84E)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.green.withOpacity(0.35),
                              blurRadius: 10,
                            )
                          ],
                        ),
                        child: const Icon(Icons.check, size: 14),
                      ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

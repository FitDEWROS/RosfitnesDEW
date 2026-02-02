import 'package:flutter/material.dart';
import '../theme.dart';

class ProgramDetailScreen extends StatelessWidget {
  const ProgramDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final headerGradient = AppTheme.isDark(context)
        ? const LinearGradient(
            colors: [Color(0xFF1F1F22), Color(0xFF121214)],
          )
        : const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF3EBDD)],
          );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const SizedBox.shrink(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: headerGradient,
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Код атлета',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(letterSpacing: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Функциональная мощь всего тела',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.mutedColor(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
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
                    'О программе',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(letterSpacing: 2, color: AppTheme.mutedColor(context)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '3 раза в неделю ты включаешь тело на максимум. '
                    'Без воды, без лишнего — только то, что реально работает.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.mutedColor(context), height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

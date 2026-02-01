import 'package:flutter/material.dart';
import '../theme.dart';

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key});

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Упражнение', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.black,
                ),
                child: const Center(child: Icon(Icons.play_circle, size: 48, color: Colors.white54)),
              ),
              const SizedBox(height: 12),
              Text('Прыжки на скакалке', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('60 секунд', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.muted)),
              const SizedBox(height: 12),
              Text('Как выполнять:', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 2.0, color: AppTheme.muted)),
              const SizedBox(height: 8),
              Text('Встань прямо, удерживая скакалку за ручки по бокам.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

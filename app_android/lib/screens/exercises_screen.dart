import 'package:flutter/material.dart';
import '../theme.dart';

class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'title': '?????? ?? ????????', 'tag': '??????'},
      {'title': '??????-??????', 'tag': '????'},
      {'title': '???????', 'tag': '????'},
    ];

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
                  Text('??????????', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 12),
              for (final item in items)
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/exercise'),
                  child: Container(
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['title']!, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(item['tag']!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.muted)),
                          ],
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white54),
                      ],
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}

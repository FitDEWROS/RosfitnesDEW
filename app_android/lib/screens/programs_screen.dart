import 'package:flutter/material.dart';
import '../models/program.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  late Future<List<Program>> _future;
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _future = _api.fetchPrograms();
  }

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
          child: FutureBuilder<List<Program>>(
            future: _future,
            builder: (context, snapshot) {
              final programs = snapshot.data ?? const <Program>[];
              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text('Fit dew', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _HeaderCard(),
                  const SizedBox(height: 20),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator()),
                  if (snapshot.hasError)
                    _EmptyState(
                      title: '?? ??????? ????????? ?????????',
                      subtitle: '????????? ?????????? ? ????????? ???????.',
                    ),
                  if (snapshot.connectionState == ConnectionState.done && programs.isEmpty)
                    _EmptyState(
                      title: '???? ??? ????????',
                      subtitle: '????? ???????? ????? ?????.',
                    ),
                  for (final program in programs) _ProgramCard(program: program),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1F22), Color(0xFF121214)],
        ),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 28,
            offset: Offset(0, 14),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: AppTheme.accent,
            ),
            child: Text(
              '?????',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.black,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '?????????',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(letterSpacing: 2.6, color: AppTheme.muted),
          ),
          const SizedBox(height: 6),
          Text(
            '????? ??????????',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(letterSpacing: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            '?????? ?????? ? ??????? ???????.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final Program program;
  const _ProgramCard({required this.program});

  @override
  Widget build(BuildContext context) {
    final tags = [
      program.type.isNotEmpty ? (program.type == 'gym' ? '???' : '????????') : '?????????',
      if (program.level.isNotEmpty) program.level,
      if (program.gender.isNotEmpty) program.gender,
    ];
    final stats = [
      if (program.frequency.isNotEmpty) program.frequency,
      if (program.weeksCount > 0) '${program.weeksCount} ??????',
      if (program.level.isNotEmpty) program.level,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFF1B1B1F),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, 12),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (program.coverImage.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Image.network(
                    program.coverImage,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    height: 150,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black26, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (program.coverImage.isNotEmpty) const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in tags)
                _Chip(label: tag.toUpperCase()),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            program.title.isNotEmpty ? program.title : '?????????',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 6),
          Text(
            program.subtitle.isNotEmpty ? program.subtitle : program.summary,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stat in stats)
                _Chip(label: stat.toUpperCase()),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white10,
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12, style: BorderStyle.solid),
        color: Colors.white10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return '';
    final pad = (int v) => v.toString().padLeft(2, '0');
    return '${pad(date.day)}.${pad(date.month)}.${date.year} ${pad(date.hour)}:${pad(date.minute)}';
  }

  Future<void> _loadNotifications() async {
    if (mounted) setState(() => _loading = true);
    Map<String, dynamic> data;
    try {
      data = await _api.fetchNotifications(limit: 50);
    } catch (_) {
      data = {'ok': false};
    }
    if (!mounted) return;
    if (data['ok'] == true) {
      final list = data['notifications'];
      if (list is List) {
        _items = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        _items = [];
      }
      _unreadCount = _toInt(data['unreadCount']);
    } else {
      _items = [];
      _unreadCount = 0;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markAllRead() async {
    await _api.markNotificationsRead(all: true);
    await _loadNotifications();
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
          child: RefreshIndicator(
            onRefresh: _loadNotifications,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Оповещения',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _unreadCount > 0
                          ? 'Непрочитано: $_unreadCount'
                          : 'Все уведомления прочитаны',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.mutedColor(context)),
                    ),
                    TextButton(
                      onPressed:
                          _items.isEmpty || _unreadCount == 0 ? null : _markAllRead,
                      child: const Text('Прочитать всё'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Оповещений пока нет.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.mutedColor(context)),
                    ),
                  )
                else
                  ..._items.map(
                    (item) => _NoticeItem(
                      title: item['title']?.toString().trim().isNotEmpty == true
                          ? item['title'].toString()
                          : 'Оповещение',
                      text: item['message']?.toString() ?? '',
                      meta: _formatDate(item['createdAt']),
                      unread: item['readAt'] == null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeItem extends StatelessWidget {
  final String title;
  final String text;
  final String meta;
  final bool unread;
  const _NoticeItem({
    required this.title,
    required this.text,
    required this.meta,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppTheme.cardColor(context),
        border: Border.all(
          color: unread
              ? AppTheme.accentColor(context).withOpacity(0.6)
              : (isDark ? Colors.white10 : Colors.black12),
        ),
        boxShadow: unread
            ? [
                BoxShadow(
                  color: AppTheme.accentColor(context).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (text.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.mutedColor(context)),
            ),
          ],
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              meta,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppTheme.mutedColor(context)),
            ),
          ],
        ],
      ),
    );
  }
}

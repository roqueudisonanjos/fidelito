import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _service = NotificationService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getNotifications();
  }

  Future<void> _refresh() async {
    setState(() => _future = _service.getNotifications());
    await _future;
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return '';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} às ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar as notificações: ${snapshot.error}',
                ),
              ),
            );
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 52),
                    SizedBox(height: 12),
                    Text('Você ainda não tem notificações.'),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = notifications[index];
                final unread = item['read_at'] == null;
                return Card(
                  elevation: 0,
                  color: unread
                      ? Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: .35)
                      : null,
                  child: ListTile(
                    leading: Icon(
                      unread
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_outlined,
                    ),
                    title: Text(
                      item['title']?.toString() ?? 'Notificação',
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['message']?.toString() ?? ''),
                          const SizedBox(height: 8),
                          Text(
                            _date(item['created_at']),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    isThreeLine: true,
                    onTap: unread
                        ? () async {
                            await _service.markAsRead(item['id'].toString());
                            if (mounted)
                              setState(
                                () => _future = _service.getNotifications(),
                              );
                          }
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

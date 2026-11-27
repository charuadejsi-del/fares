import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api.dart';
import 'order_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Stream<List<Map<String, dynamic>>> _stream = Api.notifications();
  final _date = DateFormat('yyyy/MM/dd HH:mm');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const Center(child: Text('لا توجد إشعارات'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = list[i];
              final unread = n['read'] != true;
              return ListTile(
                leading: Icon(
                    unread ? Icons.mark_email_unread : Icons.drafts_outlined,
                    color: unread
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey),
                title: Text(n['title'] as String,
                    style: TextStyle(
                        fontWeight:
                            unread ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text([
                  if (n['body'] != null) n['body'] as String,
                  _date.format(DateTime.parse(n['created_at'] as String).toLocal()),
                ].join('\n')),
                onTap: () {
                  if (unread) Api.markRead(n['id'] as int);
                  final orderId = n['order_id'] as String?;
                  if (orderId != null) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => OrderDetailScreen(orderId: orderId)));
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

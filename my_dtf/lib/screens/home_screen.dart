import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../core/labels.dart';
import '../services/api.dart';
import 'new_order_screen.dart';
import 'notifications_screen.dart';
import 'order_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Stream<List<Map<String, dynamic>>> _orders = Api.myOrders();
  late final Stream<List<Map<String, dynamic>>> _notifs = Api.notifications();
  final _date = DateFormat('yyyy/MM/dd HH:mm');

  @override
  void initState() {
    super.initState();
    Api.ensureProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _notifs,
            builder: (context, snap) {
              final unread =
                  (snap.data ?? []).where((n) => n['read'] != true).length;
              return IconButton(
                tooltip: 'الإشعارات',
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen())),
              );
            },
          ),
          IconButton(
            tooltip: 'خروج',
            icon: const Icon(Icons.logout),
            onPressed: Api.signOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('طلبية جديدة'),
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NewOrderScreen())),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _orders,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('خطأ: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snap.data!;
          if (orders.isEmpty) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                  'لا توجد طلبيات بعد.\nاضغط «طلبية جديدة» وارفع صورك لتعرف السعر فوراً.',
                  textAlign: TextAlign.center),
            ));
          }
          final total = orders
              .where((o) => o['status'] != 'rejected' && o['status'] != 'cancelled')
              .fold<num>(0, (s, o) => s + (o['print_amount'] as num) + (o['delivery_fee'] as num));
          final paid = orders.fold<num>(0, (s, o) => s + (o['amount_paid'] as num));
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat('الطلبيات', '${orders.length}'),
                      _Stat('المجموع', money(total)),
                      _Stat('المدفوع', money(paid)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final o in orders)
                Card(
                  child: ListTile(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                OrderDetailScreen(orderId: o['id'] as String))),
                    title: Text('طلبية #${o['code']}'),
                    subtitle: Text(
                        '${o['billed_meters']} م • ${money((o['print_amount'] as num) + (o['delivery_fee'] as num))}\n'
                        '${_date.format(DateTime.parse(o['created_at'] as String).toLocal())}'),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text(statusLabels[o['status']] ?? '${o['status']}'),
                      backgroundColor:
                          statusColor(o['status'] as String).withValues(alpha: .15),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

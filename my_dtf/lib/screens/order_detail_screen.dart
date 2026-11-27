import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/labels.dart';
import '../services/api.dart';

/// Étapes affichées au client, dans l'ordre.
const _steps = ['new', 'in_design', 'ready_to_print', 'printing', 'printed', 'shipped', 'delivered'];
const _pickupSteps = ['new', 'in_design', 'ready_to_print', 'printing', 'ready_pickup', 'delivered'];

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final Stream<List<Map<String, dynamic>>> _order =
      Api.order(widget.orderId);
  late Future<List<Map<String, dynamic>>> _events =
      Api.orderEvents(widget.orderId);
  late final Future<List<(Map<String, dynamic>, String)>> _images =
      _loadImages();
  final _date = DateFormat('yyyy/MM/dd HH:mm');
  String? _lastStatus;

  Future<List<(Map<String, dynamic>, String)>> _loadImages() async {
    final rows = await Api.orderImages(widget.orderId);
    return [
      for (final r in rows) (r, await Api.signedUrl(r['storage_path'] as String))
    ];
  }

  Future<void> _report() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('التبليغ عن مشكل'),
        content: TextField(
            controller: ctrl,
            maxLines: 4,
            decoration:
                const InputDecoration(hintText: 'صف المشكل (ألوان، مقاس، ...)')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('رجوع')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('إرسال')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    try {
      await Api.reportIssue(widget.orderId, ctrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('وصل تبليغك إلى الورشة')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _order,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return Scaffold(
              appBar: AppBar(),
              body: Center(
                  child: snap.hasError
                      ? Text('خطأ: ${snap.error}')
                      : const CircularProgressIndicator()));
        }
        final o = snap.data!.first;
        final status = o['status'] as String;
        if (_lastStatus != null && _lastStatus != status) {
          _events = Api.orderEvents(widget.orderId); // rafraîchir le journal
        }
        _lastStatus = status;
        final steps = o['delivery_mode'] == 'pickup' ? _pickupSteps : _steps;
        final current = steps.indexOf(status);
        final printAmount = o['print_amount'] as num;
        final fee = o['delivery_fee'] as num;
        final paid = o['amount_paid'] as num;

        return Scaffold(
          appBar: AppBar(title: Text('طلبية #${o['code']}')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Chip(
                        label: Text(statusLabels[status] ?? status),
                        backgroundColor:
                            statusColor(status).withValues(alpha: .15),
                      ),
                      if (status == 'rejected' && o['reject_reason'] != null)
                        Text('السبب: ${o['reject_reason']}'),
                      const SizedBox(height: 8),
                      Text(
                          o['final_length_cm'] != null
                              ? 'الأمتار النهائية: ${o['billed_meters']} م'
                              : 'الأمتار التقديرية: ${o['billed_meters']} م'),
                      Text('الطباعة: ${money(printAmount)}'),
                      Text('التوصيل: ${money(fee)} — ${deliveryLabels[o['delivery_mode']]}'),
                      const Divider(),
                      Text('المجموع: ${money(printAmount + fee)}',
                          style: Theme.of(context).textTheme.titleLarge),
                      if (paid > 0) Text('المدفوع: ${money(paid)}'),
                      if (o['tracking_number'] != null)
                        SelectableText(
                            'رقم التتبّع (${o['carrier'] ?? ''}): ${o['tracking_number']}'),
                    ],
                  ),
                ),
              ),
              if (current >= 0) ...[
                const SizedBox(height: 8),
                Card(
                  child: Column(children: [
                    for (var i = 0; i < steps.length; i++)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          i < current
                              ? Icons.check_circle
                              : i == current
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                          color: i <= current ? statusColor(status) : Colors.grey,
                        ),
                        title: Text(statusLabels[steps[i]]!,
                            style: TextStyle(
                                fontWeight: i == current
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ),
                  ]),
                ),
              ],
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _events,
                builder: (context, s) => Card(
                  child: ExpansionTile(
                    title: const Text('السجلّ'),
                    children: [
                      for (final e in s.data ?? [])
                        ListTile(
                          dense: true,
                          title: Text(statusLabels[e['to_status']] ?? '${e['to_status']}'),
                          trailing: Text(_date.format(
                              DateTime.parse(e['created_at'] as String).toLocal())),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('الصور', style: Theme.of(context).textTheme.titleMedium),
              FutureBuilder<List<(Map<String, dynamic>, String)>>(
                future: _images,
                builder: (context, s) {
                  if (!s.hasData) {
                    return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()));
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (r, url) in s.data!)
                        SizedBox(
                          width: 110,
                          child: Column(children: [
                            Image.network(url,
                                height: 90, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image)),
                            Text('${r['width_cm']}×${r['height_cm']} سم ×${r['quantity']}',
                                style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              if (status != 'new' && status != 'rejected')
                OutlinedButton.icon(
                  onPressed: _report,
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('التبليغ عن مشكل في الطباعة'),
                ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}

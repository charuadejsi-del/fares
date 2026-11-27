import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/labels.dart';
import '../core/nesting/nesting_engine.dart';
import '../core/pricing.dart';
import '../services/api.dart';
import '../widgets/nest_preview.dart';

const _palette = [
  Colors.teal, Colors.orange, Colors.purple, Colors.blue, Colors.pink,
  Colors.green, Colors.brown, Colors.indigo, Colors.red, Colors.cyan,
];

class _Img {
  final String id;
  final String name;
  final Uint8List bytes;
  final w = TextEditingController();
  final h = TextEditingController();
  final q = TextEditingController(text: '1');
  _Img(this.id, this.name, this.bytes);

  double? get width => double.tryParse(w.text.replaceAll(',', '.'));
  double? get height => double.tryParse(h.text.replaceAll(',', '.'));
  int? get qty => int.tryParse(q.text);
  bool get valid =>
      (width ?? 0) > 0 && (height ?? 0) > 0 && (qty ?? 0) > 0;
}

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  AppSettings? _settings;
  Map<String, dynamic>? _profile;
  String? _loadError;
  final _images = <_Img>[];
  int _seq = 0;

  NestResult? _nest;
  String? _nestError;

  String _mode = 'pickup';
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _commune = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  String? _wilaya;

  bool _sending = false;
  String _progress = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await Api.settings();
      final p = await Api.ensureProfile();
      setState(() {
        _settings = s;
        _profile = p;
        _name.text = p?['full_name'] ?? '';
        _phone.text = p?['phone'] ?? '';
        _wilaya = p?['wilaya'];
        _commune.text = p?['commune'] ?? '';
        _address.text = p?['address'] ?? '';
      });
    } catch (e) {
      setState(() => _loadError = '$e');
    }
  }

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
        type: FileType.image, allowMultiple: true, withData: true);
    if (res == null) return;
    setState(() {
      for (final f in res.files) {
        if (f.bytes == null) continue;
        _images.add(_Img('img${++_seq}', f.name, f.bytes!));
      }
    });
    _recompute();
  }

  void _recompute() {
    final s = _settings;
    if (s == null) return;
    final items = [
      for (final i in _images)
        if (i.valid)
          NestItem(
              id: i.id,
              widthCm: i.width!,
              heightCm: i.height!,
              quantity: i.qty!)
    ];
    setState(() {
      _nestError = null;
      try {
        _nest = NestingEngine(
                filmWidthCm: s.filmWidthCm,
                gapCm: s.gapCm,
                allowRotation: s.allowRotation)
            .nest(items);
      } on ItemTooWideException catch (e) {
        _nest = null;
        final idx = _images.indexWhere((i) => i.id == e.itemId) + 1;
        _nestError =
            'الصورة رقم $idx أكبر من عرض الفيلم (${s.filmWidthCm.toStringAsFixed(0)} سم)';
      }
    });
  }

  Quote? get _quote => (_nest == null || _settings == null)
      ? null
      : computeQuote(_nest!.lengthCm, _settings!.pricing);

  bool get _canSend =>
      !_sending &&
      _images.isNotEmpty &&
      _images.every((i) => i.valid) &&
      _nest != null &&
      _nestError == null &&
      (_mode == 'pickup' ||
          (_wilaya != null &&
              _name.text.trim().isNotEmpty &&
              _phone.text.trim().isNotEmpty &&
              _commune.text.trim().isNotEmpty &&
              (_mode == 'stopdesk' || _address.text.trim().isNotEmpty)));

  Future<void> _send() async {
    final q = _quote!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تأكيد الطلبية'),
        content: Text(
            'الأمتار التقديرية: ${q.billedMeters.toStringAsFixed(2)} م\n'
            'سعر الطباعة التقديري: ${money(q.printAmount)}\n'
            '${deliveryLabels[_mode]}\n\n'
            'قد يتغيّر السعر قليلاً بعد أن يرتّب المصمّم الصور، وستصلك رسالة بالسعر النهائي.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('رجوع')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('تأكيد')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _sending = true;
      _progress = 'جاري إنشاء الطلبية...';
    });
    try {
      final order = await Api.createOrder(
        estimatedLengthCm: _nest!.lengthCm,
        deliveryMode: _mode,
        deliveryFee: 0, // calculé via le transporteur (phase 5)
        ship: _mode == 'pickup'
            ? {'name': _name.text.trim(), 'phone': _phone.text.trim()}
            : {
                'name': _name.text.trim(),
                'phone': _phone.text.trim(),
                'wilaya': _wilaya,
                'commune': _commune.text.trim(),
                'address': _address.text.trim(),
              },
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        images: [
          for (final i in _images)
            OrderImageUpload(i.name, i.bytes, i.width!, i.height!, i.qty!)
        ],
        onProgress: (d, t) =>
            setState(() => _progress = 'رفع الصور $d / $t ...'),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم إرسال الطلبية #${order['code']} بنجاح')));
    } catch (e) {
      setState(() {
        _sending = false;
        _progress = '';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('فشل الإرسال: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('تعذّر التحميل: $_loadError')));
    }
    if (_settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_profile != null && _profile!['role'] != 'client') {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(
              child: Text('هذا الحساب خاص بالورشة، استعمل حساب زبون.')));
    }
    final s = _settings!;
    final quote = _quote;
    final colors = {
      for (var k = 0; k < _images.length; k++)
        _images[k].id: _palette[k % _palette.length]
    };
    final labels = {
      for (var k = 0; k < _images.length; k++) _images[k].id: '${k + 1}'
    };

    return Scaffold(
      appBar: AppBar(title: const Text('طلبية جديدة')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
              'ارفع صورك واكتب مقاس كل صورة بالسنتيمتر وعدد النسخ. '
              'عرض الفيلم ${s.filmWidthCm.toStringAsFixed(0)} سم.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          for (var k = 0; k < _images.length; k++) _imageCard(k, colors),
          OutlinedButton.icon(
            onPressed: _sending ? null : _pick,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('إضافة صور'),
          ),
          const SizedBox(height: 16),
          if (_nestError != null)
            Text(_nestError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (quote != null && _nest!.placements.isNotEmpty) ...[
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الطول التقديري: ${quote.billedMeters.toStringAsFixed(2)} م',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('سعر الطباعة: ${money(quote.printAmount)}',
                        style: Theme.of(context).textTheme.titleLarge),
                    if (s.pricing.minOrderAmount > 0)
                      Text('الحد الأدنى للطلبية: ${money(s.pricing.minOrderAmount)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    Text(
                        'نسبة استغلال الفيلم: ${(_nest!.fillRatio * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('معاينة ترتيب الصور على الفيلم:'),
            const SizedBox(height: 4),
            NestPreview(result: _nest!, colors: colors, labels: labels),
          ],
          const SizedBox(height: 20),
          Text('طريقة الاستلام', style: Theme.of(context).textTheme.titleMedium),
          for (final m in ['pickup', 'home', 'stopdesk'])
            RadioListTile<String>(
              value: m,
              groupValue: _mode,
              title: Text(deliveryLabels[m]!),
              onChanged: _sending ? null : (v) => setState(() => _mode = v!),
            ),
          if (_mode == 'pickup' && s.workshopAddress != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('عنوان الورشة: ${s.workshopAddress}'),
            ),
          if (_mode != 'pickup') ...[
            const SizedBox(height: 8),
            TextField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'اسم المستلم')),
            const SizedBox(height: 8),
            TextField(
                controller: _phone,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'هاتف المستلم')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _wilaya,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'الولاية'),
              items: [
                for (final (c, n) in wilayas)
                  DropdownMenuItem(value: n, child: Text('$c - $n')),
              ],
              onChanged: (v) => setState(() => _wilaya = v),
            ),
            const SizedBox(height: 8),
            TextField(
                controller: _commune,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'البلدية')),
            if (_mode == 'home') ...[
              const SizedBox(height: 8),
              TextField(
                  controller: _address,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'العنوان')),
            ],
            const SizedBox(height: 4),
            Text('سعر التوصيل يُضاف حسب الولاية وشركة التوصيل.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          TextField(
              controller: _note,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'ملاحظة للورشة (اختياري)')),
          const SizedBox(height: 20),
          if (_progress.isNotEmpty) ...[
            Text(_progress, textAlign: TextAlign.center),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: _canSend ? _send : null,
            icon: const Icon(Icons.send),
            label: const Text('إرسال الطلبية'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _imageCard(int k, Map<String, Color> colors) {
    final img = _images[k];
    InputDecoration dec(String l) =>
        InputDecoration(labelText: l, isDense: true);
    return Card(
      shape: RoundedRectangleBorder(
          side: BorderSide(color: colors[img.id]!, width: 2),
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: [
              CircleAvatar(
                  radius: 12,
                  backgroundColor: colors[img.id],
                  child: Text('${k + 1}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white))),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(img.bytes,
                    width: 64, height: 64, fit: BoxFit.contain),
              ),
            ]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(children: [
                Text(img.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: img.w,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: dec('العرض سم'),
                          onChanged: (_) => _recompute())),
                  const SizedBox(width: 6),
                  Expanded(
                      child: TextField(
                          controller: img.h,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: dec('الطول سم'),
                          onChanged: (_) => _recompute())),
                  const SizedBox(width: 6),
                  Expanded(
                      child: TextField(
                          controller: img.q,
                          keyboardType: TextInputType.number,
                          decoration: dec('العدد'),
                          onChanged: (_) => _recompute())),
                ]),
              ]),
            ),
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline),
              onPressed: _sending
                  ? null
                  : () {
                      setState(() => _images.removeAt(k));
                      _recompute();
                    },
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'theme.dart';

class _Page {
  final IconData icon;
  final String title;
  final String body;
  final String? example;
  const _Page(this.icon, this.title, this.body, [this.example]);
}

const _pages = [
  _Page(Icons.groups, 'لعبة لشخصين',
      'المشغّل يرى الأقفال لكنه لا يعرف كيف يفتحها.\nالخبير معه الدليل لكنه لا يرى الأقفال.\n\nلا أحد يستطيع الحلّ وحده: يجب أن تتكلّما!'),
  _Page(Icons.dialpad, '1. باب الرموز', 'المشغّل يرى 4 رموز ويصفها. الخبير يجد رقم كل رمز في جدوله.',
      'المشغّل: «بستوني، مربّع، شمس، دائرة»\nالخبير: «اكتب 6 0 3 9»'),
  _Page(Icons.cable, '2. صندوق الأسلاك', 'المشغّل يصف عدد الأسلاك وألوانها. الخبير يطبّق أوّل قاعدة صحيحة في دليله.',
      'المشغّل: «4 أسلاك: أحمر، أزرق، أحمر، أصفر»\nالخبير: «اقطع السلك رقم 3»'),
  _Page(Icons.translate, '3. المخطوط المشفّر', 'المشغّل يصف الرمز ثم يقرأ الحروف. الخبير يضغط على الرمز فيظهر له جدول الفكّ.',
      'المشغّل: «نفل… الحروف: ز، ض، غ»\nالخبير: «ب، ح، ر… الكلمة بحر!»'),
  _Page(Icons.explore, '4. السرداب المظلم', 'المشغّل لا يرى شيئاً. الخبير يرى الخريطة ويوجّهه خطوة بخطوة إلى الباب.',
      'الخبير: «فوق… يمين… يمين… تحت»'),
  _Page(Icons.lightbulb, '5. قفل الأضواء', 'المشغّل يرى أضواء تومض. الخبير يقول له أيّ زرّ يضغط حسب جدول المرحلة.',
      'المشغّل: «ومض الأحمر»\nالخبير: «اضغط الأخضر»'),
  _Page(Icons.timer, 'جاهزون؟', 'أمامكما 10 دقائق لفتح الأقفال الخمسة.\nكل خطأ يكلّف 30 ثانية، وكل اصطدام بجدار 10 ثوانٍ.\n\nفي وضع «هاتف واحد» يمكنك التبديل بين الدورين بزرّ الدور في الأعلى.'),
];

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _ctl = PageController();
  int _i = 0;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _pages.length - 1;
    return Scaffold(
      appBar: AppBar(backgroundColor: K.bg, elevation: 0, title: const Text('كيف تُلعب؟'), centerTitle: true),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView.builder(
              controller: _ctl,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (context, i) {
                final p = _pages[i];
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(children: [
                    const SizedBox(height: 20),
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: K.card, border: Border.all(color: K.gold, width: 3)),
                      child: Icon(p.icon, size: 54, color: K.gold),
                    ),
                    const SizedBox(height: 22),
                    Text(p.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    Text(p.body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, height: 1.6)),
                    if (p.example != null) ...[
                      const SizedBox(height: 18),
                      Panel(
                        border: K.gold.withAlpha(120),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('مثال', style: TextStyle(color: K.gold, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(p.example!, style: const TextStyle(fontSize: 16, height: 1.7)),
                        ]),
                      ),
                    ],
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < _pages.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _i ? 22 : 9,
                height: 9,
                decoration:
                    BoxDecoration(color: i == _i ? K.gold : K.line, borderRadius: BorderRadius.circular(99)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(18),
            child: FilledButton(
              style: bigButton(),
              onPressed: () {
                if (last) {
                  Navigator.of(context).pop();
                } else {
                  _ctl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                }
              },
              child: Text(last ? 'فهمت، لنلعب!' : 'التالي'),
            ),
          ),
        ]),
      ),
    );
  }
}

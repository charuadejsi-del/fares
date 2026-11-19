import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/services.dart';
import '../../widgets/spy_ui.dart';

class _Page {
  final IconData icon;
  final String code;
  final String title;
  final String body;
  final String? example;
  const _Page(this.icon, this.code, this.title, this.body, [this.example]);
}

const _pages = [
  _Page(Icons.groups_2_outlined, 'BRIEFING', 'فريق من شخصين',
      'العميل الميداني داخل المبنى أمام الأقفال، لكنه لا يعرف كيف يفتحها.\nالمحلّل في القاعدة معه الملفّات السرّية، لكنه لا يرى الأقفال.\n\nتكلّما، فلا أحد يستطيع الحلّ وحده.'),
  _Page(Icons.dialpad, 'LOCK 01', 'لوحة الدخول', 'العميل يصف 4 رموز، والمحلّل يجد رقم كل رمز في ملفّه.',
      'العميل: «بستوني، مربّع، شمس، دائرة»\nالمحلّل: «اكتب 6 0 3 9»'),
  _Page(Icons.cable, 'LOCK 02', 'صندوق الإنذار', 'العميل يصف الأسلاك وألوانها، والمحلّل يطبّق أوّل قاعدة صحيحة في دليله.',
      'العميل: «4 أسلاك: أحمر، أزرق، أحمر، أصفر»\nالمحلّل: «اقطع السلك رقم 3»'),
  _Page(Icons.mark_email_unread_outlined, 'LOCK 03', 'الرسالة المعترَضة',
      'العميل يصف الرمز ويقرأ الحروف، والمحلّل يضغط على الرمز فتظهر له آلة الفكّ.',
      'العميل: «نفل… الحروف: ز، ض، غ»\nالمحلّل: «ب، ح، ر… الكلمة بحر!»'),
  _Page(Icons.grid_4x4, 'LOCK 04', 'أنفاق التهوية', 'كاميرا العميل معطّلة. المحلّل يرى المخطّط ويوجّهه خطوة بخطوة إلى المخرج.',
      'المحلّل: «فوق… يمين… يمين… تحت»'),
  _Page(Icons.wb_incandescent_outlined, 'LOCK 05', 'جهاز الإشارات', 'العميل يرى مصابيح تومض، والمحلّل يقول له أيّ زرّ يضغط حسب المرحلة.',
      'العميل: «ومض الأحمر»\nالمحلّل: «اضغط الأخضر»'),
  _Page(Icons.settings_backup_restore, 'LOCK 06', 'قرص الخزنة',
      'العميل يصف 3 رموز ويدير القرص بإصبعه. المحلّل يملي رقم كل رمز حسب موضعه (الأول، الثاني، الثالث).',
      'المحلّل: «الرمز الأول نجمة ← 17، ثبّت… الثاني ← 04»'),
  _Page(Icons.cell_tower, 'LOCK 07', 'تردّد الراديو',
      'العميل يصف شكل الموجة ولون المؤشّر. المحلّل يجد التردّد في سجلّه، والعميل يضبطه ويرسل.',
      'العميل: «موجة مربّعة، المؤشّر أزرق»\nالمحلّل: «اضبط 103»'),
  _Page(Icons.table_restaurant_outlined, 'MODE', 'وضع الطاولة',
      'ضعا الهاتف على الطاولة بينكما: النصف العلوي للمحلّل مقلوباً نحوه، والنصف السفلي للعميل. تلعبان معاً بلا تبديل.'),
  _Page(Icons.timer_outlined, 'READY', 'جاهزون للمهمّة؟',
      'أمامكما 10 دقائق لفتح الأقفال الخمسة. كل خطأ −30 ثانية، وكل اصطدام بجدار −10 ثوانٍ.\n\nاحصلوا على 3 نجوم بإنهاء المهمّة بلا أخطاء وفي أقل من 5 دقائق.'),
];

class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
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
      body: SpyBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 18, 0),
              child: Row(children: [
                IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.neon)),
                const Spacer(),
                MonoLabel('TRAINING ${_i + 1}/${_pages.length}'),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctl,
                itemCount: _pages.length,
                onPageChanged: (i) {
                  ref.read(audioProvider).fx(Sfx.click, HapticKind.tap, volume: 0.4);
                  setState(() => _i = i);
                },
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: K.panel,
                            border: Border.all(color: K.neon, width: 2),
                            boxShadow: K.glow(K.neon, 30, 90),
                          ),
                          child: Icon(p.icon, size: 52, color: K.neon),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(child: MonoLabel(p.code, color: K.amber)),
                      const SizedBox(height: 6),
                      Text(p.title,
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      Text(p.body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16.5, height: 1.65)),
                      if (p.example != null) ...[
                        const SizedBox(height: 18),
                        HudPanel(
                          label: 'EXAMPLE // مثال',
                          color: K.amber,
                          child: Text(p.example!, style: const TextStyle(fontSize: 16, height: 1.8)),
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
                  width: i == _i ? 24 : 8,
                  height: 6,
                  decoration: BoxDecoration(color: i == _i ? K.neon : K.line, boxShadow: i == _i ? K.glow(K.neon, 8) : null),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.all(18),
              child: NeonButton(
                label: last ? 'جاهز للمهمّة!' : 'التالي',
                icon: last ? Icons.bolt : Icons.arrow_back,
                onTap: () {
                  if (last) {
                    context.pop();
                  } else {
                    _ctl.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
                  }
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

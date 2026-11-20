import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../widgets/spy_ui.dart';

/// سياسة الخصوصية (مختصرة وواضحة).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = <(String, String)>[
    ('ما نجمعه',
        'البريد الإلكتروني وكلمة السر (مشفّرة، لا نراها)، الاسم الحركي، تاريخ التسجيل وآخر دخول، رصيد الوقت، تقدّمك في المراحل، وطلبات الشراء (رقم العملية وصورة الوصل).'),
    ('لماذا نجمعه', 'لتشغيل حسابك، حفظ تقدّمك، حساب وقت اللعب، ومراجعة طلبات الشراء. لا شيء آخر.'),
    ('الصوت', 'المحادثة الصوتية مباشرة بين اللاعبين عبر خدمة Agora، ولا نسجّلها ولا نحفظها.'),
    ('المشاركة', 'لا نبيع بياناتك ولا نشاركها مع أي جهة إعلانية. لا توجد إعلانات في اللعبة.'),
    ('التخزين', 'البيانات محفوظة على خوادم Supabase، ووصول كل لاعب مقتصر على بياناته فقط.'),
    ('الشراء', 'الدفع يدوي عبر بريدي موب. صورة الوصل يراها المدير فقط للتحقّق، ولا توجد أي جوائز مالية.'),
    ('حذف الحساب', 'يمكنك طلب حذف حسابك وكل بياناتك في أي وقت عبر التواصل مع إدارة اللعبة.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpyBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(18), children: [
            Row(children: [
              IconButton(
                onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
                icon: const Icon(Icons.arrow_forward, color: K.neon),
              ),
              const Spacer(),
              const MonoLabel('PRIVACY // الخصوصية'),
            ]),
            const SizedBox(height: 10),
            for (final (title, body) in _sections) ...[
              HudPanel(
                label: title,
                child: Text(body, style: const TextStyle(fontSize: 15, height: 1.6)),
              ),
              const SizedBox(height: 12),
            ],
          ]),
        ),
      ),
    );
  }
}

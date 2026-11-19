// مهمّات الحملة: كل مهمّة بأقفالها وصعوبتها وموقعها على الخريطة.
import 'package:flutter/material.dart';

class Mission {
  final int id;
  final String name;
  final String story;
  final List<String> rooms;
  final String diff;
  final Offset pos; // موضع نسبي على الخريطة (0..1)
  const Mission(this.id, this.name, this.story, this.rooms, this.diff, this.pos);
}

const List<Mission> kMissions = [
  Mission(1, 'عملية الميناء', 'مستودع في الميناء يخبّئ وثائق مسروقة. مهمّة تدريبية: ثلاثة أقفال فقط.',
      ['keypad', 'wires', 'cipher'], 'recruit', Offset(0.62, 0.88)),
  Mission(2, 'عملية الأرصفة', 'تاجر معلومات يحتفظ بأرشيفه تحت الأرصفة. انتبه للأنفاق.',
      ['keypad', 'wires', 'cipher', 'maze'], 'recruit', Offset(0.30, 0.78)),
  Mission(3, 'عملية الرادار', 'محطّة الرادار المركزية. أوّل خزنة كاملة بخمسة أقفال.',
      ['keypad', 'wires', 'cipher', 'maze', 'lights'], 'recruit', Offset(0.50, 0.70)),
  Mission(4, 'عملية القرص', 'خزنة قديمة بقرص دوّار. المحلّل وحده يعرف الأرقام.',
      ['keypad', 'dial', 'wires', 'maze'], 'agent', Offset(0.76, 0.61)),
  Mission(5, 'عملية الموجة', 'اعتراض بثّ لاسلكي سرّي قبل أن يختفي التردّد.',
      ['cipher', 'radio', 'lights', 'wires'], 'agent', Offset(0.38, 0.53)),
  Mission(6, 'عملية النهر', 'مختبر سرّي على ضفّة النهر. الحراسة مشدّدة والوقت أقصر.',
      ['keypad', 'wires', 'cipher', 'maze', 'lights'], 'agent', Offset(0.62, 0.44)),
  Mission(7, 'عملية الظلّ', 'شبكة الأنفاق أكبر، والأقفال الحديثة كلها هنا.',
      ['dial', 'radio', 'maze', 'lights', 'cipher'], 'elite', Offset(0.40, 0.33)),
  Mission(8, 'عملية البرج', 'برج الاتصالات الأعلى في المدينة. ستة أقفال ونظام إنذار قاسٍ.',
      ['keypad', 'wires', 'dial', 'cipher', 'radio', 'maze'], 'elite', Offset(0.66, 0.24)),
  Mission(9, 'الخزنة الكبرى', 'الهدف الأخير: الخزنة الكبرى بكل أقفالها السبعة. فريق أسطوري فقط.',
      ['keypad', 'wires', 'cipher', 'dial', 'maze', 'radio', 'lights'], 'master', Offset(0.55, 0.12)),
];

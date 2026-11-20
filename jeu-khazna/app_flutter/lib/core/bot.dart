// العميل الآلي «نَسْر»: يلعب دور المحلّل عندما لا يوجد لاعب على الرادار.
// يقرأ الدليل ويعطي التوجيهات نصّاً خطوة بخطوة، بإيقاع بشري (تردّد، تفكير، ثم الجواب).
import 'game.dart';

const String kBotName = 'نَسْر 🤖';

/// مفتاح «الموقف» الحالي: عندما يتغيّر يبدأ الآلي نصّاً جديداً.
String botKey(GameState s) {
  switch (s.roomId) {
    case 'maze':
      return 'maze:${s.room}:${s.mazePos}';
    case 'lights':
      return 'lights:${s.room}:${s.lightStage}';
    case 'dial':
      return 'dial:${s.room}:${s.dialStep}';
    default:
      return '${s.roomId}:${s.room}';
  }
}

String _sym(int i) => '${kSymbols[i].s} ${kSymbols[i].n}';

const Map<String, String> _dirAr = {'up': 'للأعلى ⬆', 'down': 'للأسفل ⬇', 'left': 'لليسار ⬅', 'right': 'لليمين ➡'};

/// أسطر الآلي للموقف الحالي. آخر سطر هو الجواب الكامل.
List<String> botScript(GameState s, Puzzles p) {
  switch (s.roomId) {
    case 'keypad':
      final k = p.keypad;
      return [
        'صِف لي الرموز الأربعة التي على اللوحة… لحظة، أفتح ملفّ اللوحة.',
        'وجدتها في الدليل: ${[for (final i in k.shown) '${_sym(i)} = ${k.manual[i]}'].join('، ')}',
        'اكتب بالترتيب: ${k.answer.split('').join(' ')}',
      ];
    case 'wires':
      final w = p.wires;
      final n = w.wires.length;
      var rule = '';
      for (final r in w.rules[n] ?? const <WireRule>[]) {
        if (r.eval(w.wires) >= 0) {
          rule = r.text;
          break;
        }
      }
      return [
        'كم سلكاً أمامك؟ أعدّها من الأعلى… حسناً، $n أسلاك.',
        'قواعد $n أسلاك في الدليل… القاعدة التي تنطبق: $rule',
        'اقطع السلك رقم ${w.answer + 1} (${kColors[w.wires[w.answer]].n}) — لا تلمس غيره!',
      ];
    case 'cipher':
      final c = p.cipher;
      return [
        'ما الرمز المرسوم بجانب المخطوط؟ سأبحث عن إزاحته…',
        'الرمز ${_sym(c.sym)} يعني: أرجع كل حرف ${c.manual[c.sym]} خطوات في الأبجدية.',
        'فككتُ الكلمة: «${c.answer}» — اكتبها.',
      ];
    case 'maze':
      final step = nextMazeStep(p.maze, s.mazePos ?? p.maze.start);
      if (step == null) return ['أنت عند المخرج تقريباً، تقدّم!'];
      return ['أرى موقعك على الخريطة… تحرّك ${_dirAr[step]}'];
    case 'lights':
      final exp = p.lights.expected(s.lightStage);
      return [
        'راقب الأضواء جيداً في المرحلة ${s.lightStage + 1}…',
        'حسب جدول التحويل اضغط بالترتيب: ${exp.map((i) => kLights[i].n).join(' ← ')}',
      ];
    case 'dial':
      final ans = p.dial.answer;
      final i = s.dialStep.clamp(0, ans.length - 1);
      return [
        'الرمز رقم ${i + 1} في القرص هو ${_sym(p.dial.shown[i])}؟ أبحث في الجدول…',
        'أدِر القرص إلى ${ans[i]}',
      ];
    case 'radio':
      final r = p.radio;
      return [
        'صف لي شكل الموجة ولون المؤشّر على الراديو…',
        '${kWaveNames[r.wave]} مع مؤشّر ${kLights[r.color].n}… أبحث في جدول الترددات.',
        'اضبط التردّد على ${r.answer}',
      ];
  }
  return ['تقدّم، أنا معك.'];
}

/// ردّ الآلي على الرسائل السريعة.
String? botReply(String quick, List<String> script, int shown) {
  switch (quick) {
    case 'repeat':
      return shown > 0 ? script[shown - 1] : 'لم أقل شيئاً بعد، لحظة…';
    case 'code':
    case 'color':
      return script.last;
    case 'wait':
      return 'خذ وقتك، أنا هنا.';
    case 'ok':
      return 'ممتاز! واصل.';
    case 'no':
      return 'لا بأس، لنراجع: ${script.last}';
    case 'hello':
      return 'أهلاً يا بطل! أنا معك حتى النهاية 💪';
    case 'thanks':
      return 'العفو، فريق واحد!';
  }
  return null;
}

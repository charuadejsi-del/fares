// بديل بلا صوت لنسخة Windows (إضافة Agora لا تُبنى حالياً على Windows في GitHub Actions).
// يُنسخ مكان voice.dart في بناء Windows فقط.
import 'package:flutter/foundation.dart';

class VoiceService extends ChangeNotifier {
  bool starting = false;
  bool joined = false;
  bool muted = true;
  bool remoteSpeaking = false;
  bool meSpeaking = false;
  int remoteCount = 0;
  String? error = 'الصوت غير متوفّر في نسخة الحاسوب حالياً';

  Future<void> join(String room) async {}
  Future<void> toggleMute() async {}
  Future<void> leave() async {}
}

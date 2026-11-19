// الكلام الصوتي أثناء اللعب أونلاين (Agora): كل غرفة لعب = قناة صوت.
import 'dart:math';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// رقم تطبيق Agora (وضع الاختبار بلا رموز). يمكن تغييره عند البناء بـ --dart-define=AGORA_APP_ID=...
const String kAgoraAppId = String.fromEnvironment('AGORA_APP_ID', defaultValue: 'a8a28df251784e9595dbb4c8ce4b0042');

class VoiceService extends ChangeNotifier {
  RtcEngine? _engine;
  bool _disposed = false;

  bool starting = false;
  bool joined = false;
  bool muted = false;
  bool remoteSpeaking = false;
  bool meSpeaking = false;
  int remoteCount = 0;
  String? error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> join(String room) async {
    if (_engine != null || starting || kAgoraAppId.isEmpty) return;
    starting = true;
    error = null;
    _notify();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final st = await Permission.microphone.request();
        if (!st.isGranted) {
          error = 'لم يُسمح باستعمال الميكروفون';
          return;
        }
      }
      final e = createAgoraRtcEngine();
      await e.initialize(const RtcEngineContext(
        appId: kAgoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      e.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          joined = true;
          _notify();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          remoteCount++;
          _notify();
        },
        onUserOffline: (connection, remoteUid, reason) {
          remoteCount = max(0, remoteCount - 1);
          _notify();
        },
        onAudioVolumeIndication: (connection, speakers, speakerNumber, totalVolume) {
          bool remote = false, me = false;
          for (final s in speakers) {
            final v = s.volume ?? 0;
            if ((s.uid ?? 0) == 0) {
              me = v > 25 && !muted;
            } else if (v > 25) {
              remote = true;
            }
          }
          if (remote != remoteSpeaking || me != meSpeaking) {
            remoteSpeaking = remote;
            meSpeaking = me;
            _notify();
          }
        },
        onError: (err, msg) {
          error = 'خطأ في الصوت: $msg';
          _notify();
        },
      ));
      await e.enableAudio();
      await e.enableAudioVolumeIndication(interval: 300, smooth: 3, reportVad: false);
      await e.joinChannel(
        token: '',
        channelId: 'khazna-$room',
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        ),
      );
      _engine = e;
      if (_disposed) await leave();
    } catch (e) {
      error = 'تعذّر تشغيل الصوت';
    } finally {
      starting = false;
      _notify();
    }
  }

  Future<void> toggleMute() async {
    muted = !muted;
    if (muted) meSpeaking = false;
    _notify();
    try {
      await _engine?.muteLocalAudioStream(muted);
    } catch (_) {}
  }

  Future<void> leave() async {
    final e = _engine;
    _engine = null;
    joined = false;
    remoteCount = 0;
    if (e == null) return;
    try {
      await e.leaveChannel();
      await e.release();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    leave();
    super.dispose();
  }
}

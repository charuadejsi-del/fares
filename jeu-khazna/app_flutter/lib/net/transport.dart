// الاتصال أونلاين عبر Supabase Realtime (قنوات Broadcast، بلا جداول).
// نفس صيغة الرسائل المستعملة في نسخة الويب، فيمكن للويب والتطبيق اللعب معاً.
import 'dart:async';

import 'package:supabase/supabase.dart';

/// تُمرَّر عند البناء: flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
bool get onlineAvailable => kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;

abstract class Transport {
  Future<void> send(Map<String, dynamic> msg);
  Future<void> close();
}

class SupabaseTransport implements Transport {
  final SupabaseClient _client;
  final RealtimeChannel _channel;
  SupabaseTransport._(this._client, this._channel);

  static Future<SupabaseTransport> connect(String room, void Function(Map<String, dynamic>) onMessage) async {
    final client = SupabaseClient(kSupabaseUrl, kSupabaseAnonKey);
    final channel = client.channel('khazna-$room', opts: RealtimeChannelConfig(self: false));
    channel.onBroadcast(
      event: 'msg',
      callback: (payload) {
        final inner = payload['payload'];
        final msg = inner is Map ? inner : payload;
        onMessage(Map<String, dynamic>.from(msg));
      },
    );
    final ready = Completer<void>();
    channel.subscribe((status, error) {
      if (ready.isCompleted) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        ready.complete();
      } else if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
        ready.completeError(error ?? Exception(status.name));
      }
    });
    await ready.future.timeout(const Duration(seconds: 15));
    return SupabaseTransport._(client, channel);
  }

  @override
  Future<void> send(Map<String, dynamic> msg) async {
    await _channel.sendBroadcastMessage(event: 'msg', payload: msg);
  }

  @override
  Future<void> close() async {
    await _client.removeChannel(_channel);
  }
}

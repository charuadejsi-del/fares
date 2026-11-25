#include "godot_agora_win.h"

#include <IAgoraRtcEngine.h>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;
using namespace agora::rtc;

namespace {
// أحداث Agora تصل من خيط آخر: نمرّرها إلى Godot بـ call_deferred.
class Handler : public IRtcEngineEventHandler {
public:
	GodotAgoraWin *owner;
	int users = 0;
	explicit Handler(GodotAgoraWin *o) : owner(o) {}
	void onJoinChannelSuccess(const char *, agora::rtc::uid_t, int) override {
		owner->call_deferred("notify", "joined", Variant());
	}
	void onUserJoined(agora::rtc::uid_t, int) override {
		users++;
		owner->call_deferred("notify", "users", users);
	}
	void onUserOffline(agora::rtc::uid_t, USER_OFFLINE_REASON_TYPE) override {
		users = users > 0 ? users - 1 : 0;
		owner->call_deferred("notify", "users", users);
	}
	void onAudioVolumeIndication(const AudioVolumeInfo *speakers, unsigned int n, int) override {
		bool me = false, other = false;
		for (unsigned int i = 0; i < n; i++) {
			if (speakers[i].volume > 25) {
				if (speakers[i].uid == 0) me = true; else other = true;
			}
		}
		owner->call_deferred("notify", "speaking", String(me ? "1" : "0") + String(other ? "1" : "0"));
	}
	void onError(int err, const char *) override {
		owner->call_deferred("notify", "voice_error", String("Agora error ") + String::num_int64(err));
	}
};
}

GodotAgoraWin::GodotAgoraWin() {}

GodotAgoraWin::~GodotAgoraWin() { leave(); }

void GodotAgoraWin::_bind_methods() {
	ClassDB::bind_method(D_METHOD("join", "app_id", "token", "channel"), &GodotAgoraWin::join);
	ClassDB::bind_method(D_METHOD("mute", "m"), &GodotAgoraWin::mute);
	ClassDB::bind_method(D_METHOD("leave"), &GodotAgoraWin::leave);
	ClassDB::bind_method(D_METHOD("has_mic"), &GodotAgoraWin::has_mic);
	ClassDB::bind_method(D_METHOD("notify", "sig", "arg"), &GodotAgoraWin::notify);
	ADD_SIGNAL(MethodInfo("joined"));
	ADD_SIGNAL(MethodInfo("users", PropertyInfo(Variant::INT, "n")));
	ADD_SIGNAL(MethodInfo("speaking", PropertyInfo(Variant::STRING, "s")));
	ADD_SIGNAL(MethodInfo("voice_error", PropertyInfo(Variant::STRING, "e")));
}

void GodotAgoraWin::notify(const String &sig, const Variant &arg) {
	if (sig == "joined") emit_signal("joined");
	else emit_signal(sig, arg);
}

bool GodotAgoraWin::has_mic() { return mic; }

void GodotAgoraWin::join(const String &app_id, const String &token, const String &channel) {
	if (engine == nullptr) {
		engine = createAgoraRtcEngine();
		if (engine == nullptr) {
			notify("voice_error", "Agora: تعذّر تشغيل محرّك الصوت");
			return;
		}
		Handler *h = new Handler(this);
		handler = h;
		CharString app = app_id.utf8();
		RtcEngineContext ctx;
		ctx.appId = app.get_data();
		ctx.eventHandler = h;
		ctx.channelProfile = agora::CHANNEL_PROFILE_COMMUNICATION;
		int r = engine->initialize(ctx);
		if (r != 0) {
			notify("voice_error", String("Agora error ") + String::num_int64(r < 0 ? -r : r));
			return;
		}
		engine->enableAudio();
		engine->enableAudioVolumeIndication(300, 3, false);
		// هل يوجد ميكروفون؟ بدونه ندخل كمستمع فقط.
		mic = false;
		agora::util::AutoPtr<IAudioDeviceManager> adm;
		if (adm.queryInterface(engine, AGORA_IID_AUDIO_DEVICE_MANAGER) && adm.get() != nullptr) {
			IAudioDeviceCollection *rec = adm->enumerateRecordingDevices();
			if (rec != nullptr) {
				mic = rec->getCount() > 0;
				rec->release();
			}
		}
	}
	ChannelMediaOptions opts;
	opts.autoSubscribeAudio = true;
	opts.publishMicrophoneTrack = mic;
	opts.clientRoleType = CLIENT_ROLE_BROADCASTER;
	opts.channelProfile = agora::CHANNEL_PROFILE_COMMUNICATION;
	CharString tok = token.utf8();
	CharString ch = channel.utf8();
	int r = engine->joinChannel(token.is_empty() ? nullptr : tok.get_data(), ch.get_data(), 0, opts);
	if (r != 0) {
		notify("voice_error", String("Agora error ") + String::num_int64(r < 0 ? -r : r));
	}
}

void GodotAgoraWin::mute(bool m) {
	if (engine != nullptr) engine->muteLocalAudioStream(m);
}

void GodotAgoraWin::leave() {
	if (engine != nullptr) {
		engine->leaveChannel();
		engine->release();
		engine = nullptr;
	}
	if (handler != nullptr) {
		delete static_cast<Handler *>(handler);
		handler = nullptr;
	}
}

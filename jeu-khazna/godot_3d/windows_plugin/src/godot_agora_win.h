// صوت Agora لنسخة ويندوز: نفس واجهة إضافة أندرويد (GodotAgora) حتى يعمل voice.gd بلا تغيير.
#pragma once
#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/string.hpp>

namespace agora { namespace rtc { class IRtcEngine; } }

namespace godot {

class GodotAgoraWin : public Object {
	GDCLASS(GodotAgoraWin, Object)

public:
	GodotAgoraWin();
	~GodotAgoraWin();
	void join(const String &app_id, const String &token, const String &channel);
	void mute(bool m);
	void leave();
	bool has_mic();
	void notify(const String &sig, const Variant &arg);

protected:
	static void _bind_methods();

private:
	agora::rtc::IRtcEngine *engine = nullptr;
	void *handler = nullptr;
	bool mic = false;
};

}

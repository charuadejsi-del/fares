# الصوت داخل اللعبة (Agora) — نفس مشروع Agora ودالة الرمز «agora-token» في Supabase مثل تطبيق Flutter.
# يعمل على أندرويد عبر إضافة GodotAgora؛ على الحاسوب يبقى معطّلاً بهدوء.
extends Node

signal status(text: String)
signal speaking(me: bool, other: bool)

const APP_ID := "9fd63619ac984e71b3c3eba6215b5a32"
const FN := "https://ubdamgzqqwgcxjvvegwk.supabase.co/functions/v1/agora-token"

var available := false
var joined := false
var muted := false
var _agora: Object
var _channel := ""


func _ready() -> void:
	available = Engine.has_singleton("GodotAgora")
	if available:
		_agora = Engine.get_singleton("GodotAgora")
		_agora.connect("joined", func():
			joined = true
			if _agora.has_method("has_mic") and not _agora.has_mic():
				status.emit("🔈 تستمع فقط (لا يوجد ميكروفون)")
			else:
				status.emit("🎙 الصوت متّصل"))
		_agora.connect("users", func(n):
			var listen: bool = _agora.has_method("has_mic") and not _agora.has_mic()
			if int(n) > 0:
				status.emit("🔈 تستمع إلى الشريك" if listen else "🎙 الصوت متّصل")
			else:
				status.emit("🎙 بانتظار صوت الشريك…"))
		_agora.connect("speaking", func(s):
			var t := str(s)
			speaking.emit(t.substr(0, 1) == "1", t.substr(1, 1) == "1"))
		_agora.connect("voice_error", func(e):
			var m := str(e)
			var n := m.get_slice(" ", 2).to_int() if m.begins_with("Agora error") else -1
			status.emit("🔇 " + (str(ERRORS[n]) + " (" + str(n) + ")" if ERRORS.has(n) else m)))


const MIC := "android.permission.RECORD_AUDIO"
const ERRORS := {101: "معرّف Agora غير صالح", 109: "إذن الصوت انتهت صلاحيته", 110: "إذن الصوت مرفوض من السيرفر", 17: "رُفض الدخول إلى قناة الصوت", 1027: "لا يوجد إذن ميكروفون"}


# نفس الشكل الذي تقبله دالة agora-token: khazna-1234-xxxxxxxx (المفتاح يُحسب من الكود فيتطابق في الهاتفين،
# ولا يختلط بغرف تطبيق الخزنة الأصلي لأن "3d" داخل الحساب).
static func channel_for(code: String) -> String:
	return "khazna-" + code + "-" + ("khazna3d-" + code).md5_text().substr(0, 8)


static func mic_granted() -> bool:
	return OS.get_name() != "Android" or OS.get_granted_permissions().has(MIC)


func start(code: String) -> void:
	if not available or not code.is_valid_int() or code.length() != 4:
		return
	_channel = channel_for(code)
	if not mic_granted():
		status.emit("🎙 اسمح للميكروفون لتشغيل الصوت…")
		OS.request_permission(MIC)
		var t := 0.0
		while not mic_granted() and t < 60.0:
			await get_tree().create_timer(0.5).timeout
			t += 0.5
		if not mic_granted():
			status.emit("🔇 لا يوجد إذن ميكروفون — فعّله من إعدادات الهاتف")
			return
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_token.bind(req))
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + preload("res://net.gd").KEY, "Authorization: Bearer " + preload("res://net.gd").KEY])
	var err := req.request(FN, headers, HTTPClient.METHOD_POST, JSON.stringify({"channel": _channel, "appId": APP_ID}))
	if err != OK:
		status.emit("🔇 تعذّر الاتصال بالسيرفر لطلب إذن الصوت")
		return
	status.emit("🎙 جارٍ تشغيل الصوت…")


func _on_token(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, req: HTTPRequest) -> void:
	req.queue_free()
	var token := ""
	if code == 200:
		var d = JSON.parse_string(body.get_string_from_utf8())
		if typeof(d) == TYPE_DICTIONARY and d.has("token"):
			token = str(d["token"])
	if token == "":
		status.emit("🔇 لم يصل إذن الصوت من السيرفر (رمز %d)" % code)
		return
	_agora.join(APP_ID, token, _channel)


func toggle_mute() -> void:
	if not available:
		return
	muted = not muted
	_agora.mute(muted)


func stop() -> void:
	if available and joined:
		_agora.leave()
	joined = false

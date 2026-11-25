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
			status.emit("🎙 الصوت متّصل"))
		_agora.connect("users", func(n): status.emit("🎙 الصوت متّصل" if int(n) > 0 else "🎙 بانتظار صوت الشريك…"))
		_agora.connect("speaking", func(s):
			var t := str(s)
			speaking.emit(t.substr(0, 1) == "1", t.substr(1, 1) == "1"))
		_agora.connect("voice_error", func(e): status.emit("🔇 " + str(e)))


func start(code: String) -> void:
	if not available or code == "":
		return
	_channel = "khazna3d-" + code
	OS.request_permissions()
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_token.bind(req))
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + preload("res://net.gd").KEY, "Authorization: Bearer " + preload("res://net.gd").KEY])
	var err := req.request(FN, headers, HTTPClient.METHOD_POST, JSON.stringify({"channel": _channel, "appId": APP_ID}))
	if err != OK:
		_agora.join(APP_ID, "", _channel)
	status.emit("🎙 جارٍ تشغيل الصوت…")


func _on_token(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, req: HTTPRequest) -> void:
	req.queue_free()
	var token := ""
	if code == 200:
		var d = JSON.parse_string(body.get_string_from_utf8())
		if typeof(d) == TYPE_DICTIONARY and d.has("token"):
			token = str(d["token"])
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

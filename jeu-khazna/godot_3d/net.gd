# الاتصال أونلاين: قنوات Broadcast في Supabase Realtime (نفس مشروع لعبة الخزنة، بلا جداول).
# بروتوكول Phoenix فوق WebSocket: انضمام، نبض كل 25 ثانية، ورسائل broadcast باسم "msg".
extends Node

signal message(msg: Dictionary)
signal status(text: String)

const HOST := "wss://ubdamgzqqwgcxjvvegwk.supabase.co/realtime/v1/websocket?apikey=%s&vsn=1.0.0"
# المفتاح العام (anon): مصمَّم ليوضع داخل التطبيقات، وهو نفسه في نسخة Flutter.
const KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InViZGFtZ3pxcXdnY3hqdnZlZ3drIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ4ODAzNzksImV4cCI6MjExMDQ1NjM3OX0.eAQ0bOVJ139YKR3VUOa3mQNV5BOeALEYV4zyobD48RI"

var joined := false
var _ws := WebSocketPeer.new()
var _topic := ""
var _ref := 0
var _hb := 0.0
var _open := false
var _retry := 0.0


func open(code: String) -> void:
	_topic = "realtime:khazna3d-" + code
	_connect()


func _connect() -> void:
	_ws = WebSocketPeer.new()
	_ws.connect_to_url(HOST % KEY)
	_open = false
	joined = false
	status.emit("جارٍ الاتصال…")


func _raw(obj: Dictionary) -> void:
	_ws.send_text(JSON.stringify(obj))


func _next() -> String:
	_ref += 1
	return str(_ref)


func send(msg: Dictionary) -> void:
	if not joined:
		return
	_raw({"topic": _topic, "event": "broadcast", "payload": {"type": "broadcast", "event": "msg", "payload": msg}, "ref": _next()})


func _process(delta: float) -> void:
	if _topic == "":
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _open:
			_open = true
			var ref := _next()
			_raw({
				"topic": _topic, "event": "phx_join", "ref": ref, "join_ref": ref,
				"payload": {"config": {"broadcast": {"self": false, "ack": false}, "presence": {"key": ""}, "private": false}},
			})
		_hb += delta
		if _hb > 25.0:
			_hb = 0.0
			_raw({"topic": "phoenix", "event": "heartbeat", "payload": {}, "ref": _next()})
		while _ws.get_available_packet_count() > 0:
			var data = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
			if typeof(data) != TYPE_DICTIONARY:
				continue
			var ev: String = str(data.get("event", ""))
			if ev == "phx_reply" and str(data.get("topic", "")) == _topic and not joined:
				var p = data.get("payload", {})
				if typeof(p) == TYPE_DICTIONARY and str(p.get("status", "")) == "ok":
					joined = true
					status.emit("متّصل")
				else:
					status.emit("تعذّر الانضمام إلى الغرفة")
			elif ev == "broadcast":
				var p2 = data.get("payload", {})
				if typeof(p2) != TYPE_DICTIONARY:
					continue
				var inner = p2.get("payload", p2)
				if typeof(inner) == TYPE_DICTIONARY:
					message.emit(inner)
	elif st == WebSocketPeer.STATE_CLOSED:
		if _open or joined:
			status.emit("انقطع الاتصال… إعادة المحاولة")
		_open = false
		joined = false
		_retry -= delta
		if _retry <= 0.0:
			_retry = 3.0
			_connect()

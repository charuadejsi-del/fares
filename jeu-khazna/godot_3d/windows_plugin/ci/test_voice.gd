# اختبار حقيقي على ويندوز: هل تُحمَّل مكتبة الصوت؟ وهل ندخل قناة Agora بإذن من السيرفر؟
extends SceneTree

var joined := false
var err := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	if not Engine.has_singleton("GodotAgora"):
		print("WINVOICE: singleton missing")
		quit(1)
		return
	print("WINVOICE: singleton ok")
	var a = Engine.get_singleton("GodotAgora")
	a.connect("joined", func(): joined = true)
	a.connect("voice_error", func(e): err = str(e))
	var token := OS.get_environment("KHAZNA_TOKEN")
	a.join("9fd63619ac984e71b3c3eba6215b5a32", token, OS.get_environment("KHAZNA_CH"))
	var t := 0.0
	while not joined and t < 20.0:
		await create_timer(0.5).timeout
		t += 0.5
	print("WINVOICE: mic=", a.has_mic(), " joined=", joined, " err=", err)
	if joined:
		print("WINVOICE: join ok")
	a.leave()
	quit(0)

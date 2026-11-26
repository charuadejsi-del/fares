# قائمة المراحل والتقدّم المحفوظ في الهاتف.
extends RefCounted

const SAVE := "user://progress.cfg"

static var pending := -1 # «المرحلة التالية» بعد الفوز: تبدأ مباشرة بعد إعادة تحميل المشهد

const LIST := [
	{"id": "port", "name": "مخزن الميناء", "sub": "تسلّل، أسقط حارساً وخذ بدلته، والمحلّل يفتح لك باب الخزنة"},
]


static func count() -> int:
	return LIST.size()


static func get_level(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i].id == id:
			return i
	return 0


## أعلى مرحلة مفتوحة (الميناء مفتوح دائماً، والتدريب كذلك).
static func unlocked() -> int:
	var c := ConfigFile.new()
	if c.load(SAVE) != OK:
		return 0
	return clampi(int(c.get_value("progress", "unlocked", 0)), 0, LIST.size() - 1)


static func complete(i: int) -> void:
	var c := ConfigFile.new()
	c.load(SAVE)
	var u := clampi(maxi(int(c.get_value("progress", "unlocked", 0)), i + 1), 0, LIST.size() - 1)
	c.set_value("progress", "unlocked", u)
	c.save(SAVE)


# ───────── إعداد الجودة (عالية / منخفضة) ─────────
const SETTINGS := "user://settings.cfg"


static func low_quality() -> bool:
	var c := ConfigFile.new()
	if c.load(SETTINGS) != OK:
		return false
	return bool(c.get_value("video", "low", false))


static func set_low_quality(v: bool) -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("video", "low", v)
	c.save(SETTINGS)


static func save_best(id: String, stars: int, secs: float) -> void:
	var c := ConfigFile.new()
	c.load(SAVE)
	var bs := int(c.get_value("best", id + "_stars", 0))
	var bt := float(c.get_value("best", id + "_time", 99999.0))
	if stars > bs or (stars == bs and secs < bt):
		c.set_value("best", id + "_stars", stars)
		c.set_value("best", id + "_time", secs)
		c.save(SAVE)


static func best(id: String) -> int:
	var c := ConfigFile.new()
	if c.load(SAVE) != OK:
		return 0
	return int(c.get_value("best", id + "_stars", 0))

# المراحل: كل مرحلة تعيد استعمال هيكل المبنى، لكن لها جوّها الخاص (الضوء، الطقس، الأصوات)،
# وعوائقها (ليزر، كاميرات)، وحرّاسها. التقدّم يُحفظ في الهاتف: نجاح مرحلة يفتح التي بعدها.
extends RefCounted

const SAVE := "user://progress.cfg"

static var pending := -1 # «المرحلة التالية» بعد الفوز: تبدأ مباشرة بعد إعادة تحميل المشهد

# laser: [x، z0، z1، الوضع، ارتفاعات الأشعّة، الطور]
#   sweep = الأشعّة تصعد وتنزل (مرّ في الفراغ) · blink = تنطفئ وتشتعل (مرّ وهي مطفأة) · static = ثابتة (انحنِ تحتها)
# cams: [موضع الكاميرا، الاتجاه بالدرجات (0 = تنظر نحو −z، 180 = نحو +z)، زاوية المسح، مدّة الدورة]
const LIST := [
	{
		"id": "tutorial", "name": "التدريب", "sub": "تعلّم الحركة والانحناء والكاميرات — وحدك",
		"theme": "port", "mission": 900.0, "guard_speed": 0.7, "guard_sight": 0.75, "extra_guard": false, "solo_only": true,
		"lasers": [[5.0, 0.2, 7.8, "static", [1.35, 1.6], 0.0]],
		"cams": [[Vector3(14.0, 2.85, 0.25), 180.0, 45.0, 9.0]],
		"killswitch": false,
	},
	{
		"id": "port", "name": "الميناء", "sub": "مخزن الحاويات — حارسان وكاميرا",
		"theme": "port", "mission": 720.0, "guard_speed": 1.0, "guard_sight": 1.0, "extra_guard": false,
		"lasers": [],
		"cams": [[Vector3(14.0, 2.85, 0.25), 180.0, 55.0, 7.0]],
		"killswitch": false,
	},
	{
		"id": "river", "name": "النهر", "sub": "مستودع غارق تحت المطر — ممرّ ليزر وكاميرتان",
		"theme": "river", "mission": 720.0, "guard_speed": 1.1, "guard_sight": 1.0, "extra_guard": false,
		"lasers": [[15.6, 0.2, 9.8, "sweep", [0.5, 1.2, 1.9], 0.0]],
		"cams": [[Vector3(14.0, 2.85, 0.25), 180.0, 55.0, 7.0], [Vector3(25.0, 2.85, 9.75), 0.0, 50.0, 6.0]],
		"killswitch": true,
	},
	{
		"id": "mountain", "name": "الجبل", "sub": "قاعدة في الثلج — ليزر يومض، ثلاث كاميرات، ثلاثة حرّاس",
		"theme": "mountain", "mission": 660.0, "guard_speed": 1.15, "guard_sight": 1.1, "extra_guard": true,
		"lasers": [[15.6, 0.2, 9.8, "blink", [0.45, 1.0, 1.55], 0.0], [23.0, 0.2, 9.8, "static", [1.38, 1.65], 0.0]],
		"cams": [[Vector3(4.0, 2.85, 7.75), 0.0, 50.0, 8.0], [Vector3(14.0, 2.85, 0.25), 180.0, 55.0, 6.0], [Vector3(25.0, 2.85, 9.75), 0.0, 55.0, 5.0]],
		"killswitch": true,
	},
]


static func count() -> int:
	return LIST.size()


static func get_level(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i].id == id:
			return i
	return 1


## أعلى مرحلة مفتوحة (الميناء مفتوح دائماً، والتدريب كذلك).
static func unlocked() -> int:
	var c := ConfigFile.new()
	if c.load(SAVE) != OK:
		return 1
	return clampi(int(c.get_value("progress", "unlocked", 1)), 1, LIST.size() - 1)


static func complete(i: int) -> void:
	var c := ConfigFile.new()
	c.load(SAVE)
	var u := clampi(maxi(int(c.get_value("progress", "unlocked", 1)), i + 1), 1, LIST.size() - 1)
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

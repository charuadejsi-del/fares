# مرحلة «مخزن الميناء» مرسومة كشبكة (كل خانة 2×2 متر). الصفّ 0 في الأعلى (−Z)، العمود 0 يسار (−X).
#   #  جدار        ,  ساحة خارجية     .  أرضية داخلية    d  مدخل مفتوح
#   R  باب الخزنة (يفتحه المحلّل فقط)   L  خزانة ملابس (لإخفاء الأجسام)
#   B  رصّة صناديق عالية (تحجب الرؤية)  b  براميل      T  طاولة
#   V  الخزنة     C  كاميرا مراقبة     S  نقطة البداية   E  شاحنة الهروب
extends RefCounted

const TILE := 2.0

const MAP := [
	"############################",
	"#,,,,,,,,#L.L.L..#.........#",
	"#,,,,,,,,#.......#..C......#",
	"#,,S,,,,,#.T.....#...V.....#",
	"#,,,,,,,,#.......#.........#",
	"#,,,,,,,,#####.########R####",
	"#,,,,,,,,#...........#.....#",
	"#,,,,,,,,#..BB..BB...#..T..#",
	"#,,,,,,,,d...........#.....#",
	"#,,bb,,,,#..BB..BB...d.....#",
	"#,,,,,,,,#...........#.....#",
	"#,,,,,,,,#..BB..BB...#L....#",
	"#,,,,,,,,#...........#######",
	"#,E,,,,,,d...........#######",
	"############################",
]

const BLOCK := "#BbLTV"

# الغرف: [الاسم، المستطيل بالخانات (عمود، صف، عرض، ارتفاع)، الأرضية]
const ROOMS := [
	["الساحة", Rect2i(1, 1, 8, 13), "yard"],
	["غرفة الاستراحة", Rect2i(10, 1, 7, 4), "wood"],
	["المستودع", Rect2i(10, 6, 11, 8), "hall"],
	["مكتب الأمن", Rect2i(22, 6, 5, 6), "office"],
	["غرفة الخزنة", Rect2i(18, 1, 9, 4), "vault"],
]

# الحرّاس: نقاط الدورية بالخانات، ووقت التوقّف عند كل نقطة.
#   still = واقف في مكانه ينظر في اتّجاه (بالدرجات: 0 = أعلى الشاشة، 90 = يمين، 180 = أسفل، 270 = يسار)
const GUARDS := [
	{"name": "حارس الساحة", "path": [Vector2i(7, 2), Vector2i(7, 12), Vector2i(4, 12), Vector2i(7, 12)], "wait": 2.0, "range": 9.0},
	{"name": "دورية المستودع", "path": [Vector2i(11, 6), Vector2i(20, 6), Vector2i(20, 13), Vector2i(11, 13)], "wait": 1.5, "range": 8.0},
	{"name": "دورية الوسط", "path": [Vector2i(15, 6), Vector2i(15, 13)], "wait": 3.0, "range": 8.0},
	{"name": "الحارس المستريح", "still": Vector2i(13, 2), "look": 0.0, "range": 6.0, "idle": "idle2"},
	{"name": "حارس المكتب", "still": Vector2i(25, 9), "look": 270.0, "range": 8.0, "scan": 35.0},
]

# كاميرا المراقبة: موضعها، الاتجاه الأوسط، زاوية المسح، المدى
const CAMS := [
	{"cell": Vector2i(20, 1), "look": 150.0, "sweep": 35.0, "range": 10.0},
]


static func cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x * TILE + TILE * 0.5, 0.0, c.y * TILE + TILE * 0.5)


static func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / TILE)), int(floor(p.z / TILE)))


static func width() -> int:
	return str(MAP[0]).length()


static func height() -> int:
	return MAP.size()


static func at(c: Vector2i) -> String:
	if c.y < 0 or c.y >= MAP.size() or c.x < 0 or c.x >= width():
		return "#"
	return str(MAP[c.y]).substr(c.x, 1)


static func walkable(c: Vector2i) -> bool:
	return not BLOCK.contains(at(c))


static func find(ch: String) -> Array:
	var out := []
	for r in MAP.size():
		var row := str(MAP[r])
		for c in row.length():
			if row.substr(c, 1) == ch:
				out.append(Vector2i(c, r))
	return out


## اتّجاه بالدرجات (0 = أعلى الشاشة) إلى زاوية دوران حول Y (الأمام = −Z).
static func yaw_of(deg: float) -> float:
	return -deg_to_rad(deg)

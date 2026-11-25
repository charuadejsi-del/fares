# يكتب قسم [dependencies] في ملف .gdextension حسب ملفات dll الموجودة فعلاً في bin/ (تختلف بين نسخ Agora).
import os, sys, re
d = sys.argv[1]
f = os.path.join(d, "godot_agora_win.gdextension")
dlls = sorted(x for x in os.listdir(os.path.join(d, "bin")) if x.lower().endswith(".dll") and x != "godot_agora_win.dll") if os.path.isdir(os.path.join(d, "bin")) else []
entries = ", ".join('"res://addons/godot_agora_win/bin/%s": ""' % x for x in dlls)
s = open(f, encoding="utf-8").read()
s = re.sub(r"\[dependencies\][\s\S]*$", "[dependencies]\nwindows.debug.x86_64 = { %s }\nwindows.release.x86_64 = { %s }\n" % (entries, entries), s)
open(f, "w", encoding="utf-8").write(s)
print("deps:", dlls)

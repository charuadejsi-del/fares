# ينسخ إلى bin/ كل ملف dll تحتاجه الإضافة ومكتبة Agora (حسب dumpbin /dependents) من مجلد SDK.
import os, shutil, subprocess, sys
sdk = sys.argv[1]
have = {f.lower(): os.path.join(sdk, f) for f in os.listdir(sdk) if f.lower().endswith(".dll")}
seen = set()
changed = True
while changed:
    changed = False
    for f in list(os.listdir("bin")):
        if not f.lower().endswith(".dll") or f.lower() in seen:
            continue
        seen.add(f.lower())
        out = subprocess.run(["dumpbin", "/dependents", os.path.join("bin", f)], capture_output=True, text=True).stdout
        deps = [l.strip() for l in out.splitlines() if l.strip().lower().endswith(".dll")]
        print(f, "->", deps)
        for d in deps:
            if d.lower() in have and not os.path.exists(os.path.join("bin", d)):
                shutil.copy(have[d.lower()], os.path.join("bin", d))
                print("  + copied", d)
                changed = True
print("bin:", sorted(os.listdir("bin")))

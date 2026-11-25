"""يحمّل الأصول قبل البناء: الأصوات، وخامات ونماذج Poly Haven بدقّة 1k (CC0).
أيّ ملف يتعذّر تحميله يُتجاوز، واللعبة تعود إلى مواد بديلة."""
import json
import os
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cfg = json.load(open(os.path.join(ROOT, 'tools', 'assets.json'), encoding='utf-8'))
UA = {'User-Agent': 'khazna3d-build/1.0'}


def get(url, dest):
    if os.path.exists(dest):
        return True
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    try:
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=60) as r, open(dest, 'wb') as f:
            f.write(r.read())
        return True
    except Exception as e:  # noqa
        print('تعذّر:', url, e)
        if os.path.exists(dest):
            os.remove(dest)
        return False


def api(path):
    req = urllib.request.Request('https://api.polyhaven.com/' + path, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


ok = fail = 0
for name, url in cfg['sounds'].items():
    if get(url, os.path.join(ROOT, 'sounds', name + '.mp3')):
        ok += 1
    else:
        fail += 1

for tid in cfg['textures']:
    for m in ('diff', 'nor_gl', 'rough'):
        url = f'https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/{tid}/{tid}_{m}_1k.jpg'
        if get(url, os.path.join(ROOT, 'ph', 'tex', f'{tid}_{m}.jpg')):
            ok += 1
        else:
            fail += 1

for mid in cfg['models']:
    try:
        files = api('files/' + mid)
        g = files['gltf']['1k']['gltf']
    except Exception as e:  # noqa
        print('نموذج غير متاح:', mid, e)
        fail += 1
        continue
    base = os.path.join(ROOT, 'ph', 'models', mid)
    good = get(g['url'], os.path.join(base, mid + '.gltf'))
    for rel, inc in (g.get('include') or {}).items():
        good = get(inc['url'], os.path.join(base, rel)) and good
    ok += good
    fail += not good

print(f'الأصول: {ok} نجح، {fail} تعذّر')
sys.exit(0)

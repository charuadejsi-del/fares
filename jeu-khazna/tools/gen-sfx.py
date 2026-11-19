#!/usr/bin/env python3
"""يولّد المؤثّرات الصوتية للعبة «الخزنة» بالحساب (بلا مكتبات خارجية): WAV أحادي 22.05 كيلوهرتز.
الاستعمال: python3 jeu-khazna/tools/gen-sfx.py
"""
import math
import random
import struct
import wave
from pathlib import Path

SR = 22050
OUT = Path(__file__).resolve().parent.parent / 'app_flutter' / 'assets' / 'sfx'
random.seed(7)


def env_exp(t, k):
    return math.exp(-k * t)


def write(name, samples, gain=0.9):
    peak = max(1e-9, max(abs(s) for s in samples))
    data = b''.join(struct.pack('<h', int(max(-1, min(1, s / peak * gain)) * 32767)) for s in samples)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def n(sec):
    return int(SR * sec)


def lowpass(x, a):
    y, prev = [], 0.0
    for v in x:
        prev = prev + a * (v - prev)
        y.append(prev)
    return y


def highpass(x, a):
    y, prev_x, prev_y = [], 0.0, 0.0
    for v in x:
        prev_y = a * (prev_y + v - prev_x)
        prev_x = v
        y.append(prev_y)
    return y


def fade(x, ms=6):
    k = min(len(x) // 2, n(ms / 1000))
    for i in range(k):
        x[i] *= i / k
        x[-1 - i] *= i / k
    return x


# زرّ معدني
click = [(math.sin(2 * math.pi * 2600 * t) * 0.6 + random.uniform(-1, 1) * 0.5) * env_exp(t, 90)
         for t in (i / SR for i in range(n(0.05)))]
write('click.wav', fade(click), 0.7)

# صفّارة لوحة الأرقام
beep = [(math.sin(2 * math.pi * 1250 * t) + 0.25 * math.sin(2 * math.pi * 2500 * t)) * env_exp(t, 18)
        for t in (i / SR for i in range(n(0.09)))]
write('beep.wav', fade(beep), 0.6)

# خطأ: طنين منخفض
err = []
for i in range(n(0.42)):
    t = i / SR
    sq = 1 if math.sin(2 * math.pi * 140 * t) > 0 else -1
    sq2 = 1 if math.sin(2 * math.pi * 147 * t) > 0 else -1
    gate = 1 if (t % 0.14) < 0.11 else 0.15
    err.append((sq + sq2) * 0.5 * gate * env_exp(t, 2.5))
write('error.wav', fade(lowpass(err, 0.35)), 0.75)

# نجاح: نغمات صاعدة
succ = [0.0] * n(0.7)
for k, (f, start) in enumerate([(660, 0.0), (880, 0.09), (1320, 0.18), (1760, 0.27)]):
    for i in range(n(0.4)):
        j = n(start) + i
        if j >= len(succ):
            break
        t = i / SR
        succ[j] += (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 2 * t)) * env_exp(t, 7) * (0.9 - k * 0.1)
write('success.wav', fade(succ), 0.75)

# قطع سلك: شرارات
cut = []
for i in range(n(0.32)):
    t = i / SR
    crackle = random.uniform(-1, 1) if random.random() < 0.35 * env_exp(t, 6) + 0.05 else 0
    cut.append(crackle * env_exp(t, 9) + random.uniform(-0.3, 0.3) * env_exp(t, 30))
write('cut.wav', fade(highpass(cut, 0.85)), 0.8)

# اصطدام: ضربة منخفضة
bump = []
phase = 0.0
for i in range(n(0.28)):
    t = i / SR
    f = 110 * env_exp(t, 9) + 45
    phase += 2 * math.pi * f / SR
    bump.append(math.sin(phase) * env_exp(t, 11) + random.uniform(-0.2, 0.2) * env_exp(t, 40))
write('bump.wav', fade(bump), 0.9)

# مصباح: رنين زجاجي
ding = [(math.sin(2 * math.pi * 1760 * t) + 0.5 * math.sin(2 * math.pi * 2640 * t) + 0.2 * math.sin(2 * math.pi * 120 * t))
        * env_exp(t, 6) for t in (i / SR for i in range(n(0.45)))]
write('light.wav', fade(ding), 0.6)

# إنذار: صفّارة متموّجة (قابلة للتكرار)
alarm = []
phase = 0.0
for i in range(n(1.0)):
    t = i / SR
    f = 750 + 180 * math.sin(2 * math.pi * 1.0 * t)
    phase += 2 * math.pi * f / SR
    alarm.append(math.sin(phase) * 0.8 + 0.2 * math.sin(phase * 2))
write('alarm.wav', fade(alarm, 20), 0.45)

# فتح الخزنة: طقطقات ميكانيكية + هدير + ضربة معدنية
vault = [0.0] * n(2.2)
for c in range(6):
    s0 = n(0.08 + c * 0.11)
    for i in range(n(0.06)):
        t = i / SR
        vault[s0 + i] += (random.uniform(-1, 1) * 0.6 + math.sin(2 * math.pi * 1800 * t) * 0.4) * env_exp(t, 70)
rumble = lowpass([random.uniform(-1, 1) for _ in range(n(1.4))], 0.02)
for i, v in enumerate(rumble):
    t = i / SR
    vault[n(0.75) + i] += v * 6 * min(1, t / 0.3) * env_exp(t, 1.6)
clank_at = n(0.72)
for i in range(n(0.7)):
    t = i / SR
    vault[clank_at + i] += (math.sin(2 * math.pi * 220 * t) + 0.6 * math.sin(2 * math.pi * 331 * t)
                            + 0.4 * math.sin(2 * math.pi * 587 * t)) * env_exp(t, 5) * 0.6
write('vault.wav', fade(vault, 30), 0.9)

# نقرة طباعة على الشاشة
tick = [random.uniform(-1, 1) * env_exp(t, 250) for t in (i / SR for i in range(n(0.025)))]
write('type.wav', fade(highpass(tick, 0.7), 2), 0.35)

print('✓', ', '.join(sorted(p.name for p in OUT.glob('*.wav'))))

#!/usr/bin/env python3
"""8-bit 风格音效生成器。运行: python3 tools/audio/generate.py
只用方波/三角波/噪声 + 简单包络合成，22050Hz 单声道 16bit，和像素画面风格一致。
"""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sfx"))
NOTE = {n: 440.0 * 2 ** ((i - 9) / 12.0) for i, n in enumerate(
    ["C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4",
     "C5", "C#5", "D5", "D#5", "E5", "F5", "F#5", "G5", "G#5", "A5", "A#5", "B5",
     "C6", "C#6", "D6", "D#6", "E6", "F6", "F#6", "G6"])}


def tone(freq, dur, vol=0.5, wave_="square", duty=0.5, slide=0.0, decay=6.0, vibrato=0.0):
    """slide: 频率每秒变化的倍数（>0 上滑，<0 下滑）；decay: 指数衰减速度。"""
    out, phase = [], 0.0
    n = int(RATE * dur)
    for i in range(n):
        t = i / RATE
        f = freq * (2 ** (slide * t)) * (1 + vibrato * math.sin(2 * math.pi * 12 * t))
        phase = (phase + f / RATE) % 1.0
        if wave_ == "square":
            v = 1.0 if phase < duty else -1.0
        elif wave_ == "tri":
            v = 4 * abs(phase - 0.5) - 1
        else:
            v = random.uniform(-1, 1)
        env = math.exp(-decay * t) * min(1.0, i / 40.0) * min(1.0, (n - i) / 60.0)
        out.append(v * vol * env)
    return out


def seq(*parts):
    out = []
    for p in parts:
        out += p
    return out


def mix(a, b, offset=0.0):
    o = int(offset * RATE)
    out = a + [0.0] * max(0, o + len(b) - len(a))
    for i, v in enumerate(b):
        out[o + i] += v
    return out


def silence(d):
    return [0.0] * int(RATE * d)


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 30000)) for s in samples))


def arp(notes, each, **kw):
    return seq(*[tone(NOTE[n], each, **kw) for n in notes])


def build():
    random.seed(1)
    sfx = {
        "click": tone(NOTE["A5"], 0.04, 0.35, decay=40),
        "cast": seq(tone(900, 0.16, 0.18, "noise", slide=-6, decay=10), silence(0.05),
                    tone(NOTE["E5"], 0.07, 0.3, "tri", slide=-8, decay=25)),
        "bite": seq(tone(NOTE["A5"], 0.06, 0.4, duty=0.25, decay=12), silence(0.03),
                    tone(NOTE["A5"], 0.09, 0.4, duty=0.25, decay=12)),
        "reel": seq(*[seq(tone(300 + i * 45, 0.025, 0.25, duty=0.125, decay=30), silence(0.02)) for i in range(9)]),
        "catch": arp(["C5", "E5", "G5"], 0.07, vol=0.4, decay=9),
        "rare": mix(arp(["C5", "E5", "G5", "C6", "E6", "G6"], 0.075, vol=0.4, decay=7, duty=0.25),
                    tone(NOTE["C6"], 0.5, 0.2, "tri", decay=5, vibrato=0.01), 0.42),
        "coin": seq(tone(NOTE["B5"], 0.06, 0.38, decay=8), tone(NOTE["E6"], 0.22, 0.38, decay=9)),
        "buy": seq(tone(NOTE["E5"], 0.06, 0.38, decay=8), tone(NOTE["A5"], 0.06, 0.38, decay=8),
                   tone(NOTE["E6"], 0.2, 0.38, decay=9)),
        "deny": seq(tone(NOTE["D4"], 0.08, 0.35, duty=0.25, decay=6), tone(NOTE["C4"], 0.14, 0.35, duty=0.25, decay=6)),
        "done": mix(seq(arp(["G4", "C5", "E5"], 0.1, vol=0.4, decay=5), tone(NOTE["G5"], 0.2, 0.4, decay=4),
                        tone(NOTE["E5"], 0.1, 0.4, decay=5), tone(NOTE["G5"], 0.5, 0.42, decay=4, vibrato=0.008)),
                    seq(silence(0.3), tone(NOTE["C4"], 0.9, 0.25, "tri", decay=2)), 0.0),
        "break_end": seq(tone(NOTE["E5"], 0.18, 0.35, "tri", decay=5), tone(NOTE["A5"], 0.4, 0.35, "tri", decay=4)),
    }
    for n, s in sfx.items():
        save(n, s)
    print(f"OK: {len(sfx)} 个音效 → assets/sfx/")


if __name__ == "__main__":
    build()

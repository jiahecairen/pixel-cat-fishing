#!/usr/bin/env python3
"""像素素材生成器。运行: python3 tools/art/generate.py
所有素材由代码逐像素绘制，只使用 palette.py 的颜色，统一 1px 深色描边、左上光源。
"""
import math, os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
from palette import PALETTE, rgba

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "sprites")


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def set(self, x, y, k):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = k

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return None

    def rect(self, x0, y0, x1, y1, k):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, k)

    def ellipse(self, cx, cy, rx, ry, k):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.set(x, y, k)

    def pts(self, points, k):
        for x, y in points:
            self.set(x, y, k)

    def rows(self, x, y, lines, cmap=None):
        """ASCII 小图: '.' 透明，其余字符为调色板键（可经 cmap 映射）。"""
        for j, line in enumerate(lines):
            for i, ch in enumerate(line):
                if ch != ".":
                    self.set(x + i, y + j, (cmap or {}).get(ch, ch))

    def outline(self, k="K"):
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is None:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        n = self.get(x + dx, y + dy)
                        if n is not None and n != k:
                            add.append((x, y))
                            break
        self.pts(add, k)

    def blit(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                if other.px[y][x] is not None:
                    self.set(ox + x, oy + y, other.px[y][x])

    def image(self):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is not None:
                    im.putpixel((x, y), rgba(self.px[y][x]))
        return im


def sheet(frames):
    w = sum(f.w for f in frames)
    c = Canvas(w, max(f.h for f in frames))
    x = 0
    for f in frames:
        c.blit(f, x, 0)
        x += f.w
    return c


def save(c, name):
    os.makedirs(OUT, exist_ok=True)
    c.image().save(os.path.join(OUT, name + ".png"))
    return c


# ---------------------------------------------------------------- 猫
# 毛色用 f/F/l 三个槽位；未来定制形象 = 换这三个槽 + 换帽子图层。
def cat(tail_up=False, eyes_closed=False, breathe=0, hat=True):
    c = Canvas(32, 32)
    by = breathe
    # 尾巴
    tail = [(6, 27), (5, 26), (4, 25), (3, 24), (3, 23)]
    tail += [(3, 22), (4, 21)] if tail_up else [(2, 23), (2, 22)]
    for x, y in tail:
        c.rect(x, y, x + 1, y, "F")
    # 身体
    c.ellipse(13, 23 + by, 7, 7 - by, "f")
    c.ellipse(10, 25, 4, 4, "F")          # 背侧暗部
    c.ellipse(13, 23 + by, 5, 5 - by, "f")
    c.ellipse(16.5, 25, 2.6, 3.6, "w")    # 肚皮
    # 头
    c.ellipse(18, 14 + by, 7.2, 6, "f")
    c.rows(12, 7 + by, ["f....", "ff...", "fpf..", "fpff."])     # 左耳
    c.rows(20, 7 + by, ["...f.", "..ff.", ".fpf.", "ffpf."])     # 右耳
    c.ellipse(15, 12 + by, 3, 2, "l")     # 额头高光
    c.ellipse(22, 16.5 + by, 3.2, 2.2, "w")  # 嘴套
    c.set(25, 15 + by, "p")               # 鼻
    c.pts([(12, 17 + by), (13, 18 + by), (12, 15 + by)], "F")  # 脸侧花纹
    if eyes_closed:
        c.pts([(20, 14 + by), (21, 14 + by), (22, 14 + by)], "K")
    else:
        c.rect(20, 13 + by, 21, 14 + by, "K")
        c.set(20, 13 + by, "W")
    # 前爪
    c.rect(19, 22, 21, 23, "w")
    c.set(18, 22, "f")
    if hat:
        c.rect(13, 5 + by, 23, 7 + by, "h")
        c.rect(14, 4 + by, 22, 4 + by, "h")
        c.rect(13, 7 + by, 23, 7 + by, "r")
        c.rect(9, 8 + by, 27, 8 + by, "h")
        c.rect(10, 9 + by, 26, 9 + by, "H")
        c.pts([(15, 5 + by), (16, 5 + by), (17, 4 + by)], "w")
    c.outline()
    return c


def cat_sheet():
    return sheet([
        cat(),                                   # 0 坐-A
        cat(tail_up=True),                       # 1 坐-B（摆尾）
        cat(eyes_closed=True),                   # 2 打盹-A
        cat(eyes_closed=True, breathe=1),        # 3 打盹-B（呼吸）
    ])


# ---------------------------------------------------------------- 船
def boat():
    c = Canvas(64, 22)
    for i, y in enumerate(range(3, 19)):
        inset = int(round((i / 15.0) ** 1.6 * 9))
        k = "o"
        if y <= 4:
            k = "n"
        elif y >= 14:
            k = "O"
        c.rect(1 + inset, y, 62 - inset, y, k)
    c.rect(2, 9, 61, 9, "O")                     # 板缝
    c.rect(4, 5, 30, 5, "n")
    for x in (14, 31, 48):                       # 铆钉
        c.set(x, 7, "O"); c.set(x, 12, "O")
    c.rows(53, 0, ["oo", "oo", "oo"])            # 船头小桩
    c.outline()
    return c


# ---------------------------------------------------------------- 水面
def water(phase):
    w, h = 124, 22
    c = Canvas(w, h)
    for y in range(h):
        t = y / (h - 1)
        inset = int(round((1 - math.sin(math.pi * min(1, (y + 1) / 5.0) / 2)) * 6)) if y < 5 else 0
        if y > h - 6:
            inset = int(round(((y - (h - 6)) / 5.0) ** 2 * 10))
        k = "b" if t < 0.6 else "B"
        c.rect(inset, y, w - 1 - inset, y, k)
    c.rect(8, 0, w - 9, 0, "c")
    for row, (y, step) in enumerate(((3, 22), (8, 26), (13, 30))):
        for i in range(-1, 6):
            x = i * step + (row * 9 + phase * 5) % step
            if c.get(x + 6, y) is not None and c.get(x, y) is not None:
                c.rect(x, y, x + 5 - row, y, "c" if row < 2 else "b")
                c.set(x + 1, y - 1, "W") if row == 0 else None
    return c


# ---------------------------------------------------------------- 鱼
def fish(body, dark, belly, fin, spots=False):
    c = Canvas(18, 12)
    c.ellipse(9.5, 6, 5.6, 3.4, body)
    c.ellipse(9.5, 4.2, 4.2, 1.2, dark)          # 背
    c.ellipse(10, 7.8, 3.6, 1.0, belly)          # 腹
    c.rows(1, 3, ["f..", "ff.", "fff", "fff", "ff.", "f.."], {"f": fin})  # 尾
    c.rows(8, 1, ["ff", "fff"], {"f": fin})      # 背鳍
    c.set(13, 5, "K"); c.set(13, 4, "W")
    if spots:
        c.pts([(7, 5), (9, 6), (6, 7), (10, 4)], "w")
    c.outline()
    return c


# ---------------------------------------------------------------- 小图标
def tomato():
    c = Canvas(11, 11)
    c.ellipse(5, 6, 3.6, 3.2, "r")
    c.ellipse(6, 7.4, 2.4, 1.6, "R")
    c.ellipse(5, 6, 3.0, 2.4, "r")
    c.set(3, 5, "W")
    c.rows(3, 2, [".g.g.", "ggggg", ".g.g."])
    c.set(5, 1, "G")
    c.outline()
    return c


def coin():
    c = Canvas(9, 9)
    c.ellipse(4, 4, 3, 3, "y")
    c.rows(2, 2, ["...", "..H", ".HH"])
    c.pts([(4, 3), (4, 4), (4, 5)], "H")
    c.set(3, 2, "W")
    c.outline()
    return c


def basket():
    c = Canvas(11, 10)
    c.rows(1, 3, ["hhhhhhhhh", "HhHhHhHhH", "hHhHhHhHh", ".hHhHhHh.", ".hhhhhhh."])
    c.rows(3, 1, ["HHHHH", "H...H"])
    c.outline()
    return c


def bobber():
    c = Canvas(5, 8)
    c.rows(1, 1, ["rrr", "rrr", "www", "www"])
    c.set(2, 0, "K"); c.set(2, 5, "K")
    c.outline()
    return c


def bang():
    c = Canvas(7, 11)
    c.rows(2, 1, ["yyy", "yyy", "yyy", "yyy", ".y.", "...", ".y.", ".y."][:8])
    c.rows(2, 7, ["yyy", "yyy"])
    c.outline()
    return c


def zzz():
    c = Canvas(11, 10)
    c.rows(1, 5, ["WWWW", "..W.", ".W..", "WWWW"])
    c.rows(7, 1, ["WW.", ".W.", ".WW"])
    c.outline()
    return c


BTN = {
    "play": ["..g....", "..gg...", "..ggg..", "..gggg.", "..ggg..", "..gg...", "..g...."],
    "stop": [".......", ".rrrrr.", ".rrrrr.", ".rrrrr.", ".rrrrr.", ".rrrrr.", "......."],
    "sell": ["..yyy..", ".yyHyy.", ".yHyyy.", ".yyHyy.", ".yyyHy.", ".yyHyy.", "..yyy.."],
    "skip": [".......", "c..c.c.", "cc.ccc.", "cccccc.", "cc.ccc.", "c..c.c.", "......."],
    "close": [".......", ".a...a.", "..a.a..", "...a...", "..a.a..", ".a...a.", "......."],
}


def button(name, pressed=False):
    c = Canvas(11, 11)
    c.rect(1, 1, 9, 9, "A")
    c.rect(1, 1, 9, 1, "a") if not pressed else None
    c.rect(1, 9, 9, 9, "K")
    c.rows(2, 2, BTN[name])
    c.outline()
    return c


FONT = {
    "0": ["www", "w.w", "w.w", "w.w", "www"], "1": [".w.", "ww.", ".w.", ".w.", "www"],
    "2": ["www", "..w", "www", "w..", "www"], "3": ["www", "..w", "www", "..w", "www"],
    "4": ["w.w", "w.w", "www", "..w", "..w"], "5": ["www", "w..", "www", "..w", "www"],
    "6": ["www", "w..", "www", "w.w", "www"], "7": ["www", "..w", "..w", ".w.", ".w."],
    "8": ["www", "w.w", "www", "w.w", "www"], "9": ["www", "w.w", "www", "..w", "www"],
    ":": ["...", ".w.", "...", ".w.", "..."], "/": ["..w", "..w", ".w.", "w..", "w.."],
    "+": ["...", ".w.", "www", ".w.", "..."], "x": ["...", "w.w", ".w.", "w.w", "..."],
    "-": ["...", "...", "www", "...", "..."],
}
FONT_ORDER = "0123456789:/+x-"


def font():
    c = Canvas(4 * len(FONT_ORDER), 5)
    for i, ch in enumerate(FONT_ORDER):
        c.rows(i * 4, 0, FONT[ch])
    return c


def dots():
    """番茄进度点：0=未完成 1=已完成"""
    a = Canvas(5, 5); a.rect(1, 1, 3, 3, "A"); a.outline()
    b = Canvas(5, 5); b.rect(1, 1, 3, 3, "r"); b.set(1, 1, "p"); b.outline()
    return sheet([a, b])


def panel():
    c = Canvas(98, 27)
    c.rect(1, 1, 96, 25, "K")
    c.rect(2, 2, 95, 2, "A")
    for x, y in ((1, 1), (96, 1), (1, 25), (96, 25)):
        c.px[y][x] = None
    return c


def build():
    made = {
        "cat": save(cat_sheet(), "cat"),
        "boat": save(boat(), "boat"),
        "water": save(sheet([water(0), water(1), water(2)]), "water"),
        "fish_crucian": save(fish("s", "S", "w", "S"), "fish_crucian"),
        "fish_bass": save(fish("b", "B", "W", "B"), "fish_bass"),
        "fish_koi": save(fish("y", "f", "w", "r", spots=True), "fish_koi"),
        "tomato": save(tomato(), "tomato"),
        "coin": save(coin(), "coin"),
        "basket": save(basket(), "basket"),
        "bobber": save(bobber(), "bobber"),
        "bang": save(bang(), "bang"),
        "zzz": save(zzz(), "zzz"),
        "font": save(font(), "font"),
        "dots": save(dots(), "dots"),
        "panel": save(panel(), "panel"),
    }
    for n in BTN:
        made["btn_" + n] = save(sheet([button(n), button(n, True)]), "btn_" + n)
    return made


def preview(made):
    """合成一张 4 倍放大的场景预览，仅用于人工目检（不进版本库）。"""
    s = Canvas(128, 96)
    s.blit(made["panel"], 15, 1)
    s.blit(made["tomato"], 19, 3)
    for i, ch in enumerate("24:59"):
        s.rows(32 + i * 4, 6, FONT[ch])
    d = dots()
    for i in range(4):
        for y in range(5):
            for x in range(5):
                v = d.px[y][x + (5 if i < 2 else 0)]
                if v: s.set(55 + i * 6 + x, 6 + y, v)
    for i, n in enumerate(("play", "sell", "close")):
        b = button(n)
        s.blit(b, 78 + i * 11, 3)
    s.blit(made["coin"], 20, 15); s.blit(made["basket"], 56, 14)
    for i, ch in enumerate("128"): s.rows(31 + i * 4, 17, FONT[ch])
    for i, ch in enumerate("3/10"): s.rows(69 + i * 4, 17, FONT[ch])
    w0 = water(0); s.blit(w0, 2, 73)
    s.blit(cat(), 44, 39)
    s.blit(made["boat"], 34, 62)
    s.blit(made["bobber"], 110, 70)
    s.blit(made["bang"], 70, 30)
    for i, n in enumerate(("fish_crucian", "fish_bass", "fish_koi")):
        s.blit(made[n], 4 + i * 0, 30 + i * 13)
    s.blit(zzz(), 82, 34)
    im = Image.new("RGBA", (128, 96), (96, 110, 130, 255))
    im.alpha_composite(s.image())
    im = im.resize((128 * 5, 96 * 5), Image.NEAREST)
    im.save(os.path.join(os.path.dirname(__file__), "preview.png"))


def export_palette():
    """把调色板导出给 Godot，保证代码绘制的线条/文字与素材同色。"""
    lines = ["# 由 tools/art/generate.py 自动生成，请勿手改。", "extends RefCounted", ""]
    for k, v in PALETTE.items():
        name = ("U_" if k.isupper() else "L_") + k.upper()
        lines.append(f'const {name} := Color("{v}")')
    open(os.path.join(ROOT, "presentation", "palette.gd"), "w").write("\n".join(lines) + "\n")


def check(made):
    allowed = {rgba(k) for k in PALETTE}
    for n in os.listdir(OUT):
        if n.endswith(".png"):
            im = Image.open(os.path.join(OUT, n)).convert("RGBA")
            for p in {im.getpixel((x, y)) for x in range(im.width) for y in range(im.height)}:
                assert p[3] == 0 or p in allowed, f"{n}: 非调色板颜色 {p}"
    print(f"OK: {len(made)} 张素材，全部只用调色板 {len(PALETTE)} 色")


if __name__ == "__main__":
    m = build()
    preview(m)
    export_palette()
    check(m)

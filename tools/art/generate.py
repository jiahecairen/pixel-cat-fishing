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
# 猫用"槽位"作画，运行时再上色，这样玩家可以自定义形象：
#   f / F / l  毛色 基础 / 暗部 / 亮部
#   1          花纹-白色区（肚皮、嘴套、爪子）：有白肚时画奶白，否则画毛色亮部
#   2          花纹-条纹区：有条纹时画毛色暗部，否则画毛色基础
# 帽子单独成层，盖在最上面。
FUR_SLOTS = {"f": "fur_base", "F": "fur_shade", "l": "fur_light", "1": "pat_white", "2": "pat_stripe"}
HATS = ["straw", "bucket", "beret"]
STRIPES = [(8, 19), (8, 20), (8, 21), (11, 17), (11, 18), (11, 19), (14, 17), (14, 18)]
HEAD_STRIPES = [(16, 9), (16, 10), (18, 8), (18, 9), (18, 10), (20, 9), (20, 10)]


def draw_hat(c, hat, by, dx=0):
    if hat == "straw":
        c.rect(13 + dx, 5 + by, 23 + dx, 7 + by, "h")
        c.rect(14 + dx, 4 + by, 22 + dx, 4 + by, "h")
        c.rect(13 + dx, 7 + by, 23 + dx, 7 + by, "r")
        c.rect(9 + dx, 8 + by, 27 + dx, 8 + by, "h")
        c.rect(10 + dx, 9 + by, 26 + dx, 9 + by, "H")
        c.pts([(15 + dx, 5 + by), (16 + dx, 5 + by), (17 + dx, 4 + by)], "w")
    elif hat == "bucket":
        c.rect(14 + dx, 3 + by, 22 + dx, 3 + by, "g")
        c.rect(13 + dx, 4 + by, 23 + dx, 6 + by, "g")
        c.rect(13 + dx, 7 + by, 23 + dx, 7 + by, "G")
        c.rect(11 + dx, 8 + by, 25 + dx, 8 + by, "g")
        c.rect(10 + dx, 9 + by, 26 + dx, 9 + by, "G")
        c.pts([(15 + dx, 4 + by), (16 + dx, 4 + by)], "W")
    elif hat == "beret":
        c.ellipse(17 + dx, 6 + by, 6.2, 2.6, "r")
        c.rect(12 + dx, 8 + by, 22 + dx, 8 + by, "R")
        c.pts([(17 + dx, 3 + by), (17 + dx, 2 + by)], "R")
        c.pts([(14 + dx, 5 + by), (15 + dx, 4 + by)], "p")


def cat_raw(tail_up=False, eyes_closed=False, breathe=0, hat=None, pose="sit", step=0):
    c = Canvas(32, 32)
    by = breathe
    if pose == "walk":
        # 两条腿直立行走：头的位置和坐姿一样（帽子不用另画），身体在头的正下方。
        # step 0/1 两帧：手脚前后交替，身体上下颠 1 像素。
        by = step
        tail = [(10, 25), (9, 24), (8, 23), (8, 22)] + ([(8, 21), (9, 20)] if step == 0 else [(7, 21), (7, 20)])
        for x, y in tail:
            c.rect(x, y, x + 1, y, "F")
        far_leg, near_leg = (19, 14) if step == 0 else (14, 19)      # 远侧腿（暗）、近侧腿
        c.rect(far_leg, 26, far_leg + 1, 28, "F"); c.rect(far_leg, 29, far_leg + 2, 29, "F")
        far_arm = 14 if step == 0 else 20                             # 远侧手臂，和近侧腿同方向摆
        c.rect(far_arm, 21 + by, far_arm + 1, 24 + by, "F")
        c.ellipse(16.5, 23 + by, 4.6, 4.4 - by * 0.4, "f")            # 躯干
        c.rect(12, 21 + by, 13, 25 + by, "F")                         # 背侧暗部
        c.ellipse(17.6, 23.6 + by, 2.4, 3.0, "1")                     # 肚皮
        c.rect(near_leg, 26, near_leg + 1, 28, "f"); c.rect(near_leg, 29, near_leg + 2, 29, "1")
        near_arm = 20 if step == 0 else 15                            # 近侧手臂
        c.rect(near_arm, 21 + by, near_arm + 1, 24 + by, "f"); c.rect(near_arm, 25 + by, near_arm + 1, 25 + by, "1")
    else:
        tail = [(6, 27), (5, 26), (4, 25), (3, 24), (3, 23)]
        tail += [(3, 22), (4, 21)] if tail_up else [(2, 23), (2, 22)]
        for x, y in tail:
            c.rect(x, y, x + 1, y, "F")
        c.ellipse(13, 23 + by, 7, 7 - by, "f")
        c.ellipse(10, 25, 4, 4, "F")          # 背侧暗部
        c.ellipse(13, 23 + by, 5, 5 - by, "f")
        c.ellipse(16.5, 25, 2.6, 3.6, "1")    # 肚皮
    c.ellipse(18, 14 + by, 7.2, 6, "f")   # 头
    c.rows(12, 7 + by, ["f....", "ff...", "fpf..", "fpff."])     # 左耳
    c.rows(20, 7 + by, ["...f.", "..ff.", ".fpf.", "ffpf."])     # 右耳
    c.ellipse(15, 12 + by, 3, 2, "l")     # 额头高光
    c.ellipse(22, 16.5 + by, 3.2, 2.2, "1")  # 嘴套
    c.set(25, 15 + by, "p")               # 鼻
    c.pts([(12, 17 + by), (13, 18 + by), (12, 15 + by)], "F")  # 脸侧花纹
    body_stripes = [(14, 21 + by), (14, 22 + by), (15, 25 + by), (16, 26 + by)] if pose == "walk" else STRIPES
    for x, y in body_stripes + [(x, y + by) for x, y in HEAD_STRIPES]:
        if c.get(x, y) == "f":
            c.set(x, y, "2")
    if eyes_closed:
        c.pts([(20, 14 + by), (21, 14 + by), (22, 14 + by)], "K")
    else:
        c.rect(20, 13 + by, 21, 14 + by, "K")
        c.set(20, 13 + by, "W")
    if pose != "walk":
        c.rect(19, 22, 21, 23, "1")           # 前爪
        c.set(18, 22, "f")
    if hat:
        draw_hat(c, hat, by)
    c.outline()
    return c


CAT_FRAMES = [dict(), dict(tail_up=True), dict(eyes_closed=True), dict(eyes_closed=True, breathe=1),
              dict(pose="walk", step=0), dict(pose="walk", step=1)]
# 帧含义: 0 坐-A  1 坐-B（摆尾）  2 打盹-A / 眯眼  3 打盹-B（呼吸）  4 走路-A  5 走路-B


def colorize(c, look):
    """把槽位换成真实调色板键。look = (base, shade, light, white?, stripes?)"""
    base, shade, light, white, stripes = look
    m = {"f": base, "F": shade, "l": light, "1": "w" if white else light, "2": shade if stripes else base}
    out = Canvas(c.w, c.h)
    for y in range(c.h):
        for x in range(c.w):
            k = c.px[y][x]
            out.px[y][x] = m.get(k, k)
    return out


DEFAULT_LOOK = ("f", "F", "l", True, False)


def cat(hat="straw", look=DEFAULT_LOOK, **kw):
    return colorize(cat_raw(hat=hat, **kw), look)


def cat_sheet(hat="straw", look=DEFAULT_LOOK):
    return sheet([cat(hat=hat, look=look, **f) for f in CAT_FRAMES])


def cat_layers():
    """导出运行时用的分层图：每个槽位一张白色蒙版（运行时乘上毛色），
    一张固定层（描边、眼睛、鼻子、耳朵粉色），每顶帽子一张覆盖层。"""
    out_dir = os.path.join(ROOT, "assets", "cat")
    os.makedirs(out_dir, exist_ok=True)
    bare = [cat_raw(**f) for f in CAT_FRAMES]

    def write(name, canvases, as_mask):
        im = Image.new("RGBA", (32 * len(canvases), 32), (0, 0, 0, 0))
        for i, c in enumerate(canvases):
            for y in range(32):
                for x in range(32):
                    k = c.px[y][x]
                    if k is not None:
                        im.putpixel((i * 32 + x, y), (255, 255, 255, 255) if as_mask else rgba(k))
        im.save(os.path.join(out_dir, name + ".png"))

    def only(c, pred):
        o = Canvas(32, 32)
        for y in range(32):
            for x in range(32):
                if c.px[y][x] is not None and pred(c.px[y][x]):
                    o.px[y][x] = c.px[y][x]
        return o

    for slot, name in FUR_SLOTS.items():
        write(name, [only(c, lambda k, s=slot: k == s) for c in bare], True)
    write("fixed", [only(c, lambda k: k not in FUR_SLOTS) for c in bare], False)
    for hat in HATS:
        overlays = []
        for f, b in zip(CAT_FRAMES, bare):
            h = cat_raw(hat=hat, **f)
            o = Canvas(32, 32)
            for y in range(32):
                for x in range(32):
                    if h.px[y][x] != b.px[y][x]:
                        assert h.px[y][x] is not None and h.px[y][x] not in FUR_SLOTS, "帽子层只能新增像素"
                        o.px[y][x] = h.px[y][x]
            overlays.append(o)
        write("hat_" + hat, overlays, False)


def cat_gallery():
    """所有毛色 × 花纹 × 帽子的目检图（不进版本库）。"""
    import json
    cfg = json.load(open(os.path.join(ROOT, "data", "cat.json"), encoding="utf-8"))
    for f in cfg["furs"]:
        for k in ("base", "shade", "light"):
            assert f[k] in PALETTE, f"cat.json 毛色用了调色板以外的键: {f}"
    hats = [None] + HATS
    assert len(cfg["hats"]) == len(hats), "cat.json 的帽子数量与生成器不一致"
    cols = len(cfg["patterns"]) * len(hats)
    g = Canvas(34 * cols, 34 * len(cfg["furs"]))
    for r, f in enumerate(cfg["furs"]):
        for pi, p in enumerate(cfg["patterns"]):
            for hi, h in enumerate(hats):
                look = (f["base"], f["shade"], f["light"], p["white"], p["stripes"])
                g.blit(cat(hat=h, look=look), (pi * len(hats) + hi) * 34 + 1, r * 34 + 1)
    im = Image.new("RGBA", (g.w, g.h), (143, 208, 240, 255))
    im.alpha_composite(g.image())
    im.resize((g.w * 3, g.h * 3), Image.NEAREST).save(os.path.join(os.path.dirname(__file__), "preview_cats.png"))


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


# ---------------------------------------------------------------- 横版世界
# 背景类素材（海、地面、云、山）不描边；物件（房子、摊位、码头、路人）描边。
def sea(phase):
    """海面瓦片 32×6，可横向平铺；下面的深水由代码填色。"""
    c = Canvas(32, 6)
    c.rect(0, 0, 31, 5, "b")
    c.rect(0, 0, 31, 0, "c")
    for x0 in (3 + phase * 5, 19 + phase * 5):
        c.rect(x0 % 32, 0, (x0 % 32), 0, "W")
        for i in range(5):
            c.set((x0 + 6 + i) % 32, 3, "c")
    for i in range(4):
        c.set((11 + phase * 3 + i) % 32, 5, "B")
    return c


def ground():
    """小镇地面瓦片 32×16：草皮 + 泥土。"""
    c = Canvas(32, 16)
    c.rect(0, 0, 31, 2, "g")
    c.rect(0, 3, 31, 15, "n")
    for x in (2, 9, 15, 22, 28):
        c.set(x, 0, "G"); c.set(x + 1, 3, "g")
    for x, y in ((4, 6), (13, 9), (20, 5), (27, 11), (8, 13), (30, 7), (17, 12)):
        c.set(x, y, "o")
    return c


def pier():
    c = Canvas(64, 28)
    c.rect(0, 0, 63, 1, "n")
    c.rect(0, 2, 63, 3, "o")
    for x in range(7, 64, 8):
        c.set(x, 0, "o"); c.set(x, 1, "o")
    for x in (5, 30, 55):
        c.rect(x, 4, x + 2, 27, "O")
        c.rect(x, 4, x, 27, "o")
    c.outline()
    return c


def house(wall, wall_dark, roof, roof_dark, w=46, door_x=18):
    c = Canvas(w + 4, 60)
    for i in range(18):                           # 屋顶
        inset = max(0, 14 - i)
        c.rect(1 + inset, 6 + i, w + 2 - inset, 6 + i, roof if i < 14 else roof_dark)
    c.rect(w - 9, 2, w - 5, 12, "A"); c.rect(w - 10, 1, w - 4, 2, "a")   # 烟囱
    for i in range(2, 14, 4):
        c.rect(6 + max(0, 14 - i), 6 + i, w - 3 - max(0, 14 - i), 6 + i, roof_dark)
    c.rect(3, 24, w, 59, wall)
    c.rect(3, 24, w, 25, wall_dark)
    c.rect(3, 56, w, 59, wall_dark)
    c.rect(door_x, 42, door_x + 9, 59, "o"); c.rect(door_x, 42, door_x + 9, 43, "O"); c.set(door_x + 7, 51, "y")
    for wx in (6, w - 13):
        if abs(wx - door_x) > 8:
            c.rect(wx, 31, wx + 8, 39, "c"); c.rect(wx, 31, wx + 8, 31, "O"); c.rect(wx + 4, 31, wx + 4, 39, "O")
            c.rect(wx, 35, wx + 8, 35, "O"); c.set(wx + 1, 32, "W"); c.set(wx + 2, 33, "W")
    c.outline()
    return c


def tree():
    c = Canvas(24, 36)
    c.rect(10, 22, 13, 35, "o"); c.rect(10, 22, 10, 35, "O")
    c.ellipse(11.5, 13, 9.5, 10, "G")
    c.ellipse(10, 11, 7.5, 7.5, "g")
    c.pts([(6, 8), (7, 7), (9, 6), (13, 9), (5, 12)], "h")
    c.outline()
    return c


def stall_back():
    """摊位后半：立柱 + 红白条纹雨棚。猫坐在它和柜台之间。"""
    c = Canvas(46, 40)
    c.rect(3, 8, 4, 39, "o"); c.rect(41, 8, 42, 39, "o")
    for x in range(1, 45):
        k = "r" if ((x - 1) // 4) % 2 == 0 else "w"
        c.rect(x, 1, x, 8, k)
        if ((x - 1) % 4) in (1, 2):
            c.set(x, 9, k)
    c.rect(1, 1, 44, 1, "R")
    c.outline()
    return c


def stall_front():
    """摊位前半：柜台。"""
    c = Canvas(46, 15)
    c.rect(1, 1, 44, 2, "n")
    c.rect(2, 3, 43, 14, "o")
    c.rect(2, 3, 43, 3, "O")
    for x in (12, 23, 34):
        c.rect(x, 4, x, 14, "O")
    c.outline()
    return c


def villager(kind, step):
    """路人顾客，面朝左。kind: 0 兔子 1 小熊 2 狐狸"""
    body, dark, ear = [("W", "a", "p"), ("o", "O", "n"), ("f", "F", "w")][kind]
    cloth = ["b", "g", "r"][kind]
    c = Canvas(16, 22)
    if kind == 0:
        c.rect(6, 1, 7, 6, body); c.rect(10, 1, 11, 6, body); c.set(6, 3, ear); c.set(10, 3, ear)
    elif kind == 1:
        c.rect(4, 4, 6, 6, body); c.rect(10, 4, 12, 6, body)
    else:
        c.rows(4, 3, ["f..", "ff.", "fff"], {"f": body}); c.rows(10, 3, ["..f", ".ff", "fff"], {"f": body})
    c.ellipse(8, 9, 4.6, 3.8, body)
    c.ellipse(8, 16, 4, 3.6, cloth)
    c.rect(4, 15, 5, 17, body)                          # 伸出的手
    c.set(5, 9, "K"); c.set(3, 10, "p" if kind != 2 else "K")
    if kind == 2:
        c.ellipse(5, 11, 2, 1.2, "w")
    legs = [(6, 10)] if step == 0 else [(7, 9)]
    for a_, b_ in legs:
        c.rect(a_, 19, a_ + 1, 20, dark); c.rect(b_, 19, b_ + 1, 20, dark)
    c.outline()
    return c


def gameboy():
    c = Canvas(7, 9)
    c.rect(1, 1, 5, 7, "a")
    c.rect(2, 2, 4, 4, "g"); c.set(2, 2, "W")
    c.set(2, 6, "K"); c.set(4, 6, "r")
    c.outline()
    return c


def bubble():
    """满篓气泡：点它让小猫去小镇卖鱼。里面画一个小摊。"""
    c = Canvas(19, 18)
    c.rect(2, 1, 16, 12, "W"); c.rect(1, 2, 17, 11, "W")
    c.rows(4, 13, ["WWW", "WW.", "W.."])
    c.rows(5, 3, ["rwrwrwrwr", "rwrwrwrwr", ".o.....o.", ".o.sSs.o.", ".nnnnnnn.", ".ooooooo."])
    c.outline()
    return c


def cloud():
    c = Canvas(30, 11)
    c.ellipse(9, 6, 7, 3.6, "W"); c.ellipse(17, 4.5, 7, 4, "W"); c.ellipse(23, 7, 5.5, 3, "W")
    c.rect(4, 8, 26, 9, "W")
    return c


def hills():
    """远山，64 宽可平铺。"""
    c = Canvas(64, 22)
    for x in range(64):
        h1 = int(9 + 7 * math.sin(x / 64 * 2 * math.pi) + 3 * math.sin(x / 64 * 6 * math.pi))
        c.rect(x, 21 - h1, x, 21, "S")
        h2 = int(5 + 4 * math.sin(x / 64 * 4 * math.pi + 1.3))
        c.rect(x, 21 - h2, x, 21, "G")
    return c


# ---------------------------------------------------------------- 鱼
# ---------------------------------------------------------------- 室内
def room_door():
    c = Canvas(18, 30)
    c.rect(1, 1, 16, 28, "o")
    c.rect(1, 1, 16, 2, "O"); c.rect(1, 1, 2, 28, "O"); c.rect(15, 1, 16, 28, "O")
    c.rect(5, 6, 12, 14, "n"); c.rect(5, 18, 12, 25, "n")
    c.set(13, 16, "y"); c.set(13, 17, "H")
    c.outline()
    return c


def room_window():
    c = Canvas(24, 20)
    c.rect(1, 1, 22, 18, "O")
    c.rect(3, 3, 20, 16, "c")
    c.rect(11, 3, 12, 16, "O"); c.rect(3, 9, 20, 10, "O")
    c.rows(4, 12, ["..gg....", ".gggg.g.", "gggggggg"])
    c.pts([(5, 4), (6, 5), (14, 4)], "W")
    c.rect(0, 17, 23, 18, "n")
    c.outline()
    return c


def counter():
    c = Canvas(46, 18)
    c.rect(1, 1, 44, 16, "o")
    c.rect(1, 1, 44, 3, "n")
    c.rect(1, 14, 44, 16, "O")
    for x in (12, 23, 34):
        c.rect(x, 4, x, 13, "O")
    c.outline()
    return c


def shelf(kind):
    """墙上的货架。tackle: 鱼竿、饵料罐、鱼篓；hats: 三顶帽子。"""
    c = Canvas(48, 34)
    c.rect(1, 1, 46, 32, "O")
    c.rect(3, 3, 44, 15, "o"); c.rect(3, 18, 44, 30, "o")
    c.rect(1, 16, 46, 17, "n"); c.rect(1, 31, 46, 32, "n")
    if kind == "tackle":
        for x in (6, 11):                               # 鱼竿
            c.rect(x, 4, x, 15, "n"); c.set(x, 4, "r")
        for x, k in ((20, "r"), (27, "g"), (34, "b")):  # 饵料罐
            c.rect(x, 9, x + 4, 15, k); c.rect(x, 8, x + 4, 8, "a"); c.set(x + 1, 10, "W")
        c.rows(6, 22, ["..HHHHH..", "..H...H..", "hhhhhhhhh", "HhHhHhHhH", "hHhHhHhHh", ".hHhHhHh.", ".hhhhhhh."])
        c.rows(22, 24, ["s.sss.", "ssssKs", "s.sss."]); c.rows(32, 24, ["b.bbb.", "bbbbKb", "b.bbb."])
    else:
        c.rows(5, 8, ["...hhhhh...", "...hhhhh...", "...rrrrr...", "hhhhhhhhhhh", ".HHHHHHHHH."])
        c.rows(22, 8, ["....ggggg..", "...ggggggg.", "...GGGGGGG.", ".ggggggggg.", "GGGGGGGGGGG"][:5])
        c.rows(8, 22, ["...R....", ".rrrrrr.", "rrrrrrrr", "rrrrrrrr", ".RRRRRR."])
        c.rect(24, 20, 30, 29, "p"); c.rect(33, 20, 39, 29, "c"); c.rect(24, 20, 39, 20, "a")   # 布料
    c.outline()
    return c


def mirror():
    c = Canvas(16, 32)
    c.rect(1, 1, 14, 26, "H")
    c.rect(3, 3, 12, 24, "c")
    c.pts([(4, 5), (5, 4), (4, 6), (9, 12), (10, 11)], "W")
    c.rect(4, 27, 5, 30, "H"); c.rect(10, 27, 11, 30, "H")
    c.outline()
    return c


def bookshelf():
    c = Canvas(28, 40)
    c.rect(1, 1, 26, 38, "O")
    for i, y in enumerate((3, 15, 27)):
        c.rect(3, y, 24, y + 9, "o")
        x = 3
        for j, k in enumerate(["r", "b", "g", "y", "p", "s", "c", "r", "b", "h"][i:] + ["a"] * 3):
            if x > 22:
                break
            w = 2 if (i + j) % 3 else 3
            c.rect(x, y + (1 if (i + j) % 4 == 0 else 0), min(24, x + w - 1), y + 9, k)
            x += w
        c.rect(1, y + 10, 26, y + 11, "n")
    c.outline()
    return c


def calendar():
    c = Canvas(16, 18)
    c.rect(1, 1, 14, 16, "w")
    c.rect(1, 1, 14, 4, "r")
    for y in (7, 10, 13):
        for x in (3, 6, 9, 12):
            c.set(x, y, "a")
    c.rect(6, 9, 7, 11, "r"); c.set(6, 8, "g")      # 圈出来的番茄日
    c.outline()
    return c


def bed():
    c = Canvas(44, 20)
    c.rect(1, 9, 42, 15, "b")
    c.rect(1, 9, 42, 10, "c")
    c.rect(1, 6, 12, 10, "W"); c.rect(2, 7, 11, 9, "w")
    c.rect(1, 2, 3, 18, "o"); c.rect(40, 7, 42, 18, "o")
    c.rect(1, 15, 42, 16, "O")
    c.rect(20, 11, 24, 13, "y") if False else c.pts([(20, 12), (26, 12), (32, 12)], "W")
    c.outline()
    return c


def rug():
    c = Canvas(40, 5)
    c.rect(2, 1, 37, 3, "r")
    c.rect(4, 2, 35, 2, "h")
    c.rect(0, 1, 1, 3, "h"); c.rect(38, 1, 39, 3, "h")
    return c


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
    "town": ["...r...", "..rrr..", ".rrrrr.", ".hhhhh.", ".hohch.", ".hohhh.", "......."],
    "view": ["ww...ww", "w.....w", "..www..", "..www..", "..www..", "w.....w", "ww...ww"],
    "skip": [".......", "c..c.c.", "cc.ccc.", "cccccc.", "cc.ccc.", "c..c.c.", "......."],
    "bag": [".......", "..hhh..", ".h...h.", ".ooooo.", ".oonoo.", ".ooooo.", "......."],
    "gear": ["..a.a..", ".aaaaa.", "aaWWWaa", ".aW.Wa.", "aaWWWaa", ".aaaaa.", "..a.a.."],
    "menu": [".......", ".wwwww.", ".......", ".wwwww.", ".......", ".wwwww.", "......."],
    "plus": [".......", "...g...", "...g...", ".ggggg.", "...g...", "...g...", "......."],
    "minus": [".......", ".......", ".......", ".rrrrr.", ".......", ".......", "......."],
    "left": [".......", "...c...", "..cc...", ".ccc...", "..cc...", "...c...", "......."],
    "right": [".......", "...c...", "...cc..", "...ccc.", "...cc..", "...c...", "......."],
    "cat": [".f...f.", ".ff.ff.", ".fffff.", ".fKfKf.", ".ffpff.", "..fff..", "......."],
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


def pips():
    """升级等级点：0=未升 1=已升"""
    a = Canvas(5, 5); a.rect(1, 1, 3, 3, "A"); a.outline()
    b = Canvas(5, 5); b.rect(1, 1, 3, 3, "y"); b.set(1, 1, "W"); b.outline()
    return sheet([a, b])


def hold():
    """番茄渔获（船舱木箱）：专注时用它代替鱼篓图标，表示不限量。"""
    c = Canvas(11, 10)
    c.rect(1, 3, 9, 8, "o")
    c.rect(1, 3, 9, 3, "n")
    c.rect(1, 6, 9, 6, "O")
    c.rows(3, 1, ["sss..", "sSsss"])            # 露出来的鱼
    c.set(7, 1, "s"); c.set(4, 2, "K")
    c.pts([(2, 5), (8, 5), (2, 8), (8, 8)], "O")
    c.outline()
    return c


def chest(open_=False):
    """钓上来的宝箱：0=关着 1=打开（露出金币）"""
    c = Canvas(18, 16)
    c.rect(2, 8, 15, 14, "o")
    c.rect(2, 8, 15, 8, "O"); c.rect(2, 13, 15, 14, "O")
    for x in (4, 13):
        c.rect(x, 8, x, 14, "y")
    if open_:
        c.rect(2, 2, 15, 4, "o"); c.rect(2, 2, 15, 2, "n")
        for x in (4, 13):
            c.rect(x, 2, x, 4, "y")
        c.rect(3, 5, 14, 7, "y")
        c.pts([(5, 5), (9, 6), (12, 5)], "W"); c.pts([(7, 7), (11, 7)], "H")
    else:
        c.rect(2, 4, 15, 7, "o"); c.rect(3, 3, 14, 3, "o"); c.rect(3, 3, 14, 3, "n")
        for x in (4, 13):
            c.rect(x, 3, x, 7, "y")
        c.rect(8, 7, 9, 9, "y"); c.set(8, 8, "K")
    c.outline()
    return c


# ---------------------------------------------------------------- 物品图标（16×16）
def item_icon(kind):
    c = Canvas(16, 16)
    if kind == "bottle":
        c.rect(6, 5, 10, 13, "c"); c.rect(7, 2, 9, 4, "c")
        c.rect(7, 1, 9, 1, "o")                       # 木塞
        c.rect(7, 8, 9, 11, "w"); c.set(8, 9, "a")    # 里面的纸条
        c.pts([(6, 6), (6, 7)], "W")
    elif kind == "lucky_bait":
        c.rect(4, 6, 11, 13, "g"); c.rect(4, 12, 11, 13, "G")   # 罐子
        c.rect(3, 4, 12, 5, "y")                               # 盖子
        c.rows(6, 7, ["W.W", ".W.", "W.W"])                    # 四叶草记号
        c.set(4, 6, "W")
    elif kind == "bell":
        c.rect(5, 5, 10, 11, "y"); c.rect(4, 10, 11, 12, "y"); c.rect(6, 3, 9, 4, "y")
        c.rect(7, 1, 8, 2, "H")
        c.rect(9, 5, 10, 11, "H"); c.rect(4, 12, 11, 12, "H")
        c.rect(7, 13, 8, 14, "r")
        c.pts([(6, 5), (6, 6)], "W")
    elif kind == "map_piece":
        c.rows(2, 2, ["wwwwwwwww...", "wwwwwwwwww..", "wwwwwwwwwww.", "wwwwwwwwwww.", "wwwwwwwwww..", "wwwwwwww....",
                      "wwwwwwwww...", "wwwwwwwwwww.", "wwwwwwwwwww.", "wwwwwwwww...", "wwwwwww.....", "wwwww......."])
        c.pts([(4, 5), (5, 6), (6, 6), (7, 7), (8, 8), (9, 8)], "o")     # 路线
        c.rows(9, 9, ["r.r", ".r.", "r.r"])                              # 藏宝点
        c.pts([(3, 11), (4, 12)], "h")
    elif kind == "pearl":
        c.rows(2, 8, ["a..........a", "aa........aa", ".aaaaaaaaaa.", "..aaaaaaaa..", "...AAAAAA..."])   # 贝壳
        c.ellipse(8, 6, 3, 3, "W")
        c.pts([(9, 7), (10, 6), (9, 8)], "c"); c.set(7, 5, "p")
    elif kind == "boot":
        c.rect(5, 2, 9, 10, "o"); c.rect(5, 2, 9, 3, "n")
        c.rect(5, 9, 13, 12, "o"); c.rect(5, 13, 13, 13, "O")
        c.rect(9, 5, 9, 9, "O"); c.pts([(6, 5), (7, 7), (6, 9)], "h")   # 鞋带
        c.pts([(12, 10), (11, 9)], "n")
    c.outline()
    return c


def slot(selected=False):
    """物品栏的一个格子（22×22）：0=普通 1=选中"""
    c = Canvas(22, 22)
    c.rect(0, 0, 21, 21, "y" if selected else "A")
    c.rect(1, 1, 20, 20, "K")
    c.rect(2, 2, 19, 19, "A")
    c.rect(2, 2, 19, 2, "K"); c.rect(2, 2, 2, 19, "K")
    return c


def sparkle():
    """闪光粒子（特效不描边）：0=大 1=小"""
    a = Canvas(5, 5); a.rows(0, 0, ["..W..", "..y..", "WyWyW", "..y..", "..W.."])
    b = Canvas(5, 5); b.rows(1, 1, [".W.", "WyW", ".W."])
    return sheet([a, b])


def splash():
    """浮漂落水的水花，两帧（特效不描边）"""
    a = Canvas(11, 5); a.rows(0, 0, ["...........", "....W.W....", "...W...W...", "...cWWWc...", "..........."])
    b = Canvas(11, 5); b.rows(0, 0, ["..W.....W..", ".W.......W.", "...........", ".c.cWWWc.c.", "..........."])
    return sheet([a, b])


LABELS = [
    "商店", "图鉴", "统计", "设置", "鱼竿", "鱼饵", "鱼篓", "已满级",
    "自由挂机钓得更快", "稀有鱼更容易上钩", "鱼篓容量加二", "金币可以升级装备",
    "？？？", "共钓到", "今日", "累计", "近七日", "专注", "短休", "长休", "大小", "音效",
    "我的小猫", "给小猫选个样子", "完成",
    "方向键走动", "空格键互动", "空格键去小镇",
    "小猫的家", "裁缝铺", "渔具店", "空格键进入", "空格键聊天",
    "确定要退出吗", "退出", "取消", "宝箱",
    "物品栏", "使用", "空空如也", "生效中", "去钓宝箱吧",
    "欢迎光临", "空格键出门", "空格键看货", "空格键照镜子", "空格键看图鉴", "空格键看统计", "空格键小睡", "Z", "休息时才能小睡", "已经睡饱了", "小猫睡得真香",
    "今天的鱼真新鲜", "听说金锦鲤很稀有", "专注时鱼更值钱", "别让小猫饿着了", "天气真好呀", "你的帽子真好看",
]
FONT_FILE = os.path.join(os.path.dirname(__file__), "fonts", "fusion-pixel-10px-proportional-zh_hans.otf.woff")


def labels():
    """把界面用到的中文标签用开源像素字体（Fusion Pixel 10px, OFL）预渲染成图集。
    这样运行时不依赖任何字体引擎，换平台（含 3DS）也能直接用。"""
    import json
    from PIL import ImageDraw, ImageFont
    names = list(LABELS)
    extra = json.load(open(os.path.join(ROOT, "data", "fish.json"), encoding="utf-8"))["fish"]
    cat_cfg = json.load(open(os.path.join(ROOT, "data", "cat.json"), encoding="utf-8"))
    items = json.load(open(os.path.join(ROOT, "data", "balance.json"), encoding="utf-8")).get("items", [])
    for f in extra + cat_cfg["furs"] + cat_cfg["patterns"] + cat_cfg["hats"] + items:
        for key in ("name", "desc"):
            if f.get(key) and f[key] not in names:
                names.append(f[key])
    font_ = ImageFont.truetype(FONT_FILE, 10)
    rects, strips = {}, []
    for n in names:
        im = Image.new("L", (10 * len(n) + 4, 14), 0)
        d = ImageDraw.Draw(im); d.fontmode = "1"
        d.text((0, 0), n, font=font_, fill=255)
        box = im.getbbox()
        assert box and box[1] >= 2 and box[3] <= 12, f"标签渲染异常: {n} {box}"
        for i in range(len(n)):   # 每个字都必须真的画出了像素（防止缺字）
            assert im.crop((i * 10, 0, i * 10 + 10, 14)).getbbox(), f"字体缺字: {n}[{i}]"
        strips.append((n, im.crop((0, 2, box[2], 12))))
    w = max(s.width for _, s in strips)
    c = Canvas(w, 10 * len(strips))
    for row, (n, im) in enumerate(strips):
        for y in range(10):
            for x in range(im.width):
                if im.getpixel((x, y)) > 128:
                    c.set(x, row * 10 + y, "w")
        rects[n] = (0, row * 10, im.width, 10)
    save(c, "labels")
    out = ["# 由 tools/art/generate.py 自动生成，请勿手改。", "extends RefCounted", "", "const RECTS := {"]
    for n, r in rects.items():
        out.append(f'\t"{n}": Rect2({r[0]}, {r[1]}, {r[2]}, {r[3]}),')
    out.append("}")
    open(os.path.join(ROOT, "presentation", "labels.gd"), "w", encoding="utf-8").write("\n".join(out) + "\n")
    return c


def panel():
    c = Canvas(110, 27)
    c.rect(1, 1, 108, 25, "K")
    c.rect(2, 2, 107, 2, "A")
    for x, y in ((1, 1), (108, 1), (1, 25), (108, 25)):
        c.px[y][x] = None
    return c


def build():
    made = {
        "cat": save(cat_sheet(), "cat"),
        "boat": save(boat(), "boat"),
        "sea": save(sheet([sea(0), sea(1), sea(2)]), "sea"),
        "ground": save(ground(), "ground"),
        "pier": save(pier(), "pier"),
        "house_0": save(house("w", "h", "r", "R"), "house_0"),
        "house_1": save(house("l", "f", "b", "B", w=40, door_x=6), "house_1"),
        "house_2": save(house("W", "a", "g", "G", w=52, door_x=22), "house_2"),
        "tree": save(tree(), "tree"),
        "stall_back": save(stall_back(), "stall_back"),
        "stall_front": save(stall_front(), "stall_front"),
        "gameboy": save(gameboy(), "gameboy"),
        "bubble": save(bubble(), "bubble"),
        "cloud": save(cloud(), "cloud"),
        "hills": save(hills(), "hills"),
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
        "pips": save(pips(), "pips"),
        "sparkle": save(sparkle(), "sparkle"),
        "chest": save(sheet([chest(), chest(True)]), "chest"),
        "slot": save(sheet([slot(), slot(True)]), "slot"),
        "splash": save(splash(), "splash"),
        "hold": save(hold(), "hold"),
        "room_door": save(room_door(), "room_door"),
        "room_window": save(room_window(), "room_window"),
        "counter": save(counter(), "counter"),
        "shelf_tackle": save(shelf("tackle"), "shelf_tackle"),
        "shelf_hats": save(shelf("hats"), "shelf_hats"),
        "mirror": save(mirror(), "mirror"),
        "bookshelf": save(bookshelf(), "bookshelf"),
        "calendar": save(calendar(), "calendar"),
        "bed": save(bed(), "bed"),
        "rug": save(rug(), "rug"),
        "labels": labels(),
    }
    for k in ("bottle", "lucky_bait", "bell", "map_piece", "pearl", "boot"):
        made["item_" + k] = save(item_icon(k), "item_" + k)
    for k in range(3):
        made["villager_%d" % k] = save(sheet([villager(k, 0), villager(k, 1)]), "villager_%d" % k)
    for n in BTN:
        made["btn_" + n] = save(sheet([button(n), button(n, True)]), "btn_" + n)
    return made


def preview(made):
    """拼一张小镇场景目检图（不进版本库）。"""
    s = Canvas(320, 110)
    s.rect(0, 0, 319, 109, "c")
    for x in range(0, 320, 64):
        s.blit(made["hills"], x, 46)
    s.blit(made["cloud"], 30, 8); s.blit(made["cloud"], 190, 16)
    for x in range(0, 128, 32):
        s.blit(sea(0), x, 68)
    s.rect(0, 74, 127, 109, "b"); s.rect(0, 90, 127, 109, "B")
    for x in range(128, 320, 32):
        s.blit(made["ground"], x, 64)
    s.rect(128, 80, 319, 109, "n")
    s.blit(made["pier"], 84, 61)
    s.blit(made["house_0"], 140, 5); s.blit(made["house_1"], 196, 5); s.blit(made["house_2"], 262, 5)
    s.blit(made["tree"], 240, 29)
    s.blit(made["boat"], 20, 57); s.blit(cat(), 30, 34)
    s.blit(made["stall_back"], 150, 25); s.blit(cat(), 157, 33); s.blit(made["stall_front"], 150, 50)
    s.blit(cat(pose="walk"), 100, 32); s.blit(made["basket"], 104, 44)
    s.blit(cat(pose="walk", step=1, hat="beret", look=("A", "K", "a", True, True)), 215, 35)
    for k in range(3):
        s.blit(villager(k, k % 2), 200 + k * 22 + (40 if k else 0), 43)
    s.blit(made["bubble"], 52, 16); s.blit(made["gameboy"], 49, 53)
    im = s.image().resize((320 * 4, 110 * 4), Image.NEAREST)
    im.save(os.path.join(os.path.dirname(__file__), "preview.png"))


def export_palette():
    """把调色板导出给 Godot，保证代码绘制的线条/文字与素材同色。"""
    lines = ["# 由 tools/art/generate.py 自动生成，请勿手改。", "extends RefCounted", ""]
    for k, v in PALETTE.items():
        name = ("U_" if k.isupper() else "L_") + k.upper()
        lines.append(f'const {name} := Color("{v}")')
    lines += ["", "## 按调色板键取色（data/cat.json 里的毛色用键来写）", "const BY_KEY := {"]
    lines += [f'\t"{k}": Color("{v}"),' for k, v in PALETTE.items()] + ["}"]
    open(os.path.join(ROOT, "presentation", "palette.gd"), "w").write("\n".join(lines) + "\n")


def app_icon():
    """应用图标：把猫放大 7 倍放在水蓝色底上（最近邻放大，保持像素感）。"""
    c = Canvas(36, 36)
    c.rect(1, 0, 34, 35, "b"); c.rect(0, 1, 35, 34, "b")
    c.rect(0, 26, 35, 34, "B"); c.rect(1, 35, 34, 35, "B")
    for x in (4, 14, 25):
        c.rect(x, 25, x + 4, 25, "c")
    c.blit(cat(), 2, 0)
    c.image().resize((36 * 7, 36 * 7), Image.NEAREST).save(os.path.join(ROOT, "assets", "icon.png"))


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
    app_icon()
    cat_layers()
    cat_gallery()
    check(m)

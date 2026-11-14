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
    elif hat == "rain":
        # 蓑衣帽：尖顶斗笠，稻草色，带暗色草纹
        rows = [(3, 17, 19), (4, 16, 20), (5, 15, 21), (6, 14, 22), (7, 13, 23), (8, 11, 25), (9, 10, 26)]
        for y, x0, x1 in rows:
            c.rect(x0 + dx, y + by, x1 + dx, y + by, "n")
        for y, x0, x1 in rows[1:-1]:
            c.set(x0 + 2 + dx, y + by, "o"); c.set(x1 - 2 + dx, y + by, "o")
        c.rect(10 + dx, 9 + by, 26 + dx, 9 + by, "H")
        c.pts([(17 + dx, 4 + by), (18 + dx, 4 + by)], "w")
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


OUTFITS = ["scarf", "yukata", "overalls"]


def draw_outfit(b, kind, pose, by):
    """给已经描好边的小猫身体上色：只改毛色像素（FUR_SLOTS），不动描边，所以一定贴合身体。"""
    c = Canvas(32, 32)
    for y in range(32):
        for x in range(32):
            c.px[y][x] = b.px[y][x]
    fur = set(FUR_SLOTS)
    done = set()

    def paint(x0, y0, x1, y1, k):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if 0 <= x < 32 and 0 <= y < 32 and (c.px[y][x] in fur or (x, y) in done):
                    c.px[y][x] = k
                    done.add((x, y))

    walk = pose == "walk"
    if kind == "scarf":
        if walk:
            paint(14, 19 + by, 20, 20 + by, "r"); paint(14, 21 + by, 16, 21 + by, "R")
            paint(14, 22 + by, 15, 24 + by, "r")
        else:
            paint(10, 19, 18, 20, "r"); paint(10, 21, 11, 21, "R")
            paint(9, 22, 10, 25, "r"); paint(9, 25, 10, 25, "R")
            paint(12, 20, 14, 20, "R")
    elif kind == "yukata":
        if walk:
            paint(12, 20 + by, 21, 27 + by, "b"); paint(12, 26 + by, 21, 27 + by, "B")
            paint(12, 24 + by, 21, 24 + by, "w"); paint(12, 25 + by, 21, 25 + by, "y")
            for x, y in ((14, 21), (17, 22), (19, 21), (16, 26)):
                paint(x, y + by, x, y + by, "W")
        else:
            paint(6, 21 + by, 18, 29, "b"); paint(6, 28, 18, 29, "B")
            paint(6, 25, 18, 25, "w"); paint(6, 26, 18, 26, "y")
            for x, y in ((8, 22), (11, 23), (14, 22), (16, 24), (9, 27), (13, 28)):
                paint(x, y + by, x, y + by, "W")
    elif kind == "overalls":
        if walk:
            paint(13, 23 + by, 20, 27 + by, "g"); paint(13, 27 + by, 20, 27 + by, "G")
            paint(14, 20 + by, 14, 22 + by, "g"); paint(19, 20 + by, 19, 22 + by, "g")
            paint(14, 22 + by, 14, 22 + by, "y"); paint(19, 22 + by, 19, 22 + by, "y")
            paint(13, 26, 20, 29, "g")
            paint(13, 29, 20, 29, "G")
        else:
            paint(6, 22 + by, 18, 29, "g"); paint(6, 28, 18, 29, "G")
            paint(10, 20 + by, 11, 21 + by, "g"); paint(17, 20 + by, 18, 21 + by, "g")
            paint(10, 22 + by, 11, 22 + by, "y"); paint(17, 22 + by, 18, 22 + by, "y")
            paint(11, 26, 13, 27, "G"); paint(12, 26, 12, 26, "y")
    return c


def cat_raw(tail_up=False, eyes_closed=False, breathe=0, hat=None, pose="sit", step=0, rain=False):
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
    if rain:
        # 蓑衣：稻草披风，盖住躯干，下摆有一圈穗
        if pose == "walk":
            cx, cy, rx, ry = 16.5, 23.6 + by, 5.6, 5.0 - by * 0.4
        else:
            cx, cy, rx, ry = 12.6, 23.4 + by, 7.6, 7.3 - by
        c.ellipse(cx, cy, rx, ry, "n")
        for i, x in enumerate(range(int(cx - rx) + 2, int(cx + rx) - 1, 3)):
            for y in range(int(cy - ry) + 3, int(cy + ry)):
                if c.get(x, y) == "n":
                    c.set(x, y, "o")
        bottom = int(cy + ry)
        for x in range(int(cx - rx) + 1, int(cx + rx)):
            if c.get(x, bottom) == "n":
                c.set(x, bottom, "H")
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


    for kind in OUTFITS:
        overlays = []
        for f, b in zip(CAT_FRAMES, bare):
            h = draw_outfit(b, kind, f.get("pose", "sit"), f.get("step", f.get("breathe", 0)))
            o = Canvas(32, 32)
            for y in range(32):
                for x in range(32):
                    if h.px[y][x] != b.px[y][x]:
                        o.px[y][x] = h.px[y][x]
            overlays.append(o)
        write("outfit_" + kind, overlays, False)

    gear = []
    for f, b in zip(CAT_FRAMES, bare):
        h = cat_raw(hat="rain", rain=True, **f)
        o = Canvas(32, 32)
        for y in range(32):
            for x in range(32):
                if h.px[y][x] != b.px[y][x]:
                    assert h.px[y][x] is not None
                    o.px[y][x] = h.px[y][x]
        gear.append(o)
    write("rain_gear", gear, False)


def cat_gallery():
    """所有毛色 × 花纹 × 帽子的目检图（不进版本库）。"""
    import json
    cfg = json.load(open(os.path.join(ROOT, "data", "cat.json"), encoding="utf-8"))
    for f in cfg["furs"]:
        for k in ("base", "shade", "light"):
            assert f[k] in PALETTE, f"cat.json 毛色用了调色板以外的键: {f}"
    hats = [None] + HATS
    assert len(cfg["hats"]) == len(hats), "cat.json 的帽子数量与生成器不一致"
    assert len(cfg["outfits"]) == len(OUTFITS) + 1, "cat.json 的衣服数量与生成器不一致"
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


def ship_model():
    """架子上的帆船模型。26×18。"""
    c = Canvas(26, 18)
    c.rect(12, 1, 12, 11, "O")
    for i in range(8):
        c.rect(13, 2 + i, 13 + min(i, 7) // 1 if i < 7 else 20, 2 + i, "W")
    c.rect(5, 12, 22, 14, "o"); c.rect(4, 11, 23, 11, "n"); c.rect(6, 15, 21, 15, "O")
    c.pts([(8, 13), (12, 13), (16, 13), (20, 13)], "O")
    c.pts([(12, 1), (13, 1), (14, 1)], "r")
    c.outline()
    return c


def blueprint():
    """墙上的船只设计图。22×28。"""
    c = Canvas(22, 28)
    c.rect(0, 0, 21, 27, "w")
    c.rect(0, 0, 21, 0, "n"); c.rect(0, 27, 21, 27, "n")
    c.rect(1, 3, 20, 24, "c")
    c.rect(1, 3, 20, 3, "b"); c.rect(1, 24, 20, 24, "b")
    c.rect(10, 6, 10, 16, "B")
    c.rows(11, 7, ["WW", "WWW", "WWWW", "WWWWW", "WWWWWW"])
    c.rows(4, 17, ["WWWWWWWWWWWWWW", ".WWWWWWWWWWWW."])
    c.pts([(3, 21), (6, 21), (9, 21), (12, 21), (15, 21), (18, 21)], "B")
    c.outline()
    return c


def anchor():
    """墙上的铁锚。14×14。"""
    c = Canvas(14, 14)
    c.rows(0, 0, [
        ".....AAAA.....",
        ".....A..A.....",
        ".....AAAA.....",
        "...AAAAAAAA...",
        ".......AA.....",
        ".......AA.....",
        ".......AA.....",
        ".......AA.....",
        "A......AA....A",
        "AA.....AA...AA",
        ".AA....AA..AA.",
        "..AA...AA.AA..",
        "...AAAAAAAAA..",
        "....AAAAAAA...",
    ])
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


def stall_back(c1="r", c2="w", edge="R"):
    """摊位后半：立柱 + 条纹雨棚（默认红白）。猫坐在它和柜台之间。"""
    c = Canvas(46, 42)       # 比摊位高 2 像素，脚踩进草地里，不留缝
    c.rect(3, 8, 4, 41, "o"); c.rect(41, 8, 42, 41, "o")
    for x in range(1, 45):
        k = c1 if ((x - 1) // 4) % 2 == 0 else c2
        c.rect(x, 1, x, 8, k)
        if ((x - 1) % 4) in (1, 2):
            c.set(x, 9, k)
    c.rect(1, 1, 44, 1, edge)
    c.outline()
    return c


# ---------------------------------------------------------------- 市场
def _ball(c, cx, cy, r, k, hl="W"):
    c.ellipse(cx, cy, r, r, k)
    c.set(int(cx - 1), int(cy - 1), hl)


def goods(kind):
    """柜台上的货，36×8。"""
    c = Canvas(36, 8)
    if kind == "fruit":
        for i, k in enumerate(["r", "y", "r", "g", "y", "r"]):
            _ball(c, 3 + i * 6, 4, 2.6, k)
            c.set(3 + i * 6, 1, "G")
    elif kind == "veg":
        for i in range(3):
            x = 3 + i * 6
            c.rows(x - 1, 1, ["g.g", ".f.", ".f.", ".f.", ".f."], {"f": "f"})   # 胡萝卜
        for i in range(3):
            x = 22 + i * 5
            _ball(c, x, 4, 2.4, "g"); c.set(x, 3, "G"); c.set(x + 1, 5, "G")
    elif kind == "bread":
        for i in range(3):
            x = 5 + i * 8
            c.ellipse(x, 4, 3.4, 2.4, "h"); c.pts([(x - 1, 3), (x, 2), (x + 1, 3)], "H")
        c.rect(26, 3, 34, 5, "n"); c.pts([(28, 3), (31, 3), (28, 5), (31, 5)], "o")
    else:  # flower
        c.rect(1, 5, 34, 7, "o"); c.rect(1, 5, 34, 5, "n")
        for i, k in enumerate(["p", "r", "y", "p", "w", "r", "y"]):
            x = 3 + i * 5
            c.set(x, 4, "g"); c.set(x, 3, "g")
            c.rect(x - 1, 0, x + 1, 2, k); c.set(x, 1, "y" if k != "y" else "H")
    c.outline()
    return c


def goods_icon(kind):
    """买到的东西，7×7，顾客手里拿着。"""
    c = Canvas(7, 7)
    if kind == "fruit":
        _ball(c, 3, 4, 2.4, "r"); c.set(3, 1, "G"); c.set(4, 1, "g")
    elif kind == "veg":
        c.rows(1, 0, ["g.g", "...", ".f.", ".f.", ".f.", "..."], {"f": "f"}); c.rows(2, 1, ["f.f", ".f."], {"f": "f"})
    elif kind == "bread":
        c.ellipse(3, 4, 3, 2, "h"); c.pts([(2, 3), (3, 2), (4, 3)], "H")
    else:
        c.rect(2, 0, 4, 2, "p"); c.set(3, 1, "y"); c.rect(3, 3, 3, 5, "g")
    c.outline()
    return c


def market_gate():
    """市场入口的拱门，48×50。招牌由代码画（文字走标签图集）。"""
    c = Canvas(48, 50)
    c.rect(2, 8, 7, 49, "o"); c.rect(40, 8, 45, 49, "o")
    c.rect(2, 8, 3, 49, "n"); c.rect(40, 8, 41, 49, "n")
    c.rect(6, 8, 7, 49, "O"); c.rect(44, 8, 45, 49, "O")
    c.rect(0, 2, 47, 9, "o"); c.rect(0, 2, 47, 3, "n"); c.rect(0, 8, 47, 9, "O")
    for x in range(8, 40, 4):
        c.set(x, 10, "r"); c.set(x + 1, 10, "w")
    c.outline()
    return c


def stall_front():
    """摊位前半：柜台。"""
    c = Canvas(46, 13)       # 低柜台：猫和摊主的脸露在上面；最下 2 行踩进草地
    c.rect(1, 1, 44, 2, "n")
    c.rect(2, 3, 43, 12, "o")
    c.rect(2, 3, 43, 3, "O")
    for x in (12, 23, 34):
        c.rect(x, 4, x, 12, "O")
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


def bird_fly(frame):
    """飞行中的海鸟，面朝左。frame 0 翅膀上扬 / 1 翅膀下压。11×8。"""
    c = Canvas(11, 8)
    c.ellipse(6, 4, 3.6, 1.9, "w")
    c.ellipse(2.5, 3, 1.8, 1.6, "w")
    c.pts([(0, 3), (1, 3)], "y"); c.set(2, 2, "K")
    c.rect(9, 4, 10, 4, "a")
    if frame == 0:
        c.rows(4, 0, ["..a", "..aa", ".aaa"])
    else:
        c.rows(4, 5, [".aaa", "..aa", "..a"])
    c.outline()
    return c


def bird_perch():
    """停在东西上的海鸟，面朝左。8×10。"""
    c = Canvas(8, 10)
    c.ellipse(4, 5.5, 3, 3.4, "w")
    c.ellipse(3, 2.5, 2, 2, "w")
    c.pts([(0, 2), (1, 2)], "y"); c.set(2, 1, "K")
    c.rect(4, 4, 5, 6, "a"); c.rect(6, 7, 7, 8, "a")
    c.pts([(3, 9), (5, 9)], "f")
    c.outline()
    return c


def boat_head():
    """船尾的龙头：木头雕的，鸟可以停在头顶。12×20。"""
    c = Canvas(12, 20)
    c.rows(0, 0, ["...yy.......", "..nnnn......", ".nnrnnn.....", "nnnnnnnn....", "nOOOOnnn....",
                  ".....nnO....", ".....nnO....", ".....nnO....", "....nnnO....", "....nnnO...."])
    for y in range(10, 18):
        c.rect(4, y, 7, y, "n"); c.set(7, y, "O")
    c.rect(3, 18, 8, 18, "n"); c.rect(3, 19, 8, 19, "O")
    c.outline()
    return c


def boat_basket_back():
    """船上鱼篓的口（后半），鱼堆在它上面。14×5。"""
    c = Canvas(14, 5)
    c.ellipse(6.5, 2.2, 6.5, 2.3, "h")
    c.ellipse(6.5, 2.4, 5.2, 1.6, "O")
    c.outline()
    return c


def boat_basket():
    """船上鱼篓的前半（编织的篓身）。14×8。"""
    c = Canvas(14, 8)
    c.rect(0, 0, 13, 0, "h")
    for y in range(1, 8):
        inset = 1 if y >= 6 else 0
        for x in range(inset, 14 - inset):
            c.set(x, y, "H" if (x + y) % 2 else "h")
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


def bubble_sold():
    """卖光了气泡：点它让小猫回船去钓鱼。里面画一副鱼骨头。"""
    c = Canvas(19, 18)
    c.rect(2, 1, 16, 12, "W"); c.rect(1, 2, 17, 11, "W")
    c.rows(4, 13, ["WWW", "WW.", "W.."])
    c.rows(5, 4, ["..a.a.a..", "aaaaaaaaa", "..a.a.a.."])
    c.rows(5, 9, [".hhhhhhh."])
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


def coin_of(base, dark, hi):
    c = Canvas(9, 9)
    c.ellipse(4, 4, 3, 3, base)
    c.rows(2, 2, ["...", "..%s" % dark, ".%s%s" % (dark, dark)])
    c.pts([(4, 3), (4, 4), (4, 5)], dark)
    c.set(3, 2, hi)
    c.outline()
    return c


def umbrella():
    """雨伞（画在居民头顶，面朝左时伞柄在右下）。16×9。"""
    c = Canvas(16, 9)
    c.rect(2, 1, 13, 4, "r")
    c.rect(4, 0, 11, 0, "r")
    c.pts([(2, 4), (5, 4), (8, 4), (11, 4), (13, 4)], "R")
    c.pts([(4, 1), (5, 1)], "w")
    c.rect(8, 5, 8, 8, "O")
    c.pts([(7, 8)], "O")
    c.outline()
    return c


def piggy():
    """存钱罐。14×12。"""
    c = Canvas(14, 12)
    c.ellipse(6, 6, 5.5, 4.2, "p")
    c.rect(11, 5, 13, 7, "p")
    c.pts([(12, 6), (12, 5)], "R")
    c.rect(3, 9, 4, 11, "p")
    c.rect(8, 9, 9, 11, "p")
    c.pts([(9, 1), (3, 2)], "p")
    c.rect(5, 2, 8, 2, "K")
    c.set(10, 4, "K")
    c.pts([(1, 6)], "R")
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
    "fish": [".......", "..cc..c", ".cKccc.", "ccccccc", ".ccccc.", "..cc..c", "......."],
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
    "c": ["...", ".ww", "w..", "w..", ".ww"], "m": ["...", "www", "www", "w.w", "w.w"],
    "%": ["w.w", "..w", ".w.", "w..", "w.w"], ".": ["...", "...", "...", "...", ".w."],
    "(": [".w.", "w..", "w..", "w..", ".w."], ")": [".w.", "..w", "..w", "..w", ".w."],
}
FONT_ORDER = "0123456789:/+x-cm%.()"


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
    elif kind == "rod":
        for i in range(12):
            c.set(2 + i, 13 - i, "o")                 # 斜着的竿身
            c.set(3 + i, 13 - i, "O")
        c.rect(1, 12, 4, 14, "a"); c.set(2, 13, "A")  # 卷线轮
        c.pts([(14, 1), (15, 2), (15, 3), (15, 4)], "W")   # 竿尖的线
        c.pts([(13, 1), (14, 1)], "y")
    elif kind == "line":
        c.ellipse(8, 8, 5.5, 5.5, "w"); c.ellipse(8, 8, 2.2, 2.2, "a")   # 线轴
        c.rect(3, 4, 12, 4, "a"); c.rect(3, 12, 12, 12, "a")
        c.pts([(11, 7), (12, 8), (13, 9), (13, 10)], "c")
    elif kind == "hook":
        c.rect(7, 2, 8, 9, "a")                        # 钩柄
        c.pts([(7, 10), (7, 11), (6, 12), (5, 12), (4, 11), (4, 10), (3, 9)], "a")   # 钩弯
        c.pts([(3, 9), (3, 8)], "A")
        c.rect(6, 1, 9, 1, "A")                        # 钩眼
        c.set(8, 2, "K")
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
    elif kind == "bait_worm":
        c.rows(3, 4, ["pp.....pp", ".pppp.ppp", "..pRRppR.", ".pp.RR.pp", "pR....R.R"][:5])    # 一条弯弯的蚯蚓
        c.rect(3, 9, 12, 12, "n"); c.rect(3, 12, 12, 12, "O")                                 # 下面一小块泥
        c.pts([(5, 10), (8, 11), (10, 10)], "O")
    elif kind == "bait_shrimp":
        c.rows(3, 3, ["..rrrrr...", ".rrFFrrr..", "rrFrrrrrr.", "rr..rrFrrr", ".r...rrrr.", "......rr.r"])
        c.set(4, 5, "K"); c.pts([(2, 3), (1, 2)], "F")                                       # 眼睛和触须
        c.pts([(11, 8), (12, 9)], "F")
    elif kind == "boot":
        c.rect(5, 2, 9, 10, "o"); c.rect(5, 2, 9, 3, "n")
        c.rect(5, 9, 13, 12, "o"); c.rect(5, 13, 13, 13, "O")
        c.rect(9, 5, 9, 9, "O"); c.pts([(6, 5), (7, 7), (6, 9)], "h")   # 鞋带
        c.pts([(12, 10), (11, 9)], "n")
    c.outline()
    return c


def tangle():
    """空军：头顶一团乱麻似的黑线。13×10。"""
    c = Canvas(13, 10)
    c.rows(0, 1, ["..KKK.K...K..", ".K..KKKK.KK..", "KKKKK..KKK.KK", "K.KK.KKK..K..", "KKK.KK..KKKK.",
                  ".K.KKKKK.K.K.", "..KK..K.KKK..", "...KKKK.K..KK"])
    return c


def lock():
    """未解锁的小锁。7×9。"""
    c = Canvas(7, 9)
    c.rows(1, 0, [".aaa.", "a...a", "a...a"])
    c.rect(0, 3, 6, 8, "y")
    c.rect(0, 3, 6, 3, "h")
    c.rect(3, 5, 3, 6, "O")
    c.outline()
    return c


def storage():
    """家里的仓库：一口星露谷风格的木箱——圆顶箱盖、铁箍、中间一把金锁。22×18。"""
    c = Canvas(22, 18)
    c.rect(3, 0, 18, 0, "n")                      # 圆顶箱盖
    c.rect(1, 1, 20, 1, "n")
    c.rect(0, 2, 21, 4, "n")
    c.rect(0, 5, 21, 6, "o")
    c.rect(0, 7, 21, 7, "A")                      # 盖沿的铁条
    c.rect(0, 8, 21, 17, "o")                     # 箱身
    c.rect(0, 8, 21, 8, "n")
    c.rect(0, 15, 21, 17, "O")
    for x in (7, 14):                             # 木板缝
        c.rect(x, 9, x, 14, "O")
    for x in (2, 17):                             # 左右铁箍，从盖到底
        c.rect(x, 0 if x in (3, 18) else 2, x + 1, 17, "a")
        c.rect(x + 1, 2, x + 1, 17, "A")
        c.pts([(x, 10), (x, 15)], "W")
    c.rect(9, 5, 12, 11, "y")                     # 金锁
    c.rect(9, 10, 12, 11, "H")
    c.rect(8, 4, 13, 4, "A")
    c.pts([(10, 7), (10, 8), (11, 7)], "K")
    c.outline()
    return c


# ------------------------------------------------------------------ 装饰：渔具店 / 帽子店 / 摊位地面（日式阳光可爱风）
def lantern():
    """红灯笼（吊在天花板下）。9×16。"""
    c = Canvas(9, 16)
    c.rect(4, 0, 4, 3, "a")
    c.rect(2, 3, 6, 3, "K")
    c.ellipse(4, 8, 3.6, 4.2, "r")
    c.pts([(3, 6), (3, 7)], "W")
    for x in (2, 4, 6):
        c.rect(x, 5, x, 11, "R")
    c.rect(2, 12, 6, 12, "K")
    c.rect(4, 13, 4, 15, "y")
    c.outline()
    return c


def noren(kind):
    """门帘（挂在门楣）：渔具店是蓝布白鱼，帽子店是粉布草帽。18×10。"""
    c = Canvas(18, 10)
    c.rect(0, 0, 17, 0, "O")
    base = {"tackle": "b", "clothes": "g", "ship": "h"}.get(kind, "p")
    for x0 in (1, 6, 11):
        c.rect(x0, 1, x0 + 4, 8, base)
        c.rect(x0, 8, x0 + 4, 8, {"tackle": "B", "clothes": "G", "ship": "H"}.get(kind, "R"))
    if kind == "clothes":
        c.rows(6, 3, ["W...W", "WWWWW", ".WWW.", ".WWW."])
        c.pts([(2, 4), (3, 4)], "W")
        c.pts([(12, 4), (13, 4), (14, 4)], "W")
    elif kind == "ship":
        c.rows(6, 3, ["..K..", "WWKWW", "..K.."])
        c.pts([(2, 4), (3, 4)], "W")
        c.pts([(12, 4), (13, 4), (14, 4)], "W")
    elif kind == "tackle":
        c.rows(6, 3, [".WWW.", "WWWKW", ".WWW."])
        c.pts([(2, 4), (3, 4)], "W")
        c.pts([(12, 4), (13, 4), (14, 4)], "W")
    else:
        c.rows(6, 3, ["..hh.", ".hhhh", "HHHHH"])
        c.pts([(2, 4), (3, 4)], "W")
        c.pts([(12, 4), (13, 4), (14, 4)], "W")
    c.outline()
    return c


def wall_clothes():
    """墙上的衣物挂板：围巾、浴衣、背带裤挂在横杆上。40×26。"""
    c = Canvas(40, 26)
    c.rect(1, 1, 38, 24, "O")
    c.rect(2, 2, 37, 23, "n")
    c.rect(3, 4, 36, 4, "O")
    # 红围巾
    c.rect(5, 5, 8, 7, "r"); c.rect(5, 8, 6, 14, "r"); c.rect(5, 14, 6, 14, "R"); c.rect(5, 5, 8, 5, "R")
    # 蓝浴衣
    c.rect(14, 5, 24, 6, "b"); c.rect(11, 7, 27, 8, "b"); c.rect(14, 9, 24, 20, "b"); c.rect(14, 18, 24, 20, "B")
    c.rect(14, 13, 24, 13, "w"); c.rect(14, 14, 24, 14, "y")
    c.pts([(16, 10), (20, 11), (22, 16), (17, 17)], "W")
    # 背带裤
    c.rect(30, 5, 31, 8, "g"); c.rect(34, 5, 35, 8, "g"); c.rect(29, 9, 36, 20, "g"); c.rect(29, 19, 36, 20, "G")
    c.pts([(30, 8), (35, 8)], "y")
    c.rect(32, 10, 33, 12, "G")
    c.outline()
    return c


def mannequin():
    """立着的人台，穿着蓝浴衣，脖子上围红围巾。14×30。"""
    c = Canvas(14, 30)
    c.rect(6, 22, 7, 27, "O")
    c.rect(2, 28, 11, 29, "o")
    c.ellipse(7, 15, 4.8, 8, "b")
    c.rect(2, 20, 11, 22, "B")
    c.rect(2, 16, 11, 16, "w"); c.rect(2, 17, 11, 17, "y")
    c.pts([(5, 12), (9, 13), (8, 19), (4, 14)], "W")
    c.ellipse(7, 4, 3, 3, "w")
    c.rect(4, 7, 10, 8, "r"); c.rect(4, 9, 5, 12, "r"); c.rect(4, 12, 5, 12, "R")
    c.outline()
    return c


def wall_bobbers():
    """墙上的浮漂展示板：两排彩色浮漂挂在钉子上。34×26。"""
    c = Canvas(34, 26)
    c.rect(1, 1, 32, 24, "O")
    c.rect(2, 2, 31, 23, "n")
    c.rect(2, 12, 31, 12, "o")
    cols = ["r", "y", "b", "g", "p", "h"]
    for row in range(2):
        for i in range(3):
            x = 6 + i * 10
            y = 3 + row * 11
            k = cols[row * 3 + i]
            c.set(x + 1, y, "K")
            c.rect(x + 1, y + 1, x + 1, y + 2, "a")
            c.rows(x, y + 3, [".kk.", "kkkk", "wwww", "kkkk", ".kk."], {"k": k})
    c.outline()
    return c


def specimen(variant):
    """鱼标本：木牌上钉着一条鱼。28×14。"""
    c = Canvas(28, 14)
    c.rect(1, 1, 26, 12, "O")
    c.rect(2, 2, 25, 11, "n")
    body, belly = ("s", "w") if variant == 0 else ("f", "y")
    c.ellipse(13, 7, 7.5, 3.2, body)
    c.rect(8, 8, 18, 9, belly)
    c.rows(19, 4, ["..f.", ".ff.", "fff.", ".ff.", "..f."][:5], {"f": body})
    c.set(8, 6, "K")
    c.pts([(10, 5), (12, 4), (14, 4)], "S" if variant == 0 else "F")
    c.pts([(3, 3), (24, 3), (3, 10), (24, 10)], "H")
    c.outline()
    return c


def barrel_rods():
    """木桶里插着几根钓竿。16×28。"""
    c = Canvas(16, 28)
    for pts, k in (([(4, 14), (4, 12), (3, 10), (3, 8), (2, 6), (2, 4), (1, 2)], "O"),
                   ([(8, 14), (8, 12), (8, 10), (8, 8), (9, 6), (9, 4), (9, 2)], "h"),
                   ([(11, 14), (11, 12), (12, 10), (12, 8), (13, 6), (13, 4), (14, 2)], "H")):
        c.pts(pts, k)
    c.pts([(1, 2), (9, 2), (14, 2)], "r")
    c.rect(1, 14, 14, 26, "o")
    c.rect(1, 14, 14, 15, "n")
    c.rect(1, 18, 14, 18, "O")
    c.rect(1, 23, 14, 23, "O")
    c.rect(1, 26, 14, 26, "O")
    c.rect(3, 15, 3, 25, "n")
    c.outline()
    return c


def bait_jars():
    """柜台边的饵料罐和小桶。20×14。"""
    c = Canvas(20, 14)
    c.rect(1, 3, 6, 11, "c"); c.rect(1, 2, 6, 2, "a")
    c.rows(2, 6, ["pp.p", ".pp.", "pp.p"], {"p": "p"})
    c.pts([(2, 4)], "W")
    c.rect(8, 3, 13, 11, "c"); c.rect(8, 2, 13, 2, "a")
    c.rows(9, 6, ["rr.r", ".rr.", "rr.r"], {"r": "r"})
    c.pts([(9, 4)], "W")
    c.rect(15, 6, 18, 11, "o"); c.rect(15, 5, 18, 5, "n"); c.rect(15, 9, 18, 9, "O")
    c.rect(1, 12, 18, 12, "n")
    c.outline()
    return c


def wall_hats():
    """墙上的帽子挂板：几顶帽子挂在木钉上。40×18。"""
    c = Canvas(40, 18)
    c.rect(1, 1, 38, 16, "O")
    c.rect(2, 2, 37, 15, "n")
    spec = [("h", "r", 4), ("b", "W", 14), ("g", "y", 24), ("r", "w", 33)]
    for body, band, x in spec:
        c.pts([(x + 2, 2)], "K")
        c.rect(x, 7, x + 5, 8, body)
        c.rect(x + 1, 4, x + 4, 6, body)
        c.rect(x + 1, 6, x + 4, 6, band)
        c.rect(x - 1, 9, x + 6, 9, "H" if body == "h" else body)
    c.outline()
    return c


def hat_stand():
    """立着的帽架，顶上戴着一顶帽子。14×28。"""
    c = Canvas(14, 28)
    c.rect(6, 10, 7, 24, "O")
    c.rect(2, 25, 11, 26, "o")
    c.rect(4, 24, 9, 24, "n")
    c.ellipse(7, 8, 2.6, 2.6, "w")
    c.rect(4, 5, 9, 6, "p")
    c.rows(3, 1, [".hhhhhh.", "hhhhhhhh", "hrrrrrrh", "HHHHHHHH"])
    c.rect(0, 5, 13, 5, "H")
    c.rect(1, 4, 12, 4, "h")
    c.outline()
    return c


def fabric_rolls():
    """叠着的布卷。24×16。"""
    c = Canvas(24, 16)
    for x0, y0, k, s in ((1, 8, "p", "R"), (8, 8, "c", "b"), (15, 8, "y", "H"), (4, 1, "g", "G"), (12, 1, "r", "R")):
        c.rect(x0, y0, x0 + 6, y0 + 5, k)
        c.rect(x0, y0 + 5, x0 + 6, y0 + 5, s)
        c.ellipse(x0 + 1, y0 + 3, 1.2, 2.2, "w")
    c.outline()
    return c


def deco_crate(kind):
    """摊位前的小木箱，里面放着各自的货。12×11。"""
    c = Canvas(12, 11)
    c.rect(0, 4, 11, 10, "o")
    c.rect(0, 4, 11, 5, "n")
    c.rect(0, 8, 11, 8, "O")
    c.rect(0, 4, 0, 10, "O"); c.rect(11, 4, 11, 10, "O")
    if kind == "fruit":
        for x, k in ((1, "r"), (4, "y"), (7, "r"), (9, "f")):
            c.rect(x, 1, x + 2, 3, k)
            c.set(x + 1, 0, "g")
    elif kind == "veg":
        c.rect(1, 0, 4, 3, "g"); c.rect(2, 1, 3, 2, "G")
        c.rect(6, 0, 7, 3, "f"); c.rect(9, 1, 10, 3, "f"); c.rect(6, 3, 10, 3, "g")
    elif kind == "bread":
        for x in (1, 5, 8):
            c.rect(x, 1, x + 3, 3, "h"); c.rect(x + 1, 1, x + 2, 1, "H")
    elif kind == "flower":
        for x, k in ((1, "p"), (4, "y"), (7, "w"), (9, "p")):
            c.rect(x, 1, x + 1, 2, k)
            c.set(x, 3, "g")
    else:                                    # fish：冰盒
        c.rect(0, 4, 11, 10, "c")
        c.rect(0, 4, 11, 5, "W")
        c.rect(0, 8, 11, 8, "b")
        c.rect(0, 4, 0, 10, "B"); c.rect(11, 4, 11, 10, "B")
        c.rows(1, 1, ["ss.ss.s", "SsKSsKS"][:2])
        c.pts([(1, 3), (4, 3), (7, 3)], "W")
    c.outline()
    return c


def deco_board(kind):
    """看板：小黑板立在摊位前，粉笔画着货。13×15。"""
    c = Canvas(13, 15)
    c.rect(1, 1, 11, 10, "o")
    c.rect(2, 2, 10, 9, "K")
    c.rect(2, 10, 3, 14, "O"); c.rect(9, 10, 10, 14, "O")
    ic = {"fruit": ("r", [".W.", "rrr", "rrr"]), "veg": ("g", ["gg.", "ggg", ".g."]),
          "bread": ("h", [".hh.", "hhhh"]), "flower": ("p", ["p.p", ".y.", "p.p"]),
          "fish": ("W", ["WW.W", "WKWW", "WW.W"])}[kind][1]
    colk = {"fruit": "r", "veg": "g", "bread": "h", "flower": "p", "fish": "c"}[kind]
    c.rows(3, 3, ic, {"r": colk, "g": colk, "h": colk, "p": colk, "y": "y", "W": "W"} if kind != "fish" else {"W": "W", "K": "K"})
    c.rect(3, 8, 9, 8, "W")
    c.outline()
    return c


def deco_nobori(kind):
    """招牌旗（のぼり）：细竹竿挂一面竖旗，旗上是各摊位的记号。10×34。"""
    c = Canvas(10, 34)
    flag = {"fruit": "r", "veg": "g", "bread": "y", "flower": "p", "fish": "b"}[kind]
    dark = {"fruit": "R", "veg": "G", "bread": "H", "flower": "R", "fish": "B"}[kind]
    c.rect(1, 1, 1, 32, "O")
    c.rect(1, 1, 7, 1, "O")
    c.rect(2, 2, 7, 25, flag)
    c.rect(2, 2, 2, 25, dark)
    for x in (3, 5, 7):
        c.rect(x, 26, x, 27, flag)
    icon = {"fruit": [".g.", "WWW", "WWW", ".W."], "veg": ["..W", ".WW", "WWW", ".W."], "bread": [".WW.", "WWWW", "WWWW"],
            "flower": ["W.W", ".W.", "W.W"], "fish": ["WWW.", "WKWW", "WWW."]}[kind]
    c.rows(3, 6, icon)
    c.rows(3, 14, ["W.W.W", ".W.W."])
    c.rect(3, 19, 6, 19, "W")
    c.outline()
    return c


def ishidoro():
    """石灯笼，立在市场口。12×18。"""
    c = Canvas(12, 18)
    c.rect(5, 7, 6, 15, "a")
    c.rect(2, 15, 9, 16, "A")
    c.rect(3, 7, 8, 8, "a")
    c.rect(3, 9, 8, 12, "y")
    c.rect(3, 9, 4, 12, "h")
    c.rect(2, 4, 9, 6, "a")
    c.rect(4, 2, 7, 3, "a")
    c.pts([(5, 1), (6, 1)], "A")
    c.outline()
    return c


def anger():
    """鸟偷了鱼以后小猫头上冒出的红色💢。11×11。"""
    c = Canvas(11, 11)
    c.rows(0, 0, ["rrr.....rrr", "rR.......Rr", "r.........r", "...........", "...........",
                  "...........", "...........", "...........", "r.........r", "rR.......Rr", "rrr.....rrr"])
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
    "自由挂机钓得更快", "稀有鱼更容易上钩", "咬钩等待更短", "咬钩速度", "鱼篓容量加二", "金币可以升级装备",
    "？？？", "共钓到", "今日", "累计", "近七日", "专注", "短休", "长休", "大小", "音效",
    "我的小猫", "给小猫选个样子", "完成",
    "方向键走动", "空格键互动", "空格键去小镇", "空格键去钓鱼", "市场", "鱼摊", "方向键划船", "空格键摆摊", "浅滩", "浅水区", "后台", "装备", "+1铜", "+1银", "+1金", "+10金", "钱清零", "任务全完成", "重置任务", "格子加四", "存钱罐加钱", "加一个", "拿走一个", "浪太大了", "小船过不去", "普通水域", "深水区", "水果", "蔬菜", "面包", "鲜花",
    "小猫的家", "裁缝铺", "渔具店", "空格键进入", "空格键聊天", "造船厂", "空格键升级船", "小木船", "加固船", "快桨船", "远洋船", "使用中", "先买前一级", "船出海更远", "能过浪区了",
    "确定要退出吗", "退出", "取消", "宝箱", "状态", "鱼线", "鱼钩", "树枝", "竹竿", "玻纤", "碳素", "合金", "金竿", "棉线", "铁钩", "空", "钓到", "面团", "装上", "空格键开始钓鱼", "仓库", "身上", "存入", "取出", "全部", "空格键开仓库", "装备", "未解锁", "最高纪录", "最大的鱼", "空军", "番茄", "分钟", "最忙的一天", "每月番茄", "当日专注", "暂无记录", "钓过的鱼", "天", "月", "时",
    "物品栏", "使用", "空空如也", "生效中", "去钓宝箱吧",
    "欢迎光临", "空格键出门", "空格键看货", "空格键照镜子", "空格键看图鉴", "空格键看统计", "空格键小睡", "Z", "真实天气", "开", "关", "休息时才能小睡", "已经睡饱了", "小猫睡得真香",
    "服装店", "空格键看衣帽", "行李满了", "送去了仓库", "钱包满了", "多的放进存钱罐", "存钱罐是空的", "存进存钱罐", "从存钱罐取出", "空格键存取钱", "存钱罐", "水太浅了", "不能钓鱼", "空格键上岸", "空格键和店主聊聊", "店主的心愿", "交付", "好", "银钩", "买下", "穿上", "穿着", "已有", "金币不够", "开发者模式", "帽子", "衣服",
    "任务", "暂无任务", "打开漂流瓶看看", "奖励", "进行中", "已完成", "挂机速度", "稀有鱼加成", "暂无加成", "大口袋", "金钩", "今天的鱼真新鲜", "听说金锦鲤很稀有", "专注时鱼更值钱", "别让小猫饿着了", "天气真好呀", "你的帽子真好看",
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
    bal = json.load(open(os.path.join(ROOT, "data", "balance.json"), encoding="utf-8"))
    for lines in bal.get("shop_chat", {}).values():
        for line in lines:
            if line not in names:
                names.append(line)
    for q in bal.get("quests", []):
        for k in ("letter_lines", "talk_lines", "idle_lines", "done_lines"):
            for line in q.get(k, []):
                if line not in names:
                    names.append(line)
    # 装备属性文字（和 core/game.gd 的 gear_stat 格式一致）
    base_wait = float(bal.get("upgrades", {}).get("rod", {}).get("free_wait_multipliers", [2.0])[0])
    for v in bal.get("upgrades", {}).get("rod", {}).get("free_wait_multipliers", []):
        names.append("+%d％" % int(round((base_wait / float(v) - 1.0) * 100.0)))
    for v in bal.get("hook_rarity_bonus", []):
        names.append("+%d％" % int(round(float(v) * 100.0)))
    for f in extra + cat_cfg["furs"] + cat_cfg["patterns"] + cat_cfg["hats"] + cat_cfg["outfits"] + items:
        for key in ("name", "desc"):
            if f.get(key) and f[key] not in names:
                names.append(f[key])
    font_ = ImageFont.truetype(FONT_FILE, 10)
    from fontTools.ttLib import TTFont
    cmap = TTFont(FONT_FILE).getBestCmap()
    rects, strips = {}, []
    for n in names:
        for ch in n:
            assert ord(ch) in cmap, f"字体里没有这个字（会显示成方框）: {ch} 出自 {n}"
        im = Image.new("L", (10 * len(n) + 4, 14), 0)
        d = ImageDraw.Draw(im); d.fontmode = "1"
        d.text((0, 0), n, font=font_, fill=255)
        box = im.getbbox()
        assert box and box[1] >= 2 and box[3] <= 12, f"标签渲染异常: {n} {box}"
        for i in range(len(n)):   # 每个字都必须真的画出了像素（防止缺字）；ASCII 字符是窄字形，按 10 像素切会错位，只查 cmap
            if not all(ord(c) > 127 for c in n):
                continue      # 含 ASCII 的标签是变宽字形，不能按 10 像素等分检查（cmap 已查过）
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
        "house_3": save(house("n", "o", "A", "a", w=52, door_x=22), "house_3"),
        "noren_ship": save(noren("ship"), "noren_ship"),
        "ship_model": save(ship_model(), "ship_model"),
        "blueprint": save(blueprint(), "blueprint"),
        "anchor": save(anchor(), "anchor"),
        "tree": save(tree(), "tree"),
        "stall_back": save(stall_back(), "stall_back"),
        "stall_front": save(stall_front(), "stall_front"),
        "gameboy": save(gameboy(), "gameboy"),
        "bubble": save(bubble(), "bubble"),
        "bird_fly": save(sheet([bird_fly(0), bird_fly(1)]), "bird_fly"),
        "bird_perch": save(bird_perch(), "bird_perch"),
        "boat_head": save(boat_head(), "boat_head"),
        "boat_basket_back": save(boat_basket_back(), "boat_basket_back"),
        "boat_basket": save(boat_basket(), "boat_basket"),
        "market_gate": save(market_gate(), "market_gate"),
        "stall_back_fruit": save(stall_back("y", "w", "H"), "stall_back_fruit"),
        "stall_back_veg": save(stall_back("g", "w", "G"), "stall_back_veg"),
        "stall_back_bread": save(stall_back("n", "w", "o"), "stall_back_bread"),
        "stall_back_flower": save(stall_back("p", "w", "R"), "stall_back_flower"),
        "bubble_sold": save(bubble_sold(), "bubble_sold"),
        "cloud": save(cloud(), "cloud"),
        "hills": save(hills(), "hills"),
        "fish_crucian": save(fish("s", "S", "w", "S"), "fish_crucian"),
        "fish_bass": save(fish("b", "B", "W", "B"), "fish_bass"),
        "fish_koi": save(fish("y", "f", "w", "r", spots=True), "fish_koi"),
        "fish_loach": save(fish("o", "O", "n", "O"), "fish_loach"),
        "fish_bream": save(fish("a", "A", "W", "A"), "fish_bream"),
        "fish_grass_carp": save(fish("g", "G", "w", "G"), "fish_grass_carp"),
        "fish_catfish": save(fish("A", "K", "a", "a"), "fish_catfish"),
        "fish_mandarin": save(fish("n", "o", "h", "R", spots=True), "fish_mandarin"),
        "fish_arowana": save(fish("W", "a", "p", "r"), "fish_arowana"),
        "tomato": save(tomato(), "tomato"),
        "coin": save(coin(), "coin"),
        "coin_silver": save(coin_of("a", "A", "W"), "coin_silver"),
        "coin_copper": save(coin_of("n", "O", "l"), "coin_copper"),
        "umbrella": save(umbrella(), "umbrella"),
        "piggy": save(piggy(), "piggy"),
        "basket": save(basket(), "basket"),
        "bobber": save(bobber(), "bobber"),
        "bang": save(bang(), "bang"),
        "tangle": save(tangle(), "tangle"),
        "anger": save(anger(), "anger"),
        "lantern": save(lantern(), "lantern"),
        "noren_tackle": save(noren("tackle"), "noren_tackle"),
        "noren_tailor": save(noren("tailor"), "noren_tailor"),
        "wall_clothes": save(wall_clothes(), "wall_clothes"),
        "mannequin": save(mannequin(), "mannequin"),
        "wall_bobbers": save(wall_bobbers(), "wall_bobbers"),
        "specimen_0": save(specimen(0), "specimen_0"),
        "specimen_1": save(specimen(1), "specimen_1"),
        "barrel_rods": save(barrel_rods(), "barrel_rods"),
        "bait_jars": save(bait_jars(), "bait_jars"),
        "wall_hats": save(wall_hats(), "wall_hats"),
        "hat_stand": save(hat_stand(), "hat_stand"),
        "fabric_rolls": save(fabric_rolls(), "fabric_rolls"),
        "ishidoro": save(ishidoro(), "ishidoro"),
        "deco_crate_fruit": save(deco_crate("fruit"), "deco_crate_fruit"),
        "deco_board_fruit": save(deco_board("fruit"), "deco_board_fruit"),
        "deco_nobori_fruit": save(deco_nobori("fruit"), "deco_nobori_fruit"),
        "deco_crate_veg": save(deco_crate("veg"), "deco_crate_veg"),
        "deco_board_veg": save(deco_board("veg"), "deco_board_veg"),
        "deco_nobori_veg": save(deco_nobori("veg"), "deco_nobori_veg"),
        "deco_crate_bread": save(deco_crate("bread"), "deco_crate_bread"),
        "deco_board_bread": save(deco_board("bread"), "deco_board_bread"),
        "deco_nobori_bread": save(deco_nobori("bread"), "deco_nobori_bread"),
        "deco_crate_flower": save(deco_crate("flower"), "deco_crate_flower"),
        "deco_board_flower": save(deco_board("flower"), "deco_board_flower"),
        "deco_nobori_flower": save(deco_nobori("flower"), "deco_nobori_flower"),
        "deco_crate_fish": save(deco_crate("fish"), "deco_crate_fish"),
        "deco_board_fish": save(deco_board("fish"), "deco_board_fish"),
        "deco_nobori_fish": save(deco_nobori("fish"), "deco_nobori_fish"),
        "storage": save(storage(), "storage"),
        "lock": save(lock(), "lock"),
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
    for k in ("bottle", "lucky_bait", "bell", "map_piece", "pearl", "boot", "bait_worm", "bait_shrimp", "rod", "line", "hook"):
        made["item_" + k] = save(item_icon(k), "item_" + k)
    for k in ("fruit", "veg", "bread", "flower"):
        made["goods_" + k] = save(goods(k), "goods_" + k)
        made["ico_" + k] = save(goods_icon(k), "ico_" + k)
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

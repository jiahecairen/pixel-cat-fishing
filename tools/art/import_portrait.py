"""把用户提供的主角立绘（tools/art/source/hero_portrait.png，背景已去掉）缩成游戏用的像素图。

源图不是严格的像素网格（AI 生成），所以按面积平均缩小，再统一聚成 20 色，透明度二值化。
输出：
- assets/cat/portrait_bust.png  半身像（头到腰带），对话框用
主角颜色来自用户原画，不在 24 色调色板里（同 D152）。
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "tools", "art", "source", "hero_portrait.png")
OUT = os.path.join(ROOT, "assets", "cat")
COLORS = 32


def _shrink(im, box, w):
    c = im.crop(box)
    h = round(c.height * w / c.width)
    a = np.array(c).astype(float)
    out = np.zeros((h, w, 4))
    sx, sy = c.width / w, c.height / h
    for j in range(h):
        for i in range(w):
            blk = a[int(j * sy):max(int(j * sy) + 1, int((j + 1) * sy)), int(i * sx):max(int(i * sx) + 1, int((i + 1) * sx))].reshape(-1, 4)
            op = blk[:, 3] > 128
            if op.mean() >= 0.5:
                out[j, i, :3] = np.median(blk[op, :3], axis=0)
                out[j, i, 3] = 255
    return out


def _quantize(imgs):
    px = np.concatenate([f[f[..., 3] > 0][:, :3] for f in imgs])
    rng = np.random.default_rng(0)
    cen = px[rng.choice(len(px), COLORS, replace=False)]
    for _ in range(30):
        lab = ((px[:, None, :] - cen[None]) ** 2).sum(2).argmin(1)
        for k in range(COLORS):
            if (lab == k).any():
                cen[k] = px[lab == k].mean(0)
    cen = cen.round()
    for f in imgs:
        m = f[..., 3] > 0
        lab = ((f[m][:, :3][:, None, :] - cen[None]) ** 2).sum(2).argmin(1)
        f[m, :3] = cen[lab]


def _outline(f):
    """透明处紧挨着不透明像素的地方描一圈深色边，缩小后轮廓更清楚。"""
    a = f[..., 3] > 0
    n = np.zeros_like(a)
    n[1:] |= a[:-1]; n[:-1] |= a[1:]; n[:, 1:] |= a[:, :-1]; n[:, :-1] |= a[:, 1:]
    edge = n & ~a
    out = np.zeros((f.shape[0] + 0, f.shape[1], 4))
    out[...] = f
    out[edge, :3] = (43, 33, 55)
    out[edge, 3] = 255
    return out


def build():
    im = Image.open(SRC).convert("RGBA")
    bust = _shrink(im, (13, 19, 299, 360), 60)
    _quantize([bust])
    bust = _outline(bust)
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(bust.astype(np.uint8), "RGBA").save(os.path.join(OUT, "portrait_bust.png"))
    return bust.shape


if __name__ == "__main__":
    print(build())

"""把用户提供的主角走路图（放大过的像素画，tools/art/source/hero_walk.png）还原成游戏用的原生像素帧。

源图每个美术像素约 10×10 屏幕像素，背景透明。做法：
1. 按不透明列把 8 帧切开；
2. 每帧以头部中心对齐（走路时头不应左右晃），按 10 像素一格取格子中心区域的中位色；
3. 全部帧统一聚成 18 色，去掉压缩噪点；
4. 输出 assets/cat/hero.png：8 帧横排，每帧 28×35。

主角的颜色来自用户的原画，不在 24 色调色板里（见 DECISION_REGISTER D152）。
"""
import os
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "tools", "art", "source", "hero_walk.png")
OUT = os.path.join(ROOT, "assets", "cat", "hero.png")
CELL = 10.0
FW, FH = 28, 35
HEAD_COL = 15.5      # 头部中心落在第几列
COLORS = 18


def _runs(mask):
    cols = mask.sum(0)
    runs, start = [], None
    for x, v in enumerate(cols):
        if v > 3 and start is None:
            start = x
        elif v <= 3 and start is not None:
            if x - start > 60:
                runs.append((start, x))
            start = None
    return runs


def build():
    im = np.array(Image.open(SRC).convert("RGBA")).astype(float)
    opaque = im[..., 3] > 128
    rows = np.where(opaque.sum(1) > 3)[0]
    y0 = rows.min()
    head_band = (y0, y0 + 130)
    frames = []
    for x0, x1 in _runs(opaque):
        ys, xs = np.where(opaque[head_band[0]:head_band[1], x0:x1])
        ox = x0 + xs.mean() - HEAD_COL * CELL
        out = np.zeros((FH, FW, 4))
        for j in range(FH):
            for i in range(FW):
                cx, cy = ox + (i + 0.5) * CELL, y0 + (j + 0.5) * CELL
                xa, xb, ya, yb = int(cx - 3), int(cx + 4), int(cy - 3), int(cy + 4)
                if xa < x0 - 5 or xb > x1 + 5 or ya < 0:
                    continue
                blk = im[ya:yb, xa:xb].reshape(-1, 4)
                a = blk[:, 3] > 128
                if len(blk) and a.mean() > 0.5:
                    out[j, i, :3] = np.median(blk[a, :3], axis=0)
                    out[j, i, 3] = 255
        frames.append(out)
    px = np.concatenate([f[f[..., 3] > 0][:, :3] for f in frames])
    rng = np.random.default_rng(0)
    cen = px[rng.choice(len(px), COLORS, replace=False)]
    for _ in range(40):
        lab = ((px[:, None, :] - cen[None]) ** 2).sum(2).argmin(1)
        for k in range(COLORS):
            if (lab == k).any():
                cen[k] = px[lab == k].mean(0)
    cen = cen.round()
    for f in frames:
        m = f[..., 3] > 0
        lab = ((f[m][:, :3][:, None, :] - cen[None]) ** 2).sum(2).argmin(1)
        f[m, :3] = cen[lab]
    sheet = np.zeros((FH, FW * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        sheet[:, i * FW:(i + 1) * FW] = f
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(OUT)
    return len(frames)


if __name__ == "__main__":
    print("hero frames:", build())

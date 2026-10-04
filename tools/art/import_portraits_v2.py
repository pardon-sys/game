"""第二版立绘导入：蓝色公主的立绘 / 头像、三个关键人物的新立绘（白底大图）→ 像素立绘（2 倍像素密度）。

源图（保持不动）：
  blue_princess/portraits_blue1.png  普通 开心 哭泣 惊讶 生气 害羞
  blue_princess/portraits_blue2.png  战损 憋笑 战损憋笑 失控一 失控二
  blue_princess/portraits_blue3.png  战损魔法：战损吟诵 战损释放 战损憋笑吟诵 战损释放（第二种）战损憋笑释放
  blue_princess/战损.png、普通憋笑.png、战损憋笑.png、失控1.png、失控2.png、魔法吟诵.png、魔法释放.png、战损魔法吟诵.png、
    战损魔法憋笑吟诵.png、战损魔法释放.png  后来单独给的立绘，覆盖上面图集里的同名状态（BLUE_SINGLE）
  npc_portraits/银白圣徽骑士统帅.png / 猩红秘典与羽饰贵妇.png / 火焰灯笼祭典少女.png  队长 / 市场监督 / 篝火派对的主人（全身）
输出（assets/generated/）：
  portraits_blue.png / portrait_heads_blue.png  和公主的 portraits.png / portrait_heads.png 同样的 17 格顺序（11 种状态 + 6 种魔法）
  npc_portraits/captain.png、supervisor.png、bonfire_host.png  半身（头到腰）像素立绘，228x304
取景和头像框在 data/actors/blue_visuals.json（蓝色公主）和下面的 NPC 表里调。
用法：python tools/art/import_portraits_v2.py [--preview]
"""
import json
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

from import_princess2 import EMOTIONS, HEAD, MAGIC, OUT, PORTRAIT_CELL, ROOT, VISUALS, Pixelizer, body_bbox
from import_sprites_v2 import _even_cuts

BLUE_META = json.loads((ROOT / "data/actors/blue_visuals.json").read_text())
PREVIEW = ROOT / "tools/.cache/sprites_v2"
BLUE_SOURCES = [
    ("blue_princess/portraits_blue1.png", ["normal", "happy", "sad", "surprise", "angry", "shy"]),
    ("blue_princess/portraits_blue2.png", ["damaged", "giggle", "damaged_giggle", "helpless_1", "helpless_2"]),
    ("blue_princess/portraits_blue3.png", ["b3_chant", "b3_burst", "b3_giggle_chant", "b3_burst2", "b3_giggle_burst"]),
]
# 用户后来单独给的立绘（每张一个人，白底），覆盖图集里的同名状态
BLUE_SINGLE = {"damaged": "战损.png", "giggle": "普通憋笑.png", "damaged_giggle": "战损憋笑.png", "helpless_1": "失控1.png",
               "helpless_2": "失控2.png", "chant": "魔法吟诵.png", "burst": "魔法释放.png", "damaged_chant": "战损魔法吟诵.png",
               "damaged_giggle_chant": "战损魔法憋笑吟诵.png", "damaged_burst": "战损魔法释放.png"}
# 魔法 6 种 ← 第三张的 5 张（全是战损魔法；普通吟诵 / 释放用战损吟诵 / 第二种战损释放）
BLUE_MAGIC = {"chant": "b3_chant", "burst": "b3_burst2", "damaged_chant": "b3_chant", "damaged_burst": "b3_burst",
              "damaged_giggle_chant": "b3_giggle_chant", "damaged_giggle_burst": "b3_giggle_burst"}
# NPC：源图、半身取到人物高度的多少（头到腰）、横向中心偏移（相对取景宽度）；
# cx 写了就直接用它当取景中心（占原图宽度的比例）——篝火派对的主人举着的灯笼会把自动算的头部中心拉偏到右边
NPCS = {
    "captain": {"src": "npc_portraits/银白圣徽骑士统帅.png", "waist": 0.40, "dx": 0.0},
    "supervisor": {"src": "npc_portraits/猩红秘典与羽饰贵妇.png", "waist": 0.40, "dx": 0.0},
    "bonfire_host": {"src": "npc_portraits/火焰灯笼祭典少女.png", "waist": 0.42, "dx": 0.0, "cx": 0.44},
}


def key_white(rgb):
    """和图片边缘连通的白底设为透明（眼白、白裙子的高光保留）。"""
    bg = rgb.min(2) > 232
    lab, n = ndimage.label(bg)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    alpha = np.where(np.isin(lab, list(border)), 0, 255).astype(np.uint8)
    # 去掉孤立的小碎块（压缩噪点）
    fl, fn = ndimage.label(alpha > 0, structure=np.ones((3, 3)))
    if fn:
        sizes = ndimage.sum(np.ones_like(fl), fl, range(1, fn + 1))
        for i, s in enumerate(sizes, 1):
            if s < 40:
                alpha[fl == i] = 0
    return Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")


def split_figures(path, n):
    img = Image.open(OUT / path).convert("RGB")
    rgb = np.asarray(img).astype(np.int32)
    mask = ndimage.binary_opening(rgb.min(2) < 225, iterations=1)
    occ = mask.sum(0)
    xs = np.where(occ > 2)[0]
    cuts = _even_cuts(occ, int(xs[0]), int(xs[-1]) + 1, [1] * n, window=0.3)
    figs = []
    for i in range(n):
        part = key_white(rgb[:, cuts[i]:cuts[i + 1]].astype(np.uint8))
        x0, y0, x1, y1 = body_bbox(part)
        m = round(0.04 * (y1 - y0))
        figs.append(part.crop((max(0, x0 - m), max(0, y0 - m), min(part.width, x1 + m), min(part.height, y1 + m))))
    return figs


def single_figure(path):
    """单张立绘：白底抠掉，按人物外框裁好（四周留一点边）。"""
    rgb = np.asarray(Image.open(OUT / path).convert("RGB")).astype(np.uint8)
    full = key_white(rgb)
    x0, y0, x1, y1 = body_bbox(full)
    m = round(0.03 * (y1 - y0))
    return full.crop((max(0, x0 - m), max(0, y0 - m), min(full.width, x1 + m), min(full.height, y1 + m)))


def head_box(name):
    return BLUE_META.get("head_boxes", {}).get(name, [0.18, 0.0, 0.82, 0.42])


def build_blue():
    figures = {}
    for path, names in BLUE_SOURCES:
        for name, f in zip(names, split_figures(path, len(names))):
            figures[name] = f
    for name, src in BLUE_MAGIC.items():
        figures[name] = figures[src]
    for name, f in BLUE_SINGLE.items():
        figures[name] = single_figure("blue_princess/" + f)
    heads_src = {}
    for name in VISUALS:
        f = figures[name]
        hb = head_box(name)
        heads_src[name] = f.crop(tuple(round(v * (f.width if j % 2 == 0 else f.height)) for j, v in enumerate(hb)))
    pxs = {}
    for group in (list(EMOTIONS), list(MAGIC)):
        px = Pixelizer([figures[n] for n in group] + [heads_src[n] for n in group], 128,
                       [head_box(n) for n in group] + [[0, 0, 1, 1]] * len(group))
        for n in group:
            pxs[n] = px
    cw, ch = PORTRAIT_CELL
    sheet = Image.new("RGBA", (cw * len(VISUALS), ch))
    heads = Image.new("RGBA", (HEAD * len(VISUALS), HEAD))
    for i, name in enumerate(VISUALS):
        px, f = pxs[name], figures[name]
        small = px(f, min((ch - 4) / f.height, (cw - 4) / f.width), head_box(name), sharpen=(1.0, 60))
        sheet.alpha_composite(small, (i * cw + (cw - small.width) // 2, ch - small.height))
        hs = heads_src[name]
        h = px(hs, min((HEAD - 4) / hs.width, (HEAD - 4) / hs.height), [0, 0, 1, 1], sharpen=(1.0, 60))
        heads.alpha_composite(h, (i * HEAD + (HEAD - h.width) // 2, (HEAD - h.height) // 2))
    sheet.save(OUT / "portraits_blue.png")
    heads.save(OUT / "portrait_heads_blue.png")
    return sheet


def build_npcs():
    cw, ch = PORTRAIT_CELL
    out = {}
    for npc, cfg in NPCS.items():
        rgb = np.asarray(Image.open(OUT / cfg["src"]).convert("RGB")).astype(np.uint8)
        full = key_white(rgb)
        x0, y0, x1, y1 = body_bbox(full)
        bh = y1 - y0
        top, bottom = max(0, y0 - round(0.01 * bh)), y0 + round(cfg["waist"] * bh)
        # 横向以头部为中心（人物最上面 12% 的不透明像素的平均位置）
        a = np.asarray(full.getchannel("A"))[y0:y0 + round(0.12 * bh)] > 0
        cx = int(np.where(a)[1].mean()) if a.any() else (x0 + x1) // 2
        if "cx" in cfg:
            cx = round(cfg["cx"] * full.width)
        w = round((bottom - top) * cw / ch)
        cx += round(cfg["dx"] * w)
        left = max(0, min(full.width - w, cx - w // 2))
        crop = full.crop((left, top, left + w, bottom))
        face = [0.25, 0.0, 0.75, 0.42]
        px = Pixelizer([crop], 128, [face])
        small = px(crop, min((ch - 4) / crop.height, (cw - 4) / crop.width), face, sharpen=(1.0, 60))
        cell = Image.new("RGBA", (cw, ch))
        cell.alpha_composite(small, ((cw - small.width) // 2, ch - small.height))
        cell.save(OUT / "npc_portraits" / (npc + ".png"))
        out[npc] = cell
    return out


def preview(sheet, npcs):
    PREVIEW.mkdir(parents=True, exist_ok=True)
    bg = Image.new("RGBA", (sheet.width // 2, sheet.height // 2 + 20), (110, 120, 130, 255))
    bg.alpha_composite(sheet.resize((sheet.width // 2, sheet.height // 2), Image.NEAREST), (0, 20))
    d = ImageDraw.Draw(bg)
    for i, n in enumerate(VISUALS):
        d.text((i * PORTRAIT_CELL[0] // 2 + 4, 4), n, fill=(255, 255, 255))
    bg.save(PREVIEW / "portraits_blue.png")
    row = Image.new("RGBA", (PORTRAIT_CELL[0] * len(npcs), PORTRAIT_CELL[1]), (110, 120, 130, 255))
    for i, im in enumerate(npcs.values()):
        row.alpha_composite(im, (i * PORTRAIT_CELL[0], 0))
    row.save(PREVIEW / "npc_portraits.png")


def main():
    sheet = build_blue()
    npcs = build_npcs()
    if "--preview" in sys.argv:
        preview(sheet, npcs)
    print("立绘：蓝色公主 %d 张，关键人物 %d 张" % (len(VISUALS), len(npcs)))


if __name__ == "__main__":
    main()

"""鼠鼠装（反省篇：鼠鼠短裤 + 鼠爪鞋，诅咒装备）的美术：粉色公主穿着它时的立绘 / 行走图 / 魔法图。原图一张都不动，多写一份 *_mouse。

造型定稿：tools/art/src/mouse_outfit/mouse_concept.png（灰色毛绒短裤从裙摆下露出一点、粉色细尾巴、露脚趾的鼠脸拖鞋、腰头探出挠脚鼠）。
立绘（17 种，顺序同 portraits.json）：
  --refs     把 import_princess2.build_portraits 用的高清人物（白底）导出到 src/mouse_outfit/ref_<状态>.png（给 codex 当参考）
  （codex：prompts.md 里的提示词，每张 ref_<状态>.png → mouse_<状态>.png，只改腿和脚）
  默认       读 mouse_<状态>.png（没有的退回原图），按同样的像素化 → assets/generated/portraits_mouse.png
行走图 / 魔法图（princess.png、princess_hd.png、princess_magic.png、princess_magic_hd.png → 同名 *_mouse）：程序重画，
  每格找到裙摆下面露出来的腿：白色长筒袜 → 皮肤色，红鞋 → 灰色毛绒拖鞋（粉色肉垫、两只小耳朵），裙摆下沿一圈灰色绒毛（短裤），身后一条粉色细尾巴。
  已经光着脚的格子（失控一 / 失控二倒在地上）不画袜子鞋子，只加尾巴。
用法：python tools/art/import_mouse_outfit.py [--refs] [--sprites-only] [--preview]
"""
import sys

import numpy as np
from PIL import Image, ImageDraw

import import_princess2 as p2
from palette import OUT, ROOT

SRC = ROOT / "tools/art/src/mouse_outfit"
PREVIEW = ROOT / "tools/.cache/mouse_outfit"


def hd_figures():
    figures = {}
    for filename, names, key in (("portraits2.png", p2.PORTRAIT2_ORDER, "portraits2"), ("portraits3.png", p2.EXTRA_STATES, "portraits3")):
        path = OUT / filename
        edges = p2.split_figures(path, len(names), p2.FALLBACK[key])
        source = Image.open(path)
        for i, name in enumerate(names):
            figures[name] = p2.cut(source, (edges[i], 0, edges[i + 1], source.height))
    figures.update(p2.magic_portrait_figures())
    return figures


def export_refs():
    SRC.mkdir(parents=True, exist_ok=True)
    for name, f in hd_figures().items():
        bg = Image.new("RGB", (f.width + 40, f.height + 40), "white")
        bg.paste(f, (20, 20), f)
        bg.save(SRC / ("ref_%s.png" % name))
    print("参考图：", len(p2.VISUALS))


def mouse_figure(name, fallback):
    path = SRC / ("mouse_%s.png" % name)
    if not path.exists():
        return fallback, False
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.uint8)
    full = p2.Image.fromarray(np.dstack([rgb, np.where(_bg_mask(rgb), 0, 255).astype(np.uint8)]), "RGBA")
    x0, y0, x1, y1 = p2.body_bbox(full)
    return full.crop((x0, y0, x1, y1)), True


def _bg_mask(rgb):
    from scipy import ndimage
    bg = rgb.min(2) > 232
    lab, _ = ndimage.label(bg)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    return np.isin(lab, list(border))


def build_portraits():
    base = hd_figures()
    figures, done = {}, []
    for name in p2.VISUALS:
        figures[name], ok = mouse_figure(name, base[name])
        if ok:
            done.append(name)
    heads_src = {}
    for name in p2.VISUALS:
        f, hb = figures[name], p2.head_box(name)
        heads_src[name] = f.crop(tuple(round(v * (f.width if j % 2 == 0 else f.height)) for j, v in enumerate(hb)))
    pxs = {}
    for group in (list(p2.EMOTIONS), list(p2.MAGIC)):
        px = p2.Pixelizer([figures[n] for n in group] + [heads_src[n] for n in group], 128,
                          [p2.head_box(n) for n in group] + [[0, 0, 1, 1]] * len(group))
        for n in group:
            pxs[n] = px
    cw, ch = p2.PORTRAIT_CELL
    sheet = Image.new("RGBA", (cw * len(p2.VISUALS), ch))
    for i, name in enumerate(p2.VISUALS):
        f = figures[name]
        small = pxs[name](f, min((ch - 4) / f.height, (cw - 4) / f.width), p2.head_box(name), sharpen=(1.0, 60))
        sheet.alpha_composite(small, (i * cw + (cw - small.width) // 2, ch - small.height))
    sheet.save(OUT / "portraits_mouse.png")
    print("鼠鼠装立绘：%d / %d 张换了（缺的用原图）" % (len(done), len(p2.VISUALS)), [n for n in p2.VISUALS if n not in done])
    return sheet


# ------------------------------------------------------------------ 行走图 / 魔法图：程序重画
FEET_ZONE = 0.28
SHOE_ZONE = 0.09
SKIN = np.array([252, 222, 200])
SKIN_D = np.array([240, 188, 172])
FUR = np.array([168, 166, 178])
FUR_D = np.array([120, 118, 134])
FUR_L = np.array([205, 203, 214])
PAD = np.array([255, 170, 200])
TAIL = np.array([240, 160, 185])


def _hsv(rgb):
    r, g, b = [rgb[..., i].astype(np.float32) / 255.0 for i in range(3)]
    mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return mx, s


def _narrow(mask, max_w):
    """每一行只留窄的一段一段（袜子是竖着的细条；裙子下摆的蕾丝、侧面裙下那一大片白是宽的）"""
    keep = np.zeros_like(mask)
    for y in np.where(mask.any(1))[0]:
        row = mask[y]
        x = 0
        n = len(row)
        while x < n:
            if row[x]:
                e = x
                while e < n and row[e]:
                    e += 1
                if e - x <= max_w:
                    keep[y, x:e] = True
                x = e
            else:
                x += 1
    return keep


def _bezier(p0, p1, p2, n=16):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])
            for t in [i / n for i in range(n + 1)]]


def repaint_cell(cell, bare=False):
    """一格：脚下那一截（人物下面 FEET_ZONE）里的白袜 → 光腿、红鞋 → 灰色鼠拖鞋（小耳朵、粉肉垫）；身后一条粉色细尾巴。
    这一截里没有红鞋的格子（失控倒在地上、本来就光着脚）不动袜鞋，只加尾巴。"""
    a = np.asarray(cell).copy()
    alpha = a[..., 3] > 40
    if alpha.sum() < 20:
        return cell
    ys, _ = np.where(alpha)
    y0, y1 = ys.min(), ys.max()
    v, s = _hsv(a[..., :3])
    rows = np.arange(a.shape[0])[:, None]
    # 脚下的影子（不透明的灰色椭圆）不算人
    shadow = alpha & (rows >= y1 - (y1 - y0) * 0.14) & (s < 0.12) & (v > 0.5) & (v < 0.9)
    body = alpha & ~shadow
    ys, xs = np.where(body)
    y0, y1 = ys.min(), ys.max()
    h = y1 - y0 + 1
    rgb = a[..., :3].astype(np.int32)
    zone = body & (rows >= y1 - h * FEET_ZONE)
    feet = body & (rows >= y1 - h * SHOE_ZONE)
    red = feet & (s > 0.35) & (rgb[..., 0] > rgb[..., 2] + 30) & (rgb[..., 0] > 150)
    white = zone & (v > 0.62) & (s < 0.2)
    white = _narrow(white, max(3, int((xs.max() - xs.min()) * 0.16)))
    out = a.copy()
    legs_x = None
    if red.sum() >= 3 and not bare:
        shade = np.clip((v - 0.62) / 0.38, 0, 1)[..., None]
        skin = (SKIN_D * (1 - shade) + SKIN * shade).astype(np.uint8)
        out[..., :3] = np.where(white[..., None], skin, out[..., :3])
        fv = np.clip((v - 0.45) / 0.55, 0, 1)[..., None]
        fur = (FUR_D * (1 - fv) + FUR_L * fv).astype(np.uint8)
        out[..., :3] = np.where(red[..., None], fur, out[..., :3])
        ry, rx = np.where(red)
        unit = max(1, round(h / 70))
        # 拖鞋：每只鞋（按 x 分成左右两团）鞋面上两只小耳朵、鞋头一点粉色
        mid = (rx.min() + rx.max()) / 2
        for side in (rx < mid, rx >= mid) if rx.max() - rx.min() > 3 * unit else (rx >= 0,):
            if not side.any():
                continue
            sx, sy = rx[side], ry[side]
            top = sy.min()
            for ex in (sx.min() + unit, sx.max() - unit):
                out[max(0, top - unit):top, max(0, ex - unit // 2):ex + unit // 2 + 1, :3] = FUR_D
                out[max(0, top - unit):top, max(0, ex - unit // 2):ex + unit // 2 + 1, 3] = 255
            tip = sy.max()
            cx = int(sx.mean())
            out[max(0, tip - unit):tip + 1, max(0, cx - unit):cx + unit + 1, :3] = np.where(
                red[max(0, tip - unit):tip + 1, max(0, cx - unit):cx + unit + 1, None], PAD, out[max(0, tip - unit):tip + 1, max(0, cx - unit):cx + unit + 1, :3])
        legs_x = (int(rx.min()), int(rx.max()))
    img = Image.fromarray(out, "RGBA")
    # 尾巴：从腿边（脚踝上面一点）伸出来，贴着地面往外弯，尾巴尖翘起来；画在人物外面（身后）
    if legs_x is None:
        zx = np.where(zone.any(0))[0]
        legs_x = (int(zx.min()), int(zx.max())) if len(zx) else (int(xs.min()), int(xs.max()))
    side = 1 if (legs_x[0] + legs_x[1]) / 2 <= cell.width / 2 else -1
    sx = legs_x[1] if side > 0 else legs_x[0]
    sy = y1 - int(h * 0.16)
    L = h * 0.13
    pts = _bezier((sx - side * L * 0.2, sy), (sx + side * L * 0.9, sy + L * 0.9), (sx + side * L * 1.1, sy - L * 0.15))
    tw = max(1, round(h / 55))
    tail = Image.new("RGBA", img.size, (0, 0, 0, 0))
    td = ImageDraw.Draw(tail)
    if tw > 1:
        td.line(pts, fill=(110, 50, 70, 255), width=tw + 2, joint="curve")
    td.line(pts, fill=(*TAIL, 255), width=tw, joint="curve")
    ta = np.asarray(tail).copy()
    ta[body, 3] = 0
    return Image.alpha_composite(img, Image.fromarray(ta, "RGBA"))


## 行走图里本来就光着脚、倒在地上的行（失控一 / 失控二）：不动袜鞋，只加尾巴
BARE_ROWS = {"princess_hd.png": {9, 10}, "princess.png": {9, 10}}


def repaint_sheet(src, dst, cell):
    im = Image.open(OUT / src).convert("RGBA")
    out = Image.new("RGBA", im.size)
    cols, rows = im.width // cell, im.height // cell
    for r in range(rows):
        for c in range(cols):
            box = (c * cell, r * cell, c * cell + cell, r * cell + cell)
            out.alpha_composite(repaint_cell(im.crop(box), r in BARE_ROWS.get(src, set())), box[:2])
    out.save(OUT / dst)
    return out


SHEETS = [("princess_hd.png", "princess_mouse_hd.png", 256), ("princess.png", "princess_mouse.png", 32),
          ("princess_magic_hd.png", "princess_magic_mouse_hd.png", None), ("princess_magic.png", "princess_magic_mouse.png", 48)]


def build_sprites():
    for src, dst, cell in SHEETS:
        if cell is None:
            im = Image.open(OUT / src)
            small = Image.open(OUT / src.replace("_hd", ""))
            cell = round(48 * im.width / small.width)
        repaint_sheet(src, dst, cell)
        print("鼠鼠装精灵：", dst, cell)


def preview():
    PREVIEW.mkdir(parents=True, exist_ok=True)
    a = Image.open(OUT / "princess_hd.png")
    b = Image.open(OUT / "princess_mouse_hd.png")
    cells = [(0, 0), (0, 4), (0, 8), (0, 12), (7, 0), (9, 0), (10, 4), (6, 0)]
    out = Image.new("RGBA", (256 * len(cells), 512), (70, 60, 80, 255))
    for i, (r, c) in enumerate(cells):
        box = (c * 256, r * 256, c * 256 + 256, r * 256 + 256)
        out.alpha_composite(a.crop(box), (i * 256, 0))
        out.alpha_composite(b.crop(box), (i * 256, 256))
    out.save(PREVIEW / "sprites.png")


def main():
    if "--refs" in sys.argv:
        export_refs()
        return
    build_sprites()
    if "--sprites-only" not in sys.argv:
        build_portraits()
    if "--preview" in sys.argv:
        preview()


if __name__ == "__main__":
    main()

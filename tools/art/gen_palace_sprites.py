"""旧王宫的新素材（codex 画的白底大图 → 游戏里的像素图；提示词 tools/art/src/palace_sprites/prompts.md）：
  doll_maid_sheet.png    → assets/generated/npcs/doll_maid.png   人偶女仆，4x4 格、每格 32x32（同 npcs/guard.png 的排法：下 / 左 / 右 / 上 各 4 帧）
  palace_statue_sheet.png → assets/generated/palace_statue.png   浴场雕像，3 帧横排、每帧 32x48（站着 / 发光预警 / 弯腰刷）
  clock_keeper_sheet.png → assets/generated/npcs/clock_keeper.png  守钟人偶，4x4 格、每格 32x32（同人偶女仆）
  portrait_boss_sheet.png → assets/generated/portrait_boss.png     王座间的大画像，3 帧横排、每帧 64x88（完好 / 裂开伸手 / 烧穿）
  small_portrait_sheet.png → assets/generated/small_portrait.png   墙上的小画像，2 帧横排、每帧 28x36（睡着 / 醒了伸手）
  exit_markers_sheet.png → assets/generated/exit_markers.png       反省篇出口标记，5 帧、每帧 40x40（上楼梯 / 下楼梯 / 门 / 墙洞 / 梯子）
  clock_props_sheet.png → assets/generated/clock_props.png         钟楼道具，6 帧、每帧 48x56（齿轮 / 钟摆 / 风箱 / 钟 / 钟绳 / 宝箱）
  palace_misc_sheet.png → assets/generated/palace_misc.png         仆人回廊，3 帧、每帧 24x32（唤人铃 / 钥匙 / 小牌子）
  head_maid_sheet.png → assets/generated/npcs/head_maid.png        女仆长，4x4 格、每格 32x32
做法：白底抠掉（和边缘连通的白）→ 按格子切 → 每格取最大的人物块 → 等比缩到格子里（脚底对齐底边）→ 减色 + 1px 深色描边。
用法：python tools/art/gen_palace_sprites.py
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "tools/art/src/palace_sprites"
OUT = ROOT / "assets/generated"
OUTLINE = (34, 22, 36, 255)


def key_white(img):
    rgb = np.asarray(img.convert("RGB")).astype(np.int32)
    bg = rgb.min(2) > 225
    lab, _ = ndimage.label(bg)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    alpha = np.where(np.isin(lab, list(border)), 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb.astype(np.uint8), alpha]), "RGBA")


def biggest(cell):
    a = np.asarray(cell.getchannel("A")) > 0
    lab, n = ndimage.label(a, structure=np.ones((3, 3)))
    if n == 0:
        return cell
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    keep = sizes >= sizes.max() * 0.08
    mask = np.isin(lab, [i + 1 for i in range(n) if keep[i]])
    ys, xs = np.where(mask)
    out = np.asarray(cell).copy()
    out[..., 3] = np.where(mask, out[..., 3], 0)
    return Image.fromarray(out, "RGBA").crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def _shrink(fig, s):
    """面积平均缩小（预乘 alpha，边缘不发白）+ 稍微提一点饱和度和对比（缩小以后颜色容易发灰）"""
    from PIL import ImageEnhance
    a = np.asarray(fig).astype(np.float32)
    pm = a.copy()
    pm[..., :3] *= a[..., 3:4] / 255.0
    size = (max(1, round(fig.width * s)), max(1, round(fig.height * s)))
    small = np.asarray(Image.fromarray(pm.astype(np.uint8), "RGBA").resize(size, Image.BOX)).astype(np.float32)
    al = small[..., 3:4]
    small[..., :3] = np.where(al > 0, small[..., :3] * 255.0 / np.maximum(al, 1), 0)
    img = Image.fromarray(np.clip(small, 0, 255).astype(np.uint8), "RGBA")
    rgb = ImageEnhance.Color(img.convert("RGB")).enhance(1.35)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.15)
    return Image.fromarray(np.dstack([np.asarray(rgb), np.asarray(img.getchannel("A"))]), "RGBA")


def fit(fig, w, h, pad=1):
    s = min((w - 2 * pad) / fig.width, (h - 2 * pad) / fig.height)
    small = _shrink(fig, s)
    a = np.asarray(small).copy()
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
    small = Image.fromarray(a, "RGBA")
    cell = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cell.alpha_composite(small, ((w - small.width) // 2, h - small.height - pad))
    return outline(cell)


def outline(img):
    a = np.asarray(img).copy()
    solid = a[..., 3] > 0
    grown = ndimage.binary_dilation(solid, structure=np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]]))
    edge = grown & ~solid
    a[edge] = OUTLINE
    return Image.fromarray(a, "RGBA")


def quantize(sheet, colors=48):
    rgb = sheet.convert("RGB").quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = np.dstack([np.asarray(rgb), np.asarray(sheet.getchannel("A"))])
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def grid_cells(img, cols, rows):
    """按人物的空白间隙切成 cols x rows 格（每行先按行的空白切，再按列的空白切；切不出来就均分）"""
    a = np.asarray(img.getchannel("A")) > 0
    def cuts(occ, n):
        idx = np.where(occ > 0)[0]
        if len(idx) == 0:
            return [round(i * len(occ) / n) for i in range(n + 1)]
        lo, hi = idx[0], idx[-1] + 1
        step = (hi - lo) / n
        out = [lo]
        for i in range(1, n):
            c = round(lo + step * i)
            win = range(max(lo, c - round(step * 0.3)), min(hi, c + round(step * 0.3)))
            out.append(min(win, key=lambda x: occ[x]) if len(win) else c)
        out.append(hi)
        return out
    ys = cuts(a.sum(1), rows)
    cells = []
    for r in range(rows):
        band = a[ys[r]:ys[r + 1]]
        xs = cuts(band.sum(0), cols)
        for c in range(cols):
            cells.append(img.crop((xs[c], ys[r], xs[c + 1], ys[r + 1])))
    return cells


def build_walker(src_name, out_name, label):
    """4x4 走路图（下 / 左 / 右 / 上 各 4 帧）→ 每格 32x32"""
    src = SRC / src_name
    if not src.exists():
        print("没有原图：", src)
        return
    cells = grid_cells(key_white(Image.open(src)), 4, 4)
    sheet = Image.new("RGBA", (128, 128))
    figs = [biggest(c) for c in cells]
    hmax = max(f.height for f in figs)
    for i, f in enumerate(figs):
        small = _shrink(f, 30 / hmax)
        cell = Image.new("RGBA", (32, 32))
        a = np.asarray(small).copy()
        a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
        small = Image.fromarray(a, "RGBA")
        cell.alpha_composite(small, ((32 - small.width) // 2, 31 - small.height))
        sheet.alpha_composite(outline(cell), ((i % 4) * 32, (i // 4) * 32))
    sheet.save(OUT / out_name)
    print(label + "：" + out_name)


def build_strip(src_name, out_name, n, w, h, label):
    src = SRC / src_name
    if not src.exists():
        print("没有原图：", src)
        return
    cells = grid_cells(key_white(Image.open(src)), n, 1)
    sheet = Image.new("RGBA", (w * n, h))
    for i, c in enumerate(cells):
        sheet.alpha_composite(fit(biggest(c), w, h), (i * w, 0))
    sheet.save(OUT / out_name)
    print(label + "：" + out_name)


def build_maid():
    src = SRC / "doll_maid_sheet.png"
    if not src.exists():
        print("没有原图：", src)
        return
    cells = grid_cells(key_white(Image.open(src)), 4, 4)
    sheet = Image.new("RGBA", (128, 128))
    figs = [biggest(c) for c in cells]
    hmax = max(f.height for f in figs)
    for i, f in enumerate(figs):
        # 同一张图里人物大小一致：按最高的那个缩
        s = 30 / hmax
        small = _shrink(f, s)
        cell = Image.new("RGBA", (32, 32))
        a = np.asarray(small).copy()
        a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
        small = Image.fromarray(a, "RGBA")
        cell.alpha_composite(small, ((32 - small.width) // 2, 31 - small.height))
        sheet.alpha_composite(outline(cell), ((i % 4) * 32, (i // 4) * 32))
    sheet.save(OUT / "npcs/doll_maid.png")
    print("人偶女仆：npcs/doll_maid.png")


def build_statue():
    src = SRC / "palace_statue_sheet.png"
    if not src.exists():
        print("没有原图：", src)
        return
    cells = grid_cells(key_white(Image.open(src)), 3, 1)
    sheet = Image.new("RGBA", (96, 48))
    for i, c in enumerate(cells):
        sheet.alpha_composite(fit(biggest(c), 32, 48), (i * 32, 0))
    sheet.save(OUT / "palace_statue.png")
    print("浴场雕像：palace_statue.png")


if __name__ == "__main__":
    build_maid()
    build_statue()
    build_walker("clock_keeper_sheet.png", "npcs/clock_keeper.png", "守钟人偶")
    build_strip("portrait_boss_sheet.png", "portrait_boss.png", 3, 64, 88, "大画像")
    build_strip("small_portrait_sheet.png", "small_portrait.png", 2, 28, 36, "小画像")
    build_strip("exit_markers_sheet.png", "exit_markers.png", 5, 40, 40, "出口标记（上楼梯 / 下楼梯 / 门 / 墙洞 / 梯子）")
    build_strip("clock_props_sheet.png", "clock_props.png", 6, 48, 56, "钟楼道具（齿轮 / 钟摆 / 风箱 / 钟 / 钟绳 / 宝箱）")
    build_strip("palace_misc_sheet.png", "palace_misc.png", 3, 24, 32, "仆人回廊（唤人铃 / 钥匙 / 小牌子）")
    build_walker("head_maid_sheet.png", "npcs/head_maid.png", "女仆长")
    # 第四章追加事件（第一批）
    build_strip("clock_beetle_sheet.png", "clock_beetle.png", 4, 20, 18, "发条挠痒虫（三帧爬 + 翻倒）")
    build_strip("rat_king_sheet.png", "rat_king.png", 4, 44, 40, "胖鼠王（洞里探头 / 坐着 / 晕 / 扫胡子）")
    build_strip("palace_events_sheet.png", "palace_events.png", 6, 40, 40, "追加事件道具（奶酪夹 / 夹子弹起 / 钟面 / 喷泉 / 徽记台 / 石堆）")
    build_walker("armor_guard_sheet.png", "npcs/armor_guard.png", "空铠甲卫兵")

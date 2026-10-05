"""把 assets/generated/CG/<来源键>.png（手绘 CG 大图）转成笑倒 CG 第三幕用的像素化 CG 图。

输出 assets/cg/portraits/<来源键>_3.png：保持原图比例，高度 360（显示高度 180，与立绘同为 2 倍像素密度），
宽度按比例（3:2 → 540，4:3 → 480，16:9 → 640）。原图不动（CG/ 目录有 .gdignore，Godot 不导入原图）。

做法：面积平均缩小 → 轻度锐化 → 每张图单独中位切分调色板（不抖动）→ 1px 深色描边当画框。
中位切分会把小面积的颜色并进大色块（例如大片绿色青蛙里公主的蓝眼睛变成绿色）：鲜艳像素里色相偏了 40° 以上的
占比超过 HUE_BAD_RATIO 时，改用八叉树调色板（色相偏差更小才换）。
一个怪物有两张 CG 图时命名为 <来源键>_1.png / <来源键>_2.png，分别输出 <来源键>_3（第三幕）和 <来源键>_4（第四幕）。
第八层的战败 CG 在 assets/generated/BOSS_CG/（中文原图名，按 BOSS_KEYS 输出 boss8_*.png），给第八层的战败小剧场用。
扩展名大小写都可以（.png / .PNG）。
用法：python tools/art/import_cg.py [--preview]
  --preview 在 tools/.cache/cg/ 输出原图与像素化结果的对比图
"""
import sys

from PIL import Image, ImageDraw, ImageFilter

from palette import OUT, OUTLINE, ROOT

SRC = OUT / "CG"
DST = ROOT / "assets/cg/portraits"
PREVIEW = ROOT / "tools/.cache/cg"
HEIGHT = 360        # 2 倍密度：显示为 180
COLORS = 128
## 鲜艳像素（饱和度 ≥ 0.35、亮度 ≥ 0.25）的色相偏了 HUE_BAD_DEG 度以上算「偏色」；占比超过 HUE_BAD_RATIO 就换八叉树调色板再比一次。
HUE_BAD_DEG = 40
HUE_BAD_RATIO = 0.0025


def pixelize(img: Image.Image) -> Image.Image:
    img = img.convert("RGB")
    w = round(img.width * HEIGHT / img.height)
    small = img.resize((w, HEIGHT), Image.BOX)
    small = small.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    q = small.quantize(COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    bad = hue_bad_ratio(small, q)
    if bad > HUE_BAD_RATIO:
        q2 = small.quantize(COLORS, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGB")
        if hue_bad_ratio(small, q2) < bad:
            q = q2
    d = ImageDraw.Draw(q)
    d.rectangle((0, 0, w - 1, HEIGHT - 1), outline=OUTLINE[:3])
    return q


def hue_bad_ratio(src: Image.Image, q: Image.Image) -> float:
    """量化后鲜艳像素色相偏了 HUE_BAD_DEG 度以上的占比（按全图像素数算）。"""
    a = src.convert("HSV").tobytes()
    b = q.convert("HSV").tobytes()
    limit = HUE_BAD_DEG * 256 / 360
    bad = 0
    for i in range(0, len(a), 3):
        if a[i + 1] < 90 or a[i + 2] < 64:
            continue
        d = abs(a[i] - b[i])
        if min(d, 256 - d) > limit:
            bad += 1
    return bad / (src.width * src.height)


def target_key(stem: str) -> str:
    """bat → bat_3；bubble_fish_1 → bubble_fish_3；bubble_fish_2 → bubble_fish_4。"""
    if stem.endswith("_1") or stem.endswith("_2"):
        return stem[:-2] + ("_3" if stem.endswith("_1") else "_4")
    return stem + "_3"


# 第八层千手痒痒魔的战败 CG（assets/generated/BOSS_CG/，同样有 .gdignore）：中文原图名 → 输出的英文键
BOSS_SRC = OUT / "BOSS_CG"
BOSS_KEYS = {
    "boss阶段2战败": "boss8_p2",
    "boss阶段3战败双人1": "boss8_duo_1", "boss阶段3战败双人2": "boss8_duo_2", "boss阶段3战败双人3": "boss8_duo_3",
    "boss阶段3战败蓝色公主抵抗1": "boss8_resist_1", "boss阶段3战败蓝色公主抵抗2": "boss8_resist_2",
    "boss阶段3战败蓝色公弱点特攻1": "boss8_weak_1", "boss阶段3战败蓝色公弱点特攻2": "boss8_weak_2",
    "boss阶段3战败群怪蓝色公主": "boss8_mob",
    "巨石追逐战": "boss8_chase",
}


def main():
    DST.mkdir(parents=True, exist_ok=True)
    done = []
    for path in sorted(p for p in SRC.iterdir() if p.suffix.lower() == ".png"):
        out_key = target_key(path.stem)
        out = pixelize(Image.open(path))
        out.save(DST / f"{out_key}.png")
        done.append((out_key, path, out))
    if BOSS_SRC.exists():
        for path in sorted(p for p in BOSS_SRC.iterdir() if p.suffix.lower() == ".png"):
            out_key = BOSS_KEYS.get(path.stem)
            if out_key is None:
                print("没有对应键的 BOSS_CG 图（跳过）：", path.name)
                continue
            out = pixelize(Image.open(path))
            out.save(DST / f"{out_key}.png")
            done.append((out_key, path, out))
    if "--preview" in sys.argv:
        PREVIEW.mkdir(parents=True, exist_ok=True)
        for key, path, out in done:
            src = Image.open(path).convert("RGB").resize(out.size, Image.LANCZOS)
            sheet = Image.new("RGB", (out.width * 2 + 8, out.height), "#333")
            sheet.paste(src, (0, 0))
            sheet.paste(out, (out.width + 8, 0))
            sheet.save(PREVIEW / f"{key}.png")
        print("预览：", PREVIEW)
    print("CG 图：", ", ".join(f"{k} {o.size[0]}x{o.size[1]}" for k, _, o in done))


if __name__ == "__main__":
    main()

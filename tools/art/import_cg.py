"""把 assets/generated/CG/<来源键>.png（手绘 CG 大图）转成笑倒 CG 第三幕用的像素化 CG 图。

输出 assets/cg/portraits/<来源键>_3.png：保持原图比例，高度 360（显示高度 180，与立绘同为 2 倍像素密度），
宽度按比例（3:2 → 540，4:3 → 480，16:9 → 640）。原图不动（CG/ 目录有 .gdignore，Godot 不导入原图）。

做法：面积平均缩小 → 轻度锐化 → 每张图单独中位切分调色板（不抖动）→ 1px 深色描边当画框。
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


def pixelize(img: Image.Image) -> Image.Image:
    img = img.convert("RGB")
    w = round(img.width * HEIGHT / img.height)
    small = img.resize((w, HEIGHT), Image.BOX)
    small = small.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    q = small.quantize(COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    d = ImageDraw.Draw(q)
    d.rectangle((0, 0, w - 1, HEIGHT - 1), outline=OUTLINE[:3])
    return q


def main():
    DST.mkdir(parents=True, exist_ok=True)
    done = []
    for path in sorted(SRC.glob("*.png")):
        key = path.stem
        out = pixelize(Image.open(path))
        out.save(DST / f"{key}_3.png")
        done.append((key, path, out))
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

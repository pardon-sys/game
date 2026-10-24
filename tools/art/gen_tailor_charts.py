"""规范化imagegen生成的裁缝服装局部图，不绘制编号或游戏结果。

源图与提示词保存在src/tailor_charts；输出384×256透明画布供TailorChart缩放显示。
用法：test_for_master环境运行本文件。默认保留源图透明度和颜色，不覆盖源图。
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tools/art/src/tailor_charts"
OUT = ROOT / "assets/generated/after"
SIZE = (384, 256)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for key in ("armpit", "waist", "sole"):
        source = Image.open(SOURCE / f"{key}.png").convert("RGBA")
        source.thumbnail(SIZE, Image.Resampling.LANCZOS)
        image = Image.new("RGBA", SIZE)
        image.alpha_composite(source, ((SIZE[0] - source.width) // 2, (SIZE[1] - source.height) // 2))
        path = OUT / f"tailor_{key}.png"
        image.save(path)
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()

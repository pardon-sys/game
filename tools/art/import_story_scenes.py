"""骑士篇背景大图（剧情过场）：tools/art/src/story_scenes/<名字>.png（codex 内置 image_gen 生成的 1536×1024，提示词见同目录 prompts.md）
→ 裁成 16:9 的 1536×864 → assets/generated/story_scenes/<名字>.png（游戏里 StoryBackdrop 整屏铺满）。
FOCUS：每张往上 / 往下裁多少（0 = 只裁下面，1 = 只裁上面；默认 0.35：人物的脸一般偏上，下面要给对话框）。
用法：python tools/art/import_story_scenes.py [名字 …]（不写就全部）
"""
import sys
from pathlib import Path

from PIL import Image

SRC = Path("tools/art/src/story_scenes")
OUT = Path("assets/generated/story_scenes")
NAMES = ["knight_boss", "kq_shoes", "kq_samples", "kq_spear", "kq_fence", "kq_host", "kq_blue"]
FOCUS = {}
W, H = 1536, 864


def run(name):
    src = SRC / (name + ".png")
    if not src.exists():
        print("没有原图：", src)
        return
    im = Image.open(src).convert("RGB")
    if im.width != W:
        im = im.resize((W, round(im.height * W / im.width)), Image.LANCZOS)
    extra = im.height - H
    top = round(extra * FOCUS.get(name, 0.35))
    im.crop((0, top, W, top + H)).save(OUT / (name + ".png"), optimize=True)
    print(name, "→", OUT / (name + ".png"))


OUT.mkdir(parents=True, exist_ok=True)
for n in (sys.argv[1:] or NAMES):
    run(n)

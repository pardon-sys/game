"""下载第三方素材（Kenney CC0 素材包 + Fusion Pixel 像素字体 OFL）。

用法: python tools/art/download_assets.py
"""
import io
import shutil
import zipfile
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / "tools" / ".cache"

KENNEY_DUNGEON = "https://kenney.nl/media/pages/assets/tiny-dungeon/f8422efb44-1674742415/kenney_tiny-dungeon.zip"
KENNEY_AUDIO = "https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip"
FUSION_FONT = "https://github.com/TakWolf/fusion-pixel-font/releases/download/2026.09.25/fusion-pixel-font-12px-proportional-ttf-v2026.09.25.zip"

# 从 RPG Audio 中挑选要用到的音效
AUDIO_FILES = [
    "footstep00.ogg", "footstep02.ogg", "footstep04.ogg", "footstep06.ogg",
    "doorOpen_1.ogg", "doorClose_2.ogg", "creak1.ogg", "metalLatch.ogg",
    "handleCoins.ogg", "handleSmallLeather.ogg", "cloth1.ogg", "bookFlip2.ogg",
    "knifeSlice.ogg", "knifeSlice2.ogg", "chop.ogg", "drawKnife1.ogg",
    "metalClick.ogg", "metalPot1.ogg", "dropLeather.ogg", "beltHandle1.ogg",
]


def fetch(url: str) -> bytes:
    CACHE.mkdir(parents=True, exist_ok=True)
    cached = CACHE / url.rsplit("/", 1)[-1]
    if cached.exists():
        return cached.read_bytes()
    print("下载", url)
    r = requests.get(url, timeout=120)
    r.raise_for_status()
    cached.write_bytes(r.content)
    return r.content


def extract(zf: zipfile.ZipFile, member_suffix: str, dest: Path) -> None:
    for name in zf.namelist():
        if name.endswith(member_suffix):
            dest.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(name) as src, open(dest, "wb") as dst:
                shutil.copyfileobj(src, dst)
            return
    raise FileNotFoundError(member_suffix)


def main() -> None:
    dungeon = zipfile.ZipFile(io.BytesIO(fetch(KENNEY_DUNGEON)))
    out = ROOT / "assets/third_party/kenney_tiny_dungeon"
    extract(dungeon, "Tilemap/tilemap_packed.png", out / "tilemap_packed.png")
    extract(dungeon, "License.txt", out / "License.txt")

    audio = zipfile.ZipFile(io.BytesIO(fetch(KENNEY_AUDIO)))
    out = ROOT / "assets/third_party/kenney_rpg_audio"
    for f in AUDIO_FILES:
        extract(audio, "/" + f, out / f)
    extract(audio, "License.txt", out / "License.txt")

    font = zipfile.ZipFile(io.BytesIO(fetch(FUSION_FONT)))
    out = ROOT / "assets/fonts"
    extract(font, "fusion-pixel-12px-proportional-zh_hans.ttf", out / "fusion-pixel-12px-proportional-zh_hans.ttf")
    extract(font, "OFL.txt", out / "OFL.txt")
    print("完成")


if __name__ == "__main__":
    main()

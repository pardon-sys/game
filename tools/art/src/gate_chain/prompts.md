# 穿链委托的图片来源

工具：codex CLI（`codex exec`）调用内置 image_gen，参考图是游戏截图和骑士的行走图（只用来对齐像素风格）。透明底，没有下载外部素材。
导入：`tools/art/import_gate_chain_art.py` 去掉低透明度的光晕、缩小、减色。

- `soles.png` → `assets/generated/after/gate_chain_soles.png`（转 90°，脚趾朝右，22×30）：小游戏里槽口外的两只光脚。第一版写实脚底用户觉得吓人，改成童趣风重新生成（提示词见下方「第二版」）
- `wall_full.png` / `wall_half.png` / `wall_broken.png` → `assets/generated/after/gate_wall_*.png`（64×64）：失败小剧场里倒塌的墙（完整 / 碎一半 / 全碎）

提示词（一次生成四张）：

> Style for all four: retro pixel art matching the attached game screenshot and sprite sheet (small chunky pixels, dark 1-pixel outline, soft warm palette, top-down 3/4 RPG view), crisp hard pixel edges, no anti-aliasing blur, no text, no watermark, no background, nonsexual cartoon game art. The character is a clearly ADULT fantasy princess with pale peach skin.
> 1) soles.png — TWO bare human feet side by side seen from behind/below so both SOLES face the viewer (heels at bottom, toes at top, five toes each), as if sticking out of a narrow maintenance slot. Only the feet and a bit of ankle.
> 2) wall_full.png — a collapsed pile of reddish-brown bricks and wooden beams with TWO bare feet sticking out from the bottom edge, soles facing the viewer, toes slightly curled.
> 3) wall_half.png — the SAME pile and feet, about half of the bricks blasted away by a burst of soft golden magic light.
> 4) wall_broken.png — the SAME scene after the wall is completely blown apart: scattered fragments, golden sparkles fading, a few loose bricks around the bare feet.

第二版 soles.png（童趣风，参考图换成粉色公主的立绘和小游戏截图）：

> a CUTE, CHILDLIKE, storybook-style pixel-art game sprite of TWO small bare feet side by side, seen from below so both soles face the viewer (heels at the bottom, toes at the top). They belong to the chibi princess in the first attached image (the character is an ADULT but drawn in a super-deformed chibi style), so the feet must match that cute style: small, short and rounded like little mochi or bean shapes, soft milky white skin with a faint warm pink tint, five tiny round toe beans per foot drawn as simple little circles, soft rosy pink pads on the heel and the ball of the foot, and a gentle blush. NO realistic anatomy, NO wrinkles, NO creases, NO veins, NO bony detail, NO dirt; very simple flat shading with at most 2-3 tones of skin color. Chunky clean pixels, thick dark-brown 1-pixel outline, crisp hard edges, kawaii and harmless, nonsexual cartoon game art.

第二版 wall_*.png（脚换成童趣风；参考图：第二版 soles.png + 第一版三张墙，保持构图）：

> Keep that composition and the brick/beam pile style for each matching stage, BUT REPLACE THE FEET with the cute storybook style of ref_feet.png: two SMALL, short, rounded mochi/bean-shaped feet, milky white skin, five tiny round pink toe beans each, soft rosy pink pads on the heel and ball, thick dark-brown 1-pixel outline, flat 2-3 tone shading, NO realistic anatomy, NO wrinkles or creases. The feet should be small relative to the pile, centered at the bottom edge of the pile, toes up, identical in all three images.

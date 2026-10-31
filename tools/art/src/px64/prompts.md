# 精细像素精灵图（64 格，codex 直接画的像素风）

codex CLI 内置 image_gen 直接画像素画（不做程序像素化）；`tools/art/import_sprites_px64.py` 只做网格对齐（按像素块大小最近邻还原）、去白底、排进 64 格图集。
参考图：`ref_pink_portrait.png`（立绘，对齐长相和服装）、`ref_old_sprite.png`（现在 32 格的小人，对齐 Q 版比例和朝向）。

## 通用要求（每张都有）

> Use your built-in image generation tool (image_gen) to create the image described below, saved in the current directory as <名字>.png (PNG). Do not edit or create any other files. After saving it, reply with just the filename.
> TRUE PIXEL ART sprite sheet for a top-down RPG, landscape 1536x1024, PURE WHITE background. Match EXACTLY the pixel-art style, pixel block size (one art pixel = a solid block of about 4x4 screen pixels), palette, outline and chibi proportions of the attached ref_style_walk.png (same character, same figure size: about 56 art pixels tall): crisp hand-placed pixels, limited palette, clean 1-pixel dark outlines, simple cel shading, NO anti-aliasing, NO blur, NO gradients. The character is the <角色>. Outfits follow the attached portrait references exactly. Every figure: full body, same size, generous white space between figures, feet on one baseline per row, tiny one-tone ground shadow; no text, no grid lines, no labels. She is an adult drawn in cute chibi style; wholesome and non-sexual.
> WALK CYCLES (very important): side-view walking frames must clearly alternate the legs — frame 1 left leg forward and right leg back, frame 2 legs passing/together with the body slightly raised, frame 3 right leg forward and left leg back, frame 4 legs passing; front and back walking frames also alternate which foot steps forward, with a small arm swing — never just slide the same pose.
> 

## 粉色

> pink_walk.png — NORMAL outfit: white knee-high socks and pink Mary-Jane shoes, gentle smile. Layout: exactly 4 rows x 4 columns: row 1 = walking toward the viewer (front), row 2 = walking to the LEFT (side view, facing left), row 3 = walking to the RIGHT (side view, facing right), row 4 = walking away (back view).
> pink_expr.png — NORMAL outfit (white knee-high socks, pink shoes), every figure STANDING upright facing the viewer in the same relaxed pose as row 1 frame 1 of ref_style_walk.png (not crouching, not sitting). Layout: exactly 2 rows x 4 columns, each a different expression: row 1 = normal gentle smile, happy (eyes closed big smile), angry (puffed cheeks, frowning), sad (teary eyes); row 2 = surprised (wide eyes, small open mouth), shy (blushing, looking down, hands together), holding back laughter (cheeks puffed, eyes squeezed, both hands over mouth, tiny sweat drop), laughing out loud (mouth open, tears of laughter, hands on tummy).
> pink_damaged.png — BATTLE-WORN outfit exactly like the 'damaged' portraits in ref_pink_portraits_all.png: the same off-shoulder dress slightly frayed and ruffled at the hem, BAREFOOT (both feet bare, small feet with toes), only a torn scrap of white lace sock around one ankle, flustered blush and a tiny sweat drop. Layout: exactly 5 rows x 4 columns: row 1 = walking toward the viewer (front), row 2 = walking LEFT (side), row 3 = walking RIGHT (side), row 4 = walking away (back), row 5 = four front-facing frames of her holding back laughter in the battle-worn outfit (eyes squeezed shut, hands over mouth, little hearts / sparkles near her head), a small 4-frame jiggle.
> pink_helpless.png — Layout: exactly 2 rows x 4 columns. Row 1 = 'giggling helplessly': battle-worn outfit, barefoot, she has collapsed sitting on the ground with legs out to the front, hugging her tummy and laughing with tears, 4 frames of her swaying while laughing (hearts and sparkles). Row 2 = 'laughing on the floor': battle-worn outfit, barefoot, lying on her back on the ground laughing hard with tears, her two bare feet kicking up alternately, 4 frames. Each figure exactly two legs and two feet.
> pink_magic1.png — MAGIC poses, all FRONT view, 6 frames per row (a short animation from left to right). Layout: exactly 3 rows x 6 columns: row 1 = CHANT in the normal outfit (white knee socks, pink shoes): hands clasped at her chest, eyes closed, a growing pink-gold magic circle and sparkles; row 2 = BURST in the normal outfit: arms thrown open, a bright burst of pink stars expanding around her; row 3 = CHANT in the battle-worn outfit (barefoot, frayed dress): same chant animation. The magic effects stay close to her body inside each cell.
> pink_magic2.png — MAGIC poses, all FRONT view, 6 frames per row. Layout: exactly 3 rows x 6 columns: row 1 = CHANT while holding back laughter in the battle-worn outfit (barefoot): trying to chant but cheeks puffed and shoulders shaking, magic circle flickering; row 2 = BURST in the battle-worn outfit (barefoot): arms thrown open, a burst of pink stars; row 3 = BURST while laughing in the battle-worn outfit: bursting magic while laughing with tears, stars and hearts. The magic effects stay close to her body inside each cell.

（试样 ref_style_walk.png 是用户确认过的画风；表情 / 战损 / 失控 / 魔法都照它画。）

## 蓝色公主 / 派对主人

同一套提示词（`tools/.cache/px64/` 里的 blue_* / host_* 由粉色的那几段替换角色描述生成），参考图换成 `ref_blue_portraits.png` / `ref_host_portraits.png`，
并说明 `ref_style_walk.png` 只是画风参考（别的角色）。服装：蓝色 白色荷叶边短袜 + 蓝鞋，战损光脚、裙摆微破；派对主人 光腿 + 红色绑带凉鞋，战损光脚、火焰裙边微焦。
派对主人另有 `host_attack.png`（4 行方向 × 3 帧：扬起彩带 → 甩出 → 收回）。

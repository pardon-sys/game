# 骑士篇特效图的来源

工具：codex CLI（`codex exec`）调用内置 image_gen，参考图 `ref_game_style.png`（游戏截图，只用来对齐画风）。没有下载外部素材。
导入：`tools/art/import_knight_fx.py`（洋红底抠透明 → 六帧同一外框 → 缩小、减色）→ `assets/generated/fx/<名字>.png`（6 帧横排），游戏里 `KnightFx.play` 播。
队长出招的精灵图不是 codex 画的：`tools/art/gen_captain_cast.py` 用 Python 画（和行走图同一套像素）。

## 通用要求（每张都有）

> Use your built-in image generation tool (image_gen) to create the images listed below, each saved in the current directory under the given filename (PNG). Do not edit or create any other files. After saving all of them, reply with just the filenames.
> Common format for EVERY image: a sprite sheet of an animated visual effect for a cute top-down 16-bit pixel-art RPG (see the attached game screenshot ONLY for the art style: chunky crisp pixels, soft pastel palette, clean dark outline where needed, simple 2-4 tone shading, no anti-aliasing blur). Canvas 1536x1024, landscape. EXACTLY 6 animation frames laid out in a 3-column x 2-row grid of equal 512x512 cells (frame order: top row left to right, then bottom row left to right). Each frame centered in its cell with generous empty margin, the effect never crossing cell borders. Background: flat solid pure magenta #FF00FF everywhere (no gradient, no shadow on the background, no grid lines, no borders between cells). No text, no numbers, no watermark, no characters or people — only the effect itself. Magical, sparkly, polished and pretty, cute game feel, nonsexual.

## 第 a 组

> 1) spear_thrust.png — a spear THRUST energy streak pointing to the RIGHT: frame 1 a small gathering glint of white-gold light at the left; frames 2-3 a long sharp horizontal lance of white and pale-gold light shooting to the right with a bright tip and speed lines; frame 4 the full-length streak at its brightest; frames 5-6 it breaks into fading gold sparkles and small stars.
> 2) spear_sweep.png — a low SWEEPING crescent slash: a wide flat white-and-sky-blue crescent arc swinging around (seen from a top-down 3/4 view, like a flattened ring), frame 1 thin start, frames 2-4 the arc sweeping around and growing, frames 5-6 it fades into small blue-white sparkles and dust puffs.
> 3) spear_impact.png — a small HIT burst: a pale-gold star-shaped flash with little feathers and tiny pink hearts popping out, frame 1 tiny, frames 2-3 biggest flash, frames 4-6 the pieces float outward and fade.

## 第 b 组

> 1) curse_burst.png — a CURSE SURGE aura: a swirling ring of violet and magenta curse energy with tiny glowing pale-purple child-sized HANDPRINT marks floating in it; frame 1 a small dark-violet spark, frames 2-4 the ring swells outward and spins with flickering purple flames, frame 5 at full size pulsing bright, frame 6 settling into a softer glowing ring (this frame should loop well with frame 4).
> 2) shockwave.png — a GROUND SHOCKWAVE seen from top-down 3/4 view (a flattened ellipse ring on the ground): violet-pink energy ring with a bright inner edge and small rock chips, frame 1 small and bright, frames 2-5 expanding wider and thinner, frame 6 a faint wide ring breaking into sparkles.
> 3) dust_land.png — a heavy LANDING impact: puffy cream-and-tan dust clouds bursting outward in a flattened ring with a few small pebbles and a faint purple curse glow in the middle; frame 1 compressed puff, frames 2-4 billowing outward, frames 5-6 drifting and fading.
> 4) part_break.png — a piece of ARMOR SHATTERING: silver-grey armor plate fragments with violet glowing cracks bursting apart, purple curse wisps escaping upward and golden sparkles; frame 1 a cracked silver plate glowing, frames 2-3 it bursts into fragments, frames 4-6 fragments fly out and the purple wisps dissolve into tiny stars.

## 第 c 组

> 1) laugh_drain.png — a stream of stolen LAUGHTER being sucked to the RIGHT: a wavy ribbon of pink and lavender light carrying tiny musical notes and little smiling sparkles, flowing from the left edge to the right edge of each cell; the six frames are a seamless LOOP of the ribbon flowing and the notes moving rightward.
> 2) tentacle.png — a cute but eerie purple CURSE TENTACLE made of violet smoke with a tiny glowing hand-shaped tip, rising from a small dark-purple puddle on the ground; frames 1-2 it rises and sways, frames 3-6 it wiggles side to side (loop-friendly), soft glow, not scary.
> 3) lantern_pillar.png — a warm golden LIGHT PILLAR rising from a paper lantern being lit: frame 1 a small warm orange glow at the bottom, frames 2-3 a tall column of golden-white light shooting up with floating motes and little musical notes, frames 4-6 the pillar shimmering and gently pulsing (loop-friendly).
> 4) purify.png — a big PURIFICATION burst: a radiant white-gold starburst with four streams of golden light converging into the center, soft pink petals and sparkles, rings of holy light; frame 1 four thin golden beams converging, frames 2-3 a growing bright core, frame 4 the full brilliant starburst, frames 5-6 sparkles and petals drifting outward and fading.

## 第 d 组

> 1) throw_trail.png — a THROWN CURSED OBJECT flying to the RIGHT: a small glowing violet orb wrapped in tiny pale-purple handprints with a comet-like magenta trail and sparkles behind it; the six frames are a seamless LOOP of the orb spinning and the trail flickering.
> 2) beacon_light.png — a laughter BEACON IGNITING: a brazier-like warm flame bursting into a tall soft golden flare with a ring of light spreading on the ground and little musical notes and hearts floating up; frame 1 a tiny ember, frames 2-3 a bright upward flare, frame 4 full brightness with the ground ring, frames 5-6 a steady happy flame glow (loop-friendly).
> 3) trap_land.png — a cursed trap LANDING on the ground: a purple splash ring with a faint violet handprint stamped in the middle, small sparkles and dust; frame 1 a bright purple impact flash, frames 2-4 the splash ring spreading flat on the ground (top-down 3/4 view, flattened ellipse), frames 5-6 settling into a faint glowing handprint mark.

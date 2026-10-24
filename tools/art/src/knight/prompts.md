# 骑士立绘的来源

工具：codex CLI（`codex exec`）调用内置 image_gen；参考图是队长的立绘 `assets/generated/npc_portraits/银白圣徽骑士统帅.png`（只用来对齐画风）。透明背景，没有下载外部素材。
源图 `knight_portrait_source.png`（1086×1448），导入脚本 `tools/art/import_knight_portrait.py` 裁成半身、像素化成 228×304 的 `npc_portraits/knight.png`。

最终提示词：

> Use your built-in image generation tool (image_gen) to create ONE new image and save it in the current directory as knight_portrait.png (transparent background PNG). Do not edit or create any other files.
> Subject: a game character portrait in EXACTLY the same art style, rendering, line quality and colour treatment as the attached reference illustration (an anime-style fantasy knight commander), half body from head to waist, facing slightly left, 3:4 portrait aspect.
> Character: an ADULT male knight, mysterious. His face is COMPLETELY hidden by a closed full helmet with the visor lowered (only a dark eye slit, no eyes visible). Battle-worn, scratched and dulled silver-grey plate armour with faded gold trim. A tattered, frayed, faded navy-blue cape with a ripped hem, on it HALF of a faded gold royal crest (the other half torn away). A longsword at his hip whose hilt is wrapped with a red cord. A few small faint purple glowing child-sized HANDPRINT marks on his breastplate and pauldron, like a curse. A small strand of rose-pink hair escapes from under the back of the helmet. Stern, weary posture, one gauntlet resting on the sword pommel.
> Requirements: nonsexual, no text, no watermark, no background scenery, true transparent alpha background, the whole head and both shoulders inside the frame with a margin.

伏笔（只给开发看）：深蓝披风 + 金边、剑柄的红绳、头盔下的粉红头发都和队长对得上（骑士 = 未来的队长），游戏里不点破。

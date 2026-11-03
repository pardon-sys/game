# 鼠鼠装立绘（17 张，codex 改图）

工具：codex image_gen；每张参考 `ref_<状态>.png`（原立绘的高清人物）+ `mouse_concept.png`（造型定稿），输出 `mouse_<状态>.png`。
导入：`python tools/art/import_mouse_outfit.py` → `assets/generated/portraits_mouse.png`。
`{STATE}` 换成状态名；`{FEET}` 按参考图选：原图穿着袜子鞋子 → SHOES 那段；原图光脚 → BARE 那段。

> Use your built-in image generation tool (image_gen) to EDIT the attached ref_{STATE}.png and save the result in the current directory as mouse_{STATE}.png (PNG). Do not edit or create any other files. After saving it, reply with just the filename.
> Keep EVERYTHING from ref_{STATE}.png exactly the same — same character, same face and expression, same pose, same hair, same dress, same effects and sparkles, same framing, same size and position on the canvas, same cute soft-shaded chibi illustration style, PURE WHITE background — and change ONLY her lower body outfit to the "mouse outfit" shown in the attached mouse_concept.png: fluffy GREY mouse shorts (soft fur, like short bloomers with a little pink ribbon at the waistband) peeking out just under the hem of her skirt at mid-thigh; a long thin PINK mouse TAIL coming out from under the back of the skirt and curling to one side; a tiny cute grey mouse with round ears and a pink nose peeking out of the shorts' waistband or from under the skirt hem. {FEET}
> SHOES: replace her white knee-high socks and pink shoes with bare legs and GREY furry "mouse paw slippers" shaped like mouse faces (two round ears, pink nose) with OPEN TOES (her toes peek out at the front: each foot exactly five small toes in natural order) and little pink paw pads on the soles; no socks.
> BARE: she is barefoot in the reference — keep her bare feet exactly as they are (do not add slippers or socks); each foot keeps exactly five toes.
> Keep it wholesome and non-sexual (skirt stays where it is in the reference, no underwear focus). No text, no watermark.

# 裁缝局部插画提示词

2026-10-20，内置image_gen；每张单独生成，transparent_background=true。源图带透明软阴影，完整RGBA保留，运行时只规范化尺寸，不擅自改绘内容。

公共提示：
Use case: infographic-diagram. Asset type: neutral clothing inspection illustration for a fantasy dungeon game's tailor UI. Clear hand-painted cartoon illustration with crisp shapes, warm ivory padded cotton, muted rose seam accents, dark warm outlines, gentle fabric shading. Clothing only, no person, no skin, no mannequin body, no hands, no action or tools. Transparent background. No text, no numbers, no arrows, no icons, no symbols, no decorative objects. Must remain readable when reduced to a small game UI card. Centered object with generous margin.

## armpit.png
One front-view padded short-sleeved cotton shirt with sleeves raised diagonally, a clearly visible left and right shoulder seam and curved underarm seam. Crop to upper shirt, no waist. Bilaterally symmetrical. The four seam junctions should be distinct and unobstructed.

## waist.png
Two views side by side at the same size: front view on the left and back view on the right of the waist section of a padded cotton tunic, cropped from lower ribs to hem. Clearly show side seams, front center stitching, and back center stitching; front and back distinguishable by different seam construction. No body or visible skin. Clean simple fabric, not intimate clothing.

## sole.png
最终版本按用户「袜子是正常女生脚的模样，不要畸形」重新生成，替换原对称轮廓。内置image_gen编辑目标为原sole.png，透明背景，完整最终提示词如下：

Use case: precise-object-edit. Asset type: a tiny tailor-inspection game UI illustration. Edit target: the supplied ivory sock underside illustration. Replace its unnatural symmetrical silhouette with the anatomically correct plantar outline of ONE adult woman's LEFT foot wearing a thin fitted opaque ivory cotton sock. The sock must closely follow a normal slender adult female foot: five naturally aligned toes under the fabric, big toe at upper right largest and longest, the other four taper progressively toward upper left, realistic wide forefoot and narrower heel, gentle concave medial arch on image right and nearly straight lateral edge on image left. Heel at bottom, toes at top. Clearly distinct but modest textile seams at toe cap and reinforced heel. Normal proportions with no bulging pads, no hourglass shape, no extra toes, no twisted or mirrored anatomy. Keep the warm ivory cloth, subtle muted rose stitching and clean outlined hand-painted game illustration style. Full foot sole straight-on without perspective distortion, centered with generous margin. Transparent background. Sock only, no bare skin, no person, no labels, no text, no arrows, no objects. Readable at small UI size.

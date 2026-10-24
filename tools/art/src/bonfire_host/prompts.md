# 内置 imagegen 提示词与资源来源

工具：内置 image_gen；transparent_background=true。源图保留原始alpha，导入仅将低于128的alpha边缘噪点置透明。没有下载外部资源。

共同最终提示词：Same clearly ADULT human festival hostess, exact super-deformed chibi proportions of the princess reference, huge head occupying 40 percent of total height, tiny torso and short legs, orange-red half-up long wavy hair and flower ornaments, warm amber eyes, coral orange off-shoulder cropped blouse exposing midriff, compact cream white tiered festival skirt with gold trim, practical flat strappy sandals, small lantern in LEFT hand. Fine pixel-art inspired shading and outlines. Entire full body and both anatomically correct feet in frame, genuine transparent background, generous gutters, no text, no grid lines, no floor or scenery.

参考图：现有公主normal立绘（只取第一格）＋原派对主人立绘生成design-v1；首版身材过长，随后用“2.5 heads maximum, no tall slender legs, no long trailing train”修正成design。其余表均用design作为身份参考，精灵同时引用walk。

|源表|附加提示内容（按从左到右、从上到下）|
|---|---|
|portraits_daily|3 columns × 2 rows：normal welcoming；happy closed-eye wave；annoyed hand on hip；sad lowered brows；surprised hand up；bashful hand near cheek。|
|portraits_extra|3×2：slightly dusty battle-worn clothes intact；suppressed giggle hand near mouth；dusty giggle；laughing out loud knees bent；seated comic exhaustion waving for a break；relieved recovering。Only first five states imported。Nonsexual cartoon emotions, no interactions。|
|portraits_magic|3×2：ordinary chant；ordinary release；dusty chant；dusty giggling chant；dusty release；dusty giggling release。Lantern and gold/orange ribbon light, effects inside cell。|
|walk|4×4：rows down,left,right,up；each row feet together,left forward,together,right forward。Real leg and arm articulation, consistent silhouette and baseline。|
|sprite_extras|requested5×4：dusty four directions；giggle four directions；dusty giggle four directions；four front laughing phases；four seated laughing phases。Last row incomplete, import uses complete seated portrait with upper-body animation instead。|
|sprite_magic|requested6×6：six sequential phases per row, chant,release,dusty chant,dusty giggling chant,dusty release,dusty giggling release。Actual generated five rows; importer detects gutters and reads5×6。|
|sprite_magic_last|3×2 consecutive release animation frames while giggling: lantern at chest → draws hand → extends hand → ribbon spark → ribbon ring expands → hand relaxes. Slightly dusty intact clothes, shoes stay on。Completes sixth magic row。|
|sprite_attack|4×3：rows down,left,right,up；draw hand back holding ribbon ring → throw forward → recovery, lantern remains in left hand。|

最终运行时资产由import_bonfire_host.py的固定状态映射和既有Pixelizer／SpritePixelizer生成。不得直接把源表当成游戏图集使用。

## 战损裸足修订（2026-10-21）

用户最新要求：战损版人物立绘裸足。仅覆盖`damaged`、`damaged_giggle`、`damaged_chant`、`damaged_giggle_chant`、`damaged_burst`、`damaged_giggle_burst`；普通／失控立绘与地图精灵不扩大修改。

工具：内置image_gen，`transparent_background=true`。编辑目标为从原立绘裁切排成3×2的`portraits_damaged_edit_input.png`，最终源图`portraits_damaged_barefoot.png`，保留alpha。输出来自`exec-c61abe88-4fed-461f-8529-eefe051d86ee.png`，已复制入项目。原始立绘源表保留，导入器固定覆盖六格。

最终提示词：

> Use case: precise-object-edit. Edit target: the supplied 3 columns by 2 rows full-body game portrait sheet. These are six battle-damaged states of the same ADULT fantasy festival hostess drawn in the project's super-deformed chibi style. Change ONLY her footwear in EVERY one of the SIX cells: remove both sandals entirely, including every ankle strap, flower shoe ornament, sole and heel, and draw two simple natural bare feet continuous with her legs in the same pose and scale. Both feet must be anatomically coherent, small stylized game feet, naturally oriented. No detached shoes or feet, no foot closeups. Keep exact face, hair, body proportions, expressions, costumes, lanterns, pose, palette, outlines and spell effects unchanged; intact clothing, nonsexual cartoon game art. Preserve exactly six separated full-body figures in the same 3x2 grid/order with generous transparent gutters, no text, no scenery. True transparent alpha background.

导入修复：`sprite_magic_last`比主表分辨率高，先按各组裁切后的中位高度归一，再统一像素化；源图不改绘，48格中以32像素为尺寸上限，保留特效余量；六行输出高度最终在资源检查日志中记录。

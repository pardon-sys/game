# 笑倒 CG 立绘接口

`data/cgs.json` 的 `portraits` 段为每段 CG 定义了立绘 id，例如：

```json
"slime_1": {"file": "res://assets/cg/portraits/slime_1.png", "placeholder": "helpless_1"}
```

- 把正式素材按 id 命名放进这个文件夹（如 `slime_1.png`），游戏就会自动使用它，**不用改代码和 cgs.json**。
- 文件不存在时，用 `placeholder` 指定的公主状态立绘占位（现在全部是失控 1 / 失控 2，醒来的一张是难过）。
- 推荐尺寸 228×304（和现有立绘一样是 2 倍像素密度，显示为 114×152），其它尺寸会按比例缩放进立绘框。
- 想换一张图或新增立绘 id：改 `cgs.json` 的 `portraits`，并在 CG 步骤里用 `"portrait": "新的 id"` 引用。

当前的立绘 id：`defeat_1` / `defeat_2`（通用）、`wake`（醒来），以及每种怪物的 `<来源键>_1` / `<来源键>_2`：
slime、bat、ghost、spider、troll、rat、crab、split_slime、mimic、fairy、tentacle。

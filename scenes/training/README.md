# 保卫队训练小游戏

每种训练一个场景：`scenes/training/<训练 id>.tscn`（id 见 `data/training/trainings.json`）。
根节点提供 `start()`，结束时发出 `finished(passed: bool)`；过关后调用 `TrainingDB.grant(id)` 发奖励。
场景存在时 `TrainingDB.start(id)` 会返回它，营地的训练台和队长对话里的「训练」选项就会打开小游戏。

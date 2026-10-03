# 保卫队训练小游戏

训练小游戏不用场景文件：每项训练是一个脚本 `scripts/training/<kind>.gd`（kind 见 `data/training/trainings.json`），
`TrainingDB.run(id, 部位)` 创建它并 `await run(训练, 部位)`，返回 `{successes, gained}`。

- 训练一 / 三 / 四（`qte_endure` / `qte_resist` / `qte_sensitize`）继承 `TrainingStage`（`scripts/training/training_stage.gd`）：
  地图过场 → 小游戏画面（CGActor 小舞台 + 左上面板）→ 惩罚小剧场 → Esc 结束。
- 训练二（`maze_release`）换到训练迷宫 `levels/floor_06_training/` 在地图上玩。

新加一项训练：在 `trainings.json` 里加一项（`kind` 指向新脚本），脚本继承 `TrainingStage` 实现 `_tick / _on_key` 等，详见 `docs/ARCHITECTURE.md`「保卫队训练营」。

class_name Cells
## 格子坐标 → 世界坐标（过场 / 任务里摆东西用：格子中心偏下一点，站人的位置）。
## 以前写成 Cutscene.cell_to_world（静态函数从 autoload 实例上调用，编辑器一直报 STATIC_CALLED_ON_INSTANCE），统一改成 Cells.to_world。


static func to_world(c: Variant) -> Vector2:
	return Vector2(float(c[0]) * 16.0 + 8.0, float(c[1]) * 16.0 + 12.0)

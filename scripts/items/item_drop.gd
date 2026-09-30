class_name ItemDrop
extends Resource
## 掉落表中的一项：以 chance 概率掉落 min_amount~max_amount 个 item。

@export var item: ItemData
@export_range(0.0, 1.0) var chance := 0.5
@export var min_amount := 1
@export var max_amount := 1


## 按掉落表在 pos 处生成物品（每项独立判定）。
static func roll(drops: Array[ItemDrop], parent: Node, pos: Vector2) -> void:
	for d in drops:
		if d and d.item and randf() < d.chance:
			for i in randi_range(d.min_amount, d.max_amount):
				WorldItem.spawn(parent, pos, d.item, 1, true)

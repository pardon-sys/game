class_name ItemDrop
extends Resource
## 掉落表中的一项：以 chance 概率掉落 min_amount~max_amount 个 item。

@export var item: ItemData
@export_range(0.0, 1.0) var chance := 0.5
@export var min_amount := 1
@export var max_amount := 1


## 按掉落表在 pos 处生成物品（每项独立判定）。
## direct_keys = true（Boss）：钥匙类物品不掉在地上，直接放进背包并提示，保证流程不会卡住。
static func roll(drops: Array[ItemDrop], parent: Node, pos: Vector2, direct_keys := false) -> void:
	for d in drops:
		if d and d.item and randf() < d.chance:
			var n := randi_range(d.min_amount, d.max_amount)
			if direct_keys and d.item.category == ItemData.Category.KEY:
				GameState.give_item(d.item, n, GameState.player, true)
				var line := "got_" + d.item.id
				if Dialogue.has_dialogue(line):
					Dialogue.start.call_deferred(line)
				continue
			for i in n:
				WorldItem.spawn(parent, pos, d.item, 1, true)

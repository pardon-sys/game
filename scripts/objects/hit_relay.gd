class_name HitRelay
extends StaticBody2D
## 把命中转交给父节点：让 Area2D 类的机关（藤蔓）也能被权杖打到。放在 breakable 层（第 6 层），不挡路。


func _ready() -> void:
	collision_layer = 32
	collision_mask = 0


func receive_hit(hit: HitData) -> bool:
	var p := get_parent()
	return p.receive_hit(hit) if p and p.has_method("receive_hit") else false

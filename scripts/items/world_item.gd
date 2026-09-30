class_name WorldItem
extends Area2D
## 地上的可拾取物品（公主碰到即拾取）：auto_use_on_pickup 的物品立即使用，其余放进背包。

const SCENE := "res://scenes/items/world_item.tscn"

@export var item: ItemData
@export var amount := 1
## 从木桶/怪物掉落时的弹出动画。
var spawn_pop := false

@onready var sprite: Sprite2D = $Sprite

var _t := 0.0
var _ready_time := 0.0


## 在 pos 处生成一个掉落物。
static func spawn(parent: Node, pos: Vector2, it: ItemData, n := 1, pop := true) -> WorldItem:
	var w: WorldItem = load(SCENE).instantiate()
	w.item = it
	w.amount = n
	w.spawn_pop = pop
	# 先定好位置再加进场景：_ready 里的弹出动画以当前位置为起点
	# （之前先 add_child 再设位置，弹出动画会把掉落物拖回原点 (0,0)，落进地图左上角的墙里）
	w.position = (parent as Node2D).to_local(pos) if parent is Node2D else pos
	parent.add_child(w)
	return w


func _ready() -> void:
	if item:
		sprite.texture = item.icon
	_t = randf() * 3.0
	body_entered.connect(_on_body_entered)
	if spawn_pop:
		_ready_time = 0.35
		var target := position + Vector2(randf_range(-10, 10), randf_range(-2, 8))
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "position", target, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		sprite.position.y = -10
		tw.tween_property(sprite, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	_ready_time -= delta
	sprite.offset.y = -8.0 + roundf(sin(_t * 4.0) * 1.0)
	if _ready_time <= 0.0:
		for b in get_overlapping_bodies():
			_on_body_entered(b)


func _on_body_entered(body: Node) -> void:
	if _ready_time > 0.0 or item == null or is_queued_for_deletion() or not body.is_in_group("player"):
		return
	GameState.give_item(item, amount, body, item.category in [ItemData.Category.KEY, ItemData.Category.CONSUMABLE])
	queue_free()

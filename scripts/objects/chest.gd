extends StaticBody2D
## 宝箱（Interactable）：按 E 打开，把 item 交给公主并可播放对话。

const CLOSED := Rect2(80, 112, 16, 16)  # Kenney #89
const OPEN := Rect2(96, 112, 16, 16)  # Kenney #90

@export var item: ItemData
@export var amount := 1
## 打开后播放的对话 id（留空则不播放）。
@export var dialogue := ""
@export var opened := false

@onready var sprite: Sprite2D = $Sprite
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	sprite.region_rect = OPEN if opened else CLOSED
	interactable.enabled = not opened


func on_interact(actor: Node) -> void:
	if opened:
		return
	opened = true
	_refresh()
	Audio.play("chest")
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.06)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.1)
	if item:
		Fx.item_rise(get_parent(), global_position + Vector2(0, -14), item.icon)
		GameState.give_item(item, amount, actor, true)
		if item.pickup_emotion == "":
			GameState.emote("happy")
	if dialogue != "":
		await get_tree().create_timer(0.5).timeout
		Dialogue.start(dialogue)

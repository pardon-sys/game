extends StaticBody2D
## 门（Interactable）：普通门按 E 打开；设置了 required_key 的门需要背包里有对应钥匙（会被消耗）。

const CLOSED := Rect2(160, 48, 16, 16)  # Kenney #46
const OPEN := Rect2(144, 48, 16, 16)  # Kenney #45
const LOCK_FRAME := {"bronze": 5, "gold": 6}

@export var required_key: KeyItem
@export var is_open := false

@onready var sprite: Sprite2D = $Sprite
@onready var lock_sprite: Sprite2D = $Lock
@onready var shape: CollisionShape2D = $Shape
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	sprite.region_rect = OPEN if is_open else CLOSED
	shape.set_deferred("disabled", is_open)
	interactable.enabled = not is_open
	lock_sprite.visible = required_key != null and not is_open
	if lock_sprite.visible:
		lock_sprite.frame = LOCK_FRAME.get(required_key.key_type, 5)


func on_interact(_actor: Node) -> void:
	if is_open:
		return
	if required_key:
		if not GameState.inventory.remove(required_key.id):
			Audio.play("locked")
			Dialogue.start("locked_" + required_key.key_type)
			return
		Audio.play("unlock")
		GameState.notify("用%s打开了门。" % required_key.display_name)
		GameState.emote("happy")
		required_key = null
	open()


func open() -> void:
	is_open = true
	Audio.play("door")
	_refresh()

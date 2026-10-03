extends Node2D
## 存档点：台座上发光的日记本（assets/generated/save_point.png）。按 E → 选存档位（SlotMenu）→ 保存，顺便回满生命。
## 只能在这里存档（主界面读取）。图例：X = savepoint place=<地点名>

const SHEET := preload("res://assets/generated/save_point.png")

@export var place := ""

var sprite: Sprite2D
var _t := 0.0


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = 2
	sprite.offset = Vector2(0, -8)
	add_child(sprite)
	var light := PointLight2D.new()
	light.texture = preload("res://assets/lights/light_soft.tres")
	light.color = Color(1.0, 0.75, 0.9)
	light.energy = 0.6
	light.texture_scale = 0.7
	light.position = Vector2(0, -10)
	add_child(light)


func _process(delta: float) -> void:
	_t += delta
	sprite.frame = 1 if int(_t * 1.5) % 2 == 0 else 0


func on_interact(player: Node) -> void:
	Audio.play("book", -4.0)
	var menu := SlotMenu.new()
	get_tree().root.add_child(menu)
	var slot: int = await menu.choose("save")
	menu.queue_free()
	if slot < 0:
		return
	var p := player as PlayableCharacter
	if p and p.health:
		p.health.fill()
	if SaveSystem.save(slot, place):
		Audio.play("chime", -4.0, 0.05, 1.1)
		GameState.notify("已存档（存档 %d）" % slot)
	else:
		GameState.notify("存档失败……")

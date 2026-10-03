extends Node2D
## 小镇道具（房屋、摊位、篝火、帐篷、哨塔、栅栏、训练假人、路灯……）：图集 assets/generated/town_props.png，
## 每种道具的区域、碰撞、发光、动画在 town_props.json（tools/art/gen_town_art.py 生成）。
## 构建器图例：X = prop type=<道具> [action=…]
##   action = heal          交互：恢复满生命、闷笑清零（篝火）
##   action = shop:<商店>    交互：打开商店（data/shop/<商店>.json）
##   action = training      交互：保卫队训练（TrainingDB，小游戏以后接）
##   action = talk:<文件>    交互：人物对话（data/dialogues/<文件>.json）
##   action = read:<对话 id> 交互：读一段普通对话（像石碑）

const SHEET := preload("res://assets/generated/town_props.png")
const META_PATH := "res://assets/generated/town_props.json"

static var _meta := {}

@export var kind := "crate"
@export var action := ""

var sprite: Sprite2D
var _anim_t := 0.0
var _frames: Array = []


static func meta() -> Dictionary:
	if _meta.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		_meta = parsed if parsed is Dictionary else {}
	return _meta


func _ready() -> void:
	var info: Dictionary = meta().get(kind, {})
	if info.is_empty():
		push_warning("没有这种道具: " + kind)
		return
	var r: Array = info["region"]
	sprite = Sprite2D.new()
	sprite.texture = SHEET
	sprite.region_enabled = true
	sprite.region_rect = Rect2(r[0], r[1], r[2], r[3])
	sprite.offset = Vector2(0, -float(r[3]) / 2.0)
	if info.get("floor", false):
		sprite.offset = Vector2(0, -8)
		sprite.z_index = -1 if false else 0
	add_child(sprite)
	if info.has("anim"):
		var r2: Array = meta()[str(info["anim"])]["region"]
		_frames = [Rect2(r[0], r[1], r[2], r[3]), Rect2(r2[0], r2[1], r2[2], r2[3])]
	if info.has("body"):
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var b: Array = info["body"]
		rect.size = Vector2(float(b[0]), float(b[1]))
		shape.shape = rect
		shape.position = Vector2(0, float(info.get("body_y", -3)))
		body.add_child(shape)
		add_child(body)
	if info.has("light"):
		var l: Array = info["light"]
		var light := PointLight2D.new()
		light.texture = preload("res://assets/lights/light_soft.tres")
		light.color = Color(float(l[0]), float(l[1]), float(l[2]))
		var fire := kind.begins_with("bonfire")
		light.energy = 0.8 if fire else 0.4
		light.texture_scale = 1.3 if fire else 0.55
		light.position = Vector2(0, -float(r[3]) * 0.6)
		add_child(light)
	if kind.begins_with("bonfire"):
		Fx.emitter(self, "ember", 8, 1.0, {"offset": Vector2(0, -10), "dir": Vector2.UP, "spread": 25.0,
				"speed": [12.0, 26.0], "gravity": Vector2(0, -10), "color": Color(1, 0.7, 0.4), "z": 3})
	if action != "":
		var it := Interactable.new()
		it.name = "Interactable"
		it.prompt_offset = Vector2(0, -float(r[3]) - 4.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(maxf(float(r[2]), 18.0), 20)
		shape.shape = rect
		shape.position = Vector2(0, -6)
		it.add_child(shape)
		add_child(it)


func _process(delta: float) -> void:
	if _frames.is_empty():
		return
	_anim_t += delta
	sprite.region_rect = _frames[int(_anim_t * 6.0) % _frames.size()]


func on_interact(player: Node) -> void:
	var parts := action.split(":", true, 1)
	match parts[0]:
		"heal":
			Town.rest(player)
		"shop":
			Town.open_shop(parts[1] if parts.size() > 1 else "market")
		"training":
			Town.open_training()
		"talk":
			Dialogue.talk(parts[1])
		"read":
			Audio.play("book", -4.0)
			Dialogue.start(parts[1])

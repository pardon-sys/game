class_name MagicCircle
extends Node2D
## 吟唱时脚下的魔法阵 + 身上升起的星光。stage 0~3 = 蓄力档位（0 = 还不够一档）。
## 挂在施法者下面，show_behind_parent 让它画在角色身后、地面之上。

const SHEET := preload("res://assets/generated/magic_circle.png")
const SPARKLE := preload("res://assets/generated/sparkle.png")
const LIGHT_TEX := preload("res://assets/lights/light_soft.tres")

var stage := 0
var _sprite: Sprite2D
var _sparkles: CPUParticles2D
var _light: PointLight2D
var _t := 0.0


func _ready() -> void:
	show_behind_parent = true
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.hframes = 4
	_sprite.vframes = 4
	_sprite.material = mat
	_sprite.position = Vector2(0, -1)
	add_child(_sprite)
	_sparkles = CPUParticles2D.new()
	_sparkles.texture = SPARKLE
	_sparkles.material = mat
	_sparkles.amount = 10
	_sparkles.lifetime = 0.9
	_sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparkles.emission_rect_extents = Vector2(10, 4)
	_sparkles.direction = Vector2.UP
	_sparkles.spread = 15.0
	_sparkles.gravity = Vector2.ZERO
	_sparkles.initial_velocity_min = 14.0
	_sparkles.initial_velocity_max = 26.0
	_sparkles.scale_amount_min = 0.5
	_sparkles.scale_amount_max = 1.0
	_sparkles.color = Color(1, 1, 1, 0.9)
	_sparkles.position = Vector2(0, -4)
	add_child(_sparkles)
	_light = PointLight2D.new()
	_light.texture = LIGHT_TEX
	_light.color = Color(1.0, 0.85, 0.95)
	_light.position = Vector2(0, -6)
	add_child(_light)
	set_stage(0)


func set_stage(s: int) -> void:
	stage = clampi(s, 0, 3)
	if _sprite == null:
		return
	_sparkles.amount = 6 + stage * 6
	_sparkles.emission_rect_extents = Vector2(8 + stage * 6, 3 + stage * 2)
	_light.energy = 0.5 + stage * 0.35
	_light.texture_scale = 0.4 + stage * 0.25
	if stage > 0:
		var tw := create_tween()
		_sprite.scale = Vector2(1.25, 1.25)
		tw.tween_property(_sprite, "scale", Vector2.ONE, 0.15)


func _process(delta: float) -> void:
	_t += delta
	_sprite.frame = stage * 4 + int(_t * 8.0) % 4
	_sprite.modulate.a = 0.75 + 0.25 * sin(_t * 9.0)

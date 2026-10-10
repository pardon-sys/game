class_name MoonLamp
extends Node2D
## 月光灯（第八层夜迷宫的检查点）：石座上浮着一颗发冷光的「月亮」。
##   亮着时：她走进光里（RADIUS 内）→ 身上的手全部散掉、冷光补满、记为重生点（导演处理）；紫手不敢进来。
##   被偷灯小鬼吹灭（extinguish）后：不能清手；她走过去按 E 重新点亮（小鬼还在旁边时点不着）。
## 图例：X = moonlamp [lit=false]

signal changed(lit: bool)

const LIGHT_TEX := preload("res://assets/lights/light_soft.tres")
const RADIUS := 34.0

@export var lit := true

var light: PointLight2D
var interact: Interactable
var _t := 0.0


func _ready() -> void:
	add_to_group("moon_lamp")
	light = PointLight2D.new()
	light.texture = LIGHT_TEX
	light.color = Color(0.72, 0.85, 1.0)
	light.texture_scale = 1.15
	light.height = 30.0
	light.shadow_enabled = true
	light.position = Vector2(0, -18)
	add_child(light)
	interact = Interactable.new()
	interact.prompt_offset = Vector2(0, -34)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 16)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	interact.add_child(shape)
	add_child(interact)
	_apply(true)


func covers(p: Vector2) -> bool:
	return lit and p.distance_to(global_position + Vector2(0, -4)) <= RADIUS


func extinguish() -> void:
	if not lit:
		return
	lit = false
	Audio.play("puff", -4.0, 0.05, 0.8)
	_apply()
	changed.emit(false)


func relight() -> void:
	if lit:
		return
	lit = true
	Audio.play("chime", -4.0, 0.0, 0.8)
	Fx.burst(get_parent(), global_position + Vector2(0, -18), "crystal", 8, 40.0, 0.6, Vector2(0, 30), Color(0.8, 0.9, 1.0))
	_apply()
	changed.emit(true)


func on_interact(player: Node) -> void:
	if lit:
		return
	for imp in get_tree().get_nodes_in_group("lamp_imp"):
		if imp is Node2D and (imp as Node2D).global_position.distance_to(global_position) < 48.0 and imp.get("_dead") != true:
			SpeechBubble.say(player, "……先把它赶走。", 26.0)
			return
	relight()


func _apply(instant := false) -> void:
	interact.enabled = not lit
	var e := 0.75 if lit else 0.08
	if instant:
		light.energy = e
	else:
		create_tween().tween_property(light, "energy", e, 0.4)


func _process(delta: float) -> void:
	_t += delta
	if lit:
		light.texture_scale = 1.15 + sin(_t * 1.7) * 0.04
	queue_redraw()


func _draw() -> void:
	# 石座
	draw_rect(Rect2(-6, -6, 12, 6), Color(0.32, 0.34, 0.45))
	draw_rect(Rect2(-4, -12, 8, 6), Color(0.4, 0.42, 0.55))
	draw_rect(Rect2(-6, -6, 12, 1), Color(0.55, 0.58, 0.72))
	# 浮着的月亮
	var y := -20.0 + sin(_t * 2.0) * 1.5
	var core := Color(0.85, 0.92, 1.0) if lit else Color(0.35, 0.38, 0.5)
	if lit:
		draw_circle(Vector2(0, y), 7.0, Color(0.7, 0.85, 1.0, 0.25))
	draw_circle(Vector2(0, y), 4.5, core)
	draw_circle(Vector2(1.5, y - 1.0), 3.5, Color(0.12, 0.13, 0.2) if not lit else Color(0.6, 0.72, 0.95))
	# 光圈（亮着时地上一圈淡淡的范围）
	if lit:
		draw_set_transform(Vector2(0, -4), 0.0, IsoView.ground_scale())
		draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 48, Color(0.75, 0.88, 1.0, 0.18 + 0.06 * sin(_t * 2.0)), 1.0)
		draw_set_transform(Vector2.ZERO)

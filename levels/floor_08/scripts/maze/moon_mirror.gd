class_name MoonMirror
extends Node2D
## 月光镜（第八层夜迷宫）：能转的镜子。附近（POWER_RANGE 内）有亮着的月光灯时，把月光反射成一道光带，沿镜面朝向照到墙为止。
##   光带里（group light_band，covers / source_point）：身上的手慢慢散掉、冷光慢慢补、紫手不敢进来（导演 light_at）。
##   光带照到光开关（BeamSwitch）→ 打开同组的门（暗门捷径）。
##   按 E 顺时针转 90°。
## 图例：X = moonmirror [facing=0~3（右 / 下 / 左 / 上）]

const TEX := preload("res://assets/generated/maze/moon_mirror.png")
const DIRS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const POWER_RANGE := 150.0
const MAX_TILES := 14
const HALF_WIDTH := 9.0

@export var facing := 0

var sprite: Sprite2D
var beam_end := Vector2.ZERO
var powered := false
var _t := 0.0
var _remove_t := 0.0
var _dir: IsoDirectional


func _ready() -> void:
	add_to_group("light_band")
	sprite = Sprite2D.new()
	sprite.texture = TEX
	sprite.hframes = 4
	sprite.offset = Vector2(0, -12)
	add_child(sprite)
	if IsoView.enabled:
		_dir = IsoDirectional.add_to(sprite, "dir4", DIRS[facing])
	var it := Interactable.new()
	it.prompt_offset = Vector2(0, -28)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 16)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	it.add_child(shape)
	add_child(it)
	_refresh()


func on_interact(_player: Node) -> void:
	facing = (facing + 1) % 4
	Audio.play("lever", -6.0, 0.05, 1.2)
	_refresh()


func source_point() -> Vector2:
	return global_position + Vector2(0, -10)


## 这一点在光带里吗（没通电就没有光带）。
func covers(p: Vector2) -> bool:
	if not powered:
		return false
	var a := source_point()
	var seg := beam_end - a
	var t := clampf((p + Vector2(0, -6) - a).dot(seg) / maxf(seg.length_squared(), 1.0), 0.0, 1.0)
	return (a + seg * t).distance_to(p + Vector2(0, -6)) <= HALF_WIDTH


func _refresh() -> void:
	if _dir:
		_dir.facing = DIRS[facing]
		_dir.refresh()
	else:
		sprite.frame = facing
	powered = false
	for l in get_tree().get_nodes_in_group("moon_lamp"):
		if (l as MoonLamp).lit and (l as Node2D).global_position.distance_to(global_position) <= POWER_RANGE:
			powered = true
	# 光带沿朝向一格一格往前，碰到墙就停
	var lv := _level()
	var d: Vector2 = DIRS[facing]
	var p := source_point()
	beam_end = p
	for i in MAX_TILES:
		var next := beam_end + d * 16.0
		if lv and not GridPath.walkable(lv, GridPath.cell(next + Vector2(0, 6))):
			break
		beam_end = next
	for s in get_tree().get_nodes_in_group("beam_switch"):
		if s.has_method("set_lit"):
			s.set_lit(powered and covers((s as Node2D).global_position))


func _level() -> Node:
	var n: Node = get_parent()
	while n and not n.has_node("Walls"):
		n = n.get_parent()
	return n


func _process(delta: float) -> void:
	_t += delta
	_remove_t += delta
	if _remove_t >= 0.5:
		_remove_t = 0.0
		_refresh()
	queue_redraw()


func _draw() -> void:
	if not powered:
		return
	# 光源在镜子上方（屏幕方向的高度），光带沿地面走（等距下用 IsoView.offset 换成屏幕偏移）
	var a := source_point() - global_position
	var b := a + IsoView.offset(beam_end - source_point())
	var k := 0.75 + 0.25 * sin(_t * 3.0)
	draw_line(a, b, Color(0.7, 0.85, 1.0, 0.18 * k), HALF_WIDTH * 2.0)
	draw_line(a, b, Color(0.85, 0.95, 1.0, 0.35 * k), 4.0)
	draw_line(a, b, Color(1, 1, 1, 0.6 * k), 1.0)

class_name HandAlarm
extends CanvasLayer
## 大量紫手的提示（第八层夜迷宫；导演自带一个）：
##   一次召出 ≥ SUMMON_MIN 只（summoned(n)：千手的影子、笑声收集瓶、组合技），或者 NEAR 像素内同时有 ≥ CHASE_MIN 只手被笑声引着朝她来
##   → 屏幕中间黄字「……好多手……靠过来了……！」+ 屏幕边缘紫色脉冲 + 指向手来的方向的边缘箭头（ARROW_TIME 秒）+ 低沉的轰鸣。
##   冷却 COOLDOWN 秒。

signal alarmed

const SUMMON_MIN := 3
const CHASE_MIN := 4
const NEAR := 140.0
const COOLDOWN := 12.0
const ARROW_TIME := 2.0
const TEXT := "……好多手……靠过来了……！"

var director: MazeDirector
var _cool := 0.0
var _check := 0.0
var _arrow_t := 0.0
var _draw_node: Node2D
var _fx: ScreenFx
var _fx_left := 0.0
## 发过几次（测试用）
var count := 0


func _ready() -> void:
	layer = 9
	_draw_node = Node2D.new()
	_draw_node.draw.connect(_draw_arrows)
	add_child(_draw_node)


func summoned(n: int) -> void:
	if n >= SUMMON_MIN:
		trigger()


func _exit_tree() -> void:
	if is_instance_valid(_fx):
		_fx.fade_out(0.2)


func trigger() -> bool:
	if _cool > 0.0:
		return false
	_cool = COOLDOWN
	count += 1
	_arrow_t = ARROW_TIME
	GameState.hint(TEXT)
	Audio.play("rumble", -2.0, 0.05)
	if is_instance_valid(_fx):
		_fx.fade_out(0.1)
	_fx = ScreenFx.vignette(Color(0.6, 0.15, 0.9), 0.5, true)
	_fx_left = ARROW_TIME
	alarmed.emit()
	return true


func _process(delta: float) -> void:
	if _fx_left > 0.0:
		_fx_left -= delta
		if _fx_left <= 0.0 and is_instance_valid(_fx):
			_fx.fade_out(0.4)
	_cool = maxf(0.0, _cool - delta)
	_arrow_t = maxf(0.0, _arrow_t - delta)
	_draw_node.queue_redraw()
	if director == null or not is_instance_valid(director.blue):
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.3
	var n := 0
	for h in director.hands():
		if (h as Node2D).global_position.distance_to(director.blue.global_position) <= NEAR and director.attracts(h):
			n += 1
	if n >= CHASE_MIN:
		trigger()


## 屏幕边缘的箭头：每只在屏幕外（或靠边）的手一个，指向它来的方向。
func _draw_arrows() -> void:
	if _arrow_t <= 0.0 or director == null or not is_instance_valid(director.blue):
		return
	var vp := _draw_node.get_viewport().get_visible_rect().size
	var center := vp / 2.0
	var me := IsoView.canvas_pos(director.blue)
	var a := minf(1.0, _arrow_t / 0.4) * (0.65 + 0.35 * sin(_arrow_t * 16.0))
	for h in director.hands():
		var hp := IsoView.canvas_pos(h as Node2D)
		var dir := (hp - me).normalized()
		if dir == Vector2.ZERO:
			continue
		var inside := Rect2(Vector2(24, 24), vp - Vector2(48, 48)).has_point(hp)
		if inside:
			continue
		# 从屏幕中心沿方向射到边缘（留 14 像素边距）
		var half := center - Vector2(14, 14)
		var t := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
		var tip := center + dir * t
		var side := dir.orthogonal() * 5.0
		_draw_node.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 9.0 + side, tip - dir * 9.0 - side]),
			Color(0.9, 0.55, 1.0, a))
		_draw_node.draw_polyline(PackedVector2Array([tip, tip - dir * 9.0 + side, tip - dir * 9.0 - side, tip]),
			Color(0.2, 0.05, 0.25, a), 1.0)

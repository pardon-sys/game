class_name KnightFogRing
extends Node2D
## 「笑雾之中」外圈的黑雾（TaskKnightBoss 在雾里摆上，圆心是骑士的位置 _home）：半径从 R0 每秒收 SHRINK，最小 R_MIN；
##   每点亮一盏灯笼往外推 PUSH（push()）；驱散阶段停住不收。
##   圈外（radius 以外）、又不在亮着的灯笼光里（KnightCurse.LIGHT_SAFE_R）的可操作角色每 TICK 秒被挠一下（KnightTickle：+LAUGH，不超过 MAX_LAUGH，疲倦跟着涨）、
##   挂状态 fog_tickle（buffs.json），冒一句 ring 台词。亮着的灯笼周围画一圈暖光（安全区）。
##   画法：等距地面上的暗紫雾圈（IsoView.ground_scale）+ 往里飘的雾团。
## 测试：radius、frozen、push()、tick(dt)。

const R0 := 200.0
const R_MIN := 76.0
const SHRINK := 3.2
const PUSH := 42.0
const TICK := 0.5
const LAUGH := 0.05
const MAX_LAUGH := 0.95
const BUFF_TIME := 1.0

var task: TaskKnightBoss
var radius := R0
## 驱散阶段：雾圈停住
var frozen := false
var _tick := 0.0
var _t := 0.0
var _say := 0.0


func _ready() -> void:
	z_index = 0


func push() -> void:
	radius = minf(R0, radius + PUSH)
	if is_instance_valid(task):
		var lines: Array = TaskKnightBoss.data().get("fog", {}).get("ring_push", [])
		if not lines.is_empty():
			GameState.princess_reacted.emit(str(lines.pick_random()), 2.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if GameState.in_dialogue or GameState.in_cutscene or get_tree().paused:
		return
	tick(delta)


func tick(delta: float) -> void:
	_say = maxf(0.0, _say - delta)
	if not frozen:
		radius = maxf(R_MIN, radius - SHRINK * delta)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	for c in get_tree().get_nodes_in_group("player_chars"):
		var pc := c as PlayableCharacter
		if pc == null or not pc.is_alive() or pc.global_position.distance_to(global_position) <= radius:
			continue
		# 亮着的灯笼光里（KnightCurse.LIGHT_SAFE_R）不受黑雾侵蚀
		if is_instance_valid(task) and task.lights().any(func(l): return l.global_position.distance_to(pc.global_position) <= KnightCurse.LIGHT_SAFE_R):
			continue
		KnightTickle.hit(pc, LAUGH, task._body if is_instance_valid(task) else self, "sole", KnightTickle.BOSS_CRIT, MAX_LAUGH)
		pc.add_buff("fog_tickle", BUFF_TIME)
		if pc == GameState.player and _say <= 0.0:
			_say = 3.0
			var lines: Array = TaskKnightBoss.data().get("fog", {}).get("ring", [])
			if not lines.is_empty():
				GameState.princess_reacted.emit(str(lines.pick_random()), 1.6)


func _draw() -> void:
	# 雾圈：圈外一层层暗紫（画成地面上的椭圆），圈边上翻滚的雾团
	draw_set_transform(Vector2.ZERO, 0.0, IsoView.ground_scale())
	for i in 6:
		draw_arc(Vector2.ZERO, radius + 8.0 + i * 14.0, 0, TAU, 64, Color(0.1, 0.03, 0.16, 0.5 - i * 0.06), 16.0)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.55, 0.25, 0.75, 0.55 + 0.15 * sin(_t * 3.0)), 2.0)
	for i in 24:
		var a := TAU * i / 24.0 + _t * 0.15
		var r := radius + 6.0 + sin(_t * 2.0 + i) * 5.0
		draw_circle(Vector2.from_angle(a) * r, 6.0 + sin(_t * 3.0 + i * 1.3) * 2.0, Color(0.14, 0.05, 0.2, 0.55))
	draw_set_transform(Vector2.ZERO)
	# 亮着的灯笼：一圈暖光（安全区，黑雾进不来）
	if is_instance_valid(task):
		for l in task.lights():
			var at := IsoView.offset((l as Node2D).global_position - global_position)
			draw_set_transform(at, 0.0, IsoView.ground_scale())
			draw_circle(Vector2.ZERO, KnightCurse.LIGHT_SAFE_R, Color(1.0, 0.85, 0.5, 0.12 + 0.04 * sin(_t * 2.0)))
			draw_arc(Vector2.ZERO, KnightCurse.LIGHT_SAFE_R, 0, TAU, 32, Color(1.0, 0.9, 0.6, 0.55), 1.5)
			draw_set_transform(Vector2.ZERO)

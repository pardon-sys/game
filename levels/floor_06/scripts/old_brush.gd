class_name OldBrush
extends Node2D
## 旧痒痒刷（骑士篇支线「点灯笼的小姑娘」·储物间）：挂在墙上的旧刷子，每 EVERY 秒往下扫一次——先抖 WARN 秒（预警），再扫 SWEEP 秒，
##   扫的时候刷子下面那一竖条（宽 WIDTH）里的人：挠一下（大腿 / 脚心，闷笑 +LAUGH），往后推一点。看准了间隔就能过。
##   千手解放 / 冰晶结界：冻住 FROZEN 秒，不扫。
## 测试：state（idle / warn / sweep / frozen）、phase_offset、hit(角色)。

const EVERY := 2.4
const WARN := 0.45
const SWEEP := 0.55
const WIDTH := 14.0
const LAUGH := 0.09
const FROZEN := 4.0
const PUSH := 18.0

var state := "idle"
var phase_offset := 0.0
var down := true
var _t := 0.0
var _hit := {}


func _ready() -> void:
	z_index = 2
	_t = phase_offset
	add_to_group(PantsBurst.KNIGHT_GROUP)


func on_pants_burst(burst: PantsBurst) -> void:
	if global_position.distance_to(burst.global_position) <= PantsBurst.RADIUS:
		state = "frozen"
		_t = -FROZEN


func on_ice_barrier(center: Vector2, r: float, time: float) -> void:
	if global_position.distance_to(center) <= r:
		state = "frozen"
		_t = -maxf(time, FROZEN)


func covers(c: Node2D) -> bool:
	return absf(c.global_position.x - global_position.x) <= WIDTH * 0.5


func _process(delta: float) -> void:
	queue_redraw()
	if GameState.in_dialogue or GameState.in_cutscene:
		return
	_t += delta
	if _t < 0.0:
		return
	var k := fmod(_t, EVERY)
	var was := state
	if k < EVERY - WARN - SWEEP:
		state = "idle"
	elif k < EVERY - SWEEP:
		state = "warn"
	else:
		state = "sweep"
	if state == "sweep" and was != "sweep":
		_hit.clear()
	if state == "sweep":
		for c in get_tree().get_nodes_in_group("player_chars"):
			if c is PlayableCharacter and covers(c) and not _hit.has(c) and not (c as PlayableCharacter).is_dashing():
				hit(c)


func hit(c: PlayableCharacter) -> void:
	_hit[c] = true
	var zone: String = "thigh" if c is BluePrincess else str(["thigh", "sole"].pick_random())
	ZoneFx.play(zone, c.get_parent(), ZoneFx.body_point(c, zone), 0.9, false)
	if c.laugh:
		c.laugh.add(c.laugh.max_value * LAUGH)
	c.global_position.x -= PUSH
	Audio.play("brush_spin", -8.0)


func _draw() -> void:
	var swing := 0.0
	match state:
		"warn":
			swing = sin(_t * 40.0) * 0.12
		"sweep":
			swing = 1.0
	var reach := 6.0 + 22.0 * swing
	var dir := 1.0 if down else -1.0
	# 挂钩 + 刷柄 + 一排刷毛
	draw_circle(Vector2.ZERO, 1.5, Color("8a7a66"))
	draw_line(Vector2.ZERO, Vector2(0, reach * dir), Color("8b6644"), 2.0)
	for i in 5:
		draw_line(Vector2(-4 + i * 2, reach * dir), Vector2(-4 + i * 2, (reach + 5.0) * dir), Color("e8d7b0") if state != "frozen" else Color(0.75, 0.92, 1.0), 1.0)
	if state == "warn":
		draw_rect(Rect2(-WIDTH * 0.5, 4 * dir if down else -32, WIDTH, 28), Color(1, 0.5, 0.6, 0.12))

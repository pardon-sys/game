class_name BridgeHand
extends Node2D
## 桥下手印（骑士篇支线「点灯笼的小姑娘」·小桥）：躲在桥板缝下面，每 EVERY 秒冒一次泡（WARN 秒，预警），然后伸上来抓 GRAB 秒——
##   这时候站在这块桥板上（REACH 以内、没在冲刺）：抓住脚踝挠（定身 ROOT 秒、闷笑 +LAUGH）。发出 grabbed 信号（任务算「手被扯开」）。
##   千手解放 / 冰晶结界：缩回去 FROZEN 秒。
## 测试：state（hide / warn / grab / frozen）、phase_offset、grab_now(角色)。

signal grabbed(who: PlayableCharacter)

const EVERY := 2.6
const WARN := 0.6
const GRAB := 0.7
const REACH := 9.0
const ROOT := 0.7
const LAUGH := 0.08
const FROZEN := 4.0

var state := "hide"
var phase_offset := 0.0
var _t := 0.0
var _got := false


func _ready() -> void:
	z_index = 1
	_t = phase_offset
	add_to_group(PantsBurst.KNIGHT_GROUP)


func on_pants_burst(burst: PantsBurst) -> void:
	if global_position.distance_to(burst.global_position) <= PantsBurst.RADIUS:
		_t = -FROZEN


func on_ice_barrier(center: Vector2, r: float, time: float) -> void:
	if global_position.distance_to(center) <= r:
		_t = -maxf(time, FROZEN)


func _process(delta: float) -> void:
	queue_redraw()
	if GameState.in_dialogue or GameState.in_cutscene:
		return
	_t += delta
	if _t < 0.0:
		state = "frozen"
		return
	var k := fmod(_t, EVERY)
	var was := state
	state = "hide" if k < EVERY - WARN - GRAB else ("warn" if k < EVERY - GRAB else "grab")
	if state == "grab" and was != "grab":
		_got = false
	if state == "grab" and not _got:
		for c in get_tree().get_nodes_in_group("player_chars"):
			if c is PlayableCharacter and c == GameState.player and c.global_position.distance_to(global_position) <= REACH and not (c as PlayableCharacter).is_dashing():
				grab_now(c)


func grab_now(c: PlayableCharacter) -> void:
	_got = true
	if c.status:
		c.status.apply_root(ROOT)
	if c.laugh:
		c.laugh.add(c.laugh.max_value * LAUGH)
	ZoneFx.play("sole", c.get_parent(), ZoneFx.body_point(c, "sole"), 0.9, false)
	Audio.play("hand_grab", -6.0)
	grabbed.emit(c)


func _draw() -> void:
	# 桥板缝
	draw_line(IsoView.offset(Vector2(-6, 2)), IsoView.offset(Vector2(6, 2)), Color(0.2, 0.15, 0.12), 1.0)
	match state:
		"warn":
			for i in 3:
				draw_circle(Vector2(-3 + i * 3, 1 - fmod(_t * 6.0 + i, 3.0)), 1.0, Color(0.75, 0.5, 1.0, 0.7))
		"grab":
			CurseHand.draw_hand(self, Vector2(0, -3), 0.7, CurseHand.COL, CurseHand.COL_D, 0.9, sin(_t * 14.0))
		"frozen":
			draw_circle(Vector2(0, 1), 3.0, Color(0.75, 0.92, 1.0, 0.6))

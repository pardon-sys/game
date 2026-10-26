class_name EaveHand
extends Node2D
## 爬墙手印（骑士篇·夜里：支线「夜里的栅栏」、以后的追逃也能用）：贴在房檐上（画在 HANG 高处）。
##   可操作角色从下面经过（水平 TRIGGER_X、竖直 TRIGGER_Y 以内）→ 在她脚下亮影子（WARN 秒，落点固定）→ 掉下来：
##   她还站在影子上（CATCH_R 以内、没在冲刺）= 抓住脚：定身 HOLD 秒，每秒闷笑 +HOLD_LAUGH（粉色公主挠脚心、蓝色公主挠大腿）；
##   连按 J MASH 下挣开。掉下来以后爬回房檐，COOL 秒内不再掉。被千手解放扫到：缩回去 COOL 秒。
## 信号 grabbed(角色)。测试：drop_at(位置)、grab(角色)、mash()、state。

signal grabbed(who: PlayableCharacter)

const HANG := 22.0
const TRIGGER_X := 14.0
const TRIGGER_Y := 30.0
const WARN := 0.8
const CATCH_R := 10.0
const HOLD := 2.0
const HOLD_LAUGH := 0.05
const MASH := 5
const COOL := 6.0
const MAX_LAUGH := 0.97

var state := "hang"
var target := Vector2.ZERO
var victim: PlayableCharacter
var lines := {}
var _t := 0.0
var _left := 0.0
var _mash := 0
var _say := 0.0


func _ready() -> void:
	z_index = 3
	add_to_group("eave_hand")
	add_to_group(PantsBurst.KNIGHT_GROUP)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if GameState.in_dialogue or GameState.in_cutscene:
		return
	match state:
		"hang":
			var p := GameState.player
			if is_instance_valid(p) and absf(p.global_position.x - global_position.x) <= TRIGGER_X and absf(p.global_position.y - global_position.y) <= TRIGGER_Y:
				drop_at(p.global_position)
		"warn":
			_left -= delta
			if _left <= 0.0:
				_land()
		"hold":
			_left -= delta
			if is_instance_valid(victim) and victim.laugh and victim.laugh.value < victim.laugh.max_value * MAX_LAUGH:
				victim.laugh.add(minf(victim.laugh.max_value * HOLD_LAUGH * delta, victim.laugh.max_value * MAX_LAUGH - victim.laugh.value))
			if Input.is_action_just_pressed("attack") and victim == GameState.player:
				mash()
			if _left <= 0.0:
				_release()
		"cool":
			_left -= delta
			if _left <= 0.0:
				state = "hang"


## 盯上了：落点在这里亮影子
func drop_at(at: Vector2) -> void:
	if state != "hang":
		return
	state = "warn"
	target = at
	_left = WARN


func _land() -> void:
	for c in get_tree().get_nodes_in_group("player_chars"):
		var pc := c as PlayableCharacter
		if pc and pc.global_position.distance_to(target) <= CATCH_R and not pc.is_fully_invulnerable():
			grab(pc)
			return
	state = "cool"
	_left = COOL


func grab(c: PlayableCharacter) -> void:
	state = "hold"
	victim = c
	_left = HOLD
	_mash = 0
	c.status.apply_root(HOLD)
	var zone := "thigh" if c is BluePrincess else "sole"
	ZoneFx.play(zone, c.get_parent(), ZoneFx.body_point(c, zone), 1.0, false)
	Audio.play("tickle", -6.0, 0.1)
	var pool: Array = lines.get("eave_drop", [])
	if not pool.is_empty():
		GameState.princess_reacted.emit(str(pool.pick_random()), 2.4)
	var react: Array = lines.get("eave_react", [])
	if not react.is_empty() and not c is BluePrincess:
		SpeechBubble.say(c, str(react.pick_random()), 30.0, 1.4)
	grabbed.emit(c)


func mash() -> void:
	if state != "hold":
		return
	_mash += 1
	if is_instance_valid(victim):
		victim.shake(0.08)
	if _mash >= MASH:
		_release()


func _release() -> void:
	if is_instance_valid(victim):
		victim.status.clear_root()
	victim = null
	state = "cool"
	_left = COOL


func on_pants_burst(burst: PantsBurst) -> void:
	if global_position.distance_to(burst.global_position) <= PantsBurst.RADIUS + HANG:
		_release()


func _draw() -> void:
	var col := CurseHand.COL
	match state:
		"hang", "cool":
			var a := 0.35 if state == "cool" else 0.75
			CurseHand.draw_hand(self, Vector2(0, -HANG), 0.8, col, CurseHand.COL_D, a, sin(_t * 4.0), PI * 0.15)
		"warn":
			var k := 1.0 - _left / WARN
			var at := target - global_position
			draw_circle(at, CATCH_R, Color(0.55, 0.2, 0.75, 0.25 + 0.35 * k))
			draw_arc(at, CATCH_R, 0, TAU, 16, Color(0.85, 0.5, 1.0, 0.8), 1.0)
			CurseHand.draw_hand(self, Vector2(0, -HANG).lerp(at, k * k), 0.8, col, CurseHand.COL_D, 0.85, sin(_t * 12.0), PI * 0.15)
		"hold":
			if is_instance_valid(victim):
				var at2 := victim.global_position - global_position + Vector2(0, -2)
				CurseHand.draw_hand(self, at2, 0.9, col, CurseHand.COL_D, 0.9, sin(_t * 16.0))

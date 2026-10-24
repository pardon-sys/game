class_name CurseHand
extends Node2D
## 诅咒手印（骑士篇）：骑士盔甲上漏出来的紫黑色小手印，贴着地面爬。行为由放它的任务驱动（抬担架 / 以笑为饵 / Boss 召唤），这里只管移动、贴人、冻住和画。
##   state：wander 闲逛 / seek 爬向 target / flee 躲开 flee_from / latched 贴在 target 身上挠 / frozen 被冰冻住（FROZEN_TIME 秒，可以收进瓶子）/ gone 散了
##   贴上以后每秒挠一下（tick 信号，任务决定挠成什么样）：
##     粉色公主：很轻——闷笑每秒 +GENTLE_LAUGH，疲倦每秒 +GENTLE_FATIGUE（反而舒服；伏笔「手印认得她」）
##     蓝色公主（以及别的可操作角色）：闷笑每秒 +HARD_LAUGH（大腿）
##     镇民（普通 Node2D）：偷走笑声（stealing = true），只冒一个灰色的「……」
## 不是 Monster：不参与战斗、打不到，只能冻住再收走（或者被任务驱散 dispel()）。
## 测试：直接改 state / target / global_position，调 latch() / freeze() / dispel()。

signal latched(who: Node2D)
signal ticked(who: Node2D)

const SPEED := 46.0
const FLEE_SPEED := 70.0
const LATCH_R := 9.0
const FROZEN_TIME := 6.0
const GENTLE_LAUGH := 0.015
const GENTLE_FATIGUE := 0.04
const HARD_LAUGH := 0.07
const TICK := 1.0
const MAX_LAUGH := 0.97
const COL := Color(0.78, 0.45, 1.0)
const COL_D := Color(0.42, 0.18, 0.6)
## 画大一点（夜里也要看得清），不受光照影响
const SCALE := 1.6
const ICE := Color(0.72, 0.9, 1.0)

var state := "wander"
var target: Node2D
var flee_from := Vector2.ZERO
var frozen_left := 0.0
var stealing := false
var speed_mult := 1.0
var _t := 0.0
var _tick := TICK
var _dir := Vector2.RIGHT
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_index = 1
	scale = Vector2(SCALE, SCALE)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	add_to_group("curse_hand")
	_rng.randomize()
	_dir = Vector2.from_angle(_rng.randf() * TAU)


func is_pink(who: Node) -> bool:
	return who is PlayableCharacter and not who is BluePrincess


func seek(who: Node2D) -> void:
	if state in ["latched", "frozen", "gone"]:
		return
	target = who
	state = "seek"


func flee(from: Vector2) -> void:
	if state in ["latched", "frozen", "gone"]:
		return
	flee_from = from
	state = "flee"


func latch(who: Node2D) -> void:
	target = who
	state = "latched"
	_tick = 0.2
	stealing = not (who is PlayableCharacter)
	latched.emit(who)


func release() -> void:
	if state == "latched":
		state = "wander"
		stealing = false
		target = null


func freeze(time := FROZEN_TIME) -> void:
	if state == "gone":
		return
	stealing = false
	state = "frozen"
	frozen_left = time
	Audio.play("ice", -6.0, 0.1)


func dispel() -> void:
	state = "gone"
	stealing = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if GameState.in_cutscene or state == "gone":
		return
	match state:
		"frozen":
			frozen_left -= delta
			if frozen_left <= 0.0:
				state = "wander"
		"latched":
			if not is_instance_valid(target) or not target.is_inside_tree():
				release()
				return
			global_position = target.global_position + Vector2(sin(_t * 3.0) * 4.0, -6.0)
			_tick -= delta
			if _tick <= 0.0:
				_tick = TICK
				_tickle(target)
		"seek":
			if not is_instance_valid(target):
				state = "wander"
				return
			var to := target.global_position - global_position
			if to.length() <= LATCH_R:
				latch(target)
				return
			_dir = to.normalized()
			global_position += _dir * SPEED * speed_mult * delta
		"flee":
			var away := global_position - flee_from
			_dir = away.normalized() if away.length() > 0.1 else Vector2.from_angle(_rng.randf() * TAU)
			global_position += _dir * FLEE_SPEED * speed_mult * delta
		_:
			if _rng.randf() < delta * 0.8:
				_dir = _dir.rotated(_rng.randf_range(-1.4, 1.4))
			global_position += _dir * SPEED * 0.35 * delta


## 贴着人挠一下：粉色公主轻轻的（疲倦涨得多），别的可操作角色狠一点，镇民只是被偷走笑声
func _tickle(who: Node2D) -> void:
	ticked.emit(who)
	var pc := who as PlayableCharacter
	if pc == null:
		return
	var zone := "sole" if is_pink(pc) else "thigh"
	ZoneFx.play(zone, pc.get_parent(), ZoneFx.body_point(pc, zone), 0.8 if is_pink(pc) else 1.1, is_pink(pc))
	if pc.laugh and pc.laugh.value < pc.laugh.max_value * MAX_LAUGH:
		var amount := (GENTLE_LAUGH if is_pink(pc) else HARD_LAUGH) * pc.laugh.max_value
		pc.laugh.add(minf(amount, pc.laugh.max_value * MAX_LAUGH - pc.laugh.value))
	if is_pink(pc) and pc.fatigue:
		pc.fatigue.add(GENTLE_FATIGUE * pc.fatigue.max_value)
	Audio.play("tickle", -12.0 if is_pink(pc) else -7.0, 0.1)


func _draw() -> void:
	var col := ICE if state == "frozen" else COL
	draw_circle(Vector2.ZERO, 7.0, Color(col, 0.18))
	var a := 0.55 + 0.25 * sin(_t * 5.0) if state != "frozen" else 0.9
	var wob := sin(_t * 9.0) * (0.0 if state == "frozen" else 1.0)
	# 掌心 + 五根小手指
	draw_circle(Vector2.ZERO, 3.2, Color(col, a))
	for i in 5:
		var ang := -PI * 0.85 + i * PI * 0.17
		var tip := Vector2.from_angle(ang) * (6.0 + (wob if i % 2 else -wob) * 0.5)
		draw_line(Vector2.from_angle(ang) * 2.5, tip, Color(col, a), 1.6)
	draw_circle(Vector2.ZERO, 1.4, Color(COL_D if state != "frozen" else Color(0.45, 0.65, 0.85), a))
	if state == "frozen":
		draw_arc(Vector2.ZERO, 7.5, 0, TAU, 14, Color(ICE, 0.6), 1.0)
	if stealing:
		draw_string(ThemeDB.fallback_font, Vector2(-6, -12), "……", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.75, 0.72, 0.8, 0.8))

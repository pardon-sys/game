class_name BlindBat
extends Monster
## 遮眼蝠（第八层夜迷宫）：平时倒挂在墙顶上睡觉（看不见、不动）。她身边的冷光暗到 WAKE_LIGHT 以下才醒，
## 从墙顶飞下来（飞的：不被墙挡），扑到她脸上蒙住眼睛 BLIND 秒：状态 blinded（挠痒 ×1.3）、视野缩得很小、屏幕四周变黑
## （DarkSense 负责），翅膀一下下扫脖子（来源键 blind_bat）。
## 甩掉：冲刺一次；时间到了它自己飞走；冰晶结界冻住会掉下来（定住 2 秒）。之后歇 REST 秒再回墙顶。
## 图例：X = monster type=blind_bat

const SHEET := preload("res://assets/generated/maze/blind_bat.png")
const WAKE_LIGHT := 0.4
const BLIND := 3.0
const TICK := 0.5
const TICKLE := 2.0
const REST := 6.0
## 倒挂时画在墙顶上的高度
const PERCH_LIFT := 22.0

var stuck_on: PlayableCharacter
var _stick_t := 0.0
var _tick_t := 0.0
var _rest := 0.0
var _was_dashing := false
var perched := true


func _setup() -> void:
	super()
	add_to_group("maze_magic_reactive")
	add_to_group("blind_bat")
	sprite.texture = SHEET
	sprite.hframes = 3
	sprite.region_enabled = false
	collision_mask = 0


func is_stuck() -> bool:
	return is_instance_valid(stuck_on)


func _dark_enough() -> bool:
	var p := GameState.player as Node2D
	var cl := p.get_node_or_null("CarryLight") as CarryLight if is_instance_valid(p) else null
	return cl != null and cl.level < WAKE_LIGHT


## 碰到她：扑到脸上蒙住眼睛（代替普通的挠一下）。
func tickle(t: Node) -> bool:
	if perched or _rest > 0.0 or is_stuck() or not (t is PlayableCharacter):
		return false
	stuck_on = t
	_stick_t = BLIND
	_tick_t = 0.2
	collision_layer = 0
	stuck_on.add_buff("blinded", BLIND)
	Audio.play("bat_flap", -2.0, 0.1)
	if stuck_on.is_controlled():
		GameState.princess_reacted.emit(MazeLines.pick("bat"), 2.4)
		if not GameState.has_flag("f8m_hint_bat"):
			GameState.set_flag("f8m_hint_bat")
			GameState.hint("被蒙住眼睛了！冲刺甩掉它！")
	return true


func let_go(shaken := false) -> void:
	if not is_stuck():
		return
	var c := stuck_on
	stuck_on = null
	if c.has_buff("blinded"):
		c.remove_buff("blinded")
	collision_layer = 4
	_rest = REST
	z_index = 0
	global_position = c.global_position + Vector2(randf_range(-18, 18), -6)
	Audio.play("bat_flap", -6.0, 0.1, 1.2)
	if shaken:
		SpeechBubble.say(c, "……走、走开……！", 26.0)


func on_ice(_time: float) -> void:
	let_go()
	stun(2.0)


func _tick(delta: float) -> void:
	_rest = maxf(0.0, _rest - delta)
	_t += delta
	if is_stuck():
		_hold(delta)
		return
	# 歇着 / 冷光够亮：回墙顶倒挂
	if _rest > 0.0 or not _dark_enough():
		if not perched:
			var to := _home - global_position
			if to.length() < 3.0:
				perched = true
				velocity = Vector2.ZERO
			else:
				velocity = to.normalized() * stats.wander_speed * 1.5
				move_and_slide()
		target = null
		state = State.WANDER
		_animate(delta)
		return
	perched = false
	super(delta)


func _hold(delta: float) -> void:
	if not stuck_on.is_alive():
		let_go()
		return
	global_position = stuck_on.global_position + Vector2(0, 1)
	z_index = 2
	var dashing := stuck_on.state == PlayableCharacter.State.DASH
	if dashing and not _was_dashing:
		_was_dashing = dashing
		let_go(true)
		return
	_was_dashing = dashing
	if GameState.in_dialogue or CG.is_busy():
		return
	_stick_t -= delta
	if _stick_t <= 0.0:
		let_go()
		return
	stuck_on.add_buff("blinded", maxf(0.2, _stick_t))
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = TICK
		var h := make_tickle(stuck_on, TICKLE)
		h.zone = "neck"
		stuck_on.receive_hit(h)
	_animate(delta)


func _animate(_delta: float) -> void:
	if perched and not is_stuck():
		sprite.frame = 2
		sprite.position.y = -PERCH_LIFT
		sprite.modulate.a = 0.85
		return
	sprite.modulate.a = 1.0
	sprite.frame = int(_t * 10.0) % 2
	# 粘在脸上时画在她头上
	sprite.position.y = -20.0 if is_stuck() else -6.0 + sin(_t * 6.0) * 2.0

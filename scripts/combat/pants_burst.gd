class_name PantsBurst
extends Node2D
## 蓝色公主的主动技能「千手解放」（特训考核后学会：剧情标记 FLAG；技能键 skill = U）：
##   千手痒痒裤的小手全部伸长，一圈扫出去（RADIUS）——范围内的怪定身 STUN 秒、陷阱暂停 TRAP_OFF 秒；
##   副作用：之后 BACKLASH 秒小手收不回来，转过来挠她自己的大腿和屁股（闷笑每秒 +BACKLASH_RATE，状态 pants_backlash 走得慢）。冷却 COOLDOWN 秒。
## PantsBurst.cast(角色) → 释放成功返回 true（没学会 / 冷却中 / 不是蓝色公主返回 false）。可以挂额外的目标回调 extra（考核里推开粉色公主）。

const FLAG := "skill_pants_burst"
const RADIUS := 72.0
const STUN := 3.0
const TRAP_OFF := 3.0
const BACKLASH := 5.0
const BACKLASH_RATE := 0.06
const COOLDOWN := 15.0

static var _ready_at := {}

var caster: PlayableCharacter
var _t := 0.0
var _hit_t := 0.0
var _traps: Array = []


static func learned() -> bool:
	return GameState.has_flag(FLAG)


static func cooldown_left(c: Node) -> float:
	return maxf(0.0, float(_ready_at.get(c.get_instance_id(), 0.0)) - Time.get_ticks_msec() / 1000.0)


static func cast(c: PlayableCharacter) -> bool:
	if not is_instance_valid(c) or c.character_id != "blue" or not learned():
		return false
	if cooldown_left(c) > 0.0:
		GameState.notify("千手解放还要 %.0f 秒" % cooldown_left(c), 1.2)
		return false
	_ready_at[c.get_instance_id()] = Time.get_ticks_msec() / 1000.0 + COOLDOWN
	var n := PantsBurst.new()
	n.caster = c
	n.position = c.position     # 同一个父节点：先摆好位置再进树（_ready 里按位置找范围内的怪）
	c.get_parent().add_child(n)
	return true


func _ready() -> void:
	z_index = 20
	Audio.play("tickle_special", -2.0)
	SiegeFx.ring(get_parent(), global_position + Vector2(0, -8), RADIUS, Color(1.0, 0.72, 0.88, 0.9), 0.5, 0.2)
	for m in get_tree().get_nodes_in_group("enemy"):
		if m is Monster and is_instance_valid(m) and (m as Node2D).global_position.distance_to(global_position) <= RADIUS:
			(m as Monster).stun(STUN)
			HitFx.play("hand", get_parent(), (m as Node2D).global_position + Vector2(0, -8))
	for t in get_tree().get_nodes_in_group("trap"):
		var tr := t as Trap
		if tr and tr.active and tr.global_position.distance_to(global_position) <= RADIUS:
			tr.active = false
			tr._enter(Trap.Phase.IDLE)
			tr.modulate = Color(1.2, 0.8, 1.1)
			_traps.append(tr)
	if is_instance_valid(caster):
		caster.add_buff("pants_backlash", BACKLASH)
		SpeechBubble.say(caster, "……去。", 30.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= TRAP_OFF and not _traps.is_empty():
		for tr in _traps:
			if is_instance_valid(tr):
				tr.active = true
				if tr.trigger_mode == Trap.TriggerMode.CONTINUOUS:
					tr._enter(Trap.Phase.ACTIVE)
				tr.modulate = Color.WHITE
		_traps.clear()
	# 副作用：小手转过来挠她自己
	if is_instance_valid(caster) and _t < BACKLASH:
		global_position = caster.global_position
		if caster.laugh and not GameState.in_dialogue:
			caster.laugh.add(caster.laugh.max_value * BACKLASH_RATE * delta)
		_hit_t -= delta
		if _hit_t <= 0.0:
			_hit_t = 0.4
			var z: String = ["thigh", "butt"].pick_random()
			ZoneFx.play(z, caster.get_parent(), ZoneFx.body_point(caster, z), 1.0, false)
			Audio.play("tickle", -8.0, 0.1)
			if randf() < 0.3:
				SpeechBubble.say(caster, ["……收、回去……", "……唔……！", "……叛徒……"].pick_random(), 30.0, 1.0)
	if _t >= maxf(BACKLASH, TRAP_OFF):
		queue_free()


func _draw() -> void:
	# 伸出去的小手：前 0.4 秒一圈伸长，之后几条缩回她腿上乱动
	var col := Color(1.0, 0.72, 0.88, 0.85)
	if _t < 0.4:
		var r := RADIUS * (_t / 0.4)
		for i in 10:
			var a := TAU * i / 10.0
			draw_line(Vector2(0, -8), Vector2(cos(a), sin(a) * 0.6) * r + Vector2(0, -8), col, 1.5)
			draw_circle(Vector2(cos(a), sin(a) * 0.6) * r + Vector2(0, -8), 2.0, Color(1, 0.86, 0.92))
	elif _t < BACKLASH:
		for i in 4:
			var a := _t * 6.0 + i * 1.6
			draw_line(Vector2(0, -6), Vector2(cos(a) * 6.0, -4 + sin(a) * 3.0), col, 1.5)

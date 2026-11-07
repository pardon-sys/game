class_name ScrubDoll
extends Node2D
## 旧浴场的「搓澡人偶」小 Boss（PalaceBath 生成、每帧 step；标记 scrub；台词 penance_text/palace4.py 的 scrub_*）——抢海绵式：
##   有人走到 MEET_R 以内开打。身上挂着 SPONGES 块海绵（护盾）：先把海绵打掉才打得动本体（HP 下）。
##   掉下来的海绵（Sponge）会自己滚向最近的人，吸住脚（减速 + 挠脚心）。
##   招式（每 ATTACK_EVERY 秒轮流）：长柄刷横扫（BRUSH_R 以内挠腰）/ 抓人（GRAB_R 以内：status.grab，按进泡泡桶刷脚底；
##     第一次抓人演小剧场 bath_scrub_grab（CG），之后在场上抓）。抓着人的时候，另一个人打它 → 松手、踉跄。
##   打倒 → FLAG + 笑脸徽记（PalaceRoom.give_badge("scrub")）；之后浴场的镜子能擦出乐谱片③。
## 测试：phase、sponges、hp、hit_by(pc)、grab(pc)、sponges_alive。

const FLAG := "palace_scrub_down"
const WALK := "res://assets/generated/scrub_doll_walk.png"   # 4×4 走路图
const ACT := "res://assets/generated/scrub_doll_act.png"     # 动作条：0 挥刷 / 1 抓人 / 2 没海绵晕了
const MEET_R := 90.0
const HIT_R := 28.0
const SPONGES := 3
const HP := 8
const SPEED := 34.0
const ATTACK_EVERY := 2.4
const BRUSH_R := 36.0
const GRAB_R := 26.0
const GRAB_TIME := 3.0
const GRAB_PRESSES := 8
const HOLD_TICK := 0.3

var room: PalaceRoom
var home := Vector2.ZERO
var phase := "idle"   # idle / fight / hold / down
var sponges := SPONGES
var hp := HP
var target: PlayableCharacter
var sponges_alive: Array = []
var _atk := ATTACK_EVERY
var _next_grab := false
var _tick := 0.0
var _stagger := 0.0
var _swing := 0.0
var _was := {}
var _look: WalkActLook
var _moved := Vector2.ZERO


func _ready() -> void:
	z_index = 1
	if home == Vector2.ZERO:
		home = position
	_look = WalkActLook.new()
	_look.walk_tex = WALK
	_look.act_tex = ACT
	add_child(_look)
	if GameState.has_flag(FLAG):
		phase = "down"
	_refresh()


func step(delta: float) -> void:
	_swing = maxf(0.0, _swing - delta)
	_stagger = maxf(0.0, _stagger - delta)
	for s in sponges_alive.duplicate():
		if not is_instance_valid(s):
			sponges_alive.erase(s)
		else:
			(s as Sponge).step(delta)
	if phase == "down":
		_refresh()
		return
	var ms: Array = room.members().filter(func(m): return not Downed.is_downed(m as PlayableCharacter))
	if phase == "idle":
		for m in ms:
			if (m as Node2D).global_position.distance_to(home) <= MEET_R:
				phase = "fight"
				_atk = ATTACK_EVERY
				PalaceRoom.say_random(m as Node2D, "scrub_meet")
				SpeechBubble.say(self, "……洗、洗澡的时间……到了……", 40.0, 1.6)
				break
		_refresh()
		return
	# 被打（攻击键按下的那一下、离得够近）
	for m in ms:
		var pc := m as PlayableCharacter
		var atk := pc.state == PlayableCharacter.State.ATTACK
		if atk and not bool(_was.get(pc, false)) and pc.global_position.distance_to(position) <= HIT_R:
			hit_by(pc)
		_was[pc] = atk
	match phase:
		"fight":
			var near := _nearest(ms)
			_moved = Vector2.ZERO
			if near and _stagger <= 0.0:
				var before := position
				position = position.move_toward(near.global_position, SPEED * delta)
				_moved = position - before
			_atk -= delta
			if _atk <= 0.0 and near:
				_atk = ATTACK_EVERY
				if _next_grab and near.global_position.distance_to(position) <= GRAB_R:
					grab(near)
				else:
					_brush(ms)
				_next_grab = not _next_grab
		"hold":
			if not is_instance_valid(target) or not target.status.is_grabbed_by(self):
				_let_go()
			else:
				_tick -= delta
				if _tick <= 0.0:
					_tick = HOLD_TICK
					var h := HitData.make_tickle(self, 2.5)
					h.zone = "sole"
					target.receive_hit(h)
	_refresh()


func _nearest(ms: Array) -> PlayableCharacter:
	var best: PlayableCharacter = null
	for m in ms:
		var pc := m as PlayableCharacter
		if best == null or pc.global_position.distance_to(position) < best.global_position.distance_to(position):
			best = pc
	return best


func _brush(ms: Array) -> void:
	_swing = 0.5
	Audio.play("brush_spin", -6.0)
	for m in ms:
		var pc := m as PlayableCharacter
		if pc.global_position.distance_to(position) <= BRUSH_R:
			for k in 3:
				var h := HitData.make_tickle(self, 2.5)
				h.zone = "waist"
				pc.receive_hit(h)
			PalaceRoom.say_random(pc, "scrub_brush")


## 抓人：第一次演小剧场（CG），之后就在场上抓着刷脚底，等对方挣开或者被另一个人打松手
func grab(pc: PlayableCharacter) -> void:
	if not GameState.has_flag("cg_seen_theater:bath_scrub_grab"):
		phase = "fight"
		_atk = ATTACK_EVERY * 1.5
		await CG.play_theater("bath_scrub_grab")
		_stagger = 1.0
		return
	if not pc.status.grab(self, GRAB_TIME, GRAB_PRESSES):
		return
	phase = "hold"
	target = pc
	_tick = 0.1
	Audio.play("grab", -4.0)
	PalaceRoom.say_random(pc, "scrub_grab")


func _let_go() -> void:
	if is_instance_valid(target) and target.status.is_grabbed_by(self):
		target.status.release()
	target = null
	phase = "fight"
	_stagger = 0.8
	_atk = ATTACK_EVERY


## 被打一下：抓着人 → 松手；有海绵 → 打掉一块（掉在地上会滚过来吸脚）；没海绵 → 掉血
func hit_by(pc: PlayableCharacter) -> void:
	if phase == "down" or phase == "idle":
		return
	Audio.play("hit", -4.0)
	modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)
	if phase == "hold":
		_let_go()
		PalaceRoom.say_random(pc, "scrub_rescue")
	if sponges > 0:
		sponges -= 1
		var sp := Sponge.new()
		sp.room = room
		sp.position = position + Vector2(randf_range(-12, 12), 6)
		room.add_view(sp)
		sponges_alive.append(sp)
		PalaceRoom.say_random(pc, "scrub_sponge")
		_refresh()
		return
	hp -= 1
	_stagger = 0.4
	if hp <= 0:
		_down()


func _down() -> void:
	phase = "down"
	GameState.set_flag(FLAG)
	Audio.play("break", -3.0)
	SpeechBubble.say(self, "……洗……干净了……（咔哒）", 40.0, 2.0)
	PalaceRoom.give_badge("scrub")
	_refresh()


func _refresh() -> void:
	if _look and _look.ready_ok():
		if phase == "down":
			_look.act(2)
			_look.rotation = 0.35
		elif phase == "hold":
			_look.act(1)
		elif _swing > 0.0:
			_look.act(0)
		elif _moved.length() > 0.01:
			_look.walk(_moved, get_process_delta_time())
		else:
			_look.idle()
	queue_redraw()


func _draw() -> void:
	if phase != "down" and phase != "idle":
		# 身上还剩几块海绵：头顶几个小黄点
		for i in sponges:
			draw_circle(Vector2(-6 + i * 6, -54), 2.5, Color(1.0, 0.88, 0.3))
	if _look == null or not _look.ready_ok():
		draw_circle(Vector2(0, -20), 14.0, Color(0.95, 0.92, 0.95))
		draw_circle(Vector2(0, -38), 9.0, Color(0.98, 0.9, 0.88))


## 掉在地上的海绵：慢慢滚向最近的人，碰到 → 吸住脚（减速）+ 挠一下脚心，然后「噗」地瘪掉
class Sponge extends Node2D:
	const SPEED := 30.0
	const LIFE := 10.0
	var room: PalaceRoom
	var _t := 0.0
	var _s: Sprite2D

	func _ready() -> void:
		z_index = 1
		if ResourceLoader.exists(PalaceRoom.EVENTS2):
			_s = Sprite2D.new()
			_s.texture = load(PalaceRoom.EVENTS2)
			_s.hframes = 8
			_s.frame = 0
			_s.offset = Vector2(0, -8)
			_s.scale = Vector2(0.45, 0.45)
			_s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_s)

	func step(delta: float) -> void:
		_t += delta
		if _t > LIFE:
			queue_free()
			return
		var near: PlayableCharacter = null
		for m in room.members():
			var pc := m as PlayableCharacter
			if near == null or pc.global_position.distance_to(global_position) < near.global_position.distance_to(global_position):
				near = pc
		if near == null:
			return
		position = position.move_toward(near.global_position, SPEED * delta)
		if _s:
			_s.rotation += delta * 4.0
		if near.global_position.distance_to(global_position) <= 8.0:
			near.status.apply_slow(0.5, 2.0)
			for k in 2:
				var h := HitData.make_tickle(self, 2.0)
				h.zone = "sole"
				near.receive_hit(h)
			PalaceRoom.say_random(near, "scrub_stick")
			Audio.play("bubble_pop", -6.0)
			queue_free()

	func _draw() -> void:
		if _s == null:
			draw_circle(Vector2(0, -4), 4.0, Color(1.0, 0.88, 0.3))

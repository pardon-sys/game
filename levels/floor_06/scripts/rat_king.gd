class_name RatKing
extends Node2D
## 鼠洞底的胖鼠王（RatTunnel 生成、每帧 step；粉色公主一个人打。台词 penance_text/tunnel.py 的 king_*）：躲猫猫式——
##   她走进洞底（king 标记 MEET_R 以内）→ 开打（phase under）。
##   under：钻在地下 DIVE_TIME 秒 → 从一个没堵上的洞口（king_holes）冒头（peek，PEEK_TIME 秒）：
##     她在 WHISKER_R 以内就被胡子扫脚心；冒头时被她打到 → 缩回去（hits_peek +1）。
##   堵洞：洞口按 E（HoleSpot），鼠王不在这个洞里冒头时就堵上（她定身 PLUG_TIME 秒）。
##   只剩一个洞没堵 → 它从最后那个洞被逼出来（out）：追她，每 SWIPE_EVERY 秒扫一次胡子；打 HP 下就倒。
##   她笑到失控（laugh.is_helpless）→ 小剧场 tunnel_rat_king_fail（CG）→ 洞口全开、回洞底门口重来。
##   打倒 → FLAG（PalaceRoom.give_badge("rat_king")：一枚笑脸徽记）→ RatTunnel 接着演 tunnel_revenge。
## 测试：phase、hp、holes、plugged、plug(i)、peek_at(i)、hit_now()、fail_now()。

const FLAG := "tunnel_rat_king_down"
const WALK := "res://assets/generated/rat_king_walk.png"   # 4×4 走路图
const ACT := "res://assets/generated/rat_king_act.png"     # 动作条：0 洞里探头 / 1 晕 / 2 扫胡子
const MEET_R := 100.0
const DIVE_TIME := 1.2
const PEEK_TIME := 2.6
const WHISKER_R := 26.0
const HIT_R := 24.0
const PLUG_TIME := 1.0
const HP := 5
const SPEED := 38.0
const SWIPE_EVERY := 2.0
const SWIPE_R := 30.0

var tunnel: RatTunnel
var holes: Array[Vector2] = []
var plugged: Array[bool] = []
var home := Vector2.ZERO
var phase := "idle"   # idle / under / peek / out / down
var hp := HP
var at_hole := -1
var _t := 0.0
var _anim := 0.0
var _swipe := 0.0
var _whisk := 0.0
var _was_attacking := false
var _stagger := 0.0
var _look: WalkActLook
var _moved := Vector2.ZERO
var _hole_views: Array = []


func _ready() -> void:
	z_index = 2
	_look = WalkActLook.new()
	_look.walk_tex = WALK
	_look.act_tex = ACT
	add_child(_look)
	if GameState.has_flag(FLAG):
		phase = "down"
	_refresh()


## 洞口（RatTunnel._ready 里调；每个洞口一个 HoleSpot，挂在 Entities 下面各自投影）
func setup(host: Node, hole_cells: Array, king_cell: Vector2i) -> void:
	home = Cells.to_world(king_cell)
	position = home
	for c in hole_cells:
		holes.append(Cells.to_world(c))
		plugged.append(false)
		var hv := HoleSpot.new()
		hv.king = self
		hv.idx = holes.size() - 1
		hv.position = holes[holes.size() - 1]
		host.add_child.call_deferred(hv)
		_hole_views.append(hv)


func plugged_count() -> int:
	return plugged.count(true)


func open_holes() -> Array[int]:
	var out: Array[int] = []
	for i in holes.size():
		if not plugged[i]:
			out.append(i)
	return out


func active() -> bool:
	return phase in ["under", "peek", "out"]


func step(p: PlayableCharacter, delta: float) -> void:
	_anim += delta
	if phase == "down":
		return
	if phase == "idle":
		if p.global_position.distance_to(home) <= MEET_R:
			if not GameState.has_flag(INTRO_FLAG):
				_intro()
				return
			phase = "under"
			_t = DIVE_TIME
			_say(p, "king_meet")
		_refresh()
		return
	if p.laugh and p.laugh.is_helpless():
		fail_now()
		return
	var attacking := p.state == PlayableCharacter.State.ATTACK
	var swing := attacking and not _was_attacking
	_was_attacking = attacking
	match phase:
		"under":
			_t -= delta
			if _t <= 0.0:
				var open := open_holes()
				var pick := open.filter(func(i): return i != at_hole)
				peek_at(int((pick if not pick.is_empty() else open).pick_random()))
		"peek":
			_t -= delta
			_whisk -= delta
			if p.global_position.distance_to(position) <= WHISKER_R and _whisk <= 0.0:
				_whisk = 0.45
				var hw := HitData.make_tickle(self, 3.0)
				hw.zone = "sole"
				p.receive_hit(hw)
				_say(p, "king_whisker", 3.0)
			if swing and p.global_position.distance_to(position) <= HIT_R:
				hit_now()
			elif _t <= 0.0:
				_dive()
		"out":
			_stagger = maxf(0.0, _stagger - delta)
			if _stagger <= 0.0:
				var before := position
				position = position.move_toward(p.global_position, SPEED * delta)
				_moved = position - before
			_swipe -= delta
			if _swipe <= 0.0 and p.global_position.distance_to(position) <= SWIPE_R:
				_swipe = SWIPE_EVERY
				for i in 3:
					var h := HitData.make_tickle(self, 3.5)
					h.zone = "sole"
					p.receive_hit(h)
				_say(p, "king_swipe", 2.5)
			if swing and p.global_position.distance_to(position) <= HIT_R:
				hit_now()
	_refresh()


## 第一次走进洞底：开场过场（笑脸徽记的来历），演完再开打
const INTRO_FLAG := "tunnel_king_intro"


func _intro() -> void:
	GameState.set_flag(INTRO_FLAG)
	phase = "out_intro"
	position = home
	visible = true
	if _look:
		_look.idle()
	await Cutscene.play("tunnel_king_in")
	while Cutscene.is_playing():
		await get_tree().process_frame
	phase = "under"
	_t = DIVE_TIME
	_refresh()


func peek_at(i: int) -> void:
	at_hole = i
	position = holes[i]
	phase = "peek"
	_t = PEEK_TIME
	_refresh()
	Audio.play("pop", -6.0, 0.15, 1.4)
	SpeechBubble.say(self, str((RatTunnel.data().get("king_peek", ["吱！"]) as Array).pick_random()), 30.0, 1.2)


func _dive() -> void:
	phase = "under"
	_t = DIVE_TIME
	position = home
	_refresh()


## 被她打到：冒头时 → 缩回去；被逼出来以后 → 掉血、踉跄
func hit_now() -> void:
	Audio.play("hit", -4.0)
	if phase == "peek":
		_say(GameState.player, "king_hit")
		_dive()
		return
	if phase != "out":
		return
	hp -= 1
	_stagger = 0.6
	var tw := create_tween()
	modulate = Color(1.6, 1.6, 1.6)
	tw.tween_property(self, "modulate", Color.WHITE, 0.2)
	if hp <= 0:
		_defeated()


## 堵洞口（HoleSpot 按 E）：鼠王正从这个洞冒头时不行
func plug(i: int) -> bool:
	if plugged[i] or (phase == "peek" and at_hole == i) or phase == "down":
		if phase == "peek" and at_hole == i:
			_say(GameState.player, "king_plug_busy")
		return false
	plugged[i] = true
	var p := GameState.player as PlayableCharacter
	if p:
		p.status.apply_root(PLUG_TIME)
	Audio.play("drop", -4.0, 0.1, 0.7)
	_say(p, "king_plug")
	if phase == "idle":
		phase = "under"
		_t = DIVE_TIME
	var open := open_holes()
	if open.size() == 1 and phase != "out":
		_come_out(open[0])
	return true


func _come_out(i: int) -> void:
	at_hole = i
	position = holes[i]
	phase = "out"
	hp = HP
	_swipe = SWIPE_EVERY
	_refresh()
	SpeechBubble.say(self, str((RatTunnel.data().get("king_out", ["吱——！"]) as Array)[0]), 30.0, 2.2)
	Audio.play("unlock", -6.0, 0.0, 0.6)


func _defeated() -> void:
	phase = "down"
	GameState.set_flag(FLAG)
	_say(GameState.player, "king_win")
	PalaceRoom.give_badge("rat_king")
	_refresh()


## 输了：小剧场（CG）→ 洞口全开、回洞底门口
func fail_now() -> void:
	phase = "idle"
	_refresh()
	await CG.play_theater("tunnel_rat_king_fail")
	reset()
	var p := GameState.player
	if is_instance_valid(p):
		p.global_position = tunnel.checkpoint
		if p.get("camera"):
			p.camera.reset_smoothing()


func reset() -> void:
	for i in plugged.size():
		plugged[i] = false
	phase = "idle" if not GameState.has_flag(FLAG) else "down"
	hp = HP
	at_hole = -1
	position = home
	_refresh()


func _say(p: Node, key: String, cool := 0.0) -> void:
	if p == null:
		return
	if cool > 0.0 and _anim - float(get_meta("said_" + key, -99.0)) < cool:
		return
	set_meta("said_" + key, _anim)
	var lines: Array = RatTunnel.data().get(key, []) as Array
	if not lines.is_empty():
		GameState.princess_reacted.emit(str(lines.pick_random()), 2.0)


func _refresh() -> void:
	visible = phase in ["peek", "out", "down", "out_intro"]
	if _look and _look.ready_ok():
		match phase:
			"peek":
				_look.act(0)
				_look.bob(-absf(sin(_anim * 6.0)) * 2.0)
			"out":
				_look.bob(0.0)
				if _swipe > SWIPE_EVERY - 0.4:
					_look.act(2)
				elif _stagger > 0.0:
					_look.act(1)
				elif _moved.length() > 0.01:
					_look.walk(_moved, get_process_delta_time())
				else:
					_look.idle()
			"down":
				_look.bob(0.0)
				_look.act(1)
			_:
				_look.idle()
	queue_redraw()


func _draw() -> void:
	if _look and _look.ready_ok():
		return
	var c := Color(0.6, 0.58, 0.62)
	draw_circle(Vector2(0, -10), 10.0 if phase != "peek" else 6.0, c)
	draw_rect(Rect2(-4, -22, 8, 4), Color(0.95, 0.8, 0.3))


## 洞口：画一个黑洞（堵上了画一堆石头），按 E 堵上
class HoleSpot extends Node2D:
	const PROPS := "res://assets/generated/palace_events.png"
	var king: RatKing
	var idx := 0
	var _rocks: Sprite2D

	func _ready() -> void:
		z_index = 0
		var area := Interactable.new()
		var shape := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 12.0
		shape.shape = c
		area.add_child(shape)
		add_child(area)
		if ResourceLoader.exists(PROPS):
			_rocks = Sprite2D.new()
			_rocks.texture = load(PROPS)
			_rocks.hframes = 6
			_rocks.frame = 5
			_rocks.offset = Vector2(0, -10)
			_rocks.scale = Vector2(0.7, 0.7)
			_rocks.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_rocks)

	func on_interact(_player: Node) -> void:
		if is_instance_valid(king):
			king.plug(idx)

	func _process(_d: float) -> void:
		if not is_instance_valid(king):
			return
		var done := king.plugged[idx]
		if _rocks:
			_rocks.visible = done
		var it := get_child(0) as Interactable
		if it:
			it.enabled = not done and king.phase != "down"
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, IsoView.ground_scale())
		draw_circle(Vector2.ZERO, 8.0, Color(0.12, 0.08, 0.06, 0.9))
		draw_arc(Vector2.ZERO, 8.0, 0, TAU, 20, Color(0.45, 0.32, 0.2), 1.5)
		draw_set_transform(Vector2.ZERO)
		if king and king.plugged[idx] and _rocks == null:
			for o in [Vector2(-4, -3), Vector2(3, -4), Vector2(0, -7)]:
				draw_circle(o, 3.5, Color(0.55, 0.52, 0.5))

class_name PalaceLibrary
extends PalaceRoom
## 第四章④·图书馆（floor_06_palace_library，等距；布局 quest_maps._palace_library；台词 penance_text/palace2.py）：
##   书架里的手（shelf_hands）：从旁边走过被抓住脚踝（定身一下 + 挠脚底）；可以读的书（books，有打码；第六本是「书房管理记录」——残页越多看得越清楚）；
##   倒塌的书山（book_piles）：踩上去塌下来埋住半身（定身、书虫钻进袜子挠），搭档走过来 DIG_TIME 秒挖出来（AI 自动去）；
##   书山下的残页（fragment）；书虫（worms）：追人钻进袜子；羽毛笔（quills）：在空中绕圈，隔一会儿俯冲下来在脚底「写字」，被攻击就掉；
##   禁书区的金色大书（golden_book，对话 call palace_golden）：投影「那天晚上」（过场 library_flashback）→ 书变成恶作剧书怪（小剧场 library_bookmonster）；
##   密码门（cipher_door，对话里转四个铜轮 2-5-7-3，对了 call palace_cipher_ok → CIPHER_FLAG，门打开）→ 私人书房（study：过场 library_study，大线索）。
## 测试：buried、dig(who)、quills、worms、open_cipher()、golden()。

const MAP := "floor_06_palace_library"
const CIPHER_FLAG := "palace_cipher_open"
const STUDY_FLAG := "palace_study_seen"
const HAND_R := 18.0   # 手长在书架上（书架占一格），从旁边那格走过也够得着
const HAND_COOL := 3.0
const PILE_R := 9.0
const DIG_R := 16.0
const DIG_TIME := 1.5
const WORM_SPEED := 22.0
const QUILL_EVERY := 4.0

var buried := {}            # 人 -> 挖的进度
var piles_down := {}
var worms: Array = []
var quills: Array = []
var _hand_t := {}
var _door: StaticBody2D
var _door_view: Node2D


func map_id() -> String:
	return MAP


func _ready() -> void:
	super()
	var bi := 0
	for c in cells("books"):
		bi += 1
		_spot("floor_06/library_book_%d" % bi, c)
	_spot("floor_06/library_fragment", cells("fragment")[0])
	_spot("floor_06/library_door", cells("cipher_door")[0] + Vector2i(0, 1))
	_spot("floor_06/library_golden", cells("golden_book")[0])
	if not GameState.has_flag(CIPHER_FLAG):
		_door = _block(cells("cipher_door")[0])
		_door_view = CipherDoor.new()
		_door_view.position = world(cells("cipher_door")[0])
		add_view(_door_view)
	for c in cells("shelf_hands"):
		var h := HandMark.new()
		h.position = world(c)
		add_view(h)
	for c in cells("book_piles") + cells("fragment"):
		var pm := PileMark.new()
		pm.cell = c
		pm.room = self
		pm.position = world(c)
		add_view(pm)
	for c in cells("worms"):
		var w := Worm.new()
		w.room = self
		w.home = world(c)
		w.position = w.home
		add_view(w)
		worms.append(w)
	for c in cells("quills"):
		for k in 2:
			var q := Quill.new()
			q.room = self
			q.home = world(c)
			q.phase = k * PI
			q.t = randf() * QUILL_EVERY
			q.position = q.home
			add_view(q)
			quills.append(q)


func _spot(dialogue: String, c: Vector2i) -> void:
	var sp := PrisonOddities.Spot.new()
	sp.dialogue = dialogue
	add_child(sp)
	sp.global_position = world(c)


func _block(c: Vector2i) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 16)
	sh.shape = r
	body.add_child(sh)
	add_child(body)
	body.global_position = PalaceRoom.cell_pos(c)
	return body


func _process(delta: float) -> void:
	if busy():
		return
	# 私人书房
	if GameState.has_flag(CIPHER_FLAG) and not GameState.has_flag(STUDY_FLAG):
		for m in members():
			if (m as Node2D).global_position.distance_to(world(cells("study")[0])) <= 24.0:
				GameState.set_flag(STUDY_FLAG)
				Cutscene.play("library_study")
				return
	for m in members():
		var pc := m as PlayableCharacter
		if Downed.is_downed(pc):
			continue
		_tick_hands(pc, delta)
		_tick_piles(pc, delta)
	for w in worms:
		(w as Worm).step(delta)
	for q in quills:
		(q as Quill).step(delta)


func _tick_hands(pc: PlayableCharacter, delta: float) -> void:
	for c in cells("shelf_hands"):
		var k := str(c) + str(pc.get_instance_id())
		_hand_t[k] = maxf(0.0, float(_hand_t.get(k, 0.0)) - delta)
		if float(_hand_t[k]) <= 0.0 and pc.global_position.distance_to(world(c)) <= HAND_R:
			_hand_t[k] = HAND_COOL
			pc.status.apply_root(1.0)
			var h := HitData.make_tickle(self, 7.0)
			h.zone = "sole"
			pc.receive_hit(h)
			PalaceRoom.say_random(pc, "hands")


## 书山：踩上去塌下来，埋住半身；搭档在旁边站 DIG_TIME 秒挖出来
func _tick_piles(pc: PlayableCharacter, delta: float) -> void:
	if buried.has(pc):
		pc.status.apply_root(0.2)
		tickle(pc, "buried", 0.8, 2.0, "sole", delta)
		var other := Duo.partner_of(pc) if Duo.active else null
		if other and not Downed.is_downed(other) and not buried.has(other) and other.global_position.distance_to(pc.global_position) <= DIG_R:
			buried[pc] = float(buried[pc]) + delta
			if float(buried[pc]) >= DIG_TIME:
				dig(pc)
		return
	for c in cells("book_piles") + cells("fragment"):
		if not piles_down.has(c) and pc.global_position.distance_to(world(c)) <= PILE_R:
			piles_down[c] = true
			buried[pc] = 0.0
			Audio.play("rumble", -6.0, 0.0, 1.4)
			Fx.burst(pc.get_parent(), pc.global_position + Vector2(0, -8), "dust", 14, 40.0, 0.6, Vector2(0, -10), Color(0.8, 0.72, 0.6))
			PalaceRoom.say_random(pc, "pile")
			return


func dig(pc: PlayableCharacter) -> void:
	buried.erase(pc)
	pc.status.clear_root()
	PalaceRoom.say_random(pc, "dig")


func open_cipher() -> void:
	GameState.set_flag(CIPHER_FLAG)
	if is_instance_valid(_door):
		_door.queue_free()
	if is_instance_valid(_door_view):
		_door_view.queue_free()
	Audio.play("unlock", -2.0)


## 金色大书：投影「那天晚上」→ 恶作剧书怪
func golden() -> void:
	await Cutscene.play("library_flashback")
	while Cutscene.is_playing():
		await get_tree().process_frame
	await CG.play_theater("library_bookmonster")


func ai_hooks() -> BattleAIHooks:
	return LibHooks.new(self)


class LibHooks extends BattleAIHooks:
	var r: PalaceLibrary

	func _init(room: PalaceLibrary) -> void:
		r = room

	func objective_for(ai: PlayableCharacter) -> Variant:
		var other := partner_of(ai)
		if other and r.buried.has(other):
			return other.global_position
		return null

	func priority_target() -> Variant:
		var p := GameState.player
		for q in r.quills:
			if is_instance_valid(q) and (q as Quill).alive() and is_instance_valid(p) and (q as Node2D).position.distance_to(p.global_position) < 70.0:
				return q
		return null


## 密码门：嵌着四个铜轮的厚木门（开了就消失）
class CipherDoor extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-9, -30, 18, 30), Color(0.36, 0.22, 0.14))
		draw_rect(Rect2(-9, -30, 18, 30), Color(0.2, 0.12, 0.08), false, 1.0)
		draw_line(Vector2(0, -30), Vector2(0, 0), Color(0.24, 0.15, 0.1), 1.0)
		for i in 4:
			var c := Vector2(-4.5 + (i % 2) * 9, -22 + (i / 2) * 9)
			draw_circle(c, 3.0, Color(0.8, 0.6, 0.25))
			draw_circle(c, 1.2, Color(0.45, 0.3, 0.12))


## 书架里伸出来的手（缩在书缝里一抖一抖）
class HandMark extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var w := sin(_t * 6.0) * 1.5
		CurseHand.draw_hand(self, Vector2(0, -6 + w), 0.55, Color(0.95, 0.85, 0.75), Color(0.6, 0.45, 0.35), 0.8, sin(_t * 9.0))


## 书山（塌了以后变成一摊散书）
class PileMark extends Node2D:
	var room: PalaceLibrary
	var cell: Vector2i

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var down := room != null and room.piles_down.has(cell)
		var cols := [Color(0.6, 0.25, 0.25), Color(0.25, 0.4, 0.6), Color(0.55, 0.5, 0.25), Color(0.35, 0.5, 0.3)]
		if down:
			for k in 6:
				draw_rect(Rect2(Vector2(-10 + k * 4, -3 + (k % 2) * 2), Vector2(6, 3)), cols[k % 4])
			return
		for k in 6:
			draw_rect(Rect2(Vector2(-6 + (k % 2) * 2, -4 - k * 3), Vector2(12 - (k % 3), 3)), cols[k % 4])


## 书虫：追离得近的人，钻进袜子里挠一会儿
class Worm extends Node2D:
	var room: PalaceLibrary
	var home := Vector2.ZERO
	var _cool := 0.0
	var _in: PlayableCharacter
	var _in_t := 0.0
	var _t := 0.0

	func step(delta: float) -> void:
		_t += delta
		_cool = maxf(0.0, _cool - delta)
		if _in:
			_in_t -= delta
			position = _in.global_position
			room.tickle(_in, "worm", 0.5, 2.0, "sole", delta, self)
			if _in_t <= 0.0:
				_in = null
				position = home
				show()
			return
		var near: PlayableCharacter = null
		for c in room.members():
			var pc := c as PlayableCharacter
			if not Downed.is_downed(pc) and pc.global_position.distance_to(position) <= 70.0 and (near == null or pc.global_position.distance_to(position) < near.global_position.distance_to(position)):
				near = pc
		if near:
			var to := near.global_position - position
			position += to.normalized() * PalaceLibrary.WORM_SPEED * delta
			if to.length() <= 8.0 and _cool <= 0.0:
				_cool = 8.0
				_in = near
				_in_t = 3.0
				hide()
				PalaceRoom.say_random(near, "worm")
		queue_redraw()

	func _draw() -> void:
		for k in 4:
			draw_circle(Vector2(-6 + k * 4, -2 + sin(_t * 8.0 + k) * 1.0), 2.2, Color(0.6, 0.8, 0.4))
		draw_circle(Vector2(7, -3), 1.0, Color(0.1, 0.1, 0.1))


## 羽毛笔：绕着出生点飞，隔一会儿俯冲到最近的人脚底「写字」；被攻击就掉
class Quill extends Node2D:
	var room: PalaceLibrary
	var home := Vector2.ZERO
	var phase := 0.0
	var t := 0.0
	var down := 0.0
	var _dive: PlayableCharacter
	var _dive_t := 0.0

	func alive() -> bool:
		return down <= 0.0

	func step(delta: float) -> void:
		queue_redraw()
		if down > 0.0:
			down -= delta
			if down <= 0.0:
				show()
			return
		for c in room.members():
			var pc := c as PlayableCharacter
			if pc.state == PlayableCharacter.State.ATTACK and pc.global_position.distance_to(position) <= 18.0:
				down = 10.0
				hide()
				Fx.burst(get_parent(), position + Vector2(0, -10), "dust", 8, 30.0, 0.5, Vector2(0, -6), Color(0.15, 0.12, 0.3))
				return
		t += delta
		if _dive:
			_dive_t -= delta
			position = position.move_toward(_dive.global_position, 90.0 * delta)
			if position.distance_to(_dive.global_position) <= 6.0:
				room.tickle(_dive, "quill", 0.3, 2.5, "sole", delta, self)
			if _dive_t <= 0.0:
				if position.distance_to(_dive.global_position) <= 10.0:
					PalaceRoom.say_random(_dive, "quill")
				_dive = null
			return
		position = home + Vector2(cos(t * 1.5 + phase), sin(t * 1.5 + phase)) * 24.0
		if fmod(t, PalaceLibrary.QUILL_EVERY) < delta:
			var best: PlayableCharacter = null
			for c in room.members():
				var pc := c as PlayableCharacter
				if not Downed.is_downed(pc) and pc.global_position.distance_to(home) <= 110.0:
					best = pc
			if best:
				_dive = best
				_dive_t = 1.4

	func _draw() -> void:
		var tilt := sin(t * 4.0) * 0.4
		var tip := Vector2(0, -6).rotated(tilt)
		var top := Vector2(0, -22).rotated(tilt)
		draw_line(tip, top, Color(0.95, 0.95, 1.0), 3.0)
		draw_line(tip, tip + Vector2(0, 3).rotated(tilt), Color(0.15, 0.12, 0.3), 1.5)
		for k in 3:
			draw_line(top.lerp(tip, 0.2 + k * 0.2), top.lerp(tip, 0.2 + k * 0.2) + Vector2(4, -2).rotated(tilt), Color(0.9, 0.9, 1.0), 1.0)

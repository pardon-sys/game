class_name PalaceThrone
extends PalaceRoom
## 第四章⑩·王座间 Boss「封笑的女王画像」（floor_06_palace_throne；台词 penance_text/palace3.py；配乐 palace_boss）：
##   破绽在王座前（weak_point()）：站在 HIT_R 里攻击扣一格。三层画布：
##   第一层（layer 0，LAYER_HP[0]）：颜料泼洒（PaintPool：先出预警圈（danger 组，AI 会躲）再变成颜料坑，踩进去脚底沾颜料 → 画笔追着刷 PAINTED 秒）
##     + 画像小手（离画像太近被抓：定身 + 挠腋窝）；破了 → 过场 throne_layer_1（胡话）→
##   第二层（layer 1）：墙上四幅小画像（SmallPortrait，各 SMALL_HP）醒来、隔一会儿甩出画出来的手（PaintHand 飞过来）；小画像全打掉 → 大画像露出破绽 VULN_TIME 秒
##     （之后小画像又醒过来）；破了 → 过场 throne_layer_2 →
##   第三层（layer 2）：画像把玩家操控的那个人拉进画里（paint_start，旁边 paint_gate 一直挡着）：在画里自己躲开画笔（brushes 巡逻）跑到画框出口（paint_exit）
##     → 出来 → 过场 throne_finale（两人各释放一次、画布烧穿）→ 胜利；
##     失败（闷笑满 / 超过 PAINT_TIME）→ 小剧场 throne_painting_trapped（CG）→ 画框变强（empowered，FRAME_HP、颜料更快），换外面的人操控；
##     把变强的画框打破 → 画里的人出来 → throne_finale → 胜利。
##   胜利：BOSS_FLAG → 过场 palace_end（另半枚徽章、摇篮曲、章末「第四章　旧王宫　完」）。
##   两个都倒下：按在哪一层输播不同的小剧场（都有 CG）：第一层 throne_fail_paint（被涂成画）、第二层 throne_fail_tea（小画像的茶会）、
##     第三层画框变强以后 throne_fail_frame（两个人都被画进画里）、第三层其他时候 throne_fail（画像小手按在王座台阶上）→ 回入口，当前这一层回满。
##   逃出画：小剧场 throne_escape（短）→ throne_finale。
## 测试：layer、hp、vulnerable()、hit(n)、pools、small、pull()、inside、escape()、fail_inside()、empowered、frame_hp、win。

const MAP := "floor_06_palace_throne"
const BOSS_FLAG := "palace_boss_done"
const LAYER_HP := [12, 10]
const HIT_R := 34.0
const HIT_COOL := 0.35
const PAINT_EVERY := 4.5
const PAINT_EVERY_ANGRY := 2.6
const POOL_WARN := 1.0
const POOL_LIFE := 6.0
const POOL_R := 14.0
const PAINTED := 3.0
const HAND_EVERY := 5.0
const HAND_R := 70.0
const SMALL_HP := 4
const SMALL_SHOT := 3.5
const VULN_TIME := 9.0
const PULL_DELAY := 1.5
const PAINT_TIME := 45.0
const BRUSH_SPEED := 46.0
const FRAME_HP := 10
## 追加事件：女王的八音盒（石像问答的奖励，背包里放在 R 键上）：每场 BOX_USES 次，画像发呆 BOX_TIME 秒、一直露破绽，不泼颜料不伸手
const BOX_TIME := 8.0
const BOX_USES := 2
var box_t := 0.0
var box_used := 0

var layer := 0
var hp := 12
var started := false
var win := false
var pools: Array = []
var painted := {}
var small: Array = []
var vuln_t := 0.0
var inside: PlayableCharacter
var inside_t := 0.0
var empowered := false
var frame_hp := 0
var brushes: Array = []
var _paint_t := 2.0
var _hand_t := HAND_EVERY
var _hit_cool := {}
var _pull_t := -1.0
var _portrait: PortraitView
var _gate: StaticBody2D
var _gib_t := 12.0


func map_id() -> String:
	return MAP


func _ready() -> void:
	super()
	win = GameState.has_flag(BOSS_FLAG)
	_portrait = PortraitView.new()
	_portrait.room = self
	_portrait.position = world(cells("portrait")[0]) + Vector2(0, 8)
	add_view(_portrait)
	_gate = StaticBody2D.new()
	_gate.collision_layer = 1
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 16)
	sh.shape = r
	_gate.add_child(sh)
	add_child(_gate)
	_gate.global_position = PalaceRoom.cell_pos(cells("paint_gate")[0])
	var i := 0
	for c in cells("small_portraits"):
		var s := SmallPortrait.new()
		s.room = self
		s.idx = i
		s.position = world(c)
		add_view(s)
		small.append(s)
		i += 1
	for c in cells("brushes"):
		var b := Brush.new()
		b.room = self
		b.home = world(c)
		b.position = b.home
		add_view(b)
		brushes.append(b)
	hp = LAYER_HP[0]
	if GameState.inventory.has("queen_music_box") and not win:
		GameState.set_hotkey("use_special", "queen_music_box")
		GameState.notify("「女王的八音盒」放在 R 键上了（每场能用 %d 次）" % BOX_USES)


func weak_point() -> Vector2:
	return world(cells("throne")[0]) + Vector2(0, -6)


func vulnerable() -> bool:
	if win or inside != null and not empowered:
		return false
	if box_t > 0.0:
		return true
	if layer == 1:
		return vuln_t > 0.0
	return true


func _process(delta: float) -> void:
	if win or busy():
		return
	if not started:
		started = true
		return
	_tick_hits(delta)
	box_t = maxf(0.0, box_t - delta)
	if box_t <= 0.0:
		_tick_paint(delta)
		_tick_hands(delta)
	if layer == 1:
		vuln_t = maxf(0.0, vuln_t - delta)
		if vuln_t <= 0.0 and small.all(func(s): return not (s as SmallPortrait).alive()):
			for s in small:
				(s as SmallPortrait).revive()
	if layer == 2:
		if _pull_t > 0.0:
			_pull_t -= delta
			if _pull_t <= 0.0:
				pull()
		if inside and not empowered:
			inside_t += delta
			for b in brushes:
				(b as Brush).step(delta)
			if inside.global_position.distance_to(world(cells("paint_exit")[0])) <= 14.0:
				escape()
			elif inside_t >= PAINT_TIME or Downed.is_downed(inside) or inside.laugh.value >= inside.laugh.max_value * 0.95:
				fail_inside()
	_gib_t -= delta
	if _gib_t <= 0.0:
		_gib_t = randf_range(10.0, 16.0)
		SpeechBubble.say(_portrait, str(PalaceRoom.data().get("gibberish", [""]).pick_random()), 40.0, 2.5)


## 打开八音盒：放出很久以前的笑声，画像发呆露破绽（被拉进画里的时候没用）
func use_music_box() -> bool:
	if win or box_used >= BOX_USES or (inside != null and not empowered):
		GameState.notify("八音盒的发条转不动了……" if box_used >= BOX_USES else "现在打开它没有用……")
		return false
	box_used += 1
	box_t = BOX_TIME
	_clear_pools()
	Audio.play("music_box", -2.0)
	SpeechBubble.say(_portrait, str((PalaceRoom.data().get("box_gibberish", ["……这个声音……"]) as Array).pick_random()), 40.0, 3.0)
	GameState.notify("八音盒响了——画像发起呆来（还能用 %d 次）" % (BOX_USES - box_used))
	return true


# ------------------------------------------------------------------ 打破绽
func _tick_hits(delta: float) -> void:
	for k in _hit_cool.keys():
		_hit_cool[k] = maxf(0.0, float(_hit_cool[k]) - delta)
	for m in members():
		var pc := m as PlayableCharacter
		if pc == inside and not empowered:
			continue
		if pc.state != PlayableCharacter.State.ATTACK and pc.state != PlayableCharacter.State.CAST:
			continue
		var k := pc.get_instance_id()
		if float(_hit_cool.get(k, 0.0)) > 0.0:
			continue
		# 小画像
		for s in small:
			var sp := s as SmallPortrait
			if sp.alive() and pc.global_position.distance_to(sp.position) <= 24.0:
				_hit_cool[k] = HIT_COOL
				sp.hurt()
				if layer == 1 and small.all(func(x): return not (x as SmallPortrait).alive()):
					vuln_t = VULN_TIME
					PalaceRoom.say_random(pc, "weak")
				break
		if float(_hit_cool.get(k, 0.0)) > 0.0:
			continue
		if vulnerable() and pc.global_position.distance_to(weak_point()) <= HIT_R:
			_hit_cool[k] = HIT_COOL
			hit(1)


func hit(n: int) -> void:
	if empowered:
		frame_hp -= n
		_portrait.flash()
		if frame_hp <= 0:
			_free_inside()
		return
	if layer >= 2:
		return
	hp -= n
	_portrait.flash()
	Audio.play("gate", -6.0, 0.0, 1.5)
	if hp <= 0:
		_break_layer()


func _break_layer() -> void:
	_clear_pools()
	var id := "throne_layer_%d" % (layer + 1)
	layer += 1
	await Cutscene.play(id)
	while Cutscene.is_playing():
		await get_tree().process_frame
	if layer == 1:
		hp = LAYER_HP[1]
		for s in small:
			(s as SmallPortrait).revive()
		PalaceRoom.say_random(GameState.player, "small_up")
	elif layer == 2:
		for s in small:
			(s as SmallPortrait).sleep()
		_pull_t = PULL_DELAY


# ------------------------------------------------------------------ 颜料 / 画像小手
func _tick_paint(delta: float) -> void:
	_paint_t -= delta
	if _paint_t <= 0.0:
		_paint_t = PAINT_EVERY_ANGRY if empowered else PAINT_EVERY
		for m in members():
			if m == inside and not empowered:
				continue
			spawn_pool((m as Node2D).global_position + Vector2(randf_range(-30, 30), randf_range(-20, 20)))
	for p in pools:
		if not is_instance_valid(p):   # 已经被释放的颜料池：先判断再 cast（cast 已释放的对象会报错）
			continue
		var pool := p as PaintPool
		if not pool.active():
			continue
		for m in members():
			if (m as Node2D).global_position.distance_to(pool.position) <= POOL_R:
				if float(painted.get(m, 0.0)) <= 0.0:
					PalaceRoom.say_random(m, "paint")
				painted[m] = PAINTED
	pools = pools.filter(func(p): return is_instance_valid(p))
	for m in painted.keys():
		if not is_instance_valid(m):
			painted.erase(m)
			continue
		painted[m] = float(painted[m]) - delta
		if float(painted[m]) > 0.0:
			tickle(m, "painted", 0.6, 3.0, "sole", delta)


func spawn_pool(at: Vector2) -> PaintPool:
	var p := PaintPool.new()
	p.position = at
	p.add_to_group("danger")
	p.set_meta("rect", Rect2(at - Vector2(POOL_R, POOL_R), Vector2(POOL_R, POOL_R) * 2.0))
	add_view(p)
	pools.append(p)
	return p


func _clear_pools() -> void:
	for p in pools:
		if is_instance_valid(p):
			(p as Node).queue_free()
	pools.clear()
	painted.clear()


func _tick_hands(delta: float) -> void:
	_hand_t -= delta
	if _hand_t > 0.0:
		return
	_hand_t = HAND_EVERY
	for m in members():
		var pc := m as PlayableCharacter
		if pc != inside and pc.global_position.distance_to(weak_point()) <= HAND_R:
			pc.status.apply_root(1.0)
			var h := HitData.make_tickle(self, 6.0)
			h.zone = "armpit"
			pc.receive_hit(h)
			PalaceRoom.say_random(pc, "hand")
			_portrait.reach(pc.global_position)


# ------------------------------------------------------------------ 拉进画里
func pull() -> void:
	var p := GameState.player as PlayableCharacter
	if not is_instance_valid(p) or inside:
		return
	inside = p
	inside_t = 0.0
	PalaceRoom.say_random(p, "pulled")
	Fx.burst(get_parent(), p.global_position + Vector2(0, -10), "dust", 16, 50.0, 0.6, Vector2(0, -10), Color(0.9, 0.6, 0.9))
	p.global_position = world(cells("paint_start")[0])
	if p.get("camera"):
		p.camera.reset_smoothing()
	var other := Duo.partner_of(p) if Duo.active else null
	if other:
		other.status.apply_root(0.5)
	PalaceRoom.say_random(p, "inside")


func escape() -> void:
	var p := inside
	inside = null
	if is_instance_valid(p):
		p.global_position = weak_point() + Vector2(-20, 50)
		if p.get("camera"):
			p.camera.reset_smoothing()
		PalaceRoom.say_random(p, "escape")
	await CG.play_theater("throne_escape")
	await _finale()


func fail_inside() -> void:
	if empowered or _defeat_busy:
		return
	_defeat_busy = true
	if Downed.is_downed(inside):
		(inside.get_node("Downed") as Downed).revive_now()
	await CG.play_theater("throne_painting_trapped")
	empowered = true
	frame_hp = FRAME_HP
	inside.status.apply_root(999.0)
	inside.modulate.a = 0.4
	var other := Duo.partner_of(inside) if Duo.active else null
	if other and GameState.player != other:
		GameState.switch_control(other)
	_defeat_busy = false


func _free_inside() -> void:
	empowered = false
	var p := inside
	inside = null
	if is_instance_valid(p):
		p.status.clear_root()
		p.modulate.a = 1.0
		p.laugh.set_value(0.0)
		p.global_position = weak_point() + Vector2(20, 50)
	await _finale()


func _finale() -> void:
	_clear_pools()
	win = true
	_portrait.burned = true
	await Cutscene.play("throne_finale")
	while Cutscene.is_playing():
		await get_tree().process_frame
	GameState.set_flag(BOSS_FLAG)
	await PalaceRoom.try_memory()   # 徽记台已经换过发饰：先看女王的回忆
	while Cutscene.is_playing():
		await get_tree().process_frame
	Cutscene.play("palace_end")


# ------------------------------------------------------------------ 战败
func defeat_theater() -> String:
	if layer == 0:
		return "throne_fail_paint"
	if layer == 1:
		return "throne_fail_tea"
	return "throne_fail_frame" if empowered else "throne_fail"


func on_defeat(reason: String) -> void:
	if _defeat_busy:
		return
	_defeat_busy = true
	await CG.play_theater(defeat_theater())
	_clear_pools()
	if inside:
		inside.status.clear_root()
		inside.modulate.a = 1.0
		inside = null
	empowered = false
	if layer < 2:
		hp = LAYER_HP[layer]
	else:
		_pull_t = PULL_DELAY
	reset_to(world(cells("start")[0]) + Vector2(0, -24))
	_defeat_busy = false


func ai_hooks() -> BattleAIHooks:
	return ThroneHooks.new(self)


class ThroneHooks extends BattleAIHooks:
	var r: PalaceThrone

	func _init(room: PalaceThrone) -> void:
		r = room

	func priority_target() -> Variant:
		if r.layer == 1:
			for s in r.small:
				if (s as SmallPortrait).alive():
					return s
		if r.vulnerable():
			return r._portrait
		return null

	func objective_for(_ai: PlayableCharacter) -> Variant:
		if r.vulnerable():
			return r.weak_point() + Vector2(0, 20)
		return null


# ------------------------------------------------------------------ 画面
class PortraitView extends Node2D:
	const SHEET := "res://assets/generated/portrait_boss.png"
	var room: PalaceThrone
	var burned := false
	var _flash := 0.0
	var _reach := 0.0
	var _reach_to := Vector2.ZERO
	var _spr: Sprite2D

	func _ready() -> void:
		if ResourceLoader.exists(SHEET):
			_spr = Sprite2D.new()
			_spr.texture = load(SHEET)
			_spr.hframes = 3
			_spr.offset = Vector2(0, -40)
			add_child(_spr)

	func flash() -> void:
		_flash = 0.15

	func reach(to: Vector2) -> void:
		_reach = 0.6
		_reach_to = to - position

	func _process(d: float) -> void:
		_flash = maxf(0.0, _flash - d)
		_reach = maxf(0.0, _reach - d)
		if _spr:
			_spr.frame = 2 if burned else (1 if room and (room.layer >= 1 or room.empowered) else 0)
			_spr.modulate = Color(1.6, 1.3, 1.6) if _flash > 0.0 else (Color(1.2, 0.9, 1.3) if room and room.empowered else Color.WHITE)
		queue_redraw()

	func _draw() -> void:
		if not _spr:
			var r := Rect2(-22, -80, 44, 60)
			draw_rect(r.grow(4), Color(0.8, 0.62, 0.25))
			draw_rect(r, Color(0.55, 0.3, 0.4) if _flash <= 0.0 else Color(1, 0.8, 0.9))
			draw_circle(Vector2(0, -62), 9.0, Color(0.85, 0.78, 0.75))
			draw_rect(Rect2(-12, -52, 24, 28), Color(0.8, 0.4, 0.5))
			if burned:
				draw_circle(Vector2(0, -50), 12.0, Color(0.1, 0.05, 0.08))
				draw_arc(Vector2(0, -50), 12.0, 0, TAU, 20, Color(1, 0.8, 0.3), 2.0)
		if _reach > 0.0:
			draw_line(Vector2(0, -40), _reach_to, Color(0.9, 0.6, 0.8, 0.8), 3.0)
			draw_circle(_reach_to, 4.0, Color(0.95, 0.85, 0.8))
		if room and not room.win:
			var total: int = PalaceThrone.FRAME_HP if room.empowered else (PalaceThrone.LAYER_HP[room.layer] if room.layer < 2 else 1)
			var cur: int = room.frame_hp if room.empowered else (room.hp if room.layer < 2 else 1)
			for i in total:
				draw_rect(Rect2(-total * 2.5 + i * 5, -4, 4, 3), Color(0.95, 0.3, 0.45) if i < cur else Color(0.3, 0.2, 0.25))


class SmallPortrait extends Node2D:
	const SHEET := "res://assets/generated/small_portrait.png"
	var room: PalaceThrone
	var idx := 0
	var hp := 0
	var _shot := 0.0
	var _spr: Sprite2D
	var _t := 0.0

	func alive() -> bool:
		return hp > 0

	func _ready() -> void:
		_shot = PalaceThrone.SMALL_SHOT * (0.5 + idx * 0.25)
		if ResourceLoader.exists(SHEET):
			_spr = Sprite2D.new()
			_spr.texture = load(SHEET)
			_spr.hframes = 2
			_spr.offset = Vector2(0, -22)
			add_child(_spr)

	func revive() -> void:
		hp = PalaceThrone.SMALL_HP

	func sleep() -> void:
		hp = 0

	func hurt() -> void:
		hp -= 1
		Audio.play("gate", -8.0, 0.0, 1.9)
		if hp <= 0:
			Fx.burst(get_parent(), position + Vector2(0, -20), "dust", 10, 40.0, 0.5, Vector2(0, -8), Color(0.9, 0.7, 0.4))

	func _process(d: float) -> void:
		_t += d
		if _spr:
			_spr.frame = 1 if alive() else 0
			_spr.modulate.a = 1.0 if alive() or room == null or room.layer != 1 else 0.45
		queue_redraw()
		if room == null or not alive() or room.busy() or room.win:
			return
		_shot -= d
		if _shot <= 0.0:
			_shot = PalaceThrone.SMALL_SHOT
			var best: Node2D = null
			for m in room.members():
				if m != room.inside and (best == null or (m as Node2D).global_position.distance_to(position) < best.global_position.distance_to(position)):
					best = m
			if best:
				var h := PaintHand.new()
				h.room = room
				h.position = position + Vector2(0, -16)
				h.vel = (best.global_position - h.position).normalized() * 90.0
				room.add_view(h)

	func _draw() -> void:
		if _spr:
			return
		var on := alive()
		draw_set_transform(Vector2(0, -22), 0.0, Vector2(1, 1.3))
		draw_circle(Vector2.ZERO, 10.0, Color(0.8, 0.62, 0.25))
		draw_circle(Vector2.ZERO, 8.0, Color(0.95, 0.85, 0.8) if on else Color(0.5, 0.45, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if on:
			draw_circle(Vector2(-3, -24), 1.0, Color(0.1, 0.1, 0.1))
			draw_circle(Vector2(3, -24), 1.0, Color(0.1, 0.1, 0.1))


## 小画像甩出来的「画出来的手」
class PaintHand extends Node2D:
	var room: PalaceThrone
	var vel := Vector2.ZERO
	var life := 2.5

	func _process(d: float) -> void:
		if room == null or room.busy():
			return
		life -= d
		position += vel * d
		queue_redraw()
		for m in room.members():
			var pc := m as PlayableCharacter
			if pc != room.inside and pc.global_position.distance_to(position) <= 10.0:
				pc.status.apply_root(0.5)
				var h := HitData.make_tickle(self, 5.0)
				h.zone = "waist"
				pc.receive_hit(h)
				queue_free()
				return
		if life <= 0.0:
			queue_free()

	func _draw() -> void:
		CurseHand.draw_hand(self, Vector2(0, -8), 0.5, Color(0.95, 0.75, 0.9), Color(0.7, 0.4, 0.6), 0.9, sin(life * 10.0), vel.angle())


## 颜料坑：先出预警圈，再变成一滩颜料
class PaintPool extends Node2D:
	var t := 0.0
	var col := Color.from_hsv(randf(), 0.55, 1.0)

	func active() -> bool:
		return t >= PalaceThrone.POOL_WARN

	func _process(d: float) -> void:
		t += d
		if t >= PalaceThrone.POOL_WARN + PalaceThrone.POOL_LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := PalaceThrone.POOL_R
		if not active():
			draw_arc(Vector2.ZERO, r, 0, TAU, 20, Color(col, 0.8), 1.5)
			return
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.6))
		draw_circle(Vector2.ZERO, r, Color(col, 0.75))
		draw_circle(Vector2(r * 0.4, -r * 0.2), r * 0.35, Color(col.lightened(0.3), 0.8))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 画里巡逻的画笔：在出生点附近来回，离得近就追；碰到 = 闷笑涨 + 弹开
class Brush extends Node2D:
	var room: PalaceThrone
	var home := Vector2.ZERO
	var _t := 0.0
	var _cool := 0.0

	func step(d: float) -> void:
		_t += d
		_cool = maxf(0.0, _cool - d)
		var p := room.inside
		var target := home + Vector2(sin(_t * 1.3) * 40.0, 0)
		if is_instance_valid(p) and p.global_position.distance_to(position) < 60.0:
			target = p.global_position
		position = position.move_toward(target, PalaceThrone.BRUSH_SPEED * d)
		queue_redraw()
		if is_instance_valid(p) and _cool <= 0.0 and p.global_position.distance_to(position) <= 10.0:
			_cool = 1.0
			var h := HitData.make_tickle(self, 7.0)
			h.zone = "waist"
			p.receive_hit(h)
			p.global_position += (p.global_position - position).normalized() * 14.0

	func _draw() -> void:
		var a := sin(_t * 5.0) * 0.4
		draw_line(Vector2(0, -6), Vector2(0, -26).rotated(a), Color(0.55, 0.38, 0.2), 2.0)
		draw_circle(Vector2(0, -6), 3.5, Color.from_hsv(fposmod(_t * 0.2, 1.0), 0.6, 1.0))

class_name PalaceClock
extends PalaceRoom
## 第四章⑧·钟楼：拆成五层，一层一张图（floor_06_palace_clock_1 … _5，等距；布局 quest_maps._clock_1 … _5；台词 penance_text/palace3.py），
## 楼梯 / 梯子（地图里的 exit）上下连起来。同一个导演类，按这一层有的标记点开对应的机关（地图 token 的 map 参数决定是哪一层）：
##   一层 齿轮间：齿轮一开一合（GEAR_CYCLE），合上时站在缝里（gear_gaps）= 卡住脚踝（定身 + 挠脚底）；有人站在刹车（brake）上齿轮就停（AI 搭档会去踩）；
##   二层 钟摆厅：带羽毛的大钟摆在桥上来回扫（PEND_SPEED、PEND_SWING 格），扫到挠腰；
##   三层 风箱台：风箱（bellows）一开一停地往东 / 往西吹（WIND_EVERY），在范围里被吹着走 + 羽毛蛭脖子；
##     挂在齿轮上：在转轴（axle）对话 call palace_gear_ride → 小剧场 clock_gear_ride（CG）→ 梯子（ladder）放下来（LADDER_FLAG，梯子那个出口才打开）；
##   四层 回廊：离开梯子口 → 过场 clock_keeper_wake → 守钟人偶沿 PATH（回廊中线）追（KEEPER_SPEED）；人跑过闸门（gates）一段，闸门落下挡它 GATE_HOLD 秒；
##     追上 → 小剧场 clock_caught → 回检查点重新追；跑到上钟顶的楼梯口 → KEEPER_FLAG（楼梯那个出口才打开）；
##   钟顶：大钟（bell，线索）、钟绳（rope，对话 call palace_ring_bells → 过场 clock_bells → BELLS_FLAG，王座间的门开了）。
##   一~四层各有一口小宝箱（chests，对话 call palace_chest_<层>）。
## 测试：floor_no、gear_closed()、braked()、gear_caught、pend_x()、wind_dir(i)、ride()、chase_on、keeper_s、progress(pos)、gates_closed、caught_count、ring()。

const MAP := "floor_06_palace_clock_1"
const LADDER_FLAG := "palace_ladder_down"
const KEEPER_FLAG := "palace_keeper_done"
const BELLS_FLAG := "palace_bells_done"
const PROPS := "res://assets/generated/clock_props.png"
const GEAR_CYCLE := 2.4
const GEAR_CLOSED_FROM := 0.55
const GAP_R := 9.0
const BRAKE_R := 12.0
const PEND_SPEED := 1.6
const PEND_SWING := 5.0
const PEND_HALF := 12.0
const WIND_EVERY := 3.0
const WIND_R := 50.0
const WIND_PUSH := 55.0
const KEEPER_SPEED := 74.0
const WAKE_DELAY := 1.5
const WAKE_R := 30.0
const GATE_HOLD := 2.5
const CATCH_R := 40.0      # 回廊有 4~5 格宽：按「沿路线追到了」+ 这个距离算追上
## 四层的追逐路线：沿着每一段回廊的中线（从梯子口到上钟顶的楼梯口）
const PATH := [Vector2i(44, 35), Vector2i(34, 35), Vector2i(34, 27), Vector2i(8, 27), Vector2i(8, 15), Vector2i(42, 15), Vector2i(42, 3)]
const CHEST_REWARDS := [{"mint": 2}, {"equip_clock_watch": 1}, {"mint": 1, "coin": 30}, {"mint": 1}]

@export var map := MAP

var floor_no := 1
var t := 0.0
var gear_caught := {}
var chase_on := false
var keeper_s := 0.0
var caught_count := 0
var gates_closed := {}
var _gate_hold := {}
var _wait := 0.0
var _keeper: KeeperView
var _pend: Node2D
var _ladder_view: Node2D
var _path_pts: Array[Vector2] = []
var _say_cool := {}


func map_id() -> String:
	return map


func has(key: String) -> bool:
	return not cells(key).is_empty()


func _ready() -> void:
	super()
	floor_no = int(map.get_slice("_", map.get_slice_count("_") - 1)) if map.get_slice_count("_") > 0 else 1
	if has("axle"):
		_spot("floor_06/clock_axle", cells("axle")[0])
	if has("rope"):
		_spot("floor_06/clock_rope", cells("rope")[0])
		add_view(_prop(4, world(cells("rope")[0])))
	if has("bell"):
		_spot("floor_06/clock_bell", cells("bell")[0])
		var bell := _prop(3, world(cells("bell")[0]) + Vector2(0, -20))
		bell.scale = Vector2(1.6, 1.6)
		add_view(bell)
	if has("chests"):
		_spot("floor_06/clock_chest_%d" % floor_no, cells("chests")[0])
		var cv := ChestView.new()
		cv.flag = "palace_tchest_%d" % floor_no
		cv.position = world(cells("chests")[0])
		add_view(cv)
	for c in cells("gear_gaps"):
		var gv := GearView.new()
		gv.room = self
		gv.position = world(c)
		add_view(gv)
	if has("brake"):
		var bv := BrakeView.new()
		bv.room = self
		bv.position = world(cells("brake")[0])
		add_view(bv)
	if has("pendulum"):
		_pend = PendulumView.new()
		_pend.position = world(cells("pendulum")[0])
		add_view(_pend)
	var fi := 0
	for c in cells("bellows"):
		var fv := BellowsView.new()
		fv.room = self
		fv.idx = fi
		fv.position = world(c)
		add_view(fv)
		fi += 1
	if has("gear_seat"):
		var big := _prop(0, world(cells("gear_seat")[0]))
		big.scale = Vector2(1.6, 1.6)
		add_view(big)
	if has("ladder"):
		_ladder_view = LadderView.new()
		_ladder_view.position = world(cells("ladder")[0]) + Vector2(0, 8)
		_ladder_view.visible = GameState.has_flag(LADDER_FLAG)
		add_view(_ladder_view)
	if has("keeper"):
		for p in PATH:
			_path_pts.append(world(p))
		var gi := 0
		for c in cells("gates"):
			var g := GateView.new()
			g.room = self
			g.idx = gi
			g.position = world(c)
			add_view(g)
			gi += 1
		_keeper = KeeperView.new()
		_keeper.position = world(cells("keeper")[0])
		add_view(_keeper)
		if GameState.has_flag(KEEPER_FLAG):
			_keeper.position = world(PATH[PATH.size() - 1]) + Vector2(0, 40)


## clock_props.png 的一帧（0 齿轮 / 1 钟摆 / 2 风箱 / 3 钟 / 4 钟绳 / 5 宝箱）；没有图就给一个空节点
static func _prop(frame: int, at: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = at
	if ResourceLoader.exists(PROPS):
		var s := Sprite2D.new()
		s.texture = load(PROPS)
		s.hframes = 6
		s.frame = frame
		s.offset = Vector2(0, -28)
		n.add_child(s)
	return n


func _spot(dialogue: String, c: Vector2i) -> void:
	var sp := PrisonOddities.Spot.new()
	sp.dialogue = dialogue
	add_child(sp)
	sp.global_position = world(c)


func _process(delta: float) -> void:
	t += delta
	if busy():
		return
	update_checkpoints()
	for k in _say_cool.keys():
		_say_cool[k] = maxf(0.0, float(_say_cool[k]) - delta)
	for m in members():
		var pc := m as PlayableCharacter
		if Downed.is_downed(pc):
			continue
		_tick_gear(pc, delta)
		_tick_pendulum(pc, delta)
		_tick_wind(pc, delta)
	if is_instance_valid(_pend):
		_pend.position = Vector2(pend_x(), world(cells("pendulum")[0]).y)
	if has("keeper"):
		_tick_chase(delta)


func _say(pc: Node2D, key: String, cool := 2.5) -> void:
	var k := key + str(pc.get_instance_id())
	if float(_say_cool.get(k, 0.0)) > 0.0:
		return
	_say_cool[k] = cool
	PalaceRoom.say_random(pc, key)


# ------------------------------------------------------------------ 齿轮夹板（一层）
func braked() -> bool:
	if not has("brake"):
		return false
	for m in members():
		if (m as Node2D).global_position.distance_to(world(cells("brake")[0])) <= BRAKE_R:
			return true
	return false


func gear_closed() -> bool:
	return not braked() and fposmod(t, GEAR_CYCLE) / GEAR_CYCLE >= GEAR_CLOSED_FROM


func _tick_gear(pc: PlayableCharacter, delta: float) -> void:
	if not has("gear_gaps"):
		return
	gear_caught[pc] = maxf(0.0, float(gear_caught.get(pc, 0.0)) - delta)
	if not gear_closed() or float(gear_caught[pc]) > 0.0:
		return
	for c in cells("gear_gaps"):
		var p := world(c)
		if absf(pc.global_position.x - p.x) <= GAP_R and pc.global_position.y >= p.y - GAP_R and pc.global_position.y <= p.y + 16.0 + GAP_R:
			gear_caught[pc] = 2.0
			pc.status.apply_root(1.2)
			var h := HitData.make_tickle(self, 6.0)
			h.zone = "sole"
			pc.receive_hit(h)
			_say(pc, "gear", 1.5)
			Audio.play("gate", -8.0, 0.0, 1.6)
			return


# ------------------------------------------------------------------ 钟摆（二层）
func pend_x() -> float:
	if not has("pendulum"):
		return 0.0
	return world(cells("pendulum")[0]).x + sin(t * PEND_SPEED) * PEND_SWING * 16.0


func _tick_pendulum(pc: PlayableCharacter, delta: float) -> void:
	if not has("pendulum"):
		return
	var c := world(cells("pendulum")[0])
	if absf(pc.global_position.y - c.y) <= 56.0 and absf(pc.global_position.x - pend_x()) <= PEND_HALF:
		tickle(pc, "pend", 0.45, 4.0, "waist", delta, _pend)
		_say(pc, "pendulum")


# ------------------------------------------------------------------ 风箱（三层）
func wind_dir(i: int) -> float:
	var phase := int(floor(t / WIND_EVERY + i * 0.5)) % 3
	return [1.0, 0.0, -1.0][phase]


func _tick_wind(pc: PlayableCharacter, delta: float) -> void:
	var i := 0
	for c in cells("bellows"):
		var d := wind_dir(i)
		i += 1
		if d == 0.0 or pc.global_position.distance_to(world(c)) > WIND_R:
			continue
		pc.global_position.x += d * WIND_PUSH * delta
		tickle(pc, "wind", 0.8, 2.0, "neck", delta)
		_say(pc, "wind", 3.0)


# ------------------------------------------------------------------ 挂在齿轮上（三层）
func ride() -> void:
	if GameState.has_flag(LADDER_FLAG):
		return
	await CG.play_theater("clock_gear_ride")
	GameState.set_flag(LADDER_FLAG)
	if is_instance_valid(_ladder_view):
		_ladder_view.visible = true
	if is_instance_valid(pink) and has("ladder"):
		pink.global_position = world(cells("ladder")[0] + Vector2i(0, 3))
		pink.status.clear_root()
	Audio.play("unlock", -4.0)
	GameState.notify("梯子放下来了——可以上四层了")


# ------------------------------------------------------------------ 守钟人偶追逐（四层）
func path_len() -> float:
	var s := 0.0
	for i in range(1, _path_pts.size()):
		s += _path_pts[i - 1].distance_to(_path_pts[i])
	return s


func path_at(s: float) -> Vector2:
	for i in range(1, _path_pts.size()):
		var seg := _path_pts[i - 1].distance_to(_path_pts[i])
		if s <= seg:
			return _path_pts[i - 1].lerp(_path_pts[i], s / maxf(seg, 0.01))
		s -= seg
	return _path_pts[_path_pts.size() - 1]


## 某个位置在追逐路线上走到了哪儿（投影到折线上）
func progress(pos: Vector2) -> float:
	var best := 1e9
	var best_s := 0.0
	var acc := 0.0
	for i in range(1, _path_pts.size()):
		var a := _path_pts[i - 1]
		var b := _path_pts[i]
		var seg := a.distance_to(b)
		var k := clampf((pos - a).dot(b - a) / maxf(seg * seg, 0.01), 0.0, 1.0)
		var d := pos.distance_to(a.lerp(b, k))
		if d < best:
			best = d
			best_s = acc + k * seg
		acc += seg
	return best_s


func gate_s(i: int) -> float:
	return progress(world(cells("gates")[i]))


func _tick_chase(delta: float) -> void:
	if GameState.has_flag(KEEPER_FLAG):
		return
	var p := GameState.player as Node2D
	if not is_instance_valid(p):
		return
	if not chase_on:
		if p.global_position.distance_to(world(cells("start")[0])) > WAKE_R:
			start_chase()
		return
	var ps := progress(p.global_position)
	if ps >= path_len() - 10.0:
		chase_done()
		return
	for i in cells("gates").size():
		if not gates_closed.has(i) and ps > gate_s(i) + 24.0 and keeper_s < gate_s(i) - 8.0:
			gates_closed[i] = true
			_gate_hold[i] = GATE_HOLD
			_say(p, "gate", 1.0)
			Audio.play("gate", -4.0)
	if _wait > 0.0:
		_wait -= delta
		return
	var next_s := keeper_s + KEEPER_SPEED * delta
	for i in gates_closed.keys():
		if float(_gate_hold.get(i, 0.0)) > 0.0 and keeper_s <= gate_s(i) and next_s > gate_s(i) - 10.0:
			next_s = gate_s(i) - 10.0
			_gate_hold[i] = float(_gate_hold[i]) - delta
	keeper_s = next_s
	if is_instance_valid(_keeper):
		_keeper.move_to(path_at(keeper_s))
	for m in members():
		var mp := (m as Node2D).global_position
		if progress(mp) - keeper_s <= 8.0 and mp.distance_to(path_at(keeper_s)) <= CATCH_R:
			caught()
			return


func start_chase() -> void:
	chase_on = true
	keeper_s = 0.0
	gates_closed.clear()
	_gate_hold.clear()
	await Cutscene.play("clock_keeper_wake")
	while Cutscene.is_playing():
		await get_tree().process_frame
	_wait = WAKE_DELAY


func caught() -> void:
	if _defeat_busy:
		return
	_defeat_busy = true
	caught_count += 1
	await CG.play_theater("clock_caught")
	reset_to(checkpoint)
	keeper_s = 0.0
	gates_closed.clear()
	_gate_hold.clear()
	_wait = WAKE_DELAY
	if is_instance_valid(_keeper):
		_keeper.move_to(path_at(0.0))
	_defeat_busy = false


func chase_done() -> void:
	chase_on = false
	GameState.set_flag(KEEPER_FLAG)
	if is_instance_valid(_keeper):
		_keeper.move_to(path_at(path_len() - 40.0))
	PalaceRoom.say_random(GameState.player, "escape")
	GameState.notify("甩掉了守钟人偶——上钟顶的楼梯开了")


# ------------------------------------------------------------------ 宝箱 / 钟
func open_chest(i: int) -> void:
	var flag := "palace_tchest_%d" % i
	if GameState.has_flag(flag):
		return
	GameState.set_flag(flag)
	var reward: Dictionary = CHEST_REWARDS[i - 1]
	var names := []
	for id in reward:
		var it := ItemDB.get_item(str(id))
		if it:
			GameState.give_item(it, int(reward[id]))
			names.append("%s ×%d" % [it.display_name, int(reward[id])])
	Audio.play("chime", -4.0, 0.0, 1.2)
	GameState.notify("宝箱里：" + "、".join(names))


func ring() -> void:
	if GameState.has_flag(BELLS_FLAG):
		return
	await Cutscene.play("clock_bells")
	while Cutscene.is_playing():
		await get_tree().process_frame
	GameState.set_flag(BELLS_FLAG)


func ai_hooks() -> BattleAIHooks:
	return ClockHooks.new(self)


class ClockHooks extends BattleAIHooks:
	var r: PalaceClock

	func _init(room: PalaceClock) -> void:
		r = room

	## 搭档还没过齿轮：AI 去踩刹车
	func objective_for(ai: PlayableCharacter) -> Variant:
		if not r.has("gear_gaps") or not r.has("brake"):
			return null
		var other := partner_of(ai)
		if other == null:
			return null
		var row_y := r.world(r.cells("gear_gaps")[0]).y
		var ai_below := ai.global_position.y > row_y + 16.0
		var other_below := other.global_position.y > row_y - 12.0   # 还没过齿轮（站在缝里也算）
		if ai_below and other_below and other.global_position.y < row_y + 120.0:
			return r.world(r.cells("brake")[0])
		return null


# ------------------------------------------------------------------ 画面
## 齿轮缝：两边各一个转动的大齿轮（clock_props 第 0 帧），合上时齿轮靠拢
class GearView extends Node2D:
	var room: PalaceClock
	var _l: Node2D
	var _r: Node2D

	func _ready() -> void:
		_l = PalaceClock._prop(0, Vector2(-14, 0))
		_r = PalaceClock._prop(0, Vector2(14, 0))
		add_child(_l)
		add_child(_r)

	func _process(_d: float) -> void:
		if room == null:
			return
		var closed := room.gear_closed()
		var k := fposmod(room.t, PalaceClock.GEAR_CYCLE) / PalaceClock.GEAR_CYCLE
		var gap := 0.0 if closed else 6.0 * sin(clampf(k / PalaceClock.GEAR_CLOSED_FROM, 0.0, 1.0) * PI)
		_l.position.x = -12.0 - gap
		_r.position.x = 12.0 + gap
		if room.braked():
			return
		_l.rotation += _d * 2.0
		_r.rotation -= _d * 2.0
		queue_redraw()

	func _draw() -> void:
		if room and room.gear_closed():
			draw_line(Vector2(-5, -2), Vector2(5, -2), Color(1, 0.4, 0.4, 0.9), 2.0)
		if _l.get_child_count() == 0:
			for side in [-1.0, 1.0]:
				var c := Vector2(float(side) * 14.0, -14)
				draw_circle(c, 11.0, Color(0.72, 0.55, 0.25))
				draw_circle(c, 3.5, Color(0.4, 0.3, 0.15))


class BrakeView extends Node2D:
	var room: PalaceClock

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var on := room != null and room.braked()
		draw_rect(Rect2(-8, -4, 16, 8), Color(0.35, 0.3, 0.3))
		draw_line(Vector2(0, -2), Vector2(6 if on else -6, -22), Color(0.75, 0.6, 0.3), 3.0)
		draw_circle(Vector2(6 if on else -6, -22), 4.0, Color(0.85, 0.2, 0.2) if on else Color(0.7, 0.7, 0.7))


## 大钟摆（clock_props 第 1 帧，长杆 + 羽毛掸子），跟着 pend_x 来回、杆子跟着摆
class PendulumView extends Node2D:
	var _s: Node2D
	var _last := 0.0

	func _ready() -> void:
		_s = PalaceClock._prop(1, Vector2.ZERO)
		_s.scale = Vector2(1.5, 1.5)
		add_child(_s)
		_last = position.x

	func _process(_d: float) -> void:
		var v := position.x - _last
		_last = position.x
		_s.rotation = clampf(-v * 0.08, -0.5, 0.5)
		queue_redraw()

	func _draw() -> void:
		if _s.get_child_count() == 0:
			draw_line(Vector2(0, -80), Vector2(0, -14), Color(0.65, 0.5, 0.25), 3.0)
			draw_circle(Vector2(0, -14), 9.0, Color(0.8, 0.62, 0.28))
			for i in 7:
				var a := PI / 2.0 + (i - 3) * 0.28
				draw_line(Vector2(0, -8), Vector2(0, -8) + Vector2.from_angle(a) * 14.0, Color(1, 1, 1, 0.9), 2.5)


## 风箱（clock_props 第 2 帧）：吹的时候一鼓一瘪 + 风线
class BellowsView extends Node2D:
	var room: PalaceClock
	var idx := 0
	var _s: Node2D

	func _ready() -> void:
		_s = PalaceClock._prop(2, Vector2.ZERO)
		_s.scale = Vector2(1.3, 1.3)
		add_child(_s)

	func _process(_d: float) -> void:
		queue_redraw()
		if room == null:
			return
		var d := room.wind_dir(idx)
		var sq := absf(sin(room.t * 6.0)) * 0.15 if d != 0.0 else 0.0
		_s.scale = Vector2(1.3 + sq, 1.3 - sq)
		_s.scale.x *= -1.0 if d < 0.0 else 1.0

	func _draw() -> void:
		if room == null:
			return
		var d := room.wind_dir(idx)
		if _s.get_child_count() == 0:
			draw_rect(Rect2(-10, -16, 20, 14), Color(0.55, 0.35, 0.2))
		if d != 0.0:
			for i in 6:
				var x := d * (14.0 + fposmod(room.t * 50.0 + i * 11.0, 46.0))
				draw_line(Vector2(x, -12 + i * 2.5), Vector2(x + d * 8.0, -12 + i * 2.5), Color(1, 1, 1, 0.7), 1.5)
			for i in 3:
				var fx := d * (20.0 + fposmod(room.t * 40.0 + i * 15.0, 40.0))
				draw_line(Vector2(fx, -20 + i * 5), Vector2(fx + d * 5.0, -22 + i * 5), Color(1, 1, 1, 0.95), 2.0)


class LadderView extends Node2D:
	func _draw() -> void:
		draw_line(Vector2(-6, 10), Vector2(-6, -36), Color(0.55, 0.38, 0.2), 2.5)
		draw_line(Vector2(6, 10), Vector2(6, -36), Color(0.55, 0.38, 0.2), 2.5)
		for i in 7:
			draw_line(Vector2(-6, 6 - i * 7), Vector2(6, 6 - i * 7), Color(0.65, 0.45, 0.25), 2.0)


class GateView extends Node2D:
	var room: PalaceClock
	var idx := 0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var down: bool = room != null and room.gates_closed.has(idx) and float(room._gate_hold.get(idx, 0.0)) > 0.0
		var h := 30.0 if down else 8.0
		draw_rect(Rect2(-20, -36, 4, 36), Color(0.35, 0.3, 0.28))
		draw_rect(Rect2(16, -36, 4, 36), Color(0.35, 0.3, 0.28))
		draw_rect(Rect2(-20, -38, 40, 4), Color(0.4, 0.34, 0.3))
		for i in 6:
			draw_line(Vector2(-14 + i * 6, -34), Vector2(-14 + i * 6, -34 + h), Color(0.55, 0.5, 0.45), 2.5)


## 守钟人偶（npcs/clock_keeper.png 4x4 走路图；没有图就画一个）
class KeeperView extends Node2D:
	const SHEET := "res://assets/generated/npcs/clock_keeper.png"
	var _spr: Sprite2D
	var _t := 0.0

	func _ready() -> void:
		if ResourceLoader.exists(SHEET):
			_spr = Sprite2D.new()
			_spr.texture = load(SHEET)
			_spr.hframes = 4
			_spr.vframes = 4
			_spr.scale = Vector2(1.6, 1.6)
			_spr.offset = Vector2(0, -14)
			add_child(_spr)

	func move_to(p: Vector2) -> void:
		var d := p - position
		position = p
		if _spr and d.length() > 0.1:
			_t += d.length() / 12.0
			var row := 0
			if absf(d.x) > absf(d.y):
				row = 1 if d.x < 0 else 2
			else:
				row = 0 if d.y > 0 else 3
			_spr.frame = row * 4 + int(_t) % 4
		queue_redraw()

	func _draw() -> void:
		if _spr:
			return
		draw_rect(Rect2(-6, -34, 12, 22), Color(0.15, 0.3, 0.22))
		draw_circle(Vector2(0, -40), 6.0, Color(0.95, 0.92, 0.88))


## 小宝箱（clock_props 第 5 帧；打开过就半透明）
class ChestView extends Node2D:
	var flag := ""
	var _s: Node2D

	func _ready() -> void:
		_s = PalaceClock._prop(5, Vector2.ZERO)
		add_child(_s)

	func _process(_d: float) -> void:
		var open := flag != "" and GameState.has_flag(flag)
		_s.modulate = Color(0.6, 0.6, 0.6, 0.7) if open else Color.WHITE
		queue_redraw()

	func _draw() -> void:
		if _s.get_child_count() > 0:
			return
		var open := flag != "" and GameState.has_flag(flag)
		draw_rect(Rect2(-8, -10, 16, 10), Color(0.55, 0.32, 0.15))
		draw_rect(Rect2(-8, -18 if open else -14, 16, 5), Color(0.6, 0.36, 0.18))

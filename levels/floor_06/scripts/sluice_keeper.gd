class_name SluiceKeeper
extends Node2D
## 反省篇第三章章末·水闸守门人（小 Boss；WaterwayDirector 在两人走进场地 arena 时创建；台词 tools/build/penance_text/waterway.py）。
## 一台生锈的大水闸机关（keeper 标记处），场上三个阀门（valves）：站上去 VALVE_TIME 秒关掉一个（两个人一起站快一倍；AI 搭档自己去关离它最近的）；三个都关掉就赢。
## 招式（每 ATTACK_EVERY 秒轮一招）：
##   sweep  刷子臂横扫：先在一行上亮预警带 SWEEP_WARN 秒（放进 danger 组，AI 会躲），然后扫过去——带里没在冲刺的人被刷脚底（一大下）
##   bubble 泡泡弹幕：朝两个人各吐一串泡泡（和关卡里的一样，裹住要搭档戳破）
##   mud    黑泥喷口：两个喷口各吐一个黑泥小人（追人抹泥）
##   flood  放水淹场：每关掉一个阀门，它就把场地淹 FLOOD_TIME 秒浅水，小鱼群从水里窜出来——站在石堆 rocks 上才不被挠（AI 会跑上去）
## 输了（两个都倒下 / 都被泡泡裹住）：战败小剧场 keeper_fail（四幕 + CG）→ 场地复位从头打；赢了：小剧场 keeper_win（被困住）→ 章末过场 waterway_end。
## 测试：valves_closed、close_valve(i)、attack(kind)、flooding、on_defeat()、won。

const DONE_FLAG := "waterway_keeper_done"
const MAP := "floor_06_waterway"
const VALVE_R := 14.0
const VALVE_TIME := 5.0      # 关一个阀门要站这么久（两个人一起快一倍）
const ATTACK_EVERY := 2.6    # 守门人出招的间隔
const SWEEP_WARN := 1.2
const SWEEP_HALF := 10.0
const FLOOD_TIME := 5.0
const ROCK_R := 14.0
const ORDER := ["sweep", "bubble", "mud", "sweep", "bubble"]

var dir: WaterwayDirector
var valves: Array = []        # [{pos, progress, closed, node}]
var valves_closed := 0
var flooding := 0.0
var won := false
var _attack_t := 2.5
var _order_i := 0
var _body: KeeperBody
var _sweeps: Array = []
var _extra_mud: Array = []
var _gate: StaticBody2D
var _flood_node: FloodFx
var _started := false


func _ready() -> void:
	for c in QuestMaps.cells(MAP, "valves"):
		var vn := ValveMark.new()
		vn.position = WaterwayDirector.cell_pos(c)
		dir.get_parent().add_child.call_deferred(vn)
		valves.append({"pos": Cells.to_world(c), "progress": 0.0, "closed": false, "node": vn})
	_body = KeeperBody.new()
	_body.keeper = self
	_body.position = WaterwayDirector.cell_pos(QuestMaps.cell(MAP, "keeper"))
	dir.get_parent().add_child.call_deferred(_body)
	_flood_node = FloodFx.new()
	_flood_node.keeper = self
	_flood_node.position = WaterwayDirector.cell_pos(QuestMaps.cell(MAP, "keeper")) + Vector2(0, 88)
	dir.get_parent().add_child.call_deferred(_flood_node)
	# 场地入口关上（打完 / 输了复位时再说）
	_gate = StaticBody2D.new()
	_gate.collision_layer = 1
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 16)
	sh.shape = r
	_gate.add_child(sh)
	add_child(_gate)
	_gate.global_position = WaterwayDirector.cell_pos(Vector2i(90, 7))
	# 小 Boss 用通用的 Boss 战配乐（palace_boss 留给王座间的女王画像）
	Audio.play_music("boss")
	_intro.call_deferred()


func _intro() -> void:
	if not GameState.has_flag("cg_seen_keeper_intro"):
		GameState.set_flag("cg_seen_keeper_intro")
		await Cutscene.play("keeper_intro")
		while Cutscene.is_playing():
			await get_tree().process_frame
	_started = true


func _exit_tree() -> void:
	for n in [_body, _flood_node] + valves.map(func(v): return v["node"]):
		if is_instance_valid(n):
			(n as Node).queue_free()
	for m in _extra_mud:
		if is_instance_valid(m):
			(m as Node).queue_free()
			dir.mudmen.erase(m)


func _process(delta: float) -> void:
	if won or not _started or dir._busy():
		return
	var ms := dir.members()
	# 阀门
	for v in valves:
		if v["closed"]:
			continue
		var on := ms.filter(func(c): return not Downed.is_downed(c) and not dir.trapped.has(c) and (c as Node2D).global_position.distance_to(v["pos"]) <= VALVE_R)
		if on.is_empty():
			v["progress"] = maxf(0.0, float(v["progress"]) - delta * 0.5)
		else:
			v["progress"] = float(v["progress"]) + delta / VALVE_TIME * (2.0 if on.size() >= 2 else 1.0)
			if float(v["progress"]) >= 1.0:
				close_valve(valves.find(v))
				if won:
					return
		if is_instance_valid(v["node"]):
			(v["node"] as ValveMark).progress = float(v["progress"])
			(v["node"] as ValveMark).queue_redraw()
	# 淹场：不在石堆上的人被小鱼挠
	if flooding > 0.0:
		flooding -= delta
		for c in ms:
			var pc := c as PlayableCharacter
			if Downed.is_downed(pc) or _on_rock(pc):
				continue
			dir._tickle(pc, "flood", 0.6, 3.0, "sole", delta)
	# 刷子臂
	for s in _sweeps.duplicate():
		var sw := s as Sweep
		sw.left -= delta
		if sw.left <= 0.0:
			_do_sweep(sw, ms)
			_sweeps.erase(sw)
			sw.queue_free()
	# 出招
	_attack_t -= delta
	if _attack_t <= 0.0:
		_attack_t = ATTACK_EVERY
		attack(str(ORDER[_order_i % ORDER.size()]))
		_order_i += 1


func _on_rock(pc: Node2D) -> bool:
	for c in QuestMaps.cells(MAP, "rocks"):
		if pc.global_position.distance_to(Cells.to_world(c)) <= ROCK_R:
			return true
	return false


func close_valve(i: int) -> void:
	var v: Dictionary = valves[i]
	if v["closed"]:
		return
	v["closed"] = true
	v["progress"] = 1.0
	valves_closed += 1
	Audio.play("lever", -2.0)
	_body.hurt = 0.6
	var lines: Array = WaterwayDirector.data().get("valve", [])
	if not lines.is_empty():
		GameState.princess_reacted.emit(str(lines[mini(valves_closed - 1, lines.size() - 1)]), 2.4)
	if valves_closed >= valves.size():
		_win()
	else:
		attack("flood")


func attack(kind: String) -> void:
	match kind:
		"sweep":
			var ys := dir.members().map(func(c): return (c as Node2D).global_position.y)
			var y: float = ys.pick_random() if not ys.is_empty() else _body.position.y + 80.0
			var sw := Sweep.new()
			sw.keeper = self
			sw.left = SWEEP_WARN
			sw.y = y
			sw.position = Vector2(_body.position.x, y)
			dir.get_parent().add_child(sw)
			_sweeps.append(sw)
		"bubble":
			for c in dir.members():
				for k in 3:
					var b := WaterwayDirector.Bubble.new()
					b.dir = dir
					var to := ((c as Node2D).global_position - _body.position).normalized().rotated((k - 1) * 0.25)
					b.vel = to * WaterwayDirector.BUBBLE_SPEED * 1.2
					b.life = 5.0
					b.position = _body.position + Vector2(0, 16) + to * 10.0
					dir.get_parent().add_child(b)
					dir.bubbles.append(b)
			Audio.play("bubble", -6.0, 0.0, 0.9)
		"mud":
			for c in QuestMaps.cells(MAP, "nozzles"):
				var m := WaterwayDirector.MudMan.new()
				m.dir = dir
				m.home = Cells.to_world(c)
				m.position = m.home
				dir.get_parent().add_child(m)
				dir.mudmen.append(m)
				_extra_mud.append(m)
			Audio.play("puddle", -4.0, 0.0, 0.6)
		"flood":
			flooding = FLOOD_TIME
			Audio.play("water_release", -2.0, 0.0, 0.8)
			var lines: Array = WaterwayDirector.data().get("flood", [])
			if not lines.is_empty():
				GameState.princess_reacted.emit(str(lines.pick_random()), 2.2)


func _do_sweep(sw: Sweep, ms: Array) -> void:
	Audio.play("brush_spin", -3.0)
	for c in ms:
		var pc := c as PlayableCharacter
		if Downed.is_downed(pc) or absf(pc.global_position.y - sw.y) > SWEEP_HALF or pc.state == PlayableCharacter.State.DASH:
			continue
		var h := HitData.make_tickle(self, 14.0)
		h.zone = "sole"
		h.special = true
		pc.receive_hit(h)


## AI 搭档：淹场时上石堆；平时去关离它最近、没关的阀门
func objective_for(ai: PlayableCharacter) -> Variant:
	if not _started or won:
		return null
	if flooding > 0.0:
		var best: Variant = null
		for c in QuestMaps.cells(MAP, "rocks"):
			var p := Cells.to_world(c)
			if best == null or p.distance_to(ai.global_position) < (best as Vector2).distance_to(ai.global_position):
				best = p
		return best
	var bv: Variant = null
	for v in valves:
		if not v["closed"] and (bv == null or (v["pos"] as Vector2).distance_to(ai.global_position) < (bv as Vector2).distance_to(ai.global_position)):
			bv = v["pos"]
	return bv


func _win() -> void:
	won = true
	flooding = 0.0
	for s in _sweeps:
		if is_instance_valid(s):
			(s as Node).queue_free()
	_sweeps.clear()
	for m in _extra_mud:
		if is_instance_valid(m):
			(m as WaterwayDirector.MudMan).splat()
	_body.dead = true
	await CG.play_theater("keeper_win")
	GameState.set_flag(DONE_FLAG)
	Cutscene.play("waterway_end")


## 输了：战败小剧场（四幕 + CG）→ 场地复位、从入口重新打
func on_defeat(_reason: String) -> void:
	await CG.play_theater("keeper_fail")
	for v in valves:
		v["closed"] = false
		v["progress"] = 0.0
		if is_instance_valid(v["node"]):
			(v["node"] as ValveMark).progress = 0.0
			(v["node"] as ValveMark).queue_redraw()
	valves_closed = 0
	flooding = 0.0
	_attack_t = 3.0
	_order_i = 0
	for m in _extra_mud:
		if is_instance_valid(m):
			(m as Node).queue_free()
			dir.mudmen.erase(m)
	_extra_mud.clear()
	for b in dir.bubbles:
		if is_instance_valid(b) and (b as WaterwayDirector.Bubble).holding == null:
			(b as Node).queue_free()
	dir.reset_to(Cells.to_world(QuestMaps.cell(MAP, "arena")))


## 水闸机关本体（画一扇生锈的大闸门、两只刷子臂、狮子头喷口）
class KeeperBody extends Node2D:
	var keeper: SluiceKeeper
	var hurt := 0.0
	var dead := false
	var _t := 0.0

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		_t += delta
		hurt = maxf(0.0, hurt - delta)
		queue_redraw()

	func _draw() -> void:
		var shake := Vector2(sin(_t * 40.0) * 2.0, 0) if hurt > 0.0 else Vector2.ZERO
		var c := Color(0.42, 0.36, 0.32) if not dead else Color(0.3, 0.28, 0.27)
		draw_rect(Rect2(Vector2(-34, -60) + shake, Vector2(68, 56)), c)
		for k in 5:
			draw_line(Vector2(-30 + k * 15, -58) + shake, Vector2(-30 + k * 15, -6) + shake, c.darkened(0.3), 2.0)
		draw_rect(Rect2(Vector2(-34, -60) + shake, Vector2(68, 56)), Color(0.2, 0.17, 0.15), false, 2.0)
		draw_circle(Vector2(0, -36) + shake, 9.0, Color(0.62, 0.52, 0.26))
		draw_circle(Vector2(0, -34) + shake, 4.0, Color(0.1, 0.1, 0.12) if not dead else Color(0.25, 0.22, 0.2))
		if not dead:
			for s in [-1, 1]:
				var a := Vector2(s * 34, -20) + shake
				var tip := a + Vector2(s * (18 + sin(_t * 3.0 + s) * 6.0), 14)
				draw_line(a, tip, Color(0.5, 0.45, 0.4), 3.0)
				for k in 4:
					draw_line(tip + Vector2(-4 + k * 3, 0), tip + Vector2(-4 + k * 3, 5), Color(0.95, 0.85, 0.6), 1.0)


## 阀门（地上的一个红色手轮；进度一圈一圈画满）
class ValveMark extends Node2D:
	var progress := 0.0

	func _draw() -> void:
		var done := progress >= 1.0
		draw_set_transform(Vector2.ZERO, 0.0, IsoView.ground_scale())
		draw_arc(Vector2.ZERO, 7.0, 0, TAU, 20, Color(0.4, 0.8, 0.5) if done else Color(0.8, 0.3, 0.3), 2.5)
		if progress > 0.0 and not done:
			draw_arc(Vector2.ZERO, 10.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 24, Color(1, 0.9, 0.5), 2.0)
		draw_set_transform(Vector2.ZERO)


## 刷子臂横扫的预警带（danger 组：AI 会躲）
class Sweep extends Node2D:
	var keeper: SluiceKeeper
	var left := 1.2
	var y := 0.0

	func _ready() -> void:
		z_index = 0
		add_to_group("danger")
		# CompanionController 按世界坐标判断（position 在 add_child 前设好）
		set_meta("rect", Rect2(position + Vector2(-140, -SluiceKeeper.SWEEP_HALF), Vector2(280, SluiceKeeper.SWEEP_HALF * 2.0)))

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var k := 1.0 - left / SluiceKeeper.SWEEP_WARN
		for i in 9:
			var x := -128.0 + i * 32.0
			draw_line(IsoView.offset(Vector2(x, 0)), IsoView.offset(Vector2(x + 24.0, 0)), Color(1.0, 0.35, 0.35, 0.35 + 0.5 * k), 3.0)


## 淹场时整片场地的浅水
class FloodFx extends Node2D:
	var keeper: SluiceKeeper
	var _t := 0.0

	func _ready() -> void:
		z_index = 0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if keeper == null or keeper.flooding <= 0.0:
			return
		var a := clampf(keeper.flooding, 0.0, 1.0) * 0.4
		var pts := PackedVector2Array([IsoView.offset(Vector2(-136, -96)), IsoView.offset(Vector2(136, -96)), IsoView.offset(Vector2(136, 104)), IsoView.offset(Vector2(-136, 104))])
		draw_colored_polygon(pts, Color(0.35, 0.6, 0.85, a))

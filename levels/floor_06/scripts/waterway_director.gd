class_name WaterwayDirector
extends Node2D
## 反省篇第三章·废弃水道（floor_06_waterway，等距 drain_water；布局 tools/build/quest_maps.py 的 _waterway；台词 tools/build/penance_text/waterway.py）。
## 两人同行（Duo：按 C 换人，没操控的那个是 AI 搭档；笑倒 = Downed，搭档按住 E 扶起；两个都倒下 → on_defeat → 短小剧场 → 回检查点）。
## 粉色公主还穿着鼠鼠装（挠脚鼠乱窜暴击、鼠味引怪）。机关（都按标记点摆）：
##   水位（high：GameState.vars.WATER_VAR）：深水渠 deep 一直过不去；浮木 logs 高水位才浮起来能走（踩上去 LOG_FLIP 几率翻一下，水草扫脚底）；
##     水下格栅通道 grate 低水位才露出来。过不去的格子放一块看不见的墙（StaticBody2D，world 层），水面 / 干渠由 WaterCell 画。
##   轮盘 wheels：站上去就转（两个人一起站转得快：WHEEL_ONE / WHEEL_TWO 秒），转满 → 换水位；转的时候格栅里的刷子刷脚底；转完要离开再站上去才能再转。
##     AI 搭档：玩家站上去时它也过来一起转（hooks.objective_for）。
##   狮子头 lions：朝走廊吐泡泡（每 LION_EVERY 秒一个）；泡泡碰到人 → 把她裹住（定身、闷笑一直涨）；另一个人走过去攻击就戳破（AI 自动去戳）；
##     两个人都被裹住 = 失败。
##   浅水 shallow：站在里面小鱼群越聚越多（不动聚得更快），按数量挠脚底；冲刺甩掉。
##   黑泥小人 mud：追离得近的人，碰到就抹上黑泥（变慢 + 闷笑一直涨，MUD_TIME 秒）；踩进清水池 fountain 洗掉，或者蓝色公主走到她身边用冰冻碎（攻击 / AI 自动）。
##     小人被攻击就散掉，过一会儿从原地冒出来。
##   检查点 checkpoints；场地 arena：走进去开始水闸守门人（SluiceKeeper）。
## 等距地图：要单独投影的东西（水面格、泡泡、黑泥小人、鱼群）都挂在 Entities（导演的父节点）下面；挡路的墙只管物理，挂在导演下面。
## 测试：high、set_water()、wheels、lions、bubbles、trapped、fish、mud、mudmen、checkpoint、keeper、shoot(i)、trap(who)、mud_on(who)。

const MAP := "floor_06_waterway"
const WATER_VAR := "waterway_high"
const CHECK_R := 16.0
const WHEEL_R := 14.0
const WHEEL_ONE := 4.0
const WHEEL_TWO := 1.5
const LION_EVERY := Vector2(3.0, 4.5)
const BUBBLE_SPEED := 46.0
const BUBBLE_LIFE := 4.0
const BUBBLE_HIT_R := 9.0
const BUBBLE_POP_R := 18.0
const TRAP_TICK := 0.5
const FISH_GAIN := 1.2
const FISH_MAX := 6.0
const FISH_TICK := 0.7
const MUD_TIME := 10.0
const MUD_SLOW := 0.55
const MUD_TICK := 0.8
const MUD_SPEED := 30.0
const MUD_CHASE_R := 90.0
const MUD_TOUCH_R := 10.0
const MUD_RESPAWN := 8.0
const CLEAN_R := 18.0
const LOG_FLIP := 0.35
const ARENA_R := 18.0

var lv: Node
var high := true
var pink: PlayableCharacter
var blue: PlayableCharacter
var checkpoint := Vector2.ZERO
var wheels: Array = []      # [{cell, pos, progress, latched}]
var lions: Array = []       # [{pos, dir, t}]
var bubbles: Array = []
var trapped := {}           # 人 -> Bubble
var fish := {}              # 人 -> 数量
var mud := {}               # 人 -> 剩余秒
var mudmen: Array = []
var keeper: Node
var _cells := {}            # 格子 -> 种类（deep / logs / grate / shallow / fountain）
var _blockers := {}         # 格子 -> StaticBody2D
var _water_nodes: Array = []
var _cps: Array = []
var _tick := {}
var _on_log := {}
var _defeat_busy := false


static func cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * 16.0 + 8.0, c.y * 16.0 + 8.0)


func _ready() -> void:
	lv = get_parent()
	while lv and lv.get_node_or_null("Floor") == null and lv.get_parent():
		lv = lv.get_parent()
	high = bool(GameState.vars.get(WATER_VAR, true))
	for kind in ["deep", "logs", "grate", "shallow", "fountain"]:
		for c in QuestMaps.cells(MAP, kind):
			_cells[c] = kind
	for c in _cells:
		var wc := WaterCell.new()
		wc.dir = self
		wc.cell = c
		wc.kind = str(_cells[c])
		wc.position = cell_pos(c)
		get_parent().add_child.call_deferred(wc)
		_water_nodes.append(wc)
	for c in QuestMaps.cells(MAP, "wheels"):
		wheels.append({"cell": c, "pos": Cutscene.cell_to_world(c), "progress": 0.0, "latched": false})
		var wn := WheelMark.new()
		wn.position = cell_pos(c)
		get_parent().add_child.call_deferred(wn)
	for c in QuestMaps.cells(MAP, "lions"):
		var d := Vector2.ZERO
		for nd in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if not _walkable_static(c + nd):
				d = -Vector2(nd)
		lions.append({"pos": cell_pos(c), "dir": d, "t": randf_range(LION_EVERY.x, LION_EVERY.y)})
		var ln := LionMark.new()
		ln.position = cell_pos(c)
		ln.dir = d
		get_parent().add_child.call_deferred(ln)
	for c in QuestMaps.cells(MAP, "mud"):
		var m := MudMan.new()
		m.dir = self
		m.home = Cutscene.cell_to_world(c)
		m.position = m.home
		get_parent().add_child.call_deferred(m)
		mudmen.append(m)
	for c in QuestMaps.cells(MAP, "checkpoints"):
		_cps.append(Cutscene.cell_to_world(c))
	checkpoint = _cps[0] if not _cps.is_empty() else Cutscene.cell_to_world(QuestMaps.cell(MAP, "start"))
	_apply_water()
	# 跳关进来：补穿鼠鼠装
	if GameState.has_flag("penance_mouse_dev") and not PenanceCell.wearing_mouse():
		PenanceCell.wear_mouse()
	_start_duo.call_deferred()


func _start_duo() -> void:
	pink = GameState.player as PlayableCharacter
	for n in get_tree().get_nodes_in_group("player_chars"):
		if n is PlayableCharacter and (n as PlayableCharacter).character_id == "blue":
			blue = n
	if is_instance_valid(pink) and is_instance_valid(blue):
		Duo.start([pink, blue], self, WaterwayHooks.new(self))


func _exit_tree() -> void:
	if Duo.active and Duo.director == self:
		Duo.stop()


func members() -> Array:
	return [pink, blue].filter(func(c): return is_instance_valid(c))


func _walkable_static(c: Vector2i) -> bool:
	return lv != null and GridPath.walkable(lv, c)


# ------------------------------------------------------------------ 水位
func set_water(h: bool) -> void:
	high = h
	GameState.vars[WATER_VAR] = h
	_apply_water()
	Audio.play("water_release", -4.0, 0.0, 0.8 if h else 1.1)
	var lines: Array = WaterwayDirector.data().get("water_high" if h else "water_low", [])
	if not lines.is_empty():
		GameState.princess_reacted.emit(str(lines.pick_random()), 2.4)


func blocked(c: Vector2i) -> bool:
	match str(_cells.get(c, "")):
		"deep":
			return true
		"logs":
			return not high
		"grate":
			return high
	return false


func _apply_water() -> void:
	for c in _cells:
		var b := blocked(c)
		if b and not _blockers.has(c):
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var sh := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			r.size = Vector2(16, 16)
			sh.shape = r
			body.add_child(sh)
			add_child(body)
			body.global_position = cell_pos(c)
			_blockers[c] = body
		elif not b and _blockers.has(c):
			(_blockers[c] as Node).queue_free()
			_blockers.erase(c)
	for wn in _water_nodes:
		if is_instance_valid(wn):
			(wn as Node2D).queue_redraw()


# ------------------------------------------------------------------ 每帧
func _busy() -> bool:
	return GameState.in_dialogue or GameState.in_cutscene or CG.is_busy() or Dialogue.is_active()


func _process(delta: float) -> void:
	if _busy():
		return
	var ms := members()
	for c in ms:
		var pc := c as PlayableCharacter
		if Downed.is_downed(pc):
			continue
		var at := pc.global_position
		for cp in _cps:
			if at.distance_to(cp) <= CHECK_R:
				checkpoint = cp
		_tick_fish(pc, delta)
		_tick_mud(pc, delta)
		_tick_log(pc)
		_tick_trap(pc, delta)
	_tick_wheels(delta, ms)
	_tick_lions(delta, ms)
	for m in mudmen:
		if is_instance_valid(m):
			(m as MudMan).step(delta, ms)
	_check_arena(ms)


func _cell_of(p: Vector2) -> Vector2i:
	return GridPath.cell(p)


func _tickle(pc: PlayableCharacter, key: String, every: float, amount: float, zone: String, delta: float, src: Node = null) -> void:
	var k := str(pc.get_instance_id()) + key
	_tick[k] = float(_tick.get(k, 0.0)) - delta
	if float(_tick[k]) <= 0.0:
		_tick[k] = every
		var h := HitData.make_tickle(src if src else self, amount)
		h.zone = zone
		pc.receive_hit(h)


func _tick_fish(pc: PlayableCharacter, delta: float) -> void:
	var in_water := str(_cells.get(_cell_of(pc.global_position), "")) == "shallow"
	var n := float(fish.get(pc, 0.0))
	if in_water:
		if pc.state == PlayableCharacter.State.DASH:
			n = 0.0
		else:
			n = minf(FISH_MAX, n + delta * FISH_GAIN * (2.0 if pc.velocity.length() < 5.0 else 1.0))
	else:
		n = maxf(0.0, n - delta * 3.0)
	fish[pc] = n
	if n >= 1.0:
		_tickle(pc, "fish", FISH_TICK, 1.0 + n * 0.8, "sole", delta)


func _tick_mud(pc: PlayableCharacter, delta: float) -> void:
	if not mud.has(pc):
		return
	mud[pc] = float(mud[pc]) - delta
	pc.status.apply_slow(MUD_SLOW, 0.3)
	_tickle(pc, "mud", MUD_TICK, 2.5, "sole", delta)
	# 清水池洗掉；蓝色公主在身边（攻击 / AI 搭档）用冰冻碎
	var other := Duo.partner_of(pc) if Duo.active else null
	var washed := str(_cells.get(_cell_of(pc.global_position), "")) == "fountain"
	var iced := other != null and other.character_id == "blue" and not Downed.is_downed(other) \
		and other.global_position.distance_to(pc.global_position) <= CLEAN_R and (other.state == PlayableCharacter.State.ATTACK or other != GameState.player)
	if washed or iced or float(mud[pc]) <= 0.0:
		mud_off(pc, "ice" if iced and not washed else "water")


func mud_on(pc: PlayableCharacter) -> void:
	if mud.has(pc):
		mud[pc] = MUD_TIME
		return
	mud[pc] = MUD_TIME
	Audio.play("puddle", -4.0, 0.0, 0.7)
	SpeechBubble.say(pc, "黏、黏糊糊的……！" if pc.character_id == "pink" else "……黏。", 26.0, 1.4)
	pc.modulate = Color(0.75, 0.68, 0.62)


func mud_off(pc: PlayableCharacter, how := "water") -> void:
	mud.erase(pc)
	pc.modulate = Color.WHITE
	if how == "ice":
		Fx.burst(pc.get_parent(), pc.global_position + Vector2(0, -8), "dust", 10, 30.0, 0.5, Vector2(0, -10), Color(0.7, 0.9, 1.0))
		Audio.play("ice_crack", -6.0)
	else:
		Audio.play("bubble_pop", -6.0)


func _tick_log(pc: PlayableCharacter) -> void:
	var on := str(_cells.get(_cell_of(pc.global_position), "")) == "logs" and high
	if on and not _on_log.get(pc, false) and randf() < LOG_FLIP:
		var h := HitData.make_tickle(self, 6.0)
		h.zone = "sole"
		pc.receive_hit(h)
		Audio.play("puddle", -6.0)
		var lines: Array = WaterwayDirector.data().get("log", [])
		if not lines.is_empty():
			SpeechBubble.say(pc, str(lines.pick_random()), 26.0, 1.4)
	_on_log[pc] = on


# ------------------------------------------------------------------ 轮盘
func _tick_wheels(delta: float, ms: Array) -> void:
	for w in wheels:
		var on := ms.filter(func(c): return not Downed.is_downed(c) and not trapped.has(c) and (c as Node2D).global_position.distance_to(w["pos"]) <= WHEEL_R)
		if on.is_empty():
			w["latched"] = false
			w["progress"] = maxf(0.0, float(w["progress"]) - delta)
			continue
		if w["latched"]:
			continue
		var t := WHEEL_TWO if on.size() >= 2 else WHEEL_ONE
		w["progress"] = float(w["progress"]) + delta / t
		for c in on:
			_tickle(c, "wheel", 0.6, 2.0, "sole", delta)
		if float(w["progress"]) >= 1.0:
			w["progress"] = 0.0
			w["latched"] = true
			set_water(not high)


## AI 搭档：玩家正在转的轮盘
func wheel_in_use() -> Variant:
	var p := GameState.player
	if not is_instance_valid(p):
		return null
	for w in wheels:
		if not w["latched"] and p.global_position.distance_to(w["pos"]) <= WHEEL_R:
			return w["pos"]
	return null


# ------------------------------------------------------------------ 狮子头 / 泡泡
func _tick_lions(delta: float, ms: Array) -> void:
	for i in lions.size():
		var l: Dictionary = lions[i]
		l["t"] = float(l["t"]) - delta
		if float(l["t"]) <= 0.0:
			l["t"] = randf_range(LION_EVERY.x, LION_EVERY.y)
			shoot(i)
	for b in bubbles.duplicate():
		if not is_instance_valid(b):
			bubbles.erase(b)
			continue
		var bb := b as Bubble
		if bb.holding != null:
			continue
		bb.life -= delta
		bb.position += bb.vel * delta
		if bb.life <= 0.0 or not _walkable_static(_cell_of(bb.position)):
			bb.pop_now(false)
			bubbles.erase(bb)
			continue
		for c in ms:
			var pc := c as PlayableCharacter
			if not trapped.has(pc) and not Downed.is_downed(pc) and pc.global_position.distance_to(bb.position) <= BUBBLE_HIT_R:
				trap(pc, bb)
				break


func shoot(i: int) -> Bubble:
	var l: Dictionary = lions[i]
	var b := Bubble.new()
	b.dir = self
	b.vel = (l["dir"] as Vector2) * BUBBLE_SPEED
	b.life = BUBBLE_LIFE
	b.position = (l["pos"] as Vector2) + (l["dir"] as Vector2) * 8.0
	get_parent().add_child(b)
	bubbles.append(b)
	Audio.play("bubble", -10.0, 0.1, 1.2)
	return b


## 泡泡把她裹住（测试也直接调：b 为空就现吹一个）
func trap(pc: PlayableCharacter, b: Bubble = null) -> void:
	if b == null:
		b = Bubble.new()
		b.dir = self
		get_parent().add_child(b)
		bubbles.append(b)
	b.holding = pc
	trapped[pc] = b
	pc.status.apply_root(999.0)
	Audio.play("bubble", -4.0, 0.0, 0.8)
	var lines: Array = WaterwayDirector.data().get("trapped", [])
	if not lines.is_empty():
		SpeechBubble.say(pc, str(lines.pick_random()), 28.0, 1.6)
	if members().all(func(c): return trapped.has(c) or Downed.is_downed(c)):
		on_defeat("bubbles")


func _tick_trap(pc: PlayableCharacter, delta: float) -> void:
	if not trapped.has(pc):
		return
	var b := trapped[pc] as Bubble
	if is_instance_valid(b):
		b.position = pc.global_position + Vector2(0, -2)
	_tickle(pc, "trap", TRAP_TICK, 2.5, "sole", delta, b)
	var other := Duo.partner_of(pc) if Duo.active else null
	if other != null and not trapped.has(other) and not Downed.is_downed(other) and other.global_position.distance_to(pc.global_position) <= BUBBLE_POP_R \
			and (other.state == PlayableCharacter.State.ATTACK or other != GameState.player):
		release(pc)


func release(pc: PlayableCharacter) -> void:
	var b: Variant = trapped.get(pc)
	trapped.erase(pc)
	pc.status.clear_root()
	if b != null and is_instance_valid(b):
		(b as Bubble).pop_now(true)
		bubbles.erase(b)


# ------------------------------------------------------------------ 场地 / 失败
func _check_arena(ms: Array) -> void:
	if is_instance_valid(keeper) or GameState.has_flag(SluiceKeeper.DONE_FLAG):
		return
	var a := Cutscene.cell_to_world(QuestMaps.cell(MAP, "arena"))
	for c in ms:
		if (c as Node2D).global_position.distance_to(a) <= ARENA_R:
			start_keeper()
			return


func start_keeper() -> SluiceKeeper:
	if is_instance_valid(keeper):
		return keeper
	keeper = SluiceKeeper.new()
	keeper.dir = self
	add_child(keeper)
	return keeper


## 两个人都倒下 / 都被泡泡裹住：短小剧场 → 都扶起来、回检查点（守门人战里交给 SluiceKeeper：战败小剧场、从头再打）
func on_defeat(reason: String) -> void:
	if _defeat_busy:
		return
	_defeat_busy = true
	if is_instance_valid(keeper) and keeper.has_method("on_defeat"):
		await keeper.on_defeat(reason)
	else:
		var id := "waterway_down_first" if not GameState.has_flag("cg_seen_theater:waterway_down_first") else "waterway_down"
		await CG.play_theater(id)
		reset_to(checkpoint)
	_defeat_busy = false


func reset_to(at: Vector2) -> void:
	for c in members():
		var pc := c as PlayableCharacter
		if trapped.has(pc):
			release(pc)
		if mud.has(pc):
			mud_off(pc)
		if Downed.is_downed(pc):
			(pc.get_node("Downed") as Downed).revive_now()
		pc.laugh.set_value(0.0)
		fish[pc] = 0.0
		pc.global_position = at + (Vector2(10, 0) if pc.character_id == "blue" else Vector2.ZERO)
	var p := GameState.player
	if is_instance_valid(p) and p.get("camera"):
		p.camera.reset_smoothing()


static var _data := {}


## 玩法里的短台词（penance_text/waterway.py → data/after/waterway.json）
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/after/waterway.json"))
		_data = parsed if parsed is Dictionary else {}
	return _data


# ------------------------------------------------------------------ 画面
## 水面 / 干渠 / 浮木 / 格栅 / 浅水 / 清水池的一格（屏幕空间画菱形）
class WaterCell extends Node2D:
	var dir: WaterwayDirector
	var cell: Vector2i
	var kind := ""
	var _t := 0.0

	func _ready() -> void:
		# 画在地面之上（地面图块是屏幕空间的 IsoTerrain）；菱形已经用 IsoView.offset 投影过了，不再进 iso_ground 组压扁
		z_index = 0

	func _process(delta: float) -> void:
		_t += delta
		if kind in ["shallow", "fountain"] or (dir and dir.high):
			queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array([IsoView.offset(Vector2(-8, -8)), IsoView.offset(Vector2(8, -8)), IsoView.offset(Vector2(8, 8)), IsoView.offset(Vector2(-8, 8))])
		var hi := dir != null and dir.high
		var col := Color(0, 0, 0, 0)
		match kind:
			"deep":
				col = Color(0.15, 0.35, 0.6, 0.85) if hi else Color(0.18, 0.14, 0.16, 0.9)
			"logs":
				col = Color(0.15, 0.35, 0.6, 0.85) if hi else Color(0.18, 0.14, 0.16, 0.9)
			"grate":
				col = Color(0.15, 0.35, 0.6, 0.85) if hi else Color(0.35, 0.36, 0.42, 0.6)
			"shallow":
				col = Color(0.35, 0.6, 0.8, 0.35 + 0.05 * sin(_t * 2.0 + cell.x))
			"fountain":
				col = Color(0.6, 0.9, 1.0, 0.55 + 0.1 * sin(_t * 3.0))
		draw_colored_polygon(pts, col)
		if kind == "logs":
			var lc := Color(0.55, 0.36, 0.2) if hi else Color(0.35, 0.24, 0.15)
			draw_line(IsoView.offset(Vector2(-7, 0)), IsoView.offset(Vector2(7, 0)), lc, 5.0)
			draw_line(IsoView.offset(Vector2(-7, -1)), IsoView.offset(Vector2(7, -1)), lc.lightened(0.3), 1.0)
		elif kind == "grate" and not hi:
			for k in [-4.0, 0.0, 4.0]:
				draw_line(IsoView.offset(Vector2(k, -7)), IsoView.offset(Vector2(k, 7)), Color(0.2, 0.2, 0.25), 1.0)
		elif kind in ["deep", "logs", "grate"] and hi:
			var wv := IsoView.offset(Vector2(sin(_t * 1.5 + cell.y) * 4.0, 0))
			draw_line(wv + Vector2(-5, 0), wv + Vector2(5, 0), Color(0.7, 0.85, 1.0, 0.6), 1.0)


## 轮盘（地上的一个铁轮）
class WheelMark extends Node2D:
	func _ready() -> void:
		z_index = 0

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, IsoView.ground_scale())
		draw_arc(Vector2.ZERO, 7.0, 0, TAU, 20, Color(0.55, 0.5, 0.45), 2.0)
		for k in 4:
			draw_line(Vector2.ZERO, Vector2.from_angle(k * PI / 2.0) * 7.0, Color(0.55, 0.5, 0.45), 1.5)


## 墙上的狮子头出水口
class LionMark extends Node2D:
	var dir := Vector2.ZERO

	func _draw() -> void:
		draw_circle(Vector2(0, -14), 5.0, Color(0.6, 0.5, 0.25))
		draw_circle(Vector2(0, -13), 2.0, Color(0.15, 0.12, 0.1))
		draw_arc(Vector2(0, -14), 5.0, 0, TAU, 14, Color(0.3, 0.24, 0.12), 1.0)


## 狮子头吐出来的泡泡（裹住人时跟着她）
class Bubble extends Node2D:
	var dir: WaterwayDirector
	var vel := Vector2.ZERO
	var life := 4.0
	var holding: PlayableCharacter
	var _t := 0.0

	func _ready() -> void:
		z_index = 3

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func pop_now(burst := true) -> void:
		if burst:
			Fx.burst(get_parent(), position + Vector2(0, -10), "bubble", 10, 30.0, 0.5, Vector2(0, -10))
			Audio.play("bubble_pop", -4.0)
		queue_free()

	func _draw() -> void:
		var r := 13.0 if holding else 5.0
		var y := -12.0 if holding else -10.0 + sin(_t * 6.0) * 1.5
		draw_circle(Vector2(0, y), r, Color(0.75, 0.9, 1.0, 0.28))
		draw_arc(Vector2(0, y), r, 0, TAU, 24, Color(0.85, 0.95, 1.0, 0.85), 1.0)
		draw_circle(Vector2(-r * 0.4, y - r * 0.4), r * 0.2, Color(1, 1, 1, 0.8))


## 黑泥小人：追离得近的人，碰到就抹黑泥；被攻击就散掉，过一会儿从原地冒出来
class MudMan extends Node2D:
	var dir: WaterwayDirector
	var home := Vector2.ZERO
	var down := 0.0
	var _cool := 0.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 2
		add_to_group("waterway_mud")

	func alive() -> bool:
		return down <= 0.0

	func step(delta: float, ms: Array) -> void:
		_t += delta
		_cool = maxf(0.0, _cool - delta)
		if down > 0.0:
			down -= delta
			if down <= 0.0:
				position = home
				show()
			return
		var near: PlayableCharacter = null
		for c in ms:
			var pc := c as PlayableCharacter
			if Downed.is_downed(pc):
				continue
			# 被攻击就散掉
			if pc.state == PlayableCharacter.State.ATTACK and pc.global_position.distance_to(position) <= 18.0:
				splat()
				return
			if pc.global_position.distance_to(position) <= WaterwayDirector.MUD_CHASE_R and (near == null or pc.global_position.distance_to(position) < near.global_position.distance_to(position)):
				near = pc
		if near:
			var to := near.global_position - position
			position += to.normalized() * WaterwayDirector.MUD_SPEED * delta
			if to.length() <= WaterwayDirector.MUD_TOUCH_R and _cool <= 0.0:
				_cool = 2.0
				dir.mud_on(near)
		else:
			position = position.move_toward(home, WaterwayDirector.MUD_SPEED * 0.5 * delta)
		queue_redraw()

	func splat() -> void:
		down = WaterwayDirector.MUD_RESPAWN
		hide()
		Fx.burst(get_parent(), position + Vector2(0, -6), "dust", 10, 30.0, 0.5, Vector2(0, -8), Color(0.25, 0.2, 0.18))
		Audio.play("puddle", -6.0, 0.0, 0.6)

	func _draw() -> void:
		var wob := sin(_t * 5.0) * 1.0
		draw_circle(Vector2(0, -6 + wob), 6.0, Color(0.22, 0.17, 0.14))
		draw_circle(Vector2(0, -12 + wob), 4.0, Color(0.26, 0.2, 0.16))
		draw_circle(Vector2(-1.5, -13 + wob), 0.8, Color(1, 1, 1))
		draw_circle(Vector2(1.5, -13 + wob), 0.8, Color(1, 1, 1))
		draw_line(Vector2(-6, -6 + wob), Vector2(-9, -9 - wob), Color(0.22, 0.17, 0.14), 2.0)
		draw_line(Vector2(6, -6 + wob), Vector2(9, -9 + wob), Color(0.22, 0.17, 0.14), 2.0)


## AI 搭档的提示：被泡泡裹住的搭档 / 玩家在转的轮盘 / 抹了黑泥的搭档（蓝色公主过去冰掉）/ 最近的黑泥小人
class WaterwayHooks extends BattleAIHooks:
	var d: WaterwayDirector

	func _init(director: WaterwayDirector) -> void:
		d = director

	func objective_for(ai: PlayableCharacter) -> Variant:
		var other := partner_of(ai)
		if other and d.trapped.has(other):
			return other.global_position
		if other and ai.character_id == "blue" and d.mud.has(other):
			return other.global_position
		if is_instance_valid(d.keeper) and d.keeper.has_method("objective_for"):
			var o: Variant = d.keeper.objective_for(ai)
			if o is Vector2:
				return o
		return d.wheel_in_use()

	func priority_target() -> Variant:
		var p := GameState.player
		var best: Node2D = null
		for m in d.mudmen:
			if is_instance_valid(m) and (m as MudMan).alive() and is_instance_valid(p) and (m as Node2D).global_position.distance_to(p.global_position) < 90.0:
				if best == null or (m as Node2D).global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position):
					best = m
		return best

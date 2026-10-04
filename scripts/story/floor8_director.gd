class_name Floor8Director
extends Node2D
## 第八层「千手之间」的导演（地图里放一个：X = f8director）。管：
##   开场：蓝色公主走进来 → 粉色公主被千手的手臂吊着挠 → 冰晶结界冻住手臂救下她 → 两人并肩（双人模式 Duo 开始）
##   三个阶段（ThousandHand 打到血量下限 → 过场 → 下一阶段）：
##     阶段二：两块压力板（两个人同时站上去 PLATE_HOLD 秒 → 锁链把 Boss 拽下来 PULL_TIME 秒），每 TERRAIN_EVERY 秒改一次地形
##     阶段三：场地中央的光圈，谁走进去谁被抓进巢穴（右边小窗 + 献祭挣扎），另一个人打下来的手臂；地形照样变
##   战败：倒地超时 / 两人都倒下 / 阶段三有人倒下 / 献祭笑满 → 本阶段的战败小剧场 → 从本阶段开头重来
##   胜利：Boss 恼怒、乱砸墙壁、巨石滚下来 → 进追逐战（floor_08_chase）
## 位置都用地图里的到达点（spawn id=…）：boss、pink、lair、circle、plate_a1 / a2 / b1 / b2 / c1 / c2、summon1~4、limb1~4、blue_fight、pink_fight。

const BOSS_SCENE := "res://scenes/actors/monsters/thousand_hand.tscn"
const PINK_SCENE := "res://scenes/actors/playable/princess.tscn"
const PLATE_TEX := preload("res://assets/generated/duo_plate.png")
const CIRCLE_TEX := preload("res://assets/generated/sacrifice_circle.png")
const BOULDER_TEX := preload("res://assets/generated/boulder.png")
const ARM := preload("res://assets/generated/thousand_hand_arm.png")
const PLATE_HOLD := 1.0
const PULL_TIME := 6.0
const TERRAIN_EVERY := 15.0
const CIRCLE_HOLD := 0.25

static var instance: Floor8Director

var boss: ThousandHand
var pink: Princess
var blue: PlayableCharacter
var phase := 0
## 过场 / 战败处理中（期间不更新机关）
var busy := false
## 阶段三：任何一人倒下直接战败
var instant_defeat := false
var marks := {}
var arena_cells := Rect2i()
var shifter: TerrainShifter
var panel: PartnerPanel
var plates: Array[Sprite2D] = []
var plates_lit := false
var _plate_pair := 0
var _plate_hold := 0.0
var _plate_wait := 0.0
var circle: Sprite2D
var _circle_cd := 0.0
var _circle_hold := 0.0
var _circle_who: PlayableCharacter
## 献祭中：{victim, struggle, window, limbs, hands}
var sacrifice := {}
var _terrain_cd := 0.0
var _terrain_i := 0
var _t := 0.0


func _ready() -> void:
	instance = self
	add_to_group("f8_director")
	z_index = 1
	await get_tree().process_frame
	await get_tree().process_frame
	_collect_marks()
	shifter = TerrainShifter.new()
	add_child(shifter)
	var lv := _level()
	shifter.setup(lv, Vector2i(arena_cells.position.x - 1, arena_cells.position.y + 2))
	blue = GameState.player
	boss = load(BOSS_SCENE).instantiate()
	boss.name = "Boss"
	lv.get_node("Entities").add_child(boss)
	boss.global_position = marks.get("boss", Vector2.ZERO)
	boss.arena = Rect2(_cell_pos(arena_cells.position) - Vector2(8, 12), Vector2(arena_cells.size) * 16.0)
	for k in ["summon1", "summon2", "summon3", "summon4"]:
		if marks.has(k):
			boss.summon_points.append(marks[k])
	boss.threshold_reached.connect(_on_threshold)
	_spawn_pink()
	_make_plates()
	_make_circle()
	if GameState.has_flag("f8_intro_done"):
		_place_for_fight()
		start_fight()
	else:
		run_intro()


func _exit_tree() -> void:
	if instance == self:
		instance = null
	if SideWindow.is_open():
		SideWindow.current.close(true)
	Duo.stop()


func _level() -> Node2D:
	var n: Node = get_parent()
	while n and not n.has_node("Walls"):
		n = n.get_parent()
	return n as Node2D


func _collect_marks() -> void:
	var lv := _level()
	for sp in get_tree().get_nodes_in_group("spawn_point"):
		if lv.is_ancestor_of(sp):
			marks[str(sp.get("id"))] = (sp as Node2D).global_position
	if marks.has("arena_tl") and marks.has("arena_br"):
		var tl := _cell_of(marks["arena_tl"])
		var br := _cell_of(marks["arena_br"])
		arena_cells = Rect2i(tl, br - tl + Vector2i.ONE)


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / 16.0), floori((p.y - 4.0) / 16.0))


func _cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * 16 + 8, c.y * 16 + 12)


func _spawn_pink() -> void:
	pink = load(PINK_SCENE).instantiate()
	pink.name = "Pink"
	pink.faction = Faction.Type.ALLY
	pink.set_controller(ScriptedController.new())
	_level().get_node("Entities").add_child(pink)
	pink.global_position = marks.get("pink", boss.global_position + Vector2(0, 40))
	if pink.camera:
		pink.camera.enabled = false


func _place_for_fight() -> void:
	blue.global_position = marks.get("blue_fight", blue.global_position)
	pink.global_position = marks.get("pink_fight", blue.global_position + Vector2(24, 0))


# ------------------------------------------------------------------ 开场
func run_intro() -> void:
	busy = true
	# 粉色公主被手臂吊着挠（开场里不扣血，只是表现）
	pink.status.grab(boss, 9999.0, 99999)
	boss.victim = pink
	if pink.emotion:
		pink.emotion.request("helpless_1", 999.0, false)
	await Cutscene.play("f8_intro_a")
	# 冰晶结界：冻住手臂，粉色公主掉下来
	IceBarrier.cast_with(blue, 96.0, 1.5)
	boss.cancel_attacks()
	pink.status.release(true)
	pink.global_position = marks.get("pink_fight", pink.global_position)
	if pink.emotion:
		pink.emotion.request("surprise", 1.5, false)
	Audio.play_music("boss")
	await Cutscene.play("f8_intro_b")
	GameState.set_flag("f8_intro_done")
	start_fight()


func start_fight() -> void:
	Duo.start([blue, pink], self)
	if panel == null:
		panel = PartnerPanel.new()
		add_child(panel)
	Audio.play_music("boss")
	GameState.boss_changed.emit(boss)
	var gate_group := "f8_gate"
	for n in get_tree().get_nodes_in_group(gate_group):
		if Contracts.is_switchable(n):
			n.set_active(false)
	start_phase(1)


func start_phase(p: int) -> void:
	phase = p
	instant_defeat = p >= 3
	boss.set_phase(p)
	boss.fighting = true
	busy = false
	_plate_pair = 0
	_plate_hold = 0.0
	_plate_wait = 0.0
	_set_plates(p == 2)
	_circle_cd = 3.0 if p == 3 else INF
	_terrain_cd = 4.0 if p >= 2 else INF
	circle.visible = false


# ------------------------------------------------------------------ 每帧：压力板、地形、光圈
func _process(delta: float) -> void:
	_t += delta
	if circle:
		circle.frame = int(_t * 4.0) % 2
	if busy or phase == 0 or GameState.in_dialogue:
		return
	if phase == 2:
		_update_plates(delta)
	if phase >= 2:
		_terrain_cd -= delta
		if _terrain_cd <= 0.0:
			_terrain_cd = TERRAIN_EVERY
			shift_terrain()
	if phase == 3 and sacrifice.is_empty():
		_update_circle(delta)


func _make_plates() -> void:
	for i in 2:
		var s := Sprite2D.new()
		s.texture = PLATE_TEX
		s.hframes = 2
		s.z_index = 0
		s.visible = false
		_level().add_child(s)
		plates.append(s)


func _plate_positions(pair: int) -> Array:
	var keys: Array = [["plate_a1", "plate_a2"], ["plate_b1", "plate_b2"], ["plate_c1", "plate_c2"]][pair % 3]
	return [marks.get(keys[0], Vector2.ZERO), marks.get(keys[1], Vector2.ZERO)]


func _set_plates(lit: bool) -> void:
	plates_lit = lit
	var pos := _plate_positions(_plate_pair)
	for i in plates.size():
		plates[i].visible = phase == 2
		plates[i].frame = 1 if lit else 0
		plates[i].global_position = pos[i] + Vector2(0, -4)
	if lit and phase == 2:
		for i in plates.size():
			Fx.burst(_level(), plates[i].global_position, "ember", 5, 30.0, 0.5, Vector2(0, -20))


## 站在第 i 块压力板上的人（没人 = null）。
func plate_occupant(i: int) -> PlayableCharacter:
	for m in Duo.members:
		if is_instance_valid(m) and m.is_alive() and not Downed.is_downed(m) and m.global_position.distance_to(plates[i].global_position + Vector2(0, 4)) <= 11.0:
			return m
	return null


func _update_plates(delta: float) -> void:
	if not plates_lit:
		_plate_wait -= delta
		if _plate_wait <= 0.0 and not boss.is_pulled():
			_plate_pair += 1
			_set_plates(true)
		return
	var a := plate_occupant(0)
	var b := plate_occupant(1)
	if a and b and a != b:
		_plate_hold += delta
		if _plate_hold >= PLATE_HOLD:
			_plate_hold = 0.0
			pull_boss()
	else:
		_plate_hold = 0.0


func pull_boss() -> void:
	boss.pull_down(PULL_TIME)
	_set_plates(false)
	_plate_wait = PULL_TIME + 2.0
	GameState.notify("锁链把它拽下来了！快攻击本体！")
	for m in Duo.members:
		if is_instance_valid(m):
			m.shake(0.2)


## AI 搭档要去站的压力板（不用站就返回 null）：玩家离哪块近，AI 就去另一块。
func plate_for(ai: PlayableCharacter) -> Variant:
	if phase != 2 or not plates_lit or busy or boss.is_pulled():
		return null
	var p := GameState.player
	if not is_instance_valid(p) or p == ai:
		return null
	var d0 := p.global_position.distance_to(plates[0].global_position)
	var d1 := p.global_position.distance_to(plates[1].global_position)
	return plates[1 if d0 < d1 else 0].global_position + Vector2(0, 4)


## AI 优先打的东西：献祭时下来的手臂，Boss 能打时的本体。
func priority_target() -> Variant:
	if not sacrifice.is_empty():
		for l in sacrifice.get("limbs", []):
			if is_instance_valid(l) and l.is_alive():
				return l
	if boss and boss.fighting and boss.attackable:
		return boss
	return null


# ------------------------------------------------------------------ 地形
func shift_terrain() -> void:
	shifter.clear()
	var r := arena_cells
	var cx := r.position.x + r.size.x / 2
	var cy := r.position.y + r.size.y / 2
	var keep := _keep_cells()
	match _terrain_i % 3:
		0:   # 石墙：一横一竖把场地隔成四块，每段都留门洞
			var cells: Array = []
			for y in range(r.position.y + 3, r.end.y - 1):
				if absi(y - cy) > 1 and absi(y - (r.position.y + 5)) > 0:
					cells.append(Vector2i(cx, y))
			for x in range(r.position.x + 2, r.end.x - 2):
				if absi(x - cx) > 1 and absi(x - (r.position.x + 6)) > 0 and absi(x - (r.end.x - 7)) > 0:
					cells.append(Vector2i(x, cy + 2))
			shifter.raise_walls(cells.filter(func(c): return not keep.has(c)))
			GameState.notify("地面升起了石墙！")
		1:   # 泥沼 + 传送带
			for c in _free_cells(keep, 3, 4, 3):
				shifter.spawn_field("mud", c, {"w": 3, "h": 2})
			shifter.spawn_field("conveyor", Vector2i(r.position.x + 2, cy - 2), {"dir": "right", "len": 6})
			shifter.spawn_field("conveyor", Vector2i(r.end.x - 3, cy + 3), {"dir": "left", "len": 6})
			GameState.notify("地面变成了泥沼和传送带！")
		2:   # 羽毛坑（落穴洞）
			for c in _free_cells(keep, 5, 2, 2):
				shifter.spawn_field("pit", c, {"content": ["squirrel", "rat"].pick_random()})
			GameState.notify("地上塌出了洞！")
	_terrain_i += 1


## 场地里随机挑 count 个不压住 keep、彼此不重叠的格子（w×h 的一片，返回左上角）。
func _free_cells(keep: Dictionary, count: int, w: int, h: int) -> Array[Vector2i]:
	var r := arena_cells
	var out: Array[Vector2i] = []
	var used := {}
	for attempt in 200:
		if out.size() >= count:
			break
		var c := Vector2i(randi_range(r.position.x + 2, r.end.x - 2 - w), randi_range(r.position.y + 4, r.end.y - 2 - h))
		var ok := true
		for dx in w:
			for dy in h:
				if keep.has(c + Vector2i(dx, dy)) or used.has(c + Vector2i(dx, dy)):
					ok = false
		if ok:
			out.append(c)
			for dx in range(-1, w + 1):
				for dy in range(-1, h + 1):
					used[c + Vector2i(dx, dy)] = true
	return out


## 改地形时不能压住的格子：压力板、光圈、两个人站的地方附近。
func _keep_cells() -> Dictionary:
	var out := {}
	var spots: Array = []
	for p in plates:
		spots.append(p.global_position + Vector2(0, 4))
	if circle:
		spots.append(circle.global_position)
	for m in Duo.members:
		if is_instance_valid(m):
			spots.append(m.global_position)
	for s in spots:
		var c := _cell_of(s)
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				out[c + Vector2i(dx, dy)] = true
	return out


# ------------------------------------------------------------------ 献祭（阶段三）
func _make_circle() -> void:
	circle = Sprite2D.new()
	circle.texture = CIRCLE_TEX
	circle.hframes = 2
	circle.visible = false
	circle.z_index = 0
	_level().add_child(circle)
	circle.global_position = marks.get("circle", Vector2.ZERO)


func _update_circle(delta: float) -> void:
	_circle_cd -= delta
	circle.visible = _circle_cd <= 0.0
	if not circle.visible:
		return
	var inside: PlayableCharacter = null
	for m in Duo.members:
		if is_instance_valid(m) and m.is_alive() and not Downed.is_downed(m) and m.global_position.distance_to(circle.global_position) <= 16.0:
			inside = m
			break
	if inside and inside == _circle_who:
		_circle_hold += delta
		if _circle_hold >= CIRCLE_HOLD:
			begin_sacrifice(inside)
	else:
		_circle_who = inside
		_circle_hold = 0.0


func begin_sacrifice(c: PlayableCharacter) -> void:
	var other := Duo.partner_of(c)
	if other == null or not other.is_alive() or Downed.is_downed(other) or not sacrifice.is_empty():
		return
	Duo.sacrifice_lock = true
	circle.visible = false
	if c == GameState.player:
		GameState.switch_control(other)
	c.set_controller(ScriptedController.new())
	boss.sacrifice_grab(c, marks.get("lair", c.global_position))
	PlayerInputController.wasd_only = true
	var win := SideWindow.open(c, {"title": "千手的巢穴 · %s" % c.display_name(), "hint": "← → 交替连按挣扎", "zoom": 1.5})
	var st := SacrificeStruggle.start(c)
	win.set_overlay(st.overlay())
	st.escaped.connect(func(): end_sacrifice(true))
	st.broke.connect(func(): on_defeat("sacrifice"))
	var limbs: Array = []
	var keys := ["limb1", "limb2", "limb3", "limb4"]
	keys.shuffle()
	for i in 3:
		var l := BossLimb.new()
		l.boss = boss
		l.hand = [2, 4, 6][i]
		_level().get_node("Entities").add_child(l)
		l.global_position = marks.get(keys[i], circle.global_position + Vector2(-40 + 40 * i, 20))
		limbs.append(l)
	var hands := LairHands.new()
	hands.target = c
	_level().add_child(hands)
	sacrifice = {"victim": c, "struggle": st, "window": win, "limbs": limbs, "hands": hands}
	GameState.notify("主画面：打下来的手臂！   小窗：← → 交替连按挣扎")
	SpeechBubble.say(other, "……撑住！" if other.character_id == "blue" else "等我！我马上打下来！", 30.0)


func end_sacrifice(escaped: bool) -> void:
	if sacrifice.is_empty():
		return
	var c: PlayableCharacter = sacrifice["victim"]
	for l in sacrifice["limbs"]:
		if is_instance_valid(l):
			l.retract()
	if is_instance_valid(sacrifice["hands"]):
		sacrifice["hands"].queue_free()
	if is_instance_valid(sacrifice["struggle"]):
		sacrifice["struggle"].queue_free()
	if SideWindow.is_open():
		SideWindow.current.close()
	boss.sacrifice_release(c, circle.global_position + Vector2(0, 18))
	if is_instance_valid(c):
		c.set_faction(Faction.Type.ALLY)
		c.set_controller(CompanionController.new())
		if escaped:
			SpeechBubble.say(c, "……挣开了。" if c.character_id == "blue" else "呼……逃出来了！", 30.0)
	Duo.sacrifice_lock = false
	PlayerInputController.wasd_only = false
	sacrifice = {}
	_circle_cd = 5.0
	_circle_who = null


# ------------------------------------------------------------------ 阶段切换 / 战败 / 胜利
func _on_threshold(p: int) -> void:
	busy = true
	end_sacrifice(false)
	_cleanup_field()
	if p >= 3:
		victory()
		return
	await get_tree().create_timer(0.4).timeout
	await Cutscene.play("f8_phase%d" % (p + 1))
	_regroup()
	start_phase(p + 1)


func _cleanup_field() -> void:
	shifter.clear()
	boss.clear_summons()
	boss.cancel_attacks()
	_set_plates(false)
	circle.visible = false
	for m in Duo.members:
		if is_instance_valid(m) and m.status and m.status.is_grabbed():
			m.status.release(true)


## 两个人回到战斗起点（过场之后、战败重来）。
func _regroup() -> void:
	for m in Duo.members:
		if not is_instance_valid(m):
			continue
		var d := m.get_node_or_null("Downed")
		if d:
			d.free()
		if not m.is_alive() or m.state == PlayableCharacter.State.DEAD:
			m.revive()
			m._set_state(PlayableCharacter.State.IDLE)
	_place_for_fight()


func on_defeat(reason: String) -> void:
	if busy or phase == 0:
		return
	busy = true
	boss.fighting = false
	end_sacrifice(false)
	_cleanup_field()
	var key := "f8_defeat_%d" % phase
	var n := int(GameState.vars.get(key, 0)) + 1
	GameState.vars[key] = n
	print("第八层战败：阶段 %d（%s），第 %d 次" % [phase, reason, n])
	await get_tree().create_timer(0.6).timeout
	await CG.play_theater("f8_defeat_%d_%d" % [phase, mini(n, 2)])
	await reset_phase()


## 从本阶段开头重来：两人满血回到起点，Boss 回到阶段开始的血量。
func reset_phase() -> void:
	for m in Duo.members:
		if is_instance_valid(m):
			var d := m.get_node_or_null("Downed")
			if d:
				d.free()
			m.revive()
			m._set_state(PlayableCharacter.State.IDLE)
			m.set_invulnerable(1.5, true)
	boss.health.set_hp(boss.phase_start_hp(phase))
	_place_for_fight()
	start_phase(phase)


func victory() -> void:
	busy = true
	boss.fighting = false
	boss._rage = true
	_cleanup_field()
	GameState.boss_changed.emit(null)
	await Cutscene.play("f8_victory_a")
	# 恼怒地乱砸墙壁：震屏、天花板滚下巨石
	for i in 6:
		for m in Duo.members:
			if is_instance_valid(m):
				m.shake(0.35)
		_drop_boulder(Vector2(randf_range(boss.arena.position.x + 30, boss.arena.end.x - 30), boss.arena.position.y + randf_range(30, 120)))
		Audio.play("break", -2.0, 0.1, 0.6)
		await get_tree().create_timer(0.35).timeout
	await Cutscene.play("f8_victory_b")
	GameState.set_flag("f8_boss_down")
	var main := get_tree().get_first_node_in_group("main")
	if main:
		main.change_level(Floors.scene("floor_08_chase"))


func _drop_boulder(at: Vector2) -> void:
	var b := Sprite2D.new()
	b.texture = BOULDER_TEX
	b.hframes = 4
	b.z_index = 4
	_level().add_child(b)
	b.global_position = at + Vector2(0, -160)
	var tw := b.create_tween()
	tw.tween_property(b, "global_position", at, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): Fx.burst(_level(), at, "dust", 10, 60.0, 0.5, Vector2(0, 30)))


## 巢穴里围着被献祭的人挠的手（只是表现）。
class LairHands extends Node2D:
	var target: Node2D
	var _t := 0.0

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		_t += delta
		if is_instance_valid(target):
			global_position = target.global_position
		queue_redraw()

	## 手都在她的左右两边（不挡住她本人）：6 个固定角度附近晃动。
	const ANGLES := [0.0, 35.0, 145.0, 180.0, 215.0, 325.0]

	func _draw() -> void:
		for i in 6:
			var a := deg_to_rad(ANGLES[i]) + sin(_t * 3.0 + i) * 0.25
			var p := Vector2(cos(a) * 20.0, -12.0 + sin(a) * 9.0)
			var f: int = [2, 4, 6][i % 3] + int(_t * 8.0 + i) % 2
			draw_texture_rect_region(Floor8Director.ARM, Rect2(p - Vector2(7, 7), Vector2(14, 14)), Rect2(f * 24, 0, 24, 24))

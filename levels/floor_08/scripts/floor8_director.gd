class_name Floor8Director
extends Node2D
## 第八层「千手之间」的导演（地图里放一个：X = f8director）。管：
##   开场：蓝色公主走进来 → 粉色公主被千手的手臂吊着挠 → 冰晶结界冻住手臂救下她 → 两人并肩（双人模式 Duo 开始）
##   三个阶段（ThousandHand 打到血量下限 → 过场 → 下一阶段）：
##     阶段一：Boss 能打，召唤小怪（小怪和 Boss 能凑三来源组合），俯冲撞墙
##     阶段二：两块压力板（站上去按下，人离开后还保持 PLATE_LATCH 秒；两块同时按下 PLATE_HOLD 秒 → 锁链把 Boss 拽下来 PULL_TIME 秒）；
##             地形持续变化：每 TERRAIN_STEP 秒在玩家附近长出一段石墙 / 泥沼 / 传送带 / 挠痒漩涡（TERRAIN_LIFE 秒后消失，
##             不会把压力板完全堵死）；手臂砸地不抓人、积累闷笑
##     阶段三：场地中央的光圈，谁走进去谁就在原地被手臂吊起来挠（右边小窗对准她，连按空格挣扎；另一个人打她也能帮她降闷笑），
##             另一个人打下来的手臂；红色脉动暗角 + 飘羽毛 + 阶段三配乐
##   战败：两个人都倒下 / 倒地超时 → 本阶段的战败小剧场 → 从本阶段开头重来（献祭的人笑满只是倒地）
##   胜利：Boss 恼怒、乱砸墙壁、巨石滚下来 → 进追逐战（floor_08_chase）
## 位置都用地图里的到达点（spawn id=…）：boss、pink、circle、plate_a1 / a2 / b1 / b2 / c1 / c2、summon1~4、limb1~4、blue_fight、pink_fight。

const BOSS_SCENE := "res://levels/floor_08/scenes/thousand_hand.tscn"
const PINK_SCENE := "res://scenes/actors/playable/princess.tscn"
const PLATE_TEX := preload("res://assets/generated/duo_plate.png")
const CIRCLE_TEX := preload("res://assets/generated/sacrifice_circle.png")
const BOULDER_TEX := preload("res://assets/generated/boulder.png")
const ARM := preload("res://assets/generated/thousand_hand_arm.png")
const PLATE_HOLD := 1.0
const PLATE_LATCH := 3.0
const PULL_TIME := 6.0
const TERRAIN_EVERY := 15.0
const TERRAIN_STEP := {2: 3.5, 3: 5.0}
const TERRAIN_LIFE := 12.0
const TERRAIN_MAX := 8
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
## 两块板各自还要保持按下多少秒（人离开后慢慢弹起）
var latch: Array[float] = [0.0, 0.0]
var _plate_rings: Array[Line2D] = []
var plate_ui: Label
var _plate_ui_layer: CanvasLayer
## 阶段三的持续特效（红色脉动暗角、飘羽毛）
var _p3_vignette: ScreenFx
var _p3_feathers: CPUParticles2D
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
	# 第八层由蓝色公主上来（粉色公主是被抓住的那个）：粉色公主当主角进来时（旧存档、跳过了第七层的交接）换成蓝色公主
	if not (GameState.player is BluePrincess):
		GameState.set_flag("blue_is_hero")
		lv.call("_swap_hero")
		await get_tree().process_frame
		await get_tree().process_frame
		lv.call("apply_camera_limits", GameState.player)
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
	_phase3_fx(false)
	if is_instance_valid(_plate_ui_layer):
		_plate_ui_layer.queue_free()
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
	# 冰晶结界：冻住手臂（Boss 受击闪白、震屏、冰晶四溅），粉色公主被甩下来（抛物线落地 + 尘土 + 星星）
	GameState.in_dialogue = true
	IceBarrier.cast_with(blue, 96.0, 1.5)
	boss.hurt_flash(0.5)
	boss.freeze(1.2)
	Fx.burst(_level(), boss.global_position + Vector2(0, -40), "crystal", 18, 90.0, 0.7, Vector2(0, 60), Color(0.85, 0.95, 1.0))
	for m in [blue, pink]:
		m.shake(0.35)
	Audio.play("break", -2.0, 0.0, 1.4)
	await get_tree().create_timer(0.35).timeout
	boss.cancel_attacks()
	pink.status.release(true)
	await throw_down(pink, marks.get("pink_fight", pink.global_position))
	GameState.in_dialogue = false
	if pink.emotion:
		pink.emotion.request("surprise", 1.5, false)
	Audio.play_music("boss")
	await Cutscene.play("f8_intro_b")
	GameState.set_flag("f8_intro_done")
	start_fight()


## 被手臂甩下来：抛物线飞到 to，落地尘土 + 头上转星星 + 一声「呀！」。
func throw_down(c: PlayableCharacter, to: Vector2) -> void:
	var from := c.global_position
	var tw := create_tween()
	tw.tween_method(func(f: float):
		c.global_position = from.lerp(to, f) + Vector2(0, -sin(f * PI) * 40.0), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	SpeechBubble.say(c, "呀——！", 30.0)
	await tw.finished
	Fx.burst(_level(), to, "dust", 12, 60.0, 0.5, Vector2(0, 30))
	Fx.burst(_level(), to + Vector2(0, -26), "ember", 6, 24.0, 0.8, Vector2.ZERO, Color(1, 0.95, 0.5))
	c.shake(0.3)
	Audio.play("drop", -2.0, 0.0, 0.8)
	await get_tree().create_timer(0.4).timeout


func start_fight() -> void:
	# 第八层两个人都会用魔法（AI 也会放）
	if pink.magic_flag != "":
		GameState.set_flag(pink.magic_flag)
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
	instant_defeat = false
	boss.set_phase(p)
	boss.skills.reset_cooldowns()
	boss.fighting = true
	busy = false
	_plate_pair = 0
	_plate_hold = 0.0
	_plate_wait = 0.0
	latch = [0.0, 0.0]
	_set_plates(p == 2)
	_circle_cd = 3.0 if p == 3 else INF
	_terrain_cd = 3.0 if p >= 2 else INF
	circle.visible = false
	_phase3_fx(p >= 3)
	Audio.play_music("boss3" if p >= 3 else "boss", 2.0)


## 阶段三的持续特效：红色脉动暗角 + 场地上一直飘羽毛。
func _phase3_fx(on: bool) -> void:
	if on and not is_instance_valid(_p3_vignette):
		_p3_vignette = ScreenFx.vignette(Color(0.9, 0.08, 0.18), 0.45, true)
		var a := boss.arena
		_p3_feathers = Fx.emitter(_level(), "feather", 14, 3.0, {"extents": Vector2(a.size.x * 0.5, 8), "dir": Vector2.DOWN,
			"spread": 25.0, "speed": [12.0, 26.0], "gravity": Vector2(6, 10), "z": 5, "color": Color(1, 0.85, 0.9)})
		if _p3_feathers:
			_p3_feathers.global_position = Vector2(a.get_center().x, a.position.y)
	elif not on:
		if is_instance_valid(_p3_vignette):
			_p3_vignette.fade_out(0.6)
		_p3_vignette = null
		if is_instance_valid(_p3_feathers):
			_p3_feathers.queue_free()
		_p3_feathers = null


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
			_terrain_cd = float(TERRAIN_STEP.get(phase, 4.0))
			grow_terrain()
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
		var ring := Line2D.new()
		ring.width = 2.0
		ring.default_color = Color(1, 0.85, 0.3)
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		ring.material = mat
		ring.z_index = 1
		s.add_child(ring)
		_plate_rings.append(ring)
	# 屏幕上方：两块板的状态
	_plate_ui_layer = CanvasLayer.new()
	_plate_ui_layer.layer = 9
	add_child(_plate_ui_layer)
	plate_ui = Label.new()
	plate_ui.add_theme_font_size_override("font_size", 10)
	plate_ui.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	plate_ui.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.1))
	plate_ui.add_theme_constant_override("outline_size", 3)
	plate_ui.position = Vector2(150, 34)   # Boss 血条下面
	plate_ui.visible = false
	_plate_ui_layer.add_child(plate_ui)


## 第 i 块板现在是不是按下的（有人站着，或人离开后还在保持时间里）。
func plate_pressed(i: int) -> bool:
	return plate_occupant(i) != null or latch[i] > 0.0


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
	plate_ui.visible = phase == 2
	if not plates_lit:
		_plate_wait -= delta
		plate_ui.text = "锁链拽住了它！" if boss.is_pulled() else "压力板重新亮起……"
		for r in _plate_rings:
			r.points = PackedVector2Array()
		if _plate_wait <= 0.0 and not boss.is_pulled():
			_plate_pair += 1
			_set_plates(true)
		return
	for i in plates.size():
		if plate_occupant(i) != null:
			latch[i] = PLATE_LATCH
		else:
			latch[i] = maxf(0.0, latch[i] - delta)
		# 按下：板子压扁一点、周围一圈进度（保持时间）
		var pressed := plate_pressed(i)
		plates[i].scale = Vector2(1.0, 0.8 if pressed else 1.0)
		_plate_rings[i].points = Downed._arc(14.0, latch[i] / PLATE_LATCH) if pressed else PackedVector2Array()
	var states := []
	for i in plates.size():
		states.append(("■ 按下（%.1f）" % latch[i]) if plate_pressed(i) else "□ 没人")
	plate_ui.text = "压力板　左 %s　右 %s" % states
	if plate_pressed(0) and plate_pressed(1):
		_plate_hold += delta
		if _plate_hold >= PLATE_HOLD:
			_plate_hold = 0.0
			pull_boss()
	else:
		_plate_hold = 0.0


func pull_boss() -> void:
	boss.pull_down(PULL_TIME)
	latch = [0.0, 0.0]
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


## 阶段二 / 三的持续地形：在玩家附近（她前进方向的前面、或她和要去的压力板之间）长出一样东西，TERRAIN_LIFE 秒后消失。
## 石墙长出来之后检查两个人还能走到两块压力板（阶段二）/ 光圈（阶段三），不能就收回。
func grow_terrain() -> void:
	if shifter.active_count() >= TERRAIN_MAX:
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	var keep := _keep_cells()
	var pc := _cell_of(p.global_position)
	var dir := p.velocity.normalized() if p.velocity.length() > 10.0 else Vector2.ZERO
	if dir == Vector2.ZERO and phase == 2 and plates_lit:
		var goal: Vector2 = plates[0].global_position if p.global_position.distance_to(plates[0].global_position) > p.global_position.distance_to(plates[1].global_position) else plates[1].global_position
		dir = (goal - p.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.from_angle(randf() * TAU)
	var ahead := pc + Vector2i(roundi(dir.x * 3.0), roundi(dir.y * 3.0))
	var r := arena_cells
	ahead.x = clampi(ahead.x, r.position.x + 2, r.end.x - 3)
	ahead.y = clampi(ahead.y, r.position.y + 4, r.end.y - 3)
	var kinds := ["wall", "wall", "mud", "conveyor", "vortex"]
	match kinds.pick_random():
		"wall":
			# 横在她前面的一段墙（和前进方向垂直，3~4 格）
			var perp := Vector2i(0, 1) if absf(dir.x) > absf(dir.y) else Vector2i(1, 0)
			var cells: Array = []
			var n := randi_range(3, 4)
			for k in n:
				var c: Vector2i = ahead + perp * (k - n / 2)
				if r.has_point(c) and not keep.has(c):
					cells.append(c)
			if cells.is_empty():
				return
			shifter.raise_walls(cells, TERRAIN_LIFE)
			if not _still_reachable():
				shifter.lower_cells(cells)
		"mud":
			if not keep.has(ahead):
				shifter.spawn_field("mud", ahead, {"w": 2, "h": 2}, TERRAIN_LIFE)
		"conveyor":
			var d: String = ["left", "right", "up", "down"].pick_random()
			if not keep.has(ahead):
				shifter.spawn_field("conveyor", ahead, {"dir": d, "len": 3}, TERRAIN_LIFE)
		"vortex":
			var v := ahead + Vector2i(roundi(dir.x), roundi(dir.y))
			if not keep.has(v):
				shifter.spawn_field("vortex", v, {"radius": 2}, TERRAIN_LIFE * 0.7)


## 两个人都还能走到要去的地方（阶段二：两块压力板；阶段三：光圈）。
func _still_reachable() -> bool:
	var goals: Array[Vector2] = []
	if phase == 2:
		for pl in plates:
			goals.append(pl.global_position + Vector2(0, 4))
	elif circle:
		goals.append(circle.global_position)
	var lv := _level()
	for m in Duo.members:
		if not is_instance_valid(m) or Downed.is_downed(m):
			continue
		for g in goals:
			if _cell_of(m.global_position) != _cell_of(g) and GridPath.find(lv, m.global_position, g, 6000).is_empty():
				return false
	return true


## AI 搭档：千手乱舞时去最近的安全圈（没有就返回 null）。
func safe_spot_for(ai: PlayableCharacter) -> Variant:
	if boss == null or boss.skills == null or boss.skills.safe_spots.is_empty():
		return null
	var best: Vector2 = boss.skills.safe_spots[0]
	for s in boss.skills.safe_spots:
		if s.distance_to(ai.global_position) < best.distance_to(ai.global_position):
			best = s
	return best


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
	# 就在光圈那里被手臂吊起来挠（不再传送到别的房间）
	boss.sacrifice_grab(c, circle.global_position)
	var win := SideWindow.open(c, {"title": "献祭 · %s" % c.display_name(), "hint": "连按 空格 挣扎", "zoom": 1.5})
	var st := SacrificeStruggle.start(c)
	win.set_overlay(st.overlay())
	st.escaped.connect(func(): end_sacrifice(true))
	st.broke.connect(func(): _sacrifice_broke(c))
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
	GameState.notify("打下来的手臂！被吊着的人连按空格挣扎；打她也能帮她降闷笑")
	SpeechBubble.say(other, "……撑住！" if other.character_id == "blue" else "等我！我马上打下来！", 30.0)


## 献祭的人笑满：她倒地（不直接战败；两个人都倒下才算输）。
func _sacrifice_broke(c: PlayableCharacter) -> void:
	end_sacrifice(false)
	if is_instance_valid(c) and c.is_alive():
		c.set_invulnerable(0.0)
		c._full_invuln = 0.0
		c.health.damage(c.health.hp)


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
	if p + 1 >= 3:
		Audio.play_music("boss3", 2.0)   # 进入阶段三的过场里交叉淡入阶段三配乐
	await Cutscene.play("f8_phase%d" % (p + 1))
	_regroup()
	start_phase(p + 1)


func _cleanup_field() -> void:
	shifter.clear()
	boss.clear_summons()
	boss.cancel_all()
	_phase3_fx(false)
	if plate_ui:
		plate_ui.visible = false
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

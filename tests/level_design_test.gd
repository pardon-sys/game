extends Node
## 关卡设计测试：强制遭遇段绕不过去、锁门战斗房的上锁 / 解锁 / 倒下重置、各层从起点能走到出口、
## 每个三来源组合都有「踩不开」的触发点。
## 用法：Godot --headless --path . res://tests/level_design_test.tscn   （退出码 0 = 全部通过）
##
## "危险格" = 关卡里所有陷阱覆盖的格子（风扇风道、整条传送带、机关手下方、压力板、羽毛 / 藤蔓 / 喷口 / 尖刺 / 旋转刷所在格）。
## 强制段检查：避开危险格就从 start 走不到 goal（证明玩家不得不踩进陷阱区），允许踩危险格时能走到（证明路是通的）。

## [楼层, 名称, 起点格, 终点格]
const FORCED := [
	["floor_01", "守卫室门前的羽毛门廊", Vector2i(31, 35), Vector2i(31, 29)],
	["floor_01", "尖刺走廊（尖刺 + 羽毛带）", Vector2i(8, 4), Vector2i(50, 4)],
	["floor_01", "宝库的传送带与羽毛带", Vector2i(52, 9), Vector2i(52, 17)],
	["floor_02", "蝙蝠巢穴的风扇风道", Vector2i(9, 22), Vector2i(17, 9)],
	["floor_02", "幽灵长廊的藤蔓带", Vector2i(17, 7), Vector2i(52, 9)],
	["floor_02", "机关走廊的整高传送带", Vector2i(50, 31), Vector2i(30, 33)],
	["floor_03", "鼠窝的藤蔓带", Vector2i(19, 47), Vector2i(38, 48)],
	["floor_03", "蟹池出口的传送带", Vector2i(50, 39), Vector2i(42, 33)],
	["floor_03", "传送带工坊", Vector2i(41, 33), Vector2i(30, 27)],
	["floor_03", "风洞走廊", Vector2i(30, 23), Vector2i(19, 18)],
	["floor_04", "水母池出口的诅咒符文走廊", Vector2i(38, 52), Vector2i(52, 52)],
	["floor_04", "泡泡水道的黏黏毛毯", Vector2i(53, 53), Vector2i(62, 44)],
	["floor_04", "足枷长廊（毛毯 + 整宽足枷台 + 符文 + 羽毛臂）", Vector2i(64, 40), Vector2i(64, 24)],
	["floor_04", "刺猬滚道的整高毛毯 + 顶墙羽毛臂", Vector2i(49, 17), Vector2i(21, 17)],
	["floor_04", "诅咒回廊（符文 + 毛毯 + 羽毛臂）", Vector2i(32, 18), Vector2i(32, 27)],
]
## 三来源组合的触发点（每个三来源组合至少一处）：
##   通道型 [楼层, 组合 id, 起点格, 终点格, 中心格]：组合里的每一种陷阱单独都绕不开（避开它就从起点走不到终点；
##     弹弹床按落点、滑溜肥皂地板按滑到的地方算——见 _moves），需要的每种怪物都在中心格 SPOT_RADIUS 格内。
##   战斗房型 [楼层, 组合 id, "arena:<铁栅组>"]：陷阱和怪物都在锁门战斗房里；有足枷台的组合，房里要有把人送进足枷台的
##     强制位移陷阱（漩涡中心 / 弹弹床落点 / 肥皂地板滑到的地方是足枷台）。
## 怪物算：地图上的怪物、会生成它的巢穴、会召唤它的 Boss。
const COMBO_SPOTS := [
	["floor_02", "line_end", Vector2i(50, 33), Vector2i(31, 33), Vector2i(34, 31)],
	["floor_02", "three_hands", Vector2i(50, 33), Vector2i(31, 33), Vector2i(34, 31)],
	["floor_02", "sticky_ghost", Vector2i(17, 7), Vector2i(52, 9), Vector2i(30, 5)],
	["floor_02", "wind_bubble", Vector2i(9, 22), Vector2i(17, 9), Vector2i(12, 16)],
	["floor_02", "night_trio", "arena:arena_spider"],
	["floor_02", "troll_stocks3", "arena:arena_troll"],
	["floor_03", "tentacle_feather", "arena:arena_boss"],
	["floor_03", "vault_trap", "arena:arena_boss"],
	["floor_03", "vine_stocks", "arena:arena_rats"],
	["floor_03", "jelly_sole_party", Vector2i(50, 39), Vector2i(42, 33), Vector2i(51, 33)],
	["floor_03", "sticky_belt", Vector2i(50, 39), Vector2i(42, 33), Vector2i(44, 33)],
	["floor_04", "queen_feast", "arena:arena_boss"],
	["floor_04", "queen_stocks3", "arena:arena_boss"],
	["floor_04", "sole_party", "arena:arena_plaza"],
	["floor_04", "sole_mobilize", "arena:arena_plaza"],
	["floor_04", "thousand_feather", "arena:arena_plaza"],
	["floor_04", "jelly_sole", "arena:arena_plaza"],
	["floor_04", "full_scrub", Vector2i(49, 17), Vector2i(20, 17), Vector2i(27, 17)],
	["floor_04", "brush_line", Vector2i(49, 17), Vector2i(20, 17), Vector2i(35, 17)],
	["floor_04", "curse_hall", Vector2i(25, 17), Vector2i(18, 17), Vector2i(21, 17)],
	["floor_04", "bubble_spa", Vector2i(53, 53), Vector2i(62, 44), Vector2i(58, 48)],
	["floor_04", "mob_curse", Vector2i(38, 52), Vector2i(52, 52), Vector2i(45, 51)],
	["floor_04", "ultimate_stocks", Vector2i(64, 40), Vector2i(64, 24), Vector2i(64, 32)],
	["floor_04", "auto_stocks", Vector2i(64, 40), Vector2i(64, 24), Vector2i(64, 32)],
	["floor_04", "curse_chain", Vector2i(64, 40), Vector2i(64, 24), Vector2i(64, 32)],
	["floor_05", "armpit_hands", "arena:arena_f5a"],
	["floor_05", "armpit_rain", "arena:arena_f5a"],
	["floor_05", "snare_sole_feast", "arena:arena_f5a"],
	["floor_05", "imp_fitting", "arena:arena_f5b"],
	["floor_05", "feather_cocoon", "arena:arena_f5b"],
	["floor_05", "frog_squirrel", "arena:arena_f5a"],
	["floor_05", "vest_caterpillar", "arena:arena_f5a"],
	["floor_05", "latch_party", "arena:arena_f5b"],
]
## 有 levels/<楼层>/design.json 的楼层（第五层）：combo_areas 里的组合按区域检查（陷阱和怪物都在区域里），
## chains 检查「可躲」（存在不碰静态束缚 / 位移陷阱的路）和「中招就连锁」（从前一个束缚陷阱放开后，
## 按强制位移——传送带、弹弹床、风扇、漩涡——会被送进下一个）。
const SPOT_RADIUS := 8
## 新机制第一次出现的楼层要有介绍石碑：[机制, 楼层, 石碑对话 id]。石碑要比机制先走到（从楼层起点按步数算），
## 而且离它不远（MECHANIC_SIGN_STEPS 步以内）。
const MECHANIC_SIGNS := [
	["怪物巢穴", "floor_02", "sign2_nest"],
	["弹弹床", "floor_02", "sign2_bounce"],
	["吸痒漩涡", "floor_02", "sign2_vortex"],
	["滑溜肥皂地板", "floor_03", "sign3_soap"],
	["落笼", "floor_05", "sign5_cage"],
	["绊线", "floor_05", "sign5_tripwire"],
	["机关小工匠", "floor_05", "sign5_imp"],
	["倒吊绳套", "floor_05", "sign5_snare"],
	["配套挠痒机关", "floor_05", "sign5_teaser"],
	["举手铐柱", "floor_05", "sign5_cuffs"],
	["挠痒衣柜", "floor_05", "sign5_wardrobe"],
	["夹腿枷台", "floor_05", "sign5_clamp"],
	["痒痒泥沼", "floor_05", "sign5_mud"],
	["单腿吊环", "floor_05", "sign5_legloop"],
	["痒痒长靴", "floor_05", "sign5_boots"],
	["羽毛绑腿", "floor_05", "sign5_binding"],
	["藤壶贝", "floor_05", "sign5_barnacle"],
	["掸子墙", "floor_05", "sign5_duster"],
	["落穴洞", "floor_05", "sign5_pit"],
	["仰卧刑床", "floor_05", "sign5_supine"],
	["肚脐羽毛钻", "floor_05", "sign5_drill"],
	["长舌蛙", "floor_05", "sign5_frog"],
	["吸盘章鱼宝宝", "floor_05", "sign5_octopus"],
	["痒痒滑梯", "floor_05", "sign5_chute"],
	["俯卧刑凳", "floor_05", "sign5_prone"],
	["刷尾松鼠", "floor_05", "sign5_squirrel"],
	["痒痒坐垫", "floor_05", "sign5_cushion"],
	["毛毛虫", "floor_05", "sign5_caterpillar"],
	["羽毛背心", "floor_05", "sign5_vest"],
	["张臂转盘", "floor_05", "sign5_spinwheel"],
]
const MECHANIC_SIGN_STEPS := 14
var _seen_mechanics := {}
## [楼层, 战斗房铁栅组]
const ARENAS := [
	["floor_01", "arena_guard"], ["floor_02", "arena_spider"], ["floor_02", "arena_troll"],
	["floor_03", "arena_rats"], ["floor_03", "arena_hall"], ["floor_03", "arena_trial"], ["floor_03", "arena_boss"],
	["floor_04", "arena_plaza"], ["floor_04", "arena_totem"], ["floor_04", "arena_gallery"], ["floor_04", "arena_boss"],
	["floor_05", "arena_f5a"], ["floor_05", "arena_f5b"],
]

var main: Node
var level: Node
var player: Princess
var failures := 0


func _ready() -> void:
	TickleZones.enabled = false  # 部位与敏感值会让挠痒数值随机变化；在 floor5_test 里测
	ComboTracker.play_scenes = false  # 三来源组合的小演出会暂停战斗；需要时在专门的测试里打开
	HUD.slow_motion = false
	Monster.random_specials = false  # 这里要精确的挠痒数值；暴击在 floor4_test 里测
	MagicFatigue.accumulate = false  # 同理，魔力疲倦的闷笑加成在 floor4_test 里测
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish_dialogue()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	GameState.set_flag("seen_laugh_recover")
	for id in Floors.ids():
		if id != "floor_01":
			main.change_level(Floors.scene(id))
			await _wait(1.4)
		_finish_dialogue()
		level = main.level
		player = GameState.player as Princess
		player.set_controller(ScriptedController.new())
		for e in get_tree().get_nodes_in_group("enemy"):
			e.process_mode = Node.PROCESS_MODE_DISABLED
		print("-- ", id)
		_run_forced(id)
		_run_combo_spots(id)
		_run_design(id)
		_run_mechanic_signs(id)
		await _run_arenas(id)
	var covered := {}
	for sp in COMBO_SPOTS:
		covered[sp[1]] = true
	for k in _area_combos:
		covered[k] = true
	var missing: Array = []
	for c in ComboTracker.data().get("combos", []):
		if c.get("keys", []).size() >= 3 and not covered.has(c["id"]):
			missing.append(c["id"])
	check("每个三来源组合都有触发点（缺：%s）" % [missing], missing.is_empty())
	check("新机制都在地图里出现过并检查了石碑", MECHANIC_SIGNS.all(func(ms): return _seen_mechanics.has(ms[0])))
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 强制遭遇
func _run_forced(id: String) -> void:
	var hazards := hazard_cells()
	for f in FORCED:
		if f[0] != id:
			continue
		var start: Vector2i = f[2]
		var goal: Vector2i = f[3]
		var open_ok := _reachable(start, goal, {})
		var avoid_ok := _reachable(start, goal, hazards)
		check("强制段「%s」：路是通的，但不踩陷阱区就过不去" % f[1], open_ok and not avoid_ok)
	if id == "floor_03":
		# 对照：安全区里不碰陷阱也能走动（证明上面的检查不是恒成立）
		check("对照：第三层落脚点里不踩陷阱也能走动", _reachable(Vector2i(10, 50), Vector2i(12, 45), hazards))
	if id == "floor_04":
		check("对照：刺猬滚道的毛毯之前不踩陷阱也能走动", _reachable(Vector2i(48, 17), Vector2i(43, 17), hazards))
	check("%s：从起点能走到每一块地面（铁栅、门视为可通过）" % id, _reachable_all())


## 所有陷阱覆盖的格子。
func hazard_cells() -> Dictionary:
	var walls: TileMapLayer = level.get_node("Walls")
	var cells := {}
	var cell_of := func(p: Vector2) -> Vector2i: return walls.local_to_map(walls.to_local(p))
	for n in level.find_children("*", "", true, false):
		if n is FeatherFan:
			var fan := n as FeatherFan
			var c0: Vector2i = cell_of.call(fan.global_position)
			for dx in range(-fan.length - 2, fan.length + 3):
				for dy in range(-fan.length - 2, fan.length + 3):
					var c := c0 + Vector2i(dx, dy)
					if fan.in_lane(walls.to_global(walls.map_to_local(c))):
						cells[c] = true
			cells[c0] = true
		elif n is TickleConveyor:
			var belt := n as TickleConveyor
			var c0: Vector2i = cell_of.call(belt.global_position)
			for i in belt.length:
				cells[c0 + Vector2i(belt.belt) * i] = true
		elif n is StickyCarpet:
			var carpet := n as StickyCarpet
			var c0: Vector2i = cell_of.call(carpet.global_position)
			for dx in carpet.tiles_w:
				for dy in carpet.tiles_h:
					cells[c0 + Vector2i(dx, dy)] = true
		elif n is FeatherArm:
			var arm := n as FeatherArm
			var wall_cell: Vector2i = cell_of.call(arm.global_position + Vector2(0, -8))
			for i in arm.length:
				cells[wall_cell + Vector2i(arm.lane) * (i + 1)] = true
		elif n is GrabHand:
			cells[cell_of.call((n as Node2D).global_position) + Vector2i(0, 1)] = true
		elif n is Trap or (n.get_script() and str(n.get_script().resource_path).ends_with("pressure_plate.gd")):
			cells[cell_of.call((n as Node2D).global_position)] = true
	return cells


func _walkable(c: Vector2i, blocked: Dictionary) -> bool:
	var walls: TileMapLayer = level.get_node("Walls")
	var floor_layer: TileMapLayer = level.get_node("Floor")
	return floor_layer.get_cell_source_id(c) != -1 and walls.get_cell_source_id(c) == -1 and not blocked.has(c)


func _flood(start: Vector2i, blocked: Dictionary) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nc: Vector2i = c + d
			if not seen.has(nc) and _walkable(nc, blocked):
				seen[nc] = true
				queue.append(nc)
	return seen


func _reachable(start: Vector2i, goal: Vector2i, blocked: Dictionary) -> bool:
	return _flood(start, blocked).has(goal)


func _reachable_all() -> bool:
	var walls: TileMapLayer = level.get_node("Walls")
	var start := walls.local_to_map(walls.to_local(player.global_position))
	var seen := _flood(start, {})
	var missing := 0
	for c in (level.get_node("Floor") as TileMapLayer).get_used_cells():
		if _walkable(c, {}) and not seen.has(c):
			missing += 1
	# 第一层的秘密储物间要推倒暗墙才进得去
	return missing == 0 or (level.get("floor_id") == "floor_01" and missing <= 60)


# ------------------------------------------------------------------ 第五层：组合区域 + 连锁段（design.json）
func _run_design(id: String) -> void:
	var path := "res://levels/%s/design.json" % id
	if not FileAccess.file_exists(path):
		return
	var design: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var walls: TileMapLayer = level.get_node("Walls")
	for area in design.get("combo_areas", []):
		var r: Array = area["rect"]
		var cell_rect := Rect2i(int(r[0]), int(r[1]), int(r[2]) - int(r[0]) + 1, int(r[3]) - int(r[1]) + 1)
		var in_rect := func(p: Vector2) -> bool: return cell_rect.has_point(walls.local_to_map(walls.to_local(p)))
		var combo: Dictionary = ComboTracker.combo_def(str(area["combo"]))
		var problems: Array[String] = []
		var monster_slots: Array = []
		for slot in combo["keys"]:
			if ComboTracker.group("trap").has(slot[0]):
				if not _cells_of(slot).keys().any(func(c): return cell_rect.has_point(c)):
					problems.append("区域里没有陷阱 %s" % [slot])
			else:
				monster_slots.append(slot)
		problems.append_array(_missing_monsters(monster_slots, in_rect))
		check("三来源组合区域「%s」%s" % [ReactionDB.combo(str(area["combo"])).get("name", area["combo"]),
			("" if problems.is_empty() else "：" + "；".join(problems))], problems.is_empty())
		_area_combos[str(area["combo"])] = true
	var static_cells := _static_hazards()
	for ch in design.get("chains", []):
		var start := Vector2i(int(ch["start"][0]), int(ch["start"][1]))
		var goal := Vector2i(int(ch["goal"][0]), int(ch["goal"][1]))
		var links: Array = ch["links"]
		var safe := _route_ok(start, goal, static_cells)
		var flow_ok := true
		var bad := ""
		for i in links.size() - 1:
			var a := Vector2i(int(links[i][0]), int(links[i][1]))
			var b := Vector2i(int(links[i + 1][0]), int(links[i + 1][1]))
			if not _flow(a).has(b):
				flow_ok = false
				bad = "%s → %s" % [a, b]
		check("连锁段「%s」：有一条不碰束缚 / 位移陷阱的路（可躲）" % ch["name"], safe)
		check("连锁段「%s」：中了一个就被送进下一个（%d 环）%s" % [ch["name"], links.size(), "" if flow_ok else "，断在 " + bad], flow_ok)


var _area_combos := {}


## 静态的束缚 / 位移陷阱覆盖的格子（连锁段「可躲」检查要避开的；落笼、绊线、喷口、逗弄器、转轮、羽毛臂这类靠时机躲的不算）。
func _static_hazards() -> Dictionary:
	var out := {}
	for n in level.find_children("*", "", true, false):
		if n is RestraintTrap or n is TickleConveyor or n is BouncePad or n is SoapFloor or n is TickleVortex or n is FeatherFan or n is ChuteTrap \
				or n is Stocks or n is StickyCarpet or n is HexRune or n is TickleVine:
			for c in _trap_cover(n as Trap):
				out[c] = true
		if n is SoapFloor:
			for c in _forced_maps()["soap"]:
				out[c] = true
	return out


## 从 start 出发只受强制位移（弹弹床 → 落点、传送带 → 顺着走、滑梯 → 顺着滑、风扇风道 → 顺风、漩涡范围 → 中心）会经过的格子。
func _flow(start: Vector2i) -> Dictionary:
	var walls: TileMapLayer = level.get_node("Walls")
	var fm := _forced_maps()
	var belts := {}
	var fans := {}
	var vortices: Array = []
	for n in level.find_children("*", "", true, false):
		if n is TickleConveyor:
			var belt := n as TickleConveyor
			var c0 := walls.local_to_map(walls.to_local(belt.global_position))
			for i in belt.length:
				belts[c0 + Vector2i(belt.belt) * i] = Vector2i(belt.belt)
		elif n is FeatherFan:
			for c in _trap_cover(n as Trap):
				fans[c] = Vector2i((n as FeatherFan).wind)
		elif n is TickleVortex:
			vortices.append([walls.local_to_map(walls.to_local((n as Node2D).global_position)), (n as TickleVortex).radius])
	var visited := {start: true}
	var c := start
	for step in 120:
		var nxt := c
		if fm["pads"].has(c):
			nxt = fm["pads"][c]
		elif belts.has(c):
			nxt = c + belts[c]
		elif fm["chute"].has(c):
			nxt = c + fm["chute"][c]
		elif fans.has(c):
			nxt = c + fans[c]
		else:
			for v in vortices:
				if c != v[0] and Vector2(c - v[0]).length() <= float(v[1]):
					nxt = v[0]
					break
		if nxt == c or not _walkable(nxt, {}):
			break
		visited[nxt] = true
		c = nxt
	return visited


# ------------------------------------------------------------------ 新机制的介绍石碑
func _run_mechanic_signs(id: String) -> void:
	var walls: TileMapLayer = level.get_node("Walls")
	var dist := _distances(walls.local_to_map(walls.to_local(player.global_position)))
	for ms in MECHANIC_SIGNS:
		var cells := _mechanic_cells(str(ms[0]))
		if cells.is_empty() or _seen_mechanics.has(ms[0]):
			continue
		_seen_mechanics[ms[0]] = id
		var first := INF
		for c in cells:
			first = minf(first, float(dist.get(c, INF)))
		var sign_d := INF
		for n in level.find_children("*", "", true, false):
			if n.get("dialogue") == ms[2] and n is Node2D:
				# 石碑的位置在格子底边上：取它所在的那一格
				sign_d = float(dist.get(walls.local_to_map(walls.to_local((n as Node2D).global_position + Vector2(0, -8))), INF))
		var lines: Array = Dialogue._data.get(ms[2], []) if Dialogue.has_dialogue(ms[2]) else []
		var text_ok := not lines.is_empty() and str(lines[0].get("text", "")).begins_with("【%s】" % ms[0])
		check("新机制「%s」第一次出现在 %s，前面有介绍石碑（石碑 %s 步，机制 %s 步）" % [ms[0], id, sign_d, first],
			id == ms[1] and text_ok and sign_d < first and first - sign_d <= MECHANIC_SIGN_STEPS)


## 本层这种机制占的格子。
func _mechanic_cells(mech: String) -> Array[Vector2i]:
	var walls: TileMapLayer = level.get_node("Walls")
	var out: Array[Vector2i] = []
	for n in level.find_children("*", "", true, false):
		var c0 := walls.local_to_map(walls.to_local((n as Node2D).global_position)) if n is Node2D else Vector2i.ZERO
		match mech:
			"怪物巢穴":
				if n is MonsterNest:
					out.append(c0)
			"弹弹床":
				if n is BouncePad:
					out.append(c0)
			"滑溜肥皂地板":
				if n is SoapFloor:
					for dx in (n as SoapFloor).tiles_w:
						for dy in (n as SoapFloor).tiles_h:
							out.append(c0 + Vector2i(dx, dy))
			"落笼":
				if n is CageTrap:
					out.append(c0)
			"绊线":
				if n is TripwireTrap:
					out.append_array(_trap_cover(n as Trap))
			"机关小工匠":
				if n is MachineImp:
					out.append(c0)
			"倒吊绳套":
				if n is SnareTrap:
					out.append(c0)
			"配套挠痒机关":
				if n is TeaserTrap or n is WheelTrap or n is ShowerTrap:
					out.append(c0)
			"举手铐柱":
				if n is CuffsTrap:
					out.append(c0)
			"挠痒衣柜":
				if n is WardrobeTrap:
					out.append(c0)
			"夹腿枷台":
				if n is ClampTrap:
					out.append(c0)
			"痒痒泥沼":
				if n is MudTrap:
					out.append_array(_trap_cover(n as Trap))
			"单腿吊环":
				if n is LegLoopTrap:
					out.append(c0)
			"痒痒长靴":
				if n is BootsTrap:
					out.append(c0)
			"羽毛绑腿":
				if n is BindingTrap:
					out.append(c0)
			"藤壶贝":
				if n is Barnacle:
					out.append(c0)
			"掸子墙":
				if n is DusterWall:
					out.append_array(_trap_cover(n as Trap))
			"落穴洞":
				if n is PitTrap:
					out.append(c0)
			"仰卧刑床":
				if n is SupineTrap:
					out.append(c0)
			"肚脐羽毛钻":
				if n is TeaserTrap and (n as TeaserTrap).content == "drill":
					out.append(c0)
			"长舌蛙":
				if n is TongueFrog:
					out.append(c0)
			"吸盘章鱼宝宝":
				if n is SuctionOctopus:
					out.append(c0)
			"痒痒滑梯":
				if n is ChuteTrap:
					out.append_array(_trap_cover(n as Trap))
			"俯卧刑凳":
				if n is ProneTrap:
					out.append(c0)
			"刷尾松鼠":
				if n is BrushSquirrel:
					out.append(c0)
			"痒痒坐垫":
				if n is CushionTrap:
					out.append(c0)
			"毛毛虫":
				if n is Caterpillar:
					out.append(c0)
			"羽毛背心":
				if n is VestTrap:
					out.append(c0)
			"张臂转盘":
				if n is SpinWheelTrap:
					out.append(c0)
			"吸痒漩涡":
				if n is TickleVortex:
					var r: int = (n as TickleVortex).radius
					for dx in range(-r, r + 1):
						for dy in range(-r, r + 1):
							if Vector2(dx, dy).length() <= r:
								out.append(c0 + Vector2i(dx, dy))
	return out


## 从 start 出发到每一格的步数（铁栅、门、陷阱都当作能走）。
func _distances(start: Vector2i) -> Dictionary:
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nc: Vector2i = c + d
			if not dist.has(nc) and _walkable(nc, {}):
				dist[nc] = int(dist[c]) + 1
				queue.append(nc)
	return dist


# ------------------------------------------------------------------ 三来源组合的触发点
func _run_combo_spots(id: String) -> void:
	var walls: TileMapLayer = level.get_node("Walls")
	for sp in COMBO_SPOTS:
		if sp[0] != id:
			continue
		var combo: Dictionary = ComboTracker.combo_def(sp[1])
		var name := str(ReactionDB.combo(sp[1]).get("name", sp[1]))
		var trap_slots: Array = []
		var monster_slots: Array = []
		for slot in combo["keys"]:
			if ComboTracker.group("trap").has(slot[0]):
				trap_slots.append(slot)
			else:
				monster_slots.append(slot)
		var problems: Array[String] = []
		if sp[2] is String:
			var arena := _arena(str(sp[2]).trim_prefix("arena:"))
			if arena == null:
				problems.append("没有战斗房 " + sp[2])
			else:
				var rect := arena.room_rect()
				for slot in trap_slots:
					if not _cells_of(slot).keys().any(func(c): return rect.has_point(walls.to_global(walls.map_to_local(c)))):
						problems.append("房里没有陷阱 %s" % [slot])
				if trap_slots.any(func(slot): return slot.has("stocks")) and not _delivers_to_stocks(rect):
					problems.append("房里没有把人送进足枷台的强制位移陷阱")
				problems.append_array(_missing_monsters(monster_slots, func(p: Vector2): return rect.has_point(p)))
		else:
			var start: Vector2i = sp[2]
			var goal: Vector2i = sp[3]
			var center: Vector2 = walls.to_global(walls.map_to_local(sp[4]))
			if not _route_ok(start, goal, {}):
				problems.append("起点走不到终点")
			for slot in trap_slots:
				var cells := _cells_of(slot)
				if _route_ok(start, goal, cells):
					problems.append("陷阱 %s 绕得开" % [slot])
				if not cells.keys().any(func(c): return walls.to_global(walls.map_to_local(c)).distance_to(center) <= SPOT_RADIUS * 16.0):
					problems.append("陷阱 %s 不在中心附近" % [slot])
			problems.append_array(_missing_monsters(monster_slots, func(p: Vector2): return p.distance_to(center) <= SPOT_RADIUS * 16.0))
		check("三来源触发点「%s」%s" % [name, ("" if problems.is_empty() else "：" + "；".join(problems))], problems.is_empty())


## 某个组合槽位（可选来源键列表）对应的陷阱覆盖的格子。
func _cells_of(slot: Array) -> Dictionary:
	var out := {}
	for n in level.find_children("*", "", true, false):
		if n is Trap and slot.has(str(n.get("reaction_key"))):
			for c in _trap_cover(n as Trap):
				out[c] = true
	return out


## 单个陷阱覆盖的格子（和 hazard_cells 同样的规则；旋转刷按刷臂扫到的 3x3）。
func _trap_cover(n: Trap) -> Array[Vector2i]:
	var walls: TileMapLayer = level.get_node("Walls")
	var c0 := walls.local_to_map(walls.to_local(n.global_position))
	var out: Array[Vector2i] = []
	if n is FeatherFan:
		var fan := n as FeatherFan
		for dx in range(-fan.length - 2, fan.length + 3):
			for dy in range(-fan.length - 2, fan.length + 3):
				var c := c0 + Vector2i(dx, dy)
				if fan.in_lane(walls.to_global(walls.map_to_local(c))):
					out.append(c)
	elif n is TickleConveyor:
		for i in (n as TickleConveyor).length:
			out.append(c0 + Vector2i((n as TickleConveyor).belt) * i)
	elif n is StickyCarpet:
		for dx in (n as StickyCarpet).tiles_w:
			for dy in (n as StickyCarpet).tiles_h:
				out.append(c0 + Vector2i(dx, dy))
	elif n is FeatherArm:
		var wall_cell := walls.local_to_map(walls.to_local(n.global_position + Vector2(0, -8)))
		for i in (n as FeatherArm).length:
			out.append(wall_cell + Vector2i((n as FeatherArm).lane) * (i + 1))
	elif n is GrabHand:
		# 装在墙上：抓的是墙格下面那一格
		out.append(walls.local_to_map(walls.to_local(n.global_position + Vector2(0, -8))) + Vector2i(0, 1))
	elif n is FeatherBrush:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				out.append(c0 + Vector2i(dx, dy))
	elif n is MudTrap:
		for dx in (n as MudTrap).tiles_w:
			for dy in (n as MudTrap).tiles_h:
				out.append(c0 + Vector2i(dx, dy))
	elif n is ChuteTrap:
		for dx in (n as ChuteTrap).tiles_w:
			for dy in (n as ChuteTrap).tiles_h:
				out.append(c0 + Vector2i(dx, dy))
	elif n is DusterWall:
		var d := n as DusterWall
		var wall0 := walls.local_to_map(walls.to_local(n.global_position + Vector2(0, -8)))
		for i in d.length:
			out.append(wall0 + Vector2i(d.lane) + Vector2i(d.along) * i)
	elif n is TripwireTrap:
		var tw := n as TripwireTrap
		for i in tw.tiles_w:
			out.append(c0 + (Vector2i(0, i) if tw.vertical else Vector2i(i, 0)))
	elif n is ShowerTrap:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				out.append(c0 + Vector2i(dx, dy))
	elif n is TickleVortex:
		var r := (n as TickleVortex).radius
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if Vector2(dx, dy).length() <= r:
					out.append(c0 + Vector2i(dx, dy))
	else:
		out.append(c0)
	return out


## 强制位移：弹弹床格 -> 落点格；肥皂地板格；滑梯格 -> 滑的方向；滑行停下的格（会抓人 / 定身的陷阱）。
func _forced_maps() -> Dictionary:
	var walls: TileMapLayer = level.get_node("Walls")
	var pads := {}
	var soap := {}
	var chute := {}
	var stoppers := {}
	for n in level.find_children("*", "", true, false):
		if n is BouncePad:
			pads[walls.local_to_map(walls.to_local((n as BouncePad).global_position))] = walls.local_to_map(walls.to_local((n as BouncePad).landing_point()))
		elif n is SoapFloor:
			var s := n as SoapFloor
			var c0 := walls.local_to_map(walls.to_local(s.global_position))
			for dx in s.tiles_w:
				for dy in s.tiles_h:
					soap[c0 + Vector2i(dx, dy)] = true
		elif n is ChuteTrap:
			for c in _trap_cover(n as Trap):
				chute[c] = Vector2i((n as ChuteTrap).lane)
		if n is Trap and (n as Trap).stops_slide:
			for c in _trap_cover(n as Trap):
				stoppers[c] = true
	return {"pads": pads, "soap": soap, "chute": chute, "stoppers": stoppers}


## 从 c 出发的一步：[到达的格, 碰到的格]。踩上弹弹床直接飞到落点（飞过的不算碰到）；
## 踩上肥皂地板沿这个方向一直滑到离开地板、撞墙或停在会抓人 / 定身的陷阱上（滑过的格都算碰到）；
## 踩上滑梯沿滑梯的方向（拐角跟着下一段）滑到离开滑梯、撞墙或停在束缚陷阱上。
func _moves(c: Vector2i, fm: Dictionary) -> Array:
	var out: Array = []
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var n: Vector2i = c + d
		if not _walkable(n, {}):
			continue
		if fm["pads"].has(n):
			var land: Vector2i = fm["pads"][n]
			if _walkable(land, {}):
				out.append([land, [land]])
		elif fm["soap"].has(n):
			var cur := n
			var touched: Array = [n]
			while fm["soap"].has(cur) and not fm["stoppers"].has(cur) and _walkable(cur + d, {}):
				cur += d
				touched.append(cur)
			out.append([cur, touched])
		elif fm["chute"].has(n):
			var cur := n
			var touched: Array = [n]
			while fm["chute"].has(cur) and not fm["stoppers"].has(cur) and _walkable(cur + fm["chute"][cur], {}) and touched.size() < 64:
				cur += fm["chute"][cur]
				touched.append(cur)
			out.append([cur, touched])
		else:
			out.append([n, [n]])
	return out


## 不碰 forbidden 里的格子能不能从 start 走到 goal（按强制位移的规则）。
func _route_ok(start: Vector2i, goal: Vector2i, forbidden: Dictionary) -> bool:
	var fm := _forced_maps()
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		if c == goal:
			return true
		for mv in _moves(c, fm):
			var to: Vector2i = mv[0]
			if seen.has(to) or (mv[1] as Array).any(func(t): return forbidden.has(t)):
				continue
			seen[to] = true
			queue.append(to)
	return false


## 战斗房里有没有把人送进足枷台的强制位移陷阱。
func _delivers_to_stocks(rect: Rect2) -> bool:
	var walls: TileMapLayer = level.get_node("Walls")
	var stocks := _cells_of(["stocks"])
	var fm := _forced_maps()
	for n in level.find_children("*", "", true, false):
		if not (n is Trap) or not rect.has_point((n as Node2D).global_position + Vector2(0, 4)) and not (n is SoapFloor):
			continue
		var c0 := walls.local_to_map(walls.to_local((n as Node2D).global_position))
		if n is TickleVortex and stocks.has(c0):
			return true
		if n is BouncePad and stocks.has(fm["pads"][c0]):
			return true
		if n is SoapFloor:
			for sc in fm["soap"]:
				if not rect.has_point(walls.to_global(walls.map_to_local(sc))):
					continue
				for mv in _moves(sc - Vector2i.LEFT, fm) + _moves(sc - Vector2i.RIGHT, fm) + _moves(sc - Vector2i.UP, fm) + _moves(sc - Vector2i.DOWN, fm):
					if stocks.has(mv[0]) and (mv[1] as Array).has(sc):
						return true
	return false


## 按范围找组合需要的怪物，返回缺少的槽位说明。
func _missing_monsters(slots: Array, in_range: Callable) -> Array[String]:
	var have := {}
	var total := 0
	for n in level.find_children("*", "", true, false):
		var keys: Array[String] = []
		if n is Monster and in_range.call((n as Node2D).global_position):
			keys.append((n as Monster).stats.reaction_key)
			# Boss 会召唤的怪物
			if n is TentacleBoss:
				keys.append("fairy")
			elif n is TickleTroll:
				keys.append("bat")
			elif n is JellyQueen:
				keys.append("mana_jelly")
		elif n is CageTrap and (n as CageTrap).content != "feather" and in_range.call((n as Node2D).global_position):
			keys.append("slime" if (n as CageTrap).content == "slime" else "tentacle")  # 落笼放出来的怪物
		elif n is MonsterNest and in_range.call((n as Node2D).global_position):
			var m: Monster = load((n as MonsterNest).monster_scene).instantiate()
			keys.append(m.stats.reaction_key)
			m.free()
		for k in keys:
			have[k] = int(have.get(k, 0)) + 1
			total += 1
	var out: Array[String] = []
	var wild := 0
	for slot in slots:
		if slot.has("*"):
			wild += 1
		elif not slot.any(func(k): return have.has(k)):
			out.append("缺怪物 %s" % [slot])
	if total < wild + (slots.size() - wild):
		out.append("怪物不够（需要 %d 只，只有 %d）" % [slots.size(), total])
	return out


# ------------------------------------------------------------------ 锁门战斗房
func _gates(group: String) -> Array:
	return get_tree().get_nodes_in_group(group).filter(func(n: Node): return n is StaticBody2D and n.has_method("set_open"))


func _arena(group: String) -> ArenaZone:
	for a in get_tree().get_nodes_in_group("arena"):
		if a.group_name == group:
			return a
	return null


func _run_arenas(id: String) -> void:
	for a_info in ARENAS:
		if a_info[0] != id:
			continue
		var group: String = a_info[1]
		var arena := _arena(group)
		var gates := _gates(group)
		check("战斗房 %s 存在且有铁栅" % group, arena != null and not gates.is_empty())
		if arena == null:
			continue
		check("%s：进去之前门是开的" % group, gates.all(func(g: Node): return g.is_open))
		player.revive()
		player.global_position = arena.global_position
		await _wait(0.2)
		check("%s：进去后门关上、困在房间里" % group, arena.active and gates.all(func(g: Node): return not g.is_open) and arena.remaining() > 0)
		if group == ARENAS.filter(func(x: Array): return x[0] == id)[0][1]:
			# 每层第一个战斗房再测一次倒下重置
			await _laugh_down()
			check("%s：中途笑倒 → CG → 复活后门打开、战斗重置" % group, not arena.active and gates.all(func(g: Node): return g.is_open) and not arena.cleared)
			player.global_position = arena.global_position
			await _wait(0.2)
			check("%s：再次进入重新上锁" % group, arena.active and gates.all(func(g: Node): return not g.is_open))
		for m in arena._tracked:
			if is_instance_valid(m) and m.is_alive():
				if m is MonsterNest:
					(m as MonsterNest).smash()  # 巢穴要打碎
				else:
					m.health.damage(999)
		await _wait(0.4)
		for m in get_tree().get_nodes_in_group("enemy"):  # 分裂出来 / 召唤出来的
			if arena.room_rect().has_point(m.global_position) and m.is_alive():
				m.health.damage(999)
		await _wait(0.4)
		check("%s：打倒所有怪物后开门，不再触发" % group, not arena.active and arena.cleared and gates.all(func(g: Node): return g.is_open))
		_finish_dialogue()


func _laugh_down() -> void:
	player._full_invuln = 0.0
	player.health.damage(player.health.hp - 1)
	player.laugh.set_value(148.0)
	var src := Node2D.new()
	level.get_node("Entities").add_child(src)
	player.receive_hit(HitData.make_tickle(src, 10.0))
	var t := 0.0
	while not CG.is_playing() and t < 3.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	CG._can_skip = true
	CG.skip()
	await _wait(0.8)
	_finish_dialogue()
	src.queue_free()


# ------------------------------------------------------------------ 工具
func check(label: String, ok: bool) -> void:
	print(("  [通过] " if ok else "  [失败] ") + label)
	if not ok:
		failures += 1


func _finish_dialogue() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 100:
		Dialogue.advance()
		Dialogue.advance()
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

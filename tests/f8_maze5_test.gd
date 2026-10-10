extends Node
## 第八层夜迷宫第五轮的玩法：QTE 数字键、身上的小手、大量手提示、憋笑键、黑暗更怕痒、大手隔墙探照、夜啼追手 + 固定追逐、
## 遮眼蝠、墙缝刷轮、垂落吊手、以前楼层的束缚陷阱、出口微光、生成的数量和位置。
## 用法：Godot --headless --path . res://tests/f8_maze5_test.tscn   （退出码 0 = 全部通过）

var main: Node
var failures := 0


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept",
			"blue_is_hero", "f8m_dark_first", "cutscene_seen_f8_maze_intro", "intro_done_f8_maze_intro", "f8m_tutorial",
			"f8m_hint_hold", "f8m_hint_qte"]:
		GameState.set_flag(f)
	for id in ["first", "total_8", "total_12", "weak_first", "weak_4"]:
		GameState.set_flag("f8m_ms_" + id)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	_run_generated()
	await _goto(1)
	await _run_qte()
	await _run_body_hands_and_alarm()
	await _run_hold_laugh()
	await _run_dark()
	await _run_traps()
	await _goto(2)
	await _run_shadow()
	await _run_stalker()
	await _run_bat()
	await _goto(3)
	await _run_scripted_chase()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


func _dir() -> MazeDirector:
	return MazeDirector.instance


func _goto(sec: int) -> void:
	await main.change_level(Floors.scene("floor_08_maze_%d" % sec))
	await _advance_until(func(): return _dir() != null and _dir().section == sec and _dir().blue != null and not Cutscene.is_playing(), 20.0)
	_finish()
	await _wait(0.3)
	_quiet()


## 先让场上安静：怪物、紫手、追逐怪、遮眼蝠停下，束缚陷阱关掉；要测的再单独打开。
func _quiet() -> void:
	var dir := _dir()
	dir.cover.clear()
	dir._spawn_t = 999.0
	for h in get_tree().get_nodes_in_group("maze_hand"):
		h.queue_free()
	for g in ["enemy", "night_stalker", "blind_bat"]:
		for e in get_tree().get_nodes_in_group(g):
			e.process_mode = Node.PROCESS_MODE_DISABLED
	for t in get_tree().get_nodes_in_group("restraint"):
		(t as Trap).active = false
	var blue := dir.blue
	blue.laugh.set_value(0.0)
	blue.set_invulnerable(0.0)
	blue._full_invuln = 0.0


func _fresh(blue: PlayableCharacter) -> void:
	blue.laugh.set_value(0.0)
	blue.set_invulnerable(0.0)
	blue._full_invuln = 0.0
	if blue.status:
		blue.status.clear()


## 地图上一块离光远、四周都是地面的地方。
func _open_spot(min_from_light := 60.0) -> Vector2:
	var dir := _dir()
	for c in dir._floor_cells:
		var p := GridPath.center(c)
		if dir.light_at(p) is Vector2:
			continue
		var far := true
		for l in get_tree().get_nodes_in_group("moon_lamp"):
			if (l as Node2D).global_position.distance_to(p) < min_from_light:
				far = false
		if far and GridPath.walkable(main.level, c + Vector2i(1, 0)) and GridPath.walkable(main.level, c - Vector2i(1, 0)):
			return p
	return dir.blue.global_position


# ------------------------------------------------------------------ 生成的数量和位置
func _run_generated() -> void:
	print("-- 生成：数量 / 位置")
	var want := {1: {"wall_brush": 2}, 2: {"wall_brush": 3, "grab_hand": 2, "thigh_pincer": 1, "night_stalker": 1},
		3: {"wall_brush": 4, "thigh_pincer": 2, "feather_arm": 2, "night_stalker": 1, "stalker_zone": 1}}
	var scatter := {1: {"hanging_hands": 1, "snare": 1}, 2: {"blind_bat": 2, "hanging_hands": 2, "binding": 1},
		3: {"blind_bat": 3, "hanging_hands": 3, "cuffs": 1}}
	for sec in [1, 2, 3]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/floor_08_maze_%d/design.json" % sec))
		var got := {}
		for dev in d.get("devices", []):
			got[dev["kind"]] = int(got.get(dev["kind"], 0)) + 1
		var ok := true
		for k in want[sec]:
			if int(got.get(k, 0)) != int(want[sec][k]):
				ok = false
		var text := FileAccess.get_file_as_string("res://levels/floor_08_maze_%d/map.txt" % sec)
		var legend := {}
		for ln in text.split("\n"):
			if " = " in ln and ln.length() > 4 and ln[1] == " ":
				legend[ln[0]] = ln.substr(4)
		var grid := text.split("[map]\n")[1].split("\n")
		var counts := {}
		for row in grid:
			for ch in row:
				if legend.has(ch):
					for k in scatter[sec]:
						if ("type=" + k) in legend[ch]:
							counts[k] = int(counts.get(k, 0)) + 1
		for k in scatter[sec]:
			if int(counts.get(k, 0)) != int(scatter[sec][k]):
				ok = false
		check("第 %d 段：墙上的陷阱 / 追逐怪（%s）、散放的新怪物 / 陷阱（%s）数量对" % [sec, got, counts], ok)


# ------------------------------------------------------------------ QTE
func _run_qte() -> void:
	print("-- QTE：数字键 1~4")
	var blue := _dir().blue
	var q := KeySequenceQTE.start(blue, 5, 3.0)
	await get_tree().process_frame
	var only_digits := q.keys.all(func(k): return k in [KEY_1, KEY_2, KEY_3, KEY_4])
	var first := q.expected()
	var kp: int = {KEY_1: KEY_KP_1, KEY_2: KEY_KP_2, KEY_3: KEY_KP_3, KEY_4: KEY_KP_4}[first]
	q.press(kp)
	var kp_ok := q.index == 1
	var layer_ok := q.get_parent() is CanvasLayer
	await _wait(1.9)
	var urgent := q.is_urgent()
	q.press(KEY_A)
	await _wait(0.4)
	check("QTE：按键只有 1~4（%s），小键盘也认（%s），画在屏幕层（%s），剩不到 40%% 时变紧急（%s）" % [only_digits, kp_ok, layer_ok, urgent],
		only_digits and kp_ok and layer_ok and urgent)


# ------------------------------------------------------------------ 身上的小手 / 大量手提示
func _run_body_hands_and_alarm() -> void:
	print("-- 身上的小手 / 大量手提示")
	var dir := _dir()
	var blue := dir.blue
	_fresh(blue)
	dir.cover.clear()
	dir.cover_zone("thigh")
	dir.cover_zone("thigh")
	dir.cover_zone("waist")
	await _wait(0.2)
	var bh := BodyHands.of(blue)
	check("身上的小手：BodyHands 画的只数 = 身上的手（%d / %d），清手后跟着清（%s）" % [bh.total() if bh else -1, dir.cover.total(), "-"],
		bh != null and bh.total() == dir.cover.total())
	dir.cover.clear()
	await _wait(0.1)
	check("月光灯清手后身上的小手也没了（%d）" % bh.total(), bh.total() == 0)
	blue.global_position = _open_spot()
	var before := dir.alarm.count
	var made := dir.summon_near(3)
	await _wait(0.2)
	check("一次召出 %d 只紫手 → 大量手提示（%d → %d），屏幕中间黄字「%s」" % [made, before, dir.alarm.count, CenterHint.history.back() if not CenterHint.history.is_empty() else ""],
		made >= 3 and dir.alarm.count == before + 1 and CenterHint.history.has(HandAlarm.TEXT))
	for h in dir.hands():
		h.queue_free()


# ------------------------------------------------------------------ 憋笑键
func _run_hold_laugh() -> void:
	print("-- 憋笑键（空格）")
	var dir := _dir()
	var blue := dir.blue
	_fresh(blue)
	var hl := HoldLaugh.of(blue)
	blue.laugh.set_value(blue.laugh.giggle_threshold + 2.0)
	var r_before := dir.radius.radius()
	hl.force_hold = true
	await _wait(0.2)
	var muted := dir.radius.radius()
	var v0 := blue.laugh.value
	blue.laugh.add(10.0)
	var gain := blue.laugh.value - v0
	var slow := blue.stat_mul("speed")
	check("按住憋笑：笑声圈 %.0f → %.0f，闷笑只涨一半（+10 → +%.1f），走得慢（×%.2f）" % [r_before, muted, gain, slow],
		r_before > 0.0 and muted == 0.0 and absf(gain - 5.0) < 0.1 and absf(slow - 0.7) < 0.01 and hl.holding)
	# 自己松开：只放出一部分
	hl.held = 10.0
	var v1 := blue.laugh.value
	hl.force_hold = false
	await _wait(0.15)
	var soft := blue.laugh.value - v1
	check("自己松开：憋住的 10 只放出 %.1f（30%%），笑声圈恢复（%.0f）" % [soft, dir.radius.radius()],
		absf(soft - 3.0) < 0.3 and not hl.holding and dir.radius.radius() > 0.0)
	# 憋到底：噗——
	await _wait(3.5)
	_fresh(blue)
	hl.breath = 1.0
	hl.force_hold = true
	await get_tree().process_frame
	hl.held = 10.0
	hl.breath = 0.02
	var v2 := blue.laugh.value
	var bursts := {"n": 0}
	hl.released.connect(func(b: bool): if b: bursts["n"] += 1, CONNECT_ONE_SHOT)
	await _wait(0.3)
	var rooted := blue.status.is_rooted()
	check("憋到底：憋不住（%s），笑声圈爆到 %.0f，定住（%s），闷笑 +%.1f（憋住的 70%% + 10）" % [bursts["n"] == 1, dir.radius.radius(), rooted, blue.laugh.value - v2],
		bursts["n"] == 1 and dir.radius.radius() >= HoldLaugh.FAIL_RADIUS - 1.0 and rooted and blue.laugh.value - v2 >= 16.0)
	hl.force_hold = false
	await _wait(1.2)
	_fresh(blue)


# ------------------------------------------------------------------ 黑暗更怕痒
func _run_dark() -> void:
	print("-- 黑暗更怕痒")
	var dir := _dir()
	var blue := dir.blue
	_fresh(blue)
	var cl := dir.carry_light()
	var k0 := 1.0 + blue.stat_add("laugh_gain")
	cl.level = 0.2
	await _wait(0.3)
	var k1 := 1.0 + blue.stat_add("laugh_gain")
	check("冷光低于 30%%：状态 dark_sensitive（%s），挠痒 ×%.2f → ×%.2f，冷光圈缩小（%.2f），黄字提示（%s）" % [blue.has_buff("dark_sensitive"), k0, k1,
			cl.squeeze, CenterHint.history.has(DarkSense.HINT)],
		blue.has_buff("dark_sensitive") and absf(k1 - k0 - 0.2) < 0.01 and cl.squeeze < 1.0 and CenterHint.history.has(DarkSense.HINT))
	cl.level = 1.0
	await _wait(0.8)
	check("冷光亮回来：不再黑暗敏感（%s）" % blue.has_buff("dark_sensitive"), not blue.has_buff("dark_sensitive") and cl.squeeze == 1.0)


# ------------------------------------------------------------------ 刷轮 / 吊手 / 以前的束缚陷阱
func _run_traps() -> void:
	print("-- 墙缝刷轮 / 垂落吊手 / 倒吊绳套")
	var dir := _dir()
	var blue := dir.blue
	for cls in ["WallBrush", "HangingHands", "SnareTrap"]:
		_fresh(blue)
		var trap: Trap = null
		for n in main.level.find_children("*", "Trap", true, false):
			if n.get_script() and n.get_script().get_global_name() == cls:
				trap = n
				break
		if trap == null and cls == "SnareTrap":
			for n in main.level.find_children("*", "RestraintTrap", true, false):
				if str(n.get("reaction_key")) == "snare":
					trap = n
					break
		if trap == null:
			check("地图里有 %s" % cls, false)
			continue
		trap.active = true
		trap.set_meta("test_keep", true)
		var spot: Vector2 = trap.global_position
		if trap is WallBrush:
			spot = (trap as WallBrush)._hold_point()
			(trap as WallBrush)._rhythm_t = 0.05   # 正好伸出来
		blue.global_position = spot
		var t := 0.0
		while t < 2.5 and not blue.status.is_grabbed():
			await get_tree().process_frame
			t += get_process_delta_time()
			if trap is WallBrush and not blue.status.is_grabbed():
				blue.global_position = spot
		var grabbed := blue.status.is_grabbed()
		var v := blue.laugh.value
		await _wait(0.8)
		var tickled := blue.laugh.value > v
		var presses := 0
		while blue.status.is_grabbed() and presses < 30:
			blue.status.struggle()
			presses += 1
		await _wait(0.2)
		check("%s：经过时被困住（%s）、困着时在挠（%s）、连按挣脱（%d 下，%s）" % [cls, grabbed, tickled, presses, not blue.status.is_grabbed()],
			grabbed and tickled and not blue.status.is_grabbed())
		trap.active = false
		blue.global_position = _open_spot()
		await _wait(0.3)


# ------------------------------------------------------------------ 大手隔墙探照
func _run_shadow() -> void:
	print("-- 千手的影子：飘在空中，探照不被墙挡")
	var shadows: Array = main.level.find_children("*", "HandShadow", true, false)
	var hs: HandShadow = shadows[0] if not shadows.is_empty() else null
	var walls := main.level.get_node("Walls") as TileMapLayer
	var pair := []
	for c in walls.get_used_cells():
		if GridPath.walkable(main.level, c + Vector2i(-1, 0)) and GridPath.walkable(main.level, c + Vector2i(1, 0)):
			pair = [GridPath.center(c + Vector2i(-1, 0)), GridPath.center(c + Vector2i(1, 0))]
			break
	var ok := hs != null and not pair.is_empty() and hs.cone.ignore_walls
	var sees := 0.0
	var plain := -1.0
	if ok:
		var blue := _dir().blue
		hs.process_mode = Node.PROCESS_MODE_DISABLED
		hs.global_position = pair[0]
		hs.cone.facing = Vector2.RIGHT
		blue.global_position = pair[1]
		await _wait(0.1)
		sees = hs.cone.sees(blue)
		hs.cone.ignore_walls = false
		plain = hs.cone.sees(blue)
		hs.cone.ignore_walls = true
	var straight := hs != null and hs.route_points().size() >= 2 and _route_crosses_wall(hs.route_points(), walls)
	check("影子的视野隔着墙也看得到她（%.2f；地上的视野会被挡：%.2f），巡逻路线是横穿墙的直线（%s）" % [sees, plain, straight],
		ok and sees > 0.0 and plain == 0.0 and straight)


func _route_crosses_wall(pts: Array[Vector2], walls: TileMapLayer) -> bool:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		for k in 40:
			var p := a.lerp(b, k / 40.0)
			if walls.get_cell_source_id(GridPath.cell(p)) != -1:
				return true
	return false


# ------------------------------------------------------------------ 夜啼追手
func _run_stalker() -> void:
	print("-- 夜啼追手")
	var dir := _dir()
	var blue := dir.blue
	_fresh(blue)
	var list := get_tree().get_nodes_in_group("night_stalker")
	if list.is_empty():
		check("第二段有夜啼追手", false)
		return
	var ns: NightStalker = list[0]
	ns.set_meta("test_keep", true)
	ns.process_mode = Node.PROCESS_MODE_INHERIT
	var spot := _open_spot(90.0)
	blue.global_position = spot
	ns.global_position = spot + Vector2(0, 0)
	# 找一个离她 90 像素左右、走得到的格子放追手
	# 离她 100~130 像素、走得到、中间隔着墙（看不见）的格子放追手
	for c in dir._floor_cells:
		var p := GridPath.center(c)
		var d := p.distance_to(spot)
		if d > 100.0 and d < 130.0 and ns.global_position.distance_to(spot) < 1.0 and GridPath.find(main.level, p, spot, 2000).size() > 0:
			ns.global_position = p
	ns.state = "wander"
	await _wait(0.3)
	var calm := ns.state
	print("    · 追手离她 %.0f 像素" % ns.global_position.distance_to(spot))
	blue.laugh.set_value(blue.laugh.helpless_threshold + 5.0)
	await _wait(0.4)
	_finish()
	var heard := ns.state
	blue.laugh.set_value(0.0)
	# 憋笑 + 看不见 → 跟丢
	var hl := HoldLaugh.of(blue)
	hl.breath = 1.0
	hl.force_hold = true
	blue.global_position = spot
	for c in dir._floor_cells:
		var p := GridPath.center(c)
		if p.distance_to(spot) > 180.0 and p.distance_to(spot) < 260.0:
			ns.global_position = p
			break
	var t := 0.0
	while t < 3.5 and ns.state == "chase":
		_finish()
		await get_tree().process_frame
		t += get_process_delta_time()
	hl.force_hold = false
	var lost := ns.state
	check("听不到时游荡（%s），她笑出声 → 追（%s），憋笑又看不见 → 跟丢去搜（%s，%.1f 秒）" % [calm, heard, lost, t],
		calm == "wander" and heard == "chase" and lost == "search")
	# 抓到：小剧场 + 两只手 + 闷笑 +25，然后缩回黑暗
	await _wait(1.0)
	_fresh(blue)
	dir.cover.clear()
	var cg_seen := []
	var on_cg := func(id: String): cg_seen.append(id)
	CG.started.connect(on_cg)
	ns.state = "chase"
	ns.global_position = blue.global_position + Vector2(4, 0)
	await _advance_until(func(): return ns.state == "retreat" and not CG.is_busy(), 30.0)
	CG.started.disconnect(on_cg)
	check("抓到她：小剧场（%s），身上加 2 只手（%d），闷笑上涨（%.0f），追手缩回黑暗（%s）" % [cg_seen, dir.cover.total(), blue.laugh.value, ns.state],
		cg_seen.has("theater:f8_maze_stalker_1") and dir.cover.total() == 2 and blue.laugh.value >= 20.0 and ns.state == "retreat")
	dir.cover.clear()
	_fresh(blue)


# ------------------------------------------------------------------ 遮眼蝠
func _run_bat() -> void:
	print("-- 遮眼蝠")
	var dir := _dir()
	var blue := dir.blue
	_fresh(blue)
	var bats := get_tree().get_nodes_in_group("blind_bat")
	if bats.is_empty():
		check("第二段有遮眼蝠", false)
		return
	var bat: BlindBat = bats[0]
	bat.set_meta("test_keep", true)
	bat.process_mode = Node.PROCESS_MODE_INHERIT
	var cl := dir.carry_light()
	cl.level = 1.0
	await _wait(0.3)
	var asleep := bat.perched
	cl.level = 0.2
	blue.global_position = bat.global_position + Vector2(10, 0)
	var t := 0.0
	while t < 4.0 and not bat.is_stuck():
		await get_tree().process_frame
		t += get_process_delta_time()
		blue.global_position = bat.global_position + Vector2(6, 0) if not bat.is_stuck() else blue.global_position
	var blinded := blue.has_buff("blinded")
	await _wait(0.3)
	var squeeze := cl.squeeze
	blue.state = PlayableCharacter.State.DASH
	await get_tree().physics_frame
	await get_tree().physics_frame
	blue.state = PlayableCharacter.State.IDLE
	await _wait(0.1)
	check("冷光亮时倒挂睡觉（%s）；暗了扑到脸上蒙眼（%s，冷光圈 ×%.2f）；冲刺一次甩掉（%s）" % [asleep, blinded, squeeze, not bat.is_stuck()],
		asleep and blinded and squeeze < 0.6 and not bat.is_stuck() and not blue.has_buff("blinded"))
	cl.level = 1.0
	bat.process_mode = Node.PROCESS_MODE_DISABLED


# ------------------------------------------------------------------ 固定追逐（第三段）
func _run_scripted_chase() -> void:
	print("-- 固定追逐（第三段）")
	var dir := _dir()
	var blue := dir.blue
	_fresh(blue)
	var zones: Array = main.level.find_children("*", "StalkerZone", true, false)
	if zones.is_empty():
		check("第三段有固定追逐的触发区", false)
		return
	var z: StalkerZone = zones[0]
	GameState.set_flag(z.flag(), false)
	blue.global_position = z.global_position
	await _wait(0.4)
	var ns: NightStalker = null
	for n in get_tree().get_nodes_in_group("night_stalker"):
		if (n as NightStalker)._scripted:
			ns = n
	if ns:
		ns.set_meta("test_keep", true)
		ns.process_mode = Node.PROCESS_MODE_INHERIT
	var started := ns != null and ns.state == "chase" and CenterHint.history.has("跑！去月光灯！")
	var behind := ns != null and ns.global_position.distance_to(z.spawn_point()) < 8.0
	# 跑进月光灯：追逐结束
	var lamp: MoonLamp = null
	for l in get_tree().get_nodes_in_group("moon_lamp"):
		if lamp == null or (l as Node2D).global_position.distance_to(blue.global_position) < lamp.global_position.distance_to(blue.global_position):
			lamp = l
	if lamp:
		blue.global_position = lamp.global_position
	await _wait(0.5)
	var ended := ns != null and ns.state == "retreat"
	check("走进触发区 → 追手从身后冒出来（%s）开追、黄字「跑！去月光灯！」（%s）→ 进月光灯就结束（%s）" % [behind, started, ended],
		started and behind and ended and GameState.has_flag(z.flag()))
	var glows := get_tree().get_nodes_in_group("exit_glow").size()
	check("第三段的出口有微光（%d）" % glows, glows >= 1)


# ------------------------------------------------------------------ 工具
func _advance_until(cond: Callable, max_time: float) -> float:
	var t := 0.0
	while not cond.call() and t < max_time:
		if Dialogue.runner.choice_menu.is_open():
			Dialogue.runner.choice_menu.choose(0)
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await get_tree().process_frame
		t += get_process_delta_time()
	return t


func check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["通过" if ok else "失败", label])
	if not ok:
		failures += 1


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

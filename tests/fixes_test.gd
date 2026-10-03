extends Node
## 这一批修复的测试：束缚类陷阱的挠痒反应台词、组合演出 / CG 排队不被吞、配套 / 联动机关自己触发、落笼影子可见、
## 失控时被位移陷阱带走、测试模式（跳关、CG 图鉴）、第五层无解房间连续触发三来源组合。
## 用法：Godot --headless --path . res://tests/fixes_test.tscn   （退出码 0 = 全部通过）

var main: Node
var level: Node
var player: Princess
var ctrl := ScriptedController.new()
var failures := 0
var home := Vector2.ZERO

const TRAP_SOURCES := ["stocks", "carpet", "hand", "snare", "cuffs", "clamp", "wardrobe", "legloop", "mud", "boots", "binding",
	"cage", "supine", "cushion", "prone", "pit", "spinwheel", "vest", "chute"]
const BANNED := ["放开", "放我", "站不起来", "被抓住了", "解开"]


class Src extends Node2D:
	var reaction_key := ""


func _ready() -> void:
	ComboTracker.play_scenes = false
	HUD.slow_motion = false
	Monster.random_specials = false
	MagicFatigue.accumulate = false
	DevConfig.override = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish_dialogue()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	for f in ["seen_laugh_recover", "hint_latch", "hint_restraint", "hint_cage", "hint_grabbed"]:
		GameState.set_flag(f)
	_refresh()
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector2(31 * 16 + 8, 23 * 16 + 12)
	home = player.global_position
	await _run_lines()
	await _run_cg_queue()
	await _run_standalone()
	await _run_reach()
	await _run_helpless_move()
	await _run_dev_mode()
	await _run_trap_room()
	_run_burst_acts()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 台词
func _run_lines() -> void:
	print("-- 束缚类陷阱的挠痒反应台词")
	var ok := true
	var bad := []
	for k in TRAP_SOURCES:
		for st in ["grabbed", "calm", "giggle", "helpless_1", "helpless_2"]:
			var lines: Array = ReactionDB.source(k).get(st, [])
			if lines.size() < 3:
				ok = false
				bad.append("%s.%s" % [k, st])
			for l in lines:
				if BANNED.any(func(b): return str(l).contains(b)):
					ok = false
					bad.append(str(l))
	check("19 种束缚类来源每个阶段至少 3 句挠痒反应，没有只陈述处境的句子 %s" % [bad.slice(0, 4)], ok)
	check("落穴洞按洞里的怪物换台词", ReactionDB.lines("pit", "calm", "squirrel") != ReactionDB.lines("pit", "calm")
		and ReactionDB.lines("pit", "calm", "squirrel").any(func(l): return str(l).contains("尾巴")))
	# 实际被困：说的是那个洞里怪物的台词
	_reset()
	var said: Array = []
	var on_said := func(t: String, _d: float): if t != "": said.append(t)
	GameState.princess_reacted.connect(on_said)
	var pit: PitTrap = _trap("pit", Vector2(32, 0), {"content": "squirrel"})
	await _step_on(pit)
	await _wait(2.4)
	GameState.princess_reacted.disconnect(on_said)
	var pool: Array = []
	for st in ["grabbed", "calm", "giggle", "helpless_1", "helpless_2"]:
		pool.append_array(ReactionDB.lines("pit", st, "squirrel"))
	check("被困在落穴洞里：说的是被挠的反应（%s）" % [said.slice(0, 2)], not said.is_empty() and said.all(func(t): return pool.has(t)))
	await _struggle(pit.presses)
	pit.queue_free()
	_reset()


# ------------------------------------------------------------------ CG 排队
func _run_cg_queue() -> void:
	print("-- 组合演出 / CG 排队")
	var started: Array = []
	var on_start := func(id: String): started.append(id)
	CG.started.connect(on_start)
	for id in ["supine_navel", "prone_full", "frog_squirrel"]:
		GameState.flags.erase("combo_scene_" + id)
		CG.play_scene(id)
	await get_tree().process_frame
	check("同时触发 3 个组合演出：1 段在播、2 段排队", CG.is_playing() and CG.queued().size() == 2)
	CG.play_scene("prone_full")
	check("同一段不会重复排队", CG.queued().size() == 2)
	GameState.set_flag("cg_seen_death_rat")
	CG.play_death("rat")
	check("播演出时倒下：笑倒 CG 插到队首", CG.queued().size() == 3 and CG.queued()[0] == "death_rat")
	await _drain()
	CG.started.disconnect(on_start)
	check("全部依次播完、一段都没被吞（%s）" % [started], started == ["combo:supine_navel", "death_rat", "combo:prone_full", "combo:frog_squirrel"]
		and not CG.is_busy())
	check("组合演出真正播过才记已播标记", GameState.has_flag("combo_scene_frog_squirrel") and GameState.has_flag("cg_seen_combo:frog_squirrel"))
	await _wait(0.5)
	_reset()


## 一段一段跳过，直到队列播完。
func _drain() -> void:
	var guard := 0
	while CG.is_busy() and guard < 600:
		if CG.is_playing() and CG.step_index >= 0:
			CG.skip()
		await _wait(0.05)
		guard += 1


# ------------------------------------------------------------------ 配套 / 联动机关自己触发
func _run_standalone() -> void:
	print("-- 配套 / 联动机关自己触发")
	for spec in [["wheel", Vector2(32, 0), {}, Vector2.ZERO, "痒痒转轮：站上去自己转着挠"],
			["teaser", Vector2(32, 0), {}, Vector2(-14, 0), "羽毛逗弄器：走到旁边自己伸出来戳"],
			["shower", Vector2(32, 0), {"group_name": "fx_s1"}, Vector2.ZERO, "羽毛雨喷口（编在组里）：走到正下方自己下雨"],
			["cage", Vector2(32, 0), {"group_name": "fx_c1"}, Vector2.ZERO, "落笼（编在组里）：走到落点自己落下"]]:
		_reset()
		player.global_position = home
		await _wait(0.1)
		var t: Trap = _trap(spec[0], spec[1], spec[2])
		var hit := [false]
		var on_hit := func(h: HitData): if h.source == t: hit[0] = true
		player.tickled.connect(on_hit)
		player.global_position = t.global_position + spec[3]
		var waited := await _until(func(): return hit[0], 2.5)
		player.tickled.disconnect(on_hit)
		check("%s（%.1f 秒）" % [spec[4], waited], hit[0])
		if player.status.is_grabbed():
			await _struggle(10)
		t.queue_free()
	# 机关手：走到下方那一格
	_reset()
	player.global_position = home
	await _wait(0.1)
	var hand: GrabHand = load("res://scenes/traps/grab_hand.tscn").instantiate()
	hand.group_name = "fx_h1"
	level.get_node("Entities").add_child(hand)
	hand.global_position = home + Vector2(32, -16)
	player.global_position = hand.global_position + Vector2(0, 14)
	var w := await _until(func(): return player.status.is_grabbed_by(hand), 2.5)
	check("机关手（压力板那组）：走到下方那一格自己抓（%.1f 秒）" % w, player.status.is_grabbed_by(hand))
	await _struggle(hand.grab_presses)
	hand.queue_free()
	# 落笼影子
	_reset()
	player.global_position = home
	var cage: CageTrap = _trap("cage", Vector2(60, 0), {"idle_time": 5.0})
	await _wait(0.2)
	check("不对准的落笼平时地上就有影子（画在地板上面）", cage.shadow_visible())
	cage.queue_free()
	_reset()
	await _wait(0.2)


# ------------------------------------------------------------------ 束缚陷阱多一格范围、把人拉过去
func _held_by(t: Node) -> bool:
	return player.status.is_grabbed_by(t) or player.status.is_hobbled_by(t)


func _run_reach() -> void:
	print("-- 束缚陷阱：多一格触发范围，把人拉过去")
	for spec in [["pit", "落穴洞"], ["boots", "长靴"], ["cushion", "痒痒坐垫"], ["snare", "倒吊绳套"], ["stocks", "足枷台"], ["binding", "绑腿"]]:
		_reset()
		player.global_position = home
		await _wait(0.1)
		var t: Trap = _trap(spec[0], Vector2(48, 0))
		await _wait(0.05)
		player.global_position = t.global_position + Vector2(-16, 0)   # 相邻一格
		var waited := await _until(func(): return _held_by(t), 1.5)
		var caught := _held_by(t)
		await _wait(0.35)
		var target: Vector2 = t.call("_pull_target") if t.has_method("_pull_target") else t.global_position + Vector2(0, 4)
		check("%s：站在相邻一格被拉过去扣住（%.2f 秒，离陷阱 %.0f 像素）" % [spec[1], waited, player.global_position.distance_to(target)],
			caught and player.global_position.distance_to(target) < 6.0)
		if player.status.is_grabbed():
			await _struggle(12)
		if player.status.is_hobbled():
			player.status.release_hobble(false)
		t.queue_free()
		await _wait(0.1)
	# 隔两格不会触发
	_reset()
	player.global_position = home
	var far: Trap = _trap("pit", Vector2(48, 0))
	await _wait(0.05)
	player.global_position = far.global_position + Vector2(-34, 0)
	await _wait(0.5)
	check("隔两格不会被拉", not _held_by(far))
	far.queue_free()
	# 隔着墙不会被拉：找一块左右都是地面的墙
	var walls: TileMapLayer = level.get_node("Walls")
	var floor_layer: TileMapLayer = level.get_node("Floor")
	var spot := Vector2i(-1, -1)
	for c in walls.get_used_cells():
		var l := c + Vector2i.LEFT
		var r := c + Vector2i.RIGHT
		if floor_layer.get_cell_source_id(l) != -1 and walls.get_cell_source_id(l) == -1 \
				and floor_layer.get_cell_source_id(r) != -1 and walls.get_cell_source_id(r) == -1 \
				and walls.get_cell_source_id(c + Vector2i.UP) != -1 and walls.get_cell_source_id(c + Vector2i.DOWN) != -1:
			spot = c
			break
	if spot != Vector2i(-1, -1):
		_reset()
		var wt: Trap = load("res://scenes/traps/pit.tscn").instantiate()
		level.get_node("Entities").add_child(wt)
		wt.global_position = walls.to_global(walls.map_to_local(spot + Vector2i.RIGHT)) + Vector2(0, 4)
		player.global_position = walls.to_global(walls.map_to_local(spot + Vector2i.LEFT)) + Vector2(0, 4)
		await _wait(0.5)
		check("隔着墙不会被拉过去", not _held_by(wt))
		wt.queue_free()
	else:
		check("找到测试用的薄墙", false)
	_reset()
	player.global_position = home
	await _wait(0.3)


# ------------------------------------------------------------------ 失控时被位移陷阱带走
func _run_helpless_move() -> void:
	print("-- 失控时被位移陷阱带走")
	for spec in [["bounce_pad", {"dir": "right", "length": 3}, "弹弹床"], ["chute", {"tiles_w": 4, "dir": "right"}, "痒痒滑梯"]]:
		_reset()
		player.global_position = home
		await _wait(0.1)
		var t: Trap = _trap(spec[0], Vector2(16, 0), spec[1])
		_make_helpless()
		await get_tree().physics_frame
		var x0 := player.global_position.x
		player.global_position = t.global_position
		await _wait(0.9)
		check("笑到失控时踩上%s也会被带走（%s，移动 %.0f 像素）" % [spec[2], "失控中" if player.is_helpless() else "已恢复", player.global_position.x - t.global_position.x],
			player.global_position.x > t.global_position.x + 30.0)
		t.queue_free()
	# 失控时肥皂地板：被传送带推上去也会滑
	_reset()
	player.global_position = home
	await _wait(0.1)
	var soap: SoapFloor = _trap("soap_floor", Vector2(16, 0), {"tiles_w": 5, "tiles_h": 1})
	_make_helpless()
	player.global_position = soap.global_position + Vector2(-2, 0)
	for i in 10:
		player.add_push(Vector2(80, 0))
		await get_tree().physics_frame
	await _wait(0.6)
	check("笑到失控时被推上肥皂地板也会滑走", player.global_position.x > soap.global_position.x + 40.0)
	soap.queue_free()
	_reset()
	await _wait(0.2)


func _make_helpless() -> void:
	player.laugh.set_value(player.laugh.helpless_threshold + 5.0)
	player._set_state(PlayableCharacter.State.HELPLESS)


# ------------------------------------------------------------------ 测试模式
func _run_dev_mode() -> void:
	print("-- 测试模式（dev_config.json）")
	var sub_dir := str(DevConfig.data().get("dev_data_dir", ""))
	check("调试数据隔离：dev_data_dir = \"%s\"，编辑器里运行存档在 %s，导出的正式游戏在 %s" % [sub_dir, DevConfig.root_for(true) + "saves/", DevConfig.root_for(false) + "saves/"],
		sub_dir != "" and DevConfig.root_for(true) == "user://%s/" % sub_dir and DevConfig.root_for(false) == "user://"
		and SaveSystem.default_dir() == DevConfig.root_for(true) + "saves/" and DevConfig.is_dev_run())
	var src := "user://test_copy_from/"
	var dst := "user://test_copy_to/"
	for d in [src, dst]:
		if DirAccess.dir_exists_absolute(d):
			for f in DirAccess.get_files_at(d):
				DirAccess.remove_absolute(d + f)
			DirAccess.remove_absolute(d)
	DirAccess.make_dir_recursive_absolute(src)
	FileAccess.open(src + "slot_1.json", FileAccess.WRITE).store_string("{}")
	var copied := SaveSystem.copy_old_saves(src, dst)
	var again := SaveSystem.copy_old_saves(src, dst)
	check("第一次隔离时把以前的存档复制一份到调试目录（只复制一次，原来的不删）", copied == 1 and again == 0
		and FileAccess.file_exists(dst + "slot_1.json") and FileAccess.file_exists(src + "slot_1.json"))
	for d in [src, dst]:
		for f in DirAccess.get_files_at(d):
			DirAccess.remove_absolute(d + f)
		DirAccess.remove_absolute(d)
	check("配置文件读得到：有 dev_mode 开关、跳关点和各层奖励", FileAccess.file_exists(DevConfig.PATH) and DevConfig.skip_points().size() >= 6
		and DevConfig.data().has("dev_mode") and DevConfig.data().has("floor_rewards"))
	var pm: Node = main.get_node("PauseMenu")
	pm.toggle()
	check("测试模式关闭：暂停菜单没有「测试：跳关」", not pm.skip_button.visible)
	pm.toggle()
	var bp: Backpack = main.get_node("Backpack")
	GameState.flags.erase("cg_seen_death_slime")
	var slime_entry: Dictionary = Backpack.gallery_entries().filter(func(e): return e["id"] == "death_slime")[0]
	check("CG 图鉴：平时只能看看过的", not Backpack.gallery_unlocked(slime_entry)
		and Backpack.gallery_unlocked(Backpack.gallery_entries().filter(func(e): return e["id"] == "death_rat")[0]))
	DevConfig.override = true
	pm.toggle()
	check("测试模式打开：暂停菜单有「测试：跳关」", pm.skip_button.visible)
	pm.show_skip_list()
	check("跳关列表列出所有跳关点", pm.skip_box.get_child_count() == DevConfig.skip_points().size() + 1)
	pm.hide_skip_list()
	pm.toggle()
	check("CG 图鉴：测试模式下全部可看", Backpack.gallery_unlocked(slime_entry))
	# 图鉴播放
	GameState.flags.erase(GameState.BACKPACK_FLAG)
	bp.open()
	check("测试模式下没拿到背包也能打开", bp.is_open())
	bp.set_page(Backpack.PAGE_GALLERY)
	bp.gallery_selected = bp._gallery.find(slime_entry)
	var played := bp.play_selected()
	await get_tree().process_frame
	check("图鉴里选中按 E：关掉背包、播放 CG", played and not bp.is_open() and CG.is_playing() and CG.current == "death_slime")
	GameState.set_flag("cg_seen_death_slime")
	CG._can_skip = true
	await _drain()
	check("播完回到游戏", not CG.is_busy() and not GameState.in_dialogue and not get_tree().paused)
	# 跳关：第四层
	var points := DevConfig.skip_points()
	GameState.flags.erase("magic_unlocked")
	await DevConfig.skip_to(points[3])
	await _wait(0.6)
	_refresh()
	check("跳到第四层：补上第三层的魔法", main.level.scene_file_path == Floors.scene("floor_04") and GameState.has_flag("magic_unlocked")
		and not GameState.has_backpack())
	# 跳关：第五层准备间
	await DevConfig.skip_to(points[5])
	await _wait(0.6)
	_finish_cutscene()
	_refresh()
	check("跳到第五层准备间：背包、星光糖、挣脱强化都补上，站在准备间", main.level.scene_file_path == Floors.scene("floor_05")
		and GameState.has_backpack() and GameState.inventory.count("star_candy") >= 1 and GameState.passive_level("struggle_plus") >= 1
		and player.global_position.distance_to(Vector2(16 * 16 + 8, 9 * 16 + 12)) < 4.0)
	DevConfig.override = false


# ------------------------------------------------------------------ 无解房间：连续触发三来源组合
func _run_trap_room() -> void:
	print("-- 第五层无解房间")
	_refresh()
	TickleZones.enabled = true
	player.health.max_hp = 999
	player.health.fill()
	var fired := {}
	var on_fired := func(id: String): if ComboTracker.is_triple(ComboTracker.combo_def(id)): fired[id] = true
	player.combo.triggered.connect(on_fired)
	player.global_position = Vector2(11 * 16 + 8, 7 * 16 + 12)
	var t := 0.0
	while t < 60.0 and fired.size() < 4:
		await _wait(0.5)
		t += 0.5
		_finish_dialogue()
		player.health.fill()
		if player.global_position.x > 12 * 16:
			player.global_position = Vector2(11 * 16 + 8, 7 * 16 + 12)  # 倒下后在门外复活：送回房间
		if player.status.is_grabbed() or player.is_helpless() or player.status.is_hobbled():
			await _struggle(3)  # 像玩家一样挣扎
		elif player.is_alive() and player.can_act():
			ctrl.move = Vector2.from_angle(randf() * TAU)
	ctrl.move = Vector2.ZERO
	player.combo.triggered.disconnect(on_fired)
	check("一进无解房间就连续触发三来源组合（%.0f 秒内 %d 种：%s）" % [t, fired.size(), fired.keys()], fired.size() >= 4)


# ------------------------------------------------------------------ CG 最后一幕：魔力爆发后继续被挠
func _run_burst_acts() -> void:
	print("-- CG / 组合演出的最后一幕：魔力爆发")
	var all := {}
	for id in CG.cgs():
		all[id] = CG.cgs()[id]
	for id in CG.scenes:
		all["combo:" + id] = CG.scenes[id]
	var bad: Array = []
	for id in all:
		var steps: Array = all[id]["steps"]
		var burst := steps.filter(func(st): return st.get("act", "") == "burst")
		var said := burst.filter(func(st): return st.get("speaker", "") == "公主").map(func(st): return str(st["text"]))
		var has_portrait := burst.any(func(st): return st.get("portrait", "") == "fatigue_burst")
		var has_sound := burst.any(func(st): return st.get("actions", []).any(func(a): return a.get("sound", "") == "water_release"))
		var last_burst := -1
		var first_burst := steps.size()
		for i in steps.size():
			if steps[i].get("act", "") == "burst":
				last_burst = i
				first_burst = mini(first_burst, i)
		var at_end := last_burst >= 0 and steps.slice(last_burst + 1).all(func(st): return not st.has("text") or st.get("portrait", "") == "wake")
		if burst.size() < 7 or not has_portrait or not has_sound or not at_end \
				or not said.any(func(t): return t.contains("舒服")) or not said.any(func(t): return t.contains("敏感")):
			bad.append(id)
	check("全部 %d 段 CG / 组合演出最后都有魔力爆发这一幕（战损释放立绘、释放水声、有「舒服」和「敏感」两句）%s" % [all.size(), bad.slice(0, 4)],
		bad.is_empty() and all.size() == 85)
	# 最后一句是笑到快昏过去时的话，不再是「……X、X……哈哈……」的固定格式
	var stutter := RegEx.create_from_string("^……(.)、\\1")
	var old_fmt: Array = []
	for id in all:
		var said: Array = (all[id]["steps"] as Array).filter(func(st): return st.get("act", "") == "burst" and st.get("speaker", "") == "公主")
		if not said.is_empty() and stutter.search(str(said[-1]["text"])) != null:
			old_fmt.append(id)
	check("爆发一幕的最后一句是笑迷糊时的话（不是「……X、X……哈哈……」）%s" % [old_fmt.slice(0, 4)], old_fmt.is_empty())
	var portrait_ok: bool = CG.data["portraits"].has("fatigue_burst") and str(CG.data["portraits"]["fatigue_burst"]["placeholder"]) == "damaged_burst"
	check("这一幕的立绘是战损魔力释放", portrait_ok)
	check("魔力释放的水声文件存在", ResourceLoader.exists("res://assets/generated/sfx/water_release.wav"))


# ------------------------------------------------------------------ 工具
func _trap(file: String, offset: Vector2, props := {}) -> Node2D:
	var t: Node2D = load("res://scenes/traps/%s.tscn" % file).instantiate()
	for k in props:
		t.set(k, props[k])
	level.get_node("Entities").add_child(t)
	t.global_position = player.global_position + offset
	return t


func _struggle(n: int) -> void:
	for i in n:
		ctrl.press(&"attack")
		await get_tree().physics_frame
		await get_tree().physics_frame


func _step_on(t: Node2D, offset := Vector2(0, 2)) -> void:
	player.global_position = t.global_position + offset
	await _wait(0.15)


func _until(cond: Callable, max_time: float) -> float:
	var t := 0.0
	while not cond.call() and t < max_time:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return t


func _reset() -> void:
	player.revive()
	player._set_state(PlayableCharacter.State.IDLE)
	player.combo.reset()
	player.clear_buffs(false)
	player.laugh.clear()
	player._full_invuln = 0.0
	player._attack_invuln = 0.0


func _refresh() -> void:
	level = main.level
	player = GameState.player as Princess
	if not is_instance_valid(ctrl) or player.controller != ctrl:
		ctrl = ScriptedController.new()  # 换层后旧的控制器跟着旧公主一起被释放了
		player.set_controller(ctrl)


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


func _finish_cutscene() -> void:
	var guard := 0
	while Cutscene.is_playing() and guard < 400:
		_finish_dialogue()
		await get_tree().process_frame
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

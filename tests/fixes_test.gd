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
	await _run_helpless_move()
	await _run_dev_mode()
	await _run_trap_room()
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
	check("配置文件读得到，默认关闭，有跳关点和各层奖励", FileAccess.file_exists(DevConfig.PATH) and DevConfig.skip_points().size() >= 6
		and not bool(DevConfig.data().get("dev_mode", true)))
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

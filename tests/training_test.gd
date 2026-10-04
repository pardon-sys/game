extends Node
## 保卫队训练营测试：训练数值（上限、部位均分、加成、套到公主身上）、训练菜单（费用 / 未解锁 / 练满）、
## Esc 测试列表滚动条；训练一~四的小游戏、新陷阱和新组合（后面几节）。
## 用法：Godot --headless --path . res://tests/training_test.tscn   （退出码 0 = 全部通过）

var main: Node
var player: Princess
var failures := 0
var home := Vector2.ZERO
var ctrl := ScriptedController.new()


class Src extends Node2D:
	var reaction_key := ""
	var tickle_zones := {}


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	HUD.slow_motion = false
	Monster.random_specials = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	player = GameState.player as Princess
	player.set_controller(ctrl)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	for f in ["seen_laugh_recover", "hint_latch", "hint_restraint", "hint_cage", "hint_grabbed", "hint_tickled"]:
		GameState.set_flag(f)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	home = Vector2(31 * 16 + 8, 23 * 16 + 12)
	player.global_position = home
	await _run_stats()
	await _run_menu()
	await _run_esc_list()
	await _run_scroll_box()
	await _run_traps()
	await _run_combos()
	await _run_endure()
	await _run_resist()
	await _run_sensitize()
	await _run_maze()
	await _run_dialogue_entry()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 数值
func _clear_training() -> void:
	for k in GameState.vars.keys():
		if str(k).begins_with("train_"):
			GameState.vars.erase(k)
	TrainingStats.apply(player)


func _run_stats() -> void:
	print("-- 训练数值")
	_clear_training()
	check("没练过：魔力疲倦 500、闷笑 150、生命 10、部位倍率不变", player.fatigue.max_value == 500.0 and player.laugh.max_value == 150.0
		and player.health.max_hp == 10 and is_equal_approx(TickleZones.zone_multiplier("sole"), 1.2))
	check("4 项训练，第一阶段开放、二三阶段未解锁", TrainingDB.list().size() == 4
		and TrainingDB.list().all(func(t): return t["stages"][0]["unlocked"] and not t["stages"][1]["unlocked"] and not t["stages"][2]["unlocked"]))
	check("一阶段上限：疲倦 +100 / -100、释放强度 50%、耐笑 0.1、强化 0.3", TrainingStats.cap("train_fatigue_up") == 100.0
		and TrainingStats.cap("train_fatigue_down") == 100.0 and TrainingStats.cap("train_burst_power") == 50.0
		and is_equal_approx(TrainingStats.cap("train_resist_sole"), 0.1) and is_equal_approx(TrainingStats.cap("train_sens_belly"), 0.3))
	var got := TrainingStats.add("train_fatigue_up", 130)
	check("加到上限为止（加 130 实际 +100）", got == 100.0 and TrainingStats.is_full("train_fatigue_up"))
	TrainingStats.add("train_fatigue_down", 30)
	TrainingStats.add("train_burst_power", 20)
	var n := TickleZones.zone_ids().size()
	TrainingStats.add("train_resist_sole", 0.1)     # 一个部位练满
	TrainingStats.add("train_sens_thigh", 0.15)     # 一个部位练一半
	var hp_before := player.health.hp
	TrainingStats.apply(player)
	check("魔力疲倦上限 = 500 + 100 - 30", player.fatigue.max_value == 570.0)
	var lb := 25.0 / n + 0.5 * 50.0 / n
	check("闷笑上限按部位均分（耐笑满 1 个 25/%d + 强化半个 50/%d×0.5 = %.2f）" % [n, n, lb], is_equal_approx(player.laugh.max_value, 150.0 + lb))
	check("生命上限按部位均分取整（%d 个部位时 +%d HP）" % [n, TrainingStats.hp_bonus()],
		player.health.max_hp == 10 + int(floor(2.0 / n + 0.5 * 4.0 / n + 1e-6)) and player.health.hp >= hp_before)
	check("近战强度 = 50%% / %d（只有耐笑训练加）" % n, is_equal_approx(TrainingStats.melee_bonus(), 0.5 / n))
	check("部位倍率：脚心 -0.1、大腿 +0.15", is_equal_approx(TickleZones.zone_multiplier("sole"), 1.1)
		and is_equal_approx(TickleZones.zone_multiplier("thigh"), 1.05))
	var total := 0
	for i in 2000:
		total += TrainingStats.melee_damage(2)
	check("近战伤害期望 = 基础 × (1 + 强度)（%.3f）" % (total / 2000.0), absf(total / 2000.0 - 2.0 * (1.0 + 0.5 / n)) < 0.05)
	check("疲倦释放强度倍率 1.2", is_equal_approx(TrainingStats.burst_mult(), 1.2))
	check("训练成果写进 GameState.vars（随存档保存）", GameState.vars.has("train_fatigue_up") and GameState.vars.has("train_resist_sole"))
	check("训练成果总览（背包用）有疲倦 / 释放 / 闷笑 / 生命 / 近战和练过的部位", TrainingStats.summary().size() >= 7)
	_clear_training()


# ------------------------------------------------------------------ 菜单
func _run_menu() -> void:
	print("-- 训练菜单")
	GameState.inventory.remove("coin", GameState.inventory.count("coin"))
	var t := TrainingDB.info("fatigue_endure")
	check("金币不够不能开始", TrainingMenu.blocked_reason(t).contains("金币"))
	GameState.give_item(ItemDB.get_item("coin"), 20)
	check("有金币就能开始（每轮 %d 金币）" % TrainingMenu.cost(), TrainingMenu.blocked_reason(t) == "" and TrainingMenu.cost() == 5)
	TrainingStats.add("train_fatigue_up", 100)
	check("这一阶段练满就不能再练", TrainingMenu.blocked_reason(t).contains("练满"))
	_clear_training()
	var menu := TrainingMenu.new()
	get_tree().root.add_child(menu)
	var result := [null]
	var run := func(): result[0] = await menu.choose()
	run.call()
	await _wait(0.1)
	check("训练菜单列出 4 项训练并暂停游戏", menu.rows.get_child_count() == 4 and get_tree().paused)
	menu.pick(2)
	await _wait(0.05)
	check("部位类训练（耐笑）先选部位", menu.page == "zone" and menu.rows.get_child_count() == TickleZones.zone_ids().size())
	menu.cancel()
	await _wait(0.05)
	check("Esc 从选部位回到训练列表", menu.page == "list")
	var sm := TrainingDB.summary_text(TrainingDB.info("fatigue_release"), {"successes": 3, "gained": {"train_fatigue_down": 5.0, "train_burst_power": 2.5}})
	var sz := TrainingDB.summary_text(TrainingDB.info("zone_resist"), {"successes": 2, "gained": {"train_resist_sole": 0.002}})
	check("结算提示用玩家看得懂的说法（%s／%s）" % [sm, sz], sm.contains("魔力疲倦上限 -5") and sm.contains("释放强度 +2.5%")
		and sz.contains("脚心倍率 -0.002") and not (sm + sz).contains("train_"))
	menu.pick(3)
	menu.pick(1)
	await _wait(0.05)
	check("选好部位返回 {id, zone}", result[0] is Dictionary and result[0].get("id") == "zone_sensitize"
		and result[0].get("zone") == str(TickleZones.zone_ids()[1]) and not get_tree().paused)
	menu.queue_free()


# ------------------------------------------------------------------ Esc 测试列表
func _run_esc_list() -> void:
	print("-- Esc 测试列表")
	DevConfig.override = true
	var pm: Node = null
	for n in main.find_children("*", "CanvasLayer", true, false):
		if n.has_method("show_skip_list"):
			pm = n
	pm.toggle()
	pm.show_skip_list()
	await _wait(0.2)
	var sc: ScrollContainer = pm.skip_scroll
	check("跳关列表放在滚动容器里（高度固定，内容比它高时能滚）", sc.visible and pm.skip_box.get_parent() == sc
		and sc.size.y <= pm.SKIP_HEIGHT + 1.0 and pm.skip_box.get_child_count() == DevConfig.skip_points().size() + 1)
	var last: Button = pm.skip_box.get_child(pm.skip_box.get_child_count() - 1)
	last.grab_focus()
	await _wait(0.2)
	check("焦点移到最后一项时自动滚下去", pm.skip_box.size.y <= sc.size.y or sc.scroll_vertical > 0)
	pm.hide_skip_list()
	pm.toggle()
	DevConfig.override = false
	await _wait(0.1)


# ------------------------------------------------------------------ 滚动文字面板
func _run_scroll_box() -> void:
	print("-- 滚动文字面板（ScrollTextBox）")
	var box := ScrollTextBox.make(Rect2(0, 0, 120, 40))
	get_tree().root.add_child(box)
	var l := box.add_line("很长的一段说明文字，".repeat(12))
	await get_tree().process_frame
	await get_tree().process_frame
	check("长文字自动换行、不超出面板宽度，比面板高时可以滚动", l.size.x <= box.size.x and l.size.y > 30.0 and box.is_scrollable())
	box.scroll_by(1)
	await get_tree().process_frame
	check("scroll_by 一次滚一行", box.scroll_vertical > 0)
	box.queue_free()
	# 训练菜单：说明在提示行上面，最长的说明也不重叠
	GameState.give_item(ItemDB.get_item("coin"), 10)
	var menu := TrainingMenu.new()
	get_tree().root.add_child(menu)
	menu.choose()
	await _wait(0.05)
	var longest := 0
	for i in TrainingDB.list().size():
		if str(TrainingDB.list()[i]["desc"]).length() > str(TrainingDB.list()[longest]["desc"]).length():
			longest = i
	menu.selected = longest
	menu._refresh()
	await _wait(0.05)
	var db := menu.desc_box
	check("训练菜单：说明是滚动面板，在提示行上方、宽度不超框（最长的说明 %d 字）" % str(TrainingDB.list()[longest]["desc"]).length(),
		db.position.y + db.size.y <= menu.hint.position.y and menu.desc.size.x <= db.size.x
		and menu.list_box.position.y + menu.list_box.size.y <= db.position.y)
	var before := db.scroll_vertical
	var ev := InputEventAction.new()
	ev.action = "move_right"
	ev.pressed = true
	menu._input(ev)
	await _wait(0.05)
	check("←→ 翻看说明（内容超出时）", not db.is_scrollable() or db.scroll_vertical > before)
	menu.cancel()
	menu.queue_free()
	get_tree().paused = false
	# 背包状态页：长行自动换行
	TrainingStats.add("train_burst_power", 10)
	TrainingStats.add("train_resist_sole", 0.05)
	var bp: Backpack = main.get_node("Backpack")
	bp.open()
	bp.set_page(Backpack.PAGE_STATUS)
	await _wait(0.1)
	var sp := bp.status_page
	var labels := sp.find_children("*", "Label", true, false)
	check("背包状态页：滚动面板，每一行都不超出宽度（%d 行）" % labels.size(), sp is ScrollTextBox and not labels.is_empty()
		and labels.all(func(x): return x.size.x <= sp.size.x + 0.5 and x.get_global_rect().end.x <= sp.get_global_rect().end.x + 0.5))
	bp.close()
	_clear_training()


# ------------------------------------------------------------------ 新陷阱
const LEG_TRAPS := {
	"thigh_pincer": ["thigh"], "foot_thigh_rack": ["sole", "thigh"], "feather_swing": ["sole", "thigh"], "thigh_brush_ring": ["thigh"],
	"foot_bath": ["sole"], "sitz_bath": ["butt", "thigh"], "spring_seat": ["butt"], "saddle_bench": ["butt", "thigh"],
	"scissor_stand": ["thigh", "butt"],
}


func _reset() -> void:
	_finish()   # 关卡开场的对话会晚几秒才出来：先推掉，不然 in_dialogue 会让陷阱停住
	player.revive()
	player._set_state(PlayableCharacter.State.IDLE)
	player.combo.reset()
	player.clear_buffs(false)
	player.laugh.clear()
	if player.fatigue:
		player.fatigue.clear()
	player._full_invuln = 0.0
	player._attack_invuln = 0.0
	player.global_position = home


func _trap(file: String, offset: Vector2) -> LegTrap:
	var t: LegTrap = load("res://scenes/traps/%s.tscn" % file).instantiate()
	main.level.get_node("Entities").add_child(t)
	t.global_position = home + offset
	return t


func _run_traps() -> void:
	print("-- 训练营的新陷阱（脚 / 大腿 / 屁股）")
	const FX_OF := {"thigh_pincer": "TrapSnap", "scissor_stand": "TrapSnap", "spring_seat": "TrapBoing", "thigh_brush_ring": "BristleRing",
		"feather_swing": "TrapArc", "foot_thigh_rack": "TrapStroke", "saddle_bench": "TrapStroke"}
	var fx_seen: Array = []
	var on_child := func(n: Node): fx_seen.append(str(n.name))
	main.level.get_node("Entities").child_entered_tree.connect(on_child)
	for key in LEG_TRAPS:
		_reset()
		await _wait(0.1)
		fx_seen.clear()
		var t := _trap(key, Vector2(48, 0))
		await _wait(0.05)
		var zones_hit := {}
		var on_tickle := func(h: HitData): if h.source == t: zones_hit[h.zone] = true
		player.tickled.connect(on_tickle)
		if t.rhythm_on > 0.0:
			t._rhythm_t = t.rhythm_on + 0.05   # 合上的那半拍
			player.global_position = t.call("_pull_target")
			await _wait(0.15)
			check("%s：合上的那半拍不抓人" % ReactionDB.source(key)["name"], not player.status.is_grabbed_by(t))
			t._rhythm_t = 0.0
		player.global_position = t.call("_pull_target")
		var w := await _until(func(): return player.status.is_grabbed_by(t), 2.0)
		var held := player.status.is_grabbed_by(t)
		var exposed := player.sensitivity.exposed()
		check("%s：困住（%.2f 秒），露出 %s" % [ReactionDB.source(key)["name"], w, LEG_TRAPS[key]], held
			and LEG_TRAPS[key].all(func(z): return exposed.has(z)))
		var i0 := t.self_interval
		var p0 := player.status.presses_left()
		var g0 := player.status.grab_time_left()
		if t.struggle_speedup > 0.0 or t.struggle_extend > 0.0:
			for i in 2:
				ctrl.press(&"attack")
				await get_tree().physics_frame
				await get_tree().physics_frame
			await _wait(0.05)
			check("%s：挣扎 2 下后挠得更快%s" % [ReactionDB.source(key)["name"], "、多困一会儿" if t.struggle_extend > 0.0 else ""],
				t.struggles >= 1 and t.self_interval < i0 and (t.struggle_extend <= 0.0 or player.status.grab_time_left() > g0 - 0.3))
		await _wait(2.2)
		check("%s：自己挠的部位 %s（这一轮挠到 %s）" % [ReactionDB.source(key)["name"], LEG_TRAPS[key], zones_hit.keys()],
			not zones_hit.is_empty() and zones_hit.keys().all(func(z): return LEG_TRAPS[key].has(z))
			and (t.zone_cycle.size() < 2 or zones_hit.size() >= 2))
		if key == "thigh_brush_ring":
			check("大腿刷环：困得越久转得越快", t.self_interval < i0 - 0.05)
		if key == "feather_swing":
			check("羽毛秋千：把人吊起来（双脚离地）", player.pose_offset.y < -2.0)
		if key in ["foot_bath", "sitz_bath"]:
			check("%s：困住时冒泡泡" % ReactionDB.source(key)["name"], t._bubble_fx != null and t._bubble_fx.emitting)
		if FX_OF.has(key):
			check("%s：困住时有专属特效（%s）" % [ReactionDB.source(key)["name"], FX_OF[key]],
				fx_seen.any(func(nm): return str(nm).begins_with(FX_OF[key])))
		player.tickled.disconnect(on_tickle)
		if player.status.is_grabbed():
			player.status.release(true)
		t.queue_free()
		await _wait(0.1)
	main.level.get_node("Entities").child_entered_tree.disconnect(on_child)
	# 训练营：锁定部位
	var rack := _trap("foot_thigh_rack", Vector2(48, 0))
	rack.lock_zone("sole")
	check("lock_zone：训练时只挠选定的部位", rack.tickle_zones.keys() == ["sole"] and rack.current_zone() == "sole")
	rack.queue_free()
	_reset()


func _run_combos() -> void:
	print("-- 新的三来源组合（训练二的迷宫）")
	var fired: Array = []
	var on_fired := func(id: String): fired.append(id)
	player.combo.triggered.connect(on_fired)
	var specs := [["boots_clamp_crawl", ["boots", "clamp", "caterpillar"]], ["legloop_lick", ["legloop", "frog", "rat"]],
		["foot_thigh_lock", ["stocks", "clamp", "squirrel"]], ["pincer_stocks", ["thigh_pincer", "stocks", "hedgehog"]],
		["rack_crawl", ["foot_thigh_rack", "thigh_pincer", "caterpillar"]], ["swing_frenzy", ["feather_swing", "squirrel", "rat"]],
		["ring_binding", ["thigh_brush_ring", "binding", "fairy"]], ["foot_bubble", ["foot_bath", "bubble_fish", "slime"]],
		["bath_trio", ["sitz_bath", "bubble_fish", "fairy"]], ["spring_feather", ["spring_seat", "teaser", "rat"]],
		["saddle_brush", ["saddle_bench", "squirrel", "caterpillar"]], ["scissor_brush", ["scissor_stand", "cushion", "hedgehog"]]]
	for spec in specs:
		_reset()
		fired.clear()
		for k in spec[1]:
			var s := Src.new()
			s.reaction_key = k
			main.level.get_node("Entities").add_child(s)
			s.global_position = home + Vector2(20, 0)
			player.receive_hit(HitData.make_tickle(s, 1.0))
		check("「%s」：%s 一起挠就触发，有组合演出" % [ReactionDB.combo(spec[0]).get("name", spec[0]), "、".join(spec[1].map(func(k): return ReactionDB.source(k).get("name", k)))],
			fired.has(spec[0]) and CG.scenes.has(spec[0]))
		await _wait(0.1)
	player.combo.triggered.disconnect(on_fired)
	_reset()


# ------------------------------------------------------------------ 训练小游戏
## 开始一轮训练（不 await），推进开场过场直到小游戏开始；返回 [训练节点, 结果容器]。
func _start_training(id: String, zone := "") -> Array:
	_reset()
	_clear_training()
	GameState.give_item(ItemDB.get_item("coin"), 10)
	var out := [null, {}]
	var coins := GameState.inventory.count("coin")
	var go := func(): out[1] = await TrainingDB.run(id, zone)
	go.call()
	await _advance_until(func(): return TrainingDB.current != null and TrainingDB.current.playing, 30.0)
	out[0] = TrainingDB.current
	check("「%s」：扣 %d 金币，过场后进入小游戏" % [TrainingDB.info(id)["name"], TrainingMenu.cost()],
		out[0] != null and out[0].playing and GameState.inventory.count("coin") == coins - TrainingMenu.cost())
	if out[0]:
		out[0].time_scale = 0.0   # 测试里手动推进
	return out


## 每帧推进对话（过场 / 小剧场的台词），直到条件成立。
func _advance_until(cond: Callable, max_time: float) -> float:
	var t := 0.0
	while not cond.call() and t < max_time:
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await get_tree().process_frame
		t += get_process_delta_time()
	return t


## Esc 结束这一轮，推进结束过场；返回结果。
func _end_training(out: Array) -> Dictionary:
	var r: TrainingStage = out[0]
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	await _advance_until(func(): return not out[1].is_empty(), 20.0)
	return out[1]


func _punish_check(r: TrainingStage, kind: String, prefix: String) -> void:
	var seen := [""]
	var on_start := func(id: String): seen[0] = id
	CG.started.connect(on_start)
	var n0 := r.punish_count
	if kind == "fatigue":
		r.add_fatigue(player.fatigue.max_value)
	else:
		r.add_laugh(player.laugh.max_value)
	await _advance_until(func(): return r.punish_count > n0 and not r.busy, 30.0)
	CG.started.disconnect(on_start)
	check("%s满了 → 惩罚小剧场（%s）→ 清空后继续训练" % ["魔力疲倦" if kind == "fatigue" else "闷笑", seen[0]],
		str(seen[0]).begins_with("theater:" + prefix) and r.playing and not r.busy and GameState.in_dialogue
		and (player.fatigue.value == 0.0 if kind == "fatigue" else player.laugh.value == 0.0))


func _run_endure() -> void:
	print("-- 训练一：魔力疲倦忍耐（QTE）")
	var out := await _start_training("fatigue_endure")
	var r = out[0]
	if r == null:
		return
	check("地图上摆出足枷台、夹腿枷台、刑床、坐垫，公主被固定，两名卫兵就位",
		r.devices.size() == 4 and player.get("puppet_anim") == "grabbed" and Cutscene.spawned.has("train_g1") and Cutscene.spawned.has("train_g2"))
	check("小舞台：公主、两名卫兵、四种刑具", r.actors.has("princess") and r.actors.has("g1") and r.actors.has("g2")
		and ["stocks", "clamp", "supine", "cushion"].all(func(k): return r.actors.has(k)))
	r._call("ls")
	r.press("A")
	check("卫兵喊左脚心，按 A → 抵抗成功，魔力疲倦上限 +1（立刻记上）", r.successes == 1 and TrainingStats.value("train_fatigue_up") == 1.0)
	var f0: float = player.fatigue.value
	r._call("rt")
	r.press("A")
	check("喊右大腿却按 A → 失败，暴击，魔力疲倦大涨", r.fails == 1 and player.fatigue.value - f0 >= player.fatigue.max_value * 0.06
		and r.queue.is_empty())
	r._call("ls")
	r._call("rt")
	r._call("lt")
	check("连着喊三个：左边面板排成队列", r.queue.size() == 3 and r._rows.get_child_count() == 3)
	r.press("A")
	r.press("K")
	r.press("Q")
	check("按顺序按对（A、K、Q；大腿也能用 J / K）→ 三次都成功", r.successes == 4 and r.fails == 1)
	r._call("lt")
	r._call("rs")
	r.press("D")
	check("顺序不对（先按了第二个）→ 第一个算失败", r.fails == 2 and r.queue.size() == 1)
	r.queue.clear()
	r._call("rs")
	r._tick(2.0)
	check("超时没按 → 失败", r.fails == 3 and r.queue.is_empty())
	var slow: float = r.item_time()
	r.successes = 40
	check("成功越多：限时变短（%.2f → %.2f 秒）、卫兵喊得更快、一次最多喊 4 个" % [slow, r.item_time()],
		r.item_time() < slow and r.item_time() >= 0.35 and r.call_gap() < 0.45 and range(30).map(func(_i): return r.burst_len()).max() == 4)
	r.successes = 20
	check("提速倍率 ramp %.1f：20 次后的限时 %.2f 秒，比原来（%.2f 秒）更短" % [r.ramp(), r.item_time(), 1.2 * pow(0.975, 20)],
		r.ramp() > 1.0 and r.item_time() < 1.2 * pow(0.975, 20))
	r.successes = 4
	var f1: float = player.fatigue.value
	r._tick(1.0)
	check("刑具一直在挠：魔力疲倦缓慢上涨", player.fatigue.value > f1)
	r._render()
	var ids: Array = TrainingStats.stage(TrainingDB.info("fatigue_endure")).get("punish", [])
	var lens := ids.map(func(id): return (JSON.parse_string(FileAccess.get_file_as_string(CG.theater_index().get(id, ""))) as Dictionary).get("steps", []).filter(func(st): return st.has("text")).size() if CG.has_theater(id) else 0)
	check("训练一的惩罚小剧场 5 段、每段 ≥ 12 句台词（%s），台词里代入这一轮的成功次数" % [lens], ids.size() == 5
		and lens.all(func(n): return n >= 12) and r.theater_subs().get("successes") == r.successes)
	await _punish_check(r, "fatigue", "train_endure_punish_")
	var res := await _end_training(out)
	check("Esc 结束：结果 成功 %d 次、+%s；公主被放开，刑具和卫兵撤走" % [res.get("successes", 0), res.get("gained", {})],
		res.get("successes", 0) == 4 and is_equal_approx(float(res.get("gained", {}).get("train_fatigue_up", 0)), 4.0)
		and player.get("puppet_anim") == "" and main.level.find_children("TrainDevice*", "", true, false).is_empty() and not Cutscene.spawned.has("train_g1")
		and not GameState.in_dialogue and TrainingDB.current == null)
	check("训练结束后魔力疲倦上限 = 500 + 4", player.fatigue.max_value == 504.0)


func _run_resist() -> void:
	print("-- 训练三：耐笑部位（忍笑节奏条）")
	var out := await _start_training("zone_resist", "sole")
	var r = out[0]
	if r == null:
		return
	check("脚心：刑具从候选里挑（%s），舞台上一名卫兵" % r.device_key, TrainingDB.devices_for("sole").has(r.device_key)
		and r.actors.has("device") and r.actors["device"].reaction_key == r.device_key and r.actors.has("g1"))
	r._set_phase("windup", 5.0)
	r.fake = false
	r._set_phase("sweep", r.sweep_time())
	r.pointer = r.green_c
	r.press("J")
	check("指针在绿区按 J → 憋住，脚心耐笑 +0.001", r.successes == 1 and is_equal_approx(TrainingStats.value("train_resist_sole"), 0.001))
	var l0: float = player.laugh.value
	r._set_phase("windup", 5.0)
	r.press("SPACE")
	check("卫兵还在举工具就按 → 按早了，闷笑大涨", r.fails == 1 and player.laugh.value > l0 + player.laugh.max_value * 0.1)
	r._set_phase("windup", 5.0)
	r.fake = false
	r._set_phase("sweep", r.sweep_time())
	r.pointer = clampf(r.green_c + r.green_w, 0.0, 1.0) if r.green_c + r.green_w <= 1.0 else 0.0
	r.press("J")
	check("指针不在绿区 → 失败", r.fails == 2)
	r._set_phase("windup", 5.0)
	r.fake = true
	r._set_phase("sweep", r.sweep_time())
	r.pointer = r.green_c
	r.press("J")
	check("假动作（红区）按了 → 上当，失败", r.fails == 3)
	r._set_phase("windup", 5.0)
	r.fake = true
	r._set_phase("sweep", 0.1)
	r._tick(0.2)
	check("假动作忍住不按 → 看穿，不算失败", r.fails == 3 and r.feints_seen == 1)
	r._set_phase("windup", 5.0)
	r.fake = false
	r._set_phase("sweep", 0.1)
	r._tick(0.2)
	check("真的挠过来却没按 → 失败", r.fails == 4)
	var w0: float = r.zone_width()
	r.successes = 60
	check("越练绿区越窄（%.2f → %.2f）、扫得越快、假动作越多" % [w0, r.zone_width()], r.zone_width() < w0 and r.sweep_time() < 1.2 and r.fake_chance() > 0.1)
	r.successes = 20
	check("绿区和扫过速度同步提速：20 次后宽 %.3f（原来 %.3f）、扫过 %.2f 秒（原来 %.2f）" % [r.zone_width(), 0.3 * pow(0.985, 20), r.sweep_time(), 1.2 * pow(0.98, 20)],
		r.zone_width() < 0.3 * pow(0.985, 20) and r.sweep_time() < 1.2 * pow(0.98, 20))
	r.successes = 1
	var bad_json: Array = []
	for id in CG.theater_index():
		if JSON.parse_string(FileAccess.get_file_as_string(CG.theater_index()[id])) == null:
			bad_json.append(id)
	var zd := CG.theater_data("train_zone_punish_1", r.theater_subs())
	var dev_at: Array = zd.get("cast", {}).get("device", {}).get("at", [])
	check("小剧场文件都是合法 JSON（%s），部位训练的惩罚代入后刑具是本轮的、坐标是数字（%s）" % [bad_json, dev_at], bad_json.is_empty()
		and str(zd["cast"]["device"]["kind"]) == "trap:" + r.device_key and dev_at.size() == 2 and dev_at.all(func(v): return v is float or v is int))
	await _punish_check(r, "laugh", "train_zone_punish_")
	var res := await _end_training(out)
	check("Esc 结束：成功 1 次，脚心耐笑 0.001", res.get("successes", 0) == 1 and is_equal_approx(TrainingStats.value("train_resist_sole"), 0.001)
		and player.get("puppet_anim") == "")


func _run_sensitize() -> void:
	print("-- 训练四：敏感部位强化（反射克制）")
	var out := await _start_training("zone_sensitize", "thigh")
	var r = out[0]
	if r == null:
		return
	check("大腿：刑具从候选里挑（%s）" % r.device_key, TrainingDB.devices_for("thigh").has(r.device_key))
	var seg := func(dirs: Array):
		r.rest_t = 0.0
		r.current = {}
		r.pending.clear()
		for d in dirs:
			r.pending.append({"dir": d, "at": 0.0})
		r._seg_total = dirs.size()
		r._seg_done = 0
		r.seg_t = 0.0
		r._tick(0.01)
	seg.call(["LEFT"])
	check("冲动「想往左边躲」出现", not r.current.is_empty() and r._arrow.text == "←")
	r.press("RIGHT")
	r._tick(0.01)
	check("按反方向 → → 按住，这一段成功，大腿敏感 +0.003", r.successes == 1 and is_equal_approx(TrainingStats.value("train_sens_thigh"), 0.003))
	seg.call(["UP", "RIGHT", "DOWN"])
	r.press("S")
	r._tick(0.01)
	r.press("A")
	r._tick(0.01)
	r.press("W")
	r._tick(0.01)
	check("一段里连着三个冲动（↑ → ↓），WASD 也能按 → 全按住才算一次成功", r.successes == 2)
	var l0: float = player.laugh.value
	seg.call(["LEFT"])
	r.press("LEFT")
	check("按成冲动的同方向 → 躲开了，失败，闷笑上涨", r.fails == 1 and player.laugh.value > l0)
	seg.call(["DOWN"])
	r._tick(2.0)
	check("超时 → 失败", r.fails == 2)
	var l1: float = player.laugh.value
	r.rest_t = 5.0
	r._tick(1.0)
	check("卫兵一直在挠：闷笑持续上涨", player.laugh.value > l1)
	var it0: float = r.impulse_time()
	r.successes = 50
	check("提速更快：20 次后限时比原来短", (func(): r.successes = 20; return r.impulse_time() < 1.1 * pow(0.98, 20)).call())
	r.successes = 50
	check("越练限时越短（%.2f → %.2f 秒）、一段冲动越多" % [it0, r.impulse_time()], r.impulse_time() < it0
		and range(30).map(func(_i): return r.impulses_per_segment()).max() == 4)
	r.successes = 2
	await _punish_check(r, "laugh", "train_zone_punish_")
	var res := await _end_training(out)
	check("Esc 结束：成功 2 次，大腿敏感 0.006", res.get("successes", 0) == 2 and is_equal_approx(TrainingStats.value("train_sens_thigh"), 0.006))


func _run_maze() -> void:
	print("-- 训练二：魔力疲倦释放（训练迷宫）")
	await main.change_level(Floors.scene("floor_06_camp"))
	await _wait(0.6)
	_finish()
	player = GameState.player as Princess
	ctrl = ScriptedController.new()   # 换地图后旧公主（连同控制器）已经释放
	player.set_controller(ctrl)
	home = Cutscene.cell_to_world([40, 21])
	var out := await _start_training("fatigue_release")
	var r = out[0]
	if r == null:
		return
	player = GameState.player as Princess
	var lv: Node = main.level
	check("营地走到迷宫入口 → 换到训练迷宫，站在起点，出口找到了，训练中不播组合小演出",
		lv.scene_file_path == Floors.scene("floor_06_training") and r.exit_pos != Vector2.ZERO
		and player.global_position.distance_to(Cutscene.cell_to_world([25, 39])) < 24.0 and not ComboTracker.play_scenes)
	var doors := lv.find_children("*", "StaticBody2D", true, false).filter(func(n): return n.scene_file_path.ends_with("door.tscn"))
	check("迷宫 12 个房间，门都关着", doors.size() == 12 and doors.all(func(d): return not d.is_open))
	var design: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/floor_06_training/design.json"))
	var areas: Array = design.get("combo_areas", [])
	var walls: TileMapLayer = lv.get_node("Walls")
	var start := walls.local_to_map(walls.to_local(player.global_position))
	var reach := _flood(walls, start)
	check("12 个房间各一组迷宫组合，从起点都走得到（开门后）", areas.size() == 12
		and areas.map(func(a): return a["combo"]).all(func(c): return r.COMBOS.has(c))
		and areas.all(func(a): return reach.has(Vector2i(int(a["rect"][0]) + 4, int(a["rect"][1]) + 4))))
	var stairs := lv.find_children("*", "Area2D", true, false).filter(func(n): return n.scene_file_path.ends_with("stairs.tscn"))
	check("训练中出口楼梯不直接换地图（由训练判定逃离）", not stairs.is_empty() and stairs.all(func(s): return s.get("_used")))
	# 触发组合
	player.combo.triggered.emit("sole_party")
	check("迷宫外的组合不算", r.successes == 0)
	player.combo.triggered.emit("foot_bubble")
	check("触发「足浴泡泡」→ 魔力疲倦上限 -1、释放强度 +0.5%（立刻记上）", r.successes == 1
		and TrainingStats.value("train_fatigue_down") == 1.0 and is_equal_approx(TrainingStats.value("train_burst_power"), 0.5))
	var seen := [""]
	var on_start := func(id: String): seen[0] = id
	CG.started.connect(on_start)
	player.magic_event.emit("fatigue_burst", 0)
	await _advance_until(func(): return seen[0] != "" and not CG.is_busy(), 30.0)
	CG.started.disconnect(on_start)
	check("组合里魔力疲倦满了释放 → 这次提升 ×5（上限 -5、强度 +2.5%%），播奉献小剧场（%s）" % seen[0],
		TrainingStats.value("train_fatigue_down") == 5.0 and is_equal_approx(TrainingStats.value("train_burst_power"), 2.5)
		and seen[0] == "theater:train_release_foot_bubble" and r.devotions == 1)
	r._clock += 10.0
	player.combo.triggered.emit("bath_trio")
	r._clock += 10.0
	player.magic_event.emit("fatigue_burst", 0)
	check("组合触发很久之后才释放 → 不算 ×5", TrainingStats.value("train_fatigue_down") == 6.0 and r.devotions == 1)
	GameState.in_dialogue = false
	# 逃离冲动
	var d0: float = player.global_position.distance_to(r.exit_pos)
	var own_ctrl: CharacterController = player.controller
	r.start_escape()
	check("逃离冲动：控制权被抢走", player.controller == r.escape_ctrl and player.controller is WanderController and r.escaping)
	await _wait(1.2)
	var d1: float = player.global_position.distance_to(r.exit_pos)
	check("沿最短路往出口跑（离出口 %.0f → %.0f）" % [d0, d1], d1 < d0 - 8.0)
	var p0: float = r.pace_now()
	for i in 5:
		r.mash()
	r.tick(0.01)
	check("连按空格拖慢她（速度 %.2f → %.2f）" % [p0, r.pace_now()], r.pace_now() < p0 * 0.35 and is_equal_approx(r.escape_ctrl.pace, r.pace_now()))
	r.stop_escape()
	check("冲动过去：控制权还给玩家", player.controller == own_ctrl and is_instance_valid(own_ctrl) and not r.escaping)
	var s0 := {"dur": r.urge_duration(), "pace": r.base_pace(), "delay": range(20).map(func(_i): return r._urge_delay()).max()}
	r.successes = 10
	check("触发越多：冲动越频繁（最长间隔 %.1f → %.1f 秒）、持续越久、跑得越快" % [s0["delay"], range(20).map(func(_i): return r._urge_delay()).max()],
		r.urge_duration() > s0["dur"] and r.base_pace() > s0["pace"] and range(20).map(func(_i): return r._urge_delay()).max() < s0["delay"])
	check("提速更快：触发 10 次后冲动持续 %.1f 秒（原来 %.1f）" % [r.urge_duration(), 2.5 + 10 * 0.25], r.urge_duration() > 2.5 + 10 * 0.25)
	r.successes = 2
	r.urge_t = 0.01
	r.tick(0.05)
	check("间隔到了自己发作", r.escaping)
	r.stop_escape()
	# 逃到出口 = 失败
	player.global_position = r.exit_pos
	r.tick(0.01)
	await _advance_until(func(): return not out[1].is_empty(), 30.0)
	var res: Dictionary = out[1]
	player = GameState.player as Princess
	check("逃到出口 → 这一轮结束（失败），已经拿到的保留：触发 %d 次、%s" % [res.get("successes", 0), res.get("gained", {})],
		res.get("reason", "") == "escaped" and res.get("successes", 0) == 2 and is_equal_approx(float(res.get("gained", {}).get("train_fatigue_down", 0)), 6.0))
	check("回到营地的迷宫入口旁，组合小演出恢复", main.level.scene_file_path == Floors.scene("floor_06_camp")
		and player.global_position.distance_to(Cutscene.cell_to_world([46, 20])) < 24.0 and ComboTracker.play_scenes == false)
	check("魔力疲倦上限 500 - 6 = 494，释放强度 ×%.3f" % TrainingStats.burst_mult(), player.fatigue.max_value == 494.0
		and is_equal_approx(TrainingStats.burst_mult(), 1.03))


## 从人物对话（莫丝「我想训练」）进入训练：训练里读石碑、新陷阱第一次对话结束后都能继续动。
func _run_dialogue_entry() -> void:
	print("-- 从对话进入训练（读石碑 / 新陷阱第一次对话后不卡）")
	_clear_training()
	GameState.give_item(ItemDB.get_item("coin"), 10)
	player = GameState.player as Princess
	ctrl = ScriptedController.new()
	player.set_controller(ctrl)
	Dialogue.talk("floor_06/guard_moss")
	var g := 0
	while g < 900 and not (TrainingDB.current != null and TrainingDB.current.playing):
		g += 1
		var cm: ChoiceMenu = Dialogue.runner.choice_menu
		var menus := get_tree().root.get_children().filter(func(n): return n is TrainingMenu)
		if not menus.is_empty():
			menus[0].pick(1)   # 魔力疲倦释放（训练迷宫）
		elif cm.is_open():
			cm.choose(maxi(cm.options.find("我想训练"), 0))
		elif Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.03)
	var r = TrainingDB.current
	check("对话里选了训练：对话先结束，再开始训练（runner 不再占着）", r != null and r.playing and not Dialogue.runner.is_running())
	if r == null:
		return
	r.time_scale = 0.0
	player = GameState.player as Princess
	Dialogue.start("sign6_maze")
	await _advance_until(func(): return not Dialogue.is_active(), 5.0)
	await _wait(0.3)
	check("训练中读石碑：读完能继续动", not GameState.in_dialogue)
	GameState.flags.erase("met_foot_bath")
	var bath: Node2D = load("res://scenes/traps/foot_bath.tscn").instantiate()
	main.level.get_node("Entities").add_child(bath)
	bath.global_position = player.global_position + Vector2(16, 0)
	await _advance_until(func(): return GameState.has_flag("met_foot_bath"), 6.0)   # 第一次被挠时播放对话
	await _advance_until(func(): return not Dialogue.is_active(), 6.0)
	await _wait(0.4)
	var hits := [0]
	var on_hit := func(h: HitData): if h.source == bath: hits[0] += 1
	player.tickled.connect(on_hit)
	await _wait(1.0)
	player.tickled.disconnect(on_hit)
	check("训练中被新陷阱第一次挠（播放第一次的对话）：对话结束后陷阱照常挠（1 秒 %d 下）、地图不卡" % hits[0], not GameState.in_dialogue
		and GameState.has_flag("met_foot_bath") and hits[0] >= 1)
	if player.status.is_grabbed():
		player.status.release(true)
	bath.queue_free()
	r.quit("esc")
	await _advance_until(func(): return TrainingDB.current == null, 30.0)
	check("这一轮正常结束", TrainingDB.current == null and not GameState.in_dialogue)


## 墙图块上的连通格（不管门）。
func _flood(walls: TileMapLayer, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if not seen.has(n) and walls.get_cell_source_id(n) == -1 and n.x >= 0 and n.y >= 0 and n.x < 60 and n.y < 60:
				seen[n] = true
				todo.append(n)
	return seen


# ------------------------------------------------------------------ 工具
func _until(cond: Callable, max_time: float) -> float:
	var t := 0.0
	while not cond.call() and t < max_time:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return t


func check(label: String, ok: bool) -> void:
	print(("  [通过] " if ok else "  [失败] ") + label)
	if not ok:
		failures += 1


func _finish() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 60:
		Dialogue.advance()
		Dialogue.advance()
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

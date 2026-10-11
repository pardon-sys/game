extends Node
## 小镇攻防战：
##   城门 → 攻防战地图；导演、8 段城墙、梯子、两位公主（粉色操控、蓝色在城墙上用城墙法师 AI）。
##   波次：准备倒计时 → 号角提前开打 → 出怪、怪物走到墙下打墙（城墙总血量下降）→ 蓝色公主放法术打怪 → 打倒得冰晶 → 清完下一波。
##   失败：城墙归零 → 清场 → （失败小剧场）→ 城墙修好、从这一波的准备阶段重来。胜利：第 10 波打完 → siege_won。
##   蓝色公主：被挠下城墙 → 时间到自己走到梯子爬回去；倒下不倒计时，粉色公主按住 E 救起。粉色公主倒下 → 城门复活、城墙扣血。
##   C 键切换；性能：150 只怪同时在场的帧时间。
## 用法：Godot --headless --path . res://tests/siege_test.tscn   （退出码 0 = 全部通过）

var main: Node
var failures := 0


class HoldE extends CharacterController:
	func is_action_pressed(action: StringName) -> bool:
		return action == &"interact"


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept",
			"f8_maze_done", "f8_returned", "blue_tickle_pants", "backpack", "f7r_done", "f6w_arrived", "equip_unlocked"]:
		GameState.set_flag(f)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	await _run_enter()
	await _run_waves()
	await _run_blue_fall()
	await _run_downs()
	await _run_fail_and_win()
	await _run_perf()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


func _level_id() -> String:
	return str(main.level.get("floor_id")) if main.level else ""


func _dir() -> SiegeDirector:
	return SiegeDirector.current


# ------------------------------------------------------------------ 进场
func _run_enter() -> void:
	print("-- 城门 → 攻防战")
	await main.change_level(Floors.scene("floor_06_war"))
	await _advance_until(func(): return not Cutscene.is_playing() and not Dialogue.is_active(), 15.0)
	Dialogue.call("talk", "floor_06/war_gate")
	await _advance_until(func(): return _level_id() == "floor_06_siege" and _dir() != null and _dir().state != "", 30.0)
	# 开场过场（关卡载入 0.6 秒后才开始）
	await _advance_until(func(): return GameState.has_flag("siege_intro_seen") and not Cutscene.is_playing() and not Dialogue.is_active(), 30.0)
	var d := _dir()
	check("城门「出发！」→ 攻防战地图（%s），导演就绪（%s）" % [_level_id(), d.state if d else ""], _level_id() == "floor_06_siege" and d != null)
	check("8 段城墙（%d）、3 架梯子（%d）、城墙总血量 %d" % [d.walls.size(), d.ladders.size(), int(d.wall_max)],
		d.walls.size() == 8 and d.ladders.size() == 3 and d.wall_hp == d.wall_max)
	check("粉色公主操控、在城门口；蓝色公主在城墙上，用城墙法师 AI（%s）" % [d.blue.controller.get_class() if d.blue else ""],
		GameState.player == d.pink and d.blue and d.is_on_wall(d.blue) and d.blue.controller is SiegeMageController and not d.is_on_wall(d.pink)
		and Duo.active)
	check("开场过场放过了（%s）" % GameState.has_flag("siege_intro_seen"), GameState.has_flag("siege_intro_seen"))


# ------------------------------------------------------------------ 波次
func _run_waves() -> void:
	print("-- 波次")
	var d := _dir()
	var p0 := d.prep_left
	await _wait(1.0)
	check("准备阶段倒计时（%.1f → %.1f）" % [p0, d.prep_left], d.state == "prep" and d.prep_left < p0)
	var horn: SiegeHorn = main.level.find_children("*", "SiegeHorn", true, false)[0]
	horn.blow()
	await _wait(0.3)
	check("号角提前开打（%s）" % d.state, d.state == "fight")
	var hp0 := d.wall_hp
	var c0 := d.crystals
	var spells := {}
	var t := 0.0
	while t < 40.0 and d.state == "fight":
		var it: String = (d.blue.controller as SiegeMageController).intent
		if it.begins_with("spell:"):
			spells[it] = true
		await get_tree().process_frame
		t += get_process_delta_time()
	check("出怪了（打倒 %d 只），怪物打到城墙（%d → %d）" % [d.kills, int(hp0), int(d.wall_hp)], d.kills > 0 and d.wall_hp < hp0)
	check("蓝色公主自动放法术（%s）" % [spells.keys()], spells.has("spell:ice_rain"))
	check("打倒怪物得冰晶（%d → %d）" % [c0, d.crystals], d.crystals > c0)
	# 剩下的直接清掉，看清波
	d._queue.clear()
	for m in d.monsters.duplicate():
		if is_instance_valid(m):
			m.health.damage(999)
	await _advance_until(func(): return d.state == "prep" and d.wave == 2, 5.0)
	check("清完第 1 波 → 第 2 波准备（第 %d 波，%s）" % [d.wave, d.state], d.wave == 2 and d.state == "prep")


# ------------------------------------------------------------------ 蓝色公主被挠下城墙
func _run_blue_fall() -> void:
	print("-- 蓝色公主被挠下城墙 / 爬回去")
	var d := _dir()
	d.knock_off(d.blue, "测试")
	await _wait(1.0)
	var down := not d.is_on_wall(d.blue)
	d.blue.set_meta("siege_fallen_at", Time.get_ticks_msec() / 1000.0 - SiegeDirector.FALLEN_TIME - 0.1)
	var t := await _advance_until(func(): return d.is_on_wall(d.blue), 25.0)
	check("被挠下城墙（%s），时间到自己走去梯子爬回去（%.1f 秒）" % [down, t], down and d.is_on_wall(d.blue))
	# 粉色公主也能爬梯子
	var lad: SiegeLadder = d.nearest_ladder(d.pink.global_position)
	d.pink.global_position = lad.bottom_pos()
	await lad.climb(d.pink)
	var up := d.is_on_wall(d.pink)
	await lad.climb(d.pink)
	check("粉色公主爬梯子上城墙（%s）再下来（%s）" % [up, not d.is_on_wall(d.pink)], up and not d.is_on_wall(d.pink))


# ------------------------------------------------------------------ 倒下
func _run_downs() -> void:
	print("-- 倒下")
	var d := _dir()
	d.blue.health.damage(999)
	await _advance_until(func(): return Downed.is_downed(d.blue), 5.0)
	var dn: Downed = d.blue.get_node_or_null("Downed")
	var tl0 := dn.time_left if dn else 0.0
	await _wait(1.0)
	check("蓝色公主倒下：倒地不倒计时（%.1f → %.1f）" % [tl0, dn.time_left if dn else -1.0], dn != null and dn.time_left == tl0)
	var lad: SiegeLadder = d.nearest_ladder(d.blue.global_position)
	d.pink.global_position = d.blue.global_position + Vector2(10, 0)
	d.pink.set_controller(HoldE.new())
	await _advance_until(func(): return not Downed.is_downed(d.blue), 5.0)
	d.pink.set_controller(PlayerInputController.new())
	check("粉色公主过去按住 E 救起蓝色公主（%s）" % (not Downed.is_downed(d.blue)), not Downed.is_downed(d.blue) and d.blue.is_alive())
	# 粉色公主倒下：城门复活、打仗时城墙扣血
	d.blue.global_position = Vector2(d.gate_pos.x + 16.0, d.wall_top_y() + 4.0)
	d._queue = [{"t": 9999.0, "monster": "slime", "from": "bottom"}]   # 让这一波别马上清完
	d.state = "fight"
	d.pink.global_position = d.gate_pos + Vector2(200, 300)
	var hp0 := d.wall_hp
	d.pink.health.damage(999)
	await _advance_until(func(): return d.pink.is_alive() and d.pink.state != PlayableCharacter.State.DEAD, 8.0)
	check("粉色公主倒下 → 城门复活（离城门 %.0f），城墙扣血（%d → %d）" % [d.pink.global_position.distance_to(d.gate_pos), int(hp0), int(d.wall_hp)],
		d.pink.is_alive() and d.pink.global_position.distance_to(d.gate_pos) < 24.0 and d.wall_hp < hp0)
	d._queue.clear()
	d.state = "prep"


# ------------------------------------------------------------------ 失败 / 胜利
func _run_fail_and_win() -> void:
	print("-- 失败 / 胜利")
	var d := _dir()
	d.start_now()
	await _wait(0.3)
	var w := d.wave
	d.wall_hp = 10.0
	d.walls[3].take(50.0)
	await _advance_until(func(): return d.state == "prep" and not d._busy, 20.0)
	check("城墙归零 → 失败 → 城墙修好（%d）、怪物清空（%d）、从第 %d 波的准备阶段重来（第 %d 波 %s）" % [int(d.wall_hp), d.monsters.size(), w, d.wave, d.state],
		d.wall_hp == d.wall_max and d.monsters.is_empty() and d.wave == w and d.state == "prep")
	d.wave = 10
	d.start_now()
	await _wait(0.3)
	d._queue.clear()
	for m in d.monsters.duplicate():
		if is_instance_valid(m):
			m.health.damage(999)
	await _advance_until(func(): return GameState.has_flag("siege_won"), 5.0)
	check("第 10 波打完 → 胜利（%s）" % GameState.has_flag("siege_won"), GameState.has_flag("siege_won") and d.state == "won")
	await _advance_until(func(): return _level_id() == "floor_06_war", 20.0)
	check("胜利过场后回到战时小镇（%s）" % _level_id(), _level_id() == "floor_06_war")


# ------------------------------------------------------------------ 性能
func _run_perf() -> void:
	print("-- 性能：150 只怪")
	GameState.set_flag("siege_won", false)
	GameState.vars["siege_wave"] = 3
	await _wait(2.0)
	await main.change_level(Floors.scene("floor_06_siege"))
	await _advance_until(func(): return _dir() != null and _dir().state == "prep" and not Cutscene.is_playing(), 20.0)
	var d := _dir()
	d.data["alive_cap"] = 200
	var keys := ["slime", "rat", "caterpillar", "squirrel", "fairy"]
	for i in 150:
		d.spawn(keys[i % keys.size()], ["bottom", "left", "right", "hole"][i % 4])
	d.state = "fight"
	await _wait(1.0)
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var worst := 0.0
	var last := t0
	while Time.get_ticks_usec() - t0 < 4_000_000:
		await get_tree().physics_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
		frames += 1
	var avg := 4000.0 / frames
	check("150 只怪同时在场：平均每物理帧 %.1f ms（%d 帧，最慢 %.1f ms），目标 ≤ 33 ms" % [avg, frames, worst], avg <= 33.0 and d.monsters.size() >= 120)


# ------------------------------------------------------------------ 工具
func _advance_until(cond: Callable, max_time: float) -> float:
	var t := 0.0
	while not cond.call() and t < max_time:
		if Dialogue.runner.choice_menu.is_open():
			Dialogue.runner.choice_menu.choose(0)
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		if CG.is_busy() and CG.has_method("skip"):
			CG.skip()
		await get_tree().process_frame
		t += get_process_delta_time()
	return t


func check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["通过" if ok else "失败", label])
	if not ok:
		failures += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

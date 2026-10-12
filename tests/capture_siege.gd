extends Node
## 攻防战截图（开发用）：Godot --path . res://tests/capture_siege.tscn [-- only=名字,名字] → tools/.cache/shots/siege_*.png

const OUT := "res://tools/.cache/shots/"

var main: Node
var only: Array = []
var d: SiegeDirector


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.trim_prefix("only=").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_tree().create_timer(900.0, true, false, true).timeout.connect(func():
		push_error("截图超时")
		get_tree().quit(1))
	TutorialBoard.enabled = false
	SiegeIntel.auto_controls = false   # 按键说明情报不自动弹（siege3_test 单独测）
	ComboTracker.play_scenes = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept",
			"f8_maze_done", "f8_returned", "blue_tickle_pants", "backpack", "f7r_done", "f6w_arrived", "equip_unlocked", "seen_fatigue_burst",
			"intro_done_siege_intro", "siege_intro_seen"]:
		GameState.set_flag(f)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	await main.change_level(Floors.scene("floor_06_siege"))
	await _until(func(): return SiegeDirector.current != null and SiegeDirector.current.state == "prep")
	d = SiegeDirector.current
	await _wait(0.6)
	_finish()
	await _shot("prep")
	# 冰塔：两人一起造（冰光）
	d.add_crystals(300)
	var base := Vector2(d.gate_pos.x - 240.0, d.wall_foot_y() + 80.0)
	var pad := BuildPad.new()
	d.entities().add_child(pad)
	pad.global_position = base + Vector2(120, 60)
	d.pink.global_position = pad.global_position + Vector2(0, 14)
	pad.request("frost")
	await _until(func(): return pad.beaming, 15.0)
	await _wait(1.2)
	await _shot("build_beam")
	await _until(func(): return pad.tower != null, 8.0)
	# 6 种冰塔排一排
	var kinds := ["icicle", "snowman", "decoy", "mint", "frost", "repair"]
	for i in kinds.size():
		var pd := BuildPad.new()
		d.entities().add_child(pd)
		pd.global_position = base + Vector2(i * 56.0, 0)
		pd._build(kinds[i], 2 if i % 2 == 0 else 1)
	await _look(base + Vector2(140, -30), 0.6)
	await _wait(0.6)
	await _shot("towers")
	_unlook()
	# 敌塔
	var sites := get_tree().get_nodes_in_group("siege_enemy_site")
	var ek := ["totem", "thigh_tower", "sole_tower", "portal", "vine_pull", "net"]
	for i in mini(sites.size(), ek.size()):
		(sites[i] as EnemySite).build(ek[i])
	await _wait(0.8)
	await _look((sites[0] as Node2D).global_position + Vector2(0, -30), 0.5)
	await _shot("enemy_towers")
	_unlook()
	# 开打：100 多只怪
	d.data["alive_cap"] = 200
	var keys := ["slime", "rat", "caterpillar", "squirrel", "fairy", "gecko", "hook", "shield_crab", "hug_bear", "warm_slime"]
	d.start_now()
	await _wait(0.3)
	d._queue = [{"t": 99999.0, "monster": "slime", "from": "bottom"}]
	for i in 130:
		var p := Vector2(randf_range(80, d.map_size().x - 80), randf_range(d.wall_foot_y() + 60, d.wall_foot_y() + 420))
		d.spawn(keys[i % keys.size()], "", p)
	await _wait(4.0)
	await _look(Vector2(d.gate_pos.x, d.wall_foot_y() + 120), 0.5)
	await _shot("horde")
	_unlook()
	# 攻城车撞墙
	d.spawn("cart", "", Vector2(d.blue.global_position.x, d.wall_foot_y() + 150))
	await _look(Vector2(d.blue.global_position.x, d.wall_foot_y() + 30), 1.0)
	await _wait(1.0)
	await _shot("cart_warn")
	await _until(func(): return not d.is_on_wall(d.blue), 8.0)
	await _wait(0.2)
	await _shot("cart_crash")
	_unlook()
	# 钩索上墙
	var hook := d.spawn("hook", "", Vector2(d.gate_pos.x + 200, d.wall_foot_y() + 120)) as HookClimber
	await _until(func(): return hook == null or hook.climbing, 8.0)
	if hook:
		await _look(hook.global_position + Vector2(0, -40), 1.0)
		await _wait(0.5)
		await _shot("hook")
		_unlook()
	# 瞄准施法
	GameState.switch_control(d.blue)
	await _wait(0.3)
	d.blue.global_position = Vector2(d.gate_pos.x + 16.0, d.wall_top_y() + 4.0)
	d.blue.set_meta("siege_cd", {})
	d.aim.open(d.blue, "barrier")
	await _wait(0.6)
	await _shot("aim")
	d.aim.close()
	GameState.switch_control(d.pink)
	await _wait(0.3)
	# 陷阱
	d.pink.global_position = Vector2(d.gate_pos.x - 200, d.wall_foot_y() + 200)
	d.spawn_hazard("tornado", d.pink.global_position + Vector2(60, 10))
	d.spawn_hazard("fog", d.pink.global_position + Vector2(-80, 40))
	d.spawn_hazard("link_rune", d.pink.global_position + Vector2(20, 30))
	await _wait(2.4)
	await _shot("hazards")
	d.spawn_hazard("bubbles", Vector2(d.map_size().x / 2.0, d.pink.global_position.y))
	await _wait(6.0)
	await _shot("bubbles")
	# 牺牲互救：城墙爬藤
	d.clear_field()
	await _wait(0.3)
	d._queue = [{"t": 99999.0, "monster": "slime", "from": "bottom"}]
	d.state = "fight"
	d.blue.global_position = Vector2(d.gate_pos.x + 16.0, d.wall_top_y() + 4.0)
	var vine: HazardWallVine = d.spawn_hazard("wall_vine", Vector2(d.blue.global_position.x, d.wall_foot_y()))
	d.pink.global_position = vine.global_position + Vector2(0, 14)
	await _until(func(): return vine.bound != null, 6.0)
	await _wait(1.0)
	await _shot("wall_vine")
	# 冰链
	d.clear_field()
	await _wait(0.3)
	d._queue = [{"t": 99999.0, "monster": "slime", "from": "bottom"}]
	d.state = "fight"
	var s2: EnemySite = sites[2]
	var vt := s2.build("vine_pull")
	await _wait(0.3)
	d.pink.global_position = vt.global_position + Vector2(0, -140)
	vt._t = 0.0
	d.blue.global_position = Vector2(d.pink.global_position.x, d.wall_top_y() + 4.0)
	await _until(func(): return d.rescuing, 8.0)
	await _look((d.pink.global_position + d.blue.global_position) / 2.0, 0.4)
	await _wait(1.0)
	await _shot("ice_chain")
	_unlook()
	# 情报卡
	d.intel.discover("cart")
	d.intel.open("cart")
	await _wait(0.3)
	await _shot("intel")
	d.intel.close()
	# 临时装备 + 立绘飘字
	await _wait(3.0)
	Equipment.force("pink", "equip_t_feather_socks")
	EquipFx.of(d.pink).flare("equip_t_feather_socks", "sole")
	await _wait(0.15)
	await _shot("forced_equip")
	var bp = get_tree().root.find_child("Backpack", true, false)
	bp.open()
	bp.set_page(bp.PAGE_EQUIP)
	bp.equip_page.who = "pink"
	bp.equip_page.slot_index = EquipPage.ZONES.find("sole")
	bp.equip_page.refresh()
	await _wait(0.3)
	await _shot("equip_forced_page")
	bp.close()
	# 组合特效
	SiegeFx.combo_fx(d.pink, "vortex")
	SiegeFx.combo_fx(d.pink, "heart_fluff")
	await _wait(0.3)
	await _shot("combo_fx")
	# 新的笑倒 CG / 组合小演出 / 失败小剧场
	CG.play_death("hug_bear")
	await _cg_frame(5)
	await _shot("cg_bear")
	await _cg_end()
	CG.play_scene("sg_foot_assault")
	await _cg_frame(5)
	await _shot("scene_foot")
	await _cg_end()
	CG.play_theater("siege_fail_7_pants")
	await _cg_frame(8)
	await _shot("theater_fail7")
	await _cg_end()
	get_tree().quit(0)


func _cg_frame(step: int) -> void:
	var g := 0
	while CG.is_busy() and CG.step_index < step and g < 600:
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.05)
		g += 1
	await _wait(0.6)


func _cg_end() -> void:
	var g := 0
	while CG.is_busy() and g < 200:
		CG._can_skip = true
		CG.skip()
		_finish()
		await _wait(0.05)
		g += 1
	await _wait(0.3)


## 用玩家的镜头看某个地方（镜头临时脱离人物）。
func _look(at: Vector2, zoom: float) -> void:
	var cam := GameState.player.camera
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	cam.global_position = at
	cam.zoom = Vector2(zoom, zoom)
	cam.reset_smoothing()
	await _wait(0.3)


func _unlook() -> void:
	var cam := GameState.player.camera
	cam.top_level = false
	cam.position = Vector2.ZERO
	cam.position_smoothing_enabled = true
	d.cam.set_zoom_level(1.0, true)
	cam.reset_smoothing()


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _until(cond: Callable, max_time := 20.0) -> void:
	var t := 0.0
	while not cond.call() and t < max_time:
		if Dialogue.runner.choice_menu.is_open():
			Dialogue.runner.choice_menu.choose(0)
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.05)
		t += 0.05


func _shot(name: String) -> void:
	if not only.is_empty() and not only.has(name):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "siege_" + name + ".png"))
	print("shot ", name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

extends Node
## 攻防战第三轮截图（开发用）：Godot --path . res://tests/capture_siege3.tscn [-- only=名字,名字] → tools/.cache/shots/siege3_*.png

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
	d.add_crystals(300)
	# 按键说明情报
	d.intel.open("controls")
	await _wait(0.3)
	await _shot("controls")
	d.intel.close()
	# B 键造塔菜单（带滚动的选择界面），往下翻到底
	d.pink.global_position = Vector2(d.gate_pos.x + 120.0, d.wall_foot_y() + 90.0)
	d.try_build(d.pink, d.pink.global_position)
	await _wait(0.3)
	if ScrollPicker.current:
		for i in 7:
			ScrollPicker.current.selected = i + 1
			ScrollPicker.current._refresh()
		await _wait(0.3)
		await _shot("build_picker")
		ScrollPicker.current.cancel()
	await _wait(0.3)
	# 第五轮的新塔（3 级）+ 怪群
	_fight()
	var tb := Vector2(d.gate_pos.x - 200.0, d.wall_foot_y() + 120.0)
	var kinds5 := ["mortar", "vortex", "resonance", "meteor", "hotspring", "lamp", "shield"]
	for i in kinds5.size():
		var pd5 := BuildPad.new()
		d.entities().add_child(pd5)
		pd5.global_position = tb + Vector2((i % 4) * 70.0, (i / 4) * 60.0)
		pd5._build(kinds5[i], 3)
	for i in 30:
		var m5 := d.spawn("rat" if i % 2 else "slime", "", tb + Vector2(randf_range(-40, 260), randf_range(80, 160)))
		m5.mind = null
	await _wait(0.3)
	for t5 in get_tree().get_nodes_in_group("siege_tower"):
		(t5 as IceTower)._t = 0.0
	await _wait(1.0)
	await _look(tb + Vector2(110, 50), 0.9)
	await _shot("towers5")
	await _wait(0.9)
	await _shot("towers5_b")
	_unlook()
	await _clear()
	# 第七轮：城墙灯 + 冰法学徒帮忙放冰光
	if only.is_empty() or only.any(func(n): return str(n).begins_with("r7_")):
		_fight()
		d.blue.set_controller(CharacterController.new())
		var pd7 := BuildPad.new()
		d.entities().add_child(pd7)
		pd7.global_position = Vector2(d.gate_pos.x - 60.0, d.wall_foot_y() + 60.0)
		await _wait(0.1)
		pd7.request("frost")
		await _until(func(): return pd7.helpers.size() >= 1, 15.0)
		await _wait(0.2)
		await _look(pd7.global_position + Vector2(0, -20), 2.0)
		await _shot("r7_mages")
		_unlook()
		d.features.begin(["fog"])
		await _wait(2.0)
		await _look(Vector2(d.gate_pos.x - 120.0, d.wall_foot_y() - 20.0), 1.3)
		await _shot("r7_wall_lights")
		_unlook()
		d.features.end()
		await _wait(1.8)
		await _look(Vector2(d.walls[2].global_position.x, d.wall_foot_y() - 24.0), 3.0)
		await _shot("r7_wall_close")
		_unlook()
		d.features.end()
		d.blue.set_controller(d._make_ai(d.blue))
		await _clear()
	# 第六轮：每波特色
	if only.is_empty() or only.any(func(n): return str(n).begins_with("feat_")):
		var f := d.features
		d.wave = 12
		_fight()
		f.begin(["carnival", "feathers", "corps", "raiders"])
		await _wait(0.6)
		await _shot("feat_title")
		await _wait(2.5)
		var tp := Vector2(d.gate_pos.x + 140.0, d.wall_foot_y() + 120.0)
		await _clear_towers_only()
		var rs := f.raid()
		for m in rs:
			m.global_position = tp + Vector2(randf_range(-20, 100), randf_range(30, 60))
		d.pink.global_position = tp + Vector2(40, 120)
		for i in 2:
			var pdf := BuildPad.new()
			d.entities().add_child(pdf)
			pdf.global_position = tp + Vector2(i * 80.0, 0)
			pdf._build(["cocoa", "mint"][i], 1)
		await _wait(1.2)
		await _shot("feat_hud")
		await _look(tp + Vector2(40, 50), 1.2)
		await _shot("feat_raiders")
		_unlook()
		f.corps()
		await _wait(0.4)
		await _look(Vector2(d.map_size().x / 2.0, d.map_size().y - 160.0), 0.5)
		await _shot("feat_corps")
		await _wait(1.6)
		await _look(Vector2(d.map_size().x / 2.0, d.map_size().y - 120.0), 0.6)
		await _shot("feat_corps_b")
		_unlook()
		await _clear()
		f.begin(["gale", "fog"])
		await _wait(2.5)
		for i in 8:
			var gm := d.spawn("ghost" if i % 2 else "slime", "", d.pink.global_position + Vector2(randf_range(-80, 80), randf_range(-40, 60)))
			gm.mind = null
		f.gust()
		await _wait(0.5)
		await _shot("feat_gale_fog")
		f.end()
		d.wave = 1
		await _clear()
	# 镇民支援过场（中途截一张）
	var job := func(): await d.town.grant("mayor")
	job.call()
	await get_tree().create_timer(1.35, true, false, true).timeout
	await _shot("town_npc")
	await get_tree().create_timer(1.3, true, false, true).timeout
	await _shot("town_show")
	await get_tree().create_timer(3.0, true, false, true).timeout
	await _wait(0.5)
	# 士兵
	await _look(Vector2(d.gate_pos.x - 120.0, d.wall_foot_y() + 10.0), 1.4)
	await _shot("soldiers")
	_unlook()
	_fight()
	# 新友军塔
	var base := Vector2(d.gate_pos.x - 160.0, d.wall_foot_y() + 110.0)
	for i in 3:
		var pd := BuildPad.new()
		d.entities().add_child(pd)
		pd.global_position = base + Vector2(i * 70.0, 0)
		pd._build(["campfire", "ballista", "cocoa"][i], 2 if i == 1 else 1)
	for i in 3:
		var g := d.spawn("ghost", "", base + Vector2(randf_range(-20, 20), 40 + i * 12))
		g.mind = null
	await _wait(1.2)
	await _look(base + Vector2(70, -10), 1.4)
	await _shot("new_towers")
	_unlook()
	await _clear()
	# 敌塔特效
	var sites := get_tree().get_nodes_in_group("siege_enemy_site")
	sites.sort_custom(func(a, b): return (a as Node2D).global_position.y < (b as Node2D).global_position.y)
	var kinds := ["glue", "windmill", "silence", "portal", "totem", "vine_pull"]
	for i in kinds.size():
		(sites[i] as EnemySite).build_tower(kinds[i])
	await _wait(1.0)
	d.pink.global_position = (sites[1] as Node2D).global_position + Vector2(0, 80)
	var wm: EnemyTower = (sites[1] as EnemySite).tower
	wm._t = 0.6
	await _wait(0.75)
	await _look((sites[1] as Node2D).global_position + Vector2(0, 30), 1.0)
	await _shot("etower_windmill")
	_unlook()
	await _look((sites[0] as Node2D).global_position + Vector2(0, -10), 1.3)
	await _shot("etower_glue")
	_unlook()
	(sites[0] as EnemySite).tower.health.damage(5)
	await _wait(0.2)
	await _look((sites[0] as Node2D).global_position + Vector2(0, -10), 1.6)
	await _shot("etower_hit")
	_unlook()
	await _clear()
	# 新法术
	var b := d.blue
	var at := Vector2(b.global_position.x, d.wall_foot_y() + 220.0)
	for i in 14:
		var m := d.spawn("slime" if i % 2 else "rat", "", at + Vector2(randf_range(-80, 80), randf_range(-40, 40)))
		m.mind = null
	b.set_meta("siege_cd", {})
	SiegeSpells.cast(b, "blizzard", at)
	b.set_meta("siege_cd", {})
	SiegeSpells.cast(b, "spike", at + Vector2(160, 40))
	b.set_meta("siege_cd", {})
	SiegeSpells.cast(b, "mirror", at + Vector2(-140, 20))
	await _wait(0.7)
	await _look(at + Vector2(0, -40), 0.85)
	await _shot("spells")
	_unlook()
	await _clear()
	# 出生动画
	d.quiet_spawn = false
	var sp := Vector2(d.gate_pos.x + 160.0, d.wall_foot_y() + 200.0)
	for i in 6:
		d.spawn(["rat", "slime", "gecko", "hook", "shield_crab", "bat"][i], "", sp + Vector2(i * 22.0 - 55.0, 0))
	await _wait(0.3)
	await _look(sp + Vector2(0, -10), 1.6)
	await _shot("burrow")
	_unlook()
	d.quiet_spawn = true
	await _clear()
	# 小 Boss：出场 / 预警 / 狂暴
	var gat := Vector2(d.gate_pos.x - 220.0, d.wall_foot_y() + 240.0)
	var g2 := d.spawn("troll_general", "", gat) as TrollGeneral
	await _wait(1.5)
	await _shot("boss_intro")
	await _wait(1.6)
	d.pink.global_position = g2.global_position + Vector2(30, 20)
	g2.skill = ""
	g2._start("quake")
	await _wait(0.6)
	await _look(g2.global_position + Vector2(0, -20), 1.1)
	await _shot("boss_quake_warn")
	await _wait(0.5)
	await _shot("boss_quake_hit")
	_unlook()
	await _until(func(): return g2.skill == "", 4.0)
	g2._start("swipe")
	await _wait(0.3)
	await _look(g2.global_position + Vector2(0, -20), 1.3)
	await _shot("boss_swipe")
	_unlook()
	await _until(func(): return g2.skill == "", 4.0)
	g2._start("banner")
	await _wait(1.0)
	g2.health.damage(g2.health.max_hp / 2 + 2)
	await _wait(0.4)
	await _shot("boss_rage")
	await _wait(1.5)
	await _look(g2.global_position + Vector2(0, -20), 1.3)
	await _shot("boss_raged")
	_unlook()
	await _clear()
	# 修好的 CG 素材
	CG.play_death("cart")
	await _cg_frame(4)
	await _shot("cg_cart")
	await _cg_end()
	CG.play_death("gecko")
	await _cg_frame(4)
	await _shot("cg_gecko")
	await _cg_end()
	CG.play_death("troll_general")
	await _cg_frame(6)
	await _shot("cg_general")
	await _cg_end()
	# 城墙层级
	d.pink.global_position = Vector2(d.gate_pos.x - 60.0, d.wall_foot_y() + 12.0)
	await _wait(0.4)
	await _look(d.pink.global_position + Vector2(0, -20), 2.0)
	await _shot("wall_layer")
	_unlook()
	get_tree().quit(0)


func _fight() -> void:
	d._queue = [{"t": 99999.0, "monster": "slime", "from": "bottom"}]
	d._hazards.clear()
	d.state = "fight"


func _clear() -> void:
	d.state = "prep"
	d.clear_field()
	for n in get_tree().get_nodes_in_group("siege_pad"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("siege_tower"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("siege_enemy_tower"):
		n.queue_free()
	Engine.time_scale = 1.0
	await _wait(0.3)
	d.pink.global_position = d.gate_pos + Vector2(0, 140)
	_fight()


func _clear_towers_only() -> void:
	for n in get_tree().get_nodes_in_group("siege_tower"):
		n.queue_free()
	await _wait(0.1)


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
		if Dialogue.is_active() and not Dialogue.runner.choice_menu.is_open():
			Dialogue.advance()
		await _wait(0.05)
		t += 0.05


func _shot(name: String) -> void:
	if not only.is_empty() and not only.has(name):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "siege3_" + name + ".png"))
	print("shot ", name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

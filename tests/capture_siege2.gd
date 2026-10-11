extends Node
## 攻防战第二轮截图（开发用）：Godot --path . res://tests/capture_siege2.tscn [-- only=名字,名字] → tools/.cache/shots/siege2_*.png
## 法术格 + 吟诵姿势、B 键建塔菜单、友军士兵、工兵搭塔进度条、活梯子、攻城车护卫阵、蝠群空投、史莱姆合体、
## 羽毛舞会、龙卷风卷怪、迷雾伏击、双龙卷 / 迷雾龙卷 / 泡泡扫帚、小地图上搭塔的紫圈。

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
	# 士兵
	await _look(Vector2(d.gate_pos.x + 60.0, d.wall_foot_y() - 10.0), 1.3)
	await _wait(0.5)
	await _shot("soldiers")
	_unlook()
	# B 键建塔菜单
	d.pink.global_position = Vector2(d.gate_pos.x + 120.0, d.wall_foot_y() + 90.0)
	await _wait(0.3)
	d.try_build(d.pink, d.pink.global_position)
	await _wait(0.4)
	await _shot("build_menu")
	Dialogue.runner.choice_menu.choose(0)
	await _wait(0.3)
	# 法术格 + 吟诵姿势
	GameState.switch_control(d.blue)
	await _wait(0.3)
	d.blue.global_position = Vector2(d.gate_pos.x + 16.0, d.wall_top_y() + 4.0)
	d.blue.set_meta("siege_cd", {"snow": 20.0})
	d.aim.open(d.blue, "ice_rain")
	await _wait(0.8)
	await _shot("spell_chant")
	d.aim.close()
	GameState.switch_control(d.pink)
	await _wait(0.3)
	_fight()
	# 工兵搭塔
	var sites := get_tree().get_nodes_in_group("siege_enemy_site")
	var site: EnemySite = sites[sites.size() / 2]
	d.teamwork.spawn_formation("engineer_escort", site.global_position + Vector2(30, 20))
	await _until(func(): return site.is_building() or sites.any(func(s): return s.is_building()), 15.0)
	await _wait(3.0)
	var bs: EnemySite = sites.filter(func(s): return s.is_building())[0] if sites.any(func(s): return s.is_building()) else site
	await _look(bs.global_position + Vector2(0, -20), 1.3)
	await _shot("engineers")
	_unlook()
	await _wait(0.1)
	await _shot("minimap_build")
	await _clear()
	# 活梯子
	var atw := Vector2(d.gate_pos.x - 260.0, d.wall_foot_y() + 4.0)
	for g in d.teamwork.spawn_formation("gecko_ladder", atw):
		g.global_position = atw + Vector2(randf_range(-10, 10), 0)
	d.teamwork._cd.clear()
	d.teamwork.scan()
	for i in 4:
		d.spawn("slime", "", atw + Vector2(randf_range(-20, 20), 40 + i * 8))
	await _wait(0.9)
	await _look(atw + Vector2(0, -30), 1.3)
	await _shot("living_ladder")
	_unlook()
	await _clear()
	# 攻城车护卫阵
	var cat := Vector2(d.gate_pos.x + 200.0, d.wall_foot_y() + 260.0)
	d.teamwork.spawn_formation("cart_escort", cat)
	await _wait(1.5)
	await _look(cat + Vector2(0, -50), 1.1)
	await _shot("cart_escort")
	_unlook()
	await _clear()
	# 蝠群空投
	var dat := Vector2(d.gate_pos.x - 80.0, d.wall_foot_y() + 120.0)
	d.teamwork.spawn_formation("bat_airdrop", dat)
	await _wait(1.0)
	await _look(dat + Vector2(0, -60), 1.1)
	await _shot("airdrop")
	_unlook()
	await _clear()
	# 史莱姆合体 + 羽毛舞会
	var mat := Vector2(d.gate_pos.x + 60.0, d.wall_foot_y() + 140.0)
	d.pink.global_position = mat + Vector2(40, 0)
	var sl := d.teamwork.spawn_formation("slime_merge", mat)
	for m in sl:
		m.mind = null
		m.global_position = mat
	var fd := d.teamwork.spawn_formation("feather_dance", mat + Vector2(60, 10))
	for m in fd:
		m.mind = null
		m.global_position = mat + Vector2(60, 10)
	d.teamwork._cd.clear()
	d.teamwork.scan()
	await _wait(0.8)
	await _look(mat + Vector2(30, -10), 1.3)
	await _shot("teamwork")
	_unlook()
	await _clear()
	# 龙卷风卷怪 / 迷雾伏击
	var c := Vector2(d.gate_pos.x - 160.0, d.wall_foot_y() + 220.0)
	d.pink.global_position = c + Vector2(260, 0)
	d.spawn_hazard("tornado", c)
	for i in 4:
		var m := d.spawn("rat", "", c + Vector2(i * 6.0, 4))
		m.mind = null
	d.spawn_hazard("fog", c + Vector2(150, 30))
	for i in 5:
		var m2 := d.spawn("slime", "", c + Vector2(130 + i * 10.0, 20 + i * 6))
		m2.mind = null
	await _wait(2.4)
	await _look(c + Vector2(80, 0), 0.9)
	await _shot("tornado_fog")
	_unlook()
	await _clear()
	# 陷阱组合
	for k in ["double_tornado", "fog_tornado", "bubble_broom"]:
		d.spawn_hazard_combo(k)
		await _wait(2.6)
		await _look(d.pink.global_position + Vector2(0, -20), 0.6)
		await _shot("combo_" + k)
		_unlook()
		await _clear()
	get_tree().quit(0)


func _fight() -> void:
	d._queue = [{"t": 99999.0, "monster": "slime", "from": "bottom"}]
	d._hazards.clear()
	d.state = "fight"


func _clear() -> void:
	d.state = "prep"
	d.clear_field()
	await _wait(0.3)
	d.pink.global_position = d.gate_pos + Vector2(0, 140)
	_fight()


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
		if Dialogue.is_active() and not Dialogue.runner.choice_menu.is_open():
			Dialogue.advance()
		await _wait(0.05)
		t += 0.05


func _shot(name: String) -> void:
	if not only.is_empty() and not only.has(name):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "siege2_" + name + ".png"))
	print("shot ", name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

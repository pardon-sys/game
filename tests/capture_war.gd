extends Node
## 第七层归途 → 战乱的小镇 → 装备系统的截图（开发用）：Godot --path . res://tests/capture_war.tscn → tools/.cache/shots/war_*.png

const OUT := "res://tools/.cache/shots/"

var main: Node


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	get_tree().create_timer(400.0, true, false, true).timeout.connect(func():
		push_error("截图超时")
		get_tree().quit(1))
	TutorialBoard.enabled = false
	ComboTracker.play_scenes = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	for f in ["f7_argue_done", "f7_pink_ran", "f7_blue_awake", "magic_unlocked", "intro_blue_magic", "f8_done", "f8_slept",
			"f8_maze_done", "f8_returned", "blue_tickle_pants", "backpack"]:
		GameState.set_flag(f)
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	# 归途：边走边聊
	await main.change_level(Floors.scene("floor_07_return"))
	await _until(func(): return GameState.has_flag("cutscene_seen_f7r_arrive") and not Cutscene.is_playing())
	var zones: Array = main.level.find_children("*", "BanterZone", true, false)
	zones.sort_custom(func(x, y): return str(x.id) < str(y.id))
	var p := GameState.player
	var blue := _char("blue")
	_place(p, (zones[1] as Node2D).global_position)
	blue.global_position = p.global_position + Vector2(10, 4)
	await _wait(3.4)
	await _shot("return_banter")
	await _wait(3.0)
	await _shot("return_banter2")
	# 问名字 → 士兵冲进来
	_place(p, Vector2(64 * 16 + 8, 17 * 16 + 8))
	await _cut_until(func(st: Dictionary): return str(st.get("text", "")).contains("小镇……小镇被"))
	await _wait(0.5)
	await _shot("return_soldier")
	# 战乱的小镇：队长的过场
	await _cut_until(func(st: Dictionary): return str(st.get("text", "")).contains("没……没发生什么"), 60.0)
	await _wait(0.6)
	await _shot("war_shy")
	await _cut_until(func(st: Dictionary): return str(st.get("text", "")).contains("你刚才是不是笑了"))
	await _wait(0.5)
	await _shot("war_captain_pants")
	while Cutscene.is_playing():
		_finish()
		await _wait(0.05)
	await _wait(1.0)
	await _shot("war_plaza")
	# 城墙边：冰塔地基、箭塔、城门
	_place(GameState.player, Vector2(32 * 16 + 8, 36 * 16 + 8))
	_char("blue").global_position = GameState.player.global_position + Vector2(14, 0)
	await _wait(1.0)
	await _shot("war_wall")
	# 换人对话
	_char("blue").call("_on_partner_talk", GameState.player)
	await _wait(0.6)
	_finish_lines()
	await _wait(0.6)
	await _shot("war_partner_menu")
	Dialogue.runner.choice_menu.choose(2)
	await _until(func(): return not Dialogue.runner.is_running())
	# 装备：解锁、买、穿
	Dialogue.call("talk", "floor_06/war_bonfire_host")
	await _until(func(): return GameState.has_flag("equip_unlocked"), 15.0, true)
	# 解锁后回到「要做什么？」，选最后一项「再见」关掉
	var g0 := 0
	while Dialogue.runner.is_running() and g0 < 200:
		if Dialogue.runner.choice_menu.is_open():
			Dialogue.runner.choice_menu.choose(Dialogue.runner.choice_menu.options.size() - 1)
		elif Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.05)
		g0 += 1
	GameState.inventory.add(ItemDB.get_item("coin"), 300)
	var shop := ShopUI.new()
	get_tree().root.add_child(shop)
	shop.call("open", "war_market")
	await _wait(0.4)
	for i in 6:
		shop.selected = 5 + i % 3
		shop._refresh()
	shop.selected = 6
	shop._refresh()
	await _wait(0.3)
	await _shot("war_shop")
	for i in shop.items().size():
		if bool(shop.items()[i].get("equip", false)):
			shop.buy(i)
	shop.close()
	await _wait(0.3)
	shop.queue_free()
	for id in ["equip_ice_hairpin", "equip_feather_anklet"]:
		GameState.inventory.add(ItemDB.get_item(id), 1)
	Equipment.equip("pink", "equip_armpit_pad")
	Equipment.equip("pink", "equip_dance_shoes")
	Equipment.equip("pink", "equip_party_bow")
	Equipment.equip("pink", "equip_training_wraps")
	Equipment.equip("blue", "equip_ice_hairpin")
	Equipment.equip("blue", "equip_chest_guard")
	var bp = get_tree().root.find_child("Backpack", true, false)
	bp.open()
	bp.set_page(bp.PAGE_EQUIP)
	bp.equip_page.who = "pink"
	bp.equip_page.slot_index = 1
	bp.equip_page.refresh()
	await _wait(0.4)
	await _shot("equip_pink")
	bp.equip_page.who = "blue"
	bp.equip_page.slot_index = 5
	bp.equip_page.refresh()
	await _wait(0.3)
	await _shot("equip_blue")
	bp.equip_page.slot_index = 7
	bp.equip_page.handle("ok")
	await _wait(0.3)
	await _shot("equip_list")
	bp.close()
	# 一段装备小剧场（蓝色公主的「裤内外夹击」）
	GameState.switch_control(_char("blue"))
	await _wait(0.3)
	CG.play_scene("eq_pants_crawl")
	var g := 0
	while CG.is_busy() and g < 400:
		if CG.step_index >= 6:
			break
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.05)
		g += 1
	await _wait(0.5)
	await _shot("equip_theater")
	get_tree().quit(0)


func _char(id: String) -> PlayableCharacter:
	for c in main.level.find_children("*", "PlayableCharacter", true, false):
		if (c as PlayableCharacter).character_id == id:
			return c
	return null


func _place(hero: Node2D, at: Vector2) -> void:
	hero.global_position = at
	if hero.get("camera"):
		hero.camera.reset_smoothing()


func _cut_until(pred: Callable, max_time := 40.0) -> void:
	var t := 0.0
	while t < max_time:
		if Cutscene.is_playing() and Cutscene.step_index >= 0 and Cutscene.step_index < Cutscene._steps.size() \
				and pred.call(Cutscene._steps[Cutscene.step_index]):
			return
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.03)
		t += 0.03
	push_warning("截图：等不到那一步")


func _until(cond: Callable, max_time := 20.0, choose := false) -> void:
	var t := 0.0
	while not cond.call() and t < max_time:
		if choose and Dialogue.runner.choice_menu.is_open():
			Dialogue.runner.choice_menu.choose(0)
		if Dialogue.is_active():
			Dialogue.advance()
			Dialogue.advance()
		await _wait(0.05)
		t += 0.05


func _finish_lines() -> void:
	var g := 0
	while Dialogue.is_active() and not Dialogue.runner.choice_menu.is_open() and g < 30:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "war_" + name + ".png"))
	print("shot ", name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

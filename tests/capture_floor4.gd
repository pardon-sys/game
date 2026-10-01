extends Node
## 第四层截图（开发用）：Godot --path . res://tests/capture_floor4.tscn → tools/.cache/shots/f4_*.png
## 各房间、HUD 疲倦条与状态图标、暴击、疲倦爆发与水液、泡泡牢笼、足枷台、水母女王的魔力雨。

const OUT := "res://tools/.cache/shots/"
const ROOMS := [
	[Vector2i(8, 45), "f4_01_landing"],
	[Vector2i(26, 44), "f4_02_jelly_pool"],
	[Vector2i(50, 44), "f4_03_bubble_waterway"],
	[Vector2i(55, 30), "f4_04_stocks_corridor"],
	[Vector2i(40, 18), "f4_05_hedgehog_lane"],
	[Vector2i(11, 19), "f4_06_totem_hall"],
	[Vector2i(32, 26), "f4_07_glove_gallery"],
	[Vector2i(17, 6), "f4_08_queen_hall"],
	[Vector2i(38, 7), "f4_09_stairs"],
]

var main: Node
var ctrl := ScriptedController.new()
var player: Princess


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for key in ReactionDB.source_keys():
		GameState.set_flag("met_" + key)
	GameState.set_flag("seen_laugh_recover")
	GameState.set_flag("seen_fatigue_burst")
	main.change_level(Floors.scene("floor_04"))
	await _wait(1.6)
	await _shot("f4_00_intro")
	_finish()
	player = GameState.player as Princess
	player.set_controller(ctrl)
	var enemies := get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	await _capture_backpack()
	for r in ROOMS:
		_place(r[0])
		await _wait(0.9)
		await _shot(r[1])
		_finish()
	# HUD：疲倦条、状态图标、暴击
	_place(Vector2i(8, 45))
	player.fatigue.set_value(420.0)
	player.add_buff("fatigue_scar", -1.0, 3)
	player.add_buff("ticklish", 8.0)
	player.add_buff("sticky", 5.0)
	var jelly := level_find("ManaJelly_22_42") as Monster
	jelly.global_position = player.global_position + Vector2(14, 0)
	jelly.add_buff("strength", 10.0)
	player.forced_specials = 1
	jelly._action_cd = 0.0
	jelly.tickle(player)
	await _wait(0.25)
	await _shot("f4_10_hud_special")
	# 疲倦爆发与水液
	player.fatigue.set_value(499.0)
	player.receive_hit(HitData.make_tickle(jelly, 4.0))
	await _wait(0.15)
	await _shot("f4_11_fatigue_burst")
	await _wait(1.2)
	await _shot("f4_12_puddle")
	# 泡泡牢笼
	player.revive()
	player.clear_buffs(false)
	var fish := level_find("BubbleFish_46_45") as BubbleFish
	_place(Vector2i(50, 46))
	fish.global_position = player.global_position + Vector2(-50, 0)
	fish.target = player
	fish.shoot_bubble()
	await _wait(0.9)
	await _shot("f4_13_bubble_cage")
	player.status.release(true)
	# 足枷台 + 羽毛臂
	_place(Vector2i(55, 31))
	await _wait(0.2)
	player.global_position.y -= 16.0
	await _wait(0.6)
	await _shot("f4_14_stocks")
	player.status.release(true)
	# 刺猬滚动
	player.revive()
	var hog := level_find("Hedgehog_47_18") as BrushHedgehog
	_place(Vector2i(44, 18))
	player.global_position.x += 40.0
	hog.global_position = player.global_position + Vector2(-70, 0)
	hog.begin_curl(Vector2.RIGHT)
	hog.process_mode = Node.PROCESS_MODE_INHERIT
	await _wait(0.75)
	await _shot("f4_15_hedgehog_roll")
	hog.process_mode = Node.PROCESS_MODE_DISABLED
	# 水母女王的魔力雨
	player.revive()
	var queen := level_find("JellyQueen_20_4") as JellyQueen
	_place(Vector2i(20, 8))
	queen.process_mode = Node.PROCESS_MODE_INHERIT
	queen.health.damage(13)
	await _wait(1.5)
	await _shot("f4_16_queen_rain")
	get_tree().quit()


## 背包两页。
func _capture_backpack() -> void:
	GameState.give_item(ItemDB.get_item("backpack"), 1, player)
	_finish()
	for id in ["mint", "clear_dew", "star_candy", "coin", "key_bronze"]:
		GameState.give_item(ItemDB.get_item(id), 2, player)
	GameState.set_hotkey("use_special", "star_candy")
	player.laugh.set_value(70.0)
	player.fatigue.set_value(330.0)
	player.add_buff("ticklish", 6.0)
	player.add_buff("fatigue_scar", -1.0, 2)
	player.add_buff("dizzy", 3.0)
	var bp: Backpack = main.get_node("Backpack")
	bp.open()
	bp.selected = 2
	bp._refresh()
	await _wait(0.2)
	await _shot("f4_17_backpack_items")
	bp.set_page(1)
	await _wait(0.2)
	await _shot("f4_18_backpack_status")
	bp.close()
	player.clear_buffs(false)
	player.laugh.clear()
	player.fatigue.clear()
	GameState.hotkeys = GameState.DEFAULT_HOTKEYS.duplicate()
	GameState.hotkeys_changed.emit()


func level_find(n: String) -> Node:
	return main.level.find_child(n, true, false)


func _place(cell: Vector2i) -> void:
	player.revive()
	player.global_position = Vector2(cell.x * 16 + 8, cell.y * 16 + 12)
	player.camera.reset_smoothing()


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + n + ".png"))
	print("shot ", n)


func _finish() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 60:
		Dialogue.advance()
		Dialogue.advance()
		guard += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

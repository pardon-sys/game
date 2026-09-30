extends Node
## Visual QA: all 11 states, synchronized world sprite / HUD / dialogue；另外 6 种魔法姿态（magic_*.png）。
const OUT := "res://tools/.cache/shots/"
var player: Princess


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	add_child(load("res://scenes/main.tscn").instantiate())
	player = get_tree().get_first_node_in_group("player") as Princess
	player.set_controller(ScriptedController.new())
	await get_tree().create_timer(1.6).timeout
	_finish_dialogue()
	GameState.set_flag("seen_laugh_recover")
	for emotion in GameState.EMOTIONS:
		await get_tree().create_timer(0.2).timeout
		player.revive()
		player.facing = Vector2.DOWN
		if emotion in ["damaged", "damaged_giggle"]:
			player.health.damage(1)
		if emotion in ["giggle", "damaged_giggle"]:
			player.laugh.set_value(65.0)
		elif emotion == "helpless_1":
			player.laugh.set_value(85.0)
		elif emotion == "helpless_2":
			player.laugh.set_value(110.0)
		player.laugh.notify_attacked()
		Dialogue.start_lines([{"speaker": "公主", "emotion": emotion, "text": "表情与状态：" + emotion}])
		Dialogue.advance()
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + emotion + ".png"))
		print("shot ", emotion)
		_finish_dialogue()
		player.laugh.notify_attacked()
		await get_tree().create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + emotion + "_world.png"))
	await _shoot_magic()
	player.revive()
	await get_tree().create_timer(0.2).timeout
	player.receive_hit(HitData.make_tickle(null, 10.0))
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "tickle_reaction.png"))
	get_tree().quit()


## 普通 / 战损 / 战损闷笑 各截一张吟唱（接近满蓄力）和释放。
func _shoot_magic() -> void:
	GameState.set_flag("magic_unlocked")
	var ctrl := player.controller as ScriptedController
	for c in [[false, 0.0], [true, 0.0], [true, 65.0]]:
		player.revive()
		player.facing = Vector2.DOWN
		await get_tree().create_timer(0.3).timeout
		player._magic_cd = 0.0
		player.battle_damaged = c[0]
		player.laugh.set_value(c[1])
		player.laugh.notify_attacked()
		ctrl.hold(&"magic", true)
		await get_tree().create_timer(1.6).timeout
		await _save("magic_" + player.emotion.current)
		ctrl.hold(&"magic", false)
		await get_tree().create_timer(0.25).timeout
		await _save("magic_" + player.emotion.current)
		await get_tree().create_timer(0.5).timeout


func _save(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + n + ".png"))
	print("shot ", n)


func _finish_dialogue() -> void:
	while Dialogue.is_active():
		Dialogue.advance()

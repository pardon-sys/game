extends Node
## Visual QA: all 11 states, synchronized world sprite / HUD / dialogue.
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
	player.revive()
	await get_tree().create_timer(0.2).timeout
	player.receive_hit(HitData.make_tickle(null, 10.0))
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "tickle_reaction.png"))
	get_tree().quit()


func _finish_dialogue() -> void:
	while Dialogue.is_active():
		Dialogue.advance()

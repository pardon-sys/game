extends Node
## 心形血量截图（开发用）：Godot --path . res://tests/capture_hearts.tscn → tools/.cache/shots/hearts_*.png
## 7 颗心满血、掉到 5.5 颗（金心一半 + 一颗金色轮廓）。

const OUT := "res://tools/.cache/shots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.5).timeout
	while Dialogue.is_active():
		Dialogue.advance()
		Dialogue.advance()
		await get_tree().process_frame
	var h := GameState.player.health
	h.max_hp = 14
	h.hp = 14
	h.changed.emit(h.hp, h.max_hp)
	await get_tree().create_timer(0.3).timeout
	await _shot("full")
	h.hp = 11
	h.changed.emit(h.hp, h.max_hp)
	await get_tree().create_timer(0.3).timeout
	await _shot("hurt")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "hearts_" + name + ".png"))
	print("shot ", name)

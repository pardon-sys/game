extends Node
## CG 图鉴截图（开发用）：Godot --path . res://tests/capture_gallery.tscn → tools/.cache/shots/gallery_boss.png
## 测试模式下打开背包的 CG 图鉴页，选中第八层 Boss 战败的小剧场。

const OUT := "res://tools/.cache/shots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DevConfig.override = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.5).timeout
	while Dialogue.is_active():
		Dialogue.advance()
		Dialogue.advance()
		await get_tree().process_frame
	var bp: Backpack = main.get_node("Backpack")
	bp.open()
	bp.set_page(Backpack.PAGE_GALLERY)
	bp.gallery_selected = bp._gallery.find(Backpack.gallery_entries().filter(func(e): return e["id"] == "f8_defeat_3_2")[0])
	bp._refresh()
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "gallery_boss.png"))
	print("shot gallery_boss")
	get_tree().quit()

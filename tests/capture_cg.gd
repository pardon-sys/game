extends Node
## 笑倒 CG 截图（开发用）：Godot --path . res://tests/capture_cg.tscn → tools/.cache/shots/cg_<id>_<步>.png
## 每段 CG 截第 2 步（第一幕）、第 4 步（第二幕：失控 2 + 镜头拉近）、第 6 步（第三幕：横版 CG 图）；可传 -- only=death_slime 只截一段。

const OUT := "res://tools/.cache/shots/"
const SHOT_STEPS := [1, 3, 5]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	for id in CG.cgs():
		if only != "" and id != only:
			continue
		var key: String = id.trim_prefix("death_")
		CG.play(id, key)
		await get_tree().process_frame
		var shot := {}
		var guard := 0
		while CG.is_playing() and guard < 400:
			guard += 1
			var i: int = CG.step_index
			if i in SHOT_STEPS and not shot.has(i):
				shot[i] = true
				await _wait(1.3)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%scg_%s_%d.png" % [OUT, id, i + 1]))
				print("shot ", id, " ", i + 1)
			if Dialogue.is_active() and not (i in SHOT_STEPS and not shot.has(i)):
				Dialogue.advance()
				Dialogue.advance()
			await _wait(0.05)
		await _wait(0.6)
	get_tree().quit()


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

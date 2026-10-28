extends "res://tests/f6_after_test.gd"
## 背景大图过场（剧情回顾）的截图：每一段 story_* 演到第三句截一张，最后截背包图鉴的「剧情回顾」。输出到 tools/.cache/shots/story_scenes/。
const OUT := "res://tools/.cache/shots/story_scenes/"


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	TutorialBoard.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1)
	_finish()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for f in ["after_started", "penance_book", "f6_opening_done", AfterFestival.FINALE_DONE]:
		GameState.set_flag(f)
	KnightStory.jump("afternoon")
	GameState.pending_spawn = "from_house"
	await main.change_level(Floors.scene(KnightStory.KDAY))
	await _advance_until(func(): return not Cutscene.is_playing() and not GameState.in_dialogue, 20.0)
	for id in Cutscene.ids():
		if not id.begins_with("story_"):
			continue
		var img := str(Cutscene.load_cutscene(id)["steps"][0]["actions"][0]["img"])
		if not StoryBackdrop.exists(img):
			continue
		Cutscene.play(id)
		await _wait(1.6)
		for i in 2:
			Dialogue.advance()
			Dialogue.advance()
			await _wait(0.6)
		await shot(id)
		while Cutscene.is_playing():
			Dialogue.advance()
			Dialogue.advance()
			await _wait(0.1)
		await _wait(0.6)
	get_tree().quit()


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + label + ".png"))
	print("SHOT ", label)

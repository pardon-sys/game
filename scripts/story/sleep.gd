class_name Sleep
extends RefCounted
## 睡觉（可复用）：淡出 → zzz → 「第 N 天」→ 天亮（剧情标记 night 关掉、vars.day + 1、回满生命 / 清空闷笑和魔力疲倦）→ 淡入 → 早上的过场。
##   Sleep.sleep(早上的过场 id)        直接睡（await 到早上的过场播完）
##   Sleep.sleep_later(早上的过场 id)  人物对话里用：等对话结束再睡（调用方不要 await）
## 第几天记在 GameState.vars["day"]（没有就算第 1 天）。

const LAYER := 45

static var sleeping := false


static func day() -> int:
	return int(GameState.vars.get("day", 1))


static func sleep_later(morning := "") -> void:
	await TrainingDB.wait_dialogue_free()
	await sleep(morning)


static func sleep(morning := "") -> void:
	if sleeping:
		return
	sleeping = true
	var tree := Engine.get_main_loop() as SceneTree
	GameState.in_dialogue = true
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	tree.root.add_child(layer)
	var black := ColorRect.new()
	black.color = Color(0.02, 0.01, 0.04, 0.0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.95, 0.9, 1.0))
	label.modulate.a = 0.0
	layer.add_child(label)
	Audio.play("chime", -10.0, 0.0, 0.7)
	var tw := black.create_tween()
	tw.tween_property(black, "color:a", 1.0, 1.2)
	await tw.finished
	# zzz……
	label.text = "Z z z ……"
	tw = label.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.0)
	tw.tween_property(label, "modulate:a", 0.0, 0.4)
	await tw.finished
	# 天亮
	GameState.vars["day"] = day() + 1
	GameState.set_flag("night", false)
	var p := GameState.player
	if is_instance_valid(p):
		if p.health:
			p.health.fill()
		if p.laugh:
			p.laugh.clear()
		if p.get("fatigue"):
			p.fatigue.clear()
	label.text = "第 %d 天" % day()
	tw = label.create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.2)
	tw.tween_property(label, "modulate:a", 0.0, 0.4)
	await tw.finished
	tw = black.create_tween()
	tw.tween_property(black, "color:a", 0.0, 1.0)
	await tw.finished
	layer.queue_free()
	GameState.in_dialogue = false
	sleeping = false
	if morning != "" and Cutscene.has_cutscene(morning):
		await Cutscene.play(morning)

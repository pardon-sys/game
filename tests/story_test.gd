extends Node
## 剧情 / 界面测试：立绘避让；第六层后续剧情（参观小镇 → 蓝色小屋 → 夜晚 → 骑马刷凳 → 钥匙 → 睡觉 → 第二天）（后面几节）。
## 用法：Godot --headless --path . res://tests/story_test.tscn   （退出码 0 = 全部通过）

var main: Node
var player: Princess
var failures := 0


func _ready() -> void:
	DevConfig.override = false
	ComboTracker.play_scenes = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	_finish()
	player = GameState.player as Princess
	player.set_controller(ScriptedController.new())
	await _run_portrait_fade()
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)


# ------------------------------------------------------------------ 立绘避让
func _run_portrait_fade() -> void:
	print("-- 立绘避让")
	await _wait(1.5)
	_finish()
	var cam: Camera2D = player.camera
	cam.position_smoothing_enabled = false
	cam.offset = Vector2.ZERO
	await _wait(1.2)
	check("公主在画面中间：立绘不透明", not Dialogue.player_behind_portrait() and Dialogue.portrait.self_modulate.a > 0.95)
	# 镜头往右上偏：公主在画面左下，正好在立绘后面
	cam.limit_left = -100000
	cam.limit_right = 100000
	cam.limit_top = -100000
	cam.limit_bottom = 100000
	var cam_base := cam.position
	cam.position = cam_base + Vector2(170, -50)
	await _wait(1.0)
	check("公主走到立绘的位置：立绘变半透明（%.2f）" % Dialogue.portrait.self_modulate.a, Dialogue.player_behind_portrait()
		and absf(Dialogue.portrait.self_modulate.a - Dialogue.PORTRAIT_FADE_ALPHA) < 0.05)
	cam.position = cam_base
	await _wait(1.0)
	check("走开后恢复不透明", Dialogue.portrait.self_modulate.a > 0.95)


# ------------------------------------------------------------------ 工具
func check(label: String, ok: bool) -> void:
	print(("  [通过] " if ok else "  [失败] ") + label)
	if not ok:
		failures += 1


func _finish() -> void:
	var g := 0
	while Dialogue.is_active() and g < 60:
		Dialogue.advance()
		Dialogue.advance()
		g += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

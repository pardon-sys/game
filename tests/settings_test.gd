extends Node
## 设置菜单（P 键）和角色画风切换：UserSettings 读写（不丢 Audio 的音量）、高清图集（*_hd.png，Sprite 缩到 1/3、平滑过滤、缺图回退像素版）、
## 菜单开关和切换、关掉常驻立绘。用法：Godot --headless --path . res://tests/settings_test.tscn

var main: Node
var failures := 0


func check(label: String, ok: bool) -> void:
	print(("  [通过] " if ok else "  [失败] ") + label)
	if not ok:
		failures += 1


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _ready() -> void:
	DevConfig.override = false
	var old_music := Audio.music_volume
	UserSettings.set_value("art_style", "hd")
	UserSettings.set_value("show_portrait", true)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(1.0)
	while Dialogue.is_active():
		Dialogue.advance()
		await _wait(0.05)
	var p := GameState.player
	var anim: SpriteSheetAnimator = p.animator
	await _wait(0.2)
	check("高清画风：粉色公主用 princess_hd.png、缩到 1/3、平滑过滤（%s）" % p.sprite.texture.resource_path,
		anim.hd and p.sprite.texture.resource_path.ends_with("princess_hd.png") and is_equal_approx(p.sprite.scale.x, 1.0 / 3.0)
		and p.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR and is_equal_approx(p.sprite.offset.y, -48.0))
	var cfg := ConfigFile.new()
	cfg.load(UserSettings.path())
	check("设置写进 settings.cfg 的 [display] 段，[audio] 音量还在", str(cfg.get_value("display", "art_style", "")) == "hd"
		and cfg.has_section_key("audio", "music_volume") == (FileAccess.file_exists(UserSettings.path()) and cfg.has_section("audio")) and is_equal_approx(Audio.music_volume, old_music))
	# 菜单：P 打开（暂停），切换画风
	var menu: SettingsMenu = main.get_node("SettingsMenu")
	menu.open()
	check("P 键菜单打开时暂停游戏、两项设置", menu.is_open() and get_tree().paused and menu.rows.size() == 2)
	menu.toggle_row(0)
	check("切换「角色画风」→ 像素", not UserSettings.hd())
	menu.close()
	check("关掉菜单恢复游戏", not menu.is_open() and not get_tree().paused)
	await _wait(0.2)
	check("像素画风：换回 princess.png、原大小（%s）" % p.sprite.texture.resource_path,
		not anim.hd and p.sprite.texture.resource_path.ends_with("princess.png") and is_equal_approx(p.sprite.scale.x, 1.0) and is_equal_approx(p.sprite.offset.y, -16.0))
	# 魔法图集也跟着换
	UserSettings.set_value("art_style", "hd")
	anim.play("channel")
	anim.update(0.05, "down", false, 0)
	check("魔法图集也换高清（%s）" % p.sprite.texture.resource_path, p.sprite.texture.resource_path.ends_with("princess_magic_hd.png") and anim.hd)
	anim.play("idle")
	# 缺高清图时回退
	check("没有 *_hd.png 的图集用原图", UserSettings.styled_path("res://assets/generated/slime.png") == "res://assets/generated/slime.png")
	# 常驻立绘
	UserSettings.set_value("show_portrait", false)
	await _wait(0.2)
	check("关掉「显示常驻立绘」：游戏中左下角的立绘不显示", Dialogue.resident_hidden() and Dialogue.portrait.self_modulate.a == 0.0)
	UserSettings.set_value("show_portrait", true)
	await _wait(0.6)
	check("打开后立绘回来", not Dialogue.resident_hidden() and Dialogue.portrait.self_modulate.a > 0.5)
	UserSettings.set_value("art_style", "hd")
	print("\n==== %s (%d 项失败) ====" % ["全部通过" if failures == 0 else "有失败", failures])
	get_tree().quit(1 if failures else 0)

extends Control
## 主界面：新游戏 / 继续（最近一次存档）/ 读取存档（3 个存档位）/ 退出。
## 存档只能在地图上的存档点存；这里只读。继续 / 读取：记下存档位（GameState.pending_load）后进入 main 场景，main 准备好后读档。

const MAIN := "res://scenes/main.tscn"

var buttons: VBoxContainer
var continue_button: Button
var load_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# 游戏里的常驻立绘 / 对话框收起来（从游戏里回到主界面时也一样）
	Dialogue.close()
	Dialogue.portrait.hide()
	Dialogue.npc_portrait.hide()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.16, 0.07, 0.17))
	grad.set_color(1, Color(0.04, 0.02, 0.05))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	# 地上的魔法阵（检查点的图）当装饰
	var circle := Sprite2D.new()
	circle.texture = preload("res://assets/generated/checkpoint.png")
	circle.hframes = 2
	circle.frame = 1
	circle.scale = Vector2(3, 3)
	circle.position = Vector2(383, 244)
	circle.modulate = Color(1, 1, 1, 0.55)
	add_child(circle)
	var pt := TextureRect.new()
	pt.texture = Dialogue.portrait_for("happy")
	pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pt.position = Vector2(318, 96)
	pt.size = Vector2(130, 173)
	add_child(pt)
	var title := Label.new()
	title.text = "公主地牢冒险"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.75, 0.88))
	title.add_theme_color_override("font_outline_color", Color(0.35, 0.08, 0.25))
	title.add_theme_constant_override("outline_size", 8)
	title.position = Vector2(150, 34)
	add_child(title)
	var sub := Label.new()
	sub.text = "—— 怕痒的公主与满地牢的机关 ——"
	sub.add_theme_color_override("font_color", Color(0.85, 0.75, 0.9))
	sub.position = Vector2(150, 78)
	add_child(sub)
	buttons = VBoxContainer.new()
	buttons.position = Vector2(190, 120)
	buttons.add_theme_constant_override("separation", 6)
	add_child(buttons)
	_button("新游戏", new_game)
	continue_button = _button("继续", continue_game)
	load_button = _button("读取存档", load_game)
	_button("退出", func(): get_tree().quit())
	var has_save := SaveSystem.latest() > 0
	continue_button.disabled = not has_save
	load_button.disabled = not has_save
	(continue_button if has_save else buttons.get_child(0) as Button).grab_focus()
	var hearts := Fx.emitter(self, "heart", 10, 3.0, {"offset": Vector2(240, 280), "extents": Vector2(240, 4), "dir": Vector2.UP,
			"speed": [10.0, 25.0], "color": Color(1, 0.7, 0.85), "z": 1})
	hearts.emitting = true


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(100, 0)
	b.pressed.connect(cb)
	buttons.add_child(b)
	return b


func new_game() -> void:
	GameState.reset()
	GameState.pending_load = 0
	get_tree().change_scene_to_file(MAIN)


func continue_game() -> void:
	var slot := SaveSystem.latest()
	if slot > 0:
		_start_from(slot)


func load_game() -> void:
	var menu := SlotMenu.new()
	add_child(menu)
	var slot: int = await menu.choose("load")
	menu.queue_free()
	if slot > 0:
		_start_from(slot)


func _start_from(slot: int) -> void:
	GameState.reset()
	GameState.pending_load = slot
	get_tree().change_scene_to_file(MAIN)

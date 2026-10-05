class_name TutorialBoard
extends CanvasLayer
## 介绍板（可复用）：屏幕中间一块带标题的说明板，内容用 ScrollTextBox（自动换行、太长可滚动），按 E / 空格 / 回车关闭。
## 显示期间游戏暂停。
##   await TutorialBoard.show_once("flag_id", "标题", ["一行", "一行", …])   只显示一次（剧情标记 flag_id）；等过场 / 对话结束才弹出
##   await TutorialBoard.show_board("标题", lines)                            直接显示
## 用在：第一次操控蓝色公主时介绍她的冰晶结界。

signal closed

## 要盖在所有淡入淡出的黑幕上面（主场景换关卡的黑幕是 50）。
const LAYER := 70
## 弹出之前要「平静」多久（没有过场 / 对话 / 换关卡 / 剧情序列 / 黑幕）。
const CALM_TIME := 1.0
const SIZE := Vector2(320, 176)

static var current: TutorialBoard
## 测试里可以关掉（不弹介绍板、不暂停）。
static var enabled := true

var title := ""
var lines: Array = []
var _box: ScrollTextBox
var _open_t := 0.0


static func show_once(flag: String, t: String, ls: Array) -> void:
	if GameState.has_flag(flag) or not enabled:
		return
	GameState.set_flag(flag)
	var tree := Engine.get_main_loop() as SceneTree
	# 等到连续 CALM_TIME 秒都「平静」才弹：换关卡、关卡开场过场之间的空隙里不能弹（会把换关卡的淡入暂停住、卡在黑屏）
	var calm := 0.0
	var waited := 0.0
	while calm < CALM_TIME and waited < 300.0:
		await tree.process_frame
		var d := tree.root.get_process_delta_time()
		waited += d
		calm = calm + d if is_calm(tree) else 0.0
	await show_board(t, ls)


## 现在能不能弹介绍板。
static func is_calm(tree: SceneTree) -> bool:
	if tree.paused or GameState.in_dialogue or Cutscene.is_playing() or CG.is_busy() or Sleep.sleeping:
		return false
	if Cutscene.curtain and Cutscene.curtain.color.a > 0.05:
		return false
	var main := tree.get_first_node_in_group("main")
	if main and main.get("_busy") == true:
		return false
	if StoryDirector.instance and StoryDirector.instance.sequence_running:
		return false
	return is_instance_valid(GameState.player)


static func show_board(t: String, ls: Array) -> void:
	var b := TutorialBoard.new()
	b.title = t
	b.lines = ls
	(Engine.get_main_loop() as SceneTree).root.add_child(b)
	await b.closed


static func is_open() -> bool:
	return is_instance_valid(current)


func _ready() -> void:
	current = self
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.16, 0.97)
	sb.border_color = Color(0.7, 0.85, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size = SIZE
	panel.position = ((vp - SIZE) / 2.0).round()
	add_child(panel)
	var head := Label.new()
	head.text = title
	head.position = Vector2(10, 6)
	head.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0))
	panel.add_child(head)
	_box = ScrollTextBox.make(Rect2(10, 26, SIZE.x - 20, SIZE.y - 46), 3)
	panel.add_child(_box)
	for l in lines:
		_box.add_line(str(l), Color(1, 0.97, 0.9))
	var hint := Label.new()
	hint.text = "[E] / [空格] 关闭"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	hint.position = Vector2(SIZE.x - 92, SIZE.y - 17)
	panel.add_child(hint)
	get_tree().paused = true
	Audio.play("book", -6.0)


func _process(delta: float) -> void:
	_open_t += delta


func _unhandled_input(event: InputEvent) -> void:
	if _open_t < 0.3:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("move_up"):
		_box.scroll_by(-1)
	elif event.is_action_pressed("move_down"):
		_box.scroll_by(1)


func close() -> void:
	if current == self:
		current = null
	get_tree().paused = false
	closed.emit()
	queue_free()

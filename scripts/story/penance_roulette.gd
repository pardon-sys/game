class_name PenanceRoulette
extends CanvasLayer
## 训练营的受罚转盘（七日赎罪）：犯了错被拉去转一次——四种刑具（DEVICES）各一格，转盘越转越慢停在一格上，
## 然后播那种刑具的小剧场（data/theater/after/after_roulette_<刑具>.json），记进赎罪簿的受罚记录。
##   await PenanceRoulette.spin(原因)          随机一格；返回刑具 id
##   PenanceRoulette.forced = "rack"           测试用：下一次固定停在这一格

const LAYER := 40
const DEVICES := [["rack", "刑床"], ["stocks", "足枷"], ["wheel", "转轮"], ["brush", "刷子凳"]]
const COLORS := [Color(0.95, 0.55, 0.7), Color(0.6, 0.8, 1.0), Color(1.0, 0.85, 0.45), Color(0.7, 0.95, 0.65)]
const R := 70.0
const CENTER := Vector2(240, 120)

static var forced := ""
## 转盘停下以后要不要播小剧场（测试可以关掉）
static var play_theater := true

var angle := 0.0
var _title := ""


static func theater_id(device: String) -> String:
	return "after_roulette_" + device


static func device_name(device: String) -> String:
	for d in DEVICES:
		if d[0] == device:
			return str(d[1])
	return device


static func spin(reason: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var was := GameState.in_dialogue
	GameState.in_dialogue = true
	var ui := PenanceRoulette.new()
	ui._title = reason
	tree.root.add_child(ui)
	var pick := forced if forced != "" else str(DEVICES[randi() % DEVICES.size()][0])
	forced = ""
	await ui._spin_to(pick)
	ui.queue_free()
	var tid := theater_id(pick)
	if play_theater and CG.has_theater(tid):
		await CG.play_theater(tid)
	PenanceBook.punish("训练营转盘：" + device_name(pick) + "（" + reason + "）", tid)
	GameState.in_dialogue = was
	return pick


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.04, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var title := Label.new()
	title.text = "训练营的受罚转盘\n" + _title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(140, 12)
	title.size = Vector2(200, 30)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	add_child(title)
	var wheel := Node2D.new()
	wheel.set_script(preload("res://scripts/story/roulette_wheel.gd"))
	wheel.name = "Wheel"
	wheel.position = CENTER
	add_child(wheel)


## 转几圈后停在 device 那一格（格子中间偏一点，看起来不那么假）。
func _spin_to(device: String) -> void:
	var idx := 0
	for i in DEVICES.size():
		if DEVICES[i][0] == device:
			idx = i
	var seg := TAU / DEVICES.size()
	# 指针在正上方（-PI/2）：让第 idx 格的中间转到指针下面
	var target := -PI / 2.0 - (idx + 0.5) * seg + randf_range(-0.3, 0.3) * seg
	var total := TAU * 4.0 + fposmod(target, TAU)
	var wheel: Node2D = get_node("Wheel")
	Audio.play("bell_jingle", -6.0)
	var tw := create_tween()
	tw.tween_method(func(a: float):
		var before := wheel.rotation
		wheel.rotation = a
		if int(before / seg) != int(a / seg):
			Audio.play("pop", -14.0, 0.1, 1.6), 0.0, total, 3.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tw.finished
	Audio.play("chime", -4.0)
	var label := Label.new()
	label.text = "——「%s」！" % device_name(device)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(140, 206)
	label.size = Vector2(200, 20)
	label.add_theme_color_override("font_color", COLORS[idx])
	add_child(label)
	await get_tree().create_timer(1.0).timeout

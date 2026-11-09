class_name ScoreView
extends CanvasLayer
## 完整的笑声乐谱：3×3 的笑声地砖图，按 PalaceAnte.TILE_SEQ 标出踩的顺序（1~6，同一块踩两次的写两个数）和箭头。
## 打开期间人物不动（dialogue_holds）；按任意键 / 点一下关掉。测试：ScoreView.current、labels()。

static var current: ScoreView

const PAPER := Color(0.97, 0.92, 0.8)
const INK := Color(0.35, 0.22, 0.15)
const GOLD := Color(0.9, 0.65, 0.2)
const CELL := 34.0

var _panel: Control
var _opened_at := 0


static func open(tree: SceneTree) -> ScoreView:
	if is_instance_valid(current):
		return current
	var v := ScoreView.new()
	tree.root.add_child(v)
	current = v
	return v


## 每块地砖上写的序号（"1"、"2·5" ……）
static func labels() -> Array:
	var out: Array = []
	for i in 9:
		var ns: Array = []
		for k in PalaceAnte.TILE_SEQ.size():
			if int(PalaceAnte.TILE_SEQ[k]) == i:
				ns.append(str(k + 1))
		out.append("·".join(ns))
	return out


func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	_opened_at = Engine.get_process_frames()
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.draw.connect(_draw_panel)
	add_child(_panel)
	GameState.dialogue_holds += 1
	GameState.in_dialogue = true
	Audio.play("book", -6.0, 0.0, 1.2)


func close() -> void:
	GameState.dialogue_holds = maxi(0, GameState.dialogue_holds - 1)
	GameState.in_dialogue = Dialogue.is_active() or GameState.in_cutscene or GameState.dialogue_holds > 0
	if current == self:
		current = null
	queue_free()


func _input(event: InputEvent) -> void:
	# 打开的那一下（按 R / 背包里点使用）不算
	if Engine.get_process_frames() - _opened_at < 2:
		return
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		get_viewport().set_input_as_handled()
		close()


func _draw_panel() -> void:
	var vp := _panel.get_viewport_rect().size
	var size := Vector2(CELL * 3 + 80, CELL * 3 + 96)
	var o := (vp - size) * 0.5
	_panel.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.45))
	_panel.draw_rect(Rect2(o, size), PAPER)
	_panel.draw_rect(Rect2(o, size), INK, false, 2.0)
	var font := ThemeDB.fallback_font
	_panel.draw_string(font, o + Vector2(0, 22), "笑声乐谱", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, INK)
	var g := o + Vector2(40, 36)
	var lab := labels()
	var centers: Array = []
	for i in 9:
		var p := g + Vector2(i % 3, i / 3) * CELL
		centers.append(p + Vector2(CELL, CELL) * 0.5)
		var used := str(lab[i]) != ""
		_panel.draw_rect(Rect2(p + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), Color(1, 0.86, 0.6) if used else Color(0.88, 0.84, 0.76))
		_panel.draw_rect(Rect2(p + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), INK, false, 1.0)
		# 每块地砖上的小笑脸
		var c: Vector2 = centers[i]
		_panel.draw_arc(c + Vector2(0, 3), 6.0, 0.3, PI - 0.3, 8, Color(INK, 0.35), 1.0)
		if used:
			_panel.draw_string(font, p + Vector2(0, CELL * 0.5 + 2), str(lab[i]), HORIZONTAL_ALIGNMENT_CENTER, CELL, 12, Color(0.75, 0.2, 0.3))
	# 顺序的箭头
	for k in PalaceAnte.TILE_SEQ.size() - 1:
		var a: Vector2 = centers[int(PalaceAnte.TILE_SEQ[k])]
		var b: Vector2 = centers[int(PalaceAnte.TILE_SEQ[k + 1])]
		var d := (b - a).normalized()
		a += d * 9.0
		b -= d * 9.0
		_panel.draw_line(a, b, Color(GOLD, 0.85), 1.5)
		_panel.draw_line(b, b - d.rotated(0.5) * 5.0, Color(GOLD, 0.85), 1.5)
		_panel.draw_line(b, b - d.rotated(-0.5) * 5.0, Color(GOLD, 0.85), 1.5)
	_panel.draw_string(font, o + Vector2(0, size.y - 22), "♪ 跟着笑声，一块一块踩 ♪", HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, INK)
	_panel.draw_string(font, o + Vector2(0, size.y - 8), "（按任意键合上）", HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, Color(INK, 0.6))

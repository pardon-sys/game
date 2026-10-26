class_name KnightBossHud
extends CanvasLayer
## 骑士 Boss 屏幕上方的耐久条（TaskKnightBoss 开场时挂上，Boss 结束跟着收走）：
##   「诅咒盔甲」：按部件分段（PHASE_PARTS：铁手套 2 / 护腿 2 / 胸甲 2 / 笑面 1），碎一块少一段；笑面那一段按灯笼亮了几盏往下掉（durability）。
##   下面一条「骑士的笑」（挠破绽涨，满了他清醒）、当前阶段的名字；最后阶段再显示四盏灯笼的进度。

const W := 220.0
const X := 130.0
const Y := 6.0

var task: TaskKnightBoss
var _bar: Bar


func _ready() -> void:
	layer = 9
	_bar = Bar.new()
	_bar.hud = self
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.position = Vector2.ZERO
	_bar.size = Vector2(480, 60)
	add_child(_bar)


func _process(_delta: float) -> void:
	visible = is_instance_valid(task) and task.started and not task.finale and not GameState.in_cutscene
	if visible:
		_bar.queue_redraw()


class Bar extends Control:
	var hud: KnightBossHud

	func _draw() -> void:
		var task := hud.task
		if not is_instance_valid(task):
			return
		var font := ThemeDB.fallback_font
		var total := 0
		for n in TaskKnightBoss.PHASE_PARTS:
			total += int(n)
		draw_rect(Rect2(X - 2, Y + 8, W + 4, 10), Color(0.08, 0.05, 0.1, 0.85))
		var left := task.durability() * total
		var x := X
		var seg_w := W / total
		for i in total:
			var fill := clampf(left - i, 0.0, 1.0)
			var col := Color(0.86, 0.5, 1.0) if i < total - 1 else Color(1.0, 0.65, 0.9)
			draw_rect(Rect2(x + 1, Y + 9, (seg_w - 2) * fill, 8), col)
			draw_rect(Rect2(x + 1, Y + 9, seg_w - 2, 8), Color(1, 1, 1, 0.25), false, 1.0)
			x += seg_w
		var name := "诅咒盔甲 · %s" % TaskKnightBoss.PHASE_NAMES[task.phase]
		draw_string(font, Vector2(X, Y + 6), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.9, 1.0))
		# 骑士的笑
		draw_rect(Rect2(X + W * 0.25, Y + 21, W * 0.5, 4), Color(0.08, 0.05, 0.1, 0.85))
		draw_rect(Rect2(X + W * 0.25, Y + 21, W * 0.5 * task.knight_laugh, 4), Color(1, 0.85, 0.4))
		draw_string(font, Vector2(X + W * 0.25 - 40, Y + 26), "骑士的笑", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.9, 0.6))
		if task.lucid_left > 0.0:
			draw_string(font, Vector2(X + W * 0.75 + 4, Y + 26), "清醒！", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.95, 0.6))
		# 最后阶段：四盏灯笼
		if not task.lanterns.is_empty():
			for i in task.lanterns.size():
				var l = task.lanterns[i]
				if not is_instance_valid(l):
					continue
				var c := Vector2(X + W * 0.5 - 30 + i * 20, Y + 36)
				draw_circle(c, 5, Color(0.25, 0.2, 0.3))
				draw_circle(c, 4, Color(1, 0.82, 0.45, 0.3 + 0.7 * (1.0 if l.lit else l.progress)))
				if l.stealing:
					draw_arc(c, 6, 0, TAU, 12, Color(0.8, 0.4, 1.0), 1.0)

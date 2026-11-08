class_name BossBar
extends Control
## HUD 顶部的 Boss 血条：GameState.boss_changed(monster) 时显示，传 null 时隐藏。
## 也能接「不是 Monster 的 Boss」（例如旧王宫的女王画像：房间脚本自己算血）：有 boss_name() / boss_ratio() 两个方法就行，标题和血量每帧读。

const BG := Color(0.12, 0.07, 0.12, 0.4)
const FILL := Color(0.9, 0.25, 0.4, 0.65)
const BORDER := Color(1, 0.84, 0.28, 0.75)

var monster: Monster
var duck: Node   # 不是 Monster 的 Boss（boss_name() / boss_ratio()）
var _label: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(0, -15)
	_label.size = Vector2(size.x, 14)
	_label.add_theme_color_override("font_color", Color(1, 0.84, 0.28))
	_label.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.19))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	GameState.boss_changed.connect(bind_monster)


func bind_monster(m: Node) -> void:
	monster = m as Monster
	duck = m if m != null and monster == null and m.has_method("boss_ratio") else null
	# 攻防战顶部已有波次 / 城墙条，Boss 血条放在下方避免叠字。
	position = Vector2(150, 54) if SiegeDirector.current else Vector2(150, 20)
	visible = monster != null or duck != null
	if duck:
		_label.text = str(duck.call("boss_name"))
	if monster:
		_label.text = monster.stats.display_name
		monster.health.changed.connect(func(_hp: int, _max: int): queue_redraw())
	queue_redraw()


func _process(_delta: float) -> void:
	if visible and duck != null:
		if not is_instance_valid(duck):
			duck = null
			visible = false
		else:
			_label.text = str(duck.call("boss_name"))
			queue_redraw()
		return
	if visible and not is_instance_valid(monster):
		visible = false


func _draw() -> void:
	if not is_instance_valid(monster) and not is_instance_valid(duck):
		return
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var r := clampf(float(duck.call("boss_ratio")) if is_instance_valid(duck) else float(monster.health.hp) / monster.health.max_hp, 0.0, 1.0)
	draw_rect(Rect2(1, 1, roundf((size.x - 2) * r), size.y - 2), FILL)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 1.0)

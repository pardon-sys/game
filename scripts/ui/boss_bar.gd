class_name BossBar
extends Control
## HUD 顶部的 Boss 血条：GameState.boss_changed(monster) 时显示，传 null 时隐藏。

const BG := Color(0.12, 0.07, 0.12, 0.9)
const FILL := Color(0.9, 0.25, 0.4)
const BORDER := Color(1, 0.84, 0.28)

var monster: Monster
var _label: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(0, -15)
	_label.size = Vector2(size.x, 14)
	_label.add_theme_color_override("font_color", BORDER)
	_label.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.19))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	GameState.boss_changed.connect(bind_monster)


func bind_monster(m: Node) -> void:
	monster = m as Monster
	visible = monster != null
	if monster:
		_label.text = monster.stats.display_name
		monster.health.changed.connect(func(_hp: int, _max: int): queue_redraw())
	queue_redraw()


func _process(_delta: float) -> void:
	if visible and not is_instance_valid(monster):
		visible = false


func _draw() -> void:
	if not is_instance_valid(monster):
		return
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var r := clampf(float(monster.health.hp) / monster.health.max_hp, 0.0, 1.0)
	draw_rect(Rect2(1, 1, roundf((size.x - 2) * r), size.y - 2), FILL)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 1.0)

class_name PartnerPanel
extends CanvasLayer
## 双人模式的搭档小面板（右上角表情头像的左边）：搭档的头像、血量、闷笑条；倒地时显示倒计时和「按住 E 救援」。
## 切换操控时自动换成另一个人（显示的总是没被操控的那个）。

const W := 72.0
const H := 40.0

var head: TextureRect
var hp_label: Label
var bar_bg: ColorRect
var bar: ColorRect
var state_label: Label
var box: Panel


func _ready() -> void:
	layer = 9
	box = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.12, 0.85)
	sb.border_color = Color(0.7, 0.75, 1.0, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	box.add_theme_stylebox_override("panel", sb)
	box.position = Vector2(get_viewport().get_visible_rect().size.x - 44.0 - W - 6.0, 4)
	box.size = Vector2(W, H)
	add_child(box)
	head = TextureRect.new()
	head.position = Vector2(3, 4)
	head.size = Vector2(32, 32)
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(head)
	hp_label = _label(Vector2(37, 2), Color(1, 0.6, 0.7))
	bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.12, 0.25)
	bar_bg.position = Vector2(37, 17)
	bar_bg.size = Vector2(31, 4)
	box.add_child(bar_bg)
	bar = ColorRect.new()
	bar.color = Color(1, 0.6, 0.85)
	bar.size = Vector2(0, 4)
	bar_bg.add_child(bar)
	state_label = _label(Vector2(37, 22), Color(1, 0.95, 0.7))


func _label(pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", col)
	box.add_child(l)
	return l


func partner() -> PlayableCharacter:
	return Duo.partner_of(GameState.player)


func _process(_delta: float) -> void:
	var p := partner()
	var cg := get_node_or_null("/root/CG")
	visible = Duo.active and p != null and not (cg != null and cg.is_playing())
	if not visible:
		return
	var emo := p.emotion.current if p.emotion else "normal"
	head.texture = Dialogue.head_for(emo, str(p.get("portrait_set")))
	if p.health:
		hp_label.text = "♥ %d/%d" % [p.health.hp, p.health.max_hp]
	if p.laugh:
		bar.size.x = roundf(31.0 * p.laugh.ratio())
		bar.color = Color(1, 0.6, 0.85) if not p.laugh.is_helpless() else Color(1, 0.3, 0.4)
	var d := p.get_node_or_null("Downed") as Downed
	if d:
		state_label.text = "倒地 %d" % ceili(d.time_left)
		state_label.add_theme_color_override("font_color", Color(1, 0.4, 0.45))
	else:
		state_label.text = "[Tab] 切换"
		state_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))

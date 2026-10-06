class_name PartnerPanel
extends CanvasLayer
## 双人模式的搭档面板（右上角表情头像的左边）：搭档的头像和名字、心形血量、闷笑条、魔力疲倦条（带百分比）、现在在做什么
## （攻击中 / 被抓住了 / 笑到失控 / 倒地 xx 秒 / 献祭中），右下角「[C]切换」。
## 切换操控时自动换成另一个人（显示的总是没被操控的那个）。

const W := 132.0
const H := 60.0
const BAR_W := 56.0

var head: TextureRect
var name_label: Label
var hearts: HBoxContainer
var laugh_bar: ColorRect
var laugh_pct: Label
var fatigue_bar: ColorRect
var fatigue_pct: Label
var state_label: Label
var box: Panel


func _ready() -> void:
	layer = 9
	box = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.12, 0.88)
	sb.border_color = Color(0.7, 0.75, 1.0, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	box.add_theme_stylebox_override("panel", sb)
	box.position = Vector2(get_viewport().get_visible_rect().size.x - 44.0 - W - 6.0, 4)
	box.size = Vector2(W, H)
	add_child(box)
	head = TextureRect.new()
	head.position = Vector2(3, 3)
	head.size = Vector2(44, 44)
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(head)
	name_label = _label(Vector2(4, 46), Color(0.85, 0.9, 1.0))
	hearts = HBoxContainer.new()
	hearts.position = Vector2(50, 3)
	hearts.add_theme_constant_override("separation", 0)
	box.add_child(hearts)
	laugh_bar = _bar(Vector2(50, 17), Color(1, 0.6, 0.85))
	laugh_pct = _label(Vector2(50 + BAR_W + 3, 12), Color(1, 0.75, 0.9))
	fatigue_bar = _bar(Vector2(50, 26), Color(0.65, 0.55, 1.0))
	fatigue_pct = _label(Vector2(50 + BAR_W + 3, 21), Color(0.8, 0.75, 1.0))
	state_label = _label(Vector2(50, 33), Color(1, 0.95, 0.7))
	var key := _label(Vector2(W - 38, 46), Color(1, 0.9, 0.6))
	key.text = "[C]切换"


func _label(pos: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.1))
	l.add_theme_constant_override("outline_size", 2)
	box.add_child(l)
	return l


func _bar(pos: Vector2, col: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.12, 0.25)
	bg.position = pos
	bg.size = Vector2(BAR_W, 5)
	box.add_child(bg)
	var fg := ColorRect.new()
	fg.color = col
	fg.size = Vector2(0, 5)
	bg.add_child(fg)
	return fg


func partner() -> PlayableCharacter:
	return Duo.partner_of(GameState.player)


## 搭档现在在做什么（面板上那一行）。
static func activity(p: PlayableCharacter) -> String:
	var d := p.get_node_or_null("Downed") as Downed
	if d:
		return "倒地 %d 秒" % ceili(d.time_left)
	if p.get_node_or_null("SacrificeStruggle"):
		return "献祭中！"
	if p.status and p.status.is_grabbed():
		return "被抓住了"
	if p.laugh and p.laugh.is_helpless():
		return "笑到失控"
	match p.state:
		PlayableCharacter.State.ATTACK: return "攻击中"
		PlayableCharacter.State.CHANNEL: return "吟唱中"
		PlayableCharacter.State.DASH: return "闪避"
	var ai := p.controller as CompanionController
	if ai:
		return {"revive": "去救你", "plate": "去站板子", "dodge": "躲开", "attack": "攻击中", "struggle": "挣扎",
			"magic": "吟唱中"}.get(ai.intent, "跟着你")
	return ""


func _process(_delta: float) -> void:
	var p := partner()
	var cg := get_node_or_null("/root/CG")
	visible = Duo.active and p != null and not (cg != null and cg.is_playing())
	if not visible:
		return
	var emo := p.emotion.current if p.emotion else "normal"
	head.texture = Dialogue.head_for(emo, str(p.get("portrait_set")))
	name_label.text = p.display_name()
	if p.health:
		HeartRow.update(hearts, p.health.hp, p.health.max_hp, 10.0)
	if p.laugh:
		laugh_bar.size.x = roundf(BAR_W * p.laugh.ratio())
		laugh_bar.color = Color(1, 0.6, 0.85) if not p.laugh.is_helpless() else Color(1, 0.3, 0.4)
		laugh_pct.text = "%d%%" % roundi(p.laugh.percent())
	var f: MagicFatigue = p.get("fatigue")
	if f:
		var r := f.value / maxf(f.max_value, 1.0)
		fatigue_bar.size.x = roundf(BAR_W * clampf(r, 0.0, 1.0))
		fatigue_pct.text = "%d%%" % roundi(100.0 * r)
	state_label.text = activity(p)
	var bad := Downed.is_downed(p) or p.get_node_or_null("SacrificeStruggle") != null
	state_label.add_theme_color_override("font_color", Color(1, 0.4, 0.45) if bad else Color(1, 0.95, 0.7))

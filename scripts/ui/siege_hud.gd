class_name SiegeHud
extends CanvasLayer
## 攻防战的 HUD（SiegeDirector 创建）：
##   顶部中间：第 N / 10 波 + 状态（准备倒计时 / 战斗中还剩几只）、城墙血条（分 8 段，每段按挨打程度变色）、冰晶数。
##   右上（立绘框下面）：小地图——城墙、冰塔格、两位公主、怪物点、敌塔。
##   屏幕边缘：大型攻城怪（meta siege_alert）在屏幕外时的红色箭头。
##   小地图下面：这一波的特色机制标签（图标 + 名字，鼠标停上去看说明；WaveFeatures）。
##   底部：蓝色公主的 4 个城墙法术格（键位 1~4、名字、冷却遮罩；正在瞄准的那个金框）。

const BAR := Rect2(250, 16, 130, 6)
const MAP := Rect2(386, 44, 90, 66)
const RED := Color(1, 0.35, 0.4)
const GOLD := Color(1, 0.86, 0.4)
const ICE := Color(0.7, 0.92, 1.0)

var director: SiegeDirector
var view: Control
var _font: Font
## 特色标签（tags 是现在显示的 id，测试用）
var tag_box: VBoxContainer
var tags: Array[String] = []


func _ready() -> void:
	layer = 4
	view = Control.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_view)
	add_child(view)
	_font = view.get_theme_default_font()
	tag_box = VBoxContainer.new()
	tag_box.position = Vector2(MAP.position.x, MAP.end.y + 4.0)
	tag_box.add_theme_constant_override("separation", 1)
	add_child(tag_box)


func _process(_delta: float) -> void:
	visible = not CG.is_busy() and not GameState.in_cutscene
	view.queue_redraw()
	var now: Array[String] = []
	if director and director.features and director.state == "fight":
		now = director.features.active.duplicate()
	if now != tags:
		_build_tags(now)


func _build_tags(ids: Array[String]) -> void:
	tags = ids
	for c in tag_box.get_children():
		c.queue_free()
	for id in ids:
		var inf := WaveFeatures.info(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = "%s\n%s" % [inf.get("name", id), inf.get("desc", "")]
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.08, 0.05, 0.1, 0.75)
		bg.set_corner_radius_all(2)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", bg)
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.tooltip_text = row.tooltip_text
		var icon := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = WaveFeatures.TEX
		at.region = WaveFeatures.icon_rect(id)
		icon.texture = at
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		var l := Label.new()
		l.text = str(inf.get("name", id))
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", Color(str(inf.get("color", "#ffffff"))))
		l.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.1))
		l.add_theme_constant_override("outline_size", 3)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(icon)
		row.add_child(l)
		panel.add_child(row)
		tag_box.add_child(panel)


func status_text() -> String:
	if director == null:
		return ""
	match director.state:
		"prep": return "第 %d/%d 波 · 准备 %d 秒" % [director.wave, SiegeDirector.total_waves(), ceili(director.prep_left)]
		"fight":
			if director.next_left >= 0.0:
				return "第 %d/%d 波 · 场上 %d 只 · 下一波 %d 秒" % [director.wave, SiegeDirector.total_waves(), director.remaining(), ceili(director.next_left)]
			return "第 %d/%d 波 · 还剩 %d 只" % [director.wave, SiegeDirector.total_waves(), director.remaining()]
		"failed": return "城墙被攻破了……"
		"won": return "小镇守住了！"
	return ""


func _text(pos: Vector2, s: String, col: Color, fs := 9, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	view.draw_string_outline(_font, pos, s, align, w, fs, 3, Color(0.08, 0.04, 0.1))
	view.draw_string(_font, pos, s, align, w, fs, col)


func _draw_view() -> void:
	if director == null:
		return
	_text(Vector2(BAR.position.x - 30, 11), status_text(), GOLD, 9, HORIZONTAL_ALIGNMENT_CENTER, BAR.size.x + 60)
	# 城墙血条：8 段
	view.draw_rect(BAR.grow(1), Color(0.1, 0.05, 0.12, 0.85))
	var frac := director.wall_hp / maxf(director.wall_max, 1.0)
	view.draw_rect(Rect2(BAR.position, Vector2(BAR.size.x * frac, BAR.size.y)),
		Color(0.55, 0.85, 1.0) if frac > 0.5 else (Color(1, 0.8, 0.4) if frac > 0.25 else RED))
	var n := director.walls.size()
	for i in n:
		var w := director.walls[i]
		var x := BAR.position.x + BAR.size.x * float(i) / n
		if i > 0:
			view.draw_line(Vector2(x, BAR.position.y), Vector2(x, BAR.end.y), Color(0.1, 0.05, 0.12), 1.0)
		var lvl := w.damage_level()
		if lvl > 0:
			view.draw_rect(Rect2(x + 1, BAR.end.y + 1, BAR.size.x / n - 2, 2), Color(1, 0.75, 0.3) if lvl == 1 else RED)
		if w.shield_left > 0.0:
			view.draw_rect(Rect2(x + 1, BAR.position.y - 3, BAR.size.x / n - 2, 2), ICE)
	_text(Vector2(BAR.position.x, BAR.end.y + 10), "城墙 %d / %d" % [int(director.wall_hp), int(director.wall_max)], Color(0.9, 0.9, 1.0), 8)
	# 冰晶
	var cr := SiegeArt.region("crystal")
	view.draw_texture_rect_region(SiegeArt.TEX, Rect2(BAR.end + Vector2(8, -8), cr.size), cr)
	_text(BAR.end + Vector2(18, 1), "×%d" % director.crystals, ICE, 9)
	_draw_map()
	_draw_alerts()
	_draw_spells()


const SPELL_COLORS := {"ice_rain": Color(0.6, 0.85, 1.0), "barrier": Color(0.75, 0.9, 1.0), "snow": Color(0.9, 0.97, 1.0),
	"reinforce": Color(0.55, 0.75, 0.95), "blizzard": Color(0.85, 0.95, 1.0), "spike": Color(0.5, 0.8, 1.0),
	"mirror": Color(0.75, 0.85, 1.0)}


func _draw_spells() -> void:
	var b: PlayableCharacter = director.blue
	if b == null or not is_instance_valid(b):
		return
	var n := SiegeSpells.ORDER.size()
	var w := 34.0
	var x0 := 240.0 - n * (w + 4.0) / 2.0
	var y := 250.0
	for i in n:
		var id: String = SiegeSpells.ORDER[i]
		var r := Rect2(x0 + i * (w + 4.0), y, w, 14)
		view.draw_rect(r, Color(0.1, 0.06, 0.14, 0.85))
		var info: Dictionary = SiegeSpells.INFO[id]
		var cd := SiegeSpells.cooldown_left(b, id)
		if cd > 0.0:
			view.draw_rect(Rect2(r.position, Vector2(r.size.x * cd / float(info["cd"]), r.size.y)), Color(0.3, 0.3, 0.4, 0.8))
		var aiming: bool = director.aim and director.aim.active and director.aim.spell == id
		view.draw_rect(r, GOLD if aiming else SPELL_COLORS.get(id, ICE), false, 1.0)
		_text(r.position + Vector2(2, 10), "%d %s" % [i + 1, SiegeSpells.spell_name(id).left(2)], SPELL_COLORS.get(id, ICE) if cd <= 0.0 else Color(0.6, 0.6, 0.7), 8)


func world_size() -> Vector2:
	return director.map_size()


func to_map(p: Vector2) -> Vector2:
	var ws := world_size()
	return MAP.position + Vector2(p.x / ws.x * MAP.size.x, p.y / ws.y * MAP.size.y)


func _draw_map() -> void:
	view.draw_rect(MAP.grow(1), Color(0.55, 0.4, 0.6, 0.9), false, 1.0)
	view.draw_rect(MAP, Color(0.08, 0.05, 0.1, 0.75))
	if not director.walls.is_empty():
		var y := to_map(Vector2(0, director.wall_foot_y())).y
		for w in director.walls:
			var a := to_map(Vector2(w.left_x(), 0)).x
			var b := to_map(Vector2(w.right_x(), 0)).x
			var lvl := w.damage_level()
			view.draw_line(Vector2(a, y), Vector2(b, y), [Color(0.8, 0.78, 0.85), Color(1, 0.75, 0.3), RED][lvl], 2.0)
	for t in get_tree().get_nodes_in_group("siege_pad"):
		view.draw_rect(Rect2(to_map((t as Node2D).global_position) - Vector2(1, 1), Vector2(2, 2)), ICE if t.get("tower") else Color(0.4, 0.55, 0.7))
	for t in get_tree().get_nodes_in_group("siege_enemy_tower"):
		view.draw_rect(Rect2(to_map((t as Node2D).global_position) - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.85, 0.35, 0.9))
	for m in director.monsters:
		if is_instance_valid(m):
			view.draw_rect(Rect2(to_map(m.global_position), Vector2(1, 1)), RED)
	# 正在搭的敌塔地基：闪紫圈
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	for s in get_tree().get_nodes_in_group("siege_enemy_site"):
		if s.has_method("is_building") and s.call("is_building"):
			view.draw_arc(to_map((s as Node2D).global_position), 3.5, 0.0, TAU, 12, Color(0.9, 0.4, 1.0, blink), 1.0)
	for c in [director.pink, director.blue]:
		if c and is_instance_valid(c):
			view.draw_circle(to_map(c.global_position), 2.0, Color(1, 0.6, 0.85) if c.character_id == "pink" else Color(0.6, 0.8, 1.0))
	var cam := view.get_viewport().get_camera_2d()
	if cam:
		var half := view.get_viewport_rect().size / cam.zoom / 2.0
		var c := cam.get_screen_center_position()
		var r := Rect2(to_map(c - half), to_map(c + half) - to_map(c - half))
		view.draw_rect(r, Color(1, 1, 1, 0.5), false, 1.0)


func _draw_alerts() -> void:
	var cam := view.get_viewport().get_camera_2d()
	if cam == null:
		return
	var vs := view.get_viewport_rect().size
	var c := cam.get_screen_center_position()
	for m in director.monsters:
		if not is_instance_valid(m) or not m.get_meta("siege_alert", false) or director.on_screen(m.global_position, 0.0):
			continue
		var d := (m.global_position - c) * cam.zoom
		var edge := vs / 2.0 + d.limit_length(minf(vs.x, vs.y) * 0.45)
		edge.x = clampf(edge.x, 12.0, vs.x - 12.0)
		edge.y = clampf(edge.y, 30.0, vs.y - 12.0)
		var ang := d.angle()
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
		var pts := PackedVector2Array([edge + Vector2.from_angle(ang) * 7.0, edge + Vector2.from_angle(ang + 2.5) * 6.0,
			edge + Vector2.from_angle(ang - 2.5) * 6.0])
		view.draw_colored_polygon(pts, Color(RED.r, RED.g, RED.b, pulse))

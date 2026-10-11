class_name EquipPage
extends Control
## 背包的「装备」页（装备系统解锁后才出现；Equipment）。
##   左边：当前这个人的立绘（换装人形），8 个部位格用细线连到身上对应的位置；诅咒的格子挂着紫色锁链。
##   右边：上半是选中部位上的装备（图标、名字、说明）或可换的装备列表（ScrollTextBox，选中项自动滚进来）；
##         下半（DETAIL_Y 起，合计行上面）是好处绿 / 代价红，不挡列表。按 E 打开列表，再按 E 穿上 / 脱下。
##   连线连到立绘身上对应的位置（BODY_AT：按装备页立绘量出来的比例位置，左边的格子连身体左侧，右边的连右侧）。
##   底部：这个人穿着的装备的好处 / 代价合计。
##   ← / → 切换粉色公主 / 蓝色公主（两个人的装备不互通）。
## 操作交给 handle(动作)（背包的 _input 转过来）：up / down / left / right / ok / back。

const SLOT_ICONS := preload("res://assets/generated/equip_slot.png")
const ZONES := ["neck", "armpit", "chest", "waist", "belly", "thigh", "butt", "sole"]
## 部位格在左半边的位置（相对本页）和连到立绘上的点（立绘框里的比例位置）
const SLOT_POS := {
	"neck": Vector2(2, 22), "armpit": Vector2(2, 52), "chest": Vector2(2, 82), "waist": Vector2(2, 112),
	"belly": Vector2(150, 52), "thigh": Vector2(150, 82), "butt": Vector2(150, 112), "sole": Vector2(150, 142),
}
## 立绘框里的比例位置（两位公主的立绘是同样的站姿）：下巴下面是脖子，胸前蝴蝶结，腰线在裙子收腰处
const BODY_AT := {
	"neck": Vector2(0.5, 0.47), "armpit": Vector2(0.3, 0.53), "chest": Vector2(0.45, 0.55), "waist": Vector2(0.38, 0.63),
	"belly": Vector2(0.55, 0.65), "thigh": Vector2(0.55, 0.8), "butt": Vector2(0.66, 0.73), "sole": Vector2(0.55, 0.95),
}
const PORTRAIT_RECT := Rect2(30, 18, 112, 150)
const RIGHT_X := 182.0
## 右栏下半：好处 / 代价从这里开始（合计行在 174）
const DETAIL_Y := 122.0
const LIST_RECT := Rect2(182, 16, 212, 100)
const PINK := Color(1, 0.72, 0.86)
const GOLD := Color(1, 0.86, 0.4)
const TEXT := Color(0.95, 0.92, 0.98)
const DIM := Color(0.7, 0.62, 0.78)
const GOOD := Color(0.6, 1.0, 0.7)
const BAD := Color(1.0, 0.55, 0.6)
const CURSE := Color(0.8, 0.5, 1.0)

var who := "pink"
var slot_index := 0
## "slots" 选部位 / "list" 选装备
var mode := "slots"
var list_index := 0
var _font: Font
## 可换装备列表（list 模式时显示）
var list_box: ScrollTextBox


func _ready() -> void:
	size = Vector2(396, 192)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	list_box = ScrollTextBox.make(Rect2(LIST_RECT.position + Vector2(0, 14), LIST_RECT.size - Vector2(0, 14)), 1, 10)
	list_box.hide()
	add_child(list_box)


## 部位格连到立绘上的点（立绘框里的比例位置）。
func body_at(z: String) -> Vector2:
	return BODY_AT.get(z, Vector2(0.5, 0.5))


func zone() -> String:
	return ZONES[slot_index]


## 列表：这个部位能换的装备（拥有的、这个人能穿的）+ 最后一项「脱下」。
func choices() -> Array:
	var out := []
	for item in GameState.inventory.items():
		var it := item as EquipData
		if it and zone() in it.slots and it.can_wear(who) and not it.cursed:
			out.append(it.id)
	out.append("")
	return out


func refresh() -> void:
	queue_redraw()
	_refresh_list()


func _refresh_list() -> void:
	list_box.visible = mode == "list" and visible
	if mode != "list":
		return
	list_box.clear()
	var ch := choices()
	var chosen: Control = null
	for i in ch.size():
		var id := str(ch[i])
		var it := ItemDB.get_item(id) as EquipData if id != "" else null
		var sel := i == list_index
		var mark := ""
		if it:
			var why := Equipment.why_not(who, id)
			if Equipment.worn(who).values().has(id):
				mark = "　穿着"
			elif why != "":
				mark = "　" + why
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(12, 12)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = it.icon if it else null
		var row := list_box.add_row(icon, ("▶ " if sel else "") + (it.display_name if it else "（脱下）") + mark, GOLD if sel else TEXT)
		if sel:
			chosen = row
	if chosen:
		list_box.ensure_control_visible.call_deferred(chosen)


## 背包转过来的操作。返回处理了没有。
func handle(action: String) -> bool:
	if mode == "slots":
		match action:
			"up": slot_index = posmod(slot_index - 1, ZONES.size())
			"down": slot_index = posmod(slot_index + 1, ZONES.size())
			"left", "right":
				who = "blue" if who == "pink" else "pink"
				Audio.play("book", -10.0, 0.05, 1.3)
			"ok":
				var cur := Equipment.item_at(who, zone())
				if cur and cur.cursed:
					GameState.notify("%s脱不下来……" % cur.display_name)
					Audio.play("locked", -6.0)
				else:
					mode = "list"
					list_index = 0
			_: return false
	else:
		var ch := choices()
		match action:
			"up": list_index = posmod(list_index - 1, ch.size())
			"down": list_index = posmod(list_index + 1, ch.size())
			"back", "left": mode = "slots"
			"ok":
				var id := str(ch[list_index])
				if id == "":
					if Equipment.unequip(who, zone()):
						Audio.play("cloth", -6.0)
				else:
					var why := Equipment.why_not(who, id)
					if why != "":
						GameState.notify(why)
						Audio.play("locked", -6.0)
					elif Equipment.equip(who, id):
						Audio.play("pickup", -4.0)
				mode = "slots"
			_: return false
	refresh()
	return true


func hint() -> String:
	if mode == "list":
		return "↑↓ 选装备　E 换上 / 脱下　← 返回　Tab 下一页　~ 上一页"
	return "↑↓ 选部位　E 换装备　←→ 切换人物　Tab 下一页　~ 上一页"


func _name_of(w: String) -> String:
	return "蓝色的公主" if w == "blue" else "公主"


func _draw() -> void:
	# 顶部：◀ 谁 ▶
	_text(Vector2(2, 10), "◀ %s ▶" % _name_of(who), GOLD)
	# 立绘
	var set_name := "blue" if who == "blue" else "pink"
	var tex: Texture2D = Dialogue.portrait_for("normal", set_name)
	draw_rect(PORTRAIT_RECT.grow(2), Color(0.2, 0.11, 0.24, 0.9))
	if tex:
		draw_texture_rect(tex, PORTRAIT_RECT, false)
	draw_rect(PORTRAIT_RECT.grow(2), Color(0.55, 0.35, 0.6), false, 1.0)
	# 部位格 + 连线
	var w := Equipment.worn(who)
	for i in ZONES.size():
		var z: String = ZONES[i]
		var at: Vector2 = SLOT_POS[z]
		var body: Vector2 = PORTRAIT_RECT.position + PORTRAIT_RECT.size * body_at(z)
		var sel := i == slot_index
		var edge := at + Vector2(20, 10) if at.x < 100 else at + Vector2(0, 10)
		draw_line(edge, body, Color(1, 0.86, 0.4, 0.9) if sel else Color(0.7, 0.5, 0.8, 0.5), 1.0)
		draw_circle(body, 1.5, GOLD if sel else Color(0.8, 0.6, 0.9))
		var it := Equipment.item_at(who, z)
		var cursed := it != null and it.cursed
		draw_texture_rect_region(SLOT_ICONS, Rect2(at, Vector2(20, 20)), Rect2(20 if cursed else 0, 0, 20, 20))
		if it and it.icon:
			draw_texture_rect(it.icon, Rect2(at + Vector2(2, 2), Vector2(16, 16)), false)
		draw_rect(Rect2(at - Vector2(1, 1), Vector2(22, 22)), GOLD if sel else Color(0.45, 0.3, 0.5), false, 2.0 if sel else 1.0)
		var label_x := at.x + 23.0 if at.x < 100 else at.x - 25.0
		_text(Vector2(label_x, at.y + 14), TickleZones.zone_name(z), GOLD if sel else DIM, 9)
	# 右边：选中部位
	var x := RIGHT_X
	var cur := Equipment.item_at(who, zone())
	_text(Vector2(x, 10), "【%s】" % TickleZones.zone_name(zone()), PINK)
	draw_line(Vector2(x, DETAIL_Y - 6), Vector2(x + 210, DETAIL_Y - 6), Color(0.45, 0.3, 0.5, 0.8), 1.0)
	var detail: EquipData = cur
	if mode == "list":
		var ch := choices()
		var pick := str(ch[clampi(list_index, 0, ch.size() - 1)])
		detail = ItemDB.get_item(pick) as EquipData if pick != "" else null
		if detail == null:
			_text(Vector2(x, DETAIL_Y + 8), "脱下这个部位的装备", DIM, 10)
	elif cur:
		if cur.icon:
			draw_texture_rect(cur.icon, Rect2(Vector2(x, 18), Vector2(24, 24)), false)
		var forced := Equipment.is_forced(who, cur.id)
		var tag := "　（诅咒）" if cur.cursed else ("　（被强制穿上 %d 秒）" % ceili(Equipment.forced_left(who, cur.id)) if forced else "")
		_text(Vector2(x + 28, 34), _fit(cur.display_name + tag, 11, 182.0), CURSE if cur.cursed or forced else GOLD)
		var y := _wrap(Vector2(x, 56), cur.description, DIM, 9, 210.0, 4)
		for z in cur.block:
			_text(Vector2(x, y + 10), "还能挡 %d 次（休息时恢复）" % Equipment.charges(who, z), PINK, 9)
	else:
		_text(Vector2(x, 36), "（空着）", DIM)
		_text(Vector2(x, 56), "按 E 从背包里挑一件换上", DIM, 10)
	if detail:
		var y2 := _wrap(Vector2(x, DETAIL_Y + 6), "好处：" + detail.pros, GOOD, 9, 210.0, 2)
		_wrap(Vector2(x, y2 + 1), "代价：" + detail.cons, BAD, 9, 210.0, 2)
	# 底部合计
	var sm := Equipment.summary(who)
	_text(Vector2(2, 174), _fit("合计　好处：" + (sm[0] if sm[0] != "" else "—"), 9, 392.0), GOOD, 9)
	_text(Vector2(2, 186), _fit("　　　代价：" + (sm[1] if sm[1] != "" else "—"), 9, 392.0), BAD, 9)


func _text(pos: Vector2, s: String, col: Color, fs := 11) -> void:
	draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, Color(0.08, 0.04, 0.1))
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## 按实际宽度换行（最多 lines 行，放不下的最后一行加「…」）。返回下一行的 y。
func _wrap(pos: Vector2, s: String, col: Color, fs: int, width: float, lines: int) -> float:
	var rows := _split_rows(s, fs, width)
	if rows.size() > lines:
		rows = rows.slice(0, lines)
		rows[-1] = _fit(rows[-1] + "……", fs, width)
	for n in rows.size():
		_text(pos + Vector2(0, n * (fs + 3)), rows[n], col, fs)
	return pos.y + rows.size() * (fs + 3)


func _split_rows(s: String, fs: int, width: float) -> Array[String]:
	var rows: Array[String] = []
	var cur := ""
	for ch in s:
		if _font.get_string_size(cur + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and cur != "":
			rows.append(cur)
			cur = ""
		cur += ch
	if cur != "":
		rows.append(cur)
	return rows


## 一行放不下就截短加「…」。
func _fit(s: String, fs: int, width: float) -> String:
	if _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width:
		return s
	var out := s
	while out.length() > 1 and _font.get_string_size(out + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		out = out.substr(0, out.length() - 1)
	return out + "…"

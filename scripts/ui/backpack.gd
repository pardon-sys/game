class_name Backpack
extends CanvasLayer
## 背包界面（场景 scenes/ui/backpack.tscn，挂在 main 下）。拿到冒险背包（GameState.has_backpack）之后按 Tab / I 打开，打开时暂停游戏。
##   物品页：所有物品的格子；选中显示名称、数量、说明；E 使用，Q / R 把消耗品设为对应快捷键（GameState.set_hotkey）。
##   状态页：闷笑值 / 魔力疲倦百分比和当前阶段说明、魔法冷却、所有增益 / 减益（data/buffs.json 的 desc）、被抓 / 定身等情况。
##   CG 图鉴页：笑倒 CG、巢穴过场、三来源组合演出；看过的可以重看（测试模式下全部可看），E 播放。
## 操作：方向键选择，E 使用 / 播放，Q / R 设快捷键，Tab / I 翻到下一页（最后一页再按就关闭），Esc 关闭。
## 测试模式（DevConfig.enabled）下没拿到背包也能打开。

signal opened
signal closed

const BUFF_ICONS := preload("res://assets/generated/buff_icons.png")
const PAGES := ["物品", "被动技能", "状态", "CG 图鉴"]
const PAGE_ITEMS := 0
const PAGE_PASSIVES := 1
const PAGE_STATUS := 2
const PAGE_GALLERY := 3
## CG 图鉴一屏显示的行数。
const GALLERY_ROWS := 9
const COLUMNS := 8
const CATEGORY_NAMES := {
	ItemData.Category.CONSUMABLE: "消耗品", ItemData.Category.KEY: "钥匙",
	ItemData.Category.CURRENCY: "货币", ItemData.Category.INSTANT: "其它",
}
const PINK := Color(1, 0.72, 0.86)
const GOLD := Color(1, 0.86, 0.4)
const TEXT := Color(0.95, 0.92, 0.98)
const DIM := Color(0.7, 0.62, 0.78)

var page := 0
var selected := 0
var _items: Array[ItemData] = []
var _paused_by_me := false

var root: Control
var tabs_label: Label
var items_page: Control
var grid: GridContainer
var detail_name: Label
var detail_desc: Label
var hotkey_label: Label
var status_page: VBoxContainer
var passives_page: Control
var passive_grid: GridContainer
var passive_name: Label
var passive_desc: Label
var passive_selected := 0
var _passive_ids: Array = []
var hint_label: Label
var gallery_page: VBoxContainer
var gallery_selected := 0
## 图鉴条目：{kind: "cg" / "scene", id（播放用）, flag（看过的标记）, group（分类）, name}
var _gallery: Array[Dictionary] = []


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	root.hide()
	GameState.hotkeys_changed.connect(func(): if is_open(): _refresh())
	GameState.passive_changed.connect(func(_id: String, _lv: int): if is_open(): _refresh())


func is_open() -> bool:
	return root.visible


func open() -> void:
	if is_open():
		return
	page = 0
	selected = 0
	_paused_by_me = not get_tree().paused
	get_tree().paused = true
	Audio.stop_voice()
	root.show()
	_refresh()
	Audio.play("book", -6.0)
	opened.emit()


func close() -> void:
	if not is_open():
		return
	root.hide()
	if _paused_by_me:
		get_tree().paused = false
	_paused_by_me = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open() or not event.is_action_pressed("backpack"):
		return
	get_viewport().set_input_as_handled()
	if get_tree().paused or GameState.in_dialogue or not is_instance_valid(GameState.player) or not GameState.player.is_alive():
		return
	if not GameState.has_backpack() and not DevConfig.enabled():
		GameState.notify("还没有背包……")
		return
	open()


func _input(event: InputEvent) -> void:
	if not is_open() or not event.is_pressed() or event.is_echo():
		return
	var handled := true
	if event.is_action("pause") or event.is_action("ui_cancel"):
		close()
	elif event.is_action("backpack"):
		if page + 1 < PAGES.size():
			set_page(page + 1)
		else:
			close()
	elif event.is_action("move_left") or event.is_action("ui_left"):
		move_selection(-1)
	elif event.is_action("move_right") or event.is_action("ui_right"):
		move_selection(1)
	elif event.is_action("move_up") or event.is_action("ui_up"):
		move_selection(-COLUMNS)
	elif event.is_action("move_down") or event.is_action("ui_down"):
		move_selection(COLUMNS)
	elif event.is_action("interact") or event.is_action("ui_accept"):
		use_selected()
	elif event.is_action("use_item"):
		assign_selected("use_item")
	elif event.is_action("use_special"):
		assign_selected("use_special")
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func set_page(p: int) -> void:
	page = clampi(p, 0, PAGES.size() - 1)
	_refresh()


func move_selection(d: int) -> void:
	if page == PAGE_GALLERY:
		if not _gallery.is_empty():
			# 左右（±1）翻一页，上下（±COLUMNS）走一行
			var step := (1 if d > 0 else -1) * (GALLERY_ROWS if absi(d) == 1 else 1)
			gallery_selected = clampi(gallery_selected + step, 0, _gallery.size() - 1)
			_refresh()
		return
	if page == PAGE_PASSIVES:
		if not _passive_ids.is_empty():
			passive_selected = clampi(passive_selected + d, 0, _passive_ids.size() - 1)
			_refresh()
		return
	if page != PAGE_ITEMS or _items.is_empty():
		return
	selected = clampi(selected + d, 0, _items.size() - 1)
	_refresh()


func selected_item() -> ItemData:
	return _items[selected] if page == PAGE_ITEMS and selected < _items.size() else null


## 使用选中的物品（消耗品）；图鉴页播放选中的 CG。
func use_selected() -> bool:
	if page == PAGE_GALLERY:
		return play_selected()
	var it := selected_item()
	var p := GameState.player
	if it == null or not is_instance_valid(p):
		return false
	if it.category != ItemData.Category.CONSUMABLE:
		GameState.notify("%s不能直接使用。" % it.display_name)
		return false
	var ok := GameState.inventory.use(it.id, p)
	if not ok:
		GameState.notify("现在用不了%s。" % it.display_name)
	_refresh()
	return ok


## 把选中的消耗品设为 Q（use_item）或 R（use_special）。
func assign_selected(hotkey: String) -> bool:
	var it := selected_item()
	if it == null or it.category != ItemData.Category.CONSUMABLE:
		return false
	GameState.set_hotkey(hotkey, it.id)
	Audio.play("pickup", -6.0)
	_refresh()
	return true


# ------------------------------------------------------------------ 界面
func _build() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.16, 0.97)
	sb.border_color = PINK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(30, 14)
	panel.size = Vector2(420, 242)
	root.add_child(panel)
	tabs_label = _label(GOLD)
	tabs_label.position = Vector2(12, 6)
	panel.add_child(tabs_label)
	# 物品页
	items_page = Control.new()
	items_page.position = Vector2(12, 26)
	items_page.size = Vector2(396, 190)
	panel.add_child(items_page)
	grid = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	items_page.add_child(grid)
	detail_name = _label(GOLD)
	detail_name.position = Vector2(0, 92)
	items_page.add_child(detail_name)
	detail_desc = _label(TEXT)
	detail_desc.position = Vector2(0, 110)
	detail_desc.size = Vector2(396, 48)
	detail_desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	items_page.add_child(detail_desc)
	hotkey_label = _label(PINK)
	hotkey_label.position = Vector2(0, 166)
	items_page.add_child(hotkey_label)
	# 被动技能页
	passives_page = Control.new()
	passives_page.position = Vector2(12, 26)
	passives_page.size = Vector2(396, 190)
	panel.add_child(passives_page)
	passive_grid = GridContainer.new()
	passive_grid.columns = COLUMNS
	passive_grid.add_theme_constant_override("h_separation", 4)
	passive_grid.add_theme_constant_override("v_separation", 4)
	passives_page.add_child(passive_grid)
	passive_name = _label(GOLD)
	passive_name.position = Vector2(0, 92)
	passives_page.add_child(passive_name)
	passive_desc = _label(TEXT)
	passive_desc.position = Vector2(0, 110)
	passive_desc.size = Vector2(396, 70)
	passive_desc.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	passives_page.add_child(passive_desc)
	# 状态页
	status_page = VBoxContainer.new()
	status_page.position = Vector2(12, 26)
	status_page.size = Vector2(396, 190)
	status_page.add_theme_constant_override("separation", 2)
	panel.add_child(status_page)
	# CG 图鉴页
	gallery_page = VBoxContainer.new()
	gallery_page.position = Vector2(12, 26)
	gallery_page.size = Vector2(396, 190)
	gallery_page.add_theme_constant_override("separation", 1)
	panel.add_child(gallery_page)
	hint_label = _label(DIM)
	hint_label.position = Vector2(12, 222)
	panel.add_child(hint_label)


func _label(col: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", col)
	return l


func _refresh() -> void:
	var parts: Array[String] = []
	for i in PAGES.size():
		parts.append(("【%s】" if i == page else " %s ") % PAGES[i])
	tabs_label.text = "冒险背包　" + "  ".join(parts)
	items_page.visible = page == PAGE_ITEMS
	passives_page.visible = page == PAGE_PASSIVES
	status_page.visible = page == PAGE_STATUS
	gallery_page.visible = page == PAGE_GALLERY
	if page == PAGE_GALLERY:
		_refresh_gallery()
		hint_label.text = "上下 选择　左右 翻页　E 播放　Tab / Esc 关闭"
	elif page == PAGE_ITEMS:
		_refresh_items()
		hint_label.text = "方向键 选择　E 使用　Q / R 设为快捷键　Tab 下一页　Esc 关闭"
	elif page == PAGE_PASSIVES:
		_refresh_passives()
		hint_label.text = "方向键 选择　Tab 下一页　Esc 关闭"
	else:
		_refresh_status()
		hint_label.text = "Tab 下一页　Esc 关闭"


# ------------------------------------------------------------------ CG 图鉴
## 所有条目（按分类：笑倒 → 巢穴 → 组合演出）。
static func gallery_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cg: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/CG")
	if cg == null:
		return out
	var groups := {"death_": "笑倒", "nest_": "巢穴"}
	for prefix in groups:
		for id in cg.cgs():
			if str(id).begins_with(prefix):
				out.append({"kind": "cg", "id": id, "flag": "cg_seen_" + id, "group": groups[prefix],
					"name": str(cg.cgs()[id].get("name", id))})
	for id in cg.scenes:
		out.append({"kind": "scene", "id": id, "flag": "cg_seen_combo:" + id, "group": "组合",
			"name": str(cg.scenes[id].get("name", id))})
	return out


## 这一条能不能看：测试模式全部，平时看过的。
static func gallery_unlocked(e: Dictionary) -> bool:
	return DevConfig.enabled() or GameState.has_flag(str(e["flag"]))


func _refresh_gallery() -> void:
	_gallery = gallery_entries()
	gallery_selected = clampi(gallery_selected, 0, maxi(_gallery.size() - 1, 0))
	for c in gallery_page.get_children():
		gallery_page.remove_child(c)
		c.queue_free()
	var seen := _gallery.filter(func(e): return gallery_unlocked(e)).size()
	var head := _label(GOLD)
	head.text = "已解锁 %d / %d%s" % [seen, _gallery.size(), "　（测试模式：全部可看）" if DevConfig.enabled() else ""]
	gallery_page.add_child(head)
	var first := clampi(gallery_selected - GALLERY_ROWS / 2, 0, maxi(_gallery.size() - GALLERY_ROWS, 0))
	for i in range(first, mini(first + GALLERY_ROWS, _gallery.size())):
		var e := _gallery[i]
		var open_ := gallery_unlocked(e)
		var l := _label(PINK if i == gallery_selected else (TEXT if open_ else DIM))
		l.text = "%s【%s】%s" % ["▶ " if i == gallery_selected else "　 ", e["group"], e["name"] if open_ else "？？？"]
		gallery_page.add_child(l)


## 播放选中的 CG：关掉背包、解除暂停后播放（播完回到游戏）。
func play_selected() -> bool:
	if _gallery.is_empty() or not gallery_unlocked(_gallery[gallery_selected]):
		Audio.play("locked", -8.0)
		return false
	var e := _gallery[gallery_selected]
	var cg := get_node_or_null("/root/CG")
	if cg == null or cg.is_busy():
		return false
	close()
	if e["kind"] == "scene":
		cg.play_scene(str(e["id"]))
	else:
		var id := str(e["id"])
		var source := id.trim_prefix("death_") if id.begins_with("death_") else ""
		for kind in cg.data.get("nest", {}):
			if str(cg.data["nest"][kind].get("cg", "")) == id:
				source = str(cg.data["nest"][kind].get("source", ""))
		cg.play(id, source)
	return true


## 被动技能页：图标网格（右下角等级）+ 选中技能的当前效果和下一级效果。
func _refresh_passives() -> void:
	_passive_ids = PassiveDB.ids().filter(func(id): return GameState.passives.has(id))
	passive_selected = clampi(passive_selected, 0, maxi(_passive_ids.size() - 1, 0))
	for c in passive_grid.get_children():
		c.queue_free()
	for i in _passive_ids.size():
		passive_grid.add_child(_passive_slot(_passive_ids[i], i == passive_selected))
	if _passive_ids.is_empty():
		passive_name.text = "还没有被动技能。"
		passive_desc.text = "冒险中会学会新的被动技能，学会后显示在这里；以后还能升级。"
		return
	var id: String = _passive_ids[passive_selected]
	var lv := GameState.passive_level(id)
	var mx := PassiveDB.max_level(id)
	passive_name.text = "%s　Lv.%d / %d" % [PassiveDB.name(id), lv, mx]
	var text := "当前：" + str(PassiveDB.level_info(id, lv).get("desc", ""))
	text += "\n下一级：" + str(PassiveDB.level_info(id, lv + 1).get("desc", "")) if lv < mx else "\n已经满级。"
	passive_desc.text = text


func _passive_slot(id: String, active: bool) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(40, 40)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.14, 0.26) if active else Color(0.17, 0.11, 0.2)
	sb.border_color = GOLD if active else Color(0.4, 0.28, 0.45)
	sb.set_border_width_all(2 if active else 1)
	sb.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", sb)
	var icon := TextureRect.new()
	icon.texture = PassiveDB.icon(id)
	icon.position = Vector2(4, 4)
	icon.size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_child(icon)
	var n := _label(GOLD)
	n.text = "Lv%d" % GameState.passive_level(id)
	n.position = Vector2(16, 22)
	p.add_child(n)
	return p


func _refresh_items() -> void:
	_items = GameState.inventory.items()
	selected = clampi(selected, 0, maxi(_items.size() - 1, 0))
	for c in grid.get_children():
		c.queue_free()
	for i in _items.size():
		grid.add_child(_slot(_items[i], i == selected))
	var it := selected_item()
	if it:
		var hk := GameState.hotkey_of(it.id)
		detail_name.text = "%s ×%d　（%s）%s" % [it.display_name, GameState.inventory.count(it.id),
				CATEGORY_NAMES.get(it.category, ""), ("　[%s]" % hk) if hk != "" else ""]
		detail_desc.text = it.description
	else:
		detail_name.text = "背包是空的。"
		detail_desc.text = ""
	hotkey_label.text = "快捷键　Q：%s　　R：%s" % [_hotkey_name("use_item"), _hotkey_name("use_special")]


func _hotkey_name(hotkey: String) -> String:
	var id := GameState.hotkey_item(hotkey)
	var it := ItemDB.get_item(id) if id != "" else null
	if it == null:
		return "（无）"
	return "%s ×%d" % [it.display_name, GameState.inventory.count(id)]


func _slot(it: ItemData, active: bool) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(40, 40)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.14, 0.26) if active else Color(0.17, 0.11, 0.2)
	sb.border_color = GOLD if active else Color(0.4, 0.28, 0.45)
	sb.set_border_width_all(2 if active else 1)
	sb.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", sb)
	var icon := TextureRect.new()
	icon.texture = it.icon
	icon.position = Vector2(4, 4)
	icon.size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_child(icon)
	var n := _label(TEXT)
	n.text = str(GameState.inventory.count(it.id))
	n.position = Vector2(24, 22)
	p.add_child(n)
	var hk := GameState.hotkey_of(it.id)
	if hk != "":
		var k := _label(PINK)
		k.text = hk
		k.position = Vector2(3, 0)
		p.add_child(k)
	return p


func _refresh_status() -> void:
	for c in status_page.get_children():
		c.queue_free()
	var p := GameState.player
	if not is_instance_valid(p):
		return
	if p.laugh:
		_line("闷笑值 %d%%　%s" % [roundi(p.laugh.percent()), p.laugh.stage_name()], PINK)
		_line("　" + p.laugh.stage_desc(), TEXT)
	var sens: Sensitivity = p.get("sensitivity")
	if sens and p.laugh:
		var body := TickleZones.body_multiplier(p.laugh.stage(), sens.damaged)
		_line("敏感度　全身 ×%.2f%s" % [body, "（战损）" if sens.damaged else ""], Color(1, 0.7, 0.85))
		var parts: Array[String] = []
		for z in TickleZones.zone_ids():
			var mark := "↑" if sens.streak_of(z) > 0.0 else ""
			parts.append("%s ×%.2f%s" % [TickleZones.zone_name(z), sens.zone_total(z), mark])
		# 每行 4 个部位（部位多了也排得下）
		for i in range(0, parts.size(), 4):
			_line("　" + "　".join(parts.slice(i, i + 4)), TEXT)
	var f: MagicFatigue = p.get("fatigue")
	if f:
		var bonus := roundi(f.laugh_bonus() * 100.0)
		var nxt := f.next_tier()
		var tail := "　下一档：%d%% → +%d%%" % [roundi(nxt[0] * 100.0), roundi(nxt[1] * 100.0)] if not nxt.is_empty() else ""
		_line("魔力疲倦 %d%%　闷笑积累 +%d%%%s" % [roundi(f.percent()), bonus, tail], Color(0.78, 0.66, 1.0))
		if f.is_near_full():
			_line("　快满了！满了会疲倦爆发，留下一层疲倦印记。", TEXT)
	# 训练成果（练过才显示）
	if GameState.vars.keys().any(func(k): return str(k).begins_with("train_") and float(GameState.vars[k]) > 0.0):
		_line("训练成果：疲倦上限 %d　释放强度 +%.1f%%　闷笑上限 +%.1f　生命 +%s 颗心　近战 +%.1f%%" % [TrainingStats.fatigue_max(),
			TrainingStats.value("train_burst_power"), TrainingStats.laugh_bonus(), str(TrainingStats.hp_bonus() / 2.0),
			TrainingStats.melee_bonus() * 100.0], Color(0.6, 0.9, 1.0))
	if p.is_magic_unlocked():
		var cd := p.magic_cooldown_left()
		_line("星光爆发：" + ("冷却中 %.1f 秒" % cd if cd > 0.0 else "可以使用（按住 L 吟唱）"), GOLD)
	var any := false
	for id in p.buffs:
		any = true
		_buff_line(id, p.buffs[id], p)
	for s in _situations(p):
		any = true
		_line("· " + s, TEXT)
	if not any:
		_line("没有特别的状态。", DIM)


## 被抓、定身、减速、余痒等不是 buff 的情况。
func _situations(p: PlayableCharacter) -> Array[String]:
	var out: Array[String] = []
	var st := p.status
	if st == null:
		return out
	if st.is_grabbed():
		var left := st.grab_time_left()
		var who := str(ReactionDB.source(ReactionDB.key_of(st.grabber)).get("name", ""))
		out.append("被%s困住：%s，还要挣扎 %d 次" % [who if who != "" else "抓", "剩 %.1f 秒" % left if left < INF else "不会自己松开",
				st.presses_left()])
	if st.is_rooted():
		out.append("定身：动不了，还剩 %.1f 秒" % st.root_time_left())
	if st.is_slowed():
		out.append("减速：移动变慢")
	if st.has_dot():
		out.append("余痒：一直有点痒")
	if st.tickle_multiplier() > 1.0:
		out.append("易痒：受到的挠痒 ×%.1f" % st.tickle_multiplier())
	if p.forced_specials > 0:
		out.append("接下来 %d 次挠痒必定暴击" % p.forced_specials)
	return out


func _buff_line(id: String, b: Buff, p: Object = null) -> void:
	var info := Buff.display(id, p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = BUFF_ICONS
	at.region = Rect2(int(info.get("icon", 0)) * 12, 0, 12, 12)
	icon.texture = at
	icon.custom_minimum_size = Vector2(12, 12)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var time := "永久" if b.is_permanent() else "%.1f 秒" % b.time_left
	if b.stacks > 1:
		time = "%d 层，%s" % [b.stacks, time]
	var l := _label(Color(1, 0.6, 0.65) if b.is_debuff() else Color(0.6, 1, 0.7))
	l.text = "%s（%s）%s" % [info.get("name", id), time, info.get("desc", "")]
	row.add_child(l)
	status_page.add_child(row)


func _line(text: String, col: Color) -> void:
	var l := _label(col)
	l.text = text
	status_page.add_child(l)

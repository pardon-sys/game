class_name HUD
extends CanvasLayer
## HUD：左上血量、闷笑值条、背包栏（按物品数据自动生成），右上表情头像，屏幕上方提示消息。
## 魔法：闷笑条右边的魔法图标（学会后显示，冷却时变灰并显示剩余秒数），吟唱时屏幕上方闪"弱点暴露！"。

const HUD_TEX := preload("res://assets/generated/hud.png")
const MAGIC_ICON := preload("res://assets/generated/magic_icon.png")
const BUFF_ICONS := preload("res://assets/generated/buff_icons.png")

@onready var hearts: HBoxContainer = $Hearts
@onready var laugh_bar: LaughBar = $LaughRow/Bar
@onready var inventory_row: HBoxContainer = $Inventory
@onready var portrait: TextureRect = $PortraitFrame/Portrait
@onready var portrait_frame: Control = $PortraitFrame
@onready var toast_label: Label = $Toast

var _heart_tex: Array[AtlasTexture] = []
var _toast_tween: Tween
var _player: PlayableCharacter
var magic_slot: Control
var magic_icon: TextureRect
var magic_label: Label
var exposed_label: Label
var _icon_ready: AtlasTexture
var _icon_cd: AtlasTexture
var _blink := 0.0
var combo_label: Label
var _combo_tween: Tween
## 组合技专属画面特效：全屏闪光、连锁数、三来源大字标题
var combo_flash: ColorRect
var chain_label: Label
var combo_title: Label
var combo_sub: Label
var _title_tween: Tween
## 三来源组合的慢动作（测试里可以关掉）。
static var slow_motion := true
## 公主身上的增益 / 减益图标（心形右边）
var buff_row: HBoxContainer
## 闷笑条下面的魔力疲倦条
var fatigue_row: HBoxContainer
var fatigue_bar: FatigueBar
## 两条的百分比数字
var laugh_pct: Label
var fatigue_pct: Label


func _ready() -> void:
	for i in 3:
		var at := AtlasTexture.new()
		at.atlas = HUD_TEX
		at.region = Rect2(i * 16, 0, 16, 16)
		_heart_tex.append(at)
	GameState.player_registered.connect(_bind_player)
	GameState.inventory.changed.connect(_refresh_inventory)
	GameState.hotkeys_changed.connect(_refresh_inventory)
	GameState.emotion_changed.connect(_on_emotion_changed)
	GameState.toast.connect(show_toast)
	GameState.combo_triggered.connect(show_combo)
	toast_label.modulate.a = 0.0
	_build_magic_ui()
	fatigue_row = HBoxContainer.new()
	fatigue_row.name = "FatigueRow"
	fatigue_row.position = Vector2(6, 35)
	fatigue_row.add_theme_constant_override("separation", 4)
	var fl := Label.new()
	fl.text = "魔力"
	fl.add_theme_color_override("font_color", Color(0.78, 0.66, 1.0))
	fatigue_row.add_child(fl)
	fatigue_bar = FatigueBar.new()
	fatigue_bar.custom_minimum_size = Vector2(75, 5)
	fatigue_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fatigue_row.add_child(fatigue_bar)
	fatigue_pct = _pct_label(Color(0.78, 0.66, 1.0))
	fatigue_row.add_child(fatigue_pct)
	add_child(fatigue_row)
	laugh_pct = _pct_label(Color(1, 0.72, 0.86))
	$LaughRow.add_child(laugh_pct)
	fatigue_row.hide()
	buff_row = HBoxContainer.new()
	buff_row.name = "Buffs"
	buff_row.position = Vector2(92, 7)
	buff_row.add_theme_constant_override("separation", 2)
	add_child(buff_row)
	if GameState.player:
		_bind_player(GameState.player)
	_refresh_inventory()
	_on_emotion_changed(GameState.player.emotion.current if is_instance_valid(GameState.player) else "normal")


## 切换操控时先断开上一个角色的信号（不然换回来会重复连接，搭档的血量变化也会显示在 HUD 上）。
var _links: Array = []


func _link(sig: Signal, cb: Callable) -> void:
	sig.connect(cb)
	_links.append([sig, cb])


func _bind_player(p: PlayableCharacter) -> void:
	if _player == p:
		return
	for l in _links:
		if (l[0] as Signal).is_connected(l[1]):
			(l[0] as Signal).disconnect(l[1])
	_links.clear()
	_player = p
	# 换了操控的角色（蓝色公主当主角）：头像马上换成她那一套
	if p.emotion:
		_on_emotion_changed(p.emotion.current)
	if p.health:
		_link(p.health.changed, _on_hp_changed)
		_on_hp_changed(p.health.hp, p.health.max_hp)
	$LaughRow.visible = p.laugh != null
	if p.laugh:
		laugh_bar.bind(p.laugh)
		_link(p.laugh.changed, func(v: float, m: float): laugh_pct.text = "%d%%" % roundi(v / m * 100.0))
		laugh_pct.text = "%d%%" % roundi(p.laugh.percent())
	var f: MagicFatigue = p.get("fatigue")
	fatigue_row.visible = f != null
	if f:
		fatigue_bar.bind(f)
		_link(f.changed, func(v: float, m: float): fatigue_pct.text = "%d%%" % roundi(v / m * 100.0))
		fatigue_pct.text = "%d%%" % roundi(f.percent())
	_link(p.buffs_changed, _refresh_buffs)
	_refresh_buffs()


func _pct_label(col: Color) -> Label:
	var l := Label.new()
	l.text = "0%"
	l.custom_minimum_size = Vector2(26, 0)
	l.add_theme_color_override("font_color", col)
	return l


## 状态图标：每种一个，叠层的在右下角标层数；快到时的闪烁（见 _process）。
func _refresh_buffs() -> void:
	for c in buff_row.get_children():
		c.queue_free()
	if not is_instance_valid(_player):
		return
	for id in _player.buffs:
		var b: Buff = _player.buffs[id]
		var info := Buff.display(id, _player)
		var icon := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = BUFF_ICONS
		at.region = Rect2(int(info.get("icon", 0)) * 12, 0, 12, 12)
		icon.texture = at
		icon.custom_minimum_size = Vector2(12, 12)
		icon.tooltip_text = str(info.get("name", id))
		icon.set_meta("buff", id)
		if b.stacks > 1:
			var n := Label.new()
			n.text = str(b.stacks)
			n.position = Vector2(7, 2)
			n.add_theme_font_size_override("font_size", 8)
			n.add_theme_color_override("font_outline_color", Color.BLACK)
			n.add_theme_constant_override("outline_size", 2)
			icon.add_child(n)
		buff_row.add_child(icon)


func _build_magic_ui() -> void:
	_icon_ready = AtlasTexture.new()
	_icon_ready.atlas = MAGIC_ICON
	_icon_ready.region = Rect2(0, 0, 16, 16)
	_icon_cd = AtlasTexture.new()
	_icon_cd.atlas = MAGIC_ICON
	_icon_cd.region = Rect2(16, 0, 16, 16)
	magic_slot = HBoxContainer.new()
	magic_slot.name = "Magic"
	magic_slot.position = Vector2(140, 20)
	magic_slot.add_theme_constant_override("separation", 1)
	add_child(magic_slot)
	magic_icon = TextureRect.new()
	magic_icon.texture = _icon_ready
	magic_icon.custom_minimum_size = Vector2(16, 16)
	magic_slot.add_child(magic_icon)
	magic_label = Label.new()
	magic_label.add_theme_color_override("font_color", Color(1, 0.94, 0.7))
	magic_slot.add_child(magic_label)
	magic_slot.hide()
	exposed_label = Label.new()
	exposed_label.name = "Exposed"
	exposed_label.text = "弱点暴露！"
	exposed_label.position = Vector2(90, 74)
	exposed_label.size = Vector2(300, 16)
	exposed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exposed_label.add_theme_color_override("font_color", Color(1, 0.45, 0.6))
	exposed_label.add_theme_color_override("font_outline_color", Color(0.247, 0.149, 0.192))
	exposed_label.add_theme_constant_override("outline_size", 4)
	exposed_label.hide()
	add_child(exposed_label)
	combo_label = Label.new()
	combo_label.name = "Combo"
	combo_label.position = Vector2(90, 76)
	combo_label.size = Vector2(300, 16)
	combo_label.pivot_offset = Vector2(150, 8)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	combo_label.add_theme_color_override("font_outline_color", Color(0.45, 0.12, 0.3))
	combo_label.add_theme_constant_override("outline_size", 5)
	combo_label.modulate.a = 0.0
	add_child(combo_label)
	combo_flash = ColorRect.new()
	combo_flash.name = "ComboFlash"
	combo_flash.color = Color(1.0, 0.55, 0.8, 0.0)
	combo_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(combo_flash)
	move_child(combo_flash, 0)
	chain_label = Label.new()
	chain_label.name = "Chain"
	chain_label.position = Vector2(330, 90)
	chain_label.add_theme_color_override("font_color", Color(1, 0.5, 0.75))
	chain_label.add_theme_color_override("font_outline_color", Color(0.3, 0.05, 0.2))
	chain_label.add_theme_constant_override("outline_size", 4)
	chain_label.modulate.a = 0.0
	add_child(chain_label)
	combo_title = Label.new()
	combo_title.name = "ComboTitle"
	combo_title.position = Vector2(40, 100)
	combo_title.size = Vector2(400, 30)
	combo_title.pivot_offset = Vector2(200, 15)
	combo_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_title.add_theme_font_size_override("font_size", 24)
	combo_title.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
	combo_title.add_theme_color_override("font_outline_color", Color(0.5, 0.08, 0.3))
	combo_title.add_theme_constant_override("outline_size", 8)
	combo_title.modulate.a = 0.0
	add_child(combo_title)
	combo_sub = Label.new()
	combo_sub.name = "ComboSub"
	combo_sub.position = Vector2(40, 132)
	combo_sub.size = Vector2(400, 16)
	combo_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_sub.add_theme_color_override("font_color", Color(1, 0.8, 0.92))
	combo_sub.add_theme_color_override("font_outline_color", Color(0.3, 0.05, 0.2))
	combo_sub.add_theme_constant_override("outline_size", 4)
	combo_sub.modulate.a = 0.0
	add_child(combo_sub)


## 组合技横幅：弹一下，停留后淡出。全屏粉色闪光；连锁时显示「连锁 ×N」；
## 三来源组合额外在屏幕中间显示大字标题和搭配类别，并慢动作 0.3 秒。
func show_combo(id: String, combo_name: String) -> void:
	var c := ComboTracker.combo_def(id)
	var triple := ComboTracker.is_triple(c)
	var tracker: ComboTracker = _player.combo if is_instance_valid(_player) else null
	var upgraded := tracker != null and tracker.last_upgraded
	combo_label.text = ("【连锁升级】" if upgraded else ("【三重组合】" if triple else "【组合技】")) + "%s！" % combo_name
	_flash(0.45 if triple else 0.28)
	var n := tracker.chain if tracker else 0
	if n >= 2:
		chain_label.text = "连锁 ×%d" % n
		chain_label.modulate.a = 1.0
		chain_label.scale = Vector2(1.4, 1.4)
		var ct := create_tween()
		ct.tween_property(chain_label, "scale", Vector2.ONE, 0.15)
		ct.tween_interval(2.0)
		ct.tween_property(chain_label, "modulate:a", 0.0, 0.5)
	if triple:
		_show_title(combo_name, str(c.get("category", "")))
	if _combo_tween:
		_combo_tween.kill()
	combo_label.modulate.a = 1.0
	combo_label.scale = Vector2(1.5, 1.5)
	_combo_tween = create_tween()
	_combo_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.15)
	_combo_tween.tween_interval(1.6)
	_combo_tween.tween_property(combo_label, "modulate:a", 0.0, 0.4)


func _flash(alpha: float) -> void:
	combo_flash.color.a = alpha
	create_tween().tween_property(combo_flash, "color:a", 0.0, 0.3)


func _show_title(title: String, category: String) -> void:
	combo_title.text = "%s！" % title
	combo_sub.text = category
	if _title_tween:
		_title_tween.kill()
	combo_title.modulate.a = 1.0
	combo_sub.modulate.a = 1.0
	combo_title.scale = Vector2(2.0, 2.0)
	_title_tween = create_tween().set_ignore_time_scale()
	_title_tween.tween_property(combo_title, "scale", Vector2.ONE, 0.18)
	_title_tween.tween_interval(1.2)
	_title_tween.tween_property(combo_title, "modulate:a", 0.0, 0.4)
	_title_tween.parallel().tween_property(combo_sub, "modulate:a", 0.0, 0.4)
	if slow_motion:
		Engine.time_scale = 0.4
		get_tree().create_timer(0.3, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _process(delta: float) -> void:
	_update_carousel(delta)
	var p := _player
	if not is_instance_valid(p):
		return
	magic_slot.visible = p.is_magic_unlocked()
	if magic_slot.visible:
		var cd := p.magic_cooldown_left()
		magic_icon.texture = _icon_cd if cd > 0.0 or (p.laugh and p.laugh.is_helpless()) else _icon_ready
		magic_label.text = "%d" % ceili(cd) if cd > 0.0 else "[L]"
	for icon in buff_row.get_children():
		var b: Buff = p.buffs.get(icon.get_meta("buff", ""))
		icon.modulate.a = 0.4 if b and not b.is_permanent() and b.time_left < 2.0 and int(b.time_left * 6.0) % 2 == 0 else 1.0
	exposed_label.visible = p.is_channeling()
	if exposed_label.visible:
		_blink += delta
		exposed_label.modulate.a = 1.0 if int(_blink * 6.0) % 2 == 0 else 0.55
	else:
		_blink = 0.0


func _on_hp_changed(hp: int, max_hp: int) -> void:
	var count := int(ceil(max_hp / 2.0))
	while hearts.get_child_count() < count:
		var r := TextureRect.new()
		r.custom_minimum_size = Vector2(16, 16)
		hearts.add_child(r)
	for i in hearts.get_child_count():
		var r := hearts.get_child(i) as TextureRect
		var v := hp - i * 2
		r.texture = _heart_tex[0 if v >= 2 else (1 if v == 1 else 2)]
		r.visible = i < count


# ------------------------------------------------------------------ 道具栏：固定 Q / R + 自动轮播
## 最多显示 BAR_SLOTS 格：Q / R 绑定的道具（背包里有时）固定在最前，其余道具在轮播窗口里每 CAROUSEL_TIME 秒滑一格；
## 窗口两侧有 < > 箭头和「+N」（还有几个没显示）。新拿到 / 数量增加的道具会立刻转到窗口里并闪一下。
const BAR_SLOTS := 3
const CAROUSEL_TIME := 2.5
const CAROUSEL_SLOT_W := 40.0

## 轮播里的道具（测试用）。
var carousel_items: Array[ItemData] = []
var carousel_index := 0
var pinned_items: Array[ItemData] = []
var _carousel_slots := 0
var _carousel_t := 0.0
var _carousel_strip: HBoxContainer
var _more_label: Label
var _counts := {}


func _refresh_inventory() -> void:
	for c in inventory_row.get_children():
		inventory_row.remove_child(c)
		c.queue_free()
	_carousel_strip = null
	_more_label = null
	var shown: Array[ItemData] = []
	for id in ItemDB.all_ids():
		var it := ItemDB.get_item(id)
		if it and it.show_in_hud and (it.always_show or GameState.inventory.has(id)):
			shown.append(it)
	# 这次新增或数量增加的道具
	var grown := ""
	for it in shown:
		var n := GameState.inventory.count(it.id)
		if n > int(_counts.get(it.id, 0)):
			grown = it.id
		_counts[it.id] = n
	pinned_items = []
	for hk in GameState.HOTKEY_LABELS:
		var bound := GameState.hotkey_item(hk)
		var it: ItemData = ItemDB.get_item(bound) if bound != "" else null
		if it and shown.has(it) and GameState.inventory.has(it.id):
			pinned_items.append(it)
	var others: Array[ItemData] = []
	for it in shown:
		if not pinned_items.has(it):
			others.append(it)
	carousel_items = []
	_carousel_slots = 0
	if shown.size() <= BAR_SLOTS:
		for it in pinned_items + others:
			inventory_row.add_child(_item_slot(it))
		return
	for it in pinned_items:
		inventory_row.add_child(_item_slot(it))
	carousel_items = others
	_carousel_slots = BAR_SLOTS - pinned_items.size()
	var at := carousel_items.map(func(x): return x.id).find(grown)
	if at >= 0:
		carousel_index = at
	carousel_index = posmod(carousel_index, carousel_items.size())
	_carousel_t = 0.0
	inventory_row.add_child(_arrow("<"))
	var window := Control.new()
	window.name = "Carousel"
	window.clip_contents = true
	window.custom_minimum_size = Vector2(CAROUSEL_SLOT_W * _carousel_slots, 16)
	_carousel_strip = HBoxContainer.new()
	_carousel_strip.add_theme_constant_override("separation", 0)
	# 末尾补上开头几格，循环时无缝接上
	for i in carousel_items.size() + _carousel_slots:
		var slot := _item_slot(carousel_items[i % carousel_items.size()])
		slot.custom_minimum_size.x = CAROUSEL_SLOT_W
		_carousel_strip.add_child(slot)
	_carousel_strip.position.x = -carousel_index * CAROUSEL_SLOT_W
	window.add_child(_carousel_strip)
	inventory_row.add_child(window)
	inventory_row.add_child(_arrow(">"))
	_more_label = _arrow("+%d" % (carousel_items.size() - _carousel_slots))
	inventory_row.add_child(_more_label)
	if at >= 0:
		var flash := _carousel_strip.get_child(carousel_index) as Control
		flash.modulate = Color(2.0, 1.6, 1.8)
		create_tween().tween_property(flash, "modulate", Color.WHITE, 0.5)


## 现在道具栏上能看到的道具 id（固定格 + 轮播窗口；测试用）。
func visible_item_ids() -> Array:
	if carousel_items.is_empty():
		var all: Array = []
		for c in inventory_row.get_children():
			if c.has_meta("item"):
				all.append(c.get_meta("item"))
		return all
	var ids: Array = pinned_items.map(func(x): return x.id)
	for i in _carousel_slots:
		ids.append(carousel_items[(carousel_index + i) % carousel_items.size()].id)
	return ids


func more_count() -> int:
	return maxi(carousel_items.size() - _carousel_slots, 0)


func _update_carousel(delta: float) -> void:
	if _carousel_strip == null or carousel_items.size() <= _carousel_slots:
		return
	_carousel_t += delta
	if _carousel_t < CAROUSEL_TIME:
		return
	_carousel_t = 0.0
	carousel_index += 1
	var strip := _carousel_strip
	var tw := create_tween()
	tw.tween_property(strip, "position:x", -carousel_index * CAROUSEL_SLOT_W, 0.3).set_trans(Tween.TRANS_QUAD)
	if carousel_index >= carousel_items.size():
		carousel_index = 0
		tw.tween_callback(func():
			if is_instance_valid(strip):
				strip.position.x = 0.0)


func _item_slot(it: ItemData) -> HBoxContainer:
	var slot := HBoxContainer.new()
	slot.set_meta("item", it.id)
	slot.add_theme_constant_override("separation", 0)
	var icon := TextureRect.new()
	icon.texture = it.icon
	icon.custom_minimum_size = Vector2(16, 16)
	slot.add_child(icon)
	var label := Label.new()
	label.text = "×%d" % GameState.inventory.count(it.id)
	var hk := GameState.hotkey_of(it.id)
	if hk != "":
		label.text += " [%s]" % hk
	slot.add_child(label)
	return slot


func _arrow(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(1, 0.8, 0.9, 0.8))
	return l


func _on_emotion_changed(emotion: String) -> void:
	portrait.texture = Dialogue.head_for(emotion)
	var tw := create_tween()
	portrait_frame.pivot_offset = portrait_frame.size / 2.0
	tw.tween_property(portrait_frame, "scale", Vector2(1.12, 1.12), 0.06)
	tw.tween_property(portrait_frame, "scale", Vector2.ONE, 0.1)


## 屏幕上方的黄色提示：太长时自动换行（宽度不超过屏幕宽 − 40，居中，按行数往下长），不会跑出屏幕。
const TOAST_MARGIN := 20.0


func show_toast(text: String) -> void:
	var vw := get_viewport().get_visible_rect().size.x
	toast_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	toast_label.size = Vector2(vw - TOAST_MARGIN * 2.0, 0.0)
	toast_label.position.x = TOAST_MARGIN
	toast_label.text = text
	toast_label.reset_size()
	toast_label.size.x = vw - TOAST_MARGIN * 2.0
	# 时间按长度略加长，长句子来得及看完
	var hold := clampf(2.4 + text.length() * 0.03, 2.4, 5.0)
	if _toast_tween:
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(hold)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)

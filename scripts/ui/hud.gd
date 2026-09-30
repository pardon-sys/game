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
## 公主身上的增益 / 减益图标（心形右边）
var buff_row: HBoxContainer


func _ready() -> void:
	for i in 3:
		var at := AtlasTexture.new()
		at.atlas = HUD_TEX
		at.region = Rect2(i * 16, 0, 16, 16)
		_heart_tex.append(at)
	GameState.player_registered.connect(_bind_player)
	GameState.inventory.changed.connect(_refresh_inventory)
	GameState.emotion_changed.connect(_on_emotion_changed)
	GameState.toast.connect(show_toast)
	GameState.combo_triggered.connect(show_combo)
	toast_label.modulate.a = 0.0
	_build_magic_ui()
	buff_row = HBoxContainer.new()
	buff_row.name = "Buffs"
	buff_row.position = Vector2(92, 7)
	buff_row.add_theme_constant_override("separation", 2)
	add_child(buff_row)
	if GameState.player:
		_bind_player(GameState.player)
	_refresh_inventory()
	_on_emotion_changed(GameState.player.emotion.current if is_instance_valid(GameState.player) else "normal")


func _bind_player(p: PlayableCharacter) -> void:
	if _player == p:
		return
	_player = p
	if p.health:
		p.health.changed.connect(_on_hp_changed)
		_on_hp_changed(p.health.hp, p.health.max_hp)
	$LaughRow.visible = p.laugh != null
	if p.laugh:
		laugh_bar.bind(p.laugh)
	p.buffs_changed.connect(_refresh_buffs)
	_refresh_buffs()


## 状态图标：每种一个，叠层的在右下角标层数；快到时的闪烁（见 _process）。
func _refresh_buffs() -> void:
	for c in buff_row.get_children():
		c.queue_free()
	if not is_instance_valid(_player):
		return
	for id in _player.buffs:
		var b: Buff = _player.buffs[id]
		var info := Buff.info(id)
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
	magic_slot.position = Vector2(124, 20)
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
	combo_label.position = Vector2(90, 38)
	combo_label.size = Vector2(300, 16)
	combo_label.pivot_offset = Vector2(150, 8)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_color_override("font_color", Color(1, 0.86, 0.4))
	combo_label.add_theme_color_override("font_outline_color", Color(0.45, 0.12, 0.3))
	combo_label.add_theme_constant_override("outline_size", 5)
	combo_label.modulate.a = 0.0
	add_child(combo_label)


## 组合技横幅：弹一下，停留后淡出。
func show_combo(_id: String, combo_name: String) -> void:
	combo_label.text = "【组合技】%s！" % combo_name
	if _combo_tween:
		_combo_tween.kill()
	combo_label.modulate.a = 1.0
	combo_label.scale = Vector2(1.5, 1.5)
	_combo_tween = create_tween()
	_combo_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.15)
	_combo_tween.tween_interval(1.6)
	_combo_tween.tween_property(combo_label, "modulate:a", 0.0, 0.4)


func _process(delta: float) -> void:
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


func _refresh_inventory() -> void:
	for c in inventory_row.get_children():
		c.queue_free()
	var shown: Array[ItemData] = []
	for id in ItemDB.all_ids():
		var it := ItemDB.get_item(id)
		if it and it.show_in_hud and (it.always_show or GameState.inventory.has(id)):
			shown.append(it)
	for it in shown:
		var slot := HBoxContainer.new()
		slot.add_theme_constant_override("separation", 0)
		var icon := TextureRect.new()
		icon.texture = it.icon
		icon.custom_minimum_size = Vector2(16, 16)
		slot.add_child(icon)
		var label := Label.new()
		label.text = "×%d" % GameState.inventory.count(it.id)
		if it.category == ItemData.Category.CONSUMABLE:
			label.text += " [Q]"
		slot.add_child(label)
		inventory_row.add_child(slot)


func _on_emotion_changed(emotion: String) -> void:
	portrait.texture = Dialogue.head_for(emotion)
	var tw := create_tween()
	portrait_frame.pivot_offset = portrait_frame.size / 2.0
	tw.tween_property(portrait_frame, "scale", Vector2(1.12, 1.12), 0.06)
	tw.tween_property(portrait_frame, "scale", Vector2.ONE, 0.1)


func show_toast(text: String) -> void:
	toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.4)

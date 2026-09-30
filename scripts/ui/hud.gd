extends CanvasLayer
## HUD：左上血量、闷笑值条、背包栏（按物品数据自动生成），右上表情头像，屏幕上方提示消息。

const HUD_TEX := preload("res://assets/generated/hud.png")

@onready var hearts: HBoxContainer = $Hearts
@onready var laugh_bar: LaughBar = $LaughRow/Bar
@onready var inventory_row: HBoxContainer = $Inventory
@onready var portrait: TextureRect = $PortraitFrame/Portrait
@onready var portrait_frame: Control = $PortraitFrame
@onready var toast_label: Label = $Toast

var _heart_tex: Array[AtlasTexture] = []
var _toast_tween: Tween
var _player: PlayableCharacter


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
	toast_label.modulate.a = 0.0
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

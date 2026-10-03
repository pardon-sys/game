class_name ShopUI
extends CanvasLayer
## 商店界面（集贸市场）：商品表 data/shop/<id>.json。上下选、E 买、Esc / Tab 关。打开时暂停游戏。
## 用金币（coin）买；有库存的商品卖出数量记在 GameState.vars["shop_<商店>_<物品>"]（随存档保存）。
## await open(商店 id) 到关掉为止；测试 / 脚本可以直接调 buy(序号) 和 close()。

signal closed

const PINK := Color(1, 0.72, 0.86)
const GOLD := Color(1, 0.86, 0.4)
const TEXT := Color(0.95, 0.92, 0.98)
const DIM := Color(0.6, 0.55, 0.65)

var shop_id := ""
var shop := {}
var selected := 0
var panel: Panel
var list: VBoxContainer
var coins_label: Label
var desc_label: Label
var _paused_by_me := false


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.08, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.08, 0.16, 0.97)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(80, 30)
	panel.size = Vector2(320, 200)
	add_child(panel)
	coins_label = _label(GOLD)
	coins_label.position = Vector2(12, 6)
	panel.add_child(coins_label)
	list = VBoxContainer.new()
	list.position = Vector2(12, 28)
	list.add_theme_constant_override("separation", 2)
	panel.add_child(list)
	desc_label = _label(TEXT)
	desc_label.position = Vector2(12, 140)
	desc_label.size = Vector2(296, 34)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel.add_child(desc_label)
	var hint := _label(DIM)
	hint.text = "上下 选择　E 购买　Esc 离开"
	hint.position = Vector2(12, 178)
	panel.add_child(hint)


func _label(c: Color) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", c)
	return l


static func load_shop(id: String) -> Dictionary:
	var p := "res://data/shop/%s.json" % id
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else {}
	return parsed if parsed is Dictionary else {}


func open(id: String) -> void:
	shop_id = id
	shop = load_shop(id)
	selected = 0
	_paused_by_me = not get_tree().paused
	get_tree().paused = true
	Audio.play("book", -6.0)
	_refresh()
	await closed


func close() -> void:
	if _paused_by_me:
		get_tree().paused = false
	_paused_by_me = false
	closed.emit()


func items() -> Array:
	return shop.get("items", [])


func sold_key(item_id: String) -> String:
	return "shop_%s_%s" % [shop_id, item_id]


## 还剩多少库存（-1 = 不限）。
func stock_left(i: int) -> int:
	var it: Dictionary = items()[i]
	var stock := int(it.get("stock", -1))
	if stock < 0:
		return -1
	return maxi(stock - int(GameState.vars.get(sold_key(str(it["id"])), 0)), 0)


func buy(i: int) -> bool:
	if i < 0 or i >= items().size():
		return false
	var it: Dictionary = items()[i]
	var price := int(it.get("price", 0))
	var left := stock_left(i)
	if left == 0:
		GameState.notify("卖完了")
		Audio.play("locked", -8.0)
		return false
	if GameState.inventory.count("coin") < price:
		GameState.notify("金币不够……")
		Audio.play("locked", -8.0)
		return false
	var item := ItemDB.get_item(str(it["id"]))
	if item == null or GameState.inventory.add(item, 1) <= 0:
		GameState.notify("拿不下了")
		return false
	GameState.inventory.remove("coin", price)
	if left > 0:
		GameState.set_var(sold_key(str(it["id"])), int(GameState.vars.get(sold_key(str(it["id"])), 0)) + 1)
	Audio.play("pickup", -4.0)
	GameState.notify("买了%s" % item.display_name)
	_refresh()
	return true


func _refresh() -> void:
	coins_label.text = "%s　　金币 ×%d" % [str(shop.get("name", "商店")), GameState.inventory.count("coin")]
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	for i in items().size():
		var it: Dictionary = items()[i]
		var item := ItemDB.get_item(str(it["id"]))
		var left := stock_left(i)
		var l := _label(PINK if i == selected else (TEXT if left != 0 else DIM))
		l.text = "%s%s　%d 金币%s　（有 %d）" % ["▶ " if i == selected else "　 ", item.display_name if item else str(it["id"]),
			int(it.get("price", 0)), ("　剩 %d" % left) if left >= 0 else "", GameState.inventory.count(str(it["id"]))]
		list.add_child(l)
	if not items().is_empty():
		var item := ItemDB.get_item(str(items()[selected]["id"]))
		desc_label.text = item.description if item else ""


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or shop.is_empty():
		return
	if event.is_action("move_up") or event.is_action("ui_up"):
		selected = (selected - 1 + items().size()) % items().size()
		_refresh()
	elif event.is_action("move_down") or event.is_action("ui_down"):
		selected = (selected + 1) % items().size()
		_refresh()
	elif event.is_action("interact") or event.is_action("ui_accept"):
		buy(selected)
	elif event.is_action("pause") or event.is_action("ui_cancel") or event.is_action("backpack"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()

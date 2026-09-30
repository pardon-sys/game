class_name ItemData
extends Resource
## 物品基类（数据资源，放在 data/items/*.tres）。实现 Usable 接口：can_use(user) / use(user)。
## 新物品：继承本类重写 can_use / use，建一个 .tres，并在 ItemDB.PATHS 注册。

enum Category { CONSUMABLE, KEY, CURRENCY, INSTANT }

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D
@export var category := Category.CONSUMABLE
@export var stackable := true
@export var max_stack := 99
## 拾取时立即使用而不进背包（例如心）。
@export var auto_use_on_pickup := false
## 在 HUD 背包栏显示。
@export var show_in_hud := true
## 数量为 0 时也在 HUD 显示（例如金币）。
@export var always_show := false
@export var pickup_sound := "pickup"
## 获得时公主的表情（留空不做表情）。
@export var pickup_emotion := ""


func can_use(_user: Node) -> bool:
	return false


## 使用物品，返回是否被消耗。
func use(_user: Node) -> bool:
	return false

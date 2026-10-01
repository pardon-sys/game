class_name Inventory
extends RefCounted
## 背包：按物品 id 记录数量。GameState.inventory 是玩家的背包。

signal changed

var _counts := {}
var _order: Array[String] = []


## 放入物品，返回实际放入的数量（受 max_stack 限制）。
func add(item: ItemData, n := 1) -> int:
	if item == null or n <= 0:
		return 0
	var cap := item.max_stack if item.stackable else 1
	var have := count(item.id)
	var added := mini(n, cap - have)
	if added <= 0:
		return 0
	if not _counts.has(item.id):
		_order.append(item.id)
	_counts[item.id] = have + added
	changed.emit()
	return added


func remove(id: String, n := 1) -> bool:
	if n <= 0:
		return true
	if count(id) < n:
		return false
	_counts[id] -= n
	if _counts[id] <= 0:
		_counts.erase(id)
		_order.erase(id)
	changed.emit()
	return true


func count(id: String) -> int:
	return _counts.get(id, 0)


func has(id: String, n := 1) -> bool:
	return count(id) >= n


## 按获得顺序返回背包里的物品。
func items() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for id in _order:
		var it := ItemDB.get_item(id)
		if it:
			out.append(it)
	return out


## 使用某个物品（成功则消耗 1 个）。
func use(id: String, user: Node) -> bool:
	var it := ItemDB.get_item(id)
	if it == null or not has(id) or not it.can_use(user):
		return false
	if it.use(user):
		remove(id)
		return true
	return false


## 使用快捷键（use_item = Q / use_special = R）绑定的物品（GameState.hotkeys，背包里可以改）。
func use_hotkey(user: Node, hotkey := "use_item") -> bool:
	var id := GameState.hotkey_item(hotkey)
	return id != "" and use(id, user)


func clear() -> void:
	_counts.clear()
	_order.clear()
	changed.emit()

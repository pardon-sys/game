class_name InteractHint
extends Node2D
## 反省篇地图里可交互的东西：公主走到 HINT_R 以内，头顶浮出一个半透明的交互键图标（和 E 提示同一张图）；再走近、出现原来的 E 提示时就让给 E 提示。
## Interactable._ready 自动挂（只在 MAPS 那些地图）；放在关卡的 Entities 下（等距地图里自己是投影根，跟着投影）。
## 不显示：交互关掉了（enabled = false）、看不见、父节点的 done_flag 已经有了（做过的事件）、已经是哪位公主的 E 提示目标。

const HINT_R := 80.0
const MAPS := ["floor_06_penance", "floor_06_rat_tunnel", "floor_06_waterway", "floor_06_palace"]   # 同 level_exit.gd 的 MARKER_MAPS

var target: Interactable
var _t := 0.0
var _key: Sprite2D
const KEY_TEX := "res://assets/generated/items.png"   # 同 princess.tscn 的 Prompt：hframes 8，第 7 帧是 E 键


static func wants(it: Interactable) -> bool:
	if it.get_parent() is PlayableCharacter:
		return false   # 搭档身上的那个（换人 / 互动）不用提示
	var fid := level_floor(it)
	return MAPS.any(func(p): return fid.begins_with(p))


static func level_floor(n: Node) -> String:
	while n:
		var v: Variant = n.get("floor_id")
		if v != null and str(v) != "":
			return str(v)
		n = n.get_parent()
	return ""


static func attach(it: Interactable) -> void:
	if not wants(it):
		return
	var lv: Node = it
	while lv and str(lv.get("floor_id") if lv.get("floor_id") != null else "") == "":
		lv = lv.get_parent()
	if lv == null:
		return
	var host: Node = lv.get_node_or_null("Entities")
	if host == null:
		host = lv
	var h := InteractHint.new()
	h.target = it
	h.z_index = 40
	host.add_child(h)


func _ready() -> void:
	visible = false
	_key = Sprite2D.new()
	_key.texture = load(KEY_TEX)
	_key.hframes = 8
	_key.frame = 7
	_key.modulate = Color(1, 1, 1, 0.6)
	_key.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_key)


func showing() -> bool:
	if not is_instance_valid(target) or not target.enabled or not target.is_visible_in_tree():
		return false
	var p := target.get_parent()
	var df: Variant = p.get("done_flag") if p else null
	if df != null and str(df) != "" and GameState.has_flag(str(df)):
		return false
	if GameState.in_dialogue or GameState.in_cutscene or Dialogue.is_active() or CG.is_busy():
		return false
	var near := false
	for pc in get_tree().get_nodes_in_group("player_chars"):
		if pc.get("_target") == target:
			return false
		if pc.is_in_group("player") and (pc as Node2D).global_position.distance_to(target.global_position) <= HINT_R:
			near = true
	return near


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	_t += delta
	global_position = target.global_position
	var v := showing()
	if v != visible:
		visible = v
	if visible:
		_key.position = Vector2(target.prompt_offset.x, target.prompt_offset.y + sin(_t * 4.0) * 1.5).round()

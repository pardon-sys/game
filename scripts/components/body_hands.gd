class_name BodyHands
extends Node2D
## 身上的小手（可复用组件，节点名 "BodyHands"，挂在角色的 Sprite 下面，跟着小人的抬起 / 翻转走）：
##   按部位在小人身上画出小紫手（部位位置读角色的部位表 body 偏移），手指两帧轮流蠕动、轻轻抖。
##   一个部位多只手时按小螺旋错开（大腿 / 屁股上会叠成一团）；一个部位最多画 MAX_DRAW 只。
##   新抓上来的手：从大一圈「啪」地压扁再回弹 + 一圈紫光（add / set_hands(animate)）。
##   有 HandCover 时自动跟着它（hands_changed）；过场里没有 HandCover，就直接 add / set_hands / clear。

const ARM := preload("res://assets/generated/thousand_hand_arm.png")
const SIZE := 8.0
const MAX_DRAW := 6
const POP_TIME := 0.22
## 螺旋错开（像素）
const SPIRAL := [Vector2(0, 0), Vector2(2, -2), Vector2(-2, -1), Vector2(1, 2), Vector2(-2, 2), Vector2(3, 0)]

var hands := {}
var _t := 0.0
## [部位, 第几只, 已经过的秒数]
var _pops: Array = []
var _cover: HandCover
var _body := {}


static func of(c: Node) -> BodyHands:
	if c == null:
		return null
	var s := c.get_node_or_null("Sprite")
	return s.get_node_or_null("BodyHands") as BodyHands if s else null


static func attach(c: Node) -> BodyHands:
	var b := of(c)
	if b:
		return b
	var s := c.get_node_or_null("Sprite") as Node2D
	if s == null:
		return null
	b = BodyHands.new()
	b.name = "BodyHands"
	s.add_child(b)
	return b


func _ready() -> void:
	z_index = 1
	_load_body()
	var c := _actor()
	if c:
		_cover = HandCover.of(c)
	if _cover:
		hands = _cover.hands.duplicate()
		_cover.hands_changed.connect(_on_cover_changed)


func _actor() -> Node:
	var s := get_parent()
	return s.get_parent() if s else null


## 部位在小人身上的位置（相对脚底）：角色的部位表（data/characters/<id>/ticklish.json 的 body），没有就用公主的。
func _load_body() -> void:
	var c := _actor()
	var id := str(c.get("character_id")) if c and c.get("character_id") != null else ""
	var path := "res://data/characters/%s/ticklish.json" % id
	if id == "" or not FileAccess.file_exists(path):
		path = "res://data/actors/princess_ticklish.json"
	var f := FileAccess.open(path, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if data is Dictionary:
		for z in (data as Dictionary).get("zones", {}):
			var b: Variant = data["zones"][z].get("body")
			if b is Array and (b as Array).size() == 2:
				_body[z] = Vector2(float(b[0]), float(b[1]))


func _on_cover_changed(zone: String, n: int, _total: int) -> void:
	var before := int(hands.get(zone, 0))
	hands = _cover.hands.duplicate()
	if zone != "" and n > before:
		_pop(zone, n - 1)


func total() -> int:
	var n := 0
	for z in hands:
		n += int(hands[z])
	return n


## 加一只手（带抓上来的动画）。
func add(zone: String, n := 1) -> void:
	for i in n:
		hands[zone] = int(hands.get(zone, 0)) + 1
		_pop(zone, int(hands[zone]) - 1)


## 整个换掉；animate = 新多出来的手都弹一下。
func set_hands(h: Dictionary, animate := false) -> void:
	var old := hands
	hands = h.duplicate()
	if animate:
		for z in hands:
			for i in range(int(old.get(z, 0)), int(hands[z])):
				_pop(z, i)


## 手散开（散成几点紫光）。
func clear(animated := true) -> void:
	if animated and total() > 0:
		var c := _actor() as Node2D
		if c and c.get_parent():
			Fx.burst(c.get_parent(), c.global_position + Vector2(0, -12), "crystal", mini(total(), 10), 26.0, 0.4, Vector2(0, 20),
				Color(0.85, 0.55, 1.0))
	hands = {}
	_pops.clear()


func _pop(zone: String, i: int) -> void:
	_pops.append([zone, i, 0.0])


func _process(delta: float) -> void:
	_t += delta
	for p in _pops:
		p[2] += delta
	_pops = _pops.filter(func(p): return p[2] < POP_TIME + 0.2)
	visible = total() > 0
	if visible:
		queue_redraw()


## 部位的位置（相对 Sprite = 相对脚底，抬起 / 姿势偏移由 Sprite 自己的位置带着；Sprite 翻转时左右镜像）。
func zone_pos(zone: String) -> Vector2:
	var b: Vector2 = _body.get(zone, Vector2(0, -12))
	var s := get_parent() as Sprite2D
	if s and s.flip_h:
		b.x = -b.x
	return b


func _pop_scale(zone: String, i: int) -> float:
	for p in _pops:
		if p[0] == zone and p[1] == i:
			var k := clampf(p[2] / POP_TIME, 0.0, 1.0)
			# 大一圈 → 压扁 → 回弹到 1
			return lerpf(1.9, 1.0, k) if k < 0.6 else 1.0 + sin((k - 0.6) / 0.4 * PI) * -0.18
	return 1.0


func _draw() -> void:
	for z in hands:
		var n := mini(int(hands[z]), MAX_DRAW)
		for i in n:
			var base: Vector2 = zone_pos(z) + SPIRAL[i % SPIRAL.size()]
			var phase := _t * 7.0 + i * 1.7 + float(z.hash() % 7)
			var jitter := Vector2(sin(phase * 1.3), cos(phase)) * 0.5
			var s := _pop_scale(z, i)
			var size := Vector2(SIZE, SIZE) * s
			var f := 2 + int(phase) % 2
			draw_texture_rect_region(ARM, Rect2(base + jitter - size / 2.0, size), Rect2(f * 24, 0, 24, 24),
				Color(0.95, 0.72, 1.0, 0.95))
			if s > 1.05:
				draw_arc(base, 5.0 * s, 0, TAU, 16, Color(0.85, 0.5, 1.0, (s - 1.0)), 1.0)
		if int(hands[z]) > MAX_DRAW:
			draw_circle(zone_pos(z) + Vector2(4, -3), 1.5, Color(1, 0.8, 1.0))

class_name BareFloor
extends Node2D
## 光脚地面（骑士篇支线「骑士救公主」：鞋被孩子们抢走了）：只对光着脚的粉色公主生效（meta barefoot；冲刺踩过去也算）。
##   straw   晒着的稻草垫：每走 STRAW_STEP 像素扎一下脚心，闷笑 +STRAW_LAUGH
##   feather 庆功宴剩下的羽毛堆：站在里面闷笑每秒 +FEATHER_RATE，走得慢（状态 feather_floor，×0.6）
##   pebble  鹅卵石小路：每 PEBBLE_FLIP 秒在「闷笑 +PEBBLE_RATE」和「疲倦 +PEBBLE_RATE（舒服）」之间来回换
## 闷笑最多涨到 MAX_LAUGH（小镇里不会笑晕）。图用小镇道具图集的 straw_mat / feather_pile / pebble_path 铺满 size（格）。
## 踩到时脚下冒小特效，隔一会儿冒一句反应（reacts，支线文本给）。
## 生成：BareFloor.make(父节点, 种类, 左上角的格, 大小（格）)。测试：walked、inside(角色)、tick(角色, 秒)。

const STRAW_STEP := 10.0
const STRAW_LAUGH := 0.015
const FEATHER_RATE := 0.04
const PEBBLE_RATE := 0.03
const PEBBLE_FLIP := 1.0
const MAX_LAUGH := 0.97
const SAY_EVERY := 3.0
## 小镇道具的图集（prop.gd 没有 class_name）
const PROP := preload("res://scripts/objects/prop.gd")
const TEXTURE := {"straw": "straw_mat", "feather": "feather_pile", "pebble": "pebble_path"}

var kind := "straw"
var size_cells := Vector2i(2, 1)
var reacts: Array = []
var walked := 0.0
var _last := Vector2.INF
var _flip := 0.0
var _say := 0.0


static func make(parent: Node, k: String, cell: Vector2i, cells: Vector2i, lines: Array = []) -> BareFloor:
	var f := BareFloor.new()
	f.kind = k
	f.size_cells = cells
	f.reacts = lines
	# 铺在地面层（关卡的 FloorObjects，和地毯、楼梯一样画在地砖上、人物下面）
	var floor_layer: Node = parent.get_parent().get_node_or_null("FloorObjects") if parent.name == "Entities" and parent.get_parent() else null
	(floor_layer if floor_layer else parent).add_child(f)
	f.global_position = Cells.to_world(cell) - Vector2(8, 8)
	return f


func _ready() -> void:
	add_to_group("bare_floor")


func rect() -> Rect2:
	return Rect2(global_position, Vector2(size_cells) * 16.0)


static func barefoot(c: Node) -> bool:
	return c is PlayableCharacter and not c is BluePrincess and c.has_meta(&"barefoot")


func inside(c: PlayableCharacter) -> bool:
	return rect().has_point(c.global_position)


func _process(delta: float) -> void:
	if GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	if not barefoot(p):
		for c in get_tree().get_nodes_in_group("player_chars"):
			if barefoot(c):
				p = c
	if barefoot(p) and inside(p):
		tick(p, delta)
	else:
		_last = Vector2.INF


## 一帧：她光脚站在这片地面上
func tick(c: PlayableCharacter, delta: float) -> void:
	if not c.laugh:
		return
	var cap := c.laugh.max_value * MAX_LAUGH
	match kind:
		"straw":
			if _last != Vector2.INF:
				walked += c.global_position.distance_to(_last)
			_last = c.global_position
			if walked >= STRAW_STEP:
				walked -= STRAW_STEP
				_add_laugh(c, c.laugh.max_value * STRAW_LAUGH, cap)
				ZoneFx.play("sole", c.get_parent(), ZoneFx.body_point(c, "sole"), 0.6, false)
		"feather":
			c.add_buff("feather_floor", 0.3)
			_add_laugh(c, c.laugh.max_value * FEATHER_RATE * delta, cap)
			if randf() < delta * 2.0:
				Fx.burst(c.get_parent(), c.global_position, "feather", 2, 12.0, 0.4, Vector2(0, -2))
		"pebble":
			_flip += delta
			var comfy := int(_flip / PEBBLE_FLIP) % 2 == 1
			if comfy:
				if c.fatigue:
					c.fatigue.add(c.fatigue.max_value * PEBBLE_RATE * delta)
			else:
				_add_laugh(c, c.laugh.max_value * PEBBLE_RATE * delta, cap)
	_say -= delta
	if _say <= 0.0 and not reacts.is_empty():
		_say = SAY_EVERY
		SpeechBubble.say(c, str(reacts.pick_random()), 30.0, 1.4)


func _add_laugh(c: PlayableCharacter, amount: float, cap: float) -> void:
	if c.laugh.value < cap:
		c.laugh.add(minf(amount, cap - c.laugh.value))


func _draw() -> void:
	var m: Dictionary = PROP.meta().get(TEXTURE.get(kind, ""), {})
	var r: Array = m.get("region", [])
	if r.size() != 4:
		return
	var src := Rect2(r[0], r[1], r[2], r[3])
	var y := 0.0
	while y < size_cells.y * 16.0:
		var x := 0.0
		while x < size_cells.x * 16.0:
			draw_texture_rect_region(PROP.SHEET, Rect2(x, y, minf(src.size.x, size_cells.x * 16.0 - x), minf(src.size.y, size_cells.y * 16.0 - y)),
				Rect2(src.position, Vector2(minf(src.size.x, size_cells.x * 16.0 - x), minf(src.size.y, size_cells.y * 16.0 - y))))
			x += src.size.x
		y += src.size.y

class_name PalaceMemory
extends PalaceRoom
## 第四章尾声·画里的记忆（floor_06_palace_memory；台词 penance_text/palace9.py；配乐 palace_memory；一直开着画中世界的水彩滤镜）：
##   王座间打完 Boss、两半徽章合在一起（joined_badge）以后，在画前按 E 进来。一条路走过四段记忆：
##   婴儿房（memory_cradles → 小剧场 memory_nursery，CG）→ 画室（memory_easel → 过场 memory_portrait）→ 钟楼顶（memory_bell → 过场 memory_sacrifice）
##   → 走廊尽头的旧门（memory_door → 过场 memory_key）。每段之间一道铅笔线画的门（gate1 / gate2 / gate3，PencilGate），上一段看完才化开。
##   最后一段看完：EPILOGUE_FLAG → 回王座间（spawn from_memory），王座间演 palace_memory_out（画像闭着眼睛 → 章末）。
## 测试：gates_open()、finish()。

const MAP := "floor_06_palace_memory"
const EPILOGUE_FLAG := "palace_memory_done"
const STEP_FLAGS := ["palace_memory_1", "palace_memory_2", "palace_memory_3", "palace_memory_4"]
const GATE_KEYS := ["gate1", "gate2", "gate3"]
var gates: Array = []
var _water: ThroneFx.Watercolor
var _leaving := false


func map_id() -> String:
	return MAP


func _ready() -> void:
	super()
	_water = ThroneFx.Watercolor.new()
	get_tree().root.add_child.call_deferred(_water)
	# 婴儿房的两个摇篮（粉 / 蓝丝带）、画室的画架、钟楼顶的大钟、走廊尽头的旧门
	var ci := 0
	for c in cells("cradles"):
		sheet_view(PalaceRoom.PROPS3, 6, 1 + ci % 2, c, [], 0.9)
		ci += 1
	_spot("floor_06/memory_cradles", cells("nursery")[0], "palace_memory_1")
	var easel := ThroneParts.fx_sprite(4, 0.9)
	_hold(easel, cells("easel")[0], -40.0)
	_spot("floor_06/memory_easel", cells("easel")[0], "palace_memory_2")
	sheet_view("res://assets/generated/clock_props.png", 6, 3, cells("bell")[0], [], 1.2)
	_spot("floor_06/memory_bell", cells("bell")[0] + Vector2i(0, 1), "palace_memory_3")
	sheet_view("res://assets/generated/exit_markers.png", 5, 2, cells("door")[0], [], 1.2)
	_spot("floor_06/memory_door", cells("door")[0] + Vector2i(0, 1), "palace_memory_4")
	for i in GATE_KEYS.size():
		var g := PencilGate.new()
		g.room = self
		g.need = STEP_FLAGS[i]
		g.cells_ = cells(GATE_KEYS[i])
		add_child(g)
		gates.append(g)
	for c in cells("pencil"):
		var pv := PencilRoom.new()
		pv.position = world(c)
		add_view(pv)


func _hold(spr: Sprite2D, c: Vector2i, lift: float) -> void:
	var n := Node2D.new()
	n.position = world(c)
	spr.offset = Vector2(0, lift / spr.scale.y)
	n.add_child(spr)
	add_view(n)


func _spot(dialogue: String, c: Vector2i, done := "") -> void:
	var sp := PrisonOddities.Spot.new()
	sp.dialogue = dialogue
	sp.done_flag = done
	add_child(sp)
	sp.global_position = world(c)


func gates_open() -> Array:
	return gates.map(func(g): return (g as PencilGate).open)


func _exit_tree() -> void:
	if is_instance_valid(_water):
		_water.queue_free()
	super()


func _process(_delta: float) -> void:
	if busy() or _leaving:
		return
	if GameState.has_flag(STEP_FLAGS[3]) and not GameState.has_flag(EPILOGUE_FLAG):
		finish()


## 四段都看完了：回王座间（那边演 palace_memory_out → 章末）
func finish() -> void:
	if _leaving:
		return
	_leaving = true
	GameState.set_flag(EPILOGUE_FLAG)
	GameState.pending_spawn = "from_memory"
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("change_level"):
		main.change_level(Floors.scene(PalaceThrone.MAP))


## 铅笔线画的门：一排格子挡着（StaticBody），上一段记忆看完（need）就化开
class PencilGate extends Node:
	var room: PalaceMemory
	var need := ""
	var cells_: Array = []
	var open := false
	var _body: StaticBody2D
	var _views: Array = []

	func _ready() -> void:
		open = GameState.has_flag(need)
		if open:
			return
		_body = StaticBody2D.new()
		_body.collision_layer = 1
		for c in cells_:
			var sh := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			r.size = Vector2(16, 16)
			sh.shape = r
			sh.position = PalaceRoom.cell_pos(c)
			_body.add_child(sh)
			var v := PencilWall.new()
			v.position = room.world(c)
			room.add_view(v)
			_views.append(v)
		room.add_child.call_deferred(_body)

	func _process(_d: float) -> void:
		if open or not GameState.has_flag(need):
			return
		open = true
		Audio.play("paper", -4.0, 0.0, 0.9)
		if is_instance_valid(_body):
			_body.queue_free()
		for v in _views:
			if is_instance_valid(v):
				var tw := (v as Node2D).create_tween()
				tw.tween_property(v, "modulate:a", 0.0, 0.8)
				tw.tween_callback((v as Node).queue_free)


## 铅笔线的一格墙（灰白虚线框，轻轻地抖）
class PencilWall extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		z_index = 1

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var j := sin(_t * 3.0) * 0.6
		var h := 26.0
		for k in 6:
			var y := -h * k / 6.0
			draw_line(IsoView.offset(Vector2(-8, -8)) + Vector2(j, y), IsoView.offset(Vector2(8, 8)) + Vector2(-j, y), Color(0.35, 0.35, 0.4, 0.55), 1.0)
		var pts := PackedVector2Array([IsoView.offset(Vector2(-8, -8)), IsoView.offset(Vector2(8, -8)), IsoView.offset(Vector2(8, 8)), IsoView.offset(Vector2(-8, 8)), IsoView.offset(Vector2(-8, -8))])
		for i in pts.size():
			pts[i] += Vector2(0, -h)
		draw_polyline(pts, Color(0.3, 0.3, 0.35, 0.7), 1.0)


## 只有铅笔线轮廓的房间（装饰）：画在墙边，一个没上色的房间轮廓
class PencilRoom extends Node2D:
	func _ready() -> void:
		z_index = 1

	func _draw() -> void:
		var r := Rect2(-40, -40, 80, 80)
		var pts := PackedVector2Array([IsoView.offset(r.position), IsoView.offset(Vector2(r.end.x, r.position.y)), IsoView.offset(r.end),
			IsoView.offset(Vector2(r.position.x, r.end.y)), IsoView.offset(r.position)])
		for i in 3:
			var off := Vector2(0, -i * 12.0)
			var q := PackedVector2Array()
			for p in pts:
				q.append(p + off)
			draw_polyline(q, Color(0.3, 0.3, 0.36, 0.35 - i * 0.08), 1.0)
		draw_line(IsoView.offset(Vector2(-10, 0)), IsoView.offset(Vector2(10, 0)) + Vector2(0, -20), Color(0.3, 0.3, 0.36, 0.3), 1.0)

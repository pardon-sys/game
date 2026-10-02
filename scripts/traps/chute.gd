class_name ChuteTrap
extends Trap
## 痒痒滑梯（CONTINUOUS，多格：从所在格向右 tiles_w 格、向下 tiles_h 格，强制位移）：踩上任何一格就沿 dir 一直滑
## （方向固定，不受操作影响，不能冲刺），滑到滑梯尽头再滑出一小段才停；滑行中每 brush_interval 秒刷一下屁股。
## 滑到「现在会困住人」的束缚陷阱上就停下被困住（RestraintTrap.would_grab）；刚从那个陷阱放开的人继续往下滑——
## 所以滑梯尽头接束缚陷阱、陷阱下面再接一段滑梯，就是一条连锁。按人的脚底位置决定在哪一段滑梯上（拐角不会打架）。

const SHEET := preload("res://assets/generated/chute.png")

@export var tiles_w := 1
@export var tiles_h := 1
@export var dir := "right"
@export var slide_speed := 110.0
@export var brush_interval := 0.3

var lane := Vector2.RIGHT
var brushes := 0
var _tiles: Array[Sprite2D] = []
var _anim := 0.0
var _next_brush := {}


func _setup() -> void:
	trigger_mode = TriggerMode.CONTINUOUS
	hit_kind = HitData.Kind.TICKLE
	lane = Trap.dir_vector(dir)
	for y in tiles_h:
		for x in tiles_w:
			var s := Sprite2D.new()
			s.texture = SHEET
			s.hframes = 2
			s.position = Vector2(x, y) * 16.0
			s.frame = (x + y) % 2
			s.rotation = lane.angle() if lane.x == 0.0 else 0.0
			s.z_index = -1
			add_child(s)
			_tiles.append(s)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tiles_w * 16.0 - 2.0, tiles_h * 16.0 - 2.0)
	var shape := $Shape as CollisionShape2D
	shape.shape = rect
	shape.position = Vector2(tiles_w - 1, tiles_h - 1) * 8.0
	queue_redraw()


## 某个世界坐标在不在这段滑梯上。
func covers(pos: Vector2) -> bool:
	var p := to_local(pos)
	return p.x >= -8.0 and p.y >= -8.0 and p.x < tiles_w * 16.0 - 8.0 and p.y < tiles_h * 16.0 - 8.0


func _physics_process(delta: float) -> void:
	super(delta)
	if not is_dangerous() or GameState.in_dialogue:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var v := lane * slide_speed
	for body in _victims():
		var pc := body as PlayableCharacter
		if pc == null or not pc.is_alive() or not covers(pc.global_position):
			continue
		if on_stopper(pc):
			if pc.is_force_moving() and pc.forced_kind == "slide":
				pc.end_forced_move()
			continue
		if pc.is_force_moving():
			if pc.forced_kind != "slide":
				continue
			if pc.forced_velocity() != v:
				pc.force_move(v, 0.1, "slide")
			else:
				pc.extend_forced_move(0.1)
		elif pc.can_act():
			if not pc.force_move(v, 0.1, "slide"):
				continue
			Audio.play("swish", -10.0, 0.1, 0.8)
		if pc.is_force_moving() and now >= float(_next_brush.get(pc.get_instance_id(), 0.0)):
			_next_brush[pc.get_instance_id()] = now + brush_interval
			if pc.receive_hit(make_hit()):
				brushes += 1
				Audio.play("tickle", -9.0, 0.12, tickle_pitch)


## 是否站在现在会困住人的束缚陷阱（或足枷台、藤蔓、毛毯这类会定身的陷阱）上。
func on_stopper(pc: Node2D) -> bool:
	for t in get_tree().get_nodes_in_group("slide_stopper"):
		var tr := t as Trap
		if tr == null or not tr.active or not tr.overlaps_body(pc):
			continue
		if tr is RestraintTrap and not (tr as RestraintTrap).would_grab(pc):
			continue
		return true
	return false


func _apply_effect(_target: Node) -> bool:
	return false


func _process(delta: float) -> void:
	_anim += delta
	if _anim >= 0.25:
		_anim = 0.0
		for s in _tiles:
			s.frame = 1 - s.frame


## 每格画一个滑行方向的小箭头。
func _draw() -> void:
	var side := lane.orthogonal() * 3.0
	for y in tiles_h:
		for x in tiles_w:
			var c := Vector2(x, y) * 16.0
			var tip := c + lane * 5.0
			var base := c - lane * 1.0
			draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(1, 0.5, 0.75, 0.85))

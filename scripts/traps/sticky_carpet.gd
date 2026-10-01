class_name StickyCarpet
extends Trap
## 黏黏毛毯（CONTINUOUS，多格：从所在格向右 tiles_w 格、向下 tiles_h 格）：
## 走在上面持续「黏黏」（移速 ×0.4）；站着不动超过 still_time 秒会被黏住（定身 stick_time 秒）；
## 每 repeat_interval 秒被绒毛轻挠 tickle，失控时 ×2。

const SHEET := preload("res://assets/generated/carpet.png")

@export var tiles_w := 1
@export var tiles_h := 1
@export var still_time := 1.0
@export var stick_time := 1.0

## 每个目标站着不动的时间：{instance_id: 秒}
var _still := {}
var _anim := 0.0
var _tiles: Array[Sprite2D] = []


func _setup() -> void:
	stops_slide = true
	hit_kind = HitData.Kind.TICKLE
	trigger_mode = TriggerMode.CONTINUOUS
	for y in tiles_h:
		for x in tiles_w:
			var s := Sprite2D.new()
			s.texture = SHEET
			s.hframes = 2
			s.position = Vector2(x, y) * 16.0
			s.frame = (x + y) % 2
			add_child(s)
			_tiles.append(s)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tiles_w * 16.0 - 2.0, tiles_h * 16.0 - 2.0)
	var shape := $Shape as CollisionShape2D
	shape.shape = rect
	shape.position = Vector2(tiles_w - 1, tiles_h - 1) * 8.0
	Fx.emitter(self, "goo", 2 * tiles_w * tiles_h, 1.4, {"offset": shape.position, "extents": rect.size / 2.0 - Vector2(2, 2),
			"speed": [2.0, 5.0], "spread": 20.0, "z": 0})


func _physics_process(delta: float) -> void:
	super(delta)
	if not is_dangerous() or GameState.in_dialogue:
		return
	var seen := {}
	for body in _victims():
		var a := body as Actor
		if a == null or not a.is_alive():
			continue
		var id := a.get_instance_id()
		seen[id] = true
		a.add_buff("sticky", 0.3)
		if a.status == null or a.status.is_immobile():
			_still[id] = 0.0
			continue
		var moving := a.velocity.length() > 8.0
		_still[id] = 0.0 if moving else float(_still.get(id, 0.0)) + delta
		if _still[id] >= still_time:
			_still[id] = -0.8  # 黏住后给一点挣脱的空档
			a.status.apply_root(stick_time)
			Audio.play("puddle", -6.0, 0.1, 1.3)
	for id in _still.keys():
		if not seen.has(id):
			_still.erase(id)


func _process(delta: float) -> void:
	_anim += delta
	var f := int(_anim * 2.0) % 2
	for i in _tiles.size():
		_tiles[i].frame = (f + i) % 2


func _apply_effect(target: Node) -> bool:
	var h := make_hit()
	var a := target as Actor
	if a and a.laugh and a.laugh.is_helpless():
		h.tickle *= 2.0
	var ok: bool = target.receive_hit(h)
	if ok:
		Audio.play("tickle", -9.0, 0.12, tickle_pitch)
	return ok

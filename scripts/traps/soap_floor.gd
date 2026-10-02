class_name SoapFloor
extends Trap
## 滑溜肥皂地板（CONTINUOUS，多格：从所在格向右 tiles_w 格、向下 tiles_h 格，强制位移）：
## 在上面一动就沿移动方向（上下左右）一直滑，直到撞墙、离开地板，或碰到会抓人 / 定身的陷阱
## （足枷台、藤蔓、黏黏毛毯：Trap.stops_slide）才停。滑行中不能换方向、不能冲刺。

const SHEET := preload("res://assets/generated/soap.png")

@export var tiles_w := 1
@export var tiles_h := 1
@export var slide_speed := 120.0
## 开始滑的最小速度（站着不动不会滑）。
@export var start_speed := 12.0

var _tiles: Array[Sprite2D] = []
var _anim := 0.0


func _setup() -> void:
	trigger_mode = TriggerMode.CONTINUOUS
	hit_kind = HitData.Kind.TICKLE
	tickle = 0.0
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
	Fx.emitter(self, "goo", 2 * tiles_w * tiles_h, 1.2, {"offset": shape.position, "extents": rect.size / 2.0 - Vector2(2, 2),
			"speed": [2.0, 6.0], "spread": 30.0, "color": Color(0.8, 0.93, 1.0), "z": 0})


func _physics_process(delta: float) -> void:
	super(delta)
	if not is_dangerous() or GameState.in_dialogue:
		return
	for body in _victims():
		var pc := body as PlayableCharacter
		if pc == null or not pc.is_alive():
			continue
		if pc.is_force_moving():
			if pc.forced_kind != "slide":
				continue
			if on_stopper(pc):
				pc.end_forced_move()
			else:
				pc.extend_forced_move(0.1)
		elif pc.can_be_moved() and pc.get_real_velocity().length() >= start_speed and not on_stopper(pc):
			# 按实际移动方向（含传送带 / 风扇的推力：笑瘫了被推上来也会滑）
			var v := pc.get_real_velocity()
			var d := Vector2(signf(v.x), 0.0) if absf(v.x) >= absf(v.y) else Vector2(0.0, signf(v.y))
			if pc.test_move(pc.global_transform, d * 2.0):
				continue  # 贴着墙往墙上推：不滑
			if pc.force_move(d * slide_speed, 0.1, "slide"):
				Audio.play("puddle", -10.0, 0.1, 1.5)


## 是否站在会抓人 / 定身的陷阱上（滑到这里停下）。
func on_stopper(pc: Node2D) -> bool:
	for t in get_tree().get_nodes_in_group("slide_stopper"):
		var tr := t as Trap
		if tr and tr.active and tr.overlaps_body(pc):
			return true
	return false


## 地板本身不挠痒。
func _apply_effect(_target: Node) -> bool:
	return false


func _process(delta: float) -> void:
	_anim += delta
	if _anim >= 0.5:
		_anim = 0.0
		for s in _tiles:
			s.frame = 1 - s.frame

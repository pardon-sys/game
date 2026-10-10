class_name HangingHands
extends LegTrap
## 垂落吊手（第八层夜迷宫）：头顶的黑暗里垂着千手的手臂。她踩进这一格 → 地上先出现一圈越缩越小的影子（预警 WARN 秒），
## 还在圈里就被垂下来的手臂抓住腰吊起来：抬高 lift 像素、左右晃，挠腰和肚子 lock_time 秒（连按 presses 下挣脱）；
## 吊起来的一瞬间，她身上已有的手（HandCover）一起挠一下（pulse）。来源键 hanging_hands。
## 图例：X = trap type=hanging_hands

const ARM := preload("res://assets/generated/thousand_hand_arm.png")
const LIGHT_TEX := preload("res://assets/lights/light_soft.tres")
const WARN := 0.6
const DROP := 0.18

var _drop_t := 0.0
var _vt := 0.0
## 垂下来的手臂单独一层（画在墙块前面：从天上垂下来的）
var _arms: Node2D
## 手臂自己发一点紫光（迷宫很暗，不然看不见）：预警时微亮，吊起来时亮
var _glow: PointLight2D


func _restraint_setup() -> void:
	super()
	reaction_key = "hanging_hands"
	hit_fx = "hand"
	exposed = {"waist": 1.3, "belly": 1.3}
	zone_cycle.assign([{"waist": 1.0}, {"belly": 1.0}])
	tickle_zones = zone_cycle[0].duplicate()
	cycle_time = 0.8
	ramp = 0.08
	self_tickle = 1.8
	self_interval = 0.4
	_base_interval = self_interval
	lock_time = 2.5
	presses = 8
	cooldown_time = 4.0
	warn_time = WARN
	lift = 8.0
	swing = 0.12
	reach = 0
	collision_mask = 2
	if get_node_or_null("Shape") == null:
		var cs := CollisionShape2D.new()
		cs.name = "Shape"
		var r := RectangleShape2D.new()
		r.size = Vector2(12, 10)
		cs.shape = r
		add_child(cs)
	if sprite:
		sprite.visible = false
	_arms = Node2D.new()
	_arms.z_index = 6
	_arms.draw.connect(_draw_arms)
	add_child(_arms)
	_glow = PointLight2D.new()
	_glow.texture = LIGHT_TEX
	_glow.texture_scale = 0.6
	_glow.color = Color(0.75, 0.45, 1.0)
	_glow.energy = 0.0
	_glow.height = 20.0
	_glow.position = Vector2(0, -24)
	add_child(_glow)


func _on_warn() -> void:
	super()
	Audio.play("rumble", -12.0, 0.1, 1.6)


func _hold_point() -> Vector2:
	return global_position + Vector2(0, 2)


func _fx_restrain(a: Actor) -> void:
	_drop_t = DROP
	Audio.play("hand_grab", -2.0, 0.05, 0.9)
	var hc := HandCover.of(a)
	if hc:
		hc.pulse(3.0)
	if a is PlayableCharacter and (a as PlayableCharacter).is_controlled():
		GameState.princess_reacted.emit(MazeLines.pick("hanging"), 2.2)


func _process(delta: float) -> void:
	_vt += delta
	_drop_t = maxf(0.0, _drop_t - delta)
	queue_redraw()
	if _arms:
		_arms.queue_redraw()
	if _glow:
		var want := 0.9 if is_holding() else (0.35 if phase == Phase.WARN else 0.0)
		_glow.energy = move_toward(_glow.energy, want, delta * 4.0)


func _draw() -> void:
	# 预警：地上一圈越缩越小的紫影
	if phase == Phase.WARN:
		var k := clampf(_t / WARN, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, IsoView.ground_scale())
		draw_circle(Vector2.ZERO, lerpf(12.0, 6.0, k), Color(0.25, 0.05, 0.35, 0.25 + 0.35 * k))
		draw_arc(Vector2.ZERO, lerpf(14.0, 7.0, k), 0, TAU, 24, Color(0.85, 0.5, 1.0, 0.5 + 0.4 * sin(_vt * 30.0)), 1.0)
		draw_set_transform(Vector2.ZERO)
		return
	# 平时：一点点暗紫的影子（细心的话看得出来）
	if not is_holding():
		draw_set_transform(Vector2.ZERO, 0.0, IsoView.ground_scale())
		draw_circle(Vector2.ZERO, 6.0, Color(0.2, 0.05, 0.3, 0.18))
		draw_set_transform(Vector2.ZERO)
		return


## 吊着：两条手臂从上面垂下来，手掌扣在她腰上。
func _draw_arms() -> void:
	if not is_holding():
		return
	var top := -70.0
	var hand_y := -16.0 - lift + (_drop_t / DROP) * -30.0
	var sway := sin(_vt * 5.0) * 2.0
	for side in [-1.0, 1.0]:
		var x: float = side * 5.0
		# 一条连着的臂身（从黑暗里垂下来，越往上越淡），上面一节节的关节
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var y := top
		while y <= hand_y:
			pts.append(Vector2(x + sway * (y - top) / 70.0, y))
			cols.append(Color(0.78, 0.5, 1.0, clampf((y - top) / 30.0, 0.0, 0.95)))
			y += 4.0
		if pts.size() >= 2:
			_arms.draw_polyline_colors(pts, cols, 3.0)
		y = top + 14.0
		while y < hand_y - 6.0:
			_arms.draw_texture_rect_region(ARM, Rect2(Vector2(x + sway * (y - top) / 70.0 - 5, y - 5), Vector2(10, 10)),
				Rect2((int(y / 7.0) % 2) * 24, 0, 24, 24), Color(1.3, 1.0, 1.5, clampf((y - top) / 30.0, 0.0, 0.9)))
			y += 9.0
		var f: int = 2 + int(_vt * 8.0 + side) % 2
		_arms.draw_texture_rect_region(ARM, Rect2(Vector2(x + sway - 6, hand_y - 6), Vector2(12, 12)), Rect2(f * 24, 0, 24, 24),
			Color(0.95, 0.75, 1.0, 0.95))

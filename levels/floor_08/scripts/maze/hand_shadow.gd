class_name HandShadow
extends Node2D
## 千手的影子（第八层夜迷宫的巡逻者）：一团巨大的手影，沿固定路线（route，格子坐标）慢慢巡游，前面一片紫色的视野（VisionCone）。
## 它飘在迷宫上空：探照不被墙挡（VisionCone.ignore_walls），路线可以直线横穿墙（生成器给的是横扫迷宫的长直线）；
## 画面上抬高 FLOAT 像素、上下浮动，地上一团影子。她在光里（月光灯 / 光带）时看不见她。
## 看到她 → 停下来「看」LOOK 秒（可以趁这时跑出视野）；还看得到 → 她周围一下子涌出 3~5 只紫手、一阵凉意（来源键 hand_shadow），
## 然后接着巡逻（COOLDOWN 秒内不再召手）。冰晶结界冻住它 3 秒（maze_magic_reactive）。
## 图例：X = handshadow route=x,y;x,y;...

const TEX := preload("res://assets/generated/maze/hand_shadow.png")
const SPEED := 22.0
const LOOK := 1.0
const COOLDOWN := 8.0
## 飘多高（像素）
const FLOAT := 20.0

@export var route := ""

var reaction_key := "hand_shadow"
var cone: VisionCone
var sprite: Sprite2D
var _points: Array[Vector2] = []
var _i := 0
var _look := 0.0
var _cd := 0.0
var _frozen := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("hand_shadow")
	add_to_group("maze_magic_reactive")
	z_index = 4
	for part in route.split(";", false):
		var xy := part.split(",")
		if xy.size() == 2:
			_points.append(Vector2(int(xy[0]) * 16 + 8, int(xy[1]) * 16 + 12))
	sprite = Sprite2D.new()
	sprite.texture = TEX
	sprite.hframes = 2
	sprite.offset = Vector2(0, -26 - FLOAT)
	sprite.modulate = Color(1, 1, 1, 0.82)
	add_child(sprite)
	cone = VisionCone.new()
	cone.range_px = 112.0
	cone.angle_deg = 70.0
	cone.color = Color(0.65, 0.3, 0.95, 0.22)
	cone.alert_color = Color(0.95, 0.3, 0.75, 0.38)
	cone.position = Vector2(0, -2)
	cone.ignore_walls = true
	add_child(cone)


func route_points() -> Array[Vector2]:
	return _points


func on_ice(time: float) -> void:
	_frozen = maxf(_frozen, minf(time, 3.0))
	sprite.modulate = Color(0.7, 0.88, 1.35, 0.82)


func is_frozen() -> bool:
	return _frozen > 0.0


func _process(delta: float) -> void:
	_t += delta
	sprite.frame = int(_t * 2.0) % 2
	sprite.position.y = sin(_t * 1.5) * 3.0
	queue_redraw()
	if GameState.in_dialogue or CG.is_busy() or Cutscene.is_playing():
		return
	if _frozen > 0.0:
		_frozen -= delta
		if _frozen <= 0.0:
			sprite.modulate = Color(1, 1, 1, 0.82)
		return
	_cd = maxf(0.0, _cd - delta)
	var p := GameState.player as PlayableCharacter
	var sees := 0.0
	if is_instance_valid(p) and p.is_alive():
		var dir := get_tree().get_first_node_in_group("maze_director")
		var in_light: bool = dir != null and dir.light_at(p.global_position) is Vector2
		sees = 0.0 if in_light else cone.sees(p)
	cone.alerting = sees > 0.0
	if sees > 0.0 and _cd <= 0.0:
		_look += delta
		cone.facing = (p.global_position - global_position).normalized()
		if _look >= LOOK:
			_look = 0.0
			_cd = COOLDOWN
			_summon(p)
		return
	_look = 0.0
	_patrol(delta)


## 地上的影子（飘得越高越淡，跟着浮动一起缩放）。
func _draw() -> void:
	var k := 1.0 - (sin(_t * 1.5) * 3.0 + 3.0) / 30.0
	draw_set_transform(Vector2.ZERO, 0.0, IsoView.ground_scale())
	draw_circle(Vector2.ZERO, 11.0 * k, Color(0.12, 0.02, 0.2, 0.4))
	draw_circle(Vector2.ZERO, 6.0 * k, Color(0.12, 0.02, 0.2, 0.3))
	draw_set_transform(Vector2.ZERO)


func _summon(p: PlayableCharacter) -> void:
	Audio.play("grab", -2.0, 0.0, 0.6)
	ScreenFx.flash(Color(0.6, 0.2, 0.85), 0.3)
	var h := HitData.make_tickle(self, 3.0)
	p.receive_hit(h)
	SpeechBubble.say(p, "……被、被看到了……", 28.0)
	var dir := get_tree().get_first_node_in_group("maze_director")
	if dir and dir.has_method("summon_near"):
		dir.summon_near(randi_range(3, 5))


func _patrol(delta: float) -> void:
	if _points.is_empty():
		return
	var goal: Vector2 = _points[_i]
	var to := goal - global_position
	if to.length() < 3.0:
		_i = (_i + 1) % _points.size()
		return
	var step := to.normalized() * SPEED * delta
	global_position += step if step.length() < to.length() else to
	cone.facing = to.normalized()

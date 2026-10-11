class_name HazardBroom
extends SiegeHazard
## 城墙羽毛扫帚：巨大的羽毛扫帚沿城墙顶走道的某一行扫过去（先亮那一行的预警）。
## 走道有两行：站在另一行就躲开了（蓝色公主的 AI 会躲）；被扫到 → 挠一下并推下城墙。

const SWEEP := 2.2
const LANE_GAP := 16.0

var lane_y := 0.0
var _x := 0.0
var _hit := {}


func _begin() -> void:
	reaction_key = "hazard_broom"
	life = SWEEP
	var top := director.wall_top_y()
	lane_y = top + 4.0 if randf() < 0.5 else top - 12.0
	global_position = Vector2(0, lane_y)
	SiegeFx.lane(get_parent(), Vector2(0, lane_y), Vector2(director.map_size().x, lane_y), 12.0, Color(1, 0.4, 0.5), WARN)
	Audio.play("wind", -6.0, 0.1, 0.7)


## 这一行会被扫到吗（蓝色公主的 AI 用）。
func threatens(y: float) -> bool:
	return absf(y - lane_y) < LANE_GAP * 0.6


func safe_y() -> float:
	var top := director.wall_top_y()
	return top - 12.0 if absf(lane_y - (top + 4.0)) < 1.0 else top + 4.0


func _on_start() -> void:
	Audio.play("swish", -2.0, 0.0, 0.6)


func _active(_delta: float) -> void:
	_x = director.map_size().x * (_t / SWEEP)
	var b := director.blue
	if b and is_instance_valid(b) and director.is_on_wall(b) and not _hit.has(b) and absf(b.global_position.x - _x) < 14.0 and threatens(b.global_position.y):
		_hit[b] = true
		tickle(b, 10.0, "thigh")
		director.knock_off(b, "城墙羽毛扫帚")
	if randf() < 0.5:
		Fx.burst(get_parent(), Vector2(_x, lane_y), "feather", 2, 40.0, 0.6, Vector2(0, 30))


func _draw() -> void:
	if not warned:
		return
	var p := Vector2(_x, 0)
	draw_line(p + Vector2(-20, -18), p + Vector2(4, 4), Color(0.6, 0.4, 0.25), 3.0)
	for i in 6:
		draw_line(p + Vector2(4, 4), p + Vector2(10 + i * 2, -8 + i * 4), Color(1, 0.95, 1.0), 2.0)

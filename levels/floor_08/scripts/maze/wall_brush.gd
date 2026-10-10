class_name WallBrush
extends LegTrap
## 墙缝刷轮（第八层夜迷宫；装在 1 格走廊旁边的墙上）：墙缝里藏着两只转刷，按节奏伸出来——
##   缩着 IDLE 秒 → 墙缝发亮 WARN 秒（预警）→ 伸出 OUT 秒（这时经过就被夹住）。看准时机能冲过去。
##   夹住：定住 lock_time 秒（连按 presses 下挣脱），刷子来回刷大腿和屁股（来源键 wall_brush，越挣扎刷得越快）。
## face：刷子朝哪边伸（墙在走廊的哪一侧）：down = 墙在走廊上方（默认）/ up / left / right。
## 画面：刷子是单独的一个小节点（放在墙面和走廊之间），等距画面里按格子排序，从墙块正面伸出来。
## 图例：X = walltrap type=wall_brush face=down

const IDLE := 2.6
const WARN := 0.5
const OUT := 1.2

@export var face := "down"

var vis: Node2D
var _shape: CollisionShape2D


class BrushVisual extends Node2D:
	var trap: WallBrush
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		if trap == null or not is_instance_valid(trap):
			return
		var d := Trap.dir_vector(trap.face)
		var out := trap.out_amount()
		var h := Vector2(0, -9)
		# 墙缝：一道细缝，预警时发亮
		var side := d.orthogonal()
		var glow := trap.warn_amount()
		var a := IsoView.offset(side * 6.0) + h
		var b := IsoView.offset(-side * 6.0) + h
		draw_line(a, b, Color(0.15, 0.05, 0.2, 0.9), 3.0)
		if glow > 0.0:
			draw_line(a, b, Color(1.0, 0.6, 1.0, glow), 2.0)
		if out <= 0.01:
			return
		# 两只转刷：从墙缝伸向走廊，刷毛一圈圈转
		for k in [-1.0, 1.0]:
			var base := IsoView.offset(side * 3.5 * k) + h + Vector2(0, k * 2.0)
			var tip := base + IsoView.offset(d * 9.0 * out)
			draw_line(base, tip, Color(0.45, 0.3, 0.2), 2.0)
			var spin := t * (18.0 if trap.is_holding() else 10.0)
			for i in 6:
				var ang := spin + i * TAU / 6.0
				var p := tip + Vector2(cos(ang) * 3.0, sin(ang) * 1.6)
				draw_circle(p, 1.2, Color(1.0, 0.8, 0.95) if i % 2 == 0 else Color(0.85, 0.55, 0.95))
			draw_circle(tip, 1.6, Color(0.6, 0.35, 0.7))


func _restraint_setup() -> void:
	super()
	reaction_key = "wall_brush"
	hit_fx = "brush"
	exposed = {"thigh": 1.4, "butt": 1.4}
	zone_cycle.assign([{"thigh": 1.0}, {"butt": 1.0}])
	tickle_zones = zone_cycle[0].duplicate()
	cycle_time = 0.6
	struggle_speedup = 0.06
	self_tickle = 1.6
	self_interval = 0.35
	_base_interval = self_interval
	lock_time = 1.5
	presses = 5
	cooldown_time = 0.6
	rhythm_on = OUT
	rhythm_off = IDLE + WARN
	reach = 0
	collision_mask = 2
	var d := Trap.dir_vector(face)
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 12)
	_shape.shape = r
	_shape.position = d * 16.0
	add_child(_shape)
	if sprite:
		sprite.visible = false
	vis = BrushVisual.new()
	vis.trap = self
	vis.name = "WallBrushVisual"
	_attach_visual.call_deferred()


func _attach_visual() -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	get_parent().add_child(vis)
	vis.global_position = global_position + Trap.dir_vector(face) * 9.0


func _exit_tree() -> void:
	if is_instance_valid(vis):
		vis.queue_free()


## 夹人的位置：走廊那一格（贴着墙）。
func _hold_point() -> Vector2:
	return global_position + Trap.dir_vector(face) * 14.0 + Vector2(0, 2)


## 伸出来多少（0 = 缩在墙里，1 = 全伸出）。
func out_amount() -> float:
	if is_holding():
		return 1.0
	var c := fmod(_rhythm_t, rhythm_on + rhythm_off)
	if c < rhythm_on:
		return clampf(c / 0.12, 0.0, 1.0) * clampf((rhythm_on - c) / 0.12, 0.0, 1.0)
	return 0.0


## 预警的亮度（0~1）。
func warn_amount() -> float:
	if is_holding():
		return 0.6
	var c := fmod(_rhythm_t, rhythm_on + rhythm_off)
	var left := rhythm_on + rhythm_off - c
	return clampf(1.0 - left / WARN, 0.0, 1.0) * (0.6 + 0.4 * sin(_rhythm_t * 30.0)) if left < WARN else 0.0


func _fx_restrain(a: Actor) -> void:
	Audio.play("brush_spin", -2.0, 0.1)
	TrapFx.speed_lines(fx_parent(), body_point("thigh"))
	if a is PlayableCharacter and (a as PlayableCharacter).is_controlled():
		GameState.princess_reacted.emit(MazeLines.pick("brush"), 2.2)


func _fx_cycle(_zone: String) -> void:
	Audio.play("brush_spin", -8.0, 0.1, 1.2)

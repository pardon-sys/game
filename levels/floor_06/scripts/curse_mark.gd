class_name CurseMark
extends Node2D
## 诅咒地纹（骑士篇·以笑为饵）：诅咒顺着地面从地牢漏出来，在石板上留下一片紫色的手印纹。
## 可操作角色踩进 RADIUS 以内：被地纹轻挠一下（闷笑 +STEP_LAUGH，最多到 MAX_LAUGH），然后 on_step 回调（任务把附近的手印招过来）；
## 同一块 COOL 秒内不会再触发。冲刺踩过去不触发。画的是程序图形。
## 测试：stepped（触发过几次）、step(角色)。

const RADIUS := 10.0
const STEP_LAUGH := 0.1
const MAX_LAUGH := 0.97
const COOL := 3.0

var on_step := Callable()
var stepped := 0
var _cool := 0.0
var _t := 0.0
var _flash := 0.0


func _ready() -> void:
	z_index = -1
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	add_to_group("curse_mark")
	add_to_group(PantsBurst.KNIGHT_GROUP)


## 蓝色公主的千手解放扫到：地纹暂停 PantsBurst.TRAP_OFF 秒（踩上去不挠、不招手印）
func on_pants_burst(burst: PantsBurst) -> void:
	if global_position.distance_to(burst.global_position) <= PantsBurst.RADIUS:
		_cool = maxf(_cool, PantsBurst.TRAP_OFF)
		_flash = 0.5


## 冰晶结界：地纹冻住一会儿（不挠人）
func on_ice_barrier(center: Vector2, r: float, time: float) -> void:
	if global_position.distance_to(center) <= r:
		_cool = maxf(_cool, time)
		_flash = 0.5


func _process(delta: float) -> void:
	_t += delta
	_cool = maxf(0.0, _cool - delta)
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()
	if _cool > 0.0 or GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if is_instance_valid(p) and not p.is_dashing() and p.global_position.distance_to(global_position) <= RADIUS:
		step(p)


func step(p: PlayableCharacter) -> void:
	_cool = COOL
	_flash = 0.5
	stepped += 1
	if p.laugh and p.laugh.value < p.laugh.max_value * MAX_LAUGH:
		p.laugh.add(minf(p.laugh.max_value * STEP_LAUGH, p.laugh.max_value * MAX_LAUGH - p.laugh.value))
	ZoneFx.play("sole", p.get_parent(), ZoneFx.body_point(p, "sole"), 1.0, false)
	Audio.play("rune", -8.0, 0.1)
	if on_step.is_valid():
		on_step.call(self, p)


func _draw() -> void:
	var a := 0.35 + 0.15 * sin(_t * 2.0) + _flash
	for i in 3:
		var at := Vector2(-5 + i * 5, sin(i * 2.1) * 3.0)
		draw_circle(at, 2.5, Color(0.72, 0.42, 0.95, a))
		for j in 3:
			draw_line(at, at + Vector2.from_angle(-PI * 0.75 + j * PI * 0.25) * 4.5, Color(0.72, 0.42, 0.95, a), 1.2)
	if _flash > 0.0:
		draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 18, Color(0.75, 0.5, 1.0, _flash), 1.0)

class_name ShadowHand
extends Node2D
## 影子小手（骑士篇支线「骑士救公主」·灯全灭了，没有灯的小巷）：只在黑里出现——平时缩在地上的影子里，只露一对淡紫色的小点。
##   灯光（lamp_r 以内）照得到它：缩回去、躲开灯光；灯一暗（灯芯晃，QuestHide 把 lamp_r 调小）它就从黑里伸出来，摸到她就挠一下脚背 / 脚心，然后缩回去冷却。
##   不是 Monster：打不到，只能靠灯光逼开；千手解放 / 冰晶结界让它缩回去一会儿。
##   在巷子里走：伸过去 / 缩回去都沿着格子路（GridPath，每 REPATH 秒重算一次），不穿墙；平时只在自己那一格附近晃（WANDER）。
## 测试：target、lamp_r（由任务每帧给）、state（lurk / creep / touch / shrink）、touch()。

signal touched(who: Node2D)

const SPEED := 34.0
const REACH := 10.0
const COOL := 3.0
const LAUGH := 0.06
## 平时在影子里晃的幅度（小巷只有一格宽，晃大了会画进墙里）
const WANDER := 4.0
## 伸过去 / 缩回去时多久重算一次路
const REPATH := 0.5

var target: Node2D
## 她的灯照多远（任务每帧更新）；在这个半径里它就缩回去
var lamp_r := 40.0
var state := "lurk"
var home := Vector2.ZERO
var _cool := 0.0
var _t := 0.0
var _path: Array[Vector2] = []
var _repath := 0.0


func _ready() -> void:
	z_index = 1
	home = global_position
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	add_to_group(PantsBurst.KNIGHT_GROUP)


func on_pants_burst(burst: PantsBurst) -> void:
	if global_position.distance_to(burst.global_position) <= PantsBurst.RADIUS:
		shrink(4.0)


func on_ice_barrier(center: Vector2, r: float, time: float) -> void:
	if global_position.distance_to(center) <= r:
		shrink(time)


func shrink(time := COOL) -> void:
	state = "shrink"
	_cool = time
	_repath = 0.0


## 沿着格子路往 to 走一步（每 REPATH 秒重算路）
func _walk(to: Vector2, speed: float, delta: float) -> void:
	_repath -= delta
	if _repath <= 0.0 or _path.is_empty():
		_repath = REPATH
		_path = GridPath.find(Party.level_of(self), global_position, to)
		_path.append(to)
	GridPath.follow(self, _path, speed, delta)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if GameState.in_dialogue or GameState.in_cutscene:
		return
	_cool = maxf(0.0, _cool - delta)
	if not is_instance_valid(target):
		return
	var d := global_position.distance_to(target.global_position)
	# 灯暗下去（半径比够得着的距离的两倍还小）：照不住它，它能摸到脚
	var lit := lamp_r > REACH * 2.0 and d <= lamp_r
	match state:
		"shrink":
			# 退回自己的影子里
			_walk(home, SPEED * 1.4, delta)
			if _cool <= 0.0:
				state = "lurk"
		"lurk":
			global_position = home + Vector2(sin(_t * 0.7) * WANDER, cos(_t * 0.5) * 6.0)
			if not lit and d < 90.0 and _cool <= 0.0:
				state = "creep"
		"creep":
			if lit:
				shrink(1.2)
				return
			_walk(target.global_position, SPEED, delta)
			if d <= REACH:
				touch()


## 摸到她：挠一下，缩回去
func touch() -> void:
	touched.emit(target)
	var pc := target as PlayableCharacter
	if pc and pc.laugh:
		pc.laugh.add(pc.laugh.max_value * LAUGH)
		ZoneFx.play("sole", pc.get_parent(), ZoneFx.body_point(pc, "sole"), 0.7, false)
		Audio.play("tickle", -9.0, 0.1)
	shrink(COOL)


func _draw() -> void:
	var a := 0.25 if state in ["lurk", "shrink"] else 0.75
	if state == "creep":
		# 从黑里伸出来的一只影子手
		CurseHand.draw_hand(self, Vector2.ZERO, 0.8, Color(0.25, 0.12, 0.35), Color(0.12, 0.05, 0.18), a, sin(_t * 9.0))
	# 一对淡紫色的小点（黑里也看得见）
	var blink := 1.0 if fmod(_t, 3.0) > 0.15 else 0.0
	for x in [-2.0, 2.0]:
		draw_circle(Vector2(x, -4), 0.9, Color(0.85, 0.55, 1.0, (0.4 + 0.5 * a) * blink))

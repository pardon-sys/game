class_name SiegeLadder
extends Node2D
## 攻防战城墙上的梯子（图例 X = siegeladder，放在墙下第一行；城门那一架也是梯子：gate=true）。
## 两头各有一个交互点：墙下按 E 爬上城墙顶走道，墙顶按 E 爬下去（climb，约 CLIMB_TIME 秒，期间不能动）。
## 蓝色公主被挠下城墙后，AI 自己走到最近的梯子爬回去；粉色公主也能爬上去救倒在墙上的蓝色公主。

const CLIMB_TIME := 1.1
const TILE := 16.0

@export var gate := false

var _top_area: Interactable
var _bottom_area: Interactable


func _ready() -> void:
	add_to_group("siege_ladder")
	z_index = 2
	var spr := SiegeArt.sprite("ladder")
	spr.scale.y = (bottom_pos().y - top_pos().y + 8.0) / spr.region_rect.size.y
	spr.position = Vector2(0, bottom_pos().y - global_position.y + 4.0)
	add_child(spr)
	_top_area = _area(top_pos() - global_position, "爬下去")
	_bottom_area = _area(bottom_pos() - global_position, "爬上城墙")


func _area(at: Vector2, _label: String) -> Interactable:
	var a := Interactable.new()
	a.position = at
	a.prompt_offset = Vector2(0, -22)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(18, 14)
	cs.shape = r
	a.add_child(cs)
	add_child(a)
	a.interacted.connect(func(p: Node): if p is PlayableCharacter: climb(p))
	return a


## 墙顶走道上的那一头。
func top_pos() -> Vector2:
	return global_position + Vector2(0, -TILE * 3.0 - 8.0)


## 墙下的那一头。
func bottom_pos() -> Vector2:
	# 墙脚有一条挡人的窄条（SiegeWall.FOOT_STRIP）：梯子底下的落脚点在它下面
	return global_position + Vector2(0, 6.0)


## 爬梯子（离哪头近就往另一头爬）。await 到爬完。
func climb(c: PlayableCharacter) -> void:
	if c.get_meta("siege_climbing", false):
		return
	var up := c.global_position.distance_to(bottom_pos()) < c.global_position.distance_to(top_pos())
	var to := top_pos() if up else bottom_pos()
	c.set_meta("siege_climbing", true)
	c.set_physics_process(false)
	c.velocity = Vector2.ZERO
	c.global_position = bottom_pos() if up else top_pos()
	var tw := c.create_tween()
	tw.tween_property(c, "global_position", to, CLIMB_TIME)
	Audio.play("cloth", -8.0, 0.1)
	await tw.finished
	if is_instance_valid(c):
		c.set_physics_process(true)
		c.set_meta("siege_climbing", false)
		c.set_meta("siege_fallen_at", Time.get_ticks_msec() / 1000.0)

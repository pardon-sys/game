class_name LivingWall
extends Node2D
## 呼吸墙的一格（第八层夜迷宫，迷宫导演按 design.json 的呼吸墙对生成）：碰撞照常由 TerrainShifter 加在（透明的）Walls 图层上，
## 画面全由这里负责——升起时是一面带紫色脉络、会轻轻起伏的「活墙」（和 2.5D 高墙一样：正面在本格、墙顶往上画一格），
## 沉下时缩回地面，留下一块紫色裂纹（地面层，不盖住人），提醒这里会长墙。
##   set_up(升起?, 动画?)  warn(开?)：心跳前要变的地方发亮（裂纹亮 / 脉络亮）

const WALL_TEX := preload("res://assets/generated/maze/living_wall.png")
const CRACK_TEX := preload("res://assets/generated/maze/living_crack.png")
const GROW := 0.4

var cell := Vector2i.ZERO
var up := false
var warning := false
var wall: Sprite2D
var crack: Sprite2D
var _t := 0.0


## 在 level 的 cell 格放一个（墙精灵进 Entities 一起 y 排序，裂纹进 FloorObjects）。
static func make(level: Node, c: Vector2i) -> LivingWall:
	var lw := LivingWall.new()
	lw.cell = c
	lw.name = "LivingWall_%d_%d" % [c.x, c.y]
	var ents: Node = level.get_node_or_null("Entities")
	(ents if ents else level).add_child(lw)
	lw.global_position = Vector2(c.x * 16 + 8, c.y * 16 + 16)
	lw.crack = Sprite2D.new()
	lw.crack.texture = CRACK_TEX
	lw.crack.hframes = 2
	var floor_objs: Node = level.get_node_or_null("FloorObjects")
	(floor_objs if floor_objs else level).add_child(lw.crack)
	lw.crack.global_position = Vector2(c.x * 16 + 8, c.y * 16 + 8)
	return lw


func _ready() -> void:
	add_to_group("living_wall")
	wall = Sprite2D.new()
	wall.texture = WALL_TEX
	wall.hframes = 3
	wall.offset = Vector2(0, -16)
	wall.scale = Vector2(1, 0)
	wall.visible = false
	add_child(wall)


func _exit_tree() -> void:
	if is_instance_valid(crack):
		crack.queue_free()


func set_up(value: bool, animate := true) -> void:
	if value == up and wall.visible == value:
		return
	up = value
	var tw := create_tween()
	if value:
		wall.visible = true
		tw.tween_property(wall, "scale:y", 1.0, GROW if animate else 0.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(wall, "scale:y", 0.0, GROW * 0.75 if animate else 0.0).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): wall.visible = false)
	crack.visible = not value


func warn(on: bool) -> void:
	warning = on


func _process(delta: float) -> void:
	_t += delta
	if up:
		# 脉络慢慢起伏；心跳前一直亮着
		wall.frame = 2 if warning else (1 if fmod(_t, 1.6) < 0.8 else 0)
	else:
		crack.frame = 1 if warning and fmod(_t, 0.3) < 0.18 else 0

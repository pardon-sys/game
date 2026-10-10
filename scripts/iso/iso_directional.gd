class_name IsoDirectional
extends Node
## 有朝向的物件在等距视角下自动选帧 / 贴到平面上（可复用；挂在物件下面，target = 要改的 Sprite2D）：
##   mode "dir4"：target 有 4 帧（右 / 下 / 左 / 上），按逻辑朝向 facing 投影到屏幕后的主方向选帧——转了视角也朝着对的方向。
##   mode "plane"：target 是立在地上的一片（门帘、栅栏），沿逻辑方向 axis 立着：把它的横轴斜成 axis 在屏幕上的方向。
##   没有等距显示时什么都不做（dir4 直接用 facing 的帧）。改了 facing / axis 之后调 refresh()。

const DIRS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]

@export var mode := "dir4"
@export var facing := Vector2.RIGHT
@export var axis := Vector2.RIGHT
var target: Sprite2D


static func add_to(sprite: Sprite2D, m: String, dir: Vector2) -> IsoDirectional:
	var d := IsoDirectional.new()
	d.name = "IsoDirectional"
	d.target = sprite
	d.mode = m
	if m == "plane":
		d.axis = dir
	else:
		d.facing = dir
	sprite.add_child(d)
	return d


func _ready() -> void:
	add_to_group(IsoView.DIRECTIONAL_GROUP)   # IsoView 挂上 / 转视角时统一 refresh
	if target == null:
		target = get_parent() as Sprite2D
	refresh()


## 4 方向帧号（右 0 / 下 1 / 左 2 / 上 3）。
static func frame_for(dir: Vector2) -> int:
	var s := IsoView.screen_dir(dir)
	if absf(s.x) >= absf(s.y):
		return 0 if s.x > 0 else 2
	return 1 if s.y > 0 else 3


func refresh() -> void:
	if target == null:
		return
	if mode == "dir4":
		target.frame = frame_for(facing)
	elif mode == "plane" and IsoView.current:
		var s := IsoView.screen_dir(axis.normalized())
		if s.x < 0:
			s = -s
		target.transform = Transform2D(s, Vector2(0, 1), target.position)

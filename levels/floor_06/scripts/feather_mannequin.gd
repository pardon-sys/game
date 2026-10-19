class_name FeatherMannequin
extends Node2D
## 裁缝的「羽毛人台」（弥补任务「找漏风」的验收）：一个人台，身上绑着几根长长的羽毛臂一直转（程序画的）。
##   zone：它专挠哪里（armpit 羽毛臂举得高 / waist 中间 / sole 贴着地面的羽毛刷）。
##   spin(秒)：转得飞快一会儿（扫到人的时候）。

var zone := "armpit"
var _a := 0.0
var _fast := 0.0


func spin(sec: float) -> void:
	_fast = maxf(_fast, sec)


func _process(delta: float) -> void:
	_fast = maxf(0.0, _fast - delta)
	_a += delta * (9.0 if _fast > 0.0 else 2.2)
	queue_redraw()


func _draw() -> void:
	var wood := Color(0.48, 0.32, 0.2)
	var cloth := Color(0.9, 0.86, 0.8)
	var cloth_d := Color(0.72, 0.66, 0.62)
	# 底座 + 杆
	draw_rect(Rect2(-6, -2, 12, 3), wood.darkened(0.2))
	draw_line(Vector2(0, -2), Vector2(0, -10), wood, 2.0)
	# 人台身子
	var body := PackedVector2Array([Vector2(-5, -10), Vector2(5, -10), Vector2(7, -18), Vector2(5, -26), Vector2(-5, -26), Vector2(-7, -18)])
	draw_colored_polygon(body, cloth)
	draw_polyline(PackedVector2Array(Array(body) + [body[0]]), cloth_d, 1.0)
	draw_circle(Vector2(0, -28), 2.5, wood)
	# 羽毛臂：高度看专挠哪里
	var y: float = {"armpit": -22.0, "waist": -16.0, "sole": -3.0}.get(zone, -18.0)
	var cols := [Color(1, 0.75, 0.88), Color(0.8, 0.9, 1), Color(1, 0.95, 0.7)]
	for i in 3:
		var a := _a + TAU * i / 3.0
		var tip := Vector2(cos(a) * 14.0, y + sin(a) * 4.0)
		var root := Vector2(0, y)
		draw_line(root, tip, wood.lightened(0.2), 1.0)
		var col: Color = cols[i]
		var dir := (tip - root).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([tip - dir * 6.0 + side * 2.0, tip + dir * 1.0, tip - dir * 6.0 - side * 2.0, tip - dir * 9.0]), col)

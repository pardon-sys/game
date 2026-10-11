class_name GluePuddle
extends Node2D
## 黏胶喷泉喷出来的黏胶水洼：踩在上面的公主减速（StatusComponent.apply_slow），time 秒后干掉。

const RADIUS := 15.0

var time := 8.0
var _spr: Sprite2D


static func spawn(parent: Node, at: Vector2, t: float) -> GluePuddle:
	var g := GluePuddle.new()
	g.time = t
	g.add_to_group("siege_temp")
	g.z_index = -1
	parent.add_child(g)
	g.global_position = at
	return g


func _ready() -> void:
	_spr = Sprite2D.new()
	_spr.texture = IceTower.TEX
	_spr.region_enabled = true
	_spr.region_rect = IceTower.region("glue")
	add_child(_spr)
	_spr.scale = Vector2(0.2, 0.2)
	create_tween().tween_property(_spr, "scale", Vector2.ONE, 0.25)


func _physics_process(delta: float) -> void:
	time -= delta
	if time <= 0.0:
		queue_free()
		return
	if time < 1.0:
		modulate.a = time
	for n in get_tree().get_nodes_in_group("player_chars"):
		var c := n as PlayableCharacter
		if c and c.status and absf(c.global_position.x - global_position.x) < RADIUS and absf(c.global_position.y - global_position.y) < RADIUS * 0.5:
			c.status.apply_slow(0.45, 0.25)

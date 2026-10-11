class_name LivingLadder
extends Node2D
## 壁虎叠罗汉的「活梯子」：几只壁虎贴着墙面一只叠一只（MonsterTeamwork 的 living_ladder 效果生成）。
## 梯子在的时候，走到墙下、离梯子 CLIMB_X 以内的普通怪也能顺着爬上城墙（SiegeMind.march 里检查 near()）。
## 梯子里的壁虎被打倒到少于 MIN_GECKOS 只，梯子就散了。

const CLIMB_X := 28.0
const MIN_GECKOS := 3

var geckos: Array = []
var _t := 0.0


static func near(tree: SceneTree, x: float) -> LivingLadder:
	for n in tree.get_nodes_in_group("siege_ladder_living"):
		var l := n as LivingLadder
		if absf(l.global_position.x - x) <= CLIMB_X:
			return l
	return null


func _ready() -> void:
	add_to_group("siege_ladder_living")
	add_to_group("siege_temp")
	z_index = 3
	var d := SiegeDirector.current
	if d == null:
		return
	# 壁虎贴到墙面上，一只叠一只
	for i in geckos.size():
		var g: Variant = geckos[i]
		if g == null or not is_instance_valid(g):
			continue
		var m := g as Monster
		m.set_physics_process(false)
		m.collision_mask = 0
		var to := Vector2(global_position.x + (4.0 if i % 2 == 0 else -4.0), d.wall_foot_y() - 6.0 - i * 9.0)
		m.create_tween().tween_property(m, "global_position", to, 0.4)
	Fx.burst(get_parent(), global_position + Vector2(0, -10), "dust", 10, 40.0, 0.5, Vector2(0, 30))
	Audio.play("bat_flap", -6.0, 0.1, 0.7)


func alive_count() -> int:
	return geckos.filter(func(g): return g != null and is_instance_valid(g) and (g as Actor).is_alive()).size()


func _process(delta: float) -> void:
	_t += delta
	if alive_count() < MIN_GECKOS:
		_break()
		return
	# 摇摇晃晃
	for i in geckos.size():
		var g: Variant = geckos[i]
		if g != null and is_instance_valid(g):
			(g as Node2D).rotation = sin(_t * 6.0 + i) * 0.12
	if randf() < delta * 1.5:
		Fx.burst(get_parent(), global_position + Vector2(randf_range(-6, 6), -randf_range(4, 30)), "dust", 2, 20.0, 0.4, Vector2(0, 40))


func _break() -> void:
	for g in geckos:
		if g != null and is_instance_valid(g):
			(g as Monster).set_physics_process(true)
			(g as Node2D).rotation = 0.0
			(g as Monster).collision_mask = 1
			(g as Monster).remove_meta("in_ladder")
	Fx.burst(get_parent(), global_position + Vector2(0, -12), "dust", 12, 50.0, 0.5, Vector2(0, 60))
	queue_free()

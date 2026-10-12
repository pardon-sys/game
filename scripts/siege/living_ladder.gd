class_name LivingLadder
extends Actor
## 壁虎叠罗汉的「活梯子」：几只壁虎贴着墙面一只叠一只（MonsterTeamwork 的 living_ladder 效果生成）。
## 梯子在的时候，走到墙下、离梯子 CLIMB_X 以内的普通怪也能顺着爬上城墙（SiegeMind.march 里检查 near()）。
## 梯子里的壁虎被打倒到少于 MIN_GECKOS 只，梯子就散了。
## 能打：梯子本身是敌方的 Actor（在 siege_enemy_tower 组里：冰塔、弩炮、士兵、粉色公主的 AI 都会来打），
## 受击范围从墙顶一直到墙脚往下 REACH_BELOW 像素——壁虎贴在墙面上、墙脚挡人窄条的里面，直接打壁虎是够不着的；
## 打到梯子的那一下转给最下面那只活着的壁虎。

const CLIMB_X := 28.0
const MIN_GECKOS := 3
const REACH_BELOW := 14.0

var geckos: Array = []
var _t := 0.0


static func near(tree: SceneTree, x: float) -> LivingLadder:
	for n in tree.get_nodes_in_group("siege_ladder_living"):
		var l := n as LivingLadder
		if l and absf(l.global_position.x - x) <= CLIMB_X:
			return l
	return null


func _setup() -> void:
	add_to_group("siege_ladder_living")
	add_to_group("siege_temp")
	add_to_group("siege_enemy_tower")
	set_faction(Faction.Type.ENEMY)
	z_index = 3
	hurt_invuln_time = 0.15
	var d := SiegeDirector.current
	# 受击范围：一整条（layer 4：公主的挥击、士兵都扫得到；不挡路）
	collision_layer = 4
	collision_mask = 0
	if d:
		var top := d.wall_top_y() - global_position.y
		var bottom := REACH_BELOW
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(20, bottom - top)
		cs.shape = r
		cs.position = Vector2(0, (top + bottom) / 2.0)
		add_child(cs)
	if d == null:
		return
	# 壁虎贴到墙面上，一只叠一只（已经在爬墙的先停下来）
	for i in geckos.size():
		var g: Variant = geckos[i]
		if not is_instance_valid(g):
			continue
		var m := g as Monster
		if m is SiegeMonster:
			(m as SiegeMonster).stop_climb()
		m.set_physics_process(false)
		m.collision_mask = 0
		var to := Vector2(global_position.x + (4.0 if i % 2 == 0 else -4.0), d.wall_foot_y() - 6.0 - i * 9.0)
		m.create_tween().tween_property(m, "global_position", to, 0.4)
	Fx.burst(get_parent(), global_position + Vector2(0, -10), "dust", 10, 40.0, 0.5, Vector2(0, 30))
	Audio.play("bat_flap", -6.0, 0.1, 0.7)


func alive_geckos() -> Array:
	return geckos.filter(func(g): return is_instance_valid(g) and (g as Actor).is_alive())


func alive_count() -> int:
	return alive_geckos().size()


func is_alive() -> bool:
	return is_inside_tree() and alive_count() >= MIN_GECKOS


## 打到梯子：转给最下面那只活着的壁虎（挠痒不算）。
func receive_hit(hit: HitData) -> bool:
	if hit.kind != HitData.Kind.ATTACK or _attack_invuln > 0.0:
		return false
	var alive := alive_geckos()
	if alive.is_empty():
		return false
	alive.sort_custom(func(a, b): return (a as Node2D).global_position.y > (b as Node2D).global_position.y)
	_attack_invuln = hurt_invuln_time
	var g := alive[0] as Monster
	var ok := g.receive_hit(hit)
	if ok:
		Fx.burst(get_parent(), g.global_position + Vector2(0, -4), "chip", 4, 30.0, 0.3, Vector2(0, 60), Color(0.7, 1.0, 0.6))
	return ok


func _tick(delta: float) -> void:
	_t += delta
	if alive_count() < MIN_GECKOS:
		_break()
		return
	# 摇摇晃晃
	for i in geckos.size():
		var g: Variant = geckos[i]
		if is_instance_valid(g):
			(g as Node2D).rotation = sin(_t * 6.0 + i) * 0.12
	if randf() < delta * 1.5:
		Fx.burst(get_parent(), global_position + Vector2(randf_range(-6, 6), -randf_range(4, 30)), "dust", 2, 20.0, 0.4, Vector2(0, 40))


func _break() -> void:
	if is_queued_for_deletion():
		return
	for g in geckos:
		if is_instance_valid(g):
			(g as Monster).set_physics_process(true)
			(g as Node2D).rotation = 0.0
			(g as Monster).collision_mask = 1
			(g as Monster).remove_meta("in_ladder")
	Fx.burst(get_parent(), global_position + Vector2(0, -12), "dust", 12, 50.0, 0.5, Vector2(0, 60))
	remove_from_group("siege_enemy_tower")
	queue_free()

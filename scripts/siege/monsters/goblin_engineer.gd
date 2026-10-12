class_name GoblinEngineer
extends SiegeMonster
## 地精工兵（敌塔就是他们搭的）：一队 3 只扛着木料，从敌方区域出来，走到离自己最近的空地基（EnemySite），
## 在地基旁边敲敲打打——地基上出进度条，搭完立起一座敌塔；然后去找下一个空地基接着搭。
## 打倒工兵、或者冻住他们（冰晶结界 / 寒霜塔）都能打断。不攻城，被打 / 被挡时才还手。
## 工兵护送（配合技）：squad 相同的护卫怪围着领头的工兵走；护送着搭成的敌塔第一次发动威力加倍（escorted）。

## 同一队的编号（成套生成时由 MonsterTeamwork 设置）
var squad := 0
## 有护卫跟着
var escorted := false
var site: EnemySite
var _hammer_t := 0.0


func _setup() -> void:
	super()
	add_to_group("siege_engineer")


func siege_wander(_mind: SiegeMind, delta: float) -> bool:
	if site == null or not is_instance_valid(site) or site.tower != null:
		site = _pick_site()
	if site == null:
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		return true
	var to := site.global_position + Vector2(randf_range(-2, 2), 10) - global_position
	if to.length() > 16.0:
		_move(to.normalized(), stats.chase_speed * (director.town.mul("engineer_speed") if director and director.town else 1.0), delta)
		site.unregister_builder(self)
	else:
		velocity = Vector2.ZERO
		site.register_builder(self)
		_hammer_t -= delta
		if _hammer_t <= 0.0 and not is_stunned():
			_hammer_t = 0.45
			Fx.burst(get_parent(), site.global_position + Vector2(randf_range(-8, 8), -6), "chip", 3, 30.0, 0.35, Vector2(0, 60),
				Color(0.75, 0.5, 0.3))
			if director and director.on_screen(global_position):
				Audio.play("break", -18.0, 0.2, 1.8)
	return true


## 最近的空地基（没有塔、没在被别的队搭；同一队的人挑同一个）。
func _pick_site() -> EnemySite:
	for e in get_tree().get_nodes_in_group("siege_engineer"):
		var g := e as GoblinEngineer
		if g != self and g.squad == squad and squad != 0 and g.site != null and is_instance_valid(g.site) and g.site.tower == null:
			return g.site
	var best: EnemySite = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("siege_enemy_site"):
		var s := n as EnemySite
		if s.tower != null or s.claimed_by_other(squad):
			continue
		var dd := s.global_position.distance_to(global_position)
		if dd < best_d:
			best_d = dd
			best = s
	if best:
		best.claim(squad)
	return best


func _on_died() -> void:
	if site and is_instance_valid(site):
		site.unregister_builder(self)
	super()

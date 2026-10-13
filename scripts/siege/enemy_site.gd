class_name EnemySite
extends Node2D
## 敌塔地基（图例 X = enemysite index=<序号>；全地图很多个）。敌塔怎么立起来：
##   1. 地精工兵（GoblinEngineer）走过来敲：地基上出进度条，BUILD_TIME 秒搭完（3 只都在最快，少一只慢一截）；
##      工兵被冻住时进度停下，冻住超过 FROZEN_DECAY 秒开始倒退；工兵全没了进度慢慢掉。
##   2. 附近 RADIUS 内的怪 ≥ GATHER 只、连续待满 HOLD 秒，也会自己搭起来（老机制，门槛降低了）。
## 种类从这一波的 enemy_towers 里挑（还没有的优先）。护送着搭成的塔（escorted）第一次发动威力加倍。
## 塔被拆掉后地基空出来，可以再搭。

const RADIUS := 64.0
const GATHER := 5
const HOLD := 4.0
const BUILD_TIME := 12.0
const FROZEN_DECAY := 3.0

@export var index := 0
## 搭一座塔要多久（巨魔将军叫来的工兵就地搭：更快）
var build_time := BUILD_TIME
## 临时地基（巨魔将军就地搭塔）：塔拆掉 / 没人搭了就消失
var temporary := false

var tower: EnemyTower
var progress := 0.0
## 工兵搭建进度（0 ~ BUILD_TIME）
var build_progress := 0.0
var builders: Array[GoblinEngineer] = []
var _claim := 0
var _claim_t := 0.0
var _frozen_t := 0.0
var _spr: Sprite2D
var _t := 0.0
var _ring: SiegeFx.Ring
var _bar: Bar


class Bar extends Node2D:
	var site: EnemySite

	func _process(_delta: float) -> void:
		visible = site.build_progress > 0.0 and site.tower == null
		queue_redraw()

	func _draw() -> void:
		var f := site.build_progress / site.build_time
		draw_rect(Rect2(-14, -30, 28, 4), Color(0.1, 0.05, 0.1, 0.85))
		draw_rect(Rect2(-14, -30, 28 * f, 4), Color(0.95, 0.45, 0.85) if site._frozen_t <= 0.0 else Color(0.6, 0.85, 1.0))
		draw_rect(Rect2(-14, -30, 28, 4), Color(1, 0.8, 0.95), false, 1.0)


func _ready() -> void:
	add_to_group("siege_enemy_site")
	z_index = -1
	_spr = SiegeArt.sprite("site_0")
	_spr.offset = Vector2(0, -6)
	add_child(_spr)
	_ring = SiegeFx.Ring.new()
	_ring.radius = RADIUS
	_ring.color = Color(0.85, 0.4, 0.9, 0.0)
	_ring.fill = 0.08
	add_child(_ring)
	_bar = Bar.new()
	_bar.site = self
	_bar.z_index = 40
	add_child(_bar)


func claim(squad: int) -> void:
	_claim = squad
	_claim_t = 30.0


func claimed_by_other(squad: int) -> bool:
	return _claim != 0 and _claim != squad and _claim_t > 0.0


func register_builder(g: GoblinEngineer) -> void:
	if not builders.has(g):
		builders.append(g)
		g.set_meta("siege_alert", true)   # 屏幕边缘的红箭头
		if builders.size() == 1 and build_progress <= 0.0:
			var d := SiegeDirector.current
			if d:
				d.intel.discover("goblin_engineer")
				GameState.rule("地精工兵在搭敌塔！打倒他们或者冻住他们！")


func unregister_builder(g: GoblinEngineer) -> void:
	builders.erase(g)
	if is_instance_valid(g):
		g.set_meta("siege_alert", false)


func is_building() -> bool:
	return build_progress > 0.0 and tower == null


func _process(delta: float) -> void:
	_claim_t = maxf(0.0, _claim_t - delta)
	var d := SiegeDirector.current
	if d == null or d.state != "fight" or tower != null:
		progress = 0.0
		build_progress = 0.0
		_ring.color.a = 0.0
		_ring.queue_redraw()
		return
	_build_tick(delta)
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		# 工兵队（工兵和护卫）走自己的搭建流程，不算进「聚集」
		var n := d.enemies_near(global_position, RADIUS).filter(func(m): return not (m is GoblinEngineer) and not m.has_meta("escort_of")).size()
		progress = progress + 0.5 if n >= GATHER else maxf(0.0, progress - 0.5)
		_ring.color.a = clampf(progress / HOLD, 0.0, 1.0) * 0.8
		_ring.queue_redraw()
		if progress >= HOLD:
			build_tower(_pick_kind(d))


func _build_tick(delta: float) -> void:
	builders = builders.filter(func(g): return is_instance_valid(g) and g.is_alive() and g.site == self)
	if builders.is_empty():
		build_progress = maxf(0.0, build_progress - delta * 0.3)
		if temporary and build_progress <= 0.0 and tower == null and _claim_t <= 0.0:
			queue_free()
		return
	var working := builders.filter(func(g): return not g.is_stunned())
	if working.is_empty():
		_frozen_t += delta
		if _frozen_t > FROZEN_DECAY:
			build_progress = maxf(0.0, build_progress - delta)
		return
	_frozen_t = 0.0
	var town_k := SiegeDirector.current.town.mul("build_speed") if SiegeDirector.current and SiegeDirector.current.town else 1.0
	build_progress += delta * [0.0, 0.45, 0.75, 1.0][mini(working.size(), 3)] * town_k * WaveFeatures.mul_of("build_speed")
	# 敲打的木屑 / 火花
	if randf() < delta * 5.0:
		Fx.burst(get_parent(), global_position + Vector2(randf_range(-10, 10), -10), "wood", 3, 40.0, 0.5, Vector2(0, 120), Color(0.9, 0.7, 0.5))
	if build_progress >= build_time:
		var escorted := builders.any(func(g): return (g as GoblinEngineer).escorted)
		var d := SiegeDirector.current
		var t := build_tower(_pick_kind(d)) if d else null
		if t and escorted:
			t.power = 2.0
			t.set_meta("escort_built", true)


func _pick_kind(d: SiegeDirector) -> String:
	var pool: Array = d.wave_data().get("enemy_towers", [])
	if pool.is_empty():
		pool = EnemyTower.kinds()
	var have := {}
	for t in get_tree().get_nodes_in_group("siege_enemy_tower"):
		have[str(t.get("kind"))] = true
	var fresh := pool.filter(func(k): return not have.has(str(k)))
	return str((fresh if not fresh.is_empty() else pool).pick_random())


func build_tower(kind: String) -> EnemyTower:
	progress = 0.0
	build_progress = 0.0
	_claim = 0
	tower = EnemyTower.new()
	tower.kind = kind
	tower.site = self
	get_parent().add_child(tower)
	tower.global_position = global_position
	var d := SiegeDirector.current
	if d:
		d.intel.discover("etower_" + kind)
		GameState.notify("怪物搭起了「%s」！" % str(EnemyTower.info(kind).get("name", kind)))
		if d.features:
			d.features.on_tower_built(self)
	return tower


## 老名字（测试 / 截图里直接搭）。
func build(kind: String) -> EnemyTower:
	return build_tower(kind)


func tower_gone() -> void:
	tower = null
	if temporary:
		queue_free()

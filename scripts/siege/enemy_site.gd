class_name EnemySite
extends Node2D
## 敌方区域的敌塔地基（图例 X = enemysite index=<序号>）：附近 RADIUS 内的怪 ≥ GATHER 只、连续待满 HOLD 秒，就自己搭起一座敌塔
## （种类从这一波的 enemy_towers 里挑，还没有的优先）。从这里出的怪（spawn from=site）会先在地基旁边转一会儿再去攻城。
## 塔被拆掉后地基空出来，可以再搭。地上的乱石圈随聚集进度发紫光。

const RADIUS := 64.0
const GATHER := 8
const HOLD := 6.0

@export var index := 0

var tower: EnemyTower
var progress := 0.0
var _spr: Sprite2D
var _t := 0.0
var _ring: SiegeFx.Ring


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


func _process(delta: float) -> void:
	var d := SiegeDirector.current
	if d == null or d.state != "fight" or tower != null:
		progress = 0.0
		_ring.color.a = 0.0
		_ring.queue_redraw()
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		var n := d.enemies_near(global_position, RADIUS).size()
		if n >= GATHER:
			progress += 0.5
		else:
			progress = maxf(0.0, progress - 0.5)
		_ring.color.a = clampf(progress / HOLD, 0.0, 1.0) * 0.8
		_ring.queue_redraw()
		if progress >= HOLD:
			build(_pick_kind(d))


func _pick_kind(d: SiegeDirector) -> String:
	var pool: Array = d.wave_data().get("enemy_towers", [])
	if pool.is_empty():
		pool = EnemyTower.kinds()
	var have := {}
	for t in get_tree().get_nodes_in_group("siege_enemy_tower"):
		have[str(t.get("kind"))] = true
	var fresh := pool.filter(func(k): return not have.has(str(k)))
	return str((fresh if not fresh.is_empty() else pool).pick_random())


func build(kind: String) -> EnemyTower:
	progress = 0.0
	tower = EnemyTower.new()
	tower.kind = kind
	tower.site = self
	get_parent().add_child(tower)
	tower.global_position = global_position
	var d := SiegeDirector.current
	if d:
		d.intel.discover("etower_" + kind)
		GameState.notify("怪物搭起了「%s」！" % str(EnemyTower.info(kind).get("name", kind)))
	return tower


func tower_gone() -> void:
	tower = null

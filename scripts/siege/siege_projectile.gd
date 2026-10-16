class_name SiegeProjectile
extends Sprite2D
## 攻防战的飞行物（冰塔的冰锥、敌塔的小手 / 刷子手 / 痒痒装备……）：朝目标追过去，碰到就调 on_hit(目标) 然后消失。
## 目标没了就飞到最后看到的位置消失。图来自 towers 图集（IceTower.region）。冰镜之类的反弹以后再加。

var target: Node2D
var speed := 220.0
var on_hit: Callable
var _last := Vector2.ZERO
var _life := 4.0
## 可选风场接管。冰塔飞具默认关闭；原目标、回调及剩余寿命保存在本节点上。
var windable := false
var _wind_ref: WeakRef
var _spent := false


static func shoot(parent: Node, from: Vector2, to: Node2D, key: String, spd: float, hit: Callable) -> SiegeProjectile:
	if parent == null or not is_instance_valid(to):
		return null
	var p := SiegeProjectile.new()
	p.texture = IceTower.TEX
	p.region_enabled = true
	p.region_rect = IceTower.region(key)
	p.target = to
	p.speed = spd
	p.on_hit = hit
	p.windable = key in ["proj_equip", "proj_hand", "proj_brush", "net"]
	p.z_index = 30
	p.add_to_group("siege_temp")
	if p.windable:
		p.add_to_group("siege_wind_projectile")
	parent.add_child(p)
	p.global_position = from
	p._last = FortressRules.point(to,from)
	return p


func _process(delta: float) -> void:
	if GameState.in_dialogue or GameState.in_cutscene or CG.is_busy():
		return
	if _wind_ref and is_instance_valid(_wind_ref.get_ref()):
		return  # 漩涡控制位置；剩余寿命暂停，解除后继续原飞行。
	_wind_ref = null
	_life -= delta
	if is_instance_valid(target):
		_last = FortressRules.point(target,global_position) + Vector2(0, -8)
	var d := _last - global_position
	rotation = d.angle() + PI / 2.0
	if d.length() <= speed * delta + 4.0 or _life <= 0.0:
		if is_instance_valid(target) and _life > 0.0:
			wind_hit(target)
		else:
			queue_free()
		return
	global_position += d.normalized() * speed * delta


func begin_wind_capture(field: Node) -> bool:
	if not windable or _spent or (_wind_ref and is_instance_valid(_wind_ref.get_ref())):
		return false
	_wind_ref = weakref(field)
	return true


func release_wind_capture(field: Node) -> void:
	if _wind_ref and _wind_ref.get_ref() == field:
		_wind_ref = null


func wind_hit(victim: Node) -> void:
	if _spent or is_queued_for_deletion():
		return
	_spent = true
	if on_hit.is_valid():
		on_hit.call(victim)
	queue_free()

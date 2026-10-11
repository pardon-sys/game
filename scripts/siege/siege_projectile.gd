class_name SiegeProjectile
extends Sprite2D
## 攻防战的飞行物（冰塔的冰锥、敌塔的小手 / 刷子手 / 痒痒装备……）：朝目标追过去，碰到就调 on_hit(目标) 然后消失。
## 目标没了就飞到最后看到的位置消失。图来自 towers 图集（IceTower.region）。冰镜之类的反弹以后再加。

var target: Node2D
var speed := 220.0
var on_hit: Callable
var _last := Vector2.ZERO
var _life := 4.0


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
	p.z_index = 30
	p.add_to_group("siege_temp")
	parent.add_child(p)
	p.global_position = from
	p._last = to.global_position
	return p


func _process(delta: float) -> void:
	_life -= delta
	if is_instance_valid(target):
		_last = target.global_position + Vector2(0, -8)
	var d := _last - global_position
	rotation = d.angle() + PI / 2.0
	if d.length() <= speed * delta + 4.0 or _life <= 0.0:
		if is_instance_valid(target) and on_hit.is_valid() and _life > 0.0:
			on_hit.call(target)
		queue_free()
		return
	global_position += d.normalized() * speed * delta

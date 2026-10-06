class_name IceBarrier
extends Node2D
## 蓝色公主的魔法：冰晶结界（和粉色公主的星光爆发同样按住 L 吟唱、松开释放，档位越高范围越大、冻得越久）。
##   范围内的敌对角色冻住（Monster.stun：定身、不能挠，身上泛冰蓝色；有 freeze() 的 Boss 用它，按 aim_point 和 meta body_radius 算范围）；范围内的陷阱暂停（active = false，到时间恢复）；
##   她自己被困 / 被吸附的状态解除；她和范围内的友军都得到「冰晶守护」（frost_guard：期间闷笑不涨，
##   而且自然消减快 LaughMeter.FROST_DECAY 倍、不用等被挠后的延迟）。
##   会魔法反应的东西（MagicReactive）同样收到一次 on_magic_burst（和星光爆发一样能解谜）。
##   特效：冰蓝色的圆环扩散 + 冰晶 / 雪花粒子，冻住的陷阱也蒙上冰色。

const TIERS := [
	{},
	{"radius": 48.0, "time": 2.0},
	{"radius": 72.0, "time": 3.0},
	{"radius": 96.0, "time": 4.0},
]
const ICE := Color(0.7, 0.88, 1.35)

var radius := 48.0
## 结界留在原地的时间（= 冻结时间），到时间再淡出。
var duration := 2.0
var _ring: Line2D
var _t := 0.0


static func params(t: int) -> Dictionary:
	return TIERS[clampi(t, 1, TIERS.size() - 1)]


## 释放：返回被冻住的角色和陷阱。
static func cast(caster: Node2D, t: int) -> Array[Node]:
	var p := params(t)
	return cast_with(caster, p["radius"], p["time"], t)


## 通用：半径 r、冻 time 秒（疲倦爆发用满蓄力范围、一半时间）。tier 传给会魔法反应的东西。
static func cast_with(caster: Node2D, r: float, time: float, t := 3) -> Array[Node]:
	var center := caster.global_position + Vector2(0, -6)
	var hit: Array[Node] = []
	var tree := caster.get_tree()
	for n in tree.get_nodes_in_group("actor"):
		var a := n as Actor
		if a == null or a == caster or not a.is_alive() or not Faction.are_hostile(caster, a):
			continue
		# 大型 Boss：按本体中心（aim_point）和身体半径（meta hit_radius）算；会冻结的（freeze）冻住，其它的僵直
		var pt: Vector2 = a.call("aim_point") if a.has_method("aim_point") else a.global_position
		if pt.distance_to(center) > r + StarBurst.BODY_ALLOWANCE + float(a.get_meta("body_radius", 0.0)):
			continue
		if a.has_method("freeze"):
			a.freeze(time)
		elif a.has_method("stun"):
			a.stun(time)
		hit.append(a)
	for n in tree.get_nodes_in_group("trap"):
		var trap := n as Node2D
		if trap == null or not trap.is_inside_tree() or trap.global_position.distance_to(center) > r:
			continue
		if trap.get("active") == true:
			freeze_trap(trap, time)
			hit.append(trap)
	for n in tree.get_nodes_in_group("magic_reactive"):
		if n is Node2D and Contracts.is_magic_reactive(n) and (n as Node2D).global_position.distance_to(center) <= r:
			n.on_magic_burst(t, caster)
	var pc := caster as PlayableCharacter
	if pc:
		if pc.status and pc.status.is_grabbed():
			pc.status.release(true)
		pc.fling_latchers()
		pc.add_buff("frost_guard", time)
	# 范围内的友军（双人模式里的另一个公主等）也得到冰晶守护：闷笑不涨（疲倦爆发那次也算）
	for n in tree.get_nodes_in_group("actor"):
		var ally := n as Actor
		if ally == null or ally == caster or not ally.is_alive() or Faction.are_hostile(caster, ally) or Faction.of(ally) == Faction.Type.NEUTRAL:
			continue
		if ally.laugh and ally.global_position.distance_to(center) <= r + StarBurst.BODY_ALLOWANCE:
			ally.add_buff("frost_guard", time)
	var fx := IceBarrier.new()
	fx.radius = r
	fx.duration = time
	caster.get_parent().add_child(fx)
	fx.global_position = center
	Audio.play("chime", -2.0, 0.03, 1.6)
	Audio.play("puff", -6.0, 0.05, 0.6)
	return hit


## 陷阱冻住 time 秒：停止生效、蒙一层冰色，到时间恢复。
static func freeze_trap(trap: Node2D, time: float) -> void:
	trap.set("active", false)
	trap.modulate = ICE
	var ref: WeakRef = weakref(trap)
	trap.get_tree().create_timer(time, false).timeout.connect(func():
		var tr: Node2D = ref.get_ref()
		if tr:
			tr.set("active", true)
			tr.modulate = Color.WHITE)


## 扩散的椭圆圈（Line2D 缩放会把线宽一起放大，所以改点的位置；scripts/stealth 的脚步波纹也用它）。
static func ring_points(r: float, n := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := TAU * i / n
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.55))
	return pts


func _ready() -> void:
	z_index = 5
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_ring = Line2D.new()
	_ring.width = 2.0
	_ring.default_color = Color(0.75, 0.92, 1.0, 0.95)
	_ring.material = mat
	add_child(_ring)
	var inner := Line2D.new()
	inner.width = 1.0
	inner.default_color = Color(1, 1, 1, 0.7)
	inner.material = mat
	add_child(inner)
	# 结界内淡淡的冰蓝色
	var fill := Polygon2D.new()
	fill.color = Color(0.6, 0.85, 1.0, 0.18)
	fill.material = mat
	add_child(fill)
	move_child(fill, 0)
	var tw := create_tween().set_parallel()
	tw.tween_method(func(r: float):
		_ring.points = IceBarrier.ring_points(r)
		fill.polygon = IceBarrier.ring_points(r), 4.0, radius, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(r: float): inner.points = IceBarrier.ring_points(r), 4.0, radius * 0.75, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 展开后结界留在原地直到冻结结束（轻轻脉动、飘雪），最后 0.5 秒淡出
	tw.chain().tween_interval(maxf(0.0, duration - 0.45 - 0.5))
	tw.chain().tween_property(self, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(queue_free)
	# 冰晶和雪花：从中心往外飞，雪花慢慢飘落
	Fx.burst(get_parent(), global_position, "crystal", 14, radius * 1.6, 0.5, Vector2(0, 40), Color(0.85, 0.95, 1.0))
	Fx.burst(get_parent(), global_position, "snow", 10, radius * 0.8, 1.1, Vector2(0, 18))
	var snow := Fx.emitter(self, "snow", 6, 1.4, {"extents": Vector2(radius * 0.8, radius * 0.4), "gravity": Vector2(0, 14)})
	if snow:
		snow.position = Vector2(0, -radius * 0.3)


func _process(delta: float) -> void:
	_t += delta
	if _t > 0.45 and is_instance_valid(_ring):
		_ring.default_color.a = 0.6 + 0.3 * sin(_t * 5.0)

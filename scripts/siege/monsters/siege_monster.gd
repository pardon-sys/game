class_name SiegeMonster
extends Monster
## 攻城怪的基类（scenes/siege/monsters/*.tscn，tools/build/gen_siege_monsters.py 生成场景）：
##   图：assets/generated/siege/monsters.png 的 <sprite_key>_0 / _1 两帧（走路时来回换，屏幕外不换）；朝左时翻转。
##   大脑：make_mind(导演) 给自己的 SiegeMind（默认行军；子类重写成攻城车 / 爬墙 / 飞行……）。
##   免疫：block_hit(hit) 返回 true 的攻击 / 挠痒不吃（盾甲螃蟹正面、暖炉史莱姆不怕冰、羽毛蝠群够不着……），冒「叮」的火花。
##   爬墙：climb_wall() 从墙下翻到墙顶走道（冰墙加固的那段爬不上去）；上墙以后 on_wall = true，去找蓝色公主。

const TEX := preload("res://assets/generated/siege/monsters.png")
const META := "res://assets/generated/siege/monsters.json"
const CLIMB_TIME := 1.2

static var _meta := {}

@export var sprite_key := ""

var director: SiegeDirector
var on_wall := false
var climbing := false
var _frame_t := 0.0
var _frame := 0


static func region(key: String) -> Rect2:
	if _meta.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META))
		_meta = parsed if parsed is Dictionary else {}
	var r: Variant = _meta.get(key, [0, 0, 16, 16])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func _setup() -> void:
	super()
	director = SiegeDirector.current
	if sprite:
		sprite.texture = TEX
		sprite.region_enabled = true
		sprite.region_rect = region(sprite_key + "_0")
		sprite.offset = Vector2(0, -sprite.region_rect.size.y / 2.0)


func make_mind(d: Node) -> SiegeMind:
	return Mind.new(d)


## 子类重写：自己决定这一帧怎么走（返回 true = 接手了；false = 照常行军）。墙上的怪默认在走道上找蓝色公主。
func siege_wander(_mind: SiegeMind, delta: float) -> bool:
	if on_wall:
		wall_hunt(delta)
		return true
	return false


## 先问怪物自己（siege_wander），它不管就照常行军。
class Mind extends SiegeMind:
	func wander(m: Monster, delta: float) -> bool:
		var sm := m as SiegeMonster
		if sm and sm.climbing:
			return true
		if sm and sm.siege_wander(self, delta):
			return true
		return super(m, delta)


func _animate(delta: float) -> void:
	if sprite == null or get_meta("siege_spawning", false):
		return
	if director and not director.on_screen(global_position):
		return
	_frame_t += delta
	if _frame_t >= 0.22:
		_frame_t = 0.0
		_frame = 1 - _frame
		sprite.region_rect = region("%s_%d" % [sprite_key, _frame])
	if absf(velocity.x) > 2.0:
		sprite.flip_h = velocity.x < 0.0


## 子类重写：这一下不吃（免疫）。
func block_hit(_hit: HitData) -> bool:
	return false


func receive_hit(hit: HitData) -> bool:
	if not hit.ignore_block and block_hit(hit):
		_ding()
		return false
	return super(hit)


func _ding() -> void:
	Fx.burst(get_parent(), global_position + Vector2(0, -10), "chip", 3, 30.0, 0.3, Vector2(0, 40), Color(1, 1, 0.8))
	if sprite:
		sprite.modulate = Color(2.0, 1.8, 1.0)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)
	Audio.play("locked", -10.0, 0.2, 1.4)


## 移动加上冻 / 减速（怪物没有 Status 组件时用增益 siege_chill）。
func _move(dir: Vector2, speed: float, delta: float) -> void:
	velocity = velocity.move_toward(dir * speed * stat_mul("speed"), 400.0 * delta)


## 从墙下翻到墙顶走道。返回是否成功（那段墙加固了就不行）。
func climb_wall() -> bool:
	if director == null or climbing or on_wall:
		return false
	var w := director.segment_at(global_position.x)
	if w == null or not w.climbable():
		return false
	climbing = true
	set_physics_process(false)
	var to := Vector2(global_position.x, director.wall_top_y() + randf_range(-2, 6))
	var tw := create_tween()
	_climb_tw = tw
	tw.tween_property(self, "global_position", to, CLIMB_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		climbing = false
		on_wall = true
		collision_mask = 0
		set_physics_process(true))
	return true


var _climb_tw: Tween


## 停下正在进行的爬墙（叠成活梯子时）。
func stop_climb() -> void:
	if _climb_tw and _climb_tw.is_valid():
		_climb_tw.kill()
	_climb_tw = null
	climbing = false


## 墙顶走道上：找蓝色公主（她不在墙上就打墙）。
func wall_hunt(delta: float) -> void:
	if director == null:
		return
	var b := director.wall_target()
	if b and is_instance_valid(b) and b.is_alive() and not Downed.is_downed(b) and director.is_on_wall(b):
		target = b
		var d := b.global_position - global_position
		_move(Vector2(d.x, d.y * 0.3).normalized(), stats.chase_speed, delta)
	else:
		target = null
		velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
		# 没人可挠：从上面拆墙
		if _action_cd <= 0.0:
			var w := director.segment_at(global_position.x)
			if w:
				w.take(float(stats.attack_damage) * SiegeWall.DAMAGE_MULT)
			_action_cd = stats.attack_cooldown

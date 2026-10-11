class_name SiegeWall
extends Actor
## 小镇攻防战的一段城墙（一共 8 段；图例 X = siegewall index=<段> w=<格数>，放在墙下第一行、这段墙的正中，节点自己往上挪一格）。
## 是玩家一方的 Actor：怪物走到墙下时 HitArea 碰到它就会攻击（不能被挠痒，自动改成攻击）。
## 伤害不扣自己的血，而是交给 SiegeDirector 的城墙总血量（damage_wall）；自己只记这一段挨了多少（taken），
## 用来画裂缝（0 完好 / 1 裂缝 / 2 快塌了）和给蓝色公主的 AI 判断哪一段最危险。
## 冰墙加固（蓝色公主的法术）：shield_left 秒内先吸收 shield_hp 点伤害，期间怪物爬不上来（climbable() = false）。
## 墙面的图：assets/generated/siege/props.png 的 wall_0~2 / wall_shell，按宽度一格一格画。

const TILE := 16.0
## 怪物普通攻击打到城墙上的倍数（怪物的攻击力是按打公主设计的，1~2 点）
const DAMAGE_MULT := 3.0
## 挨打时冒灰尘的最短间隔
const DUST_GAP := 0.35

@export var index := 0
@export var w := 13.5

var director: Node
## 这一段挨了多少（修补会减少）
var taken := 0.0
var shield_hp := 0.0
var shield_left := 0.0
var _dust_t := 0.0
var _hit_t := 0.0


func _setup() -> void:
	# 图例放在墙下第一行（墙面那一格要保持是墙）：节点往上挪一格，贴着墙的下沿
	position.y -= TILE
	set_faction(Faction.Type.PLAYER)
	add_to_group("siege_wall")
	collision_layer = 2
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# 墙面两格高 + 往下多 8 像素（怪物站在墙下就碰得到）
	rect.size = Vector2(w * TILE, TILE * 2.0 + 8.0)
	shape.shape = rect
	shape.position = Vector2(0, -TILE + 4.0)
	add_child(shape)
	z_index = 1


func width_px() -> float:
	return w * TILE


func left_x() -> float:
	return global_position.x - width_px() / 2.0


func right_x() -> float:
	return global_position.x + width_px() / 2.0


## 墙下沿（怪物站的那一条线）。
func foot_y() -> float:
	return global_position.y + 6.0


## 墙顶走道（蓝色公主站的那一条线）。
func top_y() -> float:
	return global_position.y - TILE * 2.0 - 8.0


func is_alive() -> bool:
	return director == null or float(director.get("wall_hp")) > 0.0


func receive_hit(hit: HitData) -> bool:
	if hit.kind != HitData.Kind.ATTACK or not is_alive():
		return false
	take(float(hit.damage) * DAMAGE_MULT * (hit.source.stat_mul("wall_damage") if hit.source is Actor else 1.0))
	return true


## 城墙挨打（攻城车直接调这个，不乘倍数）：先扣冰壳，剩下的扣总血量。
func take(amount: float) -> void:
	if amount <= 0.0:
		return
	if shield_left > 0.0 and shield_hp > 0.0:
		var absorbed := minf(shield_hp, amount)
		shield_hp -= absorbed
		amount -= absorbed
		if shield_hp <= 0.0:
			shield_left = 0.0
			Audio.play("ice_crack", -4.0, 0.1)
		if amount <= 0.0:
			_hit_t = 0.12
			queue_redraw()
			return
	taken += amount
	_hit_t = 0.12
	if director:
		director.damage_wall(self, amount)
	if _dust_t <= 0.0:
		_dust_t = DUST_GAP
		Fx.burst(get_parent(), Vector2(global_position.x + randf_range(-width_px() * 0.45, width_px() * 0.45), foot_y() - 4.0),
			"dust", 4, 26.0, 0.5, Vector2(0, -10), Color(0.75, 0.7, 0.7))
	queue_redraw()


func repair(amount: float) -> float:
	var r := minf(amount, taken)
	taken -= r
	if director and r > 0.0:
		director.repair_wall(self, r)
	queue_redraw()
	return r


func reinforce(hp: float, sec: float) -> void:
	shield_hp = hp
	shield_left = sec
	queue_redraw()


func climbable() -> bool:
	return shield_left <= 0.0


## 裂缝档位：这一段挨的伤害占「一段的份额」多少。
func damage_level() -> int:
	var share := float(director.get("wall_max")) / 8.0 if director else 250.0
	var f := taken / maxf(share, 1.0)
	return 2 if f > 0.66 else (1 if f > 0.25 else 0)


func _process(delta: float) -> void:
	_dust_t -= delta
	if _hit_t > 0.0:
		_hit_t -= delta
		if _hit_t <= 0.0:
			queue_redraw()
	if shield_left > 0.0:
		shield_left -= delta
		if shield_left <= 0.0:
			shield_hp = 0.0
			queue_redraw()


func _draw() -> void:
	var lvl := damage_level()
	var n := int(ceil(w))
	var x0 := -width_px() / 2.0
	for i in n:
		var r := SiegeArt.region("wall_%d" % (lvl if (i * 7 + index) % 3 != 0 or lvl == 0 else maxi(lvl - 1, 0)))
		var dst := Rect2(x0 + i * TILE, -TILE * 2.0, minf(TILE, width_px() - i * TILE), TILE * 2.0)
		var src := Rect2(r.position, Vector2(dst.size.x, r.size.y))
		draw_texture_rect_region(SiegeArt.TEX, dst, src, Color(1.6, 1.2, 1.2) if _hit_t > 0.0 else Color.WHITE)
		if shield_left > 0.0:
			var sr := SiegeArt.region("wall_shell")
			draw_texture_rect_region(SiegeArt.TEX, dst, Rect2(sr.position, Vector2(dst.size.x, sr.size.y)))

class_name PalaceWardrobe
extends PalaceRoom
## 第四章⑤·衣帽间（floor_06_palace_wardrobe，等距；台词 penance_text/palace2.py）：
##   礼服人台（mannequins，小剧场「量尺寸」）、旧装备衣架（racks ×3：试穿一小段 + 拿到旧王宫的装备）、一大一小两件礼服（dresses：尺码 7 = 密码一位）、
##   喜欢的礼服（favorite：试衣服、蓝色公主借量尺寸挠她，CG）、自动穿袜机（socks：「清洁」脚底 + 宫廷丝袜）、
##   羽毛披肩鬼（shawl）：在衣架间飘、缠人挠脖子和膝盖窝；蓝色公主走过去攻击（AI 自动）就冻住、变成「羽毛披肩」；
##   镜子迷宫（中间那片墙）+ 镜中人伸手（mirror_hands）；大衣口袋里的残页（fragment）；
##   衣柜陷阱（trap_wardrobe，对话 call palace_trap）：粉色公主被关进去（小剧场 wardrobe_trap_in，CG）→ 换蓝色公主操控、去 keys 里找钥匙
##     （对话 call palace_search_1/2/3，钥匙随机在其中一处）；这段时间粉色公主在柜子里闷笑一直涨（TRAP_TICK）→ 回到衣柜（call palace_trap_open）→ wardrobe_trap_out。
## 测试：trap_active、key_at、has_key、search(i)、start_trap()、open_trap()、shawl_frozen、freeze_shawl()。

const MAP := "floor_06_palace_wardrobe"
const TRAP_FLAG := "palace_trap_active"
const SHAWL_FLAG := "palace_shawl_frozen"
const MIRROR_R := 18.0   # 手从穿衣镜里伸出来（镜子占一格），从旁边走过也够得着
const SHAWL_SPEED := 26.0
const TRAP_TICK := 1.2

var trap_active := false
var key_at := -1
var has_key := false
var shawl_frozen := false
var _shawl: Shawl
var _mirror_t := {}
var _pink_hold := Vector2.ZERO


func map_id() -> String:
	return MAP


func _ready() -> void:
	super()
	shawl_frozen = GameState.has_flag(SHAWL_FLAG)
	GameState.set_flag(TRAP_FLAG, false)
	var mi := 0
	for c in cells("mannequins"):
		mi += 1
		_spot("floor_06/wardrobe_mannequin", c)
	var ri := 0
	for c in cells("racks"):
		ri += 1
		_spot("floor_06/wardrobe_rack_%d" % ri, c)
	_spot("floor_06/wardrobe_dresses", cells("dresses")[0])
	_spot("floor_06/wardrobe_favorite", cells("favorite")[0])
	_spot("floor_06/wardrobe_socks", cells("socks")[0])
	_spot("floor_06/wardrobe_fragment", cells("fragment")[0])
	_spot("floor_06/wardrobe_trap", cells("trap_wardrobe")[0])
	var ki := 0
	for c in cells("keys"):
		ki += 1
		_spot("floor_06/wardrobe_key_%d" % ki, c)
	for c in cells("mirror_hands"):
		var h := PalaceLibrary.HandMark.new()
		h.position = world(c)
		h.modulate = Color(0.75, 0.85, 1.0, 0.8)
		add_view(h)
	if not shawl_frozen:
		_shawl = Shawl.new()
		_shawl.room = self
		_shawl.home = world(cells("shawl")[0])
		_shawl.position = _shawl.home
		add_view(_shawl)


func _spot(dialogue: String, c: Vector2i) -> void:
	var sp := PrisonOddities.Spot.new()
	sp.dialogue = dialogue
	add_child(sp)
	sp.global_position = world(c)


func _process(delta: float) -> void:
	if busy():
		return
	if trap_active and is_instance_valid(pink):
		pink.global_position = _pink_hold
		pink.status.apply_root(0.3)
		tickle(pink, "trap", TRAP_TICK, 3.0, "sole", delta)
	for m in members():
		var pc := m as PlayableCharacter
		if Downed.is_downed(pc) or (trap_active and pc == pink):
			continue
		for c in cells("mirror_hands"):
			var k := str(c) + str(pc.get_instance_id())
			_mirror_t[k] = maxf(0.0, float(_mirror_t.get(k, 0.0)) - delta)
			if float(_mirror_t[k]) <= 0.0 and pc.global_position.distance_to(world(c)) <= MIRROR_R:
				_mirror_t[k] = 3.0
				var h := HitData.make_tickle(self, 6.0)
				h.zone = "waist"
				pc.receive_hit(h)
				PalaceRoom.say_random(pc, "mirror")
	if is_instance_valid(_shawl):
		_shawl.step(delta)


# ------------------------------------------------------------------ 衣柜陷阱
func start_trap() -> void:
	if trap_active or not is_instance_valid(pink):
		return
	await CG.play_theater("wardrobe_trap_in")
	trap_active = true
	GameState.set_flag(TRAP_FLAG)
	has_key = false
	key_at = randi() % cells("keys").size()
	_pink_hold = world(cells("trap_wardrobe")[0])
	pink.global_position = _pink_hold
	pink.modulate.a = 0.35
	if is_instance_valid(blue) and GameState.player != blue:
		GameState.switch_control(blue)
	PalaceRoom.say_random(blue, "trap_wait")


## 蓝色公主翻找第 i 处（1 起）
func search(i: int) -> bool:
	if not trap_active or has_key:
		return false
	if i - 1 == key_at:
		has_key = true
		Audio.play("unlock", -4.0, 0.0, 1.3)
		PalaceRoom.say_random(GameState.player, "key_found")
		return true
	PalaceRoom.say_random(GameState.player, "key_none")
	return false


func open_trap() -> void:
	if not trap_active:
		return
	if not has_key:
		PalaceRoom.say_random(GameState.player, "trap_wait")
		return
	await CG.play_theater("wardrobe_trap_out")
	trap_active = false
	GameState.set_flag(TRAP_FLAG, false)
	if is_instance_valid(pink):
		pink.modulate.a = 1.0
		pink.status.clear_root()
		pink.global_position = _pink_hold + Vector2(-16, 4)
		pink.laugh.set_value(pink.laugh.max_value * 0.3)


# ------------------------------------------------------------------ 羽毛披肩鬼
func freeze_shawl() -> void:
	if shawl_frozen:
		return
	shawl_frozen = true
	GameState.set_flag(SHAWL_FLAG)
	if is_instance_valid(_shawl):
		Fx.burst(get_parent(), _shawl.position + Vector2(0, -12), "dust", 12, 40.0, 0.6, Vector2(0, -10), Color(0.75, 0.9, 1.0))
		_shawl.queue_free()
	Audio.play("ice_crack", -4.0)
	var it := ItemDB.get_item("equip_feather_shawl")
	if it and not GameState.inventory.has("equip_feather_shawl"):
		GameState.inventory.add(it)
	GameState.notify("拿到了「羽毛披肩」")
	PalaceRoom.say_random(GameState.player, "shawl_freeze")


func ai_hooks() -> BattleAIHooks:
	return WardHooks.new(self)


class WardHooks extends BattleAIHooks:
	var r: PalaceWardrobe

	func _init(room: PalaceWardrobe) -> void:
		r = room

	func priority_target() -> Variant:
		if is_instance_valid(r._shawl) and not r.shawl_frozen and is_instance_valid(GameState.player) \
				and r._shawl.position.distance_to(GameState.player.global_position) < 90.0:
			return r._shawl
		return null


## 羽毛披肩鬼：在衣架间飘，缠住人挠脖子 / 膝盖窝；蓝色公主攻击它（冰）就冻住
class Shawl extends Node2D:
	var room: PalaceWardrobe
	var home := Vector2.ZERO
	var _t := 0.0
	var _cool := 0.0

	func step(delta: float) -> void:
		_t += delta
		_cool = maxf(0.0, _cool - delta)
		queue_redraw()
		var near: PlayableCharacter = null
		for c in room.members():
			var pc := c as PlayableCharacter
			if Downed.is_downed(pc):
				continue
			if pc.character_id == "blue" and pc.state == PlayableCharacter.State.ATTACK and pc.global_position.distance_to(position) <= 20.0:
				room.freeze_shawl()
				return
			if pc.global_position.distance_to(position) <= 90.0 and (near == null or pc.global_position.distance_to(position) < near.global_position.distance_to(position)):
				near = pc
		var target := near.global_position if near else home + Vector2(cos(_t), sin(_t * 1.3)) * 30.0
		position = position.move_toward(target, PalaceWardrobe.SHAWL_SPEED * delta)
		if near and position.distance_to(near.global_position) <= 10.0 and _cool <= 0.0:
			_cool = 2.5
			var h := HitData.make_tickle(self, 6.0)
			h.zone = "neck"
			near.receive_hit(h)
			PalaceRoom.say_random(near, "shawl")

	func _draw() -> void:
		var y := -18.0 + sin(_t * 2.0) * 3.0
		var pts := PackedVector2Array()
		for k in 9:
			var a := PI * k / 8.0
			pts.append(Vector2(cos(a) * 12.0, y + sin(a) * 6.0 + sin(_t * 4.0 + k) * 1.5))
		draw_polyline(pts, Color(0.98, 0.97, 1.0, 0.9), 4.0)
		for k in 5:
			var p := pts[k * 2]
			draw_line(p, p + Vector2(sin(_t * 3.0 + k) * 2.0, 6), Color(0.95, 0.93, 1.0, 0.85), 2.0)
		draw_circle(Vector2(-3, y - 2), 1.0, Color(0.3, 0.3, 0.45))
		draw_circle(Vector2(3, y - 2), 1.0, Color(0.3, 0.3, 0.45))

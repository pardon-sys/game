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
## 追加事件·旧鞋军团：鞋柜（shoe_closet）旁边 CLOSET_R 以内的旧鞋按 E 一次关进去；全关完 → SHOES_FLAG
const SHOES_FLAG := "palace_shoes_done"
const CLOSET_R := 70.0
## 追加事件·镜子迷宫（mirror_wall：生成器当墙；这里每格摆一块镜面墙板、替地形画墙）、失窃的小画像（fake_mirror 旁边那块「镜子」其实是画）
const PORTRAIT_FLAG := "palace_portrait_found"
var mirrors: Array = []

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
	if not cells("shoe_closet").is_empty():
		var csp := PrisonOddities.Spot.new()
		csp.dialogue = "floor_06/wardrobe_shoe_closet"
		csp.done_flag = SHOES_FLAG
		csp.prompt_y = -34.0
		add_child(csp)
		csp.global_position = world(cells("shoe_closet")[0])
	_build_mirrors.call_deferred()
	if not cells("fake_mirror").is_empty():
		var fsp := PrisonOddities.Spot.new()
		fsp.dialogue = "floor_06/wardrobe_fake_mirror"
		fsp.done_flag = PORTRAIT_FLAG
		add_child(fsp)
		fsp.global_position = world(cells("fake_mirror")[0])
	if GameState.has_flag(SHOES_FLAG):
		_clear_shoes.call_deferred()
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
## 镜面墙板：只摆在挨着地面的镜墙格上（埋在土里的不用），并让等距地形别再画这格的墙块
func _build_mirrors() -> void:
	var lvl := lv
	var fake := cells("fake_mirror")[0] + Vector2i(1, 0) if not cells("fake_mirror").is_empty() else Vector2i(-99, -99)
	var terrain := IsoTerrain.of(self)
	for c in cells("mirror_wall"):
		var open := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if GridPath.walkable(lvl, c + d):
				open = true
				break
		if not open:
			continue
		var m := MirrorPanel.new()
		m.cell = c
		m.portrait = c == fake
		m.position = PalaceRoom.cell_pos(c) + Vector2(0, 7)
		add_view(m)
		mirrors.append(m)
		if terrain:
			terrain.claim(c, m)


## 识破「镜子」：小画像醒过来挠一下，拿到「迷路的小画像」（带去王座间挂回空画框）
func find_portrait() -> bool:
	if GameState.has_flag(PORTRAIT_FLAG):
		return false
	GameState.set_flag(PORTRAIT_FLAG)
	var pc := GameState.player as PlayableCharacter
	if pc:
		for k in 3:
			var h := HitData.make_tickle(self, 2.5)
			h.zone = "neck"
			pc.receive_hit(h)
	var it := ItemDB.get_item("lost_portrait")
	if it:
		GameState.give_item(it, 1)
	GameState.notify("得到「迷路的小画像」——王座间好像少了一幅")
	return true


func shoes() -> Array:
	return lv.find_children("*", "OldShoe", true, false).filter(func(m): return (m as Monster).is_alive()) if lv else []


func _clear_shoes() -> void:
	for m in shoes():
		(m as Node).queue_free()


## 鞋柜关门：附近的旧鞋全关进去（被套住的脚也松开）
func close_closet() -> int:
	var c := world(cells("shoe_closet")[0])
	var n := 0
	for m in shoes():
		if (m as Node2D).global_position.distance_to(c) <= CLOSET_R:
			for pc in members():
				if (pc as PlayableCharacter).status.is_grabbed_by(m):
					(pc as PlayableCharacter).status.release()
			(m as Node).queue_free()
			n += 1
	Audio.play("door_close", -2.0)
	if n == 0:
		GameState.notify("鞋柜「砰」地关上了……里面空空的。先把旧鞋引过来")
		return 0
	var left := shoes().size() - n
	if left <= 0:
		GameState.set_flag(SHOES_FLAG)
		GameState.notify("旧鞋全关进鞋柜了！")
		PalaceRoom.say_random(GameState.player, "shoes_done")
	else:
		GameState.notify("关进去 %d 只旧鞋，还剩 %d 只" % [n, left])
	return n


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


## 镜子迷宫的一块墙：一人多高的镜面板（palace_props4 第 5 帧），镜子里隐约映着走过的人影；
## portrait = 失窃的小画像伪装成的那一块（没识破之前画框里是一张笑脸，识破以后变回普通镜子）
class MirrorPanel extends Node2D:
	var cell := Vector2i.ZERO
	var portrait := false
	var _s: Sprite2D

	func _ready() -> void:
		add_to_group(IsoTerrain.OWNER_GROUP)
		if ResourceLoader.exists(PalaceRoom.PROPS4):
			_s = Sprite2D.new()
			_s.texture = load(PalaceRoom.PROPS4)
			_s.hframes = 6
			_s.frame = 5
			_s.offset = Vector2(0, -24)
			_s.scale = Vector2(0.9, 1.0)
			_s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_s)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var shine := 0.12 + 0.08 * sin(Time.get_ticks_msec() / 500.0 + cell.x * 0.7 + cell.y * 0.3)
		draw_rect(Rect2(-6, -40, 12, 30), Color(0.85, 0.95, 1.0, shine))
		if portrait and not GameState.has_flag(PalaceWardrobe.PORTRAIT_FLAG):
			draw_circle(Vector2(0, -26), 5.0, Color(0.95, 0.85, 0.7, 0.9))
			draw_arc(Vector2(0, -26), 5.0, 0.3, PI - 0.3, 8, Color(0.4, 0.2, 0.2), 1.0)
		if _s == null:
			draw_rect(Rect2(-7, -42, 14, 40), Color(0.75, 0.85, 0.95))

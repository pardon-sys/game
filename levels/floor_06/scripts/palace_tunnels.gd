class_name PalaceTunnels
extends PalaceRoom
## 第四章⑨·隧道与密室（floor_06_palace_tunnels；台词 penance_text/palace3.py）：
##   第一次从王座前厅的画后进来（东）；各房间的密道口（to_bath / to_library / to_wardrobe / to_training）从隧道这一边走到过才打开
##   （SECRET_FLAG % 房间：那边房间的 exit 用这个 unlock_flag），打开以后两边都能走 = 抄近路。
##   收路费的小鬼（toll）：入口西边一道栅栏挡着（所有路线都要过，每次进这张图都要重新付；有失物招领换来的通行证就免），走近自动开口要钱（对话 call palace_toll_mint / _coin / _tickle；
##     薄荷糖 1 颗、金币 TOLL_COINS 枚，或者「用痒付」= 小剧场 tunnel_toll（CG））→ TOLL_FLAG，栅栏拆掉；
##   羽毛蛛网（webs）：挡住整条路，碰到 = 粘住（定身）+ 小蜘蛛挠；粉色公主攻击 / 施法烧掉（AI 粉色公主会去烧）；
##   四口宝箱（chests，对话 call palace_tunnel_chest_N）：一口是真的（REAL_VAR，第一次进来随机），其余是宝箱怪（咬住脚踝挠脚底）；
##   女王的寝室（quilt 羽毛被子：小剧场 tunnel_quilt（CG）/ 梳妆台 / 日记）、婴儿房（cradles 摇篮：小剧场 tunnel_cradle / 旋转吊铃：摇篮曲 / 刻痕）。
## 测试：toll_paid()、pay(kind)、webs_alive()、burn(i)、web_stuck、real_chest()、open_chest(i)、mimic_bites。

const MAP := "floor_06_palace_tunnels"
const TOLL_FLAG := "palace_toll_paid"
const SEEN_FLAG := "palace_tunnels_seen"
const REAL_VAR := "palace_real_chest"
const SECRET_FLAG := "palace_secret_%s"
const TOLL_COINS := 30
const TOLL_R := 22.0   # 走到栅栏跟前（两边都行）才开口；入口出生点离栅栏两格，不会一进来就被拦
const WEB_R := 14.0
const BURN_R := 26.0
## 追加事件：失物招领（小鬼的五样东西散在五张图：PalaceRoom.LOST_ITEMS；lost_board 按 E 交还 → 免路费通行证 + 徽记）
const LOST_DONE := "palace_lost_done"
## 黑暗区：往婴儿房去的西边支路（DARK_RECT）。只有蓝色公主脚边一圈冰光（LIGHT_R）；粉色公主离开光圈 DARK_GRAB 秒 → 暗处的手抓住挠
const DARK_RECT := Rect2i(10, 32, 3, 15)
const LIGHT_R := 44.0
const DARK_GRAB := 1.5
var dark_cells: Array = []
var _dark_t := 0.0
const SECRETS := {"to_bath": "bath", "to_library": "library", "to_wardrobe": "wardrobe", "to_training": "training"}

var webs: Array = []
var web_stuck := {}
var mimic_bites := 0
var _toll_body: StaticBody2D
var _toll_cool := 0.0
var _imps: Node2D
var _chest_views: Array = []


func map_id() -> String:
	return MAP


func toll_pos() -> Vector2:
	return world(Vector2i(cells("toll")[0].x, 29))


func _ready() -> void:
	super()
	# 路费每趟都要付：进图时清掉「付过了」（有通行证 = 失物招领做完，就一直算付过）
	GameState.set_flag(TOLL_FLAG, GameState.has_flag(LOST_DONE))
	GameState.set_flag(SEEN_FLAG)
	if not GameState.vars.has(REAL_VAR):
		GameState.vars[REAL_VAR] = randi() % 4 + 1
	for pair in [["quilt", "floor_06/tunnel_quilt"], ["vanity", "floor_06/tunnel_vanity"], ["diary", "floor_06/tunnel_diary"],
			["mobile", "floor_06/tunnel_mobile"], ["height_marks", "floor_06/tunnel_marks"]]:
		_spot(str(pair[1]), cells(str(pair[0]))[0])
	_spot("floor_06/tunnel_cradle", cells("cradles")[0])
	# 婴儿房的图：两个摇篮（粉 / 蓝丝带）、旋转吊铃
	var ci := 0
	for c in cells("cradles"):
		sheet_view(PalaceRoom.PROPS3, 6, 1 + ci % 2, c, [], 0.8)
		ci += 1
	sheet_view(PalaceRoom.PROPS3, 6, 3, cells("mobile")[0], [], 0.8)
	var i := 0
	for c in cells("chests"):
		i += 1
		_spot("floor_06/tunnel_chest_%d" % i, c)
		var cv := MimicChestView.new()
		cv.idx = i
		cv.room = self
		cv.position = world(c)
		add_view(cv)
		_chest_views.append(cv)
	if not toll_paid():
		var tx := cells("toll")[0].x
		_toll_body = _block([Vector2i(tx, 28), Vector2i(tx, 29), Vector2i(tx, 30)])
		_imps = TollView.new()
		_imps.position = world(Vector2i(tx, 29))
		add_view(_imps)
	if not cells("lost_board").is_empty():
		var lsp := PrisonOddities.Spot.new()
		lsp.dialogue = "floor_06/tunnel_lost"
		lsp.done_flag = LOST_DONE
		add_child(lsp)
		lsp.global_position = world(cells("lost_board")[0])
	for y in range(DARK_RECT.position.y, DARK_RECT.end.y):
		for x in range(DARK_RECT.position.x, DARK_RECT.end.x):
			var dc := DarkCell.new()
			dc.room = self
			dc.position = PalaceRoom.cell_pos(Vector2i(x, y))
			dc.z_index = 20
			add_view(dc)
			dark_cells.append(dc)
	var wi := 0
	for c in cells("webs"):
		if GameState.has_flag("palace_web_%d" % wi):
			wi += 1
			continue
		var line: Array = [c + Vector2i(0, -1), c, c + Vector2i(0, 1)] if c.y == 29 else [c + Vector2i(-1, 0), c, c + Vector2i(1, 0)]
		var w := WebView.new()
		w.idx = wi
		w.vertical = c.y == 29
		w.position = world(c)
		w.body = _block(line)
		add_view(w)
		webs.append(w)
		wi += 1


func _spot(dialogue: String, c: Vector2i) -> void:
	var sp := PrisonOddities.Spot.new()
	sp.dialogue = dialogue
	add_child(sp)
	sp.global_position = world(c)


func _block(cs: Array) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for c in cs:
		var sh := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(16, 16)
		sh.shape = r
		sh.position = PalaceRoom.cell_pos(c)
		body.add_child(sh)
	add_child(body)
	return body


func _process(delta: float) -> void:
	if busy():
		return
	update_checkpoints()
	_toll_cool = maxf(0.0, _toll_cool - delta)
	# 走到过的密道口：那边房间的入口打开
	for key in SECRETS:
		var f := SECRET_FLAG % SECRETS[key]
		if not GameState.has_flag(f):
			for m in members():
				if (m as Node2D).global_position.distance_to(world(cells(key)[0])) <= 40.0:
					GameState.set_flag(f)
	# 收路费
	# 收路费（只认玩家操控的那个人走过来；搭档站在旁边不算）
	if not toll_paid() and _toll_cool <= 0.0 and is_instance_valid(GameState.player) \
			and GameState.player.global_position.distance_to(toll_pos()) <= TOLL_R:
		_toll_cool = 6.0
		Dialogue.talk("floor_06/tunnel_toll")
		return
	for m in members():
		var pc := m as PlayableCharacter
		if Downed.is_downed(pc):
			continue
		web_stuck[pc] = maxf(0.0, float(web_stuck.get(pc, 0.0)) - delta)
		for w in webs:
			if not is_instance_valid(w):
				continue
			var wv := w as WebView
			var d := pc.global_position.distance_to(wv.position)
			if pc.character_id == "pink" and (pc.state == PlayableCharacter.State.ATTACK or pc.state == PlayableCharacter.State.CAST) and d <= BURN_R:
				burn(wv.idx)
				break
			if d <= WEB_R and float(web_stuck[pc]) <= 0.0:
				web_stuck[pc] = 2.5
				pc.status.apply_root(1.0)
				var h := HitData.make_tickle(wv, 5.0)
				h.zone = "waist"
				pc.receive_hit(h)
				PalaceRoom.say_random(pc, "web")
	webs = webs.filter(func(w): return is_instance_valid(w))
	_tick_dark(delta)


# ------------------------------------------------------------------ 黑暗区
func in_dark(pos: Vector2) -> bool:
	return DARK_RECT.has_point(Vector2i(floori(pos.x / 16.0), floori(pos.y / 16.0)))


## 这一点被蓝色公主的冰光照到多少（0 全黑 ~ 1 亮）
func light_at(pos: Vector2) -> float:
	if not is_instance_valid(blue):
		return 0.0
	var d := pos.distance_to(blue.global_position)
	return clampf(1.0 - (d - LIGHT_R * 0.5) / (LIGHT_R * 0.5), 0.0, 1.0)


func _tick_dark(delta: float) -> void:
	if not is_instance_valid(pink) or Downed.is_downed(pink):
		return
	if in_dark(pink.global_position) and pink.global_position.distance_to(blue.global_position if is_instance_valid(blue) else Vector2(-9999, 0)) > LIGHT_R:
		_dark_t += delta
		if _dark_t >= DARK_GRAB:
			dark_grab()
	else:
		_dark_t = maxf(0.0, _dark_t - delta)


## 暗处伸出手来：抓住脚踝挠一阵
func dark_grab() -> void:
	_dark_t = -1.5
	pink.status.apply_root(1.0)
	Audio.play("hand_grab", -4.0)
	for k in 4:
		var h := HitData.make_tickle(self, 2.5)
		h.zone = ["sole", "waist"].pick_random()
		pink.receive_hit(h)
	PalaceRoom.say_random(pink, "dark_hand")


# ------------------------------------------------------------------ 失物招领
func lost_return() -> bool:
	if GameState.has_flag(LOST_DONE):
		return true
	var n := PalaceRoom.lost_found()
	if n < PalaceRoom.LOST_NAMES.size():
		var miss := PalaceRoom.LOST_NAMES.keys().filter(func(k): return not GameState.has_flag(PalaceRoom.lost_flag(k)))
		GameState.notify("失物：%d / %d。还没找到：%s" % [n, PalaceRoom.LOST_NAMES.size(), "、".join(miss.map(func(k): return PalaceRoom.LOST_NAMES[k]))])
		return false
	GameState.set_flag(LOST_DONE)
	GameState.notify("小鬼给了一张「免路费通行证」")
	if not toll_paid():
		GameState.set_flag(TOLL_FLAG)
		if is_instance_valid(_toll_body):
			_toll_body.queue_free()
		if is_instance_valid(_imps):
			_imps.queue_free()
	PalaceRoom.give_badge("lost")
	return true


# ------------------------------------------------------------------ 收路费
func toll_paid() -> bool:
	return GameState.has_flag(TOLL_FLAG)


## kind = mint / coin / tickle；没有东西付就返回 false
func pay(kind: String) -> bool:
	if toll_paid():
		return true
	match kind:
		"mint":
			if not GameState.inventory.has("mint"):
				GameState.notify("没有薄荷糖了……")
				return false
			GameState.inventory.remove("mint", 1)
		"coin":
			if not GameState.inventory.has("coin", TOLL_COINS):
				GameState.notify("金币不够 %d 枚……" % TOLL_COINS)
				return false
			GameState.inventory.remove("coin", TOLL_COINS)
		"tickle":
			await CG.play_theater("tunnel_toll")
	GameState.set_flag(TOLL_FLAG)
	if is_instance_valid(_toll_body):
		_toll_body.queue_free()
	if is_instance_valid(_imps):
		_imps.queue_free()
	Audio.play("unlock", -4.0)
	GameState.notify("小鬼们让开了路")
	return true


# ------------------------------------------------------------------ 蛛网
func webs_alive() -> int:
	return webs.filter(func(w): return is_instance_valid(w)).size()


func burn(idx: int) -> void:
	for w in webs:
		if not is_instance_valid(w):
			continue
		var wv := w as WebView
		if wv.idx == idx:
			GameState.set_flag("palace_web_%d" % idx)
			Fx.burst(get_parent(), wv.position + Vector2(0, -10), "dust", 14, 40.0, 0.6, Vector2(0, -12), Color(1.0, 0.75, 0.9))
			Audio.play("ice_crack", -6.0, 0.0, 1.4)
			if is_instance_valid(wv.body):
				wv.body.queue_free()
			wv.queue_free()
			PalaceRoom.say_random(GameState.player, "burn")
	webs = webs.filter(func(w): return is_instance_valid(w) and (w as WebView).idx != idx)


# ------------------------------------------------------------------ 宝箱 / 宝箱怪
func real_chest() -> int:
	return int(GameState.vars.get(REAL_VAR, 1))


func open_chest(i: int) -> bool:
	var flag := "palace_tunnel_chest_%d" % i
	if GameState.has_flag(flag):
		return false
	GameState.set_flag(flag)
	var pc := GameState.player as PlayableCharacter
	if i == real_chest():
		GameState.give_item(ItemDB.get_item("mint"), 2)
		GameState.give_item(ItemDB.get_item("coin"), 40)
		GameState.notify("真的宝箱：薄荷糖 ×2、金币 ×40")
		PalaceRoom.say_random(pc, "chest_ok")
		return true
	mimic_bites += 1
	# 追加事件·宝箱怪的逃亡：第一次被咬以后，它跑出隧道躲进各个房间（厨房冷藏库 → 图书馆 → 衣帽间）
	if not GameState.has_flag(PalaceRoom.MIMIC_FLED):
		GameState.set_flag(PalaceRoom.MIMIC_FLED)
		GameState.vars[PalaceRoom.MIMIC_STAGE] = 0
		GameState.notify("咬人的宝箱怪「咔嗒咔嗒」地跑出了隧道……")
	if is_instance_valid(pc):
		pc.status.apply_root(2.0)
		var h := HitData.make_tickle(self, 9.0)
		h.zone = "sole"
		pc.receive_hit(h)
		PalaceRoom.say_random(pc, "mimic")
	Audio.play("gate", -6.0, 0.0, 1.8)
	return false


func ai_hooks() -> BattleAIHooks:
	return TunnelHooks.new(self)


class TunnelHooks extends BattleAIHooks:
	var r: PalaceTunnels

	func _init(room: PalaceTunnels) -> void:
		r = room

	## AI 是蓝色公主、粉色公主进了黑暗区：贴着她走（冰光照着她）
	func objective_for(ai: PlayableCharacter) -> Variant:
		if ai.character_id == "blue" and is_instance_valid(r.pink) and r.in_dark(r.pink.global_position):
			return r.pink.global_position
		return null

	## AI 是粉色公主：离玩家近的蛛网先烧
	func priority_target() -> Variant:
		var p := GameState.player
		if not is_instance_valid(p) or (p as PlayableCharacter).character_id == "pink":
			return null
		for w in r.webs:
			if is_instance_valid(w) and (w as Node2D).position.distance_to(p.global_position) < 90.0:
				return w
		return null


class TollView extends Node2D:
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-3, -40, 6, 40), Color(0.5, 0.35, 0.2))
		draw_rect(Rect2(-2, -38, 4, 34), Color(0.85, 0.3, 0.3))
		for k in 3:
			var p := Vector2(10 + k * 6, -14 - k * 10 + sin(_t * 4.0 + k) * 2.0)
			draw_circle(p, 4.0, Color(0.55, 0.3, 0.6))
			draw_circle(p + Vector2(-1.5, -1), 0.9, Color(1, 1, 0.5))
			draw_circle(p + Vector2(1.5, -1), 0.9, Color(1, 1, 0.5))
			draw_line(p + Vector2(-4, 0), p + Vector2(-7, -3), Color(0.4, 0.2, 0.45), 1.5)


class WebView extends Node2D:
	var idx := 0
	var vertical := true
	var body: StaticBody2D

	func _draw() -> void:
		var col := Color(1, 1, 1, 0.75)
		var axis := Vector2(0, 16) if vertical else Vector2(16, 0)
		var c := Vector2(0, -10)
		for k in 6:
			var a := TAU * k / 6.0
			draw_line(c, c + Vector2(cos(a) * axis.length() * (1.4 if vertical else 1.0), sin(a) * 12.0), col, 1.0)
		for r in [4.0, 8.0, 12.0]:
			draw_arc(c, r, 0, TAU, 12, col, 1.0)
		draw_line(c - axis * 1.4, c + axis * 1.4, col, 1.0)
		draw_circle(c + Vector2(5, 3), 2.0, Color(0.2, 0.15, 0.2))


class MimicChestView extends Node2D:
	var idx := 0
	var room: PalaceTunnels
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var opened := GameState.has_flag("palace_tunnel_chest_%d" % idx)
		var mimic := room != null and idx != room.real_chest()
		var breathe := sin(_t * 2.0 + idx) * 0.8 if mimic and not opened else 0.0
		draw_rect(Rect2(-8, -10, 16, 10), Color(0.55, 0.32, 0.15))
		draw_rect(Rect2(-8, -15 - breathe, 16, 5), Color(0.6, 0.36, 0.18))
		draw_rect(Rect2(-2, -12, 4, 4), Color(0.9, 0.75, 0.3))
		if opened and mimic:
			for k in 5:
				draw_colored_polygon(PackedVector2Array([Vector2(-7 + k * 3, -10), Vector2(-5.5 + k * 3, -6), Vector2(-4 + k * 3, -10)]), Color(1, 1, 1))
			draw_circle(Vector2(-3, -13), 1.2, Color(1, 0.3, 0.3))
			draw_circle(Vector2(3, -13), 1.2, Color(1, 0.3, 0.3))


## 黑暗区的一格：离蓝色公主越远越黑（矮一点的暗柱子，人走进去也看不清）
class DarkCell extends Node2D:
	var room: PalaceTunnels

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var a := 0.96 * (1.0 - room.light_at(global_position)) if room else 0.96
		if a <= 0.02:
			return
		var top := Vector2(0, -40)
		var p := [IsoView.offset(Vector2(-8, -8)), IsoView.offset(Vector2(8, -8)), IsoView.offset(Vector2(8, 8)), IsoView.offset(Vector2(-8, 8))]
		var col := Color(0.02, 0.02, 0.05, a)
		draw_colored_polygon(PackedVector2Array([p[0] + top, p[1] + top, p[1], p[2], p[3], p[3] + top]), col)
		draw_colored_polygon(PackedVector2Array([p[0] + top, p[1] + top, p[2] + top, p[3] + top]), col)

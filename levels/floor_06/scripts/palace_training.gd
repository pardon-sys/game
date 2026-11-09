class_name PalaceTraining
extends PalaceRoom
## 第四章⑥·骑士训练场（floor_06_palace_training，等距；台词 penance_text/palace2.py）：
##   稻草人 / 木人桩（dummies ×4）：按木牌（sign）上的顺序打（ORDER：最左 → 最右 → 中间两个从右往左）才不还手；打错了被挠、顺序重来；全对 → DUMMY_FLAG（奖励薄荷糖）。
##   训练羽毛剑阵（swords）：一排羽毛剑来回挥，挥到底时旁边的人被扫到（看准间隔过去）。
##   墙上的刻痕（carvings：骑士名下三道 = 密码一位）；队长的旧日志（diary）；
##   对练擂台（ring，对话 call palace_spar）：沿用「点灯笼」支线的找痒点小游戏（BlueTickleShow，背靠背互挠）→ 赢 / 输各一段小剧场；
##   习武鸣钟（bell，对话 call palace_bell_fight）：遭遇战——四面的门关上，三波怪（WAVES），全打倒 → CLEAR_FLAG（残页箱子 fragment 打开）；
##     两个都倒下 → training_lose → 这一战重来；
##   耐痒训练台（stocks，小剧场 + 被动「骑士的忍耐」）；北门 north（通往王座间的回廊，封印着）。
## 测试：order_i、hit_dummy(i)、swords、start_fight()、wave、fighting、clear_fight()、spar_result。

const MAP := "floor_06_palace_training"
const DUMMY_FLAG := "palace_dummies_done"
const CLEAR_FLAG := "palace_training_cleared"
const ORDER := [0, 3, 2, 1]
const DUMMY_R := 18.0
const SWORD_CYCLE := 1.6
const SWORD_R := 10.0
## 一波比一波多：5 → 6（两只幽灵：要点亮擂台四周的火把才看得见）→ 巨魔 + 4 只小怪
const WAVES := [["rat", "rat", "spider", "spider", "rat"], ["ghost", "ghost", "glove", "bat", "bat", "bat"], ["troll", "rat", "spider", "glove", "bat"]]
const MONSTERS := {"rat": "res://scenes/actors/monsters/foot_rat.tscn", "spider": "res://scenes/actors/monsters/tickle_spider.tscn",
	"ghost": "res://scenes/actors/monsters/tickle_ghost.tscn", "glove": "res://scenes/actors/monsters/ghost_glove.tscn",
	"bat": "res://scenes/actors/monsters/feather_bat.tscn", "troll": "res://scenes/actors/monsters/tickle_troll.tscn"}

var order_i := 0
var dummies: Array = []
var swords: Array = []
var fighting := false
var wave := 0
var spawned: Array = []
var spar_result := ""
var _gates: Array = []
var _dummy_cool := {}


func map_id() -> String:
	return MAP


func _ready() -> void:
	super()
	for pair in [["sign", "floor_06/training_sign"], ["carvings", "floor_06/training_carvings"], ["diary", "floor_06/training_diary"],
			["ring", "floor_06/training_ring"], ["bell", "floor_06/training_bell"], ["stocks", "floor_06/training_stocks"], ["fragment", "floor_06/training_chest"]]:
		var sp := PrisonOddities.Spot.new()
		sp.dialogue = str(pair[1])
		add_child(sp)
		sp.global_position = world(cells(str(pair[0]))[0])
	var i := 0
	var dcells := cells("dummies")
	dcells.sort_custom(func(a, b): return a.x < b.x)   # 从左到右编号（木牌上的「最左 / 最右」）
	for c in dcells:
		var d := Dummy.new()
		d.idx = i
		d.position = world(c)
		add_view(d)
		dummies.append(d)
		i += 1
	for c in cells("swords"):
		var s := Sword.new()
		s.t = float(swords.size()) * 0.27
		s.position = world(c)
		add_view(s)
		swords.append(s)
	var bell := Bell.new()
	bell.room = self
	bell.position = world(cells("bell")[0])
	add_view(bell)
	if GameState.has_flag(DUMMY_FLAG):
		for d in dummies:
			(d as Dummy).lit = true
	if not cells("shade").is_empty():
		var ssp := PrisonOddities.Spot.new()
		ssp.dialogue = "floor_06/training_shade"
		ssp.done_flag = SHADE_FLAG
		ssp.prompt_y = -30.0
		add_child(ssp)
		ssp.global_position = world(cells("shade")[0])
		var post := ShadePost.new()
		post.position = world(cells("shade")[0])
		add_view(post)


func _process(delta: float) -> void:
	if busy():
		return
	_tick_shade(delta)
	for m in members():
		var pc := m as PlayableCharacter
		if Downed.is_downed(pc):
			continue
		# 稻草人
		if pc.state == PlayableCharacter.State.ATTACK:
			for d in dummies:
				var dm := d as Dummy
				var k := str(dm.idx)
				if float(_dummy_cool.get(k, 0.0)) <= 0.0 and pc.global_position.distance_to(dm.position) <= DUMMY_R:
					_dummy_cool[k] = 0.6
					hit_dummy(dm.idx, pc)
		# 羽毛剑
		for s in swords:
			var sw := s as Sword
			if sw.swinging() and pc.global_position.distance_to(sw.position) <= SWORD_R:
				tickle(pc, "sword" + str(sw.get_instance_id()), 0.5, 4.0, "sole", delta, sw)
	for k in _dummy_cool.keys():
		_dummy_cool[k] = maxf(0.0, float(_dummy_cool[k]) - delta)
	for s in swords:
		(s as Sword).t += delta
	if fighting:
		_tick_fight()


func hit_dummy(i: int, pc: PlayableCharacter = null) -> bool:
	if GameState.has_flag(DUMMY_FLAG):
		return true
	var d := dummies[i] as Dummy
	if ORDER[order_i] == i:
		d.lit = true
		order_i += 1
		Audio.play("chime", -6.0, 0.0, 1.0 + order_i * 0.1)
		if is_instance_valid(pc):
			PalaceRoom.say_random(pc, "dummy_ok")
		if order_i >= ORDER.size():
			GameState.set_flag(DUMMY_FLAG)
			var mint := ItemDB.get_item("mint")
			if mint:
				GameState.inventory.add(mint, 1)
			GameState.notify("稻草人们一起鞠了一躬——拿到了「薄荷糖」")
		return true
	# 打错：稻草人还手，顺序重来
	order_i = 0
	for x in dummies:
		(x as Dummy).lit = false
	d.punch = 0.5
	if is_instance_valid(pc):
		var h := HitData.make_tickle(d, 8.0)
		h.zone = "waist"
		pc.receive_hit(h)
		PalaceRoom.say_random(pc, "dummy_bad")
	return false


# ------------------------------------------------------------------ 对练擂台（找痒点小游戏）
func spar() -> String:
	await CG.play_theater("training_spar_in")
	var show := SparShow.new()
	show.mode = "tickle"
	get_tree().root.add_child(show)
	var ok: bool = await show.play()
	if is_instance_valid(show):
		show.queue_free()
	spar_result = "win" if ok else "lose"
	await CG.play_theater("training_spar_win" if ok else "training_spar_lose")
	return spar_result


# ------------------------------------------------------------------ 习武鸣钟：遭遇战
func start_fight() -> void:
	if fighting or GameState.has_flag(CLEAR_FLAG):
		return
	await Cutscene.play("training_bell_fight")
	while Cutscene.is_playing():
		await get_tree().process_frame
	fighting = true
	wave = 0
	for c in [cells("east")[0] + Vector2i(-1, 0), cells("north")[0] + Vector2i(0, 1)]:
		_gates.append(_block(c))
	_spawn_wave()


func _block(c: Vector2i) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 16)
	sh.shape = r
	body.add_child(sh)
	add_child(body)
	body.global_position = PalaceRoom.cell_pos(c)
	return body


func _spawn_wave() -> void:
	spawned.clear()
	var lines: Array = PalaceRoom.data().get("wave", [])
	if wave < lines.size():
		GameState.notify(str(lines[wave]), 2.0)
	var center := world(cells("ring")[0])
	var keys: Array = WAVES[wave]
	for i in keys.size():
		var path := str(MONSTERS[keys[i]])
		if not ResourceLoader.exists(path):
			continue
		var m: Node2D = load(path).instantiate()
		get_parent().add_child(m)
		m.global_position = center + Vector2.from_angle(TAU * i / maxf(1, keys.size())) * 70.0
		if keys[i] == "troll":
			m.scale = Vector2(1.3, 1.3)
		spawned.append(m)


func _tick_fight() -> void:
	spawned = spawned.filter(func(m): return is_instance_valid(m) and (not m.has_method("is_alive") or m.is_alive()))
	if not spawned.is_empty():
		return
	wave += 1
	if wave >= WAVES.size():
		clear_fight()
	else:
		_spawn_wave()


func clear_fight() -> void:
	fighting = false
	GameState.set_flag(CLEAR_FLAG)
	for g in _gates:
		if is_instance_valid(g):
			(g as Node).queue_free()
	_gates.clear()
	Cutscene.play("training_bell_clear")


## 遭遇战里两个都倒下：小剧场 → 这一战重来（怪清掉、门打开）
func defeat_theater() -> String:
	if shade_round > 0:
		return "training_shade"
	return "training_lose" if fighting else "palace_down"


func on_defeat(reason: String) -> void:
	if shade_round > 0 and not _defeat_busy:
		_defeat_busy = true
		_clear_shades()
		await CG.play_theater("training_shade")
		reset_to(world(cells("shade")[0]) + Vector2(0, 30))
		_defeat_busy = false
		return
	if fighting and not _defeat_busy:
		_defeat_busy = true
		fighting = false
		for m in spawned:
			if is_instance_valid(m):
				(m as Node).queue_free()
		spawned.clear()
		for g in _gates:
			if is_instance_valid(g):
				(g as Node).queue_free()
		_gates.clear()
		await CG.play_theater("training_lose")
		reset_to(world(cells("bell")[0]) + Vector2(0, 24))
		_defeat_busy = false
		return
	await super(reason)


# ------------------------------------------------------------------ 追加事件：年轻队长的幽影（三回合对练）
## 第一回合：一个幽影，羽毛剑连刺（THRUST_EVERY）；第二回合：分出两个；第三回合：「队长的绝招」每 WAVE_EVERY 秒全场羽毛风暴。
## 每回合打掉 SHADE_HP 下（第二回合两个各 SHADE_HP_SPLIT）。输了（两个人都倒下）→ 耐痒训练小剧场 training_shade（CG）；赢了 → 徽记 + 一句话。
const SHADE_FLAG := "palace_shade_done"
const SHADE_HP := 6
const SHADE_HP_SPLIT := 4
const SHADE_SPEED := 40.0
const THRUST_EVERY := 1.3
const THRUST_R := 26.0
const WAVE_EVERY := 3.2
const SHADE_HIT_R := 26.0
var shade_round := 0
var shades: Array = []
var _wave_t := WAVE_EVERY
var _shade_was := {}


func start_shade() -> void:
	if GameState.has_flag(SHADE_FLAG) or shade_round > 0:
		return
	shade_round = 1
	_spawn_shades(1, SHADE_HP)
	Audio.play("chime", -4.0, 0.0, 0.7)


func _spawn_shades(n: int, hp: int) -> void:
	_clear_shades()
	var c := world(cells("shade")[0])
	for k in n:
		var sh := Shade.new()
		sh.room = self
		sh.hp = hp
		sh.position = c + Vector2(-20 + 40 * k if n > 1 else 0, -10)
		add_view(sh)
		shades.append(sh)
	var lines: Array = PalaceRoom.data().get("shade_round_%d" % shade_round, []) as Array
	if not lines.is_empty() and not shades.is_empty():
		SpeechBubble.say(shades[0], str(lines.pick_random()), 40.0, 2.0)


func _clear_shades() -> void:
	for sh in shades:
		if is_instance_valid(sh):
			(sh as Node).queue_free()
	shades.clear()


func shades_alive() -> int:
	return shades.filter(func(sh): return is_instance_valid(sh) and (sh as Shade).hp > 0).size()


func _tick_shade(delta: float) -> void:
	if shade_round <= 0:
		return
	var ms: Array = members().filter(func(m): return not Downed.is_downed(m as PlayableCharacter))
	for m in ms:
		var pc := m as PlayableCharacter
		var atk := pc.state == PlayableCharacter.State.ATTACK
		if atk and not bool(_shade_was.get(pc, false)):
			for sh in shades:
				if is_instance_valid(sh) and (sh as Shade).hp > 0 and pc.global_position.distance_to((sh as Node2D).position) <= SHADE_HIT_R:
					(sh as Shade).hurt()
					break
		_shade_was[pc] = atk
	for sh in shades:
		if is_instance_valid(sh):
			(sh as Shade).step(ms, delta)
	if shade_round == 3:
		_wave_t -= delta
		if _wave_t <= 0.0:
			_wave_t = WAVE_EVERY
			shade_wave()
	if shades_alive() == 0:
		next_shade_round()


## 第三回合的绝招：全场的羽毛风暴（冲刺中的人躲得开）
func shade_wave() -> void:
	Audio.play("wind", -4.0)
	for m in members():
		var pc := m as PlayableCharacter
		if pc.state == PlayableCharacter.State.DASH:
			continue
		for k in 3:
			var h := HitData.make_tickle(self, 2.5)
			h.zone = ["armpit", "waist", "sole"].pick_random()
			pc.receive_hit(h)
	PalaceRoom.say_random(GameState.player, "shade_wave")


func next_shade_round() -> void:
	shade_round += 1
	if shade_round == 2:
		_spawn_shades(2, SHADE_HP_SPLIT)
	elif shade_round == 3:
		_wave_t = WAVE_EVERY
		_spawn_shades(1, SHADE_HP)
	else:
		_clear_shades()
		shade_round = 0
		GameState.set_flag(SHADE_FLAG)
		PalaceRoom.give_badge("shade")
		Dialogue.talk("floor_06/training_shade_win")


## 对练擂台的找痒点小游戏：规则和「点灯笼」一样，台词换成擂台的、背景里没有灯笼
class SparShow extends BlueTickleShow:
	func tx() -> Dictionary:
		return PalaceRoom.data().get("spar_show", {})

	func spots() -> Array:
		return tx().get("spots", ["膝盖窝", "大腿内侧", "腿根", "屁股", "腰"])

	func stage_cast() -> Dictionary:
		return {}


## 稻草人 / 木人桩（打对顺序就亮一下；打错了挥拳还手）
class Dummy extends Node2D:
	var idx := 0
	var lit := false
	var punch := 0.0

	func _process(delta: float) -> void:
		punch = maxf(0.0, punch - delta)
		queue_redraw()

	func _draw() -> void:
		var straw := Color(0.86, 0.72, 0.4)
		draw_line(Vector2(0, 0), Vector2(0, -26), Color(0.45, 0.3, 0.18), 2.0)
		draw_circle(Vector2(0, -26), 5.0, straw)
		draw_rect(Rect2(-6, -21, 12, 12), straw)
		var arm := 10.0 if punch > 0.0 else 7.0
		draw_line(Vector2(-6, -17), Vector2(-arm, -17 - (6.0 if punch > 0.0 else 0.0)), straw, 2.0)
		draw_line(Vector2(6, -17), Vector2(arm, -17), straw, 2.0)
		draw_circle(Vector2(-2, -27), 0.8, Color(0.2, 0.15, 0.1))
		draw_circle(Vector2(2, -27), 0.8, Color(0.2, 0.15, 0.1))
		if lit:
			draw_arc(Vector2(0, -16), 12.0, 0, TAU, 20, Color(1, 0.9, 0.4, 0.7), 1.5)
		draw_string(ThemeDB.fallback_font, Vector2(-3, -34), str(idx + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 0.8))


## 习武鸣钟：木架上挂着的铜钟（遭遇战时一直晃）
class Bell extends Node2D:
	var room: PalaceTraining
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var wood := Color(0.42, 0.28, 0.16)
		draw_line(Vector2(-10, 0), Vector2(-10, -34), wood, 2.0)
		draw_line(Vector2(10, 0), Vector2(10, -34), wood, 2.0)
		draw_line(Vector2(-12, -34), Vector2(12, -34), wood, 3.0)
		var swing := sin(_t * 6.0) * 0.35 if room and room.fighting else sin(_t * 1.2) * 0.04
		var top := Vector2(0, -33)
		var pts := PackedVector2Array()
		for p in [Vector2(-3, 2), Vector2(3, 2), Vector2(7, 14), Vector2(-7, 14)]:
			pts.append(top + (p as Vector2).rotated(swing))
		draw_colored_polygon(pts, Color(0.78, 0.55, 0.22))
		draw_circle(top + Vector2(0, 15).rotated(swing), 1.5, Color(0.5, 0.35, 0.12))


## 训练羽毛剑：插在地上来回挥，挥到底的那一下扫到旁边的人
class Sword extends Node2D:
	var t := 0.0

	func swinging() -> bool:
		var k := fposmod(t, PalaceTraining.SWORD_CYCLE) / PalaceTraining.SWORD_CYCLE
		return k > 0.4 and k < 0.6

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var a := sin(fposmod(t, PalaceTraining.SWORD_CYCLE) / PalaceTraining.SWORD_CYCLE * TAU) * 1.1
		var tip := Vector2(0, -22).rotated(a)
		draw_rect(Rect2(-3, -3, 6, 3), Color(0.45, 0.35, 0.25))
		draw_line(Vector2(0, -3), tip, Color(0.75, 0.75, 0.8), 2.0)
		for k in 4:
			var p := Vector2(0, -3).lerp(tip, 0.4 + k * 0.15)
			draw_line(p, p + Vector2(4, -1).rotated(a), Color(1, 1, 1, 0.9), 1.5)
		if swinging():
			draw_arc(Vector2(0, -6), 14.0, -PI / 2.0 - 1.0, -PI / 2.0 + 1.0, 12, Color(1, 1, 1, 0.5), 1.5)


## 幽影的木桩（对练开始的地方：插着一把羽毛剑，发着淡淡的蓝光）
class ShadePost extends Node2D:
	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if GameState.has_flag(PalaceTraining.SHADE_FLAG):
			return
		var a := 0.35 + 0.2 * sin(Time.get_ticks_msec() / 400.0)
		draw_circle(Vector2(0, -12), 10.0, Color(0.6, 0.8, 1.0, a * 0.5))
		draw_line(Vector2(0, 0), Vector2(0, -22), Color(0.75, 0.85, 1.0, 0.9), 2.0)
		draw_circle(Vector2(0, -24), 4.0, Color(1, 1, 1, 0.9))


## 年轻队长的幽影：追最近的人，隔 THRUST_EVERY 秒用羽毛剑刺一下（THRUST_R 以内挠腰 / 腋下）
class Shade extends Node2D:
	const SHEET := "res://assets/generated/npcs/captain_shade.png"
	var room: PalaceTraining
	var hp := 6
	var _t := 0.0
	var _thrust := PalaceTraining.THRUST_EVERY
	var _anim := 0.0
	var _stagger := 0.0
	var _spr: Sprite2D

	func _ready() -> void:
		z_index = 1
		modulate = Color(1, 1, 1, 0.85)
		if ResourceLoader.exists(SHEET):
			_spr = Sprite2D.new()
			_spr.texture = load(SHEET)
			_spr.hframes = 4
			_spr.vframes = 4
			_spr.offset = Vector2(0, -14)
			_spr.scale = Vector2(1.2, 1.2)
			_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_spr)

	func step(ms: Array, delta: float) -> void:
		_t += delta
		_stagger = maxf(0.0, _stagger - delta)
		if hp <= 0:
			return
		var near: PlayableCharacter = null
		for m in ms:
			var pc := m as PlayableCharacter
			if near == null or pc.global_position.distance_to(position) < near.global_position.distance_to(position):
				near = pc
		if near == null:
			return
		var d := near.global_position - position
		if _stagger <= 0.0 and d.length() > 14.0:
			position = position.move_toward(near.global_position, PalaceTraining.SHADE_SPEED * delta)
			_anim += delta * 6.0
		if _spr:
			var sd := IsoView.screen_dir(d)
			var row := (1 if sd.x < 0 else 2) if absf(sd.x) > absf(sd.y) else (0 if sd.y > 0 else 3)
			_spr.frame = row * 4 + int(_anim) % 4
		_thrust -= delta
		if _thrust <= 0.0 and d.length() <= PalaceTraining.THRUST_R:
			_thrust = PalaceTraining.THRUST_EVERY
			Audio.play("swish", -4.0)
			for k in 2:
				var h := HitData.make_tickle(self, 3.0)
				h.zone = ["waist", "armpit"].pick_random()
				near.receive_hit(h)
		queue_redraw()

	func hurt() -> void:
		hp -= 1
		_stagger = 0.4
		Audio.play("hit", -4.0)
		modulate = Color(1.8, 1.8, 2.0, 0.9)
		create_tween().tween_property(self, "modulate", Color(1, 1, 1, 0.85), 0.2)
		if hp <= 0:
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.5)

	func _draw() -> void:
		if _spr == null:
			draw_rect(Rect2(-6, -28, 12, 20), Color(0.6, 0.8, 1.0, 0.7))
			draw_circle(Vector2(0, -32), 6.0, Color(0.7, 0.85, 1.0, 0.7))

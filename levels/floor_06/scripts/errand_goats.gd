class_name ErrandGoats
extends Node2D
## 委托「赶蘑菇羊回圈」（女仆）的玩法节点（AfterErrands.make_runner，导演摆进小镇）。台词 data/after/errand_goats.json。
##   阶段一 shoe：小羊羔咩咩叼着鞋躲着公主跑（跑一会儿歇一会儿），追上它 → 演一段，咩咩跟上来。
##   阶段二 lead：抱着盐块走近别的羊（第一次见演几句）→ 跟上来，排成一串跟在后面。
##     怕生的（shy）要站着不动等它过来；走太快（冲刺 / 离最后一只羊太远 LOSE_DIST）→ 跟着的羊不跟了（领头的不跟，排在它后面的也跟它走）；最黏人的（calm）甩不掉。
##     走太慢（站着不动超过 STILL_T 秒，贪吃的更短）→ 跟着的羊追上来舔一下：部位按性格轮换（trait_licks），第一次被这样舔时演几句，之后旁白 + 反应字（闷笑三档）。
##     闷笑满（> TRIP）：绊倒（演一段）、盐块掉在原地，羊围着盐块舔；走过去捡起来接着赶。
##   阶段三 pen：带着羊走到羊圈门口 PEN_GATE → 跟着的羊进圈；五只都进了 → 门口的「谢礼」（演一段）→ 完成。
## 实时状态写 vars.errand_goats_text（目标提示下面一行）。

const TEXT_PATH := "res://data/after/errand_goats.json"
const PEN_GATE := Vector2i(57, 33)
const PEN_IN := [Vector2i(56, 29), Vector2i(58, 29), Vector2i(57, 30), Vector2i(56, 31), Vector2i(58, 31)]
const CATCH := 14.0
const MEET_R := 44.0
const JOIN_R := 30.0
const LOSE_DIST := 120.0
const DASH_LOSE := 0.35
const STILL_T := 1.3
const GREEDY_STILL := 0.6
const LICK_GAIN := 0.16
const LICK_CD := 2.4
const TRIP := 0.95
const SALT_R := 12.0

static var quiet := false
static var _text := {}

var errand_id := "goats"
var phase := "shoe"
var goats := {}
var followers: Array = []
var penned: Array = []
var licks_seen := {}
var licks_done := 0
var trips := 0
var has_salt := true
var salt: Node2D
var _met := {}
var _lick_i := {}
var _cd := {}
var _still := 0.0
## 站着不动多久了（不被舔打断；怕生的羊看这个）
var _idle := 0.0
var _dash := 0.0
var _greedy_t := 5.0
var _busy := false
var _done := false


static func text() -> Dictionary:
	if _text.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXT_PATH)) if FileAccess.file_exists(TEXT_PATH) else null
		_text = parsed if parsed is Dictionary else {}
	return _text


func _ready() -> void:
	for g in text().get("goats", []):
		var info: Dictionary = g
		var goat := MushroomGoat.spawn(get_parent(), Cutscene.cell_to_world(info["cell"]), str(info["id"]), str(info.get("trait", "calm")))
		goats[goat.gid] = goat
		_lick_i[goat.gid] = 0
		_cd[goat.gid] = 0.0
	var lamb: MushroomGoat = goats.get("mimi")
	if lamb:
		lamb.mode = MushroomGoat.Mode.FLEE
	_update_text()
	if not quiet:
		_say(text().get("intro", []))


func _exit_tree() -> void:
	for g in goats.values():
		if is_instance_valid(g):
			g.queue_free()
	if is_instance_valid(salt):
		salt.queue_free()
	GameState.vars.erase("errand_goats_text")


func goat_info(id: String) -> Dictionary:
	for g in text().get("goats", []):
		if str(g.get("id", "")) == id:
			return g
	return {}


func _say(lines: Array) -> void:
	if quiet or lines.is_empty():
		return
	_busy = true
	Dialogue.start_lines(lines, "errand_goats")
	while Dialogue.is_active():
		await get_tree().process_frame
	_busy = false


func _update_text() -> void:
	var s := "鞋被小羊羔叼走了！追上它" if phase == "shoe" else "跟着的羊 %d 只　圈里 %d / 5%s" % [followers.size(), penned.size(), "" if has_salt else "　（盐块掉了！）"]
	GameState.vars["errand_goats_text"] = s


func _process(delta: float) -> void:
	if _done or _busy or GameState.in_dialogue or GameState.in_cutscene:
		return
	var p := GameState.player
	if not is_instance_valid(p):
		return
	match phase:
		"shoe":
			var lamb: MushroomGoat = goats.get("mimi")
			if lamb and lamb.global_position.distance_to(p.global_position) < CATCH:
				_catch_lamb(lamb)
		"lead":
			_lead(p, delta)


func _catch_lamb(lamb: MushroomGoat) -> void:
	lamb.mode = MushroomGoat.Mode.STAY
	await _say(text().get("shoe", []))
	_lick(lamb, "toes", true)
	phase = "lead"
	_join(lamb)
	_update_text()


func _join(g: MushroomGoat) -> void:
	if g in followers:
		return
	followers.append(g)
	_relink()
	SpeechBubble.say(g, str(goat_info(g.gid).get("join", "咩～")), 20.0, 1.2)
	Audio.play("pickup", -10.0, 0.2)
	_update_text()


## 跟着的羊排成一串：第一只跟公主，后面的跟前一只
func _relink() -> void:
	var prev: Node2D = GameState.player
	for g in followers:
		g.mode = MushroomGoat.Mode.FOLLOW
		g.goal_node = prev
		g.spacing = 14.0
		prev = g


func _lose(from: int, why: String) -> void:
	var lost: Array = followers.slice(from)
	followers = followers.slice(0, from)
	for g in lost:
		g.mode = MushroomGoat.Mode.WANDER
		g.set_home(g.global_position)
		_cd[g.gid] = 3.0
	_relink()
	var names := ", ".join(lost.map(func(g): return str(goat_info(g.gid).get("name", g.gid))))
	GameState.notify(why % names if "%s" in why else why, 2.4)
	_update_text()


func _lead(p: PlayableCharacter, delta: float) -> void:
	for id in _cd:
		_cd[id] = maxf(0.0, float(_cd[id]) - delta)
	var moving := p.velocity.length() > 12.0
	_still = 0.0 if moving else _still + delta
	_idle = 0.0 if moving else _idle + delta
	_dash = _dash + delta if p.is_dashing() else 0.0
	# 捡盐块
	if not has_salt:
		if is_instance_valid(salt) and salt.global_position.distance_to(p.global_position) < SALT_R:
			_pick_salt()
		return
	# 遇到羊 / 跟上来
	for g in goats.values():
		if g in followers or g in penned or g.mode != MushroomGoat.Mode.WANDER or float(_cd[g.gid]) > 0.0:
			continue
		var d: float = g.global_position.distance_to(p.global_position)
		if d < MEET_R and not _met.has(g.gid):
			_met[g.gid] = true
			await _say(goat_info(g.gid).get("meet", []))
			return
		if g.temper == "shy":
			if d < MEET_R and moving:
				g.set_home(g.global_position + p.global_position.direction_to(g.global_position) * 10.0)
			elif d < MEET_R and _idle > 1.0:
				_lick(g, "toes")
				_join(g)
		elif d < JOIN_R:
			_join(g)
	# 走太快：冲刺 / 离最后一只羊太远
	if not followers.is_empty():
		var last: Node2D = followers[-1]
		if _dash > DASH_LOSE or last.global_position.distance_to(p.global_position) > LOSE_DIST + followers.size() * 14.0:
			var i := 0
			while i < followers.size() and followers[i].temper == "calm":
				i += 1
			if i < followers.size():
				_lose_from(i)
	# 走太慢：追上来舔
	_greedy_t -= delta
	for g in followers:
		if float(_cd[g.gid]) > 0.0:
			continue
		var need := GREEDY_STILL if g.temper == "greedy" else STILL_T
		if _still > need or (g.temper == "greedy" and _greedy_t <= 0.0):
			_greedy_t = randf_range(5.0, 8.0)
			_lick(g)
			break
	# 闷笑满：绊倒
	if p.laugh and p.laugh.value >= p.laugh.max_value * TRIP:
		_trip(p)
		return
	# 进圈
	if not followers.is_empty() and Cutscene.cell_to_world(PEN_GATE).distance_to(p.global_position) < 22.0:
		_pen()


## 走太快：最前面那只不黏人的羊掉队，排在它后面的跟着它走（领头的掉队时说得更明白）。
func _lose_from(i: int) -> void:
	var g: MushroomGoat = followers[i]
	var lose: Dictionary = text().get("lose", {})
	var key := "leader" if g.temper == "leader" else "fast"
	var lines: Array = lose.get(key, ["（%s 不跟了）"])
	_lose(i, str(lines.pick_random()))


func _lick(g: MushroomGoat, kind := "", force := false) -> void:
	var p := GameState.player
	if not is_instance_valid(p):
		return
	if kind == "":
		var pool: Array = text().get("trait_licks", {}).get(g.temper, ["sole"])
		kind = str(pool[int(_lick_i[g.gid]) % pool.size()])
		_lick_i[g.gid] = int(_lick_i[g.gid]) + 1
	_cd[g.gid] = LICK_CD * (0.65 if g.temper == "greedy" else 1.0)
	_still = 0.0
	licks_done += 1
	var lk: Dictionary = text().get("licks", {}).get(kind, {})
	var zone := str(lk.get("zone", "sole"))
	if not licks_seen.has(kind):
		licks_seen[kind] = true
		await _say(lk.get("first", []))
	if not is_instance_valid(p):
		return
	if p.laugh:
		var cap := p.laugh.max_value * (0.9 if force else 0.97)
		p.laugh.add(maxf(0.0, minf(p.laugh.max_value * LICK_GAIN, cap - p.laugh.value)))
	p.shake(0.2)
	Audio.play("tickle", -6.0, 0.1)
	HitFx.play("goo", p.get_parent(), p.global_position + Vector2(randf_range(-5, 5), -6))
	ZoneFx.play(zone, p.get_parent(), ZoneFx.body_point(p, zone), 1.0, false)
	GameState.emote("helpless_1", 1.0, false)
	var caps: Array = lk.get("caption", [])
	if not caps.is_empty():
		GameState.princess_reacted.emit(str(caps.pick_random()), 3.0)
	SpeechBubble.say(p, react_line(kind), 30.0, 1.6)
	SpeechBubble.say(g, "咩～", 20.0, 0.8)


## 反应字：按闷笑分三档
func react_line(kind: String) -> String:
	var p := GameState.player
	var lr := p.laugh.ratio() if is_instance_valid(p) and p.laugh else 0.0
	var tier := "light" if lr < 0.35 else ("mid" if lr < 0.7 else "heavy")
	var pool: Array = text().get("licks", {}).get(kind, {}).get("react", {}).get(tier, ["……"])
	return str(pool.pick_random())


func _trip(p: PlayableCharacter) -> void:
	trips += 1
	has_salt = false
	salt = Node2D.new()
	salt.name = "SaltBlock"
	var spr := Sprite2D.new()
	spr.texture = _salt_tex()
	salt.add_child(spr)
	get_parent().add_child(salt)
	salt.global_position = p.global_position + Vector2(24, 6)
	Audio.play("drop", -4.0)
	await _say(text().get("trip", []))
	if p.laugh:
		p.laugh.set_value(p.laugh.max_value * 0.4)
	for g in followers:
		g.mode = MushroomGoat.Mode.GOTO
		g.goal_pos = salt.global_position + Vector2(randf_range(-10, 10), randf_range(-6, 6))
	_update_text()


func _pick_salt() -> void:
	has_salt = true
	salt.queue_free()
	_relink()
	GameState.notify("捡回了盐块。羊们又跟上来了。", 2.0)
	_update_text()


func _pen() -> void:
	var n := followers.size()
	for i in followers.size():
		var g: MushroomGoat = followers[i]
		g.mode = MushroomGoat.Mode.GOTO
		g.goal_pos = Cutscene.cell_to_world(PEN_IN[(penned.size()) % PEN_IN.size()])
		penned.append(g)
	followers.clear()
	GameState.notify("%d 只羊进了羊圈（%d / 5）" % [n, penned.size()], 2.0)
	_update_text()
	if penned.size() >= goats.size():
		_finish()


func _finish() -> void:
	_done = true
	await _say(text().get("pen", []))
	var p := GameState.player
	if is_instance_valid(p) and p.laugh:
		p.laugh.set_value(0.0)
	await _say(text().get("done", []))
	AfterErrands.complete(errand_id, "（摔倒 %d 次）" % trips)
	queue_free()


## 盐块：白色的小方块（程序画的，免得为一块盐加图集）
func _salt_tex() -> Texture2D:
	var img := Image.create(8, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(1, 7):
		for x in range(0, 8):
			var c := Color(0.96, 0.94, 0.9) if y > 1 else Color(1, 1, 1)
			if x == 0 or x == 7 or y == 6:
				c = Color(0.6, 0.56, 0.6)
			img.set_pixel(x, y, c)
	img.set_pixel(2, 3, Color(0.85, 0.82, 0.86))
	img.set_pixel(5, 4, Color(0.85, 0.82, 0.86))
	return ImageTexture.create_from_image(img)

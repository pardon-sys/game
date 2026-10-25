class_name TaskKnightBoss
extends Node2D
## 骑士篇 F Boss「痒铠骑士」（小镇广场，floor_06_after）：被诅咒附身的盔甲跪在广场中间（CENTER），只能打诅咒部件，骑士本人不掉血。台词 data/after/knight_finale.json 的 boss。
##   阶段一 铁手套（左右两只 BossPart）：扑抓（目标脚下预警圈 GRAB_WARN 秒 → 手套扑过去，圈里的人被抓住挠，连按 J 挣开）、扫腿（一行预警 → 扫中的人被绊倒挠脚心）。
##   阶段二 护腿（左右两只）：跺地放出一圈痒波（半径从 0 涨到 WAVE_R，波峰碰到的人闷笑上涨、减速），跺完卡住 STUCK_TIME 秒（这时打护腿不用先冻住）；召出 SUMMON 只诅咒手印。
##   阶段三 头盔笑面：吐笑气（GAS，圈里的人闷笑持续上涨），骑士的声音冲出来；MASK_TIME 秒后图腾的光落下来，两个符文圈（RUNES）亮起：
##     没被操控的那位自动站进自己的圈（粉色 RUNES[0]、蓝色 RUNES[1]），把操控的那位带进另一个圈 → 共鸣（ResonanceMeter，两人真实的闷笑；在圈里每秒被符文挠 RUNE_RATE，按 J 绷住 / 冰封压下去一截）→ 充满 = 光柱净化笑面 = 胜利。
##   部件：平时诅咒太硬打不动，被蓝色公主冻住（她在旁边按 J，FREEZE_R 以内，冻 FREEZE_TIME 秒，冷却 FREEZE_COOL）以后，谁的普通攻击都能打（PART_HP 下碎）。
##     粉色公主贴近（SOFT_R 以内）时部件的出招变慢（×SOFT_SLOW），抓到她时挠得很轻（伏笔：诅咒认得她）。
##   被抓 / 绊倒累计 CATCHES 次 = 失败（knight_fail_boss），从这个阶段重来（打碎的部件不回来）。这段能换人。
##   没被操控的那位由 AI 控制（KnightAI，ai_plan + Hooks）：两人都躲预警圈 / 扫腿线；AI 蓝色公主走近没冻住的部件、冷却一好就冻住；
##     AI 粉色公主贴近本体（SOFT_R 以内，让出招变慢），有冻住 / 卡住的部件就去打（priority_target）；被抓住自己连按挣开；共鸣时站进自己的符文圈。
## 状态 vars.task_boss_phase、task_boss_caught。测试：parts、phase、meter、freeze_part()、hit_part()、grab(角色)、stomp()、in_runes()。

signal finished(ok: bool)

const CENTER := Vector2i(41, 22)
const RUNES := [Vector2i(37, 27), Vector2i(45, 27)]
const RUNE_R := 12.0
const PART_HP := 3
const FREEZE_R := 44.0
const FREEZE_TIME := 4.0
const FREEZE_COOL := 5.0
const SOFT_R := 40.0
const SOFT_SLOW := 1.6
const ATTACK_EVERY := [3.2, 3.6, 3.0]
const GRAB_WARN := 0.9
const GRAB_R := 14.0
const GRAB_TIME := 3.5
const MASH := 7
const HARD_LAUGH := 0.12
const SOFT_LAUGH := 0.04
const SOFT_FATIGUE := 0.1
const SWEEP_LEN := 200.0
const SWEEP_W := 14.0
const WAVE_R := 110.0
const WAVE_TIME := 1.1
const WAVE_LAUGH := 0.1
const STUCK_TIME := 2.2
const SUMMON := 3
const GAS_R := 26.0
const GAS_RATE := 0.08
const GAS_LIFE := 6.0
const MASK_TIME := 14.0
const RUNE_RATE := 0.05
const TENSE := 0.12
const CATCHES := 4
## AI 被抓时多久挣一下
const AI_MASH_EVERY := 0.18
const PHASE_KEY := "task_boss_phase"
const CAUGHT_KEY := "task_boss_caught"
const SHEET := preload("res://assets/generated/npcs/knight_cursed.png")

static var _data := {}

var aborted := false
var started := false
var pink: PlayableCharacter
var blue: PlayableCharacter
var phase := 0
var parts: Array = []
var hands: Array = []
var gases: Array = []
var meter := ResonanceMeter.new()
var resonance := false
var freeze_cool := 0.0
var attack_t := 2.0
var mask_t := 0.0
var stuck_left := 0.0
var wave_left := 0.0
var wave_r := 0.0
var grabbed: PlayableCharacter
var grab_left := 0.0
var mashes := 0
var warn: Dictionary = {}
var _voice_t := 4.0
var _emitted := false
var _music_was := ""
var _lv: Node
var _was_no_switch := false
var _had_switch := false
var _body: Node2D
var _t := 0.0


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/after/knight_finale.json")) if FileAccess.file_exists("res://data/after/knight_finale.json") else null
		_data = parsed if parsed is Dictionary else {}
	return _data.get("boss", {})


static func caught() -> int:
	return int(GameState.vars.get(CAUGHT_KEY, 0))


static func reset_items() -> void:
	GameState.vars[CAUGHT_KEY] = 0


static func status_text() -> String:
	var names := ["铁手套", "护腿", "笑面"]
	var p := int(GameState.vars.get(PHASE_KEY, 0))
	return "%s　被抓 %d / %d" % [names[clampi(p, 0, 2)], caught(), CATCHES]


func _ready() -> void:
	_lv = get_parent().get_parent()
	for n in _lv.find_children("*", "PlayableCharacter", true, false):
		if n is BluePrincess:
			blue = n
		elif not n is BonfireHost:
			pink = n
	_was_no_switch = bool(_lv.get("no_switch"))
	_had_switch = _lv.get_meta(&"free_switch", false)
	_lv.set("no_switch", false)
	_lv.set_meta(&"free_switch", true)
	Duo._bind_tab()   # 骑士篇的小镇图写了 no_switch，C 键原来没绑上
	_body = Body.new()
	(_body as Body).task = self
	get_parent().add_child(_body)
	_body.global_position = Cutscene.cell_to_world(CENTER)
	phase = clampi(int(GameState.vars.get(PHASE_KEY, 0)), 0, 2)
	_enter_phase(phase)
	var hooks := Hooks.new()
	hooks.task = self
	KnightAI.install([pink, blue], ai_plan, hooks)
	_music_was = Audio.music_id
	Audio.play_music("knight_boss")
	started = true


func _exit_tree() -> void:
	if _music_was != "" and Audio.music_id == "knight_boss":
		Audio.play_music(_music_was)
	for n in parts + hands + gases + [_body]:
		if is_instance_valid(n):
			n.queue_free()
	_clear_warn()
	KnightAI.uninstall()
	if is_instance_valid(_lv):
		_lv.set("no_switch", _was_no_switch)
		_lv.set_meta(&"free_switch", _had_switch)
	if is_instance_valid(pink) and GameState.player != pink and is_instance_valid(GameState.player):
		GameState.switch_control(pink)


func _enter_phase(p: int) -> void:
	phase = p
	GameState.vars[PHASE_KEY] = p
	for part in parts:
		if is_instance_valid(part):
			part.queue_free()
	parts.clear()
	resonance = false
	meter.reset()
	var ids: Array = [["gauntlet_l", Vector2(-22, -10)], ["gauntlet_r", Vector2(22, -10)]] if p == 0 else \
		([["greave_l", Vector2(-10, 12)], ["greave_r", Vector2(10, 12)]] if p == 1 else [["mask", Vector2(0, -34)]])
	for spec in ids:
		var part := BossPart.new()
		part.task = self
		part.id = str(spec[0])
		part.offset = spec[1]
		part.hp = PART_HP
		get_parent().add_child(part)
		part.global_position = _body.global_position + part.offset
		parts.append(part)
	mask_t = MASK_TIME
	attack_t = 2.0
	var lines: Array = data().get("phase_intro", [])
	if p < lines.size() and not (lines[p] as Array).is_empty():
		GameState.princess_reacted.emit(str(lines[p][0]), 3.0)


func _process(delta: float) -> void:
	if _emitted or not started or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink):
		return
	advance(delta)


func advance(delta: float) -> void:
	_t += delta
	freeze_cool = maxf(0.0, freeze_cool - delta)
	stuck_left = maxf(0.0, stuck_left - delta)
	if Input.is_action_just_pressed("attack"):
		if grabbed and GameState.player == grabbed:
			mash()
		elif GameState.player == blue:
			freeze_part(blue)
		if resonance and in_runes():
			_tense(GameState.player)
	if grabbed:
		_grab_tick(delta)
		return
	_tick_warn(delta)
	_tick_wave(delta)
	_tick_gas(delta)
	_tick_hands()
	_voice(delta)
	if phase == 2:
		if not resonance:
			mask_t -= delta
			if mask_t <= 0.0:
				_start_resonance()
		else:
			_resonance(delta)
	attack_t -= delta * (1.0 / SOFT_SLOW if _pink_near() else 1.0)
	if attack_t <= 0.0 and warn.is_empty() and stuck_left <= 0.0:
		attack_t = float(ATTACK_EVERY[phase])
		_attack()


func _pink_near() -> bool:
	return pink.global_position.distance_to(_body.global_position) <= SOFT_R + 16.0


func _players() -> Array:
	return [pink, blue].filter(func(c): return is_instance_valid(c))


func _target() -> PlayableCharacter:
	var ps := _players()
	return ps[randi() % ps.size()] if not ps.is_empty() else pink


# ------------------------------------------------------------------ 出招
func _attack() -> void:
	match phase:
		0:
			if randf() < 0.55:
				_warn_grab(_target())
			else:
				_warn_sweep(_target())
		1:
			stomp()
		2:
			_gas()


func _warn_grab(who: PlayableCharacter) -> void:
	var at := who.global_position
	warn = {"kind": "grab", "at": at, "left": GRAB_WARN, "node": _danger_circle(at, GRAB_R)}


func _warn_sweep(who: PlayableCharacter) -> void:
	var c := who.global_position
	var rect := Rect2(c.x - SWEEP_LEN * 0.5, c.y - SWEEP_W * 0.5, SWEEP_LEN, SWEEP_W)
	var node := CursedArmor.WarnLine.new()
	node.rect = rect
	node.add_to_group("danger")
	node.set_meta("rect", rect)
	get_parent().add_child(node)
	node.global_position = Vector2.ZERO
	warn = {"kind": "sweep", "rect": rect, "left": GRAB_WARN, "node": node}
	_say(data().get("sweep", []))


func _tick_warn(delta: float) -> void:
	if warn.is_empty():
		return
	warn["left"] = float(warn["left"]) - delta
	if float(warn["left"]) > 0.0:
		return
	match str(warn["kind"]):
		"grab":
			for c in _players():
				if c.global_position.distance_to(warn["at"]) <= GRAB_R:
					grab(c)
					break
		"sweep":
			var node: Variant = warn.get("node")
			if is_instance_valid(node):
				(node as CursedArmor.WarnLine).sweep()
			for c in _players():
				if (warn["rect"] as Rect2).has_point(c.global_position):
					_say(data().get("trip", []))
					grab(c)
					break
	_clear_warn()


func _clear_warn() -> void:
	var node: Variant = warn.get("node")
	if is_instance_valid(node) and not (node is CursedArmor.WarnLine and (node as CursedArmor.WarnLine)._swept >= 0.0):
		(node as Node).queue_free()
	warn = {}


func _danger_circle(at: Vector2, r: float) -> Node2D:
	var n := DangerCircle.new()
	n.radius = r
	n.add_to_group("danger")
	get_parent().add_child(n)
	n.global_position = at
	return n


## 跺地：一圈痒波；跺完护腿卡住（这时打护腿不用冻）；召出手印
func stomp() -> void:
	wave_left = WAVE_TIME
	wave_r = 0.0
	stuck_left = STUCK_TIME + WAVE_TIME
	_say(data().get("stomp", []))
	for i in SUMMON:
		var h := CurseHand.new()
		get_parent().add_child(h)
		h.global_position = _body.global_position + Vector2.from_angle(randf() * TAU) * 30.0
		var ps := _players()
		if not ps.is_empty():
			h.seek(ps[i % ps.size()])
		hands.append(h)


func _tick_wave(delta: float) -> void:
	if wave_left <= 0.0:
		return
	var before := wave_r
	wave_left -= delta
	wave_r = WAVE_R * (1.0 - maxf(0.0, wave_left) / WAVE_TIME)
	for c in _players():
		var d: float = c.global_position.distance_to(_body.global_position)
		if d > before and d <= wave_r and not c.is_dashing():
			if c.laugh:
				c.laugh.add(c.laugh.max_value * WAVE_LAUGH)
			if c.status:
				c.status.apply_slow(0.6, 1.2)
			ZoneFx.play("sole", c.get_parent(), ZoneFx.body_point(c, "sole"), 1.0, false)
	if wave_left <= 0.0:
		_say(data().get("stuck", []))


func _tick_hands() -> void:
	for h in hands.duplicate():
		if not is_instance_valid(h) or h.state == "gone":
			hands.erase(h)


func _gas() -> void:
	var g := GasCloud.new()
	get_parent().add_child(g)
	g.global_position = _target().global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	gases.append(g)
	_say(data().get("gas", []))


func _tick_gas(delta: float) -> void:
	for g in gases.duplicate():
		if not is_instance_valid(g):
			gases.erase(g)
			continue
		for c in _players():
			if c.global_position.distance_to(g.global_position) <= GAS_R and c.laugh:
				c.laugh.add(c.laugh.max_value * GAS_RATE * delta)


func _voice(delta: float) -> void:
	if phase == 0:
		return
	_voice_t -= delta
	if _voice_t <= 0.0:
		_voice_t = randf_range(6.0, 9.0)
		var pool: Array = data().get("voice", [])
		if not pool.is_empty():
			SpeechBubble.say(_body, str(pool.pick_random()), 46.0, 2.0)


# ------------------------------------------------------------------ 被抓
func grab(who: PlayableCharacter) -> void:
	if grabbed or _emitted:
		return
	grabbed = who
	grab_left = GRAB_TIME
	mashes = 0
	GameState.vars[CAUGHT_KEY] = caught() + 1
	if who.status:
		who.status.apply_root(GRAB_TIME)
	var soft := who == pink
	_say(data().get("grab_soft" if soft else "grab", []))
	if caught() >= CATCHES:
		_emit(false)


func _grab_tick(delta: float) -> void:
	grab_left -= delta
	# 抓住的是 AI 搭档：自己连按挣开
	if ai_enabled and grabbed != GameState.player:
		_ai_mash_t -= delta
		if _ai_mash_t <= 0.0:
			_ai_mash_t = AI_MASH_EVERY
			mash()
			if not grabbed:
				return
	var soft := grabbed == pink
	if grabbed.laugh:
		grabbed.laugh.add(grabbed.laugh.max_value * (SOFT_LAUGH if soft else HARD_LAUGH) * delta)
	if soft and grabbed.fatigue:
		grabbed.fatigue.add(grabbed.fatigue.max_value * SOFT_FATIGUE * delta)
	if randf() < delta * 2.0:
		var zone := "sole" if soft else ("thigh" if grabbed is BluePrincess else "waist")
		ZoneFx.play(zone, grabbed.get_parent(), ZoneFx.body_point(grabbed, zone), 0.8 if soft else 1.1, soft)
	if grab_left <= 0.0:
		_release_grab()


func mash() -> void:
	if not grabbed:
		return
	mashes += 1
	grabbed.shake(0.1)
	if mashes >= MASH:
		_release_grab()


func _release_grab() -> void:
	if grabbed and grabbed.status:
		grabbed.status.clear_root()
	grabbed = null
	attack_t = maxf(attack_t, 1.5)


# ------------------------------------------------------------------ AI 搭档
## 测试：关掉 AI 搭档（没被操控的那位原地不动）
var ai_enabled := true
var _ai_mash_t := 0.0


## 没被操控的那位这一帧干什么（KnightAI 的 plan）；被抓住时的挣扎在 _grab_tick 里
func ai_plan(ai: PlayableCharacter) -> Dictionary:
	if not ai_enabled or _emitted or not is_instance_valid(_body) or grabbed == ai:
		return {"hold": true}
	if resonance:
		return {"to": Cutscene.cell_to_world(RUNES[0 if ai == pink else 1]), "near": 2.0}
	if ai == blue:
		var p := _nearest_part(blue, func(x): return x.freeze_left <= 0.0 and not (phase == 1 and stuck_left > 0.0))
		if p and freeze_cool <= 0.0:
			if p.global_position.distance_to(blue.global_position) <= FREEZE_R - 6.0:
				freeze_part(blue)
				return {"hold": true}
			return {"to": p.global_position + Vector2(0, 18), "near": 6.0, "dash": true}
		return {}
	if soft_target() != null:
		return {}
	# 粉色公主贴近本体：诅咒认得她，出招变慢
	return {"to": _body.global_position + Vector2(0, 26), "near": SOFT_R * 0.6}


## 现在打得动的部件（冻住了 / 护腿跺完卡住了）
func soft_target() -> Node2D:
	return _nearest_part(GameState.player, func(x): return x.freeze_left > 0.0 or (phase == 1 and stuck_left > 0.0))


func _nearest_part(from: Node2D, ok: Callable) -> BossPart:
	var best: BossPart = null
	var best_d := INF
	for part in parts:
		if is_instance_valid(part) and not part.broken and part.id != "mask" and ok.call(part):
			var d: float = part.global_position.distance_to(from.global_position) if is_instance_valid(from) else 0.0
			if d < best_d:
				best_d = d
				best = part
	return best


## AI 的导演提示：先打冻住 / 卡住的部件
class Hooks extends BattleAIHooks:
	var task: TaskKnightBoss

	func priority_target() -> Variant:
		return task.soft_target() if is_instance_valid(task) else null

	func engage_range() -> float:
		return 220.0


# ------------------------------------------------------------------ 部件
## 蓝色公主 J：冻住身边的部件
func freeze_part(who: PlayableCharacter) -> bool:
	if freeze_cool > 0.0 or not is_instance_valid(who):
		return false
	var hit := false
	for part in parts:
		if is_instance_valid(part) and not part.broken and part.global_position.distance_to(who.global_position) <= FREEZE_R:
			part.freeze_left = FREEZE_TIME
			hit = true
	for h in hands:
		if is_instance_valid(h) and h.global_position.distance_to(who.global_position) <= FREEZE_R:
			h.freeze()
	if hit:
		freeze_cool = FREEZE_COOL
		Audio.play("ice", -4.0)
	return hit


## 打部件（测试也直接调）：冻住了 / 护腿卡住了才打得动
func hit_part(part: BossPart) -> bool:
	if not is_instance_valid(part) or part.broken:
		return false
	var soft := part.freeze_left > 0.0 or (phase == 1 and stuck_left > 0.0)
	if part.id == "mask" or not soft:
		GameState.notify("诅咒太硬了……先冻住它！", 1.0)
		return false
	part.hp -= 1
	part.flash = 0.15
	if part.hp <= 0:
		part.broken = true
		var lines: Array = data().get("break", [])
		if not lines.is_empty():
			GameState.princess_reacted.emit(str(lines[0]) % str(data().get("parts", {}).get(part.id, "")), 2.0)
		Audio.play("break", -4.0)
		if parts.all(func(p): return not is_instance_valid(p) or p.broken or p.id == "mask"):
			if phase < 2:
				_enter_phase(phase + 1)
	return true


# ------------------------------------------------------------------ 共鸣收尾
func _start_resonance() -> void:
	resonance = true
	meter.reset()
	meter.rate = 1.0 / 10.0
	for c in RUNES:
		var r := _danger_circle(Cutscene.cell_to_world(c), RUNE_R)
		r.remove_from_group("danger")
		(r as DangerCircle).rune = true
		gases.append(r)
	var lines: Array = data().get("resonance", [])
	for l in lines:
		GameState.princess_reacted.emit(str(l), 3.0)


func in_runes() -> bool:
	if not is_instance_valid(blue):
		return false
	var a := Cutscene.cell_to_world(RUNES[0])
	var b := Cutscene.cell_to_world(RUNES[1])
	return (pink.global_position.distance_to(a) <= RUNE_R and blue.global_position.distance_to(b) <= RUNE_R) \
		or (pink.global_position.distance_to(b) <= RUNE_R and blue.global_position.distance_to(a) <= RUNE_R)


## 没被操控的那位站在自己的符文圈里不动
func _pin_partner() -> void:
	for i in 2:
		var c: PlayableCharacter = pink if i == 0 else blue
		if is_instance_valid(c) and c != GameState.player:
			c.global_position = Cutscene.cell_to_world(RUNES[i])
			c.velocity = Vector2.ZERO


## J：在符文圈里绷住（粉色）/ 冰封（蓝色），自己的闷笑压下去一截
func _tense(who: PlayableCharacter) -> void:
	if who and who.laugh:
		who.laugh.set_value(maxf(0.0, who.laugh.value - who.laugh.max_value * TENSE))


func _resonance(delta: float) -> void:
	_pin_partner()
	if not in_runes():
		meter.step(delta, 0.0, 0.0)
		return
	for c in _players():
		if c.laugh:
			c.laugh.add(c.laugh.max_value * RUNE_RATE * delta)
	var st := meter.step(delta, pink.laugh.ratio(), blue.laugh.ratio())
	if st == "crack":
		meter.reset()
		for c in _players():
			c.laugh.set_value(c.laugh.max_value * 0.3)
		GameState.princess_reacted.emit("（笑过头了——共鸣断了！稳住，再来！）", 2.0)
	elif st == "full":
		var lines: Array = data().get("purge", [])
		for l in lines:
			GameState.princess_reacted.emit(str(l), 3.0)
		_emit(true)


func _say(pool: Array) -> void:
	if not pool.is_empty():
		GameState.princess_reacted.emit(str(pool.pick_random()), 2.4)


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	if grabbed:
		_release_grab()
	if ok:
		GameState.vars[PHASE_KEY] = 0
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)


## 跪在广场中间的盔甲本体（放大的 knight_cursed，光晕随阶段变）
class Body extends Node2D:
	var task: TaskKnightBoss
	var _t := 0.0

	func _ready() -> void:
		z_index = 2

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2(0, 4), 26 + sin(_t * 3.0) * 2.0, Color(0.6, 0.3, 0.9, 0.2))
		draw_texture_rect_region(SHEET, Rect2(-32, -60, 64, 64), Rect2(0, 0, 32, 32))
		if is_instance_valid(task) and task.resonance:
			draw_circle(Vector2(0, -30), 18 + task.meter.charge * 30.0, Color(1, 0.85, 0.5, 0.15 + task.meter.charge * 0.4))


## 诅咒部件：平时打不动（诅咒太硬），冻住（或护腿卡住）以后普通攻击就能打碎
class BossPart extends CharacterBody2D:
	var task: TaskKnightBoss
	var id := ""
	var offset := Vector2.ZERO
	var hp := PART_HP
	var broken := false
	var freeze_left := 0.0
	var flash := 0.0
	var faction := Faction.Type.ENEMY
	var _t := 0.0

	func _ready() -> void:
		add_to_group("enemy")
		collision_layer = 4
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 9.0
		shape.shape = c
		add_child(shape)
		z_index = 3
		set_meta("hit_radius", 9.0)

	func is_alive() -> bool:
		return not broken

	func receive_hit(_hit: HitData) -> bool:
		return is_instance_valid(task) and task.hit_part(self)

	func _process(delta: float) -> void:
		_t += delta
		freeze_left = maxf(0.0, freeze_left - delta)
		flash = maxf(0.0, flash - delta)
		if is_instance_valid(task) and is_instance_valid(task._body):
			global_position = task._body.global_position + offset + Vector2(sin(_t * 2.0 + offset.x) * 2.0, 0)
		queue_redraw()

	func _draw() -> void:
		if broken:
			return
		var col := Color(0.75, 0.92, 1.0) if freeze_left > 0.0 else Color(0.72, 0.45, 0.95)
		if flash > 0.0:
			col = Color.WHITE
		match id:
			"mask":
				draw_circle(Vector2.ZERO, 10, Color(0.55, 0.3, 0.75, 0.9))
				draw_arc(Vector2(0, 2), 5, 0.2, PI - 0.2, 8, Color(1, 0.8, 1.0), 2)
				draw_circle(Vector2(-4, -3), 1.5, Color(1, 0.85, 1.0))
				draw_circle(Vector2(4, -3), 1.5, Color(1, 0.85, 1.0))
			_:
				draw_rect(Rect2(-7, -6, 14, 12), col)
				for i in 4:
					draw_line(Vector2(-5 + i * 3.3, -6), Vector2(-5 + i * 3.3, -11), col, 2)
		for i in hp:
			draw_rect(Rect2(-6 + i * 5, 9, 4, 2), Color(1, 0.6, 0.8))
		if freeze_left > 0.0:
			draw_arc(Vector2.ZERO, 12, 0, TAU, 16, Color(0.8, 0.95, 1.0, 0.8), 1.5)


## 地上的预警圈 / 符文圈
class DangerCircle extends Node2D:
	var radius := 12.0
	var rune := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var col := Color(1, 0.8, 0.45) if rune else Color(0.75, 0.35, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(col, 0.18 + 0.12 * sin(_t * 10.0)))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 20, Color(col, 0.8), 1.5)


## 笑面吐出来的笑气（GAS_LIFE 秒后散掉）
class GasCloud extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= GAS_LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var a := 0.35 * (1.0 - _t / GAS_LIFE)
		for i in 5:
			var p := Vector2.from_angle(i * TAU / 5.0 + _t) * 10.0
			draw_circle(p, 12, Color(0.95, 0.6, 0.9, a))

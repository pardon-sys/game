class_name TaskKnightBoss
extends Node2D
## 骑士篇 F Boss「痒铠骑士」（骑士篇的空小镇 floor_06_knight_chase 的广场）：被诅咒附身的盔甲跪在广场中间（CENTER），骑士本人不掉血。
## 台词 data/after/knight_finale.json 的 boss（← knight_text/finale.py）；场上的东西画在 KnightBossFx 里。
## 四个阶段，每个阶段拆掉一套盔甲（部件 BossPart）：0 铁手套 → 1 护腿 → 2 胸甲 → 3 头盔笑面（拆不掉，最后靠符文圈共鸣净化）。
##   部件平时诅咒太硬打不动：被蓝色公主冻住（J，FREEZE_R 以内，冻 FREEZE_TIME 秒，冷却 FREEZE_COOL）、护腿跺完 / 冲撞完卡住（stuck）、
##   骑士清醒（lucid）的时候，谁的普通攻击都能打（PART_HP 下掉）。
##   反击——挠骑士：每掉一个部件（还有护腿卡住、喊完骑士之名）露出破绽（WeakSpot：手腕 / 膝盖窝 / 腰侧 / 脖子）WEAK_TIME 秒，
##     这时打破绽 = 挠骑士，骑士的笑 knight_laugh +KNIGHT_TICKLE；满了：骑士清醒 LUCID_TIME 秒（「快……趁现在……」），所有部件不冻也打得动；
##     头盔阶段挠满：笑面撑不住，符文圈马上亮。
##   出招（每 ATTACK_EVERY 秒一招，从这个阶段的 SKILLS 里挑，不连着用同一招；粉色公主贴近 SOFT_R 以内时变慢）：
##     铁手套：扑抓（预警圈 → 抓住挠，连按 J 挣开）/ 扫腿（一行预警，扫中绊倒挠脚心）/ 弹指（三发扇形，打中小挠一下）/ 十指痒网（3×3 预警格，指头一格格冒出来）
##     护腿：跺地痒波 + 召手印 / 冲撞（预警线 → 直冲过去，撞到人抓住；冲完卡住 = 破绽）/ 踢沙（三团痒尘：闷笑慢慢涨、减速）
##     胸甲：诅咒穿戴（甩出一件痒痒装备，穿到她身上一直挠、减速；搭档在身边按住 E 扯下来，或者她连按 J 挣掉）/
##           护心磁吸（把身边的人往中间吸，吸到跟前就抓住）/ 甲片飞散（六片甲片在场上弹来弹去）
##     笑面：吐笑气 / 呼唤骑士之名（冲击波把人往中间推，喊完露出破绽）/ 镜面笑脸（三张笑脸先绕圈再追人）；MASK_TIME 秒后符文圈亮起 → 共鸣
##   每次换阶段：过场（knight_boss_p1~p3，演示新招、最后提示玩法）。
##   场上的人（Victim）：逃跑的镇民、被挠倒的队员、护着镇民的队员。手印会贴上去（最多 MAX_CURSED 个，每 CURSE_EVERY 秒一个）：
##     走到身边按住 E 1 秒（AI 搭档站在旁边也算）或者蓝色公主冻住它 = 救下来：冻结冷却马上好，被救的队员替公主挡一次扑抓 / 冲撞（shield）；
##     有人被贴着超过 ENRAGE_AFTER 秒没人管：诅咒变强，出招间隔 ×ENRAGE，直到救下一个。
##   阶段四（笑面）：没被操控的那位自动站进自己的符文圈（粉色 RUNES[0]、蓝色 RUNES[1]），把操控的那位带进另一个圈 → 共鸣（ResonanceMeter）→ 充满 = 胜利。
##   被抓 / 绊倒累计 CATCHES 次 = 失败（knight_fail_boss），从这个阶段重来（打碎的部件不回来）。这段能换人（C，只在两位公主之间）。
##   没被操控的那位由 AI 控制（KnightAI，ai_plan + Hooks）：两人都躲预警；AI 蓝色公主冻没冻的部件、去冻贴着人的手印；
##     AI 粉色公主贴近本体（出招变慢）、有破绽 / 冻住的部件就去打、搭档身上有诅咒装备就去扯、被抓住自己连按挣开、共鸣时站进自己的符文圈。
## 状态 vars.task_boss_phase（0~3）、task_boss_caught。
## 测试：parts、phase、meter、freeze_part()、hit_part()、grab(角色)、mash()、stomp()、flick()、net()、charge()、sand()、throw_gear()、wear_gear()、
##   magnet()、shards()、name_call()、mirrors()、tickle_knight()、curse_victim()、rescue()、in_runes()、ai_plan()、ai_enabled、skip_cutscenes。

signal finished(ok: bool)

const CENTER := Vector2i(41, 22)
const RUNES := [Vector2i(37, 27), Vector2i(45, 27)]
const ARENA := Vector2(130, 90)
const RUNE_R := 12.0
const PART_HP := 3
const FREEZE_R := 44.0
const FREEZE_TIME := 4.0
const FREEZE_COOL := 5.0
const SOFT_R := 40.0
const SOFT_SLOW := 1.6
const PHASES := 4
const PHASE_NAMES := ["铁手套", "护腿", "胸甲", "笑面"]
const SKILLS := [["grab", "sweep", "flick", "net"], ["stomp", "charge", "sand"], ["gear", "magnet", "shards"], ["gas", "name", "mirror"]]
const ATTACK_EVERY := [3.0, 3.2, 3.0, 2.8]
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
const MASK_TIME := 18.0
const RUNE_RATE := 0.05
const TENSE := 0.12
const CATCHES := 4
## 反击：破绽、骑士的笑、清醒
const WEAK_TIME := 4.0
const KNIGHT_TICKLE := 0.25
const LUCID_TIME := 5.0
## 弹指 / 诅咒装备 / 甲片 / 痒尘 / 冲击波 / 镜面笑脸
const FLICK_SPEED := 130.0
const FLICK_LAUGH := 0.08
const NET_DELAY := 0.12
const NET_LAUGH := 0.1
const CHARGE_WARN := 0.8
const CHARGE_LEN := 170.0
const CHARGE_SPEED := 260.0
const DUST_RATE := 0.06
const GEAR_SPEED := 110.0
const GEAR_LAUGH := 0.05
const GEAR_TEARS := 8
const GEAR_PULL := 1.0
const GEARS := {"equip_t_feather_socks": "sole", "equip_t_toe_brush": "sole", "equip_t_thigh_ring": "thigh",
	"equip_t_feather_shackles": "sole", "equip_t_bell_anklet": "sole"}
const MAGNET_TIME := 2.0
const MAGNET_R := 140.0
const MAGNET_PULL := 60.0
const SHARDS := 6
const SHARD_LAUGH := 0.07
const RING_LAUGH := 0.08
const RING_PUSH := 40.0
const MIRRORS := 3
const MIRROR_RATE := 0.1
## 场上的人和救人
const MAX_CURSED := 2
const CURSE_EVERY := 10.0
const RESCUE_R := 22.0
const RESCUE_TIME := 1.0
const ENRAGE_AFTER := 15.0
const ENRAGE := 0.75
## AI 被抓 / 被穿上诅咒装备时多久挣一下
const AI_MASH_EVERY := 0.18
const PHASE_KEY := "task_boss_phase"
const CAUGHT_KEY := "task_boss_caught"
const SHEET := preload("res://assets/generated/npcs/knight_cursed.png")
## 场上的人：[人物图, 样子, 相对广场中间的位置]
const VICTIMS := [["guard", "fallen", Vector2(-92, 40)], ["guard", "fallen", Vector2(96, -34)], ["guard", "guard", Vector2(-104, -40)],
	["kid", "runner", Vector2(-120, 70)], ["granny", "runner", Vector2(120, 70)]]

static var _data := {}
## 测试：换阶段不演过场
static var skip_cutscenes := false

var aborted := false
var started := false
var pink: PlayableCharacter
var blue: PlayableCharacter
var phase := 0
var parts: Array = []
var hands: Array = []
var gases: Array = []
var fx: Array = []
var victims: Array = []
var meter := ResonanceMeter.new()
var resonance := false
var transitioning := false
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
var knight_laugh := 0.0
var weak_left := 0.0
var weak_spot: Node2D
var lucid_left := 0.0
var charge_dir := Vector2.ZERO
var charge_left := 0.0
var magnet_left := 0.0
var shield := 0
var curse_t := CURSE_EVERY * 0.5
var enraged := false
var last_skill := ""
var _home := Vector2.ZERO
var _voice_t := 4.0
var _emitted := false
var _music_was := ""
var _lv: Node
var _was_no_switch := false
var _had_switch := false
var _body: Node2D
var _t := 0.0
var _tips := {}


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
	var p := clampi(int(GameState.vars.get(PHASE_KEY, 0)), 0, PHASES - 1)
	var tips: Array = data().get("phase_tips", [])
	return "%s　被抓 %d / %d%s" % [PHASE_NAMES[p], caught(), CATCHES, ("\n" + str(tips[p])) if p < tips.size() else ""]


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
	_home = Cutscene.cell_to_world(CENTER)
	_body.global_position = _home
	_spawn_victims()
	phase = clampi(int(GameState.vars.get(PHASE_KEY, 0)), 0, PHASES - 1)
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
	_clear_field()
	for n in parts + victims + [_body]:
		if is_instance_valid(n):
			n.queue_free()
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
	knight_laugh = 0.0
	lucid_left = 0.0
	_close_weak()
	var ids: Array = [[["gauntlet_l", Vector2(-22, -10)], ["gauntlet_r", Vector2(22, -10)]],
		[["greave_l", Vector2(-10, 12)], ["greave_r", Vector2(10, 12)]],
		[["plate_l", Vector2(-11, -18)], ["plate_r", Vector2(11, -18)]],
		[["mask", Vector2(0, -34)]]][p]
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
	last_skill = ""
	var lines: Array = data().get("phase_intro", [])
	if p < lines.size() and not (lines[p] as Array).is_empty():
		GameState.princess_reacted.emit(str(lines[p][0]), 3.0)


## 拆完一套：清场 → 换阶段的过场（演示新招、提示玩法）→ 下一阶段
func _transition(p: int) -> void:
	transitioning = true
	_clear_field()
	if grabbed:
		_release_grab()
	_body.global_position = _home
	if not skip_cutscenes and Cutscene.has_cutscene("knight_boss_p%d" % p):
		await Cutscene.play("knight_boss_p%d" % p)
	if not is_inside_tree() or _emitted:
		return
	_enter_phase(p)
	transitioning = false


func _clear_field() -> void:
	_clear_warn()
	for n in hands + gases + fx:
		if is_instance_valid(n):
			n.queue_free()
	hands.clear()
	gases.clear()
	fx.clear()
	_close_weak()
	charge_left = 0.0
	magnet_left = 0.0
	wave_left = 0.0
	for c in _players():
		_take_gear(c)


func _process(delta: float) -> void:
	if _emitted or not started or transitioning or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink):
		return
	advance(delta)


func advance(delta: float) -> void:
	_t += delta
	freeze_cool = maxf(0.0, freeze_cool - delta)
	stuck_left = maxf(0.0, stuck_left - delta)
	lucid_left = maxf(0.0, lucid_left - delta)
	if weak_left > 0.0:
		weak_left -= delta
		if weak_left <= 0.0:
			_close_weak()
	if Input.is_action_just_pressed("attack"):
		var me := GameState.player
		if grabbed and me == grabbed:
			mash()
		elif me.has_meta(&"knight_gear"):
			tear_gear(me)
		elif me == blue:
			freeze_part(blue)
		if resonance and in_runes():
			_tense(me)
	_tick_gears(delta)
	_tick_victims(delta)
	if grabbed:
		_grab_tick(delta)
		return
	_tick_warn(delta)
	_tick_wave(delta)
	_tick_gas(delta)
	_tick_fx(delta)
	_tick_charge(delta)
	_tick_magnet(delta)
	_tick_hands()
	_voice(delta)
	if phase == PHASES - 1:
		if not resonance:
			mask_t -= delta
			if mask_t <= 0.0:
				_start_resonance()
		else:
			_resonance(delta)
			return
	if charge_left <= 0.0 and stuck_left <= 0.0 and _body.global_position.distance_to(_home) > 1.0:
		_body.global_position = _body.global_position.move_toward(_home, 70.0 * delta)
	attack_t -= delta * (1.0 / SOFT_SLOW if _pink_near() else 1.0) / (ENRAGE if enraged else 1.0)
	if attack_t <= 0.0 and warn.is_empty() and stuck_left <= 0.0 and charge_left <= 0.0 and magnet_left <= 0.0:
		attack_t = float(ATTACK_EVERY[phase])
		_attack()


func _pink_near() -> bool:
	return pink.global_position.distance_to(_body.global_position) <= SOFT_R + 16.0


func _players() -> Array:
	return [pink, blue].filter(func(c): return is_instance_valid(c))


func _target() -> PlayableCharacter:
	var ps := _players()
	return ps[randi() % ps.size()] if not ps.is_empty() else pink


func _tip(key: String) -> void:
	if _tips.has(key):
		return
	_tips[key] = true
	var t: String = str(data().get("tips", {}).get(key, ""))
	if t != "":
		GameState.notify(t, 3.0)


# ------------------------------------------------------------------ 出招
func _attack() -> void:
	var pool: Array = (SKILLS[phase] as Array).duplicate()
	if pool.size() > 1:
		pool.erase(last_skill)
	var skill: String = str(pool.pick_random())
	last_skill = skill
	use_skill(skill)


func use_skill(skill: String) -> void:
	match skill:
		"grab": _warn_grab(_target())
		"sweep": _warn_sweep(_target())
		"flick": flick(_target())
		"net": net(_target())
		"stomp": stomp()
		"charge": charge(_target())
		"sand": sand(_target())
		"gear": throw_gear(_target())
		"magnet": magnet()
		"shards": shards()
		"gas": _gas()
		"name": name_call()
		"mirror": mirrors()


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
		"charge":
			charge_left = CHARGE_LEN / CHARGE_SPEED
			_say(data().get("charge_go", []))
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


func _add_fx(n: Node2D, at: Vector2) -> Node2D:
	get_parent().add_child(n)
	n.global_position = at
	fx.append(n)
	return n


## 打中一下：闷笑上涨 + 那个部位的挠痒特效（冲刺中躲得开）
func _hit(c: PlayableCharacter, laugh: float, zone := "sole") -> bool:
	if not is_instance_valid(c) or c.is_dashing():
		return false
	if c.laugh:
		c.laugh.add(c.laugh.max_value * laugh)
	ZoneFx.play(zone, c.get_parent(), ZoneFx.body_point(c, zone), 0.9, false)
	return true


## 铁手套：弹指——三发扇形
func flick(who: PlayableCharacter) -> void:
	var from := _body.global_position + Vector2(0, -10)
	var dir := from.direction_to(who.global_position)
	for a in [-0.3, 0.0, 0.3]:
		var p := KnightBossFx.Bolt.new()
		p.vel = dir.rotated(a) * FLICK_SPEED
		p.set_meta("kind", "flick")
		_add_fx(p, from)
	_say(data().get("flick", []))


## 铁手套：十指痒网——目标脚下 3×3 格，一格一格冒指头
func net(who: PlayableCharacter) -> void:
	var c := who.global_position
	var i := 0
	for y in [-1, 0, 1]:
		for x in [-1, 0, 1]:
			var cell := KnightBossFx.NetCell.new()
			cell.warn = GRAB_WARN + i * NET_DELAY
			cell.add_to_group("danger")
			cell.set_meta("radius", KnightBossFx.NetCell.SIZE * 0.6)
			_add_fx(cell, c + Vector2(x, y) * KnightBossFx.NetCell.SIZE)
			i += 1
	_say(data().get("net", []))


## 护腿：跺地——一圈痒波；跺完护腿卡住（破绽：膝盖窝）；召出手印
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
		if d > before and d <= wave_r and _hit(c, WAVE_LAUGH) and c.status:
			c.status.apply_slow(0.6, 1.2)
	if wave_left <= 0.0:
		_say(data().get("stuck", []))
		open_weak(Vector2(0, 12))


## 护腿：冲撞——预警线 → 直冲过去，撞到人就抓住；冲完卡住（破绽）
func charge(who: PlayableCharacter) -> void:
	charge_dir = _body.global_position.direction_to(who.global_position)
	if charge_dir == Vector2.ZERO:
		charge_dir = Vector2.RIGHT
	var a := _body.global_position
	var line := CursedArmor.WarnLine.new()
	var w := 18.0
	# 预警线：沿冲的方向（只画成横 / 竖的矩形，取主方向）
	var rect := Rect2(a.x, a.y - w * 0.5, CHARGE_LEN * signf(charge_dir.x), w) if absf(charge_dir.x) >= absf(charge_dir.y) \
		else Rect2(a.x - w * 0.5, a.y, w, CHARGE_LEN * signf(charge_dir.y))
	rect = rect.abs()
	charge_dir = Vector2(signf(charge_dir.x), 0) if absf(charge_dir.x) >= absf(charge_dir.y) else Vector2(0, signf(charge_dir.y))
	line.rect = rect
	line.add_to_group("danger")
	line.set_meta("rect", rect)
	get_parent().add_child(line)
	line.global_position = Vector2.ZERO
	warn = {"kind": "charge", "left": CHARGE_WARN, "node": line}
	_say(data().get("charge", []))


func _tick_charge(delta: float) -> void:
	if charge_left <= 0.0:
		return
	charge_left -= delta
	var to := _body.global_position + charge_dir * CHARGE_SPEED * delta
	var lim := Rect2(_home - ARENA, ARENA * 2.0)
	_body.global_position = Vector2(clampf(to.x, lim.position.x, lim.end.x), clampf(to.y, lim.position.y, lim.end.y))
	for c in _players():
		if c.global_position.distance_to(_body.global_position) <= 16.0 and not c.is_dashing():
			charge_left = 0.0
			grab(c)
			break
	if charge_left <= 0.0 or _body.global_position != to:
		charge_left = 0.0
		stuck_left = STUCK_TIME
		Audio.play("crash", -6.0)
		_say(data().get("charge_stuck", []))
		open_weak(Vector2(0, 12))


## 护腿：踢沙——三团痒尘
func sand(who: PlayableCharacter) -> void:
	for i in 3:
		var d := KnightBossFx.Dust.new()
		_add_fx(d, who.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0, 24))
	_say(data().get("sand", []))


## 胸甲：诅咒穿戴——甩出一件痒痒装备
func throw_gear(who: PlayableCharacter) -> void:
	var from := _body.global_position + Vector2(0, -18)
	var id: String = GEARS.keys().pick_random()
	var p := KnightBossFx.Bolt.new()
	p.vel = from.direction_to(who.global_position) * GEAR_SPEED
	p.icon = ItemDB.get_item(id).icon if ItemDB.get_item(id) else null
	p.set_meta("kind", "gear")
	p.set_meta("item", id)
	p.life = 3.0
	_add_fx(p, from)
	_say(data().get("gear", []))


## 诅咒装备穿到她身上（测试也直接调）
func wear_gear(c: PlayableCharacter, id := "") -> void:
	if not is_instance_valid(c) or c.has_meta(&"knight_gear"):
		return
	if id == "":
		id = GEARS.keys().pick_random()
	var g := KnightBossFx.Gear.new()
	g.who = c
	g.item_id = id
	g.zone = str(GEARS.get(id, "sole"))
	var item := ItemDB.get_item(id)
	g.icon = item.icon if item else null
	get_parent().add_child(g)
	c.set_meta(&"knight_gear", g)
	var name := item.display_name if item else id
	GameState.princess_reacted.emit(str(data().get("gear_on", "（%s被穿到了身上！）")) % name, 2.6)
	_tip("gear")


## 被穿着诅咒装备的人连按 J：挣掉
func tear_gear(c: PlayableCharacter) -> void:
	var g: Variant = c.get_meta(&"knight_gear") if c.has_meta(&"knight_gear") else null
	if not is_instance_valid(g):
		return
	g.tears += 1
	c.shake(0.08)
	if g.tears >= GEAR_TEARS:
		_take_gear(c, "gear_torn")


func _take_gear(c: PlayableCharacter, say := "") -> void:
	if not is_instance_valid(c) or not c.has_meta(&"knight_gear"):
		return
	var g: Variant = c.get_meta(&"knight_gear")
	c.remove_meta(&"knight_gear")
	if is_instance_valid(g):
		(g as Node).queue_free()
	if say != "":
		_say(data().get(say, []))


func _tick_gears(delta: float) -> void:
	for c in _players():
		var g: Variant = c.get_meta(&"knight_gear") if c.has_meta(&"knight_gear") else null
		if not is_instance_valid(g):
			continue
		if c.laugh:
			c.laugh.add(c.laugh.max_value * GEAR_LAUGH * delta)
		if c.status and fmod(_t, 0.3) < delta:
			c.status.apply_slow(0.7, 0.4)
		if randf() < delta * 2.0:
			ZoneFx.play(g.zone, c.get_parent(), ZoneFx.body_point(c, g.zone), 0.8, false)
		# 搭档在身边：按住 E（AI 搭档站在旁边就算）把它扯下来
		var other: PlayableCharacter = blue if c == pink else pink
		var pulling := is_instance_valid(other) and other.global_position.distance_to(c.global_position) <= RESCUE_R \
			and ((other == GameState.player and Input.is_action_pressed("interact")) or (other != GameState.player and ai_enabled))
		g.pull = minf(1.0, g.pull + delta / GEAR_PULL) if pulling else maxf(0.0, g.pull - delta)
		if g.pull >= 1.0:
			_take_gear(c, "gear_pulled")
			continue
		# 被穿着的是 AI 搭档：自己挣
		if c != GameState.player and ai_enabled:
			_ai_mash_t -= delta
			if _ai_mash_t <= 0.0:
				_ai_mash_t = AI_MASH_EVERY * 1.5
				tear_gear(c)


## 胸甲：护心磁吸——把身边的人往中间吸，吸到跟前就抓住
func magnet() -> void:
	magnet_left = MAGNET_TIME
	_say(data().get("magnet", []))


func _tick_magnet(delta: float) -> void:
	if magnet_left <= 0.0:
		return
	magnet_left -= delta
	for c in _players():
		var d: float = c.global_position.distance_to(_body.global_position)
		if d <= MAGNET_R and d > 1.0 and not c.is_dashing():
			c.global_position += c.global_position.direction_to(_body.global_position) * minf(MAGNET_PULL * delta, d)
	if magnet_left <= 0.0:
		for c in _players():
			if c.global_position.distance_to(_body.global_position) <= 24.0:
				grab(c)
				break


## 胸甲：甲片飞散——六片在场上弹来弹去
func shards() -> void:
	for i in SHARDS:
		var s := KnightBossFx.Shard.new()
		s.vel = Vector2.from_angle(i * TAU / SHARDS + randf_range(-0.2, 0.2)) * 90.0
		s.bounds = Rect2(_home - ARENA, ARENA * 2.0)
		_add_fx(s, _body.global_position + Vector2(0, -16))
	_say(data().get("shards", []))


## 笑面：呼唤骑士之名——冲击波往外扩，把人往中间推；喊完露出破绽（脖子）
func name_call() -> void:
	var r := KnightBossFx.Ring.new()
	r.set_meta("kind", "ring")
	_add_fx(r, _body.global_position)
	_say(data().get("name_call", []))
	open_weak(Vector2(0, -26))


## 笑面：镜面笑脸——三张笑脸先绕圈再去追人
func mirrors() -> void:
	for i in MIRRORS:
		var m := KnightBossFx.Mirror.new()
		m.center = _body
		m.angle = i * TAU / MIRRORS
		m.target = _players()[i % _players().size()]
		_add_fx(m, _body.global_position)
	_say(data().get("mirror", []))


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


## 场上的弹幕：碰到谁
func _tick_fx(delta: float) -> void:
	for n in fx.duplicate():
		if not is_instance_valid(n):
			fx.erase(n)
			continue
		if n is KnightBossFx.Bolt:
			if n.hit:
				fx.erase(n)
				continue
			for c in _players():
				if c.global_position.distance_to(n.global_position) <= n.radius + 8.0 and not c.is_dashing():
					n.hit = true
					if str(n.get_meta("kind", "")) == "gear":
						wear_gear(c, str(n.get_meta("item", "")))
					elif _hit(c, FLICK_LAUGH, "waist") and c.status:
						c.status.apply_slow(0.7, 0.8)
					break
		elif n is KnightBossFx.NetCell:
			if n.active > 0.0 and not n.has_meta("hit"):
				for c in _players():
					if absf(c.global_position.x - n.global_position.x) <= KnightBossFx.NetCell.SIZE * 0.5 \
							and absf(c.global_position.y - n.global_position.y) <= KnightBossFx.NetCell.SIZE * 0.5 and _hit(c, NET_LAUGH):
						n.set_meta("hit", true)
						if c.status:
							c.status.apply_root(0.5)
		elif n is KnightBossFx.Dust:
			for c in _players():
				if c.global_position.distance_to(n.global_position) <= KnightBossFx.Dust.RADIUS and c.laugh:
					c.laugh.add(c.laugh.max_value * DUST_RATE * delta)
					if c.status and fmod(_t, 0.3) < delta:
						c.status.apply_slow(0.75, 0.4)
		elif n is KnightBossFx.Shard:
			for c in _players():
				if c.global_position.distance_to(n.global_position) <= 9.0 and not n.has_meta("hit_%d" % c.get_instance_id()):
					if _hit(c, SHARD_LAUGH, "waist"):
						n.set_meta("hit_%d" % c.get_instance_id(), true)
		elif n is KnightBossFx.Ring:
			for c in _players():
				var d: float = c.global_position.distance_to(n.global_position)
				if absf(d - n.r) <= 8.0 and not n.has_meta("hit_%d" % c.get_instance_id()):
					n.set_meta("hit_%d" % c.get_instance_id(), true)
					if _hit(c, RING_LAUGH, "waist"):
						c.global_position += c.global_position.direction_to(n.global_position) * RING_PUSH
		elif n is KnightBossFx.Mirror:
			for c in _players():
				if c.global_position.distance_to(n.global_position) <= 12.0 and c.laugh:
					c.laugh.add(c.laugh.max_value * MIRROR_RATE * delta)
					if randf() < delta * 2.0:
						ZoneFx.play("waist", c.get_parent(), ZoneFx.body_point(c, "waist"), 0.7, false)


func _tick_hands() -> void:
	for h in hands.duplicate():
		if not is_instance_valid(h) or h.state == "gone":
			hands.erase(h)


func _voice(delta: float) -> void:
	if phase == 0:
		return
	_voice_t -= delta
	if _voice_t <= 0.0:
		_voice_t = randf_range(6.0, 9.0)
		var pool: Array = data().get("voice", [])
		if not pool.is_empty():
			SpeechBubble.say(_body, str(pool.pick_random()), 46.0, 2.0)


# ------------------------------------------------------------------ 反击：破绽、挠骑士、清醒
## 部件掉下来 / 卡住 / 喊完：露出破绽（at：相对本体的位置）
func open_weak(at: Vector2) -> void:
	if resonance:
		return
	_close_weak()
	weak_left = WEAK_TIME
	var w := KnightBossFx.WeakSpot.new()
	w.task = self
	var spots: Array = data().get("weak_spots", [])
	w.spot = str(spots[phase]) if phase < spots.size() else ""
	get_parent().add_child(w)
	w.global_position = _body.global_position + at
	weak_spot = w
	_tip("weak")
	if w.spot != "":
		GameState.princess_reacted.emit(str(data().get("weak", "（露出破绽了——%s！）")) % w.spot, 2.0)


func _close_weak() -> void:
	weak_left = 0.0
	if is_instance_valid(weak_spot):
		weak_spot.queue_free()
	weak_spot = null


## 打破绽 = 挠骑士：骑士的笑涨；满了骑士清醒（所有部件不冻也打得动；头盔阶段：符文圈马上亮）
func tickle_knight() -> bool:
	if weak_left <= 0.0 or resonance:
		return false
	knight_laugh = minf(1.0, knight_laugh + KNIGHT_TICKLE)
	ZoneFx.play("waist", get_parent(), weak_spot.global_position if is_instance_valid(weak_spot) else _body.global_position, 1.0, false)
	SpeechBubble.say(_body, str(data().get("knight_laugh", ["噗……！"]).pick_random()), 46.0, 1.0)
	if knight_laugh >= 1.0:
		knight_laugh = 0.0
		_close_weak()
		_say(data().get("lucid", []))
		if phase == PHASES - 1:
			mask_t = 0.0
		else:
			lucid_left = LUCID_TIME
			_tip("lucid")
	return true


# ------------------------------------------------------------------ 场上的人和救人
func _spawn_victims() -> void:
	for spec in VICTIMS:
		var v := KnightBossFx.Victim.new()
		v.sheet = load("res://assets/generated/npcs/%s.png" % spec[0])
		v.kind = str(spec[1])
		if v.kind == "runner":
			var c := _home
			v.path = [c + Vector2(-125, 75), c + Vector2(125, 75), c + Vector2(125, -70), c + Vector2(-125, -70)]
		get_parent().add_child(v)
		v.global_position = _home + (spec[2] as Vector2)
		victims.append(v)


## 手印贴上一个人（测试也直接调）
func curse_victim(v: KnightBossFx.Victim = null) -> KnightBossFx.Victim:
	if v == null:
		var free: Array = victims.filter(func(x): return is_instance_valid(x) and not x.cursed)
		if free.is_empty():
			return null
		v = free.pick_random()
	v.cursed = true
	v.cursed_t = 0.0
	v.rescue = 0.0
	SpeechBubble.say(v, str(data().get("victim_laugh", ["哈哈哈……救、救命……！"]).pick_random()), 30.0, 1.6)
	_tip("rescue")
	return v


func _tick_victims(delta: float) -> void:
	if resonance:
		return
	curse_t -= delta
	var cursed: Array = victims.filter(func(x): return is_instance_valid(x) and x.cursed)
	if curse_t <= 0.0:
		curse_t = CURSE_EVERY
		if cursed.size() < MAX_CURSED:
			curse_victim()
	var was := enraged
	enraged = cursed.any(func(x): return x.cursed_t > ENRAGE_AFTER)
	if enraged and not was:
		_say(data().get("enrage", []))
	for v in cursed:
		var helping := false
		for c in _players():
			if c.global_position.distance_to(v.global_position) <= RESCUE_R:
				if (c == GameState.player and Input.is_action_pressed("interact")) or (c != GameState.player and ai_enabled):
					helping = true
		v.rescue = minf(1.0, v.rescue + delta / RESCUE_TIME) if helping else maxf(0.0, v.rescue - delta * 0.5)
		if v.rescue >= 1.0:
			rescue(v)


## 救下来：冻结冷却马上好；被救的队员替公主挡一次扑抓 / 冲撞
func rescue(v: KnightBossFx.Victim) -> void:
	if not is_instance_valid(v) or not v.cursed:
		return
	v.cursed = false
	v.cursed_t = 0.0
	v.rescue = 0.0
	freeze_cool = 0.0
	shield = 1
	enraged = victims.any(func(x): return is_instance_valid(x) and x.cursed and x.cursed_t > ENRAGE_AFTER)
	SpeechBubble.say(v, str(data().get("thanks", ["谢、谢谢！下一下我替你挡！"]).pick_random()), 30.0, 2.0)
	Audio.play("star_burst", -8.0)


## 被救的队员冲上来挡一下（扑抓 / 冲撞 / 磁吸抓人之前问）
func _block(c: PlayableCharacter) -> bool:
	if shield <= 0:
		return false
	shield -= 1
	Fx.burst(c.get_parent(), c.global_position + Vector2(0, -8), "dust", 10, 40.0, 0.5, Vector2.ZERO, Color(0.7, 0.9, 1.0))
	_say(data().get("block", []))
	return true


# ------------------------------------------------------------------ 被抓
func grab(who: PlayableCharacter) -> void:
	if grabbed or _emitted or resonance:
		return
	if _block(who):
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


## 没被操控的那位这一帧干什么（KnightAI 的 plan）；被抓住、被穿上诅咒装备时的挣扎在 _grab_tick / _tick_gears 里
func ai_plan(ai: PlayableCharacter) -> Dictionary:
	if not ai_enabled or _emitted or transitioning or not is_instance_valid(_body) or grabbed == ai:
		return {"hold": true}
	if resonance:
		return {"to": Cutscene.cell_to_world(RUNES[0 if ai == pink else 1]), "near": 2.0}
	var other: PlayableCharacter = blue if ai == pink else pink
	# 搭档身上有诅咒装备：过去扯下来（站在旁边就在扯）
	if is_instance_valid(other) and other.has_meta(&"knight_gear"):
		return {"to": other.global_position, "near": RESCUE_R * 0.6, "dash": true}
	if ai == blue:
		var cursed: Array = victims.filter(func(x): return is_instance_valid(x) and x.cursed)
		if not cursed.is_empty() and freeze_cool <= 0.0:
			var v: Node2D = cursed[0]
			if v.global_position.distance_to(blue.global_position) <= FREEZE_R - 8.0:
				freeze_part(blue)
				return {"hold": true}
			return {"to": v.global_position, "near": 8.0, "dash": true}
		var p := _nearest_part(blue, func(x): return x.freeze_left <= 0.0 and not _soft(x))
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


## 现在打得动的：破绽（挠骑士）优先，再是冻住 / 卡住 / 骑士清醒时的部件
func soft_target() -> Node2D:
	if weak_left > 0.0 and is_instance_valid(weak_spot):
		return weak_spot
	return _nearest_part(GameState.player, func(x): return _soft(x))


func _soft(part: BossPart) -> bool:
	return part.freeze_left > 0.0 or lucid_left > 0.0 or (phase == 1 and stuck_left > 0.0)


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


## AI 的导演提示：先打破绽 / 冻住 / 卡住的部件
class Hooks extends BattleAIHooks:
	var task: TaskKnightBoss

	func priority_target() -> Variant:
		return task.soft_target() if is_instance_valid(task) else null

	func engage_range() -> float:
		return 220.0


# ------------------------------------------------------------------ 部件
## 蓝色公主 J：冻住身边的部件（贴在镇民身上的手印也一起冻掉 = 救下来）
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
			hit = true
	for v in victims:
		if is_instance_valid(v) and v.cursed and v.global_position.distance_to(who.global_position) <= FREEZE_R:
			rescue(v)
			return true
	if hit:
		freeze_cool = FREEZE_COOL
		Audio.play("ice", -4.0)
	return hit


## 打部件（测试也直接调）：冻住了 / 护腿卡住了 / 骑士清醒时才打得动；掉一个露出破绽，一套拆完换阶段
func hit_part(part: BossPart) -> bool:
	if not is_instance_valid(part) or part.broken:
		return false
	if part.id == "mask" or not _soft(part):
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
			if phase < PHASES - 1:
				_transition(phase + 1)
		else:
			open_weak(part.offset)
	return true


# ------------------------------------------------------------------ 共鸣收尾
func _start_resonance() -> void:
	resonance = true
	_close_weak()
	for n in fx:
		if is_instance_valid(n):
			n.queue_free()
	fx.clear()
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
	for c in _players():
		_take_gear(c)
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
		if not is_instance_valid(task):
			return
		# 骑士的笑（挠破绽涨）：头顶一条金色的条；清醒的时候整个身子发金光
		if task.knight_laugh > 0.0 or task.weak_left > 0.0:
			draw_rect(Rect2(-20, -72, 40, 4), Color(0.15, 0.1, 0.2, 0.8))
			draw_rect(Rect2(-20, -72, 40 * task.knight_laugh, 4), Color(1, 0.85, 0.4))
		if task.lucid_left > 0.0:
			draw_circle(Vector2(0, -20), 30 + sin(_t * 8.0) * 3.0, Color(1, 0.9, 0.5, 0.18))
		if task.enraged:
			draw_arc(Vector2(0, -20), 34, 0, TAU, 24, Color(0.9, 0.3, 0.6, 0.5 + 0.3 * sin(_t * 12.0)), 2.0)


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
		if is_instance_valid(task) and task.lucid_left > 0.0 and freeze_left <= 0.0:
			col = Color(1, 0.85, 0.5)
		if flash > 0.0:
			col = Color.WHITE
		match id:
			"mask":
				draw_circle(Vector2.ZERO, 10, Color(0.55, 0.3, 0.75, 0.9))
				draw_arc(Vector2(0, 2), 5, 0.2, PI - 0.2, 8, Color(1, 0.8, 1.0), 2)
				draw_circle(Vector2(-4, -3), 1.5, Color(1, 0.85, 1.0))
				draw_circle(Vector2(4, -3), 1.5, Color(1, 0.85, 1.0))
			"plate_l", "plate_r":
				# 半块胸甲：圆角的甲片 + 中间一道护心的纹
				var sx := -1.0 if id == "plate_l" else 1.0
				draw_rect(Rect2(-7, -8, 14, 16), col)
				draw_line(Vector2(-7 * sx, -8), Vector2(-7 * sx, 8), Color(col.darkened(0.3)), 2)
				draw_circle(Vector2(-5 * sx, -2), 2.0, Color(1, 0.7, 0.9))
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

class_name TaskArmorChase
extends Node2D
## 骑士篇 E「镇中追逃」（小镇 floor_06_after）：被诅咒附身的盔甲（CursedArmor）从营地楼梯口冲出来，一直追粉色公主。台词 data/after/knight_finale.json 的 chase。
##   开局两人在 PINK_START 附近，盔甲在营地楼梯口（START）挣扎 START_STUN 秒才追过来。
##   点亮四座笑声灯笼信标（BEACONS，分在镇上东北 / 西北 / 西边市场 / 南边城墙，按顺序，目标提示指过去 target_cell）：
##   站在信标 BEACON_R 以内按住 E 累计 HOLD 秒（亮的一瞬间盔甲被光晃到，停 LIGHT_STUN 秒）；四座都亮了以后跑回广场图腾柱下（PLAZA，也指路）= 完成。
##   扔陷阱：每 THROW_EVERY 秒（离她 THROW_MIN ~ THROW_MAX 之间、没被冻 / 晃）盔甲把地牢里的陷阱（THROWS 八种）扔到她前面的路上：
##     落点先亮影子 THROW_FLY 秒（Throw），落地变成真的陷阱场景，TRAP_LIFE 秒后收走（她正被这个陷阱缠着就等她脱身）；第一次扔某一种时粉色公主吐槽。
##   盔甲直线快、转弯慢，会被房子挡住；隔一阵铁手横扫一行（预警线）。镇民帮忙：盔甲走近栅栏点（GATES）而她已经跑开时，栅栏关上 GATE_TIME 秒挡住它。
##     栅栏门是支线「夜里的栅栏」装的：没做那个支线就没有栅栏（KnightQuests.is_done("fence")）。
##   做过支线「队长的旧剑术」：队长替她挡一次抱住（captain_block，盔甲被他顶开、晃 LIGHT_STUN 秒）。冲刺无敌的时候抓不住、横扫扫不到。
##   C 换成蓝色公主：J 冻住身边 FREEZE_R 以内的盔甲 FREEZE_TIME 秒，冷却 FREEZE_COOL 秒。
##   AI：AI_GUARD 以内盔甲在追粉色公主 → AI 蓝色公主去拦；AI_FLEE 以内 → AI 粉色公主跑开。
##   被抓住：盔甲抱住她轻挠——闷笑每秒 +GRAB_LAUGH（慢），疲倦每秒 +GRAB_FATIGUE（快，越来越舒服）；连按 J 够 MASH 下挣开（最多 GRAB_TIME 秒也会挣开）。
##     被抓 CATCHES 次 = 失败（knight_fail_chase），已经点亮的信标不灭。这段任务期间能换人（只在两位公主之间）。
##   没被操控的那位由 AI 控制（KnightAI，ai_plan）：AI 蓝色公主跟着、盔甲靠近粉色公主时冲过去，冷却一好就冻住它；
##     AI 粉色公主（玩家换成蓝色公主时）背着盔甲跑开，离得远就跟着玩家。两人都会躲铁手横扫的预警线。
## 状态 vars.task_chase_lit（亮了几座）、task_chase_caught（这一轮被抓了几次）。测试：armor、light(i)、grab()、mash()、freeze()、gates。

signal finished(ok: bool)

const START := Vector2i(57, 37)
const PINK_START := Vector2i(47, 33)
const START_STUN := 2.5
const LIGHT_STUN := 1.5
const BEACONS := [Vector2i(56, 12), Vector2i(14, 5), Vector2i(6, 24), Vector2i(26, 35)]
const PLAZA := Vector2i(41, 25)
const GATES := [Vector2i(53, 34), Vector2i(45, 35), Vector2i(36, 32)]
const BEACON_R := 16.0
const HOLD := 1.6
const PLAZA_R := 24.0
const GATE_TIME := 5.0
const GATE_NEAR := 50.0
const FREEZE_R := 48.0
const FREEZE_TIME := 3.0
const FREEZE_COOL := 12.0
const GRAB_TIME := 5.0
const GRAB_LAUGH := 0.02
const GRAB_FATIGUE := 0.09
const MASH := 8
const CATCHES := 3
const SAFE_TIME := 2.0
const AI_GUARD := 110.0
const AI_FLEE := 120.0
## 扔陷阱：种类 → 陷阱场景和要改的属性（绊索连着一个瞄准她的落笼；地洞里住着小触手）
const THROWS := {
	"tripwire": {"scene": "tripwire", "props": {"tiles_w": 3}},
	"pit": {"scene": "pit", "props": {"content": "tentacle"}},
	"powder_vent": {"scene": "powder_vent", "props": {}},
	"tickle_vine": {"scene": "tickle_vine", "props": {}},
	"mud": {"scene": "mud", "props": {"tiles_w": 2, "tiles_h": 1}},
	"sticky_carpet": {"scene": "sticky_carpet", "props": {"tiles_w": 2, "tiles_h": 2}},
	"cage": {"scene": "cage", "props": {}},
	"snare": {"scene": "snare", "props": {}},
}
const THROW_EVERY := 5.0
const THROW_FIRST := 6.0
const THROW_MIN := 50.0
const THROW_MAX := 260.0
const THROW_FLY := 0.9
const THROW_AHEAD := 44.0
const TRAP_LIFE := 10.0

## 测试：关掉 AI 搭档（没被操控的那位原地不动）
var ai_enabled := true
const LIT_KEY := "task_chase_lit"
const CAUGHT_KEY := "task_chase_caught"

static var _data := {}

var aborted := false
var started := false
var pink: PlayableCharacter
var blue: PlayableCharacter
var armor: CursedArmor
var beacons: Array = []
var gates: Array = []
var hold := 0.0
var grabbing := false
var grab_left := 0.0
var mashes := 0
var safe_left := 0.0
var freeze_cool := 0.0
var captain_block := 0
var _emitted := false
var _music_was := ""
var _lv: Node
var _was_no_switch := false
var _had_switch := false
var _near_t := 0.0
## 扔陷阱：下一次还有几秒、地上的陷阱 [{node, left}]、这一轮扔过的种类（第一次扔才吐槽）、按顺序轮着扔
var throw_left := THROW_FIRST
var traps: Array = []
var thrown_kinds: Array = []
var _throw_i := 0


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/after/knight_finale.json")) if FileAccess.file_exists("res://data/after/knight_finale.json") else null
		_data = parsed if parsed is Dictionary else {}
	return _data.get("chase", {})


static func lit() -> int:
	return int(GameState.vars.get(LIT_KEY, 0))


static func caught() -> int:
	return int(GameState.vars.get(CAUGHT_KEY, 0))


static func reset_items() -> void:
	GameState.vars[CAUGHT_KEY] = 0


static func status_text() -> String:
	if lit() >= BEACONS.size():
		return "回广场的图腾柱下！被抓 %d / %d" % [caught(), CATCHES]
	return "信标 %d / %d　被抓 %d / %d" % [lit(), BEACONS.size(), caught(), CATCHES]


func _ready() -> void:
	_lv = get_parent().get_parent()
	for n in _lv.find_children("*", "PlayableCharacter", true, false):
		if n is BluePrincess:
			blue = n
		else:
			pink = n
	_was_no_switch = bool(_lv.get("no_switch"))
	_had_switch = _lv.get_meta(&"free_switch", false)
	_lv.set("no_switch", false)
	_lv.set_meta(&"free_switch", true)
	Duo._bind_tab()   # 骑士篇的小镇图写了 no_switch，C 键原来没绑上
	for i in BEACONS.size():
		var b := Beacon.new()
		b.lit = i < lit()
		get_parent().add_child(b)
		b.global_position = Cutscene.cell_to_world(BEACONS[i])
		beacons.append(b)
	# 栅栏门：支线「夜里的栅栏」钉的那三道
	for c in (GATES if KnightQuests.is_done("fence") else []):
		var g := Gate.new()
		get_parent().add_child(g)
		g.global_position = Cutscene.cell_to_world(c)
		gates.append(g)
	armor = CursedArmor.new()
	get_parent().add_child(armor)
	armor.global_position = Cutscene.cell_to_world(START)
	armor.target = pink
	armor.grabbed.connect(func(_w): grab())
	armor.stun(START_STUN)
	if is_instance_valid(pink):
		pink.global_position = Cutscene.cell_to_world(PINK_START)
		if pink.camera:
			pink.camera.reset_smoothing()
	if is_instance_valid(blue):
		blue.global_position = Cutscene.cell_to_world(PINK_START) + Vector2(-14, 4)
	safe_left = SAFE_TIME
	captain_block = 1 if KnightQuests.is_done("spear") else 0
	KnightAI.install([pink, blue], ai_plan, null, ["struggle", "dodge", "task", "follow"])
	_music_was = Audio.music_id
	Audio.play_music("knight_boss")
	started = true


func _exit_tree() -> void:
	if _music_was != "" and Audio.music_id == "knight_boss":
		Audio.play_music(_music_was)
	for t in traps:
		if is_instance_valid(t["node"]):
			(t["node"] as Node).queue_free()
	for n in beacons + gates + [armor]:
		if is_instance_valid(n):
			n.queue_free()
	KnightAI.uninstall()
	if is_instance_valid(_lv):
		_lv.set("no_switch", _was_no_switch)
		_lv.set_meta(&"free_switch", _had_switch)
	if is_instance_valid(pink) and GameState.player != pink and is_instance_valid(GameState.player):
		GameState.switch_control(pink)


func _process(delta: float) -> void:
	if _emitted or not started or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink):
		return
	advance(delta)


func advance(delta: float) -> void:
	safe_left = maxf(0.0, safe_left - delta)
	freeze_cool = maxf(0.0, freeze_cool - delta)
	armor.paused = grabbing
	if grabbing:
		_grab_tick(delta)
		return
	if Input.is_action_just_pressed("attack") and GameState.player == blue:
		freeze()
	_gates()
	var i := lit()
	if i < BEACONS.size():
		var b: Beacon = beacons[i]
		if GameState.player == pink and pink.global_position.distance_to(b.global_position) <= BEACON_R and Input.is_action_pressed("interact"):
			hold += delta
			b.progress = hold / HOLD
			if hold >= HOLD:
				light(i)
		else:
			hold = maxf(0.0, hold - delta * 0.5)
			b.progress = hold / HOLD
	elif pink.global_position.distance_to(Cutscene.cell_to_world(PLAZA)) <= PLAZA_R:
		_emit(true)
		return
	_throw_tick(delta)
	_trap_tick(delta)
	_near_t -= delta
	if _near_t <= 0.0 and armor.global_position.distance_to(pink.global_position) < 60.0:
		_near_t = 4.0
		var pool: Array = data().get("near", [])
		if not pool.is_empty():
			SpeechBubble.say(armor, str(pool.pick_random()), 40.0, 1.6)


## 没被操控的那位这一帧干什么（KnightAI 的 plan）
func ai_plan(ai: PlayableCharacter) -> Dictionary:
	var r := _ai_move(ai)
	if ai == blue and _ai_burst():
		r = r.duplicate()
		r["skill"] = true
	return r


## AI 蓝色公主放千手解放：J 还在冷却、盔甲又在她身边，而且正扑向粉色公主（或者已经抱住了她）
func _ai_burst() -> bool:
	if not ai_enabled or _emitted or not is_instance_valid(armor) or not is_instance_valid(blue) or not PantsBurst.learned():
		return false
	if PantsBurst.cooldown_left(blue) > 0.0 or armor.stun_left > 0.0 or armor.freeze_left > 0.0:
		return false
	var near := blue.global_position.distance_to(armor.global_position) <= PantsBurst.RADIUS - 8.0
	return near and (grabbing or (freeze_cool > 0.0 and armor.global_position.distance_to(pink.global_position) < AI_GUARD))


func _ai_move(ai: PlayableCharacter) -> Dictionary:
	if not ai_enabled or _emitted or grabbing or not is_instance_valid(armor) or not is_instance_valid(pink):
		return {"hold": true}
	var d_pink := armor.global_position.distance_to(pink.global_position)
	if ai == blue:
		if armor.freeze_left > 0.0 or freeze_cool > 0.0 or d_pink > AI_GUARD:
			return {}
		if blue.global_position.distance_to(armor.global_position) <= FREEZE_R - 6.0:
			freeze()
			return {"hold": true}
		# 拦在盔甲和粉色公主之间
		return {"to": armor.global_position.lerp(pink.global_position, 0.3), "near": 6.0, "dash": true}
	if ai == pink and d_pink < AI_FLEE and armor.freeze_left <= 0.0 and armor.stun_left <= 0.0:
		var away := armor.global_position.direction_to(pink.global_position)
		return {"to": pink.global_position + away * 48.0, "near": 2.0, "dash": d_pink < 60.0}
	return {}


## 点亮第 i 座信标
func light(i: int) -> void:
	if i != lit():
		return
	GameState.vars[LIT_KEY] = i + 1
	hold = 0.0
	(beacons[i] as Beacon).lit = true
	armor.stun(LIGHT_STUN)
	Audio.play("star_burst", -6.0)
	var lines: Array = data().get("beacon_lit", [])
	if i < lines.size():
		GameState.princess_reacted.emit(str(lines[i]), 2.6)
	KnightFx.play(get_parent(), "beacon_light", (beacons[i] as Node2D).global_position + Vector2(0, -14), {"size": 56.0})
	if lit() >= BEACONS.size():
		GameState.hint(str(data().get("to_plaza", "")))
	_refresh_objective()


## 目标提示指向：下一座信标 / 四座都亮了以后的广场（KnightStory.objective 读）
func target_cell() -> Vector2i:
	return BEACONS[lit()] if lit() < BEACONS.size() else PLAZA


func _refresh_objective() -> void:
	if is_instance_valid(_lv):
		for n in _lv.find_children("*", "", true, false):
			if n.has_method("refresh_objective"):
				n.call("refresh_objective")
				break


## 扔陷阱的计时：到点了、离她不远不近、没被冻住 / 晃住 → 扔一个
func _throw_tick(delta: float) -> void:
	throw_left -= delta
	if throw_left > 0.0 or armor.freeze_left > 0.0 or armor.stun_left > 0.0:
		return
	var d := armor.global_position.distance_to(pink.global_position)
	if d < THROW_MIN or d > THROW_MAX:
		return
	throw_left = THROW_EVERY
	var kinds := THROWS.keys()
	throw_trap(str(kinds[_throw_i % kinds.size()]))
	_throw_i += 1


## 往她前面的路上扔一个 kind 的陷阱：落点 = 她走的方向前面 THROW_AHEAD（站着不动就是脚下）；落点在墙里就换近一点的
func throw_trap(kind: String, at := Vector2.INF) -> Throw:
	if not THROWS.has(kind) or not is_instance_valid(armor):
		return null
	if at == Vector2.INF:
		var ahead := pink.velocity.normalized() * THROW_AHEAD if pink.velocity.length() > 5.0 else Vector2.ZERO
		at = _free_spot(pink.global_position + ahead)
	var th := Throw.new()
	th.from = armor.global_position + Vector2(0, -20)
	th.to = at
	th.kind = kind
	th.task = self
	get_parent().add_child(th)
	armor.stun(0.35)
	SpeechBubble.say(armor, "……！", 30.0, 0.8)
	if not thrown_kinds.has(kind):
		thrown_kinds.append(kind)
		var first: Dictionary = data().get("throw_first", {})
		if first.has(kind):
			GameState.princess_reacted.emit(str(first[kind]), 2.8)
		if thrown_kinds.size() == 3 and is_instance_valid(blue):
			SpeechBubble.say(blue, str(data().get("throw_blue", "")), 30.0, 2.6)
	return th


## 落点附近一个没被墙 / 道具挡住的格子中心
func _free_spot(want: Vector2) -> Vector2:
	var space := get_world_2d().direct_space_state
	for r in [0.0, 16.0, 32.0]:
		for k in 8:
			var p: Vector2 = want + Vector2.RIGHT.rotated(k * TAU / 8.0) * float(r)
			var c := Cutscene.cell_to_world(_cell_of(p))
			var q := PhysicsPointQueryParameters2D.new()
			q.position = c
			q.collision_mask = 1
			if space.intersect_point(q, 1).is_empty():
				return c
			if r == 0.0:
				break
	return Cutscene.cell_to_world(_cell_of(pink.global_position))


static func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / 16.0), floori((p.y - 4.0) / 16.0))


## 落地：变成真的陷阱场景
func land(kind: String, at: Vector2) -> Node:
	var spec: Dictionary = THROWS[kind]
	var scn := load("res://scenes/traps/%s.tscn" % spec["scene"]) as PackedScene
	if scn == null:
		return null
	var n := scn.instantiate()
	for k in spec["props"]:
		n.set(k, spec["props"][k])
	var ents := get_parent()
	if kind == "tripwire":
		# 绊索：连着一个瞄准她的落笼（绊到了笼子就掉下来）
		var grp := "chase_trip_%d" % get_instance_id()
		n.set("targets", grp)
		var cage := (load("res://scenes/traps/cage.tscn") as PackedScene).instantiate()
		cage.set("group_name", grp)
		cage.set("aim", true)
		cage.set("trigger_mode", Trap.TriggerMode.MANUAL)
		ents.add_child(cage)
		cage.global_position = at
		traps.append({"node": cage, "left": TRAP_LIFE})
	ents.add_child(n)
	(n as Node2D).global_position = at
	traps.append({"node": n, "left": TRAP_LIFE, "kind": kind})
	KnightFx.play(ents, "trap_land", at, {"size": 40.0, "z": 0})
	Audio.play("drop", -6.0)
	return n


## 地上的陷阱到时间收走（她还被它缠着 / 站在上面就等一等）
func _trap_tick(delta: float) -> void:
	for t in traps.duplicate():
		var n: Node2D = t["node"] if is_instance_valid(t["node"]) else null
		if n == null:
			traps.erase(t)
			continue
		t["left"] = float(t["left"]) - delta
		if float(t["left"]) > 0.0:
			continue
		if pink.global_position.distance_to(n.global_position) < 28.0 and float(t["left"]) > -8.0:
			continue
		n.queue_free()
		traps.erase(t)


## 镇民帮忙：盔甲走近栅栏点、她已经跑开 → 关上栅栏挡一下
func _gates() -> void:
	for g in gates:
		var gate := g as Gate
		if gate.closed_left > 0.0 or gate.used:
			continue
		if armor.global_position.distance_to(gate.global_position) < GATE_NEAR and pink.global_position.distance_to(gate.global_position) > GATE_NEAR:
			gate.close(GATE_TIME)
			var pool: Array = data().get("townsfolk", [])
			if not pool.is_empty():
				GameState.princess_reacted.emit(str(pool.pick_random()), 2.4)


## 蓝色公主 J：冻住身边的盔甲
func freeze() -> bool:
	if freeze_cool > 0.0:
		GameState.notify(str(data().get("freeze_cool", "")), 1.0)
		return false
	if not is_instance_valid(blue) or blue.global_position.distance_to(armor.global_position) > FREEZE_R:
		return false
	freeze_cool = FREEZE_COOL
	armor.freeze(FREEZE_TIME)
	var pool: Array = data().get("freeze", [])
	if not pool.is_empty():
		GameState.princess_reacted.emit(str(pool.pick_random()), 2.0)
	return true


## 被抓住
func grab() -> void:
	if grabbing or safe_left > 0.0 or _emitted:
		return
	if captain_block > 0:
		# 支线「队长的旧剑术」：「到时候我会在」——队长冲上来，用矛杆把盔甲顶开
		captain_block -= 1
		safe_left = SAFE_TIME
		armor.stun(LIGHT_STUN)
		var line: Array = data().get("captain_block", ["（一根木矛横着插了进来——队长用矛杆把盔甲顶开了！「……我说过，我会在。」）"])
		GameState.princess_reacted.emit(str(line.pick_random()), 3.0)
		Audio.play("hit", -4.0)
		return
	grabbing = true
	grab_left = GRAB_TIME
	mashes = 0
	GameState.vars[CAUGHT_KEY] = caught() + 1
	if GameState.player != pink:
		GameState.switch_control(pink)
	if pink.status:
		pink.status.apply_root(GRAB_TIME)
	var pool: Array = data().get("caught", [])
	if not pool.is_empty():
		GameState.princess_reacted.emit(str(pool.pick_random()), 3.0)
	if caught() >= CATCHES:
		_emit(false)


func _grab_tick(delta: float) -> void:
	grab_left -= delta
	armor.global_position = armor.global_position.lerp(pink.global_position + Vector2(10, -2), 0.3)
	if pink.laugh:
		pink.laugh.add(pink.laugh.max_value * GRAB_LAUGH * delta)
	if pink.fatigue:
		pink.fatigue.add(pink.fatigue.max_value * GRAB_FATIGUE * delta)
	if randf() < delta * 1.5:
		ZoneFx.play("sole", pink.get_parent(), ZoneFx.body_point(pink, "sole"), 0.7, true)
		var r: Array = data().get("caught_react", [])
		if not r.is_empty():
			SpeechBubble.say(pink, str(r.pick_random()), 30.0, 1.2)
	if Input.is_action_just_pressed("attack"):
		mash()
	if grab_left <= 0.0:
		_escape()


## 连按 J
func mash() -> void:
	if not grabbing:
		return
	mashes += 1
	pink.shake(0.1)
	if mashes >= MASH:
		_escape()


func _escape() -> void:
	grabbing = false
	safe_left = SAFE_TIME
	if pink.status:
		pink.status.clear_root()
	armor.freeze(1.2)
	armor.global_position += pink.global_position.direction_to(armor.global_position) * 24.0
	var pool: Array = data().get("escape", [])
	if not pool.is_empty():
		GameState.princess_reacted.emit(str(pool.pick_random()), 1.8)


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	grabbing = false
	# 被抓住时结束（第三次被抓 = 失败）：把抱住的定身解开，不然重来以后她还要站着不动好几秒
	for c in [pink, blue]:
		if is_instance_valid(c) and c.status:
			c.status.clear_root()
	if is_instance_valid(armor):
		armor.paused = true
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)


## 笑声灯笼信标：灯杆 + 灯笼，点亮的进度一圈，亮了以后发光
class Beacon extends Node2D:
	var lit := false
	var progress := 0.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 1
		add_to_group("chase_beacon")

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_line(Vector2(0, 4), Vector2(0, -18), Color("6b4a32"), 2)
		var col := Color(1, 0.8, 0.45) if lit else Color(0.4, 0.32, 0.38)
		if lit:
			draw_circle(Vector2(0, -20), 12 + sin(_t * 4.0) * 1.5, Color(1, 0.75, 0.4, 0.25))
		draw_circle(Vector2(0, -20), 5, col)
		draw_arc(Vector2(0, -21), 1.5, 0.2, PI - 0.2, 6, Color("3a2a2a"), 1)
		if not lit and progress > 0.0:
			draw_arc(Vector2(0, -20), 9, -PI / 2, -PI / 2 + TAU * clampf(progress, 0.0, 1.0), 16, Color(1, 0.9, 0.5), 2)


## 扔过来的陷阱：落点的影子越来越大（THROW_FLY 秒），一团紫色的东西沿着抛物线飞过去（throw_trail 特效），落地 → task.land
class Throw extends Node2D:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var kind := ""
	var task: TaskArmorChase
	var _t := 0.0
	var _fx: KnightFx

	func _ready() -> void:
		z_index = 3
		global_position = to
		_fx = KnightFx.play(self, "throw_trail", from, {"size": 30.0, "loop": true, "z": 4})

	func _process(delta: float) -> void:
		_t += delta
		var k := clampf(_t / TaskArmorChase.THROW_FLY, 0.0, 1.0)
		if is_instance_valid(_fx):
			var p := from.lerp(to, k) + Vector2(0, -sin(k * PI) * 46.0)
			_fx.global_position = p
			_fx.rotation = (to - from).angle()
		queue_redraw()
		if k >= 1.0:
			if is_instance_valid(task):
				task.land(kind, to)
			queue_free()

	func _draw() -> void:
		var k := clampf(_t / TaskArmorChase.THROW_FLY, 0.0, 1.0)
		var r := 4.0 + 10.0 * k
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, r, Color(0.25, 0.05, 0.3, 0.25 + 0.35 * k))
		draw_arc(Vector2.ZERO, 14.0, 0, TAU, 20, Color(0.85, 0.4, 1.0, 0.5 + 0.4 * k), 1.5)
		draw_set_transform(Vector2.ZERO)


## 镇民拉上的栅栏：关着的时候挡住盔甲（也挡人），GATE_TIME 秒后打开；每个点只帮一次
class Gate extends StaticBody2D:
	var closed_left := 0.0
	var used := false
	var _shape: CollisionShape2D

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 0
		_shape = CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(44, 8)
		_shape.shape = r
		_shape.disabled = true
		add_child(_shape)

	func close(time: float) -> void:
		closed_left = time
		used = true
		collision_layer = 1
		_shape.disabled = false

	func _process(delta: float) -> void:
		if closed_left > 0.0:
			closed_left -= delta
			if closed_left <= 0.0:
				collision_layer = 0
				_shape.disabled = true
		queue_redraw()

	func _draw() -> void:
		if closed_left <= 0.0:
			return
		for i in 6:
			draw_line(Vector2(-22 + i * 8.8, -6), Vector2(-22 + i * 8.8, 4), Color("8b6644"), 2)
		draw_line(Vector2(-22, -3), Vector2(22, -3), Color("a47a50"), 2)
		draw_line(Vector2(-22, 2), Vector2(22, 2), Color("a47a50"), 2)

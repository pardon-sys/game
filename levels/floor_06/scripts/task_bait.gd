class_name TaskBait
extends Node2D
## 骑士篇 C「以笑为饵」（小镇 floor_06_after，夜里）：诅咒从地牢漏出来，变成诅咒手印，贴在镇民身上偷走他们的笑声。台词 data/after/knight.json 的 bait。
##   手印（CurseHand）怕人：可操作角色走近 FEAR_R 以内就躲开；只会被粉色公主的笑声引过来——
##     粉色公主的闷笑到 LURE_AT 以上时，LURE_BASE + 闷笑 × LURE_PER 以内的手印会扔下镇民爬向她（贴上来挠得很轻，疲倦涨得多）；
##     闷笑到 SWARM_AT 以上 = 笑过头：全图的手印一起扑过来。身上同时贴着 SWAMP 只 = 失败（knight_fail_bait，抓到的不退）。
##   让自己笑起来：广场上的痒痒草（TickleGrass）、诅咒地纹（CurseMark，踩上去还会把最近的手印招过来）。
##   抓：C 换成蓝色公主，按 J 冻住身边 FREEZE_R 以内的手印（贴在谁身上都冻得掉，冷却 FREEZE_COOL 秒），再按 K 把身边冻住的收进瓶子。
##   收够 GOAL 只 = 完成。这段任务期间小镇能换人（free_switch）。
## 状态 vars.task_bait_caught。测试：hands、caught()、freeze_near(角色)、bottle_near(角色)、advance(秒)、pink / blue。

signal finished(ok: bool)

const GOAL := 6
const HANDS := 8
const SPAWN := [Vector2i(37, 22), Vector2i(36, 27), Vector2i(48, 22), Vector2i(49, 27), Vector2i(42, 21), Vector2i(44, 23), Vector2i(33, 24), Vector2i(51, 25)]
const GRASS := [Vector2i(30, 20), Vector2i(26, 26), Vector2i(46, 30), Vector2i(53, 21)]
const MARKS := [Vector2i(35, 30), Vector2i(29, 24), Vector2i(48, 18), Vector2i(41, 31), Vector2i(55, 27)]
const FEAR_R := 40.0
const LURE_AT := 0.25
const LURE_BASE := 30.0
const LURE_PER := 150.0
const SWARM_AT := 0.85
const SWAMP := 5
const FREEZE_R := 30.0
const FREEZE_COOL := 1.5
const BOTTLE_R := 20.0
const CAUGHT_KEY := "task_bait_caught"

static var _data := {}

var aborted := false
var started := false
var pink: PlayableCharacter
var blue: PlayableCharacter
var hands: Array[CurseHand] = []
var grass: Array = []
var marks: Array = []
var swarming := false
var freeze_cool := 0.0
var _emitted := false
var _lv: Node
var _had_switch := false
var _was_no_switch := false
var _say_t := 0.0


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/after/knight.json")) if FileAccess.file_exists("res://data/after/knight.json") else null
		_data = parsed if parsed is Dictionary else {}
	return _data.get("bait", {})


static func caught() -> int:
	return int(GameState.vars.get(CAUGHT_KEY, 0))


static func reset_items() -> void:
	pass   # 抓到的不退，失败只把手印重新撒一遍


static func status_text() -> String:
	return "收瓶 %d / %d　蓝色：J 冻住 K 收瓶" % [caught(), GOAL]


func _ready() -> void:
	_lv = get_parent().get_parent()
	for n in _lv.find_children("*", "PlayableCharacter", true, false):
		if n is BluePrincess:
			blue = n
		elif n == GameState.player or pink == null:
			pink = n
	if GameState.player is BluePrincess:
		pink = null
		for n in _lv.find_children("*", "PlayableCharacter", true, false):
			if not n is BluePrincess:
				pink = n
	_was_no_switch = bool(_lv.get("no_switch"))
	_had_switch = _lv.get_meta(&"free_switch", false)
	_lv.set("no_switch", false)
	_lv.set_meta(&"free_switch", true)
	for c in SPAWN.slice(0, HANDS):
		_spawn(Cutscene.cell_to_world(c))
	for c in GRASS:
		var g := TickleGrass.new()
		get_parent().add_child(g)
		g.global_position = Cutscene.cell_to_world(c)
		grass.append(g)
	for c in MARKS:
		var m := CurseMark.new()
		m.on_step = _on_mark
		get_parent().add_child(m)
		m.global_position = Cutscene.cell_to_world(c)
		marks.append(m)
	started = true


func _exit_tree() -> void:
	for n in hands + grass + marks:
		if is_instance_valid(n):
			n.queue_free()
	if is_instance_valid(_lv):
		_lv.set("no_switch", _was_no_switch)
		_lv.set_meta(&"free_switch", _had_switch)
	if is_instance_valid(pink) and GameState.player != pink and is_instance_valid(GameState.player):
		GameState.switch_control(pink)


func _spawn(at: Vector2) -> CurseHand:
	var h := CurseHand.new()
	get_parent().add_child(h)
	h.global_position = at
	h.ticked.connect(_on_tick.bind(h))
	hands.append(h)
	var npc := _nearest_npc(at, 40.0)
	if npc:
		h.latch(npc)
	return h


## 镇民（小镇导演 AfterTown 摆的那些，不算可操作角色）
func _npcs() -> Array:
	for d in _lv.find_children("*", "AfterTown", true, false):
		return (d as AfterTown).residents.values().filter(func(n): return is_instance_valid(n) and not n is PlayableCharacter and (n as Node2D).visible)
	return []


func _nearest_npc(at: Vector2, r: float) -> Node2D:
	var best: Node2D = null
	for n in _npcs():
		var nd := n as Node2D
		if nd and nd.global_position.distance_to(at) < r:
			if best == null or nd.global_position.distance_to(at) < best.global_position.distance_to(at):
				best = nd
	return best


func _process(delta: float) -> void:
	if _emitted or not started or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink):
		return
	advance(delta)
	if Input.is_action_just_pressed("attack") and GameState.player == blue:
		freeze_near(blue)


func _unhandled_input(event: InputEvent) -> void:
	if _emitted or GameState.in_dialogue:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_K:
		if is_instance_valid(GameState.player):
			bottle_near(GameState.player)
		get_viewport().set_input_as_handled()


## 一帧：按粉色公主的闷笑决定手印扑向她还是躲开，数身上贴着几只
func advance(delta: float) -> void:
	freeze_cool = maxf(0.0, freeze_cool - delta)
	var r := pink.laugh.ratio() if pink.laugh else 0.0
	var was := swarming
	swarming = r >= SWARM_AT
	if swarming and not was:
		_say(data().get("swarm", []))
	var lure := LURE_BASE + r * LURE_PER if r >= LURE_AT else 0.0
	var on_pink := 0
	for h in hands.duplicate():
		if not is_instance_valid(h) or h.state == "gone":
			hands.erase(h)
			continue
		if h.state == "frozen":
			continue
		if h.state == "latched":
			if h.target == pink:
				on_pink += 1
				continue
			if h.target == blue:
				continue
		var d: float = h.global_position.distance_to(pink.global_position)
		if swarming or d <= lure:
			if h.state == "latched":
				h.release()
			h.seek(pink)
		elif h.state != "latched" and _near_player(h.global_position) and h.state != "seek":
			h.flee(GameState.player.global_position)
		elif h.state in ["flee", "wander"] and not _near_player(h.global_position):
			var npc := _nearest_npc(h.global_position, 60.0)
			if npc:
				h.seek(npc)
	if on_pink >= SWAMP:
		_emit(false)
		return
	_say_t -= delta
	if _say_t <= 0.0 and r < LURE_AT:
		_say_t = 6.0
		_say(data().get("calm", []))


func _near_player(at: Vector2) -> bool:
	for c in [pink, blue]:
		if is_instance_valid(c) and c.global_position.distance_to(at) <= FEAR_R:
			return true
	return false


## 踩到诅咒地纹：把离她最近的那只手印招过来
func _on_mark(_m: CurseMark, who: PlayableCharacter) -> void:
	var best: CurseHand = null
	for h in hands:
		if is_instance_valid(h) and h.state not in ["frozen", "gone"] and (h.state != "latched" or h.target != who):
			if best == null or h.global_position.distance_to(who.global_position) < best.global_position.distance_to(who.global_position):
				best = h
	if best:
		if best.state == "latched":
			best.release()
		best.seek(who)
	_say(data().get("mark", []))


func _on_tick(who: Node2D, _h: CurseHand) -> void:
	var pool: Array = data().get("pink_tick" if who == pink else ("blue_tick" if who == blue else "npc_tick"), [])
	if not pool.is_empty() and randf() < 0.5:
		GameState.princess_reacted.emit(str(pool.pick_random()), 2.4)
	var react: Array = data().get("pink_react" if who == pink else ("blue_react" if who == blue else ""), [])
	if not react.is_empty() and randf() < 0.4:
		SpeechBubble.say(who, str(react.pick_random()), 30.0, 1.4)


## J（蓝色公主）：冻住身边的手印（贴在谁身上都冻得掉）
func freeze_near(who: PlayableCharacter) -> int:
	if freeze_cool > 0.0 or not is_instance_valid(who):
		return 0
	freeze_cool = FREEZE_COOL
	var n := 0
	for h in hands:
		if is_instance_valid(h) and h.state != "gone" and h.state != "frozen" and h.global_position.distance_to(who.global_position) <= FREEZE_R:
			h.release()
			h.freeze()
			n += 1
	Fx.burst(who.get_parent(), who.global_position, "drop", 8, 30.0, 0.4, Vector2(0, -10))
	if n > 0:
		_say(data().get("freeze", []))
	return n


## K：把身边冻住的手印收进瓶子
func bottle_near(who: PlayableCharacter) -> int:
	var n := 0
	for h in hands.duplicate():
		if is_instance_valid(h) and h.state == "frozen" and h.global_position.distance_to(who.global_position) <= BOTTLE_R:
			hands.erase(h)
			h.dispel()
			n += 1
	if n == 0:
		return 0
	GameState.vars[CAUGHT_KEY] = caught() + n
	Audio.play("item", -4.0)
	GameState.notify(str(data().get("bottled", "收进瓶子：%d / %d")) % [caught(), GOAL], 1.6)
	if caught() >= GOAL:
		_emit(true)
	elif hands.size() < GOAL - caught() + 1:
		_spawn(Cutscene.cell_to_world(SPAWN[randi() % SPAWN.size()]))
	return n


func _say(pool: Array) -> void:
	if not pool.is_empty():
		GameState.princess_reacted.emit(str(pool.pick_random()), 2.6)


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)

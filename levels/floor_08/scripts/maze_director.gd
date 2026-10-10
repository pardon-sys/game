class_name MazeDirector
extends Node2D
## 第八层夜迷宫的导演（每段迷宫地图里放一个：X = f8maze section=<1|2|3>；第八层专属）：
##   她（蓝色公主）身上挂手覆盖（HandCover）、笑声半径（LaughRadius）；冷光（CarryLight，关卡的 light_drain）。
##   紫手：保持场上最多 hand_cap 只，在离她 110~260 像素、不在光里的地面上刷出来；笑得越厉害刷得越快。
##   QTE：紫手靠近 → 头顶按键序列（KeySequenceQTE）；按键数 / 限时按身上的手和闷笑；冷光暗时提示晚出现。
##        成功 → 手消散；失败 → 盖在一个部位上（偏大腿 / 屁股；信使记号优先）+ 她的反应台词（data/characters/blue/maze_lines.json）。
##   节点小剧场：第一只 / 超过 8 只 / 超过 12 只 / 第一次大腿屁股 / 大腿屁股超过 4 只（f8_maze_<id>，各一次）。
##   月光灯：走进亮着的灯 → 手全散、冷光补、记为重生点。冰晶结界：冻住范围内的手；满蓄力震掉大腿 / 屁股以外的手；扣冷光。
##   节奏：身上的手一起蓄力时屏幕边缘闪紫光；光里或冲刺能躲。
##   笑倒：迷宫笑倒小剧场（f8_maze_defeat_1 / 2 轮流）→ 回到上一盏亮着的灯，手清空。
##   换段：身上的手和冷光记在 GameState.vars（f8m_hands / f8m_light），下一段接着用。

const HAND_SCRIPT := preload("res://levels/floor_08/scripts/maze_hand.gd")
## 每段：同时最多几只紫手、刷新间隔（秒，平静时）
const SECTION := {
	1: {"cap": 6, "gap": 7.0},
	2: {"cap": 9, "gap": 5.5},
	3: {"cap": 12, "gap": 4.5},
}
const SPAWN_MIN := 110.0
const SPAWN_MAX := 260.0
const MILESTONES := ["first", "total_8", "total_12", "weak_first", "weak_4"]

## 第一次进迷宫时的介绍板
const TUTORIAL := [
	"千手的紫手在黑暗里游荡。靠近时她头顶会弹出一排按键：按键时站着不能动，按顺序按完（J K L U I O）就能把手弹开。",
	"· 没按上：那只手会盖在她身上的一个部位，一直慢慢地挠（每个部位一只，大腿和屁股不限只数）。",
	"· 她一笑就有一圈「笑声」：圈里的手会被吸引过来。越笑圈越大。",
	"· 月光灯：走进亮着的灯，身上的手全部散掉，也是重生点。冰晶结界满蓄力能震掉大腿 / 屁股以外的手。",
	"· 身边的冷光会慢慢变暗：越暗手越难看见、按键提示越晚。在月光灯下补满；放魔法会消耗一截。",
	"· 身上的手有时会一起「屏住」然后狠挠一下：屏幕边缘闪紫光时冲刺，或者躲进光里。",
	"· 按 Z / X 绕着她转镜头（90°）：被墙挡住的角落转一下就看得到；挡住她的墙会变半透明。方向键始终按屏幕方向走。",
	"· 迷宫里散落着发光的碎片……捡起来看看。",
]

static var instance: MazeDirector

@export var section := 1

var blue: PlayableCharacter
var cover: HandCover
var radius: LaughRadius
var last_lamp: MoonLamp
var marked_zone := ""
var _spawn_t := 3.0
var _floor_cells: Array[Vector2i] = []
var _qte_hand: MazeHand
var _hud: CanvasLayer
var _hud_label: Label
var _light_bar: ColorRect
var _rhythm_fx: ScreenFx
var _defeats := 0
var _busy := false
## 第三段的出口（spawn id=maze_exit）：走到这里 → 结局
var _exit_at := Vector2.INF
var _ended := false


func _ready() -> void:
	instance = self
	add_to_group("maze_director")
	add_to_group("combo_effect_handler")
	await get_tree().process_frame
	await get_tree().process_frame
	_collect_floor()
	_bind(GameState.player)
	GameState.player_registered.connect(_bind)
	PlayableCharacter.death_override = _on_down
	_make_hud()
	for sp in get_tree().get_nodes_in_group("spawn_point"):
		if str(sp.get("id")) == "maze_exit" and level().is_ancestor_of(sp):
			_exit_at = (sp as Node2D).global_position
	if section == 1:
		TutorialBoard.show_once("f8m_tutorial", "夜迷宫", TUTORIAL)
	_setup_breathing()


func _exit_tree() -> void:
	if instance == self:
		instance = null
	Dialogue.portrait_fx.cover_hands = {}
	Dialogue.portrait_fx.cover_charging = false
	if PlayableCharacter.death_override.is_valid() and PlayableCharacter.death_override.get_object() == self:
		PlayableCharacter.death_override = Callable()
	_save_carry()
	PlayerInputController.actions_locked = false
	PlayerInputController.movement_locked = false


func level() -> Node:
	var n: Node = get_parent()
	while n and not n.has_node("Walls"):
		n = n.get_parent()
	return n


func _collect_floor() -> void:
	var lv := level()
	if lv == null:
		return
	var floor_layer := lv.get_node_or_null("Floor") as TileMapLayer
	var walls := lv.get_node_or_null("Walls") as TileMapLayer
	if floor_layer == null:
		return
	for c in floor_layer.get_used_cells():
		if walls == null or walls.get_cell_source_id(c) == -1:
			_floor_cells.append(c)


func _bind(p: Node) -> void:
	if not (p is PlayableCharacter) or not is_instance_valid(p) or not level().is_ancestor_of(p):
		return
	blue = p as PlayableCharacter
	cover = HandCover.attach(blue)
	cover.safe_check = func(c: Node2D) -> bool: return light_at(c.global_position) is Vector2
	if not cover.hands_changed.is_connected(_on_hands_changed):
		cover.hands_changed.connect(_on_hands_changed)
		cover.milestone.connect(_on_milestone)
		cover.rhythm.connect(_on_rhythm)
	for id in MILESTONES:
		if GameState.has_flag("f8m_ms_" + id):
			cover.reached[id] = true
	radius = LaughRadius.attach(blue)
	if not blue.magic_event.is_connected(_on_magic):
		blue.magic_event.connect(_on_magic)
	# 迷宫里：闷笑满了就笑倒（不等扣完血）
	if blue.laugh and not blue.laugh.overflow.is_connected(_on_overflow):
		blue.laugh.overflow.connect(_on_overflow)
	_load_carry()


# ------------------------------------------------------------------ 换段：带上身上的手和冷光
func _save_carry() -> void:
	if cover and is_instance_valid(cover):
		GameState.vars["f8m_hands"] = cover.hands.duplicate()
	var cl := carry_light()
	if cl:
		GameState.vars["f8m_light"] = cl.level


func _load_carry() -> void:
	var saved: Variant = GameState.vars.get("f8m_hands", {})
	if saved is Dictionary and cover.total() == 0:
		for z in saved:
			for i in int(saved[z]):
				cover.hands[z] = cover.count(z) + 1
		if cover.total() > 0:
			cover.hands_changed.emit("", 0, cover.total())
	Dialogue.portrait_fx.cover_hands = cover.hands.duplicate()
	var cl := carry_light()
	if cl and GameState.vars.has("f8m_light"):
		cl.level = float(GameState.vars["f8m_light"])


func carry_light() -> CarryLight:
	return blue.get_node_or_null("CarryLight") as CarryLight if is_instance_valid(blue) else null


# ------------------------------------------------------------------ 光 / 吸引（紫手调）
## pos 在光里（亮着的月光灯、月光镜的光带）就返回光源位置，否则 null。
func light_at(pos: Vector2) -> Variant:
	for l in get_tree().get_nodes_in_group("moon_lamp"):
		var lamp := l as MoonLamp
		if lamp and lamp.covers(pos):
			return lamp.global_position
	for b in get_tree().get_nodes_in_group("light_band"):
		if b.has_method("covers") and b.covers(pos):
			return b.call("source_point")
	return null


func attracts(hand: Node2D) -> bool:
	if not is_instance_valid(blue) or radius == null:
		return false
	var r := radius.radius()
	return r > 0.0 and hand.global_position.distance_to(blue.global_position) <= r


## 笑得越厉害，被吸引的手走得越快（0 ~ 1）。
func attract_boost() -> float:
	return clampf(radius.radius() / 140.0, 0.0, 1.0) * 0.6 if radius else 0.0


## 冷光越暗，紫手越淡（0 ~ 1）。
func hand_visibility() -> float:
	var cl := carry_light()
	return cl.brightness() if cl else 1.0


func laugh_stage() -> int:
	if blue == null or blue.laugh == null:
		return 0
	var lm := blue.laugh
	return 3 if lm.value >= lm.helpless_stage2_threshold else (2 if lm.is_helpless() else (1 if lm.value >= lm.giggle_threshold else 0))


# ------------------------------------------------------------------ 每帧
func _process(delta: float) -> void:
	if not is_instance_valid(blue):
		_bind(GameState.player)
		return
	if _busy:
		return
	_update_hud()
	if GameState.in_dialogue or CG.is_busy() or Cutscene.is_playing() or not blue.is_alive():
		return
	_check_lamps(delta)
	var cl := carry_light()
	if cl:
		GameState.vars["f8m_light"] = cl.level
	if _exit_at != Vector2.INF and not _ended and blue.global_position.distance_to(_exit_at) < 16.0:
		_run_ending()
		return
	_update_heartbeat(delta)
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		var info: Dictionary = SECTION.get(section, SECTION[1])
		_spawn_t = float(info["gap"]) / (1.0 + laugh_stage() * 0.6)
		if hands().size() < int(info["cap"]):
			spawn_hand()


func hands() -> Array:
	return get_tree().get_nodes_in_group("maze_hand")


## 在离她不远不近、不在光里的地面上刷一只紫手（返回它；没地方刷返回 null）。
func spawn_hand(at := Vector2.INF) -> MazeHand:
	var lv := level()
	var pos := at
	if pos == Vector2.INF:
		for i in 40:
			if _floor_cells.is_empty():
				break
			var c: Vector2i = _floor_cells.pick_random()
			var p := GridPath.center(c)
			var d := p.distance_to(blue.global_position)
			if d >= SPAWN_MIN and d <= SPAWN_MAX and not (light_at(p) is Vector2):
				pos = p
				break
	if pos == Vector2.INF:
		return null
	var h := MazeHand.new()
	h.director = self
	var ents := lv.get_node_or_null("Entities")
	(ents if ents else lv).add_child(h)
	h.global_position = pos
	return h


## 在她周围一圈（离她 30~64 像素、不在光里的地面格；不够就放宽到 100）召出 n 只紫手（千手的影子、笑声收集瓶、组合技）。
func summon_near(n: int) -> int:
	if not is_instance_valid(blue):
		return 0
	var near: Array[Vector2] = []
	for far in [64.0, 100.0]:
		near.clear()
		for c in _floor_cells:
			var p := GridPath.center(c)
			var d := p.distance_to(blue.global_position)
			if d >= 30.0 and d <= far and not (light_at(p) is Vector2):
				near.append(p)
		if near.size() >= n:
			break
	near.shuffle()
	var made := 0
	for p in near.slice(0, n):
		if spawn_hand(p):
			made += 1
	return made


## 从某个地方（镜面水洼的倒影）冒出一只紫手，她这次失败就优先盖 zone。
func hand_from(pos: Vector2, zone: String) -> void:
	marked_zone = zone
	var h := spawn_hand(pos)
	if h:
		h.cooldown(0.2)


# ------------------------------------------------------------------ 组合技的关卡效果（ComboTracker 转过来）
func on_combo_effect(e: Dictionary, actor: Node, _source: Node) -> void:
	if actor != blue:
		return
	match str(e.get("type", "")):
		"laugh_radius_boost":
			radius.boost(float(e.get("mult", 2.0)), float(e.get("duration", 8.0)))
		"summon_hands":
			summon_near(int(e.get("count", 3)))
		"cover_hands":
			for i in int(e.get("count", 1)):
				cover_zone(str(e.get("zone", "thigh")))
		"light_drain":
			var cl := carry_light()
			if cl:
				cl.level = minf(cl.level, float(e.get("to", 0.1)))
				cl.dim(3.0)
		"rhythm_now":
			cover.rhythm_now()
		"rhythm_again":
			cover.rhythm_again()
		"jar_burst":
			for j in get_tree().get_nodes_in_group("laugh_jar"):
				if (j as Node2D).global_position.distance_to(blue.global_position) < 200.0 and j.has_method("fill_now"):
					j.fill_now()


# ------------------------------------------------------------------ 呼吸墙（迷宫会呼吸）
## design.json 的 breathing：[{a: [[x,y]...], b: [...]}]——地图上两段都是地面；开场先把 b 升起来（a 通、b 封），
## 每次心跳翻转一次（a 升起、b 沉下 / 反过来）。画面是「活墙」（LivingWall）：心跳前 WARN 秒要升的裂纹 / 要沉的墙脉络发亮、地面轻震、低沉的心跳声。
## 间隔：BEAT_BASE 秒，身上每只手 −2 秒，最快 BEAT_MIN 秒。有人站着的格子不升墙（TerrainShifter）。
const BEAT_BASE := 40.0
const BEAT_MIN := 15.0
const BEAT_WARN := 1.5

var breathing: Array = []
var breath_state := false
var shifter: TerrainShifter
var living_walls := {}
var _beat_t := BEAT_BASE
var _beat_warned := false


func _setup_breathing() -> void:
	var lv := level()
	if lv == null:
		return
	var path := "res://levels/%s/design.json" % str(lv.get("floor_id"))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not (parsed is Dictionary):
		return
	for b in parsed.get("breathing", []):
		var a_cells: Array[Vector2i] = []
		var b_cells: Array[Vector2i] = []
		for p in b["a"]:
			a_cells.append(Vector2i(int(p[0]), int(p[1])))
		for p in b["b"]:
			b_cells.append(Vector2i(int(p[0]), int(p[1])))
		breathing.append({"a": a_cells, "b": b_cells})
	if breathing.is_empty():
		return
	shifter = TerrainShifter.new()
	add_child(shifter)
	var walls := lv.get_node("Walls") as TileMapLayer
	shifter.setup(lv, walls.get_used_cells()[0])
	# 每个呼吸墙格子一面「活墙」（画面）；碰撞由 TerrainShifter 加在透明的 Walls 图层上
	for pair in breathing:
		for c in pair["a"] + pair["b"]:
			if not living_walls.has(c):
				living_walls[c] = LivingWall.make(lv, c)
		shifter.raise_walls(pair["b"])
	_sync_living_walls(false)


## 活墙的样子跟着碰撞走（有人站着的格子升不起来，那一格就还是裂纹）。
func _sync_living_walls(animate := true) -> void:
	var walls := level().get_node("Walls") as TileMapLayer
	for c in living_walls:
		(living_walls[c] as LivingWall).set_up(walls.get_cell_source_id(c) != -1, animate)


## 心跳前要变的地方发亮（要升起的裂纹、要沉下的墙）。
func _warn_living_walls(on: bool) -> void:
	for c in living_walls:
		(living_walls[c] as LivingWall).warn(on)


func beat_interval() -> float:
	return maxf(BEAT_MIN, BEAT_BASE - (cover.total() if cover else 0) * 2.0)


func _update_heartbeat(delta: float) -> void:
	if breathing.is_empty():
		return
	_beat_t -= delta
	if _beat_t <= BEAT_WARN and not _beat_warned:
		_beat_warned = true
		_warn_living_walls(true)
		Audio.play("roll", -6.0, 0.0, 0.5)
		if is_instance_valid(blue):
			blue.shake(0.4)
	if _beat_t <= 0.0:
		heartbeat()


## 心跳一次：所有呼吸墙翻转。
func heartbeat() -> void:
	_beat_t = beat_interval()
	_beat_warned = false
	_warn_living_walls(false)
	breath_state = not breath_state
	for pair in breathing:
		var up: Array = pair["a"] if breath_state else pair["b"]
		var down: Array = pair["b"] if breath_state else pair["a"]
		shifter.lower_cells(down)
		shifter.raise_walls(up)
	_sync_living_walls()
	Audio.play("door_close", -4.0, 0.0, 0.5)
	ScreenFx.flash(Color(0.45, 0.2, 0.6), 0.25)


func _check_lamps(delta: float) -> void:
	var cl := carry_light()
	var lamp_here: MoonLamp = null
	for l in get_tree().get_nodes_in_group("moon_lamp"):
		if (l as MoonLamp).covers(blue.global_position):
			lamp_here = l
	if lamp_here:
		if cover.total() > 0:
			cover.clear()
			marked_zone = ""
			Audio.play("chime", -6.0, 0.0, 0.7)
			GameState.princess_reacted.emit(MazeLines.pick("lamp_clear"), 2.4)
		if cl:
			cl.refill(0.5)
		if last_lamp != lamp_here:
			last_lamp = lamp_here
			GameState.set_checkpoint(lamp_here.global_position + Vector2(0, 10))
	elif cl:
		for b in get_tree().get_nodes_in_group("light_band"):
			if b.has_method("covers") and b.covers(blue.global_position):
				cl.refill(0.12)


# ------------------------------------------------------------------ QTE
## 紫手靠近时调：同一时间只有一个 QTE；她在光里 / 倒下 / 对话中时不触发。
## 两个 QTE 之间至少隔 QTE_GAP 秒（QTE 期间不能动：留一点时间让她挪一步）。
const QTE_GAP := 0.6
var _qte_free_at := 0.0


func request_qte(hand: MazeHand) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if KeySequenceQTE.is_running() or _qte_hand != null or not blue.is_alive() or light_at(blue.global_position) is Vector2 \
			or now < _qte_free_at:
		hand.cooldown(0.6)
		return
	_run_qte(hand)


func qte_params() -> Dictionary:
	var n := cover.total() if cover else 0
	var stage := laugh_stage()
	var count := clampi(2 + n / 4 + (1 if stage >= 2 else 0), 2, 5)
	var limit := clampf(2.4 - n * 0.06 - stage * 0.2, 1.2, 2.4)
	var cl := carry_light()
	var delay := 0.0
	if cl:
		delay = (1.0 - cl.brightness()) * 0.5
	return {"count": count, "limit": limit * (0.9 if delay > 0.3 else 1.0), "delay": delay}


func _run_qte(hand: MazeHand) -> void:
	_qte_hand = hand
	var prm := qte_params()
	var q := KeySequenceQTE.start(blue, int(prm["count"]), float(prm["limit"]), float(prm["delay"]))
	var ok: bool = await q.finished
	_qte_hand = null
	_qte_free_at = Time.get_ticks_msec() / 1000.0 + QTE_GAP
	if not is_instance_valid(hand) or hand.is_gone():
		return
	if ok:
		hand.vanish()
		return
	var zone := cover.pick_zone(marked_zone)
	if zone == "":
		hand.vanish()
		return
	hand.latch_onto(blue)
	cover_zone(zone)


## 在 zone 上盖一只手（QTE 失败、组合技「门后千手」、镜面水洼……）。
func cover_zone(zone: String) -> bool:
	if not cover.add(zone):
		return false
	blue.shake(0.25)
	Audio.play("grab", -4.0, 0.05, 1.2)
	if zone == marked_zone:
		marked_zone = ""
	return true


func _on_hands_changed(zone: String, n: int, _total: int) -> void:
	Dialogue.portrait_fx.cover_hands = cover.hands.duplicate()
	GameState.vars["f8m_hands"] = cover.hands.duplicate()
	if zone == "" or n <= 0:
		return
	var line := MazeLines.for_zone(zone, n)
	if line != "":
		GameState.princess_reacted.emit(line, 3.0)


func _on_milestone(id: String) -> void:
	GameState.set_flag("f8m_ms_" + id)
	CG.play_theater("f8_maze_" + id)


func _on_rhythm(state: String) -> void:
	Dialogue.portrait_fx.cover_charging = state == "charge"
	match state:
		"charge":
			if is_instance_valid(_rhythm_fx):
				_rhythm_fx.fade_out(0.1)
			_rhythm_fx = ScreenFx.vignette(Color(0.65, 0.2, 0.95), 0.55, true)
			GameState.princess_reacted.emit(MazeLines.pick("rhythm_charge"), 1.6)
		"hit", "miss":
			if is_instance_valid(_rhythm_fx):
				_rhythm_fx.fade_out(0.3)
			if state == "hit":
				ScreenFx.flash(Color(0.8, 0.4, 1.0), 0.25)
			GameState.princess_reacted.emit(MazeLines.pick("rhythm_" + state), 2.4)


func _on_magic(event: String, tier: int) -> void:
	if event != "burst" and event != "fatigue_burst":
		return
	var t := tier if event == "burst" else 3
	var r := float(IceBarrier.params(t).get("radius", 72.0))
	var time := float(IceBarrier.params(t).get("time", 2.0))
	for h in hands():
		if (h as Node2D).global_position.distance_to(blue.global_position) <= r + 8.0:
			(h as MazeHand).freeze(time)
	if t >= 3 and cover.shake_off(true) > 0:
		GameState.princess_reacted.emit(MazeLines.pick("shake_off"), 2.4)
	var cl := carry_light()
	if cl and event == "burst":
		cl.spend(0.1 * t)
	for n in get_tree().get_nodes_in_group("maze_magic_reactive"):
		if n.has_method("on_ice") and (n as Node2D).global_position.distance_to(blue.global_position) <= r + 8.0:
			n.on_ice(time)


# ------------------------------------------------------------------ 笑倒 → 回到上一盏灯
func _on_overflow() -> void:
	if not _busy and not _ended:
		_run_defeat()


func _on_down(c: PlayableCharacter) -> bool:
	if c != blue:
		return false
	_run_defeat()
	return true


func _run_defeat() -> void:
	if _busy:
		return
	_busy = true
	_defeats += 1
	if is_instance_valid(_rhythm_fx):
		_rhythm_fx.fade_out(0.2)
	await get_tree().create_timer(0.6).timeout
	await CG.play_theater("f8_maze_defeat_%d" % (1 + (_defeats - 1) % 2))
	cover.clear()
	marked_zone = ""
	for h in hands():
		(h as MazeHand).vanish()
	if last_lamp and not last_lamp.lit:
		last_lamp.relight()
	blue.respawn()
	var cl := carry_light()
	if cl:
		cl.level = maxf(cl.level, 0.6)
	_spawn_t = 4.0
	_busy = false


# ------------------------------------------------------------------ 出口（第三段）
func _run_ending() -> void:
	_ended = true
	_busy = true
	for h in hands():
		(h as MazeHand).vanish()
	if MemoryShard.collected() >= MemoryShard.TOTAL:
		await CG.play_theater("f8_maze_memory")
	GameState.set_flag("f8_maze_done")
	await Cutscene.play("f8_maze_exit")
	_busy = false


# ------------------------------------------------------------------ HUD：手 ×N、冷光条、回忆 n / 6
func _make_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 9
	add_child(_hud)
	var bg := ColorRect.new()
	bg.color = Color(0.25, 0.4, 0.6, 0.55)
	bg.position = Vector2(8, 74)
	bg.size = Vector2(80, 4)
	_hud.add_child(bg)
	_light_bar = ColorRect.new()
	_light_bar.color = Color(0.7, 0.9, 1.0)
	_light_bar.size = Vector2(80, 4)
	bg.add_child(_light_bar)
	_hud_label = Label.new()
	_hud_label.position = Vector2(8, 79)
	_hud_label.add_theme_font_size_override("font_size", 10)
	_hud_label.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0))
	_hud_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	_hud_label.add_theme_constant_override("outline_size", 3)
	_hud.add_child(_hud_label)


func _update_hud() -> void:
	if _hud == null:
		return
	_hud.visible = not CG.is_busy()
	var cl := carry_light()
	_light_bar.size.x = 80.0 * (cl.level if cl else 1.0)
	_light_bar.color = Color(0.7, 0.9, 1.0) if not (cl and cl.is_dimmed()) else Color(0.45, 0.5, 0.7)
	var n := cover.total() if cover else 0
	_hud_label.text = "冷光　手 ×%d　回忆 %d / 6" % [n, MemoryShard.collected()]

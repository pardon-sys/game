class_name SiegeDirector
extends Node2D
## 小镇攻防战的导演（图例 X = siege；地图 floor_06_siege，生成器 tools/build/gen_floor06_siege.py）。
## 数据：data/siege/waves.json（同一个生成器写）：
##   wall_hp 城墙总血量、prep_first / prep 准备秒数、alive_cap 同时在场上限、monsters {键: 场景}、
##   waves [{name, groups: [{monster, count, from, interval, delay}], reward, hazards, theater}]（10 波）
## 流程：准备（prep，可以造塔；号角提前开打）→ 战斗（按 groups 排队出怪，同时最多 alive_cap 只）→ 清完 → 奖励冰晶 → 下一波。
##   城墙总血量归零 → 失败：清场 → 放这一波的失败小剧场（data/theater/siege/siege_fail_<N>.json）→ 城墙修好、冰塔保留 → 从这一波的准备阶段重来。
##   10 波撑过 → 胜利（剧情标记 siege_won）→ 过场 siege_won（「（待续）」）→ 回战时小镇。
## 两位公主（Duo：C 键切换）：
##   粉色公主默认操控，地面近战；AI 时用 CompanionController（SiegeAIHooks：闷笑高时去薄荷冰泉、没事做时去最危险的那段墙下）。
##   蓝色公主在城墙顶走道（SiegeMageController：自动放法术；被挠下城墙后 10 秒走到梯子爬回去）。
##   镜头（SiegeCamera）：滚轮 / - / = 缩放（0.5~1.5 倍），V 切换整个战场的全景（暂停）。
##   玩家操控蓝色公主时按 1~4：瞄准施法（SpellAim，选点放 4 个城墙法术；L 仍是她自己的冰晶结界）。
##   倒下（death_override）：放笑倒 CG（按她自己的角色版本）；粉色公主在城门复活、城墙扣一点血；
##   蓝色公主倒在原地（Downed.timeless：不倒计时、不会自己起来），要粉色公主过去按住 E 救。
## 怪物：每只挂 SiegeMind（行军大脑；攻城怪自己的 make_mind() 给特别的大脑）。目标表 nearest_target 每次只查几个对象，不扫全场。
## 建塔：粉色公主按 B（siege_build）在脚下放冰塔基座（BuildPad，try_build / build_blocked），蓝色公主冰光造出来。
## 冰晶：打倒怪物 +1（大怪更多）、每波奖励；造塔 / 升级用（spend）。存在 GameState.vars（siege_wave / siege_crystals）。

signal state_changed(state: String)
signal wave_started(n: int)
signal wave_cleared(n: int)
signal wall_changed(hp: float, max_hp: float)
signal crystals_changed(n: int)
signal failed(n: int)
signal won

const WAVES_PATH := "res://data/siege/waves.json"
const TOTAL_WAVES := 10
## 粉色公主笑倒复活时城墙扣掉的比例
const DOWN_PENALTY := 0.05
## 蓝色公主被挠下城墙后，多久自己走去梯子爬回去
const FALLEN_TIME := 10.0
## 从敌塔地基出来的怪先在地基旁边转多久（聚集起来就会搭敌塔）
const SITE_HOLD := 14.0

static var current: SiegeDirector


## 怪物 / 敌塔特殊能力和陷阱的频率倍数（waves.json 的 ability_rate，默认 1）。
static func ability_rate() -> float:
	return float(current.data.get("ability_rate", 1.0)) if current else 1.0

var data := {}
var wave := 1
## prep / fight / failed / won
var state := ""
var prep_left := 0.0
var wall_hp := 2000.0
var wall_max := 2000.0
var crystals := 0
var walls: Array[SiegeWall] = []
var ladders: Array[Node2D] = []
var pink: PlayableCharacter
var blue: PlayableCharacter
var monsters: Array[Monster] = []
## 额外的目标（小雪人、诱饵冰雕……）：怪物的 nearest_target 也会考虑；元素可以带 lure 半径（诱饵）
var extra_targets: Array[Node2D] = []
var spawn_points := {}
var gate_pos := Vector2.ZERO
var hooks: SiegeAIHooks
var hud: SiegeHud
var intel: SiegeIntel
var cam: SiegeCamera
var aim: SpellAim
var teamwork: MonsterTeamwork
## 这一波还没出的怪：[{t, monster, from}]（t = 战斗开始后第几秒出）
var _queue: Array = []
## 这一波还没放的大范围陷阱：[{t, kind}]
var _hazards: Array = []
var _fight_t := 0.0
var _total_this_wave := 0
var _busy := false
## 打倒的怪（测试用）
var kills := 0


func _ready() -> void:
	current = self
	add_to_group("combo_effect_handler")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WAVES_PATH))
	data = parsed if parsed is Dictionary else {}
	wall_max = float(data.get("wall_hp", 2000.0))
	wall_hp = wall_max
	await get_tree().process_frame
	await get_tree().process_frame
	_setup()


func _exit_tree() -> void:
	if current == self:
		current = null
	if PlayableCharacter.death_override.is_valid() and PlayableCharacter.death_override.get_object() == self:
		PlayableCharacter.death_override = Callable()
	if PlayableCharacter.ai_factory.is_valid() and PlayableCharacter.ai_factory.get_object() == self:
		PlayableCharacter.ai_factory = Callable()
	PlayableCharacter.magic_override = Callable()
	PlayerInputController.movement_locked = false
	PlayerInputController.actions_locked = false
	Downed.timeless = false
	# 离开攻防战：两位公主的镜头恢复默认（倍数 1、跟着人）
	for c: PlayableCharacter in [pink, blue]:
		if c and is_instance_valid(c) and c.camera:
			c.camera.zoom = Vector2.ONE
			c.camera.top_level = false
			c.camera.position = Vector2.ZERO
	if Duo.director == self:
		Duo.stop()
	Equipment.clear_forced()


func level() -> Node:
	var n := get_parent()
	while n and not n.has_node("Walls"):
		n = n.get_parent()
	return n


## 地图大小（像素）：墙图层用到的范围。
var _map_size := Vector2.ZERO


func map_size() -> Vector2:
	if _map_size != Vector2.ZERO:
		return _map_size
	var lv := level()
	var walls_layer := lv.get_node_or_null("Walls") as TileMapLayer if lv else null
	if walls_layer == null:
		return Vector2(110, 80) * 16.0
	var r := walls_layer.get_used_rect()
	_map_size = Vector2(r.end) * 16.0
	return _map_size


func entities() -> Node:
	var lv := level()
	return lv.get_node_or_null("Entities") if lv else get_parent()


func _setup() -> void:
	var lv := level()
	for n in lv.find_children("*", "SiegeWall", true, false):
		var w := n as SiegeWall
		w.director = self
		walls.append(w)
	walls.sort_custom(func(a, b): return a.index < b.index)
	for n in get_tree().get_nodes_in_group("siege_ladder"):
		ladders.append(n)
	for n in lv.find_children("*", "SpawnPoint", true, false):
		var sid := str(n.get("id"))
		if sid == "gate":
			gate_pos = (n as Node2D).global_position
		elif sid.begins_with("siege_"):
			var from := sid.trim_prefix("siege_").get_slice("_", 0)
			if not spawn_points.has(from):
				spawn_points[from] = []
			spawn_points[from].append((n as Node2D).global_position)
	for n in lv.find_children("*", "PlayableCharacter", true, false):
		var c := n as PlayableCharacter
		if c.character_id == "blue":
			blue = c
		else:
			pink = c
	if blue and blue.has_method("start_following"):
		blue.start_following("")
		blue.follow = false
		blue.partner_talk = ""
	hooks = SiegeAIHooks.new(self)
	PlayableCharacter.ai_factory = _make_ai
	PlayableCharacter.death_override = _on_down
	Downed.timeless = true
	if pink and blue:
		if GameState.player != pink:
			GameState.switch_control(pink)
		Duo.start([pink, blue], self, hooks)
		blue.set_controller(_make_ai(blue))
	if gate_pos != Vector2.ZERO:
		GameState.set_checkpoint(gate_pos)
	hud = SiegeHud.new()
	hud.director = self
	add_child(hud)
	intel = SiegeIntel.new()
	add_child(intel)
	cam = SiegeCamera.new()
	cam.director = self
	add_child(cam)
	cam.setup(map_size())
	aim = SpellAim.new()
	aim.director = self
	add_child(aim)
	teamwork = MonsterTeamwork.new()
	teamwork.spawn_func = func(k: String, at: Vector2) -> Monster: return spawn(k, "", at)
	teamwork.monsters_func = func() -> Array: return monsters
	teamwork.triggered.connect(func(id: String, _at: Vector2):
		intel.discover("team_" + id)
		Audio.play("combo", -4.0, 0.05))
	add_child(teamwork)
	_restore_towers()
	_spawn_soldiers()
	wave = clampi(int(GameState.vars.get("siege_wave", 1)), 1, TOTAL_WAVES)
	crystals = int(GameState.vars.get("siege_crystals", int(data.get("start_crystals", 20))))
	crystals_changed.emit(crystals)
	wall_changed.emit(wall_hp, wall_max)
	_begin_prep()


func _make_ai(c: PlayableCharacter) -> CharacterController:
	if c.character_id == "blue":
		var m := SiegeMageController.new()
		m.director = self
		return m
	var cc := CompanionController.new()
	cc.behaviours.assign(["struggle", "dodge", "revive", "safe", "attack", "objective", "wander"])
	cc.hooks = hooks
	return cc


# ------------------------------------------------------------------ 流程
func wave_data(n := -1) -> Dictionary:
	var ws: Array = data.get("waves", [])
	var i := (wave if n < 0 else n) - 1
	return ws[i] if i >= 0 and i < ws.size() else {}


func _set_state(s: String) -> void:
	state = s
	state_changed.emit(s)


func _begin_prep() -> void:
	prep_left = float(data.get("prep_first", 30.0)) if wave == 1 else float(data.get("prep", 20.0))
	GameState.vars["siege_wave"] = wave
	GameState.vars["siege_crystals"] = crystals
	_set_state("prep")
	GameState.notify("第 %d 波：%s——准备时间 %d 秒" % [wave, str(wave_data().get("name", "")), int(prep_left)])


## 提前开打（号角）。
func start_now() -> void:
	if state == "prep":
		prep_left = 0.0


func _begin_fight() -> void:
	_queue.clear()
	_fight_t = 0.0
	for g in wave_data().get("groups", []):
		var n := int(g.get("count", 1))
		var iv := float(g.get("interval", 1.0))
		var delay := float(g.get("delay", 0.0))
		for i in n:
			if g.has("formation"):
				_queue.append({"t": delay + i * iv, "formation": str(g["formation"]), "from": str(g.get("from", "bottom"))})
			else:
				_queue.append({"t": delay + i * iv, "monster": str(g.get("monster", "slime")), "from": str(g.get("from", "bottom"))})
	_queue.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	_total_this_wave = _queue.size()
	_hazards = (wave_data().get("hazards", []) as Array).duplicate(true)
	_hazards.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	_set_state("fight")
	Audio.play("siege_horn", -1.0)
	GameState.hint("第 %d 波来了！" % wave)
	wave_started.emit(wave)


## 临时痒痒装备：另一位公主靠近按住 E HELP_TIME 秒帮忙解开（{角色 id: 已经按了几秒}）
const HELP_TIME := 2.0
const HELP_RANGE := 24.0
var _help := {}


func _help_unequip(delta: float) -> void:
	for c: PlayableCharacter in [pink, blue]:
		if c == null or not is_instance_valid(c) or Equipment.forced_items(c.character_id).is_empty():
			_help.erase(c.character_id if c else "")
			continue
		var other: PlayableCharacter = blue if c == pink else pink
		var helping := other != null and is_instance_valid(other) and other.is_alive() and not Downed.is_downed(other) \
			and other.global_position.distance_to(c.global_position) <= HELP_RANGE and other.controller != null \
			and other.controller.is_action_pressed(&"interact")
		if not helping:
			_help.erase(c.character_id)
			continue
		if not _help.has(c.character_id):
			SpeechBubble.say(other, "我来帮你解开！" if other == pink else "……别动。解开。", 28.0, 1.2)
		_help[c.character_id] = float(_help.get(c.character_id, 0.0)) + delta
		if float(_help[c.character_id]) >= HELP_TIME:
			_help.erase(c.character_id)
			Equipment.release(c.character_id)
			Fx.burst(c.get_parent(), c.global_position + Vector2(0, -10), "heart", 6, 30.0, 0.5, Vector2(0, -10), Color(1, 0.8, 0.9))
			Audio.play("cloth", -4.0)
			SpeechBubble.say(c, "解开了……谢谢！" if c == pink else "……谢谢。", 28.0, 1.4)


func help_progress(who: String) -> float:
	return float(_help.get(who, 0.0)) / HELP_TIME


func _process(delta: float) -> void:
	if not (_busy or state == "" or GameState.in_dialogue or CG.is_busy() or GameState.in_cutscene):
		_help_unequip(delta)
	if _busy or state == "" or GameState.in_dialogue or CG.is_busy() or GameState.in_cutscene:
		return
	match state:
		"prep":
			prep_left -= delta
			if prep_left <= 0.0:
				_begin_fight()
		"fight":
			_fight_t += delta
			monsters = monsters.filter(func(m): return is_instance_valid(m) and m.is_alive())
			# 场上不设上限（alive_cap 写了才限制）
			var cap := int(data.get("alive_cap", 1 << 30))
			while not _queue.is_empty() and float(_queue[0]["t"]) <= _fight_t and monsters.size() < cap:
				var q: Dictionary = _queue.pop_front()
				if q.has("formation"):
					teamwork.spawn_formation(str(q["formation"]), spawn_pos(str(q["from"])))
				else:
					spawn(str(q["monster"]), str(q["from"]))
			while not _hazards.is_empty() and float(_hazards[0]["t"]) <= _fight_t:
				var hz: Dictionary = _hazards.pop_front()
				if hz.has("combo"):
					spawn_hazard_combo(str(hz["combo"]))
				else:
					spawn_hazard(str(hz["kind"]))
			if _queue.is_empty() and monsters.is_empty():
				_clear_wave()


func remaining() -> int:
	return _queue.size() + monsters.size()


func _clear_wave() -> void:
	var reward := int(wave_data().get("reward", 10))
	add_crystals(reward)
	wave_cleared.emit(wave)
	Audio.play("chime", -2.0, 0.0, 1.1)
	if wave >= TOTAL_WAVES:
		_win()
		return
	GameState.notify("第 %d 波挡住了！冰晶 +%d" % [wave, reward])
	wave += 1
	_begin_prep()


# ------------------------------------------------------------------ 出怪
func monster_scene(key: String) -> String:
	return str(data.get("monsters", {}).get(key, ""))


func spawn(key: String, from := "bottom", at = null) -> Monster:
	var path := monster_scene(key)
	if path == "" or not ResourceLoader.exists(path):
		push_warning("攻防战：没有这种怪 " + key)
		return null
	var m := load(path).instantiate() as Monster
	if m == null:
		return null
	var site: Node2D = null
	if from == "site" and not (at is Vector2):
		var sites := get_tree().get_nodes_in_group("siege_enemy_site")
		if not sites.is_empty():
			site = sites.pick_random()
	var pos: Vector2 = at if at is Vector2 else (site.global_position + Vector2(randf_range(-30, 30), randf_range(-20, 20)) if site else spawn_pos(from))
	entities().add_child(m)
	m.global_position = pos
	# 攻防战里怪物之间不互相挡（几百只同时在场时省物理计算）
	m.collision_mask = 1 if m.collision_mask != 0 else 0
	m.add_buff("siege_rapid", 99999.0)
	_speed_up_specials(m)
	m.mind = m.call("make_mind", self) if m.has_method("make_mind") else SiegeMind.new(self)
	if site and m.mind is SiegeMind:
		(m.mind as SiegeMind).hold(site.global_position, SITE_HOLD)
	m.set_home(pos, 9999.0)
	m.died.connect(_on_monster_died)
	monsters.append(m)
	intel.discover(key)
	if from == "hole":
		Fx.burst(m.get_parent(), pos, "dust", 8, 40.0, 0.5, Vector2(0, 40), Color(0.6, 0.5, 0.4))
	return m


## 放一个大范围陷阱（位置按种类挑：龙卷风 / 迷雾 / 符文在战场上靠近粉色公主，城墙爬藤在蓝色公主那段墙下，扫帚在走道上……）。
func spawn_hazard(kind: String, at: Variant = null) -> SiegeHazard:
	var h := SiegeHazard.make(kind)
	if h == null:
		return null
	var pos: Vector2 = at if at is Vector2 else _hazard_pos(kind)
	h.position = pos
	entities().add_child(h)
	h.global_position = pos
	intel.discover("hazard_" + kind)
	return h


func _hazard_pos(kind: String) -> Vector2:
	var ms := map_size()
	var field_top := wall_foot_y() + 60.0
	var near := pink.global_position if pink and is_instance_valid(pink) else Vector2(ms.x / 2.0, ms.y / 2.0)
	match kind:
		"wall_vine":
			var bx := blue.global_position.x if blue and is_instance_valid(blue) else gate_pos.x
			return Vector2(bx + randf_range(-30, 30), wall_foot_y())
		"broom":
			return Vector2(0, wall_top_y())
		"bubbles":
			return Vector2(ms.x / 2.0, clampf(near.y, field_top + 60.0, ms.y - 120.0))
		"sticky_net":
			return near
	var p := near + Vector2(randf_range(-90, 90), randf_range(-60, 60))
	return Vector2(clampf(p.x, 60.0, ms.x - 60.0), clampf(p.y, field_top, ms.y - 60.0))


## 怪物特殊能力的间隔按 ability_rate 缩短（翻滚、吐泡泡、舌头、吐丝、召唤、再扑上来……；抓住后的挠痒节奏不动）。
const SPECIAL_PROPS := ["roll_cooldown", "shot_cooldown", "brush_cooldown", "combo_cooldown", "switch_cooldown", "tongue_cooldown",
	"web_cooldown", "relatch_delay", "summon_interval", "puddle_interval", "strike_interval"]


func _speed_up_specials(m: Monster) -> void:
	var r := ability_rate()
	if r <= 1.0:
		return
	for prop in SPECIAL_PROPS:
		var v: Variant = m.get(prop)
		if v is float:
			m.set(prop, float(v) / r)


## 陷阱组合（成套出现）：bubble_broom 泡泡扫帚 / double_tornado 双龙卷 / fog_tornado 迷雾龙卷 / net_link 黏网连线。
const HAZARD_COMBOS := {"bubble_broom": ["泡泡扫帚", "#9fd8ff"], "double_tornado": ["双龙卷", "#e0b0ff"],
	"fog_tornado": ["迷雾龙卷", "#ffb0d8"], "net_link": ["黏网连线", "#ffd0f0"]}


func spawn_hazard_combo(kind: String) -> Array:
	var made: Array = []
	var near := pink.global_position if pink and is_instance_valid(pink) else gate_pos + Vector2(0, 200)
	var c := _hazard_pos("tornado")
	match kind:
		"bubble_broom":
			made.append(spawn_hazard("bubbles"))
			made.append(spawn_hazard("broom"))
		"double_tornado":
			for i in 2:
				# 一里一外两圈、方向相反：不会叠成一个，甩出去容易落进另一个的路上
				var t := spawn_hazard("tornado", c + Vector2(60.0 if i == 0 else -110.0, 0)) as HazardTornado
				if t:
					t.orbit_center = c
					t.orbit_dir = 1.0 if i == 0 else -1.0
					made.append(t)
		"fog_tornado":
			var f := spawn_hazard("fog", c) as HazardFog
			var t2 := spawn_hazard("tornado", c) as HazardTornado
			if t2:
				t2.hidden_in = f
			made += [f, t2]
		"net_link":
			made.append(spawn_hazard("link_rune", near + Vector2(10, 0)))
			var wr: WeakRef = weakref(self)
			get_tree().create_timer(1.0).timeout.connect(func():
				var d2 := wr.get_ref() as SiegeDirector
				if d2 and d2.state == "fight":
					d2.spawn_hazard("sticky_net"))
	var info: Array = HAZARD_COMBOS.get(kind, [kind, "#ffffff"])
	teamwork.announce(str(info[0]), c, Color(str(info[1])), "陷阱组合：")
	intel.discover("hzcombo_" + kind)
	return made


## 这个位置在痒痒迷雾里吗（蓝色公主看不见、支援不了）。
func in_fog(pos: Vector2) -> bool:
	for h in get_tree().get_nodes_in_group("siege_hazard"):
		if h is HazardFog and (h as HazardFog).covers(pos):
			return true
	return false


func spawn_pos(from: String) -> Vector2:
	var pts: Array = spawn_points.get(from, spawn_points.get("bottom", []))
	if pts.is_empty():
		return Vector2(gate_pos.x, gate_pos.y + 600.0)
	var p: Vector2 = pts.pick_random()
	return p + Vector2(randf_range(-10, 10), randf_range(-6, 6))


func _on_monster_died(a: Actor) -> void:
	kills += 1
	var m := a as Monster
	var gain := 1
	if m and m.stats and m.stats.max_hp >= 8:
		gain = 3
	add_crystals(gain, a.global_position)


func add_crystals(n: int, at = null) -> void:
	crystals += n
	crystals_changed.emit(crystals)
	if at is Vector2:
		var l := Label.new()
		l.text = "+%d" % n
		l.add_theme_color_override("font_color", Color(0.7, 0.92, 1.0))
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.35))
		l.add_theme_constant_override("outline_size", 3)
		l.add_theme_font_size_override("font_size", 8)
		l.z_index = 20
		entities().add_child(l)
		l.global_position = (at as Vector2) + Vector2(-6, -24)
		var tw := l.create_tween().set_parallel()
		tw.tween_property(l, "position:y", l.position.y - 12.0, 0.7)
		tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
		tw.chain().tween_callback(l.queue_free)


func spend(n: int) -> bool:
	if crystals < n:
		return false
	crystals -= n
	crystals_changed.emit(crystals)
	return true


# ------------------------------------------------------------------ 城墙
func damage_wall(_seg: SiegeWall, amount: float) -> void:
	if state == "failed" or state == "won":
		return
	wall_hp = maxf(0.0, wall_hp - amount)
	wall_changed.emit(wall_hp, wall_max)
	if wall_hp <= 0.0 and not _busy:
		_fail()


func repair_wall(_seg: SiegeWall, amount: float) -> void:
	wall_hp = minf(wall_max, wall_hp + amount)
	wall_changed.emit(wall_hp, wall_max)


func wall_foot_y() -> float:
	return walls[0].foot_y() if not walls.is_empty() else 0.0


func wall_top_y() -> float:
	return walls[0].top_y() if not walls.is_empty() else 0.0


func segment_at(x: float) -> SiegeWall:
	var best: SiegeWall = null
	var best_d := INF
	for w in walls:
		var d := 0.0 if x >= w.left_x() and x <= w.right_x() else minf(absf(x - w.left_x()), absf(x - w.right_x()))
		if d < best_d:
			best_d = d
			best = w
	return best


## 这段墙下有多少怪（蓝色公主的 AI 用来挑最危险的那段）。
func threat(w: SiegeWall) -> int:
	var n := 0
	var foot := w.foot_y()
	for m in monsters:
		if is_instance_valid(m) and m.global_position.x >= w.left_x() - 8.0 and m.global_position.x <= w.right_x() + 8.0 \
				and m.global_position.y < foot + 120.0:
			n += 1
	return n


func hottest_wall() -> SiegeWall:
	var best: SiegeWall = null
	var best_n := -1
	for w in walls:
		var n := threat(w)
		if n > best_n:
			best_n = n
			best = w
	return best


func is_on_wall(c: Node2D) -> bool:
	return c.global_position.y < wall_foot_y() - 20.0


# ------------------------------------------------------------------ 敌塔相关
## 蓝色公主（在城墙上）是不是在魔力干扰塔的范围里。
func silenced(c: PlayableCharacter) -> bool:
	for t in get_tree().get_nodes_in_group("siege_enemy_tower"):
		if t.get("kind") == "silence" and t.has_method("silences") and t.silences(c):
			return true
	return false


## 要蓝色公主去救的粉色公主：被拖走（藤蔓拉拽塔 / 搬运小鬼 → 冰链）或被黏网罩住（→ 探出城垛割网）。
func rescue_request() -> Variant:
	if pink and is_instance_valid(pink) and (pink.get_meta("siege_dragged", false) or pink.get_meta("siege_netted", false)) \
			and not in_fog(pink.global_position):
		return pink
	return null


## 救援要付出的时间（秒）：冰链拉住 / 探出城垛割网，期间蓝色公主动不了、被挠。
const RESCUE_TIME := 3.0
const NET_REACH := 40.0
## 冰链能拉多远（从城墙上一直够到敌方区域）
const CHAIN_RANGE := 1100.0
var rescuing := false
var _rescue_line: Line2D


## 蓝色公主开始救援（AI 自动调；玩家操控时在城墙上按 E）。返回是否开始了（条件不满足返回 false）。
func rescue(b: PlayableCharacter) -> bool:
	if rescuing or b == null or not is_on_wall(b) or Downed.is_downed(b) or rescue_request() == null:
		return false
	var netted: bool = pink.get_meta("siege_netted", false)
	if netted and absf(b.global_position.x - pink.global_position.x) > NET_REACH:
		return false
	if not netted and b.global_position.distance_to(pink.global_position) > CHAIN_RANGE:
		return false
	_rescue_seq(b, netted)
	return true


func _rescue_seq(b: PlayableCharacter, netted: bool) -> void:
	rescuing = true
	b.set_meta("siege_beaming", true)
	if b.is_controlled():
		PlayerInputController.movement_locked = true
	pink.set_meta("siege_chained", true)
	_rescue_line = Line2D.new()
	_rescue_line.width = 2.0
	_rescue_line.default_color = Color(0.75, 0.93, 1.0) if not netted else Color(0.9, 0.97, 1.0)
	_rescue_line.z_index = 30
	_rescue_line.add_to_group("siege_temp")
	entities().add_child(_rescue_line)
	_rescue_line.global_position = Vector2.ZERO
	SpeechBubble.say(b, "……抓住。……冰链。" if not netted else "……我、我探出去……割网。", 28.0, 1.6)
	Audio.play("chant", -4.0, 0.0, 1.2)
	# 墙上的怪趁机挠她（探出城垛时大腿和屁股露在外面）
	if enemies_near(b.global_position, 60.0).filter(func(m): return m is SiegeMonster and (m as SiegeMonster).on_wall).size() < 2:
		for i in 2:
			var g: Monster = spawn("gecko", "", Vector2(b.global_position.x + (40.0 if i == 0 else -40.0), wall_top_y() + 2.0))
			if g is SiegeMonster:
				(g as SiegeMonster).on_wall = true
				g.collision_mask = 0
	var t := 0.0
	var tick := 0.0
	var ok := true
	while t < RESCUE_TIME:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		if CG.is_busy() or GameState.in_dialogue:
			continue
		t += dt
		tick -= dt
		if not is_instance_valid(b) or not is_instance_valid(pink) or not is_on_wall(b) or Downed.is_downed(b) or state != "fight":
			ok = false
			break
		_rescue_line.points = PackedVector2Array([b.global_position + Vector2(0, -12), pink.global_position + Vector2(0, -10)])
		if tick <= 0.0:
			tick = 0.45
			var src: Node = null
			for m in enemies_near(b.global_position, 60.0):
				src = m
				break
			var h := HitData.make_tickle(src if src else self, 5.0)
			h.zone = ["thigh", "butt"].pick_random() if netted else ["armpit", "waist", "thigh"].pick_random()
			b.receive_hit(h)
	if is_instance_valid(_rescue_line):
		_rescue_line.queue_free()
	if is_instance_valid(b):
		b.set_meta("siege_beaming", false)
		if b.is_controlled():
			PlayerInputController.movement_locked = false
	if is_instance_valid(pink):
		pink.set_meta("siege_chained", false)
	rescuing = false
	if not ok or not is_instance_valid(pink):
		return
	if netted:
		for h in get_tree().get_nodes_in_group("siege_hazard"):
			if h is HazardStickyNet and (h as HazardStickyNet).caught == pink:
				(h as HazardStickyNet).free_caught()
		SpeechBubble.say(pink, "网破了！谢谢你——！", 28.0, 1.6)
	else:
		var dragger: Variant = pink.get_meta("siege_dragger") if pink.has_meta("siege_dragger") else null
		if dragger is Node and is_instance_valid(dragger) and dragger.has_method("release_drag"):
			dragger.release_drag()
		var tw := pink.create_tween()
		tw.tween_property(pink, "global_position", pink.global_position.move_toward(Vector2(pink.global_position.x, wall_foot_y() + 40.0), 50.0), 0.4)
		SpeechBubble.say(pink, "被拉回来了！", 28.0, 1.4)
	Audio.play("chime", -2.0, 0.0, 1.5)


# ------------------------------------------------------------------ 三来源组合的攻防战效果（ComboTracker 交给 combo_effect_handler）
##   siege_lockup  直接被运进最近的敌塔里关着挠（被抬走的印记）
##   siege_knockoff 被挠下城墙（扫帚下的城墙）
##   siege_fx      专属特效 {kind: vortex / brush_flowers / heart_fluff / mark_trail / purple_hands / feather_storm / bell_ripple / wind_lines}
func on_combo_effect(e: Dictionary, who: Actor, _source: Node) -> void:
	var c := who as PlayableCharacter
	if c == null:
		return
	match str(e.get("type", "")):
		"siege_lockup":
			lock_up(c)
		"siege_knockoff":
			knock_off(c, "组合")
		"siege_fx":
			SiegeFx.combo_fx(c, str(e.get("kind", "")))


## 把人关进最近的敌塔里挠 time 秒再扔出来（搬运小鬼、被抬走的印记）。
const LOCK_TIME := 8.0


func lock_up(c: PlayableCharacter, at: Variant = null, sec := LOCK_TIME) -> void:
	if c == null or not is_instance_valid(c) or not c.visible:
		return
	var pos: Vector2 = at if at is Vector2 else c.global_position
	if not (at is Vector2):
		var best: Node2D = null
		for t in get_tree().get_nodes_in_group("siege_enemy_tower"):
			if best == null or (t as Node2D).global_position.distance_to(c.global_position) < best.global_position.distance_to(c.global_position):
				best = t
		if best:
			pos = best.global_position + Vector2(0, 8)
	c.visible = false
	c.set_physics_process(false)
	c.global_position = pos
	GameState.notify("%s被关进敌塔里了……" % c.display_name())
	var tw := c.create_tween().set_loops(int(sec / 0.5))
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		if is_instance_valid(c):
			c.receive_hit(HitData.make_tickle(self, 3.0))
			Fx.burst(c.get_parent(), pos + Vector2(0, -16), "feather", 3, 30.0, 0.4, Vector2(0, -10)))
	get_tree().create_timer(sec).timeout.connect(func():
		if is_instance_valid(c):
			c.visible = true
			c.set_physics_process(true)
			c.global_position = pos + Vector2(0, 24)
			c.apply_knockback(pos, 200.0)
			SpeechBubble.say(c, "呼……哈……被、被扔出来了……" if c.character_id == "pink" else "……出、出来了……哈……", 28.0, 2.0))


# ------------------------------------------------------------------ 造塔
const BUILD_GAP := 32.0
const BUILD_MARGIN := 24.0
const BUILD_FROM_WALL := 30.0


## 粉色公主按 B：站在已有冰塔旁边 → 升级 / 拆掉；否则在脚下放一个冰塔基座、选塔。
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("siege_build") or state == "" or _busy or GameState.in_dialogue or get_tree().paused:
		return
	var p := GameState.player
	if p == null or p != pink:
		if p == blue:
			GameState.notify("建塔要粉色公主来：先按 C 换过去")
		return
	get_viewport().set_input_as_handled()
	try_build(pink, pink.global_position)


## 在这里建（或者打开旁边那座塔的菜单）。返回基座（不能建返回 null，并提示原因）。
func try_build(c: PlayableCharacter, at: Vector2) -> BuildPad:
	for pd in get_tree().get_nodes_in_group("siege_pad"):
		if (pd as Node2D).global_position.distance_to(at) < 18.0:
			(pd as BuildPad).on_pink(c)
			return pd
	var why := build_blocked(at)
	if why != "":
		GameState.notify("这里不能建：" + why)
		Audio.play("locked", -6.0)
		return null
	var pad := BuildPad.new()
	entities().add_child(pad)
	pad.global_position = at.snapped(Vector2(4, 4))
	pad.on_pink.call_deferred(c)
	return pad


## 不能建的原因（"" = 能建）：城墙上 / 太靠近城墙、离别的冰塔或敌塔地基不到 2 格、地图边上。
func build_blocked(at: Vector2) -> String:
	var ms := map_size()
	if at.x < BUILD_MARGIN or at.x > ms.x - BUILD_MARGIN or at.y > ms.y - BUILD_MARGIN:
		return "太靠边了"
	if at.y < wall_foot_y() + BUILD_FROM_WALL:
		return "城墙上 / 离城墙太近"
	for g in ["siege_pad", "siege_tower", "siege_enemy_site", "siege_enemy_tower"]:
		for n in get_tree().get_nodes_in_group(g):
			if (n as Node2D).global_position.distance_to(at) < BUILD_GAP:
				return "离别的塔太近"
	return ""


## 读存档里的冰塔（[{x, y, kind, level}]）。
func _restore_towers() -> void:
	var saved: Variant = GameState.vars.get("siege_towers", [])
	if not saved is Array:
		return
	for t in saved:
		if not t is Dictionary:
			continue
		var pad := BuildPad.new()
		entities().add_child(pad)
		pad.global_position = Vector2(float(t["x"]), float(t["y"]))
		pad._build.call_deferred(str(t["kind"]), int(t["level"]), true)


## 正在等蓝色公主冰光的冰塔格（第一个；没有返回 null）。
func build_request() -> Variant:
	for pad in get_tree().get_nodes_in_group("siege_pad"):
		if pad.has_method("waiting") and pad.waiting():
			return pad
	return null


# ------------------------------------------------------------------ 目标 / 查询
## 怪物要找的最近目标：两位公主（在墙下 / 地面上的）+ 额外目标（小雪人、诱饵冰雕：lure 半径内优先）。
func nearest_target(m: Monster, max_range: float) -> Actor:
	var best: Actor = null
	var best_d := max_range * max_range
	for c: PlayableCharacter in [pink, blue]:
		if c == null or not is_instance_valid(c) or not c.is_alive() or Downed.is_downed(c) or is_on_wall(c):
			continue
		var d := m.global_position.distance_squared_to(c.global_position)
		# 痒痒印记臀贴：怪物优先找她（相当于近了一大截）
		if Equipment.has_special(c.character_id, "mark"):
			d *= 0.35
		if d < best_d:
			best_d = d
			best = c
	for t in extra_targets:
		if not is_instance_valid(t) or not (t is Actor) or not (t as Actor).is_alive():
			continue
		var lure := float(t.get("lure")) if t.get("lure") != null else 0.0
		var d := m.global_position.distance_squared_to(t.global_position)
		if lure > 0.0 and d < lure * lure:
			return t
		if d < best_d:
			best_d = d
			best = t
	return best


func enemies_near(pos: Vector2, r: float, include_fog := true) -> Array[Monster]:
	var out: Array[Monster] = []
	var r2 := r * r
	for m in monsters:
		if is_instance_valid(m) and m.is_alive() and m.global_position.distance_squared_to(pos) <= r2:
			if not include_fog and m.get_meta("in_fog", false):
				continue
			out.append(m)
	return out


## 怪最密的地方（半径 r 内最多的那只怪的位置；没有怪返回 null）。
func densest(r := 40.0, near = null, within := INF) -> Variant:
	var best: Variant = null
	var best_n := 0
	var step := maxi(1, monsters.size() / 30)
	for i in range(0, monsters.size(), step):
		var m := monsters[i]
		if not is_instance_valid(m):
			continue
		if near is Vector2 and m.global_position.distance_to(near) > within:
			continue
		var n := enemies_near(m.global_position, r).size()
		if n > best_n:
			best_n = n
			best = m.global_position
	return best


func on_screen(pos: Vector2, margin := 48.0) -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return true
	var half := get_viewport_rect().size / cam.zoom / 2.0 + Vector2(margin, margin)
	var c := cam.get_screen_center_position()
	return absf(pos.x - c.x) <= half.x and absf(pos.y - c.y) <= half.y


func nearest_ladder(pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for l in ladders:
		var d := absf(l.global_position.x - pos.x)
		if d < best_d:
			best_d = d
			best = l
	return best


# ------------------------------------------------------------------ 蓝色公主被挠下城墙
## 震下 / 推下城墙：从走道落到墙下（x 附近），坐着笑一阵；FALLEN_TIME 秒后 AI 自己走去梯子爬回去。
func knock_off(c: PlayableCharacter, cause := "") -> void:
	if c == null or not is_on_wall(c) or c.get_meta("siege_falling", false):
		return
	c.set_meta("siege_falling", true)
	c.set_meta("siege_fallen_at", Time.get_ticks_msec() / 1000.0)
	var to := Vector2(c.global_position.x, wall_foot_y() + 22.0)
	c.set_physics_process(false)
	var tw := c.create_tween()
	tw.tween_property(c, "global_position", c.global_position + Vector2(0, -10), 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "global_position", to, 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		c.set_physics_process(true)
		c.set_meta("siege_falling", false)
		c.shake(0.4)
		Fx.burst(c.get_parent(), c.global_position, "dust", 10, 40.0, 0.5, Vector2(0, 20))
		Audio.play("pop", -4.0, 0.1, 0.7)
		if c.laugh:
			c.laugh.add(c.laugh.max_value * 0.2)
		SpeechBubble.say(c, "……掉、掉下来了。" if c.character_id == "blue" else "呀——！", 28.0))
	if cause != "":
		GameState.notify("%s被%s挠下了城墙！" % [c.display_name(), cause])


func fallen_for(c: PlayableCharacter) -> float:
	if is_on_wall(c):
		return 0.0
	return Time.get_ticks_msec() / 1000.0 - float(c.get_meta("siege_fallen_at", Time.get_ticks_msec() / 1000.0))


# ------------------------------------------------------------------ 倒下
func _on_down(c: PlayableCharacter) -> bool:
	if c != pink and c != blue:
		return false
	_down_seq(c)
	return true


func _down_seq(c: PlayableCharacter) -> void:
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(c):
		return
	var key := ""
	if c.is_laugh_defeat() and c.has_method("defeat_source_key"):
		key = str(c.call("defeat_source_key"))
	if key != "" and state != "failed":
		Characters.scope(c.character_id)
		await CG.play_death(key)
		Characters.unscope()
	if not is_instance_valid(c):
		return
	if c == blue:
		# 倒在原地：友军士兵过来把她抬上城墙复活；没人来的话 BLUE_REVIVE 秒后自己起来；粉色公主也能按住 E 救
		var dn := Downed.start(c)
		dn.revive_after = BLUE_REVIVE
		call_bearers(c)
		return
	GameState.set_checkpoint(gate_pos)
	c.respawn()
	if state == "fight":
		damage_wall(segment_at(gate_pos.x), wall_max * DOWN_PENALTY)
		GameState.notify("%s在城门口醒过来了……城墙被趁机打了一顿" % c.display_name())


func on_defeat(_reason: String) -> void:
	pass


# ------------------------------------------------------------------ 友军士兵
const SPEARMEN := 6
const ARCHERS := 4
## 蓝色公主没人来抬时，多久自己复活
const BLUE_REVIVE := 40.0
var soldiers: Array[SiegeSoldier] = []


func _spawn_soldiers() -> void:
	if walls.is_empty():
		return
	var ms := map_size()
	for i in SPEARMEN:
		var s := SiegeSoldier.new()
		s.role = "spear"
		s.director = self
		entities().add_child(s)
		s.global_position = Vector2(ms.x * (i + 0.5) / SPEARMEN, wall_foot_y() + 26.0)
		s.post = s.global_position
		soldiers.append(s)
		extra_targets.append(s)
	for i in ARCHERS:
		var a := SiegeSoldier.new()
		a.role = "archer"
		a.director = self
		entities().add_child(a)
		a.global_position = Vector2(ms.x * (i + 0.5) / ARCHERS + 30.0, wall_top_y() - 10.0)
		a.post = a.global_position
		soldiers.append(a)


## 叫士兵来抬倒下的蓝色公主（墙下：两个长矛兵；墙顶：一个弓箭手）。返回派了几个。
func call_bearers(b: PlayableCharacter) -> int:
	var role := "archer" if is_on_wall(b) else "spear"
	var need := 1 if role == "archer" else 2
	var pool := soldiers.filter(func(s): return is_instance_valid(s) and s.role == role and s.available())
	pool.sort_custom(func(x, y): return x.global_position.distance_to(b.global_position) < y.global_position.distance_to(b.global_position))
	var picked := pool.slice(0, need)
	for i in picked.size():
		var partner: SiegeSoldier = picked[1 - i] if picked.size() == 2 else null
		(picked[i] as SiegeSoldier).assign_carry(b, partner)
	if not picked.is_empty():
		GameState.notify("士兵们赶去救蓝色的公主！")
	return picked.size()


## 蓝色公主复活（士兵抬上城墙 / 扶起来）。
func revive_blue(b: PlayableCharacter, msg := "") -> void:
	var dn := b.get_node_or_null("Downed") as Downed
	if dn:
		dn.revive_now()
	if not is_on_wall(b):
		b.global_position = Vector2(b.global_position.x, wall_top_y() + 4.0)
	if b.laugh:
		b.laugh.set_value(0.0)
	b.set_meta("siege_carried", false)
	if msg != "":
		GameState.notify(msg)


# ------------------------------------------------------------------ 失败 / 胜利
func _fail() -> void:
	if _busy:
		return
	_busy = true
	_set_state("failed")
	failed.emit(wave)
	Audio.play("lose_fanfare", -1.0)
	GameState.hint("城墙被攻破了……")
	await get_tree().create_timer(1.2).timeout
	clear_field()
	var tid := "siege_fail_%d" % wave
	# 蓝色公主穿着千手痒痒裤时用她那几句换成裤子的版本
	if GameState.has_flag(Equipment.PANTS_FLAG) and CG.has_theater(tid + "_pants"):
		tid += "_pants"
	if CG.has_theater(tid):
		await CG.play_theater(tid)
	reset_after_fail()
	_busy = false
	_begin_prep()
	GameState.notify("重新挑战第 %d 波" % wave)


## 清场：怪物、陷阱、敌塔里关着的人……全部收掉；临时装备解开。
func clear_field() -> void:
	for m in monsters:
		if is_instance_valid(m):
			m.queue_free()
	monsters.clear()
	_queue.clear()
	_hazards.clear()
	for n in get_tree().get_nodes_in_group("siege_temp"):
		if n.has_method("_end"):
			n.call("_end")
		n.queue_free()
	for c: PlayableCharacter in [pink, blue]:
		if c and is_instance_valid(c):
			for k in ["siege_dragged", "siege_netted", "siege_bubbled", "siege_chained"]:
				c.set_meta(k, false)
			if c.status:
				c.status.release(true)
				c.status.clear_root()
			c.visible = true
	Equipment.clear_forced()


## 士兵全部下场 / 回岗（测试和以后的剧情用）。
func bench_soldiers(benched: bool) -> void:
	for s in soldiers:
		if not is_instance_valid(s):
			continue
		s.reset_post()
		s.retreating = benched
		s.visible = not benched


func reset_after_fail() -> void:
	wall_hp = wall_max
	for w in walls:
		w.taken = 0.0
		w.shield_left = 0.0
		w.queue_redraw()
	wall_changed.emit(wall_hp, wall_max)
	for c: PlayableCharacter in [pink, blue]:
		if c == null or not is_instance_valid(c):
			continue
		var d := c.get_node_or_null("Downed")
		if d:
			d.queue_free()
		if not c.is_alive() or c.state == PlayableCharacter.State.DEAD:
			c.revive()
			c._set_state(PlayableCharacter.State.IDLE)
		if c.laugh:
			c.laugh.set_value(0.0)
		c.set_meta("siege_falling", false)
		c.set_physics_process(true)
		if c.sprite:
			c.sprite.modulate.a = 1.0
	for s in soldiers:
		if is_instance_valid(s):
			s.reset_post()
	if pink:
		pink.global_position = gate_pos
	if blue and not walls.is_empty():
		blue.global_position = Vector2(gate_pos.x + 16.0, wall_top_y() + 4.0)


func _win() -> void:
	_busy = true
	_set_state("won")
	GameState.set_flag("siege_won")
	GameState.vars.erase("siege_wave")
	won.emit()
	Audio.play("win_fanfare", -1.0)
	await get_tree().create_timer(1.0).timeout
	if FileAccess.file_exists(Cutscene.DIR + "floor_06/siege_won.json"):
		Cutscene.play("siege_won")
	else:
		GameState.hint("小镇守住了！（待续）")


## 暂停菜单的「撤退」：回战时小镇（这一波从准备阶段重来）。
func retreat() -> void:
	clear_field()
	GameState.vars["siege_wave"] = wave
	GameState.vars["siege_crystals"] = crystals
	GameState.pending_spawn = "from_siege"
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("change_level"):
		main.change_level(Floors.scene("floor_06_war"))

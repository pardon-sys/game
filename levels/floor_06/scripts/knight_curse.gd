class_name KnightCurse
extends Node2D
## 骑士 Boss 的「诅咒爆发」和「盯上镇民」（TaskKnightBoss 挂一个，advance 里 tick；台词 data/after/knight_finale.json 的 boss.surge / hunt）。
##   诅咒爆发：铁手套 / 护腿 / 胸甲阶段，开始 SURGE_DELAY 秒后一次、这一阶段的耐久掉到一半一次。爆发期间部件打不动（invulnerable）；
##     周身一圈诅咒（SURGE_R）：站在里面闷笑每秒 +SURGE_LAUGH；有人在里面（被吸着笑声）就每 DRAIN_EVERY 秒给部件回 1 点耐久（持续吸、持续回）。
##     破解（每个阶段不同）：
##       hands 铁手套「手印风暴」：三只手印飞到三个镇民身上（surge_victims）——三个人都救下来（按住 E / 蓝色公主冻）。
##       veins 护腿「痒波地脉」：地上冒出紫色的地脉（VEINS 个，站上去闷笑涨），镇民搬来三根木桩（STAKES，木箱的样子换成木桩）；
##             粉色公主在 LURE_R 以内按住 Y 故意笑 → 盔甲朝她冲撞（冷却 LURE_COOL），躲开让它撞上木桩，撞断 STAKE_HITS 根。
##       heart 胸甲「护心诅咒」：两颗诅咒核心（cores）绕着胸口转，粉色公主贴在身边时转得慢；蓝色公主 J 冻住一颗（冻 CORE_WINDOW 秒），两颗同时冻着 = 破。
##     破了：诅咒散开、骑士露出破绽（open_weak）。
##   笑面阶段的「吸笑」（drain）：有灯笼亮了以后每 MASK_DRAIN_EVERY 秒一次，持续 MASK_DRAIN_TIME 秒——全场的笑声往它身上吸：
##     不站在亮着的灯笼光里（LIGHT_SAFE_R）闷笑每秒 +MASK_DRAIN_LAUGH，没亮的灯笼每秒 −MASK_DRAIN_LANTERN；这段时间灯笼不长进度。
##   盯上镇民（hunt）：没在爆发的时候每 HUNT_EVERY 秒盯上一个镇民（吓得缩在原地，头上紫色的「！」），盔甲朝他走；
##     走到了（HUNT_STEAL_R）：偷走他的笑声，部件回 HUNT_HEAL 点耐久（笑面阶段：没亮的灯笼掉进度）；
##     粉色公主在 LURE_R 以内按住 Y 笑 → 盔甲回头冲她来（引开）；HUNT_GIVEUP 秒没走到也放弃。
## 测试：surge、start()、end()、stakes、stake_hits、cores、freeze_cores()、hunt、start_hunt()、lure()、invulnerable()、surge_victims。

const SURGE_R := 70.0
const SURGE_LAUGH := 0.25
const DRAIN_EVERY := 1.5
const SURGE_DELAY := 2.5
const VEINS := 5
const VEIN_R := 18.0
const VEIN_LAUGH := 0.1
const STAKES := [Vector2(-76, 10), Vector2(76, 2), Vector2(0, 72)]
const STAKE_HITS := 3
const LURE_R := 150.0
const LURE_COOL := 2.5
const CORE_ORBIT := 30.0
const CORE_SPEED := 2.4
const CORE_WINDOW := 3.0
const CORE_FREEZE_R := 20.0
const MASK_DRAIN_EVERY := 14.0
const MASK_DRAIN_TIME := 4.0
const MASK_DRAIN_LAUGH := 0.12
const MASK_DRAIN_LANTERN := 0.05
const LIGHT_SAFE_R := 34.0
const HUNT_EVERY := 12.0
const HUNT_FIRST := 8.0
const HUNT_STEAL_R := 22.0
const HUNT_HEAL := 2
const HUNT_GIVEUP := 12.0
const KINDS := ["hands", "veins", "heart", "drain"]
## 测试：关掉自动爆发 / 自动盯镇民（专门的用例自己调 start() / start_hunt()）
static var auto := true

var task: TaskKnightBoss
var surge := ""
## 这一阶段爆发过几次（开始一次、半血一次）
var surges := 0
var surge_victims: Array = []
var stakes: Array = []
var stake_hits := 0
var veins: Array = []
var cores: Array = []
var mask_t := MASK_DRAIN_EVERY
var mask_left := 0.0
var hunt: Node2D
var hunt_left := 0.0
var hunt_t := HUNT_FIRST
var _start_t := SURGE_DELAY
var _drain_t := DRAIN_EVERY
var _lure_cool := 0.0
var _aura: KnightFx
var _drain_fx := {}
var _t := 0.0


static func text() -> Dictionary:
	return TaskKnightBoss.data().get("surge", {})


func _ready() -> void:
	z_index = 3


func phase_started(_p: int) -> void:
	end(true)
	surges = 0
	_start_t = SURGE_DELAY
	mask_t = MASK_DRAIN_EVERY
	_end_hunt()
	hunt_t = HUNT_FIRST


## 部件现在打不动（爆发中）
func invulnerable() -> bool:
	return surge in ["hands", "veins", "heart"]


func tick(delta: float) -> void:
	_t += delta
	_lure_cool = maxf(0.0, _lure_cool - delta)
	queue_redraw()
	if surge == "":
		_maybe_start(delta)
	else:
		_tick_surge(delta)
	_tick_hunt(delta)


func _maybe_start(delta: float) -> void:
	if not auto:
		return
	if task.phase >= TaskKnightBoss.PHASES - 1:
		if task.lanterns.any(func(l): return is_instance_valid(l) and l.lit):
			mask_t -= delta
			if mask_t <= 0.0:
				start()
		return
	if surges == 0:
		_start_t -= delta
		if _start_t <= 0.0:
			start()
	elif surges == 1 and task.phase_hp_ratio() <= 0.5:
		start()


## 爆发（测试也直接调）
func start() -> void:
	if surge != "":
		return
	surge = KINDS[mini(task.phase, KINDS.size() - 1)]
	surges += 1
	_drain_t = DRAIN_EVERY
	_end_hunt()
	var tx: Dictionary = text().get(surge, {})
	# 第一次：演介绍过场；之后只冒一句旁白
	if not TaskKnightBoss.intro("surge_" + surge):
		GameState.princess_reacted.emit(str(tx.get("start", "")), 3.4)
	task._shake(0.4, 3.0)
	Audio.play("rumble", -4.0)
	if surge != "drain":
		_aura = KnightFx.play(task.get_parent(), "curse_burst", task._body.global_position + Vector2(0, -16), {"size": SURGE_R * 2.2, "loop": true, "fps": 10.0, "color": Color(1.2, 1.0, 1.3, 0.95), "z": 3})
	match surge:
		"hands":
			surge_victims.clear()
			var free: Array = task.victims.filter(func(x): return is_instance_valid(x) and not x.cursed)
			free.shuffle()
			for v in free.slice(0, 3):
				task.curse_victim(v)
				surge_victims.append(v)
				KnightFx.play(task.get_parent(), "trap_land", v.global_position, {"size": 36.0, "z": 0})
		"veins":
			stake_hits = 0
			for o in STAKES:
				var st := KnightBossFx.Crate.new()
				st.stake = true
				task.get_parent().add_child(st)
				st.global_position = task._home + (o as Vector2)
				task.crates.append(st)
				stakes.append(st)
			for i in VEINS:
				var at := task._home + Vector2.from_angle(TAU * i / VEINS + 0.4) * randf_range(40.0, 90.0)
				var n := task._danger_circle(at, VEIN_R)
				n.set_meta("vein", true)
				veins.append(n)
		"heart":
			cores = [{"a": 0.0, "frozen": 0.0}, {"a": PI, "frozen": 0.0}]
		"drain":
			mask_left = MASK_DRAIN_TIME


## 破解 / 吸完（quiet：换阶段时直接收掉，不演）
func end(quiet := false) -> void:
	if surge == "":
		return
	var was := surge
	surge = ""
	if is_instance_valid(_aura):
		_aura.queue_free()
	_aura = null
	for f in _drain_fx.values():
		if is_instance_valid(f):
			(f as Node).queue_free()
	_drain_fx.clear()
	for st in stakes:
		if is_instance_valid(st):
			task.crates.erase(st)
			(st as Node).queue_free()
	stakes.clear()
	for n in veins:
		if is_instance_valid(n):
			(n as Node).queue_free()
	veins.clear()
	cores.clear()
	surge_victims.clear()
	if was == "drain":
		mask_t = MASK_DRAIN_EVERY
	if quiet:
		return
	var tx: Dictionary = text().get(was, {})
	GameState.princess_reacted.emit(str(tx.get("end", "")), 3.0)
	if was != "drain":
		KnightFx.play(task.get_parent(), "purify", task._body.global_position + Vector2(0, -20), {"size": 96.0})
		Audio.play("star_burst", -4.0)
		task.open_weak(Vector2(0, -6))


func _tick_surge(delta: float) -> void:
	var body := task._body.global_position
	if is_instance_valid(_aura):
		_aura.global_position = body + Vector2(0, -16)
	# 被吸着笑声的人：爆发圈里的（笑面：不站在亮灯笼光里的）
	var drained: Array = []
	for c in task._players():
		var hit := false
		if surge == "drain":
			hit = not _in_light(c)
			if hit and c.laugh:
				KnightTickle.over(c, MASK_DRAIN_LAUGH, delta, task._body, "drain")
		elif c.global_position.distance_to(body) <= SURGE_R:
			hit = true
			if c.laugh:
				KnightTickle.over(c, SURGE_LAUGH, delta, task._body, "surge")
		if hit:
			drained.append(c)
		_drain_line(c, hit)
	if not drained.is_empty():
		_drain_t -= delta
		if _drain_t <= 0.0:
			_drain_t = DRAIN_EVERY
			heal(1)
	match surge:
		"hands":
			if surge_victims.all(func(v): return not is_instance_valid(v) or not v.cursed):
				end()
		"veins":
			for n in veins:
				if not is_instance_valid(n):
					continue
				for c in task._players():
					if c.global_position.distance_to((n as Node2D).global_position) <= VEIN_R and c.laugh:
						KnightTickle.over(c, VEIN_LAUGH, delta, task._body, "vein", "sole")
			# 粉色公主按住 Y 笑（AI 粉色公主走近了就笑）→ 引它冲过来
			var ai_pink := task.pink != GameState.player and task.ai_enabled and task.pink.global_position.distance_to(task._body.global_position) <= LURE_R
			if (task.pink == GameState.player and KnightLaugh.tick(task.pink, delta)) or ai_pink:
				lure()
			var left := stakes.filter(func(s): return is_instance_valid(s) and not s.broken).size()
			stake_hits = STAKES.size() - left
			if stake_hits >= STAKE_HITS:
				end()
		"heart":
			var slow := 0.5 if task._pink_near() else 1.0
			for c in cores:
				c["frozen"] = maxf(0.0, float(c["frozen"]) - delta)
				if float(c["frozen"]) <= 0.0:
					c["a"] = float(c["a"]) + CORE_SPEED * slow * delta
			if not cores.is_empty() and cores.all(func(c): return float(c["frozen"]) > 0.0):
				end()
		"drain":
			for l in task.lanterns:
				if is_instance_valid(l) and not l.lit:
					l.progress = maxf(0.0, l.progress - MASK_DRAIN_LANTERN * delta)
			mask_left -= delta
			if mask_left <= 0.0:
				end()


## 在亮着的灯笼光里（笑面吸笑的时候安全）
func _in_light(c: Node2D) -> bool:
	return task.lights().any(func(l): return l.global_position.distance_to(c.global_position) <= LIGHT_SAFE_R)


## 吸笑声的光带（从被吸的人飘到盔甲身上）
func _drain_line(c: PlayableCharacter, on: bool) -> void:
	var f: Variant = _drain_fx.get(c)
	if not on:
		if is_instance_valid(f):
			(f as Node).queue_free()
		_drain_fx.erase(c)
		return
	var from := c.global_position + Vector2(0, -12)
	var to := task._body.global_position + Vector2(0, -24)
	if not is_instance_valid(f):
		f = KnightFx.play(task.get_parent(), "laugh_drain", from, {"size": 56.0, "loop": true, "fps": 12.0, "z": 4})
		_drain_fx[c] = f
	if is_instance_valid(f):
		var fx := f as KnightFx
		fx.global_position = from.lerp(to, 0.5)
		fx.rotation = (to - from).angle()
		var k := clampf(from.distance_to(to) / 56.0, 0.4, 3.0)
		fx.scale = Vector2(k, 0.8) * (56.0 / (fx.texture.get_width() / KnightFx.FRAMES))


## 吸到笑声：部件回耐久（笑面阶段：没亮的灯笼掉进度）
func heal(n: int) -> void:
	if task.phase >= TaskKnightBoss.PHASES - 1:
		for l in task.lanterns:
			if is_instance_valid(l) and not l.lit:
				l.progress = maxf(0.0, l.progress - 0.08 * n)
		return
	for i in n:
		var best: TaskKnightBoss.BossPart = null
		for p in task.parts:
			if is_instance_valid(p) and not p.broken and p.hp < TaskKnightBoss.PART_HP and (best == null or p.hp < best.hp):
				best = p
		if best:
			best.hp += 1
			best.flash = 0.2
	SpeechBubble.say(task._body, str((text().get("heal", ["……笑……声……"]) as Array).pick_random()), 46.0, 1.0)


## 粉色公主笑着引它：盔甲回头冲她（地脉阶段冲撞，平时把盯着的镇民放掉）
func lure() -> bool:
	if _lure_cool > 0.0 or not is_instance_valid(task.pink):
		return false
	if task.pink.global_position.distance_to(task._body.global_position) > LURE_R:
		return false
	_lure_cool = LURE_COOL
	if is_instance_valid(hunt):
		_end_hunt()
		hunt_t = HUNT_EVERY
		SpeechBubble.say(task._body, str((TaskKnightBoss.data().get("hunt", {}).get("lured", ["……殿……下……"]) as Array).pick_random()), 46.0, 1.4)
	if surge == "veins" and task.warn.is_empty() and task.charge_left <= 0.0 and task.stuck_left <= 0.0 and task.leap_left <= 0.0:
		task.body_mode = "walk"
		task.windup_left = 0.0
		task.charge(task.pink)
	return true


## 帮手（小孩们）替她把盔甲引开：不看距离，盯着的镇民放掉
func lure_by(who: Node2D) -> bool:
	if not is_instance_valid(hunt):
		return false
	_end_hunt()
	hunt_t = HUNT_EVERY
	SpeechBubble.say(task._body, str((TaskKnightBoss.data().get("hunt", {}).get("lured", ["……"]) as Array).pick_random()), 46.0, 1.4)
	return true


## 蓝色公主 J：冻住身边的诅咒核心（TaskKnightBoss.freeze_part 先问这里）
func freeze_cores(who: PlayableCharacter) -> bool:
	if surge != "heart":
		return false
	var hit := false
	for c in cores:
		if core_pos(c).distance_to(who.global_position) <= CORE_FREEZE_R:
			c["frozen"] = CORE_WINDOW
			hit = true
	if hit:
		Fx.burst(task.get_parent(), task._body.global_position + Vector2(0, -20), "drop", 10, 30.0, 0.4, Vector2(0, -10), Color(0.8, 0.95, 1.0))
	return hit


## 冰晶结界：范围里的心核都冻住
func freeze_cores_at(center: Vector2, r: float) -> void:
	if surge != "heart":
		return
	for c in cores:
		if core_pos(c).distance_to(center) <= r:
			c["frozen"] = CORE_WINDOW


func core_pos(c: Dictionary) -> Vector2:
	return task._body.global_position + Vector2(0, -22) + Vector2.from_angle(float(c["a"])) * Vector2(CORE_ORBIT, CORE_ORBIT * 0.6)


# ------------------------------------------------------------------ 盯上镇民
func _tick_hunt(delta: float) -> void:
	if task.finale or task.transitioning:
		return
	if is_instance_valid(hunt):
		hunt_left -= delta
		if task.pink == GameState.player and surge != "veins" and KnightLaugh.pressed() and KnightLaugh.tick(task.pink, delta):
			lure()
			return
		if task._body.global_position.distance_to(hunt.global_position) <= HUNT_STEAL_R:
			_steal()
		elif hunt_left <= 0.0:
			_end_hunt()
			hunt_t = HUNT_EVERY
		return
	if surge != "" or not auto:
		return
	hunt_t -= delta
	if hunt_t <= 0.0:
		start_hunt()


## 盯上一个镇民（测试也直接调）
func start_hunt(v: Node2D = null) -> Node2D:
	if v == null:
		var pool: Array = task.victims.filter(func(x): return is_instance_valid(x) and not x.cursed and x.kind != "fallen")
		if pool.is_empty():
			hunt_t = HUNT_EVERY
			return null
		v = pool.pick_random()
	hunt = v
	hunt.set("hunted", true)
	hunt_left = HUNT_GIVEUP
	var tx: Dictionary = TaskKnightBoss.data().get("hunt", {})
	SpeechBubble.say(task._body, str((tx.get("bark", ["……笑……声……"]) as Array).pick_random()), 46.0, 1.4)
	if not TaskKnightBoss.intro("hunt"):
		GameState.princess_reacted.emit(str(tx.get("warn", "")), 2.6)
	return hunt


func _steal() -> void:
	var v := hunt
	_end_hunt()
	hunt_t = HUNT_EVERY
	var tx: Dictionary = TaskKnightBoss.data().get("hunt", {})
	SpeechBubble.say(v, str((tx.get("victim", ["哈……笑、笑不出来了……"]) as Array).pick_random()), 30.0, 1.8)
	GameState.princess_reacted.emit(str(tx.get("stolen", "")), 2.6)
	var f := KnightFx.play(task.get_parent(), "laugh_drain", v.global_position.lerp(task._body.global_position, 0.5) + Vector2(0, -16),
		{"size": 56.0, "rot": (task._body.global_position - v.global_position).angle()})
	if f:
		f.scale.x *= clampf(v.global_position.distance_to(task._body.global_position) / 56.0, 0.4, 2.0)
	heal(HUNT_HEAL)


func _end_hunt() -> void:
	if is_instance_valid(hunt):
		hunt.set("hunted", false)
	hunt = null


func _draw() -> void:
	if not is_instance_valid(task) or not is_instance_valid(task._body):
		return
	# 胸口的两颗诅咒核心
	for c in cores:
		var p := to_local(core_pos(c))
		var frozen := float(c["frozen"]) > 0.0
		var col := Color(0.75, 0.92, 1.0) if frozen else Color(0.75, 0.3, 1.0)
		draw_circle(p, 7.0, Color(col, 0.25))
		draw_circle(p, 4.0, col)
		draw_circle(p + Vector2(-1, -1), 1.5, Color(1, 1, 1, 0.8))
		if frozen:
			draw_arc(p, 8.0, -PI / 2, -PI / 2 + TAU * float(c["frozen"]) / CORE_WINDOW, 16, Color(0.8, 0.95, 1.0), 1.5)
	# 被盯上的镇民头上的紫色「！」
	if is_instance_valid(hunt):
		var h := to_local(hunt.global_position) + Vector2(0, -44 + sin(_t * 8.0) * 2.0)
		draw_rect(Rect2(h + Vector2(-1.5, -8), Vector2(3, 7)), Color(0.85, 0.35, 1.0))
		draw_rect(Rect2(h + Vector2(-1.5, 1), Vector2(3, 3)), Color(0.85, 0.35, 1.0))
	# 笑面吸笑：亮着的灯笼脚下一圈安全的光
	if surge == "drain":
		for l in task.lights():
			draw_circle(to_local(l.global_position), LIGHT_SAFE_R, Color(1, 0.85, 0.45, 0.18 + 0.06 * sin(_t * 6.0)))
			draw_arc(to_local(l.global_position), LIGHT_SAFE_R, 0, TAU, 32, Color(1, 0.9, 0.55, 0.8), 1.5)

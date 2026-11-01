class_name KnightHelpers
extends Node2D
## 骑士 Boss 场上的帮手（TaskKnightBoss 开场时挂一个，advance 里 tick）：做完哪个支线，那个人从第一阶段起就在场上帮忙（KnightQuests.helpers()）。
##   shoes   小汤姆、小莉莉（FieldHelper）：在掩体之间跑；盔甲盯上镇民时每个阶段一次替她笑着把它引开（KnightCurse.lure_by）；
##           跑去帮着扒被手印贴着的镇民（救人 ×KID_RESCUE，TaskKnightBoss._tick_victims 问 kid_near）。
##   samples 药剂师奶奶：站在场边（GRANNY_AT）；谁的闷笑过 MINT_AT 就扔一颗薄荷糖（−MINT，冷却 MINT_COOL）；点着安神香，烟（Smoke）慢慢飘，烟里的小手变慢。
##   spear   队长：跟着粉色公主；每 BLOCK_EVERY 秒替她挡一次扑抓 / 冲撞（task.shield）；冻住的部件他也上去打（每 CAP_HIT_EVERY 秒 1 点）。
##   fence   工匠：每个阶段打 STAKES_PER_PHASE 根木桩（Crate.stake，冲撞撞上就卡住）；痒波地脉多扛一根；每 REPAIR_EVERY 秒修好一个被撞碎的木箱。
##   host    派对主人：可操作角色（bonfire_host 场景），C 键切不到她（meta no_switch）；KnightAI（HOST_BEHAVIOURS：挣扎、躲预警、放庆典光环、
##           任务、主动攻击——彩带打冻住 / 露出破绽的部件）。她也是骑士的攻击目标（TaskKnightBoss._players），被抓 / 穿上诅咒装备自己挣；
##           被抓不算 Boss 战失败；笑倒了坐地笑 HOST_DOWN 秒再起来（meta on_down，不放笑倒 CG）。庆典光环照原描述双方加成。
##           每 MUSIC_EVERY 秒放一次八音盒：全场小手停住（冻 MUSIC_FREEZE 秒）、骑士出招慢一拍。
##   blue    （蓝色公主本来就在）旧石灯笼：从开场就亮着的第五盏灯（old_lantern，躲进光里安全、小手进来就化）；她的冻结范围 ×BLUE_REACH。
##   最后阶段（灯笼）开始时，①～④ 的人跑去自己那盏灯笼下陪着笑（原来的 KnightBossFx.Helper），场上的这几个收走。
## 测试：present、field、granny_mint_cool、captain_cool、music_t、old_lantern、mint(角色)、music()、plant_stakes()、kid_near(位置)。

const KID_RESCUE := 2.0
const GRANNY_AT := Vector2(-150, 60)
const MINT_AT := 0.7
const MINT := 0.15
const MINT_COOL := 20.0
const SMOKE_R := 40.0
const BLOCK_EVERY := 25.0
const CAP_HIT_EVERY := 2.0
const CAP_REACH := 70.0
const STAKES_PER_PHASE := 2
const REPAIR_EVERY := 15.0
const MUSIC_EVERY := 25.0
const MUSIC_FREEZE := 4.0
const BLUE_REACH := 1.3
const OLD_LANTERN_AT := Vector2(0, 112)
const LURE_COOL := 6.0
## 派对主人的 AI：比公主多一个放魔法；笑倒了坐地笑几秒再起来
const HOST_BEHAVIOURS: Array[String] = ["struggle", "dodge", "magic", "task", "attack", "follow"]
const HOST_DOWN := 6.0

var task: TaskKnightBoss
var present: Array = []
var field := {}
var host: PlayableCharacter
var old_lantern: KnightBossFx.Lantern
var smoke: Node2D
var granny_mint_cool := 0.0
var captain_cool := 0.0
var _cap_hit := CAP_HIT_EVERY
var _repair := REPAIR_EVERY
var music_t := MUSIC_EVERY * 0.6
var _kid_lured_phase := -1
var _stakes: Array = []


static func text() -> Dictionary:
	return TaskKnightBoss.data().get("field_helpers", {})


func setup() -> void:
	present = KnightQuests.helpers()
	var home := task._home
	if present.has("shoes"):
		field["tom"] = _spawn("kid", home + Vector2(-60, 90), "shoes")
		field["lily"] = _spawn("kid", home + Vector2(60, 90), "shoes")
	if present.has("samples"):
		field["granny"] = _spawn("pharmacist", home + GRANNY_AT, "samples")
		field["granny"].roam = false
		smoke = Smoke.new()
		task.get_parent().add_child(smoke)
		smoke.global_position = home + GRANNY_AT + Vector2(20, -10)
		smoke.set_meta("home", home)
	if present.has("spear"):
		field["captain"] = _spawn("captain", home + Vector2(-30, 120), "spear")
		field["captain"].follow = task.pink
		task.shield = maxi(task.shield, 1)
	if present.has("fence"):
		field["engineer"] = _spawn("miner", home + Vector2(150, 60), "fence")
	if present.has("host"):
		_spawn_host(home + Vector2(30, 120))
	if present.has("blue"):
		old_lantern = KnightBossFx.Lantern.new()
		old_lantern.index = 4
		old_lantern.lit = true
		old_lantern.progress = 1.0
		task.get_parent().add_child(old_lantern)
		old_lantern.global_position = home + OLD_LANTERN_AT
	phase_started(task.phase)
	# 登场：每个人喊一句
	var lines: Dictionary = text().get("arrive", {})
	for k in field:
		var q := str(field[k].get_meta("quest", ""))
		if lines.has(q):
			SpeechBubble.say(field[k], str(lines[q]), 30.0, 2.4)


func _spawn(sheet: String, at: Vector2, quest: String) -> FieldHelper:
	var h := FieldHelper.new()
	h.sheet = load("res://assets/generated/npcs/%s.png" % sheet)
	h.task = task
	h.set_meta("quest", quest)
	task.get_parent().add_child(h)
	h.global_position = at
	return h


func _spawn_host(at: Vector2) -> void:
	var scn := load("res://scenes/actors/playable/bonfire_host.tscn") as PackedScene
	if scn == null:
		return
	host = scn.instantiate() as PlayableCharacter
	host.set("ai", false)
	host.set("show_flag", "")
	task.get_parent().add_child(host)
	host.global_position = at
	host.set_faction(Faction.Type.ALLY)
	host.set_meta(&"no_switch", true)
	host.set_meta(&"on_down", _host_down)
	var ai := KnightAI.new()
	ai.plan = task.ai_plan
	ai.hooks = task._ai_hooks
	ai.behaviours.assign(HOST_BEHAVIOURS)
	host.set_controller(ai)
	field["host"] = host
	host.set_meta("quest", "host")


## 派对主人笑倒：坐地笑 HOST_DOWN 秒，闷笑清零、满血起来（不放笑倒 CG、不算失败）
func _host_down(c: PlayableCharacter) -> bool:
	SpeechBubble.say(c, "哈哈哈……让、让我缓一下……！", 30.0, 2.0)
	get_tree().create_timer(HOST_DOWN).timeout.connect(func():
		if is_instance_valid(c):
			c.revive()
			if c.laugh:
				c.laugh.set_value(0.0)
			c.set_invulnerable(1.5, true)
			c._set_state(PlayableCharacter.State.IDLE))
	return true


func cleanup() -> void:
	for k in field:
		if is_instance_valid(field[k]):
			(field[k] as Node).queue_free()
	for n in [smoke, old_lantern]:
		if is_instance_valid(n):
			(n as Node).queue_free()
	for s in _stakes:
		if is_instance_valid(s):
			task.crates.erase(s)
			(s as Node).queue_free()


## 最后阶段开始：①～④ 的人跑去灯笼下（原来的 Helper 接手），场上的这几个收走
func to_lanterns() -> void:
	for k in ["tom", "lily", "granny", "captain", "engineer"]:
		if field.has(k) and is_instance_valid(field[k]):
			(field[k] as Node).queue_free()
			field.erase(k)


## 换阶段：工匠打新的木桩、小孩们又能引一次
func phase_started(_p: int) -> void:
	if present.has("fence") and _p < TaskKnightBoss.PHASES - 1:
		plant_stakes(STAKES_PER_PHASE)


## 工匠打木桩（冲撞撞上就卡住）
func plant_stakes(n: int) -> int:
	var spots := TaskKnightBoss.COVERS.duplicate()
	spots.shuffle()
	var made := 0
	for o in spots:
		if made >= n:
			break
		var at: Vector2 = task._home + (o as Vector2) + Vector2(0, 14)
		if task.crates.any(func(c): return is_instance_valid(c) and c.global_position.distance_to(at) < 20.0):
			continue
		var st := KnightBossFx.Crate.new()
		st.stake = true
		task.get_parent().add_child(st)
		st.global_position = at
		task.crates.append(st)
		_stakes.append(st)
		made += 1
	if made > 0 and field.has("engineer") and is_instance_valid(field["engineer"]):
		SpeechBubble.say(field["engineer"], str((text().get("stake", ["木桩！"]) as Array).pick_random()), 30.0, 1.6)
	return made


## 有没有小孩在这个位置附近（救人 ×KID_RESCUE）
func kid_near(at: Vector2) -> bool:
	for k in ["tom", "lily"]:
		if field.has(k) and is_instance_valid(field[k]) and (field[k] as Node2D).global_position.distance_to(at) <= 30.0:
			return true
	return false


## 奶奶扔一颗薄荷糖
func mint(c: PlayableCharacter) -> bool:
	if granny_mint_cool > 0.0 or not c.laugh:
		return false
	granny_mint_cool = MINT_COOL
	c.laugh.set_value(maxf(0.0, c.laugh.value - c.laugh.max_value * MINT))
	if field.has("granny") and is_instance_valid(field["granny"]):
		SpeechBubble.say(field["granny"], str((text().get("mint", ["接着！"]) as Array).pick_random()), 30.0, 1.6)
	Audio.play("pickup", -6.0)
	return true


## 派对主人的八音盒：全场小手停住、骑士慢一拍
func music() -> void:
	music_t = MUSIC_EVERY
	for h in task.hands:
		if is_instance_valid(h) and h.state != "gone":
			(h as CurseHand).freeze(MUSIC_FREEZE)
	task.attack_t += 1.5
	if is_instance_valid(host):
		SpeechBubble.say(host, str((text().get("music", ["♪"]) as Array).pick_random()), 30.0, 2.0)
	Audio.play("music_box", -6.0)


func tick(delta: float) -> void:
	granny_mint_cool = maxf(0.0, granny_mint_cool - delta)
	# 奶奶：薄荷糖、安神香的烟
	if present.has("samples") and field.has("granny"):
		for c in task._players():
			if c.laugh and c.laugh.ratio() >= MINT_AT and mint(c):
				break
		if is_instance_valid(smoke):
			for h in task.hands:
				if is_instance_valid(h):
					(h as CurseHand).speed_mult = 0.5 if h.global_position.distance_to(smoke.global_position) <= SMOKE_R else 1.0
	# 小孩们：盔甲盯上镇民 → 每个阶段一次替她引开
	if present.has("shoes") and is_instance_valid(task.curse) and is_instance_valid(task.curse.hunt) and _kid_lured_phase != task.phase:
		_kid_lured_phase = task.phase
		var kid: Node2D = field.get("tom") if field.has("tom") else null
		if task.curse.lure_by(kid):
			SpeechBubble.say(kid, str((text().get("kid_lure", ["这边这边！哈哈哈！"]) as Array).pick_random()), 30.0, 1.8)
	# 队长：挡一次、打冻住的部件
	if present.has("spear") and field.has("captain") and is_instance_valid(field["captain"]):
		if task.shield <= 0:
			captain_cool -= delta
			if captain_cool <= 0.0:
				captain_cool = BLOCK_EVERY
				task.shield = 1
		_cap_hit -= delta
		if _cap_hit <= 0.0:
			_cap_hit = CAP_HIT_EVERY
			var cap: Node2D = field["captain"]
			for part in task.parts:
				if is_instance_valid(part) and not part.broken and part.freeze_left > 0.0 and part.global_position.distance_to(cap.global_position) <= CAP_REACH:
					if task.hit_part(part):
						SpeechBubble.say(cap, "……哼。", 30.0, 0.8)
					break
	# 工匠：修木箱
	if present.has("fence"):
		_repair -= delta
		if _repair <= 0.0:
			_repair = REPAIR_EVERY
			for o in TaskKnightBoss.CRATES:
				var at: Vector2 = task._home + (o as Vector2)
				if not task.crates.any(func(c): return is_instance_valid(c) and c.global_position.distance_to(at) < 4.0):
					var c := KnightBossFx.Crate.new()
					task.get_parent().add_child(c)
					c.global_position = at
					task.crates.append(c)
					if field.has("engineer") and is_instance_valid(field["engineer"]):
						SpeechBubble.say(field["engineer"], str((text().get("repair", ["修好了！"]) as Array).pick_random()), 30.0, 1.4)
					break
	# 派对主人：八音盒
	if present.has("host") and is_instance_valid(host):
		music_t -= delta
		if music_t <= 0.0:
			music()


## 场上跑来跑去的帮手（小孩、奶奶、队长、工匠）：在掩体之间走；follow 给了就跟着那个人
class FieldHelper extends Node2D:
	var sheet: Texture2D
	var task: TaskKnightBoss
	var roam := true
	var follow: Node2D
	var _goal := Vector2.INF
	var _t := 0.0
	var _dir := 0

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if GameState.in_cutscene or not is_instance_valid(task):
			return
		if is_instance_valid(follow):
			var want := follow.global_position + Vector2(-22, 10)
			if global_position.distance_to(want) > 18.0:
				_step(want, delta)
			return
		if not roam:
			return
		if _goal == Vector2.INF or global_position.distance_to(_goal) < 2.0:
			_goal = task._home + (TaskKnightBoss.COVERS.pick_random() as Vector2)
		_step(_goal, delta)

	func _step(to: Vector2, delta: float) -> void:
		var d := to - global_position
		_dir = 1 if absf(d.x) > absf(d.y) and d.x < 0 else (2 if absf(d.x) > absf(d.y) else (3 if d.y < 0 else 0))
		global_position = global_position.move_toward(to, 52.0 * delta)

	func _draw() -> void:
		if sheet == null:
			return
		var col := int(_t * 7.0) % 4
		draw_texture_rect_region(sheet, Rect2(-16, -28, 32, 32), Rect2(col * 32, _dir * 32, 32, 32))


## 安神香的烟：一团淡紫色的烟，绕着广场中间慢慢飘
class Smoke extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		z_index = 3
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = mat

	func _process(delta: float) -> void:
		_t += delta
		var home: Vector2 = get_meta("home", global_position)
		global_position = home + Vector2(cos(_t * 0.25) * 90.0, sin(_t * 0.25) * 50.0)
		queue_redraw()

	func _draw() -> void:
		for i in 6:
			var o := Vector2.from_angle(i * TAU / 6.0 + _t * 0.4) * 16.0
			draw_circle(o, 14.0 + sin(_t * 2.0 + i) * 2.0, Color(0.85, 0.78, 0.95, 0.12))

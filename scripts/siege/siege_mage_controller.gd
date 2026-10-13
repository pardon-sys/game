class_name SiegeMageController
extends CompanionController
## 攻防战里蓝色公主的 AI（没被玩家操控时；SiegeDirector 的 ai_factory 给她）。
## 继承 Boss 战的通用 AI（CompanionController）：挣扎（被抓 / 失控 / 身上挂着怪：连按）、闪避（danger 组的预警：Boss 重击、跳劈落点、
## 攻城车 / 冲锋的路线……）、攻击（打身边的怪）、救人（墙下时去救倒地的粉色公主）；在这之上做攻防战自己的事：
##   在城墙上：沿墙顶走道左右走，站到最危险的那段墙上面；每 THINK 秒挑一个法术放（SiegeSpells）：
##     清凉雪花（粉色公主闷笑高 / 被缠住 / 穿着临时痒痒装备）> 帮忙造冰塔（director.build_request）> 冰链救援（director.rescue_request）
##     > 冰墙加固（某段墙下的怪 ≥ REINFORCE_AT）> 冰镜分身（粉色公主身边怪 ≥ MIRROR_AT）> 冰川突刺（射程里有攻城车 / Boss / 敌塔）
##     > 暴风雪（一大团怪 ≥ BLIZZARD_AT）> 冰晶结界（一团怪 ≥ BARRIER_AT）> 冰锥雨（射程内有怪）
##     爬上城墙的怪贴到 WALL_FIGHT 以内：先用普通攻击打它；预警落在走道上：沿走道左右闪开（不往墙下跳）。
##   在城墙上被挠到失控、身边有怪 → 被挠下城墙（director.knock_off）。
##   在墙下（被震下 / 推下）：坐着笑一阵（这时也会挣扎、闪避），SiegeDirector.FALLEN_TIME 秒后走到最近的梯子爬回去；
##     路上粉色公主倒在附近就先去救，被怪围住就先打。倒地（Downed）：什么也不做，等人救。

## 法术放得勤：每 THINK 秒想一次，门槛低（AI 放的冷却 / 疲倦还有 SiegeSpells.AI_CD / AI_FATIGUE）
const THINK := 0.2
const REINFORCE_AT := 4
const BARRIER_AT := 3
const BLIZZARD_AT := 6
const MIRROR_AT := 3
## 粉色公主放魔法时，有这么大几率跟着一起放（吟唱开始时决定，她放出来的那一下一起放）
const JOIN_PINK := 0.5
## 一起放时按这个顺序挑第一个冷却好了的；都在冷却就放一发不看冷却的冰锥雨
const JOIN_SPELLS := ["blizzard", "barrier", "spike", "ice_rain"]
## 墙顶上贴到这么近的怪：先打
const WALL_FIGHT := 26.0
## 墙下：救粉色公主 / 打怪的范围
const GROUND_HELP := 120.0

var director: SiegeDirector
var _think := 0.0
## 跟着粉色公主放魔法：这次决定一起放了 / 一起放过几次（测试用）
var join_next := false
var joined := 0
var _pink_hooked: PlayableCharacter
var _climbing := false
var _patrol_x := 0.0
var _patrol_t := 0.0


func _me() -> PlayableCharacter:
	return get_parent() as PlayableCharacter


func _physics_process(delta: float) -> void:
	_attack_cd -= delta
	_struggle_cd -= delta
	_dash_cd -= delta
	_move = Vector2.ZERO
	_held.clear()
	var me := _me()
	if hooks == null and director:
		hooks = director.hooks
	_hook_pink()
	if me == null or director == null or not me.is_alive() or Downed.is_downed(me) or GameState.in_dialogue \
			or me.get_meta("siege_falling", false) or me.get_meta("siege_beaming", false) or _climbing:
		intent = "idle"
		return
	# 被缠住 / 被抓住 / 笑到失控 / 身上挂着东西：连按挣扎（通用的 + 直接挣一下）
	var stuck: bool = (me.status and (me.status.is_grabbed() or me.status.is_immobile())) or me.latch_count() > 0 \
		or me.state in [PlayableCharacter.State.GRABBED, PlayableCharacter.State.HELPLESS]
	if stuck:
		intent = "struggle"
		if _struggle_cd <= 0.0:
			_struggle_cd = STRUGGLE_INTERVAL
			_pressed[&"attack"] = true
			me.struggle()
		return
	if director.is_on_wall(me):
		_on_wall(me, delta)
	else:
		_ground(me)


## 接上粉色公主的魔法事件（吟唱开始时掷骰子，放出来时一起放）。
func _hook_pink() -> void:
	var p: PlayableCharacter = director.pink if director else null
	if p == _pink_hooked or p == null:
		return
	if is_instance_valid(_pink_hooked) and _pink_hooked.magic_event.is_connected(_on_pink_magic):
		_pink_hooked.magic_event.disconnect(_on_pink_magic)
	_pink_hooked = p
	p.magic_event.connect(_on_pink_magic)


func _exit_tree() -> void:
	if is_instance_valid(_pink_hooked) and _pink_hooked.magic_event.is_connected(_on_pink_magic):
		_pink_hooked.magic_event.disconnect(_on_pink_magic)


func _on_pink_magic(event: String, _tier: int) -> void:
	match event:
		"channel":
			join_next = randf() < JOIN_PINK
		"burst":
			if join_next:
				join_next = false
				join_pink()
		"fizzle", "fail", "interrupted":
			join_next = false


## 跟着粉色公主一起放：往她身边最密的地方放最强的那个冷却好了的法术。
func join_pink() -> bool:
	var me := _me()
	var p: PlayableCharacter = director.pink if director else null
	if me == null or p == null or not me.is_alive() or Downed.is_downed(me) or me.get_meta("siege_beaming", false) or not director.is_on_wall(me):
		return false
	var at: Vector2 = p.global_position
	var crowd: Variant = director.densest(40.0, p.global_position, 90.0)
	if crowd is Vector2:
		at = crowd
	if not SiegeSpells.in_range(me, at):
		return false
	for id in JOIN_SPELLS:
		if SiegeSpells.ready(me, id) and SiegeSpells.cast(me, id, at):
			_joined(me, id)
			return true
	if SiegeSpells.cast(me, "ice_rain", at, true):
		_joined(me, "ice_rain")
		return true
	return false


func _joined(me: PlayableCharacter, id: String) -> void:
	joined += 1
	intent = "spell:" + id
	SpeechBubble.say(me, "……一起。", 28.0, 1.0)


## 墙顶上的闪避：预警落在她身上 → 沿走道往离预警远的一边跑（冲刺），不往墙下跳。
func _wall_dodge(me: PlayableCharacter) -> bool:
	var d := CompanionController.danger_at(get_tree(), me.global_position, DODGE_MARGIN)
	if d == null:
		d = _incoming(me)
	if d == null:
		return false
	intent = "dodge"
	var sx := signf(me.global_position.x - d.global_position.x)
	if sx == 0.0:
		sx = 1.0 if randf() < 0.5 else -1.0
	_move = Vector2(sx, 0)
	if _dash_cd <= 0.0:
		_dash_cd = 0.8
		_pressed[&"dash"] = true
	return true


## 墙顶上贴过来的怪（被扔上来 / 爬上来）：走过去用普通攻击打。
func _wall_fight(me: PlayableCharacter) -> bool:
	var best: Monster = null
	var best_d := WALL_FIGHT
	for m in director.enemies_near(me.global_position, WALL_FIGHT, true):
		if m.get_meta("siege_on_wall", false):
			var dist := m.global_position.distance_to(me.global_position)
			if dist < best_d:
				best_d = dist
				best = m
	if best == null:
		return false
	intent = "attack"
	var to := best.global_position - me.global_position
	if to.length() > ATTACK_RANGE:
		_move = to.normalized()
	else:
		_move = to.normalized() * 0.15
		if _attack_cd <= 0.0:
			_attack_cd = ATTACK_INTERVAL
			_pressed[&"attack"] = true
	return true


func _on_wall(me: PlayableCharacter, delta: float) -> void:
	# 墙上被挠到失控、身边有怪 → 被挠下去
	if me.laugh and me.laugh.stage() == "helpless_2" and not director.enemies_near(me.global_position, 22.0).is_empty():
		director.knock_off(me, "爬上城墙的怪物")
		return
	if _wall_dodge(me) or _wall_fight(me):
		return
	var goal_x := me.global_position.x
	var req: Variant = director.call("build_request") if director.has_method("build_request") else null
	var rescue: Variant = director.call("rescue_request") if director.has_method("rescue_request") else null
	if req is Node2D:
		goal_x = (req as Node2D).global_position.x
	elif rescue is Node2D:
		goal_x = (rescue as Node2D).global_position.x
	else:
		var hot := director.hottest_wall()
		if hot and director.threat(hot) > 0:
			goal_x = clampf(me.global_position.x, hot.left_x() + 20.0, hot.right_x() - 20.0)
		else:
			# 没有威胁：在墙顶走道上随机挑个地方来回巡逻
			_patrol_t -= delta
			if _patrol_t <= 0.0 or absf(_patrol_x - me.global_position.x) < 6.0:
				_patrol_t = randf_range(3.0, 6.0)
				_patrol_x = clampf(me.global_position.x + randf_range(-160.0, 160.0), 40.0, director.map_size().x - 40.0)
			goal_x = _patrol_x
	var walk_y := director.wall_top_y() + 4.0
	# 城墙羽毛扫帚要扫过来：先换到另一行（最优先，直接竖着走）；扫帚还在的时候巡逻也走安全的那一行，不往回走
	for h in get_tree().get_nodes_in_group("siege_hazard"):
		if h is HazardBroom:
			var br := h as HazardBroom
			if br.threatens(walk_y):
				walk_y = br.safe_y()
			if br.threatens(me.global_position.y):
				_move = Vector2(0, signf(br.safe_y() - me.global_position.y))
				intent = "dodge"
				return
	var d := Vector2(goal_x - me.global_position.x, (walk_y - me.global_position.y) * 0.5)
	if d.length() > 6.0:
		_move = d.normalized()
		intent = "patrol"
	_think -= delta
	if _think > 0.0:
		return
	_think = THINK
	_decide(me, req, rescue)


func _decide(me: PlayableCharacter, req: Variant, rescue: Variant) -> void:
	var pink := director.pink
	# 清凉雪花：粉色公主撑不住了
	if pink and pink.is_alive() and not Downed.is_downed(pink) and SiegeSpells.ready(me, "snow") \
			and SiegeSpells.in_range(me, pink.global_position):
		var need := (pink.laugh and pink.laugh.ratio() > 0.6) or not Equipment.forced_items("pink").is_empty() \
			or (pink.status and pink.status.is_grabbed())
		if need and SiegeSpells.cast(me, "snow", pink.global_position):
			intent = "spell:snow"
			return
	# 帮忙造冰塔
	if req is Node2D and (req as Node2D).has_method("blue_beam"):
		if absf((req as Node2D).global_position.x - me.global_position.x) < 60.0:
			(req as Node2D).call("blue_beam", me)
			intent = "build"
		return
	# 冰链救援 / 探出城垛割网（被拖走 / 被黏网罩住的粉色公主）
	if rescue is Node2D and director.rescue(me):
		intent = "rescue"
		return
	# 冰墙加固
	var hot := director.hottest_wall()
	if hot and director.threat(hot) >= REINFORCE_AT and hot.climbable() and SiegeSpells.ready(me, "reinforce"):
		if SiegeSpells.cast(me, "reinforce", Vector2(hot.global_position.x, hot.foot_y())):
			intent = "spell:reinforce"
			return
	# 冰镜分身：粉色公主被围住了——放个分身把怪引开
	if pink and pink.is_alive() and not Downed.is_downed(pink) and SiegeSpells.ready(me, "mirror") \
			and director.enemies_near(pink.global_position, 60.0).size() >= MIRROR_AT:
		var at := pink.global_position + Vector2(randf_range(-50, 50), 40.0)
		if SiegeSpells.in_range(me, at) and SiegeSpells.cast(me, "mirror", at):
			intent = "spell:mirror"
			return
	# 冰川突刺：攻城车 / Boss / 敌塔
	if SiegeSpells.ready(me, "spike"):
		var big: Node2D = null
		for m in director.enemies_near(me.global_position, SiegeSpells.RANGE * 0.6):
			if m is SiegeCart or m is TrollGeneral:
				big = m
				break
		if big == null:
			for t in me.get_tree().get_nodes_in_group("siege_enemy_tower"):
				if (t as Node2D).global_position.distance_to(me.global_position) < 360.0:
					big = t
					break
		if big and SiegeSpells.cast(me, "spike", big.global_position):
			intent = "spell:spike"
			return
	# 暴风雪：一大团怪
	if SiegeSpells.ready(me, "blizzard"):
		var pb: Variant = director.densest(60.0, me.global_position, SiegeSpells.RANGE)
		if pb is Vector2 and director.enemies_near(pb, 90.0).size() >= BLIZZARD_AT:
			if SiegeSpells.cast(me, "blizzard", pb):
				intent = "spell:blizzard"
				return
	# 冰晶结界：一大团怪
	if SiegeSpells.ready(me, "barrier"):
		var p: Variant = director.densest(40.0, me.global_position, SiegeSpells.RANGE)
		if p is Vector2 and director.enemies_near(p, 40.0).size() >= BARRIER_AT:
			if SiegeSpells.cast(me, "barrier", p):
				intent = "spell:barrier"
				return
	# 冰锥雨：射程内最密的地方
	if SiegeSpells.ready(me, "ice_rain"):
		var p2: Variant = director.densest(30.0, me.global_position, SiegeSpells.RANGE)
		if p2 is Vector2 and SiegeSpells.cast(me, "ice_rain", p2):
			intent = "spell:ice_rain"


## 在墙下：闪避预警 → 救附近倒地的粉色公主 → 被怪贴身就打 → 先坐着笑一阵，时间到了走去梯子爬回去。
func _ground(me: PlayableCharacter) -> void:
	if _dodge(me):
		return
	var pink := director.pink
	if pink and Downed.is_downed(pink) and pink.global_position.distance_to(me.global_position) < GROUND_HELP and _revive(me):
		return
	if _enemies_near(me, 30.0) >= 1 and _attack(me):
		return
	_fallen(me)


func _fallen(me: PlayableCharacter) -> void:
	if director.fallen_for(me) < SiegeDirector.FALLEN_TIME:
		intent = "fallen"
		return
	var ladder := director.nearest_ladder(me.global_position)
	if ladder == null:
		return
	var bottom: Vector2 = ladder.call("bottom_pos")
	var d := bottom - me.global_position
	if d.length() > 8.0:
		_move = d.normalized()
		intent = "ladder"
		return
	_climbing = true
	intent = "ladder"
	await ladder.call("climb", me)
	_climbing = false

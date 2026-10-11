class_name SiegeMageController
extends CharacterController
## 攻防战里蓝色公主的 AI（没被玩家操控时；SiegeDirector 的 ai_factory 给她）：
##   在城墙上：沿墙顶走道左右走，站到最危险的那段墙上面；每 THINK 秒挑一个法术放（SiegeSpells）：
##     清凉雪花（粉色公主闷笑高 / 被缠住 / 穿着临时痒痒装备）> 帮忙造冰塔（director.build_request）> 冰链救援（director.rescue_request）
##     > 冰墙加固（某段墙下的怪 ≥ REINFORCE_AT）> 冰晶结界（一团怪 ≥ BARRIER_AT）> 冰锥雨（射程内有怪）
##   在城墙上被挠到失控、身边有怪 → 被挠下城墙（director.knock_off）。
##   在墙下（被震下 / 推下）：坐着笑一阵，SiegeDirector.FALLEN_TIME 秒后走到最近的梯子爬回去。
##   被缠住 / 被抓住：连按挣扎。倒地（Downed）：什么也不做，等粉色公主救。

const THINK := 0.45
const REINFORCE_AT := 7
const BARRIER_AT := 6

var director: SiegeDirector
var _move := Vector2.ZERO
var _think := 0.0
var _struggle_t := 0.0
## 最近一次做的决定（测试 / 调试用）：idle / patrol / spell:<id> / fallen / ladder / struggle / build / rescue
var intent := "idle"
var _climbing := false


func get_move_vector() -> Vector2:
	return _move


func _me() -> PlayableCharacter:
	return get_parent() as PlayableCharacter


func _physics_process(delta: float) -> void:
	_move = Vector2.ZERO
	var me := _me()
	if me == null or director == null or not me.is_alive() or Downed.is_downed(me) or GameState.in_dialogue \
			or me.get_meta("siege_falling", false) or me.get_meta("siege_beaming", false) or _climbing:
		intent = "idle"
		return
	# 被缠住 / 被抓住 / 身上挂着东西：连按挣扎
	_struggle_t -= delta
	var stuck: bool = (me.status and (me.status.is_grabbed() or me.status.is_immobile())) or me.latch_count() > 0 \
		or me.state in [PlayableCharacter.State.GRABBED]
	if stuck:
		intent = "struggle"
		if _struggle_t <= 0.0:
			_struggle_t = 0.14
			me.struggle()
		return
	if director.is_on_wall(me):
		_on_wall(me, delta)
	else:
		_fallen(me)


func _on_wall(me: PlayableCharacter, delta: float) -> void:
	# 墙上被挠到失控、身边有怪 → 被挠下去
	if me.laugh and me.laugh.stage() == "helpless_2" and not director.enemies_near(me.global_position, 22.0).is_empty():
		director.knock_off(me, "爬上城墙的怪物")
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
	var walk_y := director.wall_top_y() + 4.0
	# 城墙羽毛扫帚要扫过来：先换到另一行（最优先，直接竖着走）
	for h in get_tree().get_nodes_in_group("siege_hazard"):
		if h is HazardBroom and (h as HazardBroom).threatens(me.global_position.y):
			_move = Vector2(0, signf((h as HazardBroom).safe_y() - me.global_position.y))
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


## 在墙下：先坐着笑一阵，时间到了走去梯子爬回去。
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

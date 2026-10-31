class_name HandShard
extends Node2D
## 手印碎片（骑士篇支线「手印样本」）：诅咒手印掉下来的一小块，躲在石头 / 木桶（cover）底下；是笑声做的，被真心的笑声引出来。
##   state：hidden 躲着（可操作角色走到 WOBBLE_R 以内，盖着它的东西会晃）/ peek 探头 / crawl 爬向粉色公主的脚 / flee 躲开蓝色公主 /
##          frozen 被冻住（FROZEN_TIME 秒，走过去按 E 装瓶）/ caught 装进瓶子了。
##   粉色公主在 LURE_R 以内故意笑（KnightLaugh）：探头 PEEK_TIME 秒 → 爬向她的脚，碰到就轻轻拍拍脚背、乖乖进瓶子（伏笔：认得她）。
##   蓝色公主走到 FLEE_R 以内：它逃开；被追着逃了 CORNER_TIME 秒、她还贴着（CORNER_R 以内）→ 被逼急了扑上去挠她的大腿（闷笑 +CORNER_LAUGH），再躲回去。
##   冻住：蓝色公主 J（任务调 freeze）、千手解放（on_pants_burst）。
##   tease（支线「骑士救公主」·小莉莉的宝贝盒：搬着盒子碎片的手印）：爬到她脚边不进瓶子，挠她一下脚心（闷笑 +TEASE_LAUGH），
##     然后抱着碎片晃晃悠悠（frozen 状态 DAZED_TIME 秒）——这时候按 E 抢回来；没抢到它就躲回货摊。
## 信号 caught_by(碎片)、teased(碎片)。测试：直接改 state，调 lure(角色)、freeze()、bottle()。

signal caught_by(shard: HandShard)
signal teased(shard: HandShard)

const WOBBLE_R := 40.0
const LURE_R := 60.0
const PEEK_TIME := 2.0
const CRAWL_SPEED := 34.0
const FLEE_R := 40.0
const FLEE_SPEED := 60.0
const CORNER_TIME := 1.5
const CORNER_R := 30.0
const CORNER_LAUGH := 0.08
const FROZEN_TIME := 5.0
const CATCH_R := 8.0
const BOTTLE_R := 18.0
const TEASE_LAUGH := 0.07
const DAZED_TIME := 1.8

var cover := "stone"
var tease := false
var state := "hidden"
var home := Vector2.ZERO
var lines := {}
var _t := 0.0
var _peek := 0.0
var _flee_t := 0.0
var _frozen := 0.0
var _wobble := 0.0
var _say := 0.0


static func make(parent: Node, at: Vector2, cover_kind := "stone", text := {}) -> HandShard:
	var s := HandShard.new()
	s.cover = cover_kind
	s.lines = text
	parent.add_child(s)
	s.global_position = at
	s.home = at
	return s


func _ready() -> void:
	z_index = 1
	add_to_group("hand_shard")
	add_to_group(PantsBurst.KNIGHT_GROUP)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func pink() -> PlayableCharacter:
	for c in get_tree().get_nodes_in_group("player_chars"):
		if not c is BluePrincess:
			return c
	return null


func blue() -> PlayableCharacter:
	for c in get_tree().get_nodes_in_group("player_chars"):
		if c is BluePrincess:
			return c
	return null


func _process(delta: float) -> void:
	_t += delta
	_wobble = maxf(0.0, _wobble - delta)
	_say = maxf(0.0, _say - delta)
	queue_redraw()
	if GameState.in_dialogue or GameState.in_cutscene or state == "caught":
		return
	var p := pink()
	var b := blue()
	match state:
		"hidden":
			var near := false
			for c in [p, b]:
				if is_instance_valid(c) and c.global_position.distance_to(home) <= WOBBLE_R:
					near = true
			if near and _wobble <= 0.0:
				_wobble = 0.6
		"peek":
			_peek -= delta
			if _peek <= 0.0:
				state = "crawl"
		"crawl":
			if not is_instance_valid(p):
				state = "hidden"
				return
			global_position = global_position.move_toward(p.global_position, CRAWL_SPEED * delta)
			if global_position.distance_to(p.global_position) <= CATCH_R:
				if tease:
					_tease(p)
				else:
					_caught_by_pink(p)
		"flee":
			if not is_instance_valid(b):
				state = "hidden"
				return
			var d := global_position.distance_to(b.global_position)
			if d > FLEE_R * 1.6:
				_flee_t = 0.0
				state = "hidden"
				global_position = home
				return
			var np := (global_position + b.global_position.direction_to(global_position) * FLEE_SPEED * delta).clamp(home - Vector2(48, 48), home + Vector2(48, 48))
			# 逃跑不穿墙（等距楼层的墙是方块）
			var lv := Party.level_of(self)
			if lv == null or GridPath.walkable(lv, GridPath.cell(np)):
				global_position = np
			_flee_t += delta
			if _flee_t >= CORNER_TIME and d <= CORNER_R:
				_corner(b)
		"frozen":
			_frozen -= delta
			if _frozen <= 0.0:
				state = "hidden"
				global_position = home
	# 蓝色公主走近：逃开（冻住的、已经在爬向粉色公主的不逃）
	if state in ["hidden", "peek"] and is_instance_valid(b) and b.global_position.distance_to(global_position) <= FLEE_R and b == GameState.player:
		if state == "peek" or b.global_position.distance_to(home) <= FLEE_R * 0.7:
			state = "flee"
			_flee_t = 0.0
			_line("flee")


## 粉色公主在附近故意笑：探头 → 爬过来（任务每帧问）
func lure(c: PlayableCharacter) -> void:
	if state == "hidden" and c.global_position.distance_to(home) <= LURE_R:
		state = "peek"
		_peek = PEEK_TIME
		_line("peek")


func freeze() -> void:
	if state == "caught":
		return
	state = "frozen"
	_frozen = FROZEN_TIME
	Audio.play("chime", -8.0)


## 冰晶结界：范围里的碎片冻住
func on_ice_barrier(center: Vector2, r: float, _time: float) -> void:
	if state != "caught" and global_position.distance_to(center) <= r:
		freeze()


## 走过去按 E：冻住的装进瓶子
func bottle(by: PlayableCharacter) -> bool:
	if state != "frozen" or by.global_position.distance_to(global_position) > BOTTLE_R:
		return false
	_finish()
	return true


func on_pants_burst(burst: PantsBurst) -> void:
	if state != "caught" and global_position.distance_to(burst.global_position) <= PantsBurst.RADIUS:
		freeze()


## 搬盒子的手印：挠一下脚心，然后抱着碎片晃悠（按 E 抢）
func _tease(p: PlayableCharacter) -> void:
	ZoneFx.play("sole", p.get_parent(), ZoneFx.body_point(p, "sole"), 0.8, false)
	if p.laugh:
		p.laugh.add(p.laugh.max_value * TEASE_LAUGH)
	Audio.play("tickle", -7.0, 0.1)
	state = "frozen"
	_frozen = DAZED_TIME
	teased.emit(self)


func _caught_by_pink(p: PlayableCharacter) -> void:
	ZoneFx.play("sole", p.get_parent(), ZoneFx.body_point(p, "sole"), 0.6, false)
	if p.fatigue:
		p.fatigue.add(p.fatigue.max_value * 0.03)
	_line("caught")
	_finish()


func _corner(b: PlayableCharacter) -> void:
	ZoneFx.play("thigh", b.get_parent(), ZoneFx.body_point(b, "thigh"), 1.1, false)
	if b.laugh:
		b.laugh.add(b.laugh.max_value * CORNER_LAUGH)
	b.shake(0.2)
	Audio.play("tickle", -6.0, 0.1)
	_line("corner")
	var react: Array = lines.get("blue_react", [])
	if not react.is_empty():
		SpeechBubble.say(b, str(react.pick_random()), 30.0, 1.4)
	state = "hidden"
	global_position = home
	_flee_t = 0.0


func _finish() -> void:
	state = "caught"
	Audio.play("pickup", -4.0)
	caught_by.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(hide)


func _line(key: String) -> void:
	var pool: Array = lines.get(key, [])
	if pool.is_empty() or _say > 0.0:
		return
	_say = 2.0
	GameState.princess_reacted.emit(str(pool.pick_random()), 2.4)


func _draw() -> void:
	var off := home - global_position
	var wob := sin(_t * 30.0) * 1.2 if _wobble > 0.0 else 0.0
	# 盖着它的东西（离开以后留在原地）
	if cover == "stone":
		draw_colored_polygon(PackedVector2Array([off + Vector2(-7 + wob, 3), off + Vector2(-5 + wob, -3), off + Vector2(3 + wob, -4),
			off + Vector2(7 + wob, 1), off + Vector2(5 + wob, 4)]), Color(0.6, 0.57, 0.62))
		draw_line(off + Vector2(-4 + wob, -2), off + Vector2(3 + wob, -3), Color(0.75, 0.72, 0.78), 1.0)
	elif cover == "barrel":
		draw_rect(Rect2(off + Vector2(-5 + wob, -10), Vector2(10, 12)), Color(0.66, 0.43, 0.27))
		draw_line(off + Vector2(-5 + wob, -6), off + Vector2(5 + wob, -6), Color(0.47, 0.45, 0.5), 1.0)
		draw_line(off + Vector2(-5 + wob, -1), off + Vector2(5 + wob, -1), Color(0.47, 0.45, 0.5), 1.0)
	elif cover == "stall":
		# 货摊的布帘（红白条纹，晃起来就是底下有东西）
		for i in 4:
			draw_rect(Rect2(off + Vector2(-8 + i * 4 + wob, -9), Vector2(4, 10)), Color(0.85, 0.3, 0.35) if i % 2 == 0 else Color(0.95, 0.9, 0.85))
		draw_line(off + Vector2(-9, -10), off + Vector2(9, -10), Color(0.5, 0.33, 0.2), 2.0)
	if state in ["hidden", "caught"]:
		return
	if tease:
		# 怀里抱着一块宝贝盒的碎片
		draw_rect(Rect2(Vector2(-3, -11), Vector2(6, 4)), Color(0.72, 0.5, 0.3))
		draw_rect(Rect2(Vector2(-3, -11), Vector2(6, 4)), Color(0.45, 0.28, 0.16), false, 1.0)
	var col := CurseHand.ICE if state == "frozen" else CurseHand.COL
	var a := 0.9 if state == "frozen" else 0.6 + 0.25 * sin(_t * 6.0)
	var k := 0.55 if state == "peek" else 0.75
	CurseHand.draw_hand(self, Vector2(0, -2), k, col, CurseHand.COL_D, a, sin(_t * 12.0) * (0.0 if state == "frozen" else 1.0))
	if state == "frozen":
		draw_arc(Vector2(0, -2), 6.0, 0, TAU, 12, Color(CurseHand.ICE, 0.6), 1.0)

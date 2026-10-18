class_name AfterKid
extends Resident
## 七日赎罪里在路上闲逛的小孩（委托「送饼干」、弥补任务「装备回收」用）：
##   平时在出生点附近溜达；lure（Callable → bool：公主拿着饼干 / 闷笑超过 40% / 装备在发作……）成立、公主在 SIGHT 以内
##   → 跑过去（CHASE）→ 贴上来挠 TICKLE_TIME 秒（闷笑上涨，部位按 pick_zone，头顶冒字、旁白字幕按 caption）→ on_catch(小孩)
##   → 跑开（LEAVE），COOL 秒内不再来。公主冲刺甩开（离开 GIVE_UP）、或者走到身边按 E（talk → shoo）都能把他哄走。
##   闷笑最多涨到 MAX_LAUGH（小镇里不会笑晕），满了算「被挠软了」（on_catch 照样调）。
## 生成：AfterKid.spawn(父节点, 位置)。

enum Mode { WANDER, CHASE, TICKLE, LEAVE }

const SIGHT := 96.0
const GIVE_UP := 150.0
const RUN_SPEED := 62.0
const TICKLE_TIME := 1.8
## 每秒涨闷笑上限的比例
const TICKLE_RATE := 0.16
const COOL := 10.0
const MAX_LAUGH := 0.97

var mode := Mode.WANDER
var lure := Callable()
var on_catch := Callable()
## 被按 E 哄走时（送饼干：分他一块）
var on_shoo := Callable()
## (小孩) → 部位
var pick_zone := Callable()
## (小孩, 部位) → 详细的旁白字幕（""= 不出）
var caption := Callable()
var chase_words: Array = ["姐姐！", "抓到你了！"]
var tickle_words: Array = ["咯吱咯吱～", "这里这里！"]
var rate_mul := 1.0
var _mode_t := 0.0
var _cool := 0.0
var _zone := "waist"
var _hit_t := 0.0


static func spawn(parent: Node, at: Vector2, wander_cells := 2.0) -> AfterKid:
	var k: AfterKid = load("res://levels/floor_06/scenes/after_kid.tscn").instantiate()
	k.npc_id = "kid"
	k.dialogue = "floor_06/after_kid_shoo"
	k.wander = wander_cells
	parent.add_child(k)
	k.global_position = at
	k._home = at
	k._goal = at
	return k


func talk(_player: Node) -> void:
	shoo()


## 被哄走：跑开，COOL 秒内不来。
func shoo() -> void:
	if mode == Mode.LEAVE or (mode == Mode.WANDER and _cool > 0.0):
		return
	if on_shoo.is_valid():
		on_shoo.call(self)
	else:
		SpeechBubble.say(self, "切——不好玩！", 26.0, 1.2)
	_leave()


func _leave() -> void:
	mode = Mode.LEAVE
	_mode_t = 1.6
	_cool = COOL


func _tick(delta: float) -> void:
	_t += delta
	_cool = maxf(0.0, _cool - delta)
	var p := GameState.player
	if GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(p):
		velocity = Vector2.ZERO
		move_and_slide()
		_animate(delta)
		return
	var d := p.global_position.distance_to(global_position)
	match mode:
		Mode.WANDER:
			super(delta)
			if _cool <= 0.0 and d <= SIGHT and lure.is_valid() and bool(lure.call()):
				mode = Mode.CHASE
				SpeechBubble.say(self, str(chase_words.pick_random()), 26.0, 1.0)
			return
		Mode.CHASE:
			if d > GIVE_UP or p.is_dashing() or not (lure.is_valid() and bool(lure.call())):
				SpeechBubble.say(self, "跑、跑掉了……", 26.0, 1.0)
				_leave()
			elif d < 12.0:
				mode = Mode.TICKLE
				_mode_t = TICKLE_TIME
				_zone = str(pick_zone.call(self)) if pick_zone.is_valid() else "waist"
				var cap := str(caption.call(self, _zone)) if caption.is_valid() else ""
				if cap != "":
					GameState.notify(cap, 3.0)
			else:
				velocity = global_position.direction_to(p.global_position) * RUN_SPEED
				facing = velocity.normalized()
		Mode.TICKLE:
			velocity = Vector2.ZERO
			global_position = global_position.lerp(p.global_position + Vector2(10 if global_position.x > p.global_position.x else -10, 2), 0.3)
			_mode_t -= delta
			_hit_t -= delta
			if p.laugh:
				var cap_v := p.laugh.max_value * MAX_LAUGH
				if p.laugh.value < cap_v:
					p.laugh.add(minf(p.laugh.max_value * TICKLE_RATE * rate_mul * delta, cap_v - p.laugh.value))
			if _hit_t <= 0.0:
				_hit_t = 0.3
				p.shake(0.15)
				Audio.play("tickle", -6.0, 0.1)
				HitFx.play("hand", p.get_parent(), p.global_position + Vector2(randf_range(-5, 5), -10))
				ZoneFx.play(_zone, p.get_parent(), ZoneFx.body_point(p, _zone), 1.0, false)
				if randf() < 0.3:
					SpeechBubble.say(self, str(tickle_words.pick_random()), 26.0, 0.8)
					GameState.emote("helpless_1", 1.0, false)
			if p.is_dashing() or _mode_t <= 0.0:
				if on_catch.is_valid():
					on_catch.call(self)
				_leave()
		Mode.LEAVE:
			_mode_t -= delta
			velocity = p.global_position.direction_to(global_position) * RUN_SPEED * 0.8
			if _mode_t <= 0.0:
				mode = Mode.WANDER
				_goal = _home
	move_and_slide()
	_animate(delta)


func zone() -> String:
	return _zone

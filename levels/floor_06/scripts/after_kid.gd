class_name AfterKid
extends Resident
## 七日赎罪里在路上闲逛的小孩（委托「送饼干」、弥补任务「装备回收」用）：
##   平时在出生点附近溜达；lure（Callable → bool：公主拿着饼干 / 闷笑超过 40% / 装备在发作……）成立、公主在 SIGHT 以内
##   → 跑过去（CHASE）→ 贴上来挠 TICKLE_TIME 秒（闷笑上涨，部位按 pick_zone）→ on_catch(小孩) → 跑开（LEAVE），COOL 秒内不再来。
##   刚贴上来时暂停演一小段对话：小孩的话 + caption 的挠法描写 + 公主的反应（react，按闷笑三档），不用画面下方的反应框。
##   冲刺甩不掉（贴上来以后跑也跑不开）；走远到 GIVE_UP 以外（追的时候）、或者走到身边按 E（talk → shoo）才能哄走。
##   闷笑最多涨到 MAX_LAUGH（小镇里不会笑晕），满了算「被挠软了」（on_catch 照样调）。
## 生成：AfterKid.spawn(父节点, 位置)。

enum Mode { WANDER, CHASE, TICKLE, LEAVE }

const SIGHT := 160.0
const GIVE_UP := 240.0
const RUN_SPEED := 62.0
const TICKLE_TIME := 4.0
## 每秒涨闷笑上限的比例
const TICKLE_RATE := 0.16
const COOL := 10.0
const MAX_LAUGH := 0.97
## 两段「贴上来的对话」之间至少隔几秒（几个小孩接连扑上来时，后来的只冒气泡，不再暂停）
const SCENE_GAP := 7.0

static var _last_scene := -100.0

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
## 贴上来时公主的反应（按闷笑三档：{light / mid / heavy: [...]}）
var react_pool: Dictionary = {
	"light": ["哇、别、别过来……！", "……我、我在干活呢！", "唔……又来了……"],
	"mid": ["哈、哈哈……别挠了……！", "噗……放、放开我……！", "哈哈……一会儿就好……一会儿……"],
	"heavy": ["哈哈哈……不、不行了……", "哈……饶、饶了我……", "哈哈哈……站、站不住了……"]}
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
			if d > GIVE_UP or not (lure.is_valid() and bool(lure.call())):
				SpeechBubble.say(self, "跑、跑掉了……", 26.0, 1.0)
				_leave()
			elif d < 12.0:
				mode = Mode.TICKLE
				_mode_t = TICKLE_TIME
				_zone = str(pick_zone.call(self)) if pick_zone.is_valid() else "waist"
				_tickle_scene()
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
			if _mode_t <= 0.0:
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


## 刚贴上来：暂停演一小段（小孩的话 + 挠法描写 + 公主的反应）
func _tickle_scene() -> void:
	var cap := str(caption.call(self, _zone)) if caption.is_valid() else ""
	var p := GameState.player
	var lr := p.laugh.ratio() if is_instance_valid(p) and p.laugh else 0.0
	var tier := "light" if lr < 0.35 else ("mid" if lr < 0.7 else "heavy")
	var pool: Array = react_pool.get(tier, [])
	var lines: Array = [{"speaker": "小孩", "text": str(tickle_words.pick_random())}]
	if cap != "":
		lines.append({"speaker": "", "text": cap})
	if not pool.is_empty():
		lines.append({"speaker": "公主", "text": str(pool.pick_random()), "emotion": "helpless_1" if tier != "heavy" else "helpless_2"})
	var now := Time.get_ticks_msec() / 1000.0
	if not Dialogue.is_active() and now - _last_scene >= SCENE_GAP:
		_last_scene = now
		Dialogue.start_lines(lines, "after_kid")
	else:
		SpeechBubble.say(self, str(lines[0]["text"]), 26.0, 1.2)
		if is_instance_valid(p) and lines.size() > 1:
			SpeechBubble.say(p, str(lines[-1]["text"]), 30.0, 1.6)


func zone() -> String:
	return _zone

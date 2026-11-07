class_name PalaceServants
extends PalaceRoom
## 第四章②·仆人回廊（floor_06_palace_servants，等距；潜入：地图里的 StealthDirector（on_caught = palace）+ 人偶女仆 guard_patrol（maid 图集、doll））：
##   被发现 → StealthDirector._caught → on_caught_static → 小剧场 servants_caught_first（第一次长）/ servants_caught → 回入口重来；
##   木箱 / 帘子（hides）按 E 躲；hide_event 那一处躲进去会触发「千手裤发作、粉色公主自告奋勇去引开」的小剧场 servants_hide（CG，只是剧情）；
##   尘土堆（dust）：走过去打喷嚏（声音引来人偶，StealthDirector.noise）；会动的扫帚（brooms）：在房间里来回扫，碰到就扫脚底（也有声音）；
##   F：丢出去的是挠脚鼠（StealthDirector.throw_stone，穿着鼠鼠装时）；旧排班表 / 日记（clues，线索）；
##   女仆长人偶（head_maid，站岗的 guard_patrol）守着钥匙：拉唤人铃（bell，对话 call palace_bell）她会过去查看，趁机拿钥匙（key，call palace_key → KEY_FLAG）；
##   出口 east 要钥匙。唤人铃、钥匙都画出来（MiscView：palace_misc.png 的「墙上的唤人铃 / 挂在钩子上的钥匙」），女仆长头顶挂着名牌「女仆长」、用自己的图集 head_maid.png。
## 测试：caught_count、hide_done、dust_t、brooms、ring_bell()、take_key()。

const MAP := "floor_06_palace_servants"
const KEY_FLAG := "palace_servants_key"
const DUST_R := 10.0
const DUST_COOL := 4.0
const BELL_R := 220.0
const BROOM_RANGE := 40.0
const BROOM_SPEED := 30.0

static var current: PalaceServants

var caught_count := 0
var hide_done := false
var dust_t := {}
var brooms: Array = []


func map_id() -> String:
	return MAP


func _ready() -> void:
	super()
	current = self
	hide_done = GameState.has_flag("cg_seen_theater:servants_hide")
	for c in cells("brooms"):
		var b := Broom.new()
		b.room = self
		b.home = world(c)
		b.position = b.home
		add_view(b)
		brooms.append(b)
	var ci := 0
	for c in cells("clues"):
		ci += 1
		_spot("floor_06/palace_schedule_%d" % ci, c)
	_spot("floor_06/palace_bell", cells("bell")[0])
	_spot("floor_06/palace_key", cells("key")[0])
	var bv := MiscView.new()
	bv.frame = 0
	bv.position = world(cells("bell")[0])
	add_view(bv)
	var kv := MiscView.new()
	kv.frame = 1
	kv.hide_flag = KEY_FLAG
	kv.position = world(cells("key")[0])
	add_view(kv)
	if not cells("deliver").is_empty():
		_spot("floor_06/servants_deliver", cells("deliver")[0])
	_tag_head_maid.call_deferred()


## 女仆长：离她站岗那格最近的巡逻人偶，头顶挂名牌
func _tag_head_maid() -> void:
	await get_tree().process_frame
	var at := world(cells("head_maid")[0])
	var best: Node2D = null
	for g in get_tree().get_nodes_in_group("patrol_guard"):
		if best == null or (g as Node2D).global_position.distance_to(at) < best.global_position.distance_to(at):
			best = g
	if best == null:
		return
	var tag := Label.new()
	tag.text = "女仆长"
	tag.add_theme_font_size_override("font_size", 8)
	tag.add_theme_color_override("font_color", Color(0.95, 0.75, 1.0))
	tag.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.25))
	tag.add_theme_constant_override("outline_size", 3)
	tag.position = Vector2(-14, -48)
	best.add_child(tag)
	best.scale = Vector2(1.15, 1.15)


func _spot(dialogue: String, c: Vector2i) -> void:
	var sp := PrisonOddities.Spot.new()
	sp.dialogue = dialogue
	add_child(sp)
	sp.global_position = world(c)


func _exit_tree() -> void:
	super()
	if current == self:
		current = null


func _process(delta: float) -> void:
	if busy():
		return
	var sd := StealthDirector.current
	# 躲藏点的剧情
	if not hide_done and sd and is_instance_valid(sd.hidden_in) and sd.hidden_in.global_position.distance_to(world(cells("hide_event")[0])) <= 12.0:
		hide_done = true
		CG.play_theater("servants_hide")
		return
	# 尘土堆：走过去打喷嚏
	for c in cells("dust"):
		var k := str(c)
		dust_t[k] = maxf(0.0, float(dust_t.get(k, 0.0)) - delta)
		if float(dust_t[k]) > 0.0:
			continue
		for m in members():
			var pc := m as PlayableCharacter
			if pc.velocity.length() > 10.0 and pc.global_position.distance_to(world(c)) <= DUST_R:
				dust_t[k] = DUST_COOL
				sneeze(pc)
				break
	for b in brooms:
		(b as Broom).step(delta)


func sneeze(pc: PlayableCharacter) -> void:
	PalaceRoom.say_random(pc, "sneeze")
	Fx.burst(pc.get_parent(), pc.global_position + Vector2(0, -6), "dust", 8, 30.0, 0.5, Vector2(0, -8), Color(0.75, 0.7, 0.6))
	if StealthDirector.current:
		StealthDirector.current.noise(pc.global_position, 100.0)


## 拉唤人铃：女仆长（和附近的人偶）过去查看
func ring_bell() -> int:
	Audio.play("chime", -2.0, 0.0, 1.3)
	PalaceRoom.say_random(GameState.player, "bell")
	var sd := StealthDirector.current
	return sd.noise(world(cells("bell")[0]), BELL_R) if sd else 0


## 追加事件·送餐潜行：把厨房的点心端到女仆长的房间（deliver）→ 笑声乐谱片②
func deliver_tray() -> bool:
	if not PalaceRoom.carrying_tray():
		return false
	PalaceRoom.set_tray(false)
	Audio.play("chime", -4.0)
	PalaceRoom.give_sheet(2)
	return true


func take_key() -> void:
	if GameState.has_flag(KEY_FLAG):
		return
	GameState.set_flag(KEY_FLAG)
	Audio.play("unlock", -2.0)
	GameState.notify("拿到了「仆人回廊的钥匙」")


static func on_caught_static() -> void:
	if current:
		current.caught()


func caught() -> void:
	if _defeat_busy:
		return
	_defeat_busy = true
	caught_count += 1
	var id := "servants_caught_first" if not GameState.has_flag("cg_seen_theater:servants_caught_first") else "servants_caught"
	# 追加事件：端着点心被发现 → 试吃惩罚（CG），点心没了，要回厨房重拿
	if PalaceRoom.carrying_tray():
		id = "servants_tasting"
		PalaceRoom.set_tray(false)
	await CG.play_theater(id)
	reset_to(world(cells("start")[0]))
	if StealthDirector.current:
		StealthDirector.current.reset()
	_defeat_busy = false


## 墙上的唤人铃 / 挂在钩子上的钥匙（palace_misc.png 3 帧：铃 / 钥匙 / 小牌子；没有图就画简笔）；hide_flag 有了就不画（钥匙拿走了）
class MiscView extends Node2D:
	const TEX := "res://assets/generated/palace_misc.png"
	var frame := 0
	var hide_flag := ""
	var _spr: Sprite2D
	var _t := 0.0

	func _ready() -> void:
		if ResourceLoader.exists(TEX):
			_spr = Sprite2D.new()
			_spr.texture = load(TEX)
			_spr.hframes = 3
			_spr.frame = frame
			_spr.offset = Vector2(0, -18)
			add_child(_spr)

	func _process(d: float) -> void:
		_t += d
		visible = hide_flag == "" or not GameState.has_flag(hide_flag)
		if _spr:
			_spr.modulate = Color(1, 1, 1).lerp(Color(1.4, 1.3, 0.9), 0.5 + sin(_t * 3.0) * 0.5)
		queue_redraw()

	func _draw() -> void:
		if _spr:
			return
		if frame == 0:
			draw_line(Vector2(0, -30), Vector2(0, -12), Color(0.75, 0.2, 0.2), 1.5)
			draw_circle(Vector2(0, -32), 4.0, Color(0.9, 0.75, 0.3))
			draw_circle(Vector2(0, -11), 2.0, Color(0.9, 0.3, 0.3))
		else:
			draw_circle(Vector2(-3, -14), 3.0, Color(0.95, 0.8, 0.3))
			draw_line(Vector2(0, -14), Vector2(7, -14), Color(0.95, 0.8, 0.3), 2.0)
			draw_line(Vector2(5, -14), Vector2(5, -11), Color(0.95, 0.8, 0.3), 1.5)


## 会动的扫帚：在房间里来回扫，碰到就扫脚底（还会发出声音）
class Broom extends Node2D:
	var room: PalaceServants
	var home := Vector2.ZERO
	var _t := 0.0
	var _cool := 0.0

	func step(delta: float) -> void:
		_t += delta
		_cool = maxf(0.0, _cool - delta)
		position = home + Vector2(sin(_t * PalaceServants.BROOM_SPEED / PalaceServants.BROOM_RANGE) * PalaceServants.BROOM_RANGE, 0)
		queue_redraw()
		if _cool > 0.0:
			return
		for c in room.members():
			var pc := c as PlayableCharacter
			if not Downed.is_downed(pc) and pc.global_position.distance_to(position) <= 12.0:
				_cool = 2.0
				var h := HitData.make_tickle(self, 6.0)
				h.zone = "sole"
				pc.receive_hit(h)
				PalaceRoom.say_random(pc, "broom")
				if StealthDirector.current:
					StealthDirector.current.noise(position, 70.0)
				return

	func _draw() -> void:
		var tilt := sin(_t * 3.0) * 0.3
		var top := Vector2(0, -26).rotated(tilt)
		draw_line(Vector2(0, -4), top, Color(0.55, 0.38, 0.22), 2.0)
		var base := Vector2(0, -4)
		for k in 5:
			draw_line(base + Vector2(-5 + k * 2.5, 0), base + Vector2(-6 + k * 3.0, 6), Color(0.9, 0.8, 0.5), 1.5)

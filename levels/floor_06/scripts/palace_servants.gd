class_name PalaceServants
extends PalaceRoom
## 第四章②·仆人回廊（floor_06_palace_servants，等距；潜入：地图里的 StealthDirector（on_caught = palace）+ 人偶女仆 guard_patrol（maid 图集、doll））：
##   被发现 → StealthDirector._caught → on_caught_static → 小剧场 servants_caught_first（第一次长）/ servants_caught → 回入口重来；
##   木箱 / 帘子（hides）按 E 躲；hide_event 那一处躲进去会触发「千手裤发作、粉色公主自告奋勇去引开」的小剧场 servants_hide（CG，只是剧情）；
##   尘土堆（dust）：走过去打喷嚏（声音引来人偶，StealthDirector.noise）；会动的扫帚（brooms）：在房间里来回扫，碰到就扫脚底（也有声音）；
##   F：丢出去的是挠脚鼠（StealthDirector.throw_stone，穿着鼠鼠装时）；旧排班表 / 日记（clues，线索）；
##   女仆长人偶（head_maid，站岗的 guard_patrol）守着钥匙：拉唤人铃（bell，对话 call palace_bell）她会过去查看，趁机拿钥匙（key，call palace_key → KEY_FLAG）；
##   出口 east 要钥匙。
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
	await CG.play_theater(id)
	reset_to(world(cells("start")[0]))
	if StealthDirector.current:
		StealthDirector.current.reset()
	_defeat_busy = false


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

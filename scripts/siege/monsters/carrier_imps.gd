class_name CarrierImps
extends SiegeMonster
## 搬运小鬼队：在战场上转悠；粉色公主失控（闷笑到失控 2）时一群小鬼冲过去把她抬起来，往最近的敌塔（没有就往敌方区域）运——
## 运到了就把她关进塔里挠 LOCK_TIME 秒再扔出来。蓝色公主可以放冰链把人拉回来，冻住 / 打倒小鬼也会把人放下。

const CARRY_SPEED := 42.0
const LOCK_TIME := 8.0
const GRAB_RANGE := 120.0

var carrying: PlayableCharacter
var _dest := Vector2.ZERO


func siege_wander(_mind: SiegeMind, delta: float) -> bool:
	if director == null:
		return false
	var p := director.pink
	if carrying:
		_carry_tick(delta)
		return true
	if p and is_instance_valid(p) and p.is_alive() and p.laugh and p.laugh.stage() == "helpless_2" \
			and not p.get_meta("siege_dragged", false) and p.global_position.distance_to(global_position) < GRAB_RANGE:
		var d := p.global_position - global_position
		if d.length() < 12.0:
			_pick_up(p)
		else:
			_move(d.normalized(), stats.chase_speed * 1.4, delta)
		return true
	return false


func _pick_up(p: PlayableCharacter) -> void:
	if p.status == null or not p.status.grab(self, 12.0, 16):
		return
	carrying = p
	p.set_meta("siege_dragged", true)
	p.set_meta("siege_dragger", self)
	p.add_buff("lifted", 12.0)
	var best: Node2D = null
	for t in get_tree().get_nodes_in_group("siege_enemy_tower"):
		if best == null or (t as Node2D).global_position.distance_to(global_position) < best.global_position.distance_to(global_position):
			best = t
	_dest = best.global_position + Vector2(0, 8) if best else Vector2(global_position.x, director.map_size().y - 40.0)
	SpeechBubble.say(p, "放、放我下来——！", 28.0, 1.6)
	Audio.play("grab", -4.0, 0.1)


func _carry_tick(delta: float) -> void:
	var p := carrying
	if not is_instance_valid(p) or not p.is_alive() or p.status == null or not p.status.is_grabbed_by(self) or is_stunned():
		drop()
		return
	var d := _dest - global_position
	velocity = Vector2.ZERO if p.get_meta("siege_chained", false) else d.normalized() * CARRY_SPEED * stat_mul("speed")
	p.global_position = global_position + Vector2(0, -6)
	if randf() < delta * 8.0:
		Fx.burst(get_parent(), global_position + Vector2(randf_range(-8, 8), 2), "dust", 1, 20.0, 0.5, Vector2(0, 10))
	if randf() < delta * 0.4:
		SpeechBubble.say(self, "嘿咻、嘿咻！", 24.0, 1.0)
	if randf() < delta * 2.0:
		p.receive_hit(HitData.make_tickle(self, 4.0))
	if d.length() < 10.0:
		_lock_up(p)


## 关进塔里挠一阵再扔出来（SiegeDirector.lock_up）。
func _lock_up(p: PlayableCharacter) -> void:
	var pos := global_position
	drop()
	SpeechBubble.say(self, "关进去咯！", 26.0, 1.4)
	if director:
		director.lock_up(p, pos, LOCK_TIME)


## 放下（被冰链拉走 / 被冻住 / 被打倒）。
func drop() -> void:
	var p := carrying
	carrying = null
	if p and is_instance_valid(p):
		if p.has_meta("siege_dragger") and p.get_meta("siege_dragger") == self:
			p.set_meta("siege_dragged", false)
			p.set_meta("siege_dragger", null)
		if p.status and p.status.is_grabbed_by(self):
			p.status.release(true)
		p.remove_buff("lifted")


func release_drag() -> void:
	drop()


func _on_died() -> void:
	drop()
	super()

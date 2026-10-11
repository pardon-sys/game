class_name SuckJelly
extends SiegeMonster
## 魔力吸吸水母：飘着（不挡路），直接飘上城墙吸住蓝色公主（连按挣脱）——吸着的时候她的法术放不出来；
## 她一抬手想施法，水母就专挠腋下（SiegeSpells.cast 里被吸住时打断并调 on_cast_try）。

var _held: PlayableCharacter


func _setup() -> void:
	super()
	collision_mask = 0
	z_index = 8
	tickle_zones = {"armpit": 3.0, "waist": 1.0}


func siege_wander(_mind: SiegeMind, delta: float) -> bool:
	if director == null:
		return false
	var b := director.blue
	if _held and is_instance_valid(_held) and _held.status and _held.status.is_grabbed_by(self):
		velocity = Vector2.ZERO
		global_position = _held.global_position + Vector2(0, -14)
		return true
	_held = null
	if b and is_instance_valid(b) and b.is_alive() and not Downed.is_downed(b):
		var d := b.global_position + Vector2(0, -8) - global_position
		velocity = d.normalized() * stats.chase_speed * stat_mul("speed") + Vector2(0, sin(_t * 3.0) * 8.0)
		if d.length() < 10.0 and b.status and not b.status.is_grabbed():
			if b.status.grab(self, 4.0, 12):
				_held = b
				SpeechBubble.say(b, "……吸、吸住了。……魔力……", 28.0, 1.6)
				Audio.play("chomp", -4.0, 0.1, 1.3)
	return true


## 被吸着的她想施法：专挠腋下。
func on_cast_try(c: PlayableCharacter) -> void:
	var h := HitData.make_tickle(self, 8.0)
	h.zone = "armpit"
	h.special = true
	c.receive_hit(h)
	SpeechBubble.say(c, "……一、一抬手……腋下……！", 28.0, 1.4)

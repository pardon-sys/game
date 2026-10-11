class_name HugBear
extends SiegeMonster
## 拥抱小熊：从正面扑上来抱住粉色公主（连按挣脱），抱着的时候一直挠胸口和腋下；
## 蓝色公主的冰锥打中它就松手（还会愣一下）。

var _held: PlayableCharacter


func _setup() -> void:
	super()
	tickle_zones = {"chest": 3.0, "armpit": 2.0}


func _on_tickle_performed(t: Node) -> void:
	super(t)
	var c := t as PlayableCharacter
	if c == null or c.character_id != "pink" or c.status == null or c.status.is_grabbed():
		return
	if c.status.grab(self, 4.0, 12):
		_held = c
		SpeechBubble.say(c, "被、被抱住了——胸口……哈哈！", 28.0, 1.6)
		Fx.burst(get_parent(), c.global_position + Vector2(0, -10), "heart", 5, 30.0, 0.5, Vector2(0, -10), Color(1, 0.7, 0.85))


func _tick(delta: float) -> void:
	super(delta)
	if _held and is_instance_valid(_held) and _held.status and _held.status.is_grabbed_by(self):
		velocity = Vector2.ZERO
		global_position = global_position.move_toward(_held.global_position + Vector2(0, 2), 40.0 * delta)
	else:
		_held = null


func receive_hit(hit: HitData) -> bool:
	var ok := super(hit)
	if ok and hit.source is PlayableCharacter and (hit.source as PlayableCharacter).character_id == "blue" and _held:
		if _held.status and _held.status.is_grabbed_by(self):
			_held.status.release(true)
		_held = null
		stun(1.5)
	return ok

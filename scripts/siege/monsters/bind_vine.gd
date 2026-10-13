class_name BindVine
extends SiegeMonster
## 捆绑藤怪：慢吞吞地爬，碰到公主就缠住她（连按挣脱），缠着的时候强制给她穿上一件束缚类 / 挠痒类的临时痒痒装备，
## 藤尖一直挠。清凉雪花能把人解开。

const ITEMS := ["equip_t_feather_shackles", "equip_t_thigh_strap", "equip_t_knead_tights", "equip_t_fluff_bra", "equip_t_toe_brush"]

var _held: PlayableCharacter


func _on_tickle_performed(t: Node) -> void:
	super(t)
	var c := t as PlayableCharacter
	if c == null or not c.status or c.status.is_grabbed():
		return
	if c.status.grab(self, 3.5, 10):
		_held = c
		var id: String = ITEMS.pick_random()
		var how := Equipment.force(c.character_id, id, Equipment.FORCE_TIME * WaveFeatures.mul_of("equip_time"))
		Audio.play("vine", -3.0, 0.1)
		SpeechBubble.say(c, "藤、藤蔓缠上来了！" if c.character_id == "pink" else "……缠、缠住了。", 28.0, 1.6)
		if how != "" and director and director.intel:
			director.intel.discover(id)


func _tick(delta: float) -> void:
	super(delta)
	if _held and is_instance_valid(_held) and _held.status and _held.status.is_grabbed_by(self):
		velocity = Vector2.ZERO
		_held.global_position = _held.global_position.move_toward(global_position + Vector2(0, 6), 30.0 * delta)
	else:
		_held = null

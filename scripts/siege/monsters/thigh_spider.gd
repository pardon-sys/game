class_name ThighSpider
extends SiegeMonster
## 腿根爬爬蛛：走到墙下就爬上城墙，专门找蓝色公主的大腿和屁股挠（部位权重只有大腿 / 屁股）；
## 她穿着千手痒痒裤时引发「裤子共振」——蜘蛛一挠，裤子立刻跟着发作一次。

var _retry := 0.0


func _setup() -> void:
	super()
	tickle_zones = {"thigh": 3.0, "butt": 2.0}


func siege_wander(_mind: SiegeMind, delta: float) -> bool:
	if on_wall:
		wall_hunt(delta)
		return true
	if director and global_position.y <= director.wall_foot_y() + 16.0:
		_retry -= delta
		if _retry <= 0.0 and not climb_wall():
			_retry = 0.6
			_move(Vector2(1.0 if randf() < 0.5 else -1.0, 0.0), stats.chase_speed, delta)
		return true
	return false


func _on_tickle_performed(t: Node) -> void:
	super(t)
	var c := t as PlayableCharacter
	if c and c.has_method("pants_flare") and c.has_buff("thousand_pants"):
		c.call("pants_flare", ["knead", "climb"].pick_random())
		var fx := EquipFx.of(c)
		if fx:
			fx.flare(Equipment.PANTS_ID, "thigh", "resonance", false)

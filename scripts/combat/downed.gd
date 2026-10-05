class_name Downed
extends Node2D
## 倒地（双人模式）：笑倒的人躺在地上（失控二），头顶一圈倒计时（TIME = 45 秒）；附近的小怪围过来挠，倒计时走得更快。
## 搭档走到旁边按住 E（interact）REVIVE_TIME 秒救起（进度圈；搭档被打 / 被抓就重来），救起后半血、闷笑清空、短暂无敌。
## 倒计时到了、或者两个人都倒下 → Duo.director.on_defeat("downed")。玩家正在操控的人倒下时自动切到搭档。
## 挂在角色下面（节点名 Downed），Downed.start(角色) 开始。

const TIME := 45.0
const REVIVE_TIME := 2.0
const REVIVE_RANGE := 22.0
const MOB_RANGE := 40.0

var who: PlayableCharacter
var time_left := TIME
var revive := 0.0
var _ring: Line2D
var _rev_ring: Line2D
var _tick := 0.0
var _done := false


static func is_downed(c: Node) -> bool:
	return is_instance_valid(c) and c.get_node_or_null("Downed") != null


static func start(c: PlayableCharacter) -> Downed:
	if is_downed(c):
		return c.get_node("Downed")
	var d := Downed.new()
	d.name = "Downed"
	d.who = c
	c.add_child(d)
	return d


func _ready() -> void:
	z_index = 6
	position = Vector2(0, -30)
	_ring = _arc_line(Color(1, 0.45, 0.55), 2.0)
	_rev_ring = _arc_line(Color(0.6, 1, 0.75), 2.0)
	if who.emotion:
		who.emotion.request("helpless_2", 999.0, false)
	SpeechBubble.say(who, "……", 26.0)
	var other := Duo.partner_of(who)
	if who == GameState.player and other and other.is_alive() and not Downed.is_downed(other):
		GameState.switch_control(other)
		GameState.notify("%s倒下了！走到旁边按住 E 救她" % _name_of(who))
	if Duo.all_down() or (Duo.director and Duo.director.get("instant_defeat") == true):
		_fail()


func _arc_line(c: Color, w: float) -> Line2D:
	var l := Line2D.new()
	l.width = w
	l.default_color = c
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	l.material = mat
	add_child(l)
	return l


static func _arc(r: float, frac: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := maxi(2, int(24 * frac) + 1)
	for i in n:
		var a := -PI / 2.0 + TAU * frac * float(i) / float(n - 1)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _process(delta: float) -> void:
	if _done or not is_instance_valid(who) or GameState.in_dialogue:
		return
	var mobs := 0
	for m in get_tree().get_nodes_in_group("enemy"):
		if m is Monster and m.is_alive() and (m as Node2D).global_position.distance_to(who.global_position) < MOB_RANGE:
			mobs += 1
	time_left -= delta * (1.0 + 0.5 * mobs)
	# 小怪围着挠：挠痒特效 + 她笑
	_tick -= delta
	if mobs > 0 and _tick <= 0.0:
		_tick = 0.7
		Fx.burst(who.get_parent(), who.global_position + Vector2(0, -8), "feather", 3, 30.0, 0.4, Vector2(0, 20))
		Characters.scope(who.character_id)
		var lines := ReactionDB.lines("", "helpless_2")
		Characters.unscope()
		if not lines.is_empty() and randf() < 0.35:
			SpeechBubble.say(who, str(lines.pick_random()).left(14), 26.0)
	# 搭档按住 E 救援
	var other := Duo.partner_of(who)
	var helping := other != null and other.is_alive() and not Downed.is_downed(other) \
		and other.global_position.distance_to(who.global_position) <= REVIVE_RANGE \
		and other.controller != null and other.controller.is_action_pressed(&"interact") \
		and not (other.status and other.status.is_grabbed()) and other.state != PlayableCharacter.State.HURT
	revive = revive + delta if helping else 0.0
	_ring.points = _arc(9.0, clampf(time_left / TIME, 0.0, 1.0))
	_rev_ring.points = _arc(6.0, clampf(revive / REVIVE_TIME, 0.0, 1.0)) if revive > 0.0 else PackedVector2Array()
	if revive >= REVIVE_TIME:
		_revive()
	elif time_left <= 0.0 or Duo.all_down():
		_fail()


func _revive() -> void:
	_done = true
	var c := who
	c.revive()
	if c.health:
		c.health.set_hp(maxi(1, int(ceil(c.health.max_hp / 2.0))))
	c._set_state(PlayableCharacter.State.IDLE)
	c.set_invulnerable(2.0, true)
	if c.emotion:
		c.emotion.request("normal", 0.1, false)
	Fx.burst(c.get_parent(), c.global_position + Vector2(0, -8), "heart", 8, 40.0, 0.6, Vector2(0, -20))
	Audio.play("chime", -4.0, 0.0, 1.2)
	SpeechBubble.say(c, "……谢谢。" if c.character_id == "blue" else "得救了……！", 26.0)
	queue_free()


func _fail() -> void:
	_done = true
	if Duo.director and Duo.director.has_method("on_defeat"):
		Duo.director.on_defeat("downed")


static func _name_of(c: Node) -> String:
	return str(c.call("display_name")) if c.has_method("display_name") else "公主"

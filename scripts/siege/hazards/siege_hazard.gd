class_name SiegeHazard
extends Node2D
## 攻防战的大范围陷阱基类（SiegeDirector 按波次的 hazards 时间表放出来：{t, kind}）。
## 先有 WARN 秒预警（地上的圈 / 线），然后生效 life 秒，到时间淡出删掉。挠痒的来源键 = hazard_<种类>（reaction_key），三来源组合认它。
## 子类：tornado 痒痒龙卷风 / bubbles 痒痒泡泡潮 / link_rune 痒感连线符文 / broom 城墙羽毛扫帚 / fog 痒痒迷雾 /
##       wall_vine 城墙爬藤（牺牲互救）/ sticky_net 黏网（牺牲互救）

const WARN := 1.2

var director: SiegeDirector
var reaction_key := ""
var life := 15.0
var warned := false
var _warn_left := WARN
var _t := 0.0


static func make(kind: String) -> SiegeHazard:
	match kind:
		"tornado": return HazardTornado.new()
		"bubbles": return HazardBubbles.new()
		"link_rune": return HazardLinkRune.new()
		"broom": return HazardBroom.new()
		"fog": return HazardFog.new()
		"wall_vine": return HazardWallVine.new()
		"sticky_net": return HazardStickyNet.new()
	return null


func _ready() -> void:
	add_to_group("siege_temp")
	add_to_group("siege_hazard")
	director = SiegeDirector.current
	_begin()


## 子类：出现时（画预警）。
func _begin() -> void:
	pass


## 子类：生效后每帧。
func _active(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	if director == null or director.state != "fight" and director.state != "prep":
		return
	if _warn_left > 0.0:
		_warn_left -= delta
		if _warn_left <= 0.0:
			warned = true
			_on_start()
		queue_redraw()
		return
	life -= delta
	_t += delta
	_active(delta)
	queue_redraw()
	if life <= 0.0:
		_end()


func _on_start() -> void:
	pass


func _end() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
	set_process(false)


func tickle(c: PlayableCharacter, amount: float, zone := "") -> void:
	if c == null or not is_instance_valid(c) or not c.is_alive() or Downed.is_downed(c):
		return
	var h := HitData.make_tickle(self, amount)
	h.zone = zone
	c.receive_hit(h)


func chars() -> Array[PlayableCharacter]:
	var out: Array[PlayableCharacter] = []
	for c: PlayableCharacter in [director.pink, director.blue]:
		if c and is_instance_valid(c) and c.is_alive() and not Downed.is_downed(c):
			out.append(c)
	return out

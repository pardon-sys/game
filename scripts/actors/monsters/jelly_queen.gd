class_name JellyQueen
extends Monster
## 魔力水母女王（第四层 Boss）：慢慢飘着追，近身用触须蛰挠（暴击率 stats.special_chance = 0.35）。
##   每 summon_interval 秒召唤 summon_count 只魔力水母（场上最多 max_jellies 只）。
##   每 puddle_interval 秒在身下留一滩疲倦水液（怪物踩到获得「力量」）。
##   血量低于一半：「魔力雨」——战斗中公主每秒 +rain_percent% 魔力疲倦，场上飘着紫色雨滴。
##   死亡时打开 open_on_death 组的 Switchable（Boss 房的门），召唤出的水母一起散掉。

const JELLY_SCENE := "res://scenes/actors/monsters/mana_jelly.tscn"
const DROP_TEX := preload("res://assets/generated/mana_drop.png")

@export var summon_interval := 8.0
@export var summon_count := 2
@export var max_jellies := 4
@export var puddle_interval := 6.0
@export var puddle_life := 14.0
@export var rain_percent := 0.6
@export var open_on_death := ""

var raining := false
var _announced := false
var _summon_cd := 3.0
var _puddle_cd := 4.0
var _drop_t := 0.0


func _setup() -> void:
	super()
	sprite.hframes = 2


func _tick(delta: float) -> void:
	if not _announced and state == State.CHASE:
		_announced = true
		GameState.boss_changed.emit(self)
		maybe_taunt(true)
	super(delta)
	if not _announced or GameState.in_dialogue or not is_alive() or is_stunned():
		return
	_update_summon(delta)
	_update_puddle(delta)
	_update_rain(delta)


func _update_summon(delta: float) -> void:
	_summon_cd -= delta
	if _summon_cd > 0.0:
		return
	_summon_cd = summon_interval
	var alive := get_tree().get_nodes_in_group("summoned_jelly").size()
	var n := mini(summon_count, max_jellies - alive)
	if n <= 0:
		return
	for i in n:
		var j: Monster = load(JELLY_SCENE).instantiate()
		j.add_to_group("summoned_jelly")
		get_parent().add_child(j)
		j.global_position = global_position + Vector2(-26.0 + 52.0 * i, 20.0)
		Fx.puff(get_parent(), j.global_position + Vector2(0, -6))
	Audio.play("bubble", -2.0, 0.05, 0.7)
	SpeechBubble.say(self, "孩子们，去陪她玩～", 50.0)


func _update_puddle(delta: float) -> void:
	_puddle_cd -= delta
	if _puddle_cd > 0.0:
		return
	_puddle_cd = puddle_interval
	FatiguePuddle.spawn(get_parent(), global_position, puddle_life, 22.0)


## 半血后的魔力雨：公主在战斗范围内时疲倦持续上涨。
func _update_rain(delta: float) -> void:
	var was := raining
	raining = health.hp <= health.max_hp / 2
	if not raining:
		return
	if not was:
		SpeechBubble.say(self, "魔力雨，落下来吧～", 50.0)
		Audio.play("rune", -2.0, 0.0, 0.8)
		GameState.notify("魔力雨：魔力疲倦在持续上涨！")
	var p := GameState.player
	if not is_instance_valid(p) or not p.is_alive() or global_position.distance_to(p.global_position) > stats.lose_range:
		return
	if p.fatigue and MagicFatigue.accumulate:
		p.fatigue.add_percent(rain_percent * delta)
	_drop_t -= delta
	if _drop_t <= 0.0:
		_drop_t = 0.08
		_spawn_drop(p.global_position + Vector2(randf_range(-80, 80), randf_range(-60, 40)))


func _spawn_drop(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = DROP_TEX
	s.z_index = 20
	s.scale = Vector2(2, 2)
	get_parent().add_child(s)
	s.global_position = pos + Vector2(0, -24)
	var tw := s.create_tween()
	tw.tween_property(s, "global_position:y", pos.y, 0.35)
	tw.parallel().tween_property(s, "modulate:a", 0.2, 0.35)
	tw.tween_callback(s.queue_free)


func _move(dir: Vector2, speed: float, delta: float) -> void:
	if dir != Vector2.ZERO:
		dir = dir.rotated(sin(_t * 1.2) * 0.4)
	super(dir, speed, delta)


func _animate(_delta: float) -> void:
	sprite.frame = int(_t * 2.5) % 2
	sprite.offset.y = -16.0 + roundf(sin(_t * 2.0) * 1.5)


func _on_died() -> void:
	raining = false
	for j in get_tree().get_nodes_in_group("summoned_jelly"):
		if j is Actor and (j as Actor).is_alive():
			(j as Actor).health.damage(99)
	if open_on_death != "":
		for n in get_tree().get_nodes_in_group(open_on_death):
			if Contracts.is_switchable(n):
				n.set_active(true)
	super()

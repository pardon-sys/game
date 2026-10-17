class_name HazardStickyNet
extends SiegeHazard
## 黏网（牺牲互救）：敌方区域抛出一张大黏网，落点先亮预警（这时躲开还来得及）；罩住粉色公主后她动不了，网眼里伸出小手挠。
## 救法：蓝色公主走到城墙上她正上方，探出城垛用冰刃割网（SiegeDirector.rescue：要 LEAN 秒）——
## 探出去的时候大腿和屁股露在墙外，被爬墙的怪挠（她付出的代价）。没人救的话 life 秒后网自己松开。
## 罩住的同时网里爆出伏兵（粉色公主挠脚鼠 / 蓝色公主腿根爬爬蛛）围上来。

const R := 24.0
## 黏网里的伏兵（第十轮）：罩住公主时网里爆出 AMBUSH_N 只——粉色公主是挠脚鼠，蓝色公主是腿根爬爬蛛——围上来挠
const AMBUSH_N := 3

var caught: PlayableCharacter
var _tt := 0.0
## 测试用：网里爆出来的伏兵
var ambushed: Array[Monster] = []


func _begin() -> void:
	reaction_key = "hazard_net"
	life = 16.0
	var p := director.pink
	if p and is_instance_valid(p):
		global_position = p.global_position
	SiegeFx.ring(get_parent(), global_position, R + 4.0, Color(0.9, 0.85, 0.6, 0.9), WARN)
	Audio.play("swish", -4.0, 0.0, 0.6)


func _on_start() -> void:
	var p := director.pink
	if p and is_instance_valid(p) and not director.is_on_wall(p) and p.global_position.distance_to(global_position) < R and p.status:
		if p.status.grab(self, 999.0, 99999):
			caught = p
			p.set_meta("siege_netted", true)
			SpeechBubble.say(p, "黏、黏网！动不了了——网眼里有手！", 28.0, 1.8)
			GameState.rule("粉色公主被黏网罩住了！蓝色公主到她正上方的城墙上探出去割网！")
			ambushed = ambush(global_position, ["rat" if p.character_id == "pink" else "thigh_spider"], AMBUSH_N, p)
			return
	life = 0.6


func _active(delta: float) -> void:
	if caught == null or not is_instance_valid(caught):
		return
	caught.global_position = caught.global_position.move_toward(global_position, 20.0 * delta)
	# 黏液往下滴
	if randf() < delta * 3.0:
		Fx.burst(get_parent(), global_position + Vector2(randf_range(-R, R), -R), "drop", 1, 10.0, 0.6, Vector2(0, 80), Color(0.95, 0.9, 0.6))
	_tt -= delta
	if _tt <= 0.0:
		_tt = 0.6
		tickle(caught, 4.0, ["sole", "waist", "armpit"].pick_random())


func free_caught() -> void:
	if caught and is_instance_valid(caught):
		caught.set_meta("siege_netted", false)
		if caught.status and caught.status.is_grabbed_by(self):
			caught.status.release(true)
	caught = null
	life = 0.0


func _end() -> void:
	free_caught()
	super()


func _draw() -> void:
	if not warned or caught == null:
		return
	var c := Color(0.95, 0.9, 0.7, 0.8)
	for i in range(-2, 3):
		draw_line(Vector2(i * 7, -R - 10), Vector2(i * 7, 4), c, 1.0)
		draw_line(Vector2(-R, -10 + i * 6), Vector2(R, -10 + i * 6), c, 1.0)

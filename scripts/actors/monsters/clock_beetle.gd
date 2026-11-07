class_name ClockBeetle
extends Monster
## 发条挠痒虫（钟楼一层 / 三层；PalaceClock 在 beetle_nests 标记从齿轮缝里放出来）：
##   贴上脚踝 → 定身 ROOT_TIME 秒并挠脚心；一下就打死；发条只够转 WIND 秒，到时自己停下（翻倒、弹出弹簧）然后消失。
## 图：assets/generated/clock_beetle.png（4 帧：三帧爬 + 一帧翻倒）。数值见 data/monsters/clock_beetle.tres。

const WIND := 14.0
const ROOT_TIME := 1.0

var wind_left := WIND
var _anim_t := 0.0
var _stopped := false


func _tick(delta: float) -> void:
	if _stopped:
		return
	wind_left -= delta
	if wind_left <= 0.0:
		wind_down()
		return
	super(delta)


## 发条转完：翻倒、弹出弹簧，过一会儿消失（不掉东西）
func wind_down() -> void:
	_stopped = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	sprite.frame = 3
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func stopped() -> bool:
	return _stopped


func _animate(delta: float) -> void:
	_anim_t += delta
	if _stopped:
		return
	sprite.frame = int(_anim_t * (10.0 if velocity.length() > 5.0 else 3.0)) % 3
	if velocity.x != 0.0:
		sprite.flip_h = velocity.x > 0.0


## 贴上来挠一下：顺便把脚踝卡住一秒
func _on_tickle_performed(t: Node) -> void:
	var a := t as Actor
	if a and a.get("status"):
		a.status.apply_root(ROOT_TIME)

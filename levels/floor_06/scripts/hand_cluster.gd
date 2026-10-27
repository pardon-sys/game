class_name HandCluster
extends Node2D
## 手印团（骑士篇支线「手印样本」·地窖）：一大团手印挤在一起蠕动。冻住它（蓝色公主 J / 千手解放）或者拍散它（粉色公主 J 打它），
## 就「啪」地裂成 SPLIT 块手印碎片（HandShard，不带盖子，直接在外面爬），四散逃开。可操作角色走到 GRAB_R 以内：伸出手挠她一下（COOL 秒一次）。
## 信号 split_into(碎片数组)。测试：split()、touch(角色)。

signal split_into(shards: Array)

const SPLIT := 3
const GRAB_R := 14.0
const COOL := 1.6
const PINK_LAUGH := 0.03
const BLUE_LAUGH := 0.07
const HIT_R := 22.0

var lines := {}
var done := false
var _t := 0.0
var _cool := 0.0


func _ready() -> void:
	z_index = 1
	add_to_group(PantsBurst.KNIGHT_GROUP)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func _process(delta: float) -> void:
	_t += delta
	_cool = maxf(0.0, _cool - delta)
	queue_redraw()
	if done or GameState.in_dialogue or GameState.in_cutscene:
		return
	for c in get_tree().get_nodes_in_group("player_chars"):
		if c.global_position.distance_to(global_position) <= GRAB_R and _cool <= 0.0:
			touch(c)


## 挠一下靠近的人：粉色公主轻、蓝色公主挠大腿重
func touch(c: PlayableCharacter) -> void:
	_cool = COOL
	var is_blue := c is BluePrincess
	var zone := "thigh" if is_blue else "sole"
	ZoneFx.play(zone, c.get_parent(), ZoneFx.body_point(c, zone), 1.0, false)
	if c.laugh:
		c.laugh.add(c.laugh.max_value * (BLUE_LAUGH if is_blue else PINK_LAUGH))


## 被打中（任务在粉色公主出手时问）
func try_hit(by: PlayableCharacter) -> bool:
	if done or by.global_position.distance_to(global_position) > HIT_R:
		return false
	split()
	return true


func on_pants_burst(burst: PantsBurst) -> void:
	if not done and global_position.distance_to(burst.global_position) <= PantsBurst.RADIUS:
		split()


## 冰晶结界：冻裂成碎片
func on_ice_barrier(center: Vector2, r: float, _time: float) -> void:
	if not done and global_position.distance_to(center) <= r:
		split()


## 冻住 / 拍散：裂成几块碎片四散
func split() -> Array:
	if done:
		return []
	done = true
	var out := []
	for i in SPLIT:
		var at := global_position + Vector2.from_angle(TAU * i / SPLIT + 0.4) * 22.0
		var s := HandShard.make(get_parent(), at, "none", lines)
		s.state = "crawl" if i == 0 else "hidden"
		out.append(s)
	Audio.play("tickle_special", -6.0)
	Fx.burst(get_parent(), global_position, "drop", 10, 30.0, 0.5, Vector2(0, -6))
	var pool: Array = lines.get("split_line", [])
	if not pool.is_empty():
		GameState.princess_reacted.emit(str(pool[0]), 2.6)
	split_into.emit(out)
	queue_free()
	return out


func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, Color(CurseHand.COL, 0.15))
	for i in 7:
		var ang := TAU * i / 7.0 + _t * 0.8
		var at := Vector2.from_angle(ang) * (5.0 + 2.0 * sin(_t * 3.0 + i))
		CurseHand.draw_hand(self, at, 0.7, CurseHand.COL, CurseHand.COL_D, 0.7, sin(_t * 10.0 + i), ang - PI * 0.35)
	CurseHand.draw_hand(self, Vector2.ZERO, 0.9, CurseHand.COL, CurseHand.COL_D, 0.85, sin(_t * 8.0))

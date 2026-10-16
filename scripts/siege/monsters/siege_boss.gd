class_name SiegeBoss
extends TickleTroll
## 攻防战小 Boss 的共用规则，从 TrollGeneral 提取：塔伤害 25%、半场边界、建筑脱困。
## 技能 / 出场 / 狂暴仍由具体 Boss 管理；抓取、挣脱和反击窗口沿用 TickleTroll。

var director: SiegeDirector
var skill := ""
var raged := false
## 冰塔 / 小雪人打它只有 TOWER_MULT 的伤害（小数部分攒着）
const TOWER_MULT := 0.25
var _tower_frac := 0.0
## 被建筑（冰塔、敌塔、道具）卡住：STUCK_SIDE 秒走不动 → 往侧面绕 SIDE_TIME 秒；绕了 PASS_AFTER 次还是被挡（中间没顺畅走过 FREE_RESET 秒）
## 或者一直卡着 STUCK_PASS 秒 → 穿过去（直到完全出来）
const STUCK_SIDE := 0.5
const SIDE_TIME := 0.8
const STUCK_PASS := 2.0
const PASS_TIME := 1.2
const PASS_AFTER := 2
const FREE_RESET := 1.0
var _blocked_n := 0
var _free_t := 0.0
var _stuck_t := 0.0
var _side_t := 0.0
var _side_dir := Vector2.ZERO
var _pass_t := 0.0
## 绕开 / 穿过去的次数（测试用）
var unstuck := 0
var _mask0 := 1


func _setup() -> void:
	_mask0 = collision_mask if collision_mask != 0 else 1
	super()
	director = SiegeDirector.current
	add_to_group("siege_boss")


func make_mind(_d: Node) -> RefCounted:
	return null


func receive_hit(hit: HitData) -> bool:
	var tower_hit := hit.from_tower or (is_instance_valid(hit.source) and (hit.source is IceTower or hit.source is Snowman))
	if hit.kind == HitData.Kind.ATTACK and tower_hit and hit.damage > 0:
		# 被无敌拒绝的命中不累计；只缩放副本，保留法术标签、来源位置等。
		if is_invulnerable() or health == null:
			return false
		var total := _tower_frac + hit.damage * TOWER_MULT
		var damage := int(floorf(total))
		if damage <= 0:
			_tower_frac = total
			flash(Color(0.7, 0.9, 1.0), 0.08)
			return false
		var reduced := hit.copy()
		reduced.damage = damage
		var accepted := super(reduced)
		if accepted:
			_tower_frac = total - damage
		return accepted
	return super(hit)


## 卡住检测：想走却几乎没动 → 先往侧面绕，还卡着就暂时穿过建筑。
func _unstick(delta: float) -> void:
	if _pass_t > 0.0:
		_pass_t -= delta
		if _pass_t <= 0.0:
			# 还压在建筑里：接着穿（直到完全出来）
			collision_mask = _mask0
			if test_move(global_transform, Vector2.ZERO) or test_move(global_transform, velocity.normalized() * 2.0):
				collision_mask = 0
				_pass_t = 0.3
	var want := velocity.length()
	# 墙下（狂暴后本来就要贴着墙打）不算卡住，也不能穿进城墙里
	var at_wall := director != null and global_position.y < director.wall_foot_y() + 40.0
	if want < 10.0 or skill in ["leap", "grab"] or at_wall:
		_stuck_t = maxf(0.0, _stuck_t - delta)
		return
	var blocked := get_real_velocity().length() < want * 0.25
	if blocked:
		_stuck_t += delta
		_free_t = 0.0
	else:
		_stuck_t = maxf(0.0, _stuck_t - delta * 2.0)
		if _side_t <= 0.0:
			_free_t += delta
			if _free_t > FREE_RESET:
				_blocked_n = 0
	if _side_t > 0.0:
		_side_t -= delta
		velocity = _side_dir * want
	elif _stuck_t > STUCK_SIDE and skill == "":
		_blocked_n += 1
		_stuck_t = 0.0
		unstuck += 1
		if _blocked_n >= PASS_AFTER:
			_stuck_t = STUCK_PASS + 1.0   # 绕了几次还被挡：直接穿过去
		else:
			_side_t = SIDE_TIME
			var o := velocity.orthogonal().normalized()
			# 第一次随机挑一边，之后接着往同一边绕
			_side_dir = o if randf() < 0.5 else -o
	if _stuck_t > STUCK_PASS and _pass_t <= 0.0:
		_stuck_t = 0.0
		_side_t = 0.0
		_blocked_n = 0
		_pass_t = PASS_TIME
		collision_mask = 0
		unstuck += 1
		Fx.burst(get_parent(), global_position + Vector2(0, -10), "dust", 10, 40.0, 0.5, Vector2(0, 40))


## 能走到的最高处（y 最小）：狂暴前是地图半高，狂暴后不限（能一路打到墙下）。
func min_y() -> float:
	if raged or director == null:
		return -INF
	return maxf(director.map_size().y / 2.0, director.wall_foot_y() + 40.0)



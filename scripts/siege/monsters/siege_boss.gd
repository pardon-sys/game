class_name SiegeBoss
extends TickleTroll
## 攻防战小 Boss 的基类（第 3 波 TrollGeneral、第 6 波 GaleBear、第 9 波 PuppetMaster、第 12 波 CarnivalFortress）。
## 共用规则：冰塔 / 小雪人伤害 ×TOWER_MULT、狂暴前只在下半场（min_y）、被建筑卡住先绕再穿（_unstick）。
## 共用的技能框架（具体技能由子类写）：
##   技能数据在 data/siege/bosses.json（tools/build/gen_siege_bosses.py 生成）：boss_key 选哪一段，
##   skill_info / skill_name / skill_cd / skill_warn / skill_shout 读；cds 冷却（tick_cooldowns / put_on_cooldown）、used / last_used 记录（mark_used）。
##   预警节点 track_warn、持续场地 register_field（clear_warns / clear_fields 一起收掉，出树时自动收）。
##   strike_tools：机关工具挠一下（走 make_tickle，每个目标 TOOL_GAP 秒内只算一次）。
##   出场 / 狂暴 / 打倒的横幅 announce("intro" / "rage" / "defeat")、护卫 spawn_escorts、打倒奖励 reward_defeat。
## 抓取、挣脱和反击窗口沿用 TickleTroll。

const DATA_PATH := "res://data/siege/bosses.json"
## 机关工具对同一个人的最短间隔
const TOOL_GAP := 0.12

static var _data := {}

## data/siege/bosses.json 里的哪一段
@export var boss_key := ""

var director: SiegeDirector
var skill := ""
var raged := false
## 每个技能剩下的冷却（秒）
var cds := {}
## 用过的技能（按顺序）/ 每个技能上次放的时间（_t）
var used: Array[String] = []
var last_used := {}
var _fields: Array[WeakRef] = []
var _warns: Array[Node] = []
var _tool_hits := {}
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


# ------------------------------------------------------------------ 数据
static func boss_data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data


func info() -> Dictionary:
	return boss_data().get(boss_key, {})


## 某个 Boss 的 {技能: 冷却} / {技能: 预警秒数}（测试 / 截图用）。
static func cd_table(key: String) -> Dictionary:
	var out := {}
	var skills: Dictionary = boss_data().get(key, {}).get("skills", {})
	for k in skills:
		out[k] = float(skills[k].get("cd", 10.0))
	return out


static func warn_table(key: String) -> Dictionary:
	var out := {}
	var skills: Dictionary = boss_data().get(key, {}).get("skills", {})
	for k in skills:
		out[k] = float(skills[k].get("warn", 0.0))
	return out


func boss_color() -> Color:
	var c: Array = info().get("color", [1, 1, 1])
	return Color(float(c[0]), float(c[1]), float(c[2]))


func skill_keys() -> Array:
	return (info().get("skills", {}) as Dictionary).keys()


func skill_info(key: String) -> Dictionary:
	return (info().get("skills", {}) as Dictionary).get(key, {})


func has_skill(key: String) -> bool:
	return not skill_info(key).is_empty()


func skill_name(key: String) -> String:
	return str(skill_info(key).get("name", key))


func skill_cd(key: String) -> float:
	return float(skill_info(key).get("cd", 10.0))


func skill_warn(key: String) -> float:
	return float(skill_info(key).get("warn", 0.0))


func skill_shout(key: String) -> String:
	return str(skill_info(key).get("shout", ""))


## 狂暴后冷却的倍数（bosses.json 的 rage_cd，没写 = 1）
func rage_cd() -> float:
	return float(info().get("rage_cd", 1.0))


func notice(key: String) -> String:
	return str((info().get("notices", {}) as Dictionary).get(key, ""))


# ------------------------------------------------------------------ 冷却 / 记录
func reset_cooldowns(value := 0.0) -> void:
	for key in skill_keys():
		cds[key] = value


func tick_cooldowns(delta: float) -> void:
	for key in cds:
		cds[key] = maxf(0.0, float(cds[key]) - delta)


func cooled(key: String) -> bool:
	return float(cds.get(key, 0.0)) <= 0.0


func put_on_cooldown(key: String, mult := 1.0) -> void:
	cds[key] = skill_cd(key) * mult


func mark_used(key: String) -> void:
	used.append(key)
	last_used[key] = _t


# ------------------------------------------------------------------ 预警 / 场地
func track_warn(n: Node) -> Node:
	if is_instance_valid(n):
		_warns.append(n)
	return n


func register_field(n: Node) -> void:
	if n == null:
		return
	_fields = _fields.filter(func(ref): return is_instance_valid(ref.get_ref()))
	_fields.append(weakref(n))


func live_fields() -> Array:
	var out: Array = []
	for ref in _fields:
		var n: Variant = ref.get_ref()
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			out.append(n)
	return out


func clear_warns() -> void:
	for n in _warns:
		if is_instance_valid(n):
			n.queue_free()
	_warns.clear()


func clear_fields() -> void:
	for ref in _fields:
		var n: Variant = ref.get_ref()
		if is_instance_valid(n):
			if n.has_method("_end"):
				n.call("_end")
			n.queue_free()
	_fields.clear()


func _exit_tree() -> void:
	clear_fields()
	clear_warns()


## 机关工具挠一下（魔偶师的刷子、要塞的巨手……）：走 make_tickle（暴击 / 部位），每个人 gap 秒内只算一次。
func strike_tools(c: PlayableCharacter, amount: float, part: String, variant: String, gap := TOOL_GAP) -> bool:
	if not SiegeTools.alive(c) or _t < float(_tool_hits.get(c.get_instance_id(), -INF)):
		return false
	var h := make_tickle(c, amount)
	h.zone = part
	h.reaction_variant = variant
	var ok := c.receive_hit(h)
	if ok:
		_tool_hits[c.get_instance_id()] = _t + gap
	return ok


# ------------------------------------------------------------------ 出场 / 狂暴 / 打倒
## 横幅：kind = intro / rage / defeat（bosses.json 里的 title / sub）。
func announce(kind: String) -> void:
	var b: Dictionary = info().get(kind, {})
	if b.is_empty():
		return
	var col := boss_color()
	if b.has("color"):
		col = Color(float(b["color"][0]), float(b["color"][1]), float(b["color"][2]))
	SiegeFx.big_title(self, str(b.get("title", "")), col, str(b.get("sub", "")))


## 波次表里预留的护卫（wave_data().boss_escort = {怪物键: 数量}），围成一圈出场、跟着 Boss。
func spawn_escorts(radius := 58.0) -> Array[Monster]:
	var made: Array[Monster] = []
	if director == null:
		return made
	var keys: Array[String] = []
	var table: Dictionary = director.wave_data().get("boss_escort", {})
	for key in table:
		for _i in int(table[key]):
			keys.append(str(key))
	for i in keys.size():
		var offset := Vector2.from_angle(TAU * i / keys.size()) * radius
		var m := director.spawn(keys[i], "", director.clamp_in_map(global_position + offset))
		if m:
			m.set_meta("escort_of", self)
			m.set_meta("escort_off", offset)
			made.append(m)
	return made


## 打倒奖励的冰晶（bosses.json 的 crystals）。
func reward_defeat() -> void:
	var n := int(info().get("crystals", 0))
	if director and n > 0:
		director.add_crystals(n, global_position)


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



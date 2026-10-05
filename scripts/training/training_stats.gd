class_name TrainingStats
extends RefCounted
## 训练成果（存在 GameState.vars，随存档保存）：
##   train_fatigue_up      魔力疲倦上限 +（训练一）
##   train_fatigue_down    魔力疲倦上限 -（训练二）
##   train_burst_power     魔力疲倦释放强度 +%（训练二）
##   train_resist_<部位>   这个部位的闷笑倍率 -（训练三）
##   train_sens_<部位>     这个部位的闷笑倍率 +（训练四）
## 上限按 data/training/trainings.json 当前解锁阶段的 caps（部位类的 key 去掉部位后缀查）。
## 训练三、四的进度（已练量 / 上限）换来闷笑上限、生命、近战强度，按部位均分（部位数动态，以后加部位自动重算）。
## apply(公主) 把这些套到公主的组件上：开局、换关卡（公主 _setup）和每次训练结算时调用。
## 每个可操作角色有自己的一份训练记录（按 Characters.current()）：粉色公主用上面的键（兼容旧存档），
## 别的角色在键后面加「@角色」（蓝色公主 train_fatigue_up@blue …），从 0 开始，互不复用。

const BASE_FATIGUE := 500.0


## 当前角色的存储键。
static func var_key(key: String, who := "") -> String:
	var c := who if who != "" else Characters.current()
	return key if c == "" or c == "pink" else "%s@%s" % [key, c]


static func value(key: String) -> float:
	return float(GameState.vars.get(var_key(key), 0.0))


## 某项数值属于哪项训练（部位类去掉后缀）。
static func base_key(key: String) -> String:
	for prefix in ["train_resist", "train_sens"]:
		if key.begins_with(prefix + "_"):
			return prefix
	return key


static func training_of(key: String) -> Dictionary:
	var k := base_key(key)
	for t in TrainingDB.list():
		for st in t.get("stages", []):
			if st.get("caps", {}).has(k):
				return t
	return {}


## 当前解锁到第几阶段（0 起）。
static func stage_index(training: Dictionary) -> int:
	var idx := 0
	var stages: Array = training.get("stages", [])
	for i in stages.size():
		if stages[i].get("unlocked", false):
			idx = i
	return idx


static func stage(training: Dictionary) -> Dictionary:
	var stages: Array = training.get("stages", [])
	return stages[stage_index(training)] if not stages.is_empty() else {}


static func cap(key: String) -> float:
	return float(stage(training_of(key)).get("caps", {}).get(base_key(key), 0.0))


## 加数值，截到当前阶段上限；返回实际加了多少。
static func add(key: String, amount: float) -> float:
	var before := value(key)
	var after := clampf(before + amount, 0.0, cap(key))
	GameState.set_var(var_key(key), after)
	return after - before


static func is_full(key: String) -> bool:
	return value(key) >= cap(key) - 1e-6


static func zone_key(prefix: String, zone: String) -> String:
	return "%s_%s" % [prefix, zone]


## 部位类训练在某部位的进度（0~1）。
static func zone_progress(prefix: String, zone: String) -> float:
	var c := cap(zone_key(prefix, zone))
	return clampf(value(zone_key(prefix, zone)) / c, 0.0, 1.0) if c > 0.0 else 0.0


## 部位倍率修正：耐笑训练降、强化训练升（TickleZones.modifier 里加上）。
static func zone_modifier(zone: String) -> float:
	return -value(zone_key("train_resist", zone)) + value(zone_key("train_sens", zone))


## 部位类训练的加成：Σ 各部位进度 × 总加成 / 部位数。
static func _zone_bonus(training_id: String, prefix: String, field: String) -> float:
	var t := TrainingDB.info(training_id)
	var total := float(t.get("bonus", {}).get(field, 0.0))
	var zones := TickleZones.zone_ids()
	if total == 0.0 or zones.is_empty():
		return 0.0
	var sum := 0.0
	for z in zones:
		sum += zone_progress(prefix, str(z))
	return sum * total / zones.size()


static func laugh_bonus() -> float:
	return _zone_bonus("zone_resist", "train_resist", "laugh_max") + _zone_bonus("zone_sensitize", "train_sens", "laugh_max")


## 生命上限加成（HP，1 颗心 = 2）。
static func hp_bonus() -> int:
	return int(floor(_zone_bonus("zone_resist", "train_resist", "hp") + _zone_bonus("zone_sensitize", "train_sens", "hp") + 1e-6))


## 近战强度（0.5 = +50%）。
static func melee_bonus() -> float:
	return _zone_bonus("zone_resist", "train_resist", "melee") + _zone_bonus("zone_sensitize", "train_sens", "melee")


## 近战伤害：基础 × (1 + 强度)，小数部分按概率多 1 点。
static func melee_damage(base: int) -> int:
	var d := float(base) * (1.0 + melee_bonus())
	var whole := int(floor(d))
	return whole + (1 if randf() < d - whole else 0)


static func fatigue_max() -> float:
	return BASE_FATIGUE + value("train_fatigue_up") - value("train_fatigue_down")


## 魔力疲倦释放强度倍率（1.5 = +50%）。
static func burst_mult() -> float:
	return 1.0 + value("train_burst_power") / 100.0


static func apply(p: Node) -> void:
	if p == null or not is_instance_valid(p):
		return
	Characters.scope(str(p.get("character_id")) if p.get("character_id") != null else "pink")
	_apply(p)
	Characters.unscope()


static func _apply(p: Node) -> void:
	var fatigue: MagicFatigue = p.get("fatigue")
	if fatigue:
		fatigue.max_value = fatigue_max()
		if fatigue.value > fatigue.max_value:
			fatigue.value = fatigue.max_value
		fatigue.changed.emit(fatigue.value, fatigue.max_value)
	var laugh: LaughMeter = p.get("laugh")
	if laugh:
		if not p.has_meta("train_base_laugh"):
			p.set_meta("train_base_laugh", laugh.max_value)
		laugh.max_value = float(p.get_meta("train_base_laugh")) + laugh_bonus()
		laugh.changed.emit(laugh.value, laugh.max_value)
	var health: HealthComponent = p.get("health")
	if health:
		if not p.has_meta("train_base_hp"):
			p.set_meta("train_base_hp", health.max_hp)
		var new_max := int(p.get_meta("train_base_hp")) + hp_bonus()
		var grow := new_max - health.max_hp
		health.max_hp = new_max
		health.hp = clampi(health.hp + maxi(grow, 0), 0, new_max)
		health.changed.emit(health.hp, health.max_hp)


## 背包「训练成果」页用：[{name, value, cap, unit}]
static func summary() -> Array:
	var out: Array = [
		{"name": "魔力疲倦上限", "value": "%d" % fatigue_max(), "detail": "忍耐 +%d / %d　释放 -%d / %d" % [value("train_fatigue_up"), cap("train_fatigue_up"),
			value("train_fatigue_down"), cap("train_fatigue_down")]},
		{"name": "疲倦释放强度", "value": "+%.1f%%" % value("train_burst_power"), "detail": "上限 +%d%%" % cap("train_burst_power")},
		{"name": "闷笑上限", "value": "+%.1f" % laugh_bonus(), "detail": ""},
		{"name": "生命上限", "value": "+%s 颗心" % str(hp_bonus() / 2.0), "detail": ""},
		{"name": "近战强度", "value": "+%.1f%%" % (melee_bonus() * 100.0), "detail": ""},
	]
	for z in TickleZones.zone_ids():
		var r := value(zone_key("train_resist", z))
		var s := value(zone_key("train_sens", z))
		if r > 0.0 or s > 0.0:
			out.append({"name": "%s 倍率" % TickleZones.zone_name(z), "value": "%+.3f" % (s - r), "detail": "耐笑 -%.3f　强化 +%.3f" % [r, s]})
	return out

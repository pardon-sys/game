class_name Princess
extends PlayableCharacter
## 公主：通用操作逻辑都在 PlayableCharacter，这里只放公主特有的反应（表情、台词、提示）。


## 受挠台词统一放在 data/princess_reactions.json（通过 ReactionDB 读取）。
var battle_damaged := false
## 最后一次挠到公主的来源键（选笑倒 CG 用；组合技、余痒这类没有来源键的挠痒不覆盖它）。
var last_tickle_key := ""
## 刚播完笑倒 CG：这次复活不再播"复活"对话。
var _after_cg := false
## 被拖进了哪种巢穴（MonsterNest.kind；倒下时播这种巢穴的过场 CG）。
var dragged_into := ""
var _reaction_cooldown := 0.0
var _last_reaction := ""
var _reaction_stage := ""
## 立绘套装（Dialogue.PORTRAIT_SETS 的名字）：公主 "pink"，蓝色公主 "blue"。
var portrait_set := "pink"


## 是不是玩家正在操控的那一个（GameState.player）。AI 控制的（蓝色公主）只保留小人的动画和表情，
## 不触发台词气泡、提示、语音、剧情对话这些属于玩家的反馈。
func is_controlled() -> bool:
	return GameState.player == self


## Called by EmotionComponent; no action-state changes are made here.
## 优先级：魔法姿态（吟唱 / 释放中）> 失控2 > 失控1 > 憋笑 > 事件表情（剧情/开箱等请求，requested 非空）> 战损 > 普通。
## 事件结束（请求松开）后回到战损。
func resolve_visual(requested: String) -> String:
	if not is_alive():
		return "damaged" if battle_damaged else "sad"
	if state == State.CAST and fatigue_bursting:
		return "damaged_burst"  # 疲倦爆发复用战损释放
	if state in [State.CHANNEL, State.CAST]:
		return magic_visual(state == State.CAST)
	return _resolve_normal(requested)


## 魔法姿态：憋笑以上（闷笑 > 35%）不管有没有战损都用「战损闷笑吟诵 / 释放」（没有未战损的闷笑版素材）；
## 没在憋笑时按战损区分普通 / 战损版。
func magic_visual(releasing: bool) -> String:
	var pose := "burst" if releasing else "chant"
	if laugh.value > laugh.giggle_threshold:
		return "damaged_giggle_" + pose
	return ("damaged_" if battle_damaged else "") + pose


func _resolve_normal(requested: String) -> String:
	if laugh.value > laugh.helpless_stage2_threshold:
		return "helpless_2"
	if laugh.value > laugh.helpless_threshold:
		return "helpless_1"
	if laugh.value > laugh.giggle_threshold:
		return "damaged_giggle" if battle_damaged else "giggle"
	if requested != "":
		return requested
	return "damaged" if battle_damaged else "normal"


func _setup() -> void:
	super()
	if fatigue:
		fatigue.changed.connect(_on_fatigue_changed)
	tickled.connect(func(hit: HitData):
		var k := ReactionDB.key_of(hit.source)
		if k != "":
			last_tickle_key = k)
	state_changed.connect(func(_s: State): emotion.refresh())
	health.damaged.connect(func(_amount: int):
		battle_damaged = true
		emotion.refresh()
	)
	laugh.changed.connect(_on_laugh_value_changed)
	# 关卡切换后恢复的闷笑值 / 战损需要立即反映到形象与语音
	_on_laugh_value_changed(laugh.value, laugh.max_value)
	animator.config.row_names.assign(GameState.VISUALS)
	GameState.enemy_defeated.connect(func(_e: Node): if is_controlled(): GameState.emote("happy", 1.5))
	if status:
		status.grabbed.connect(_on_grabbed)
	magic_event.connect(_on_magic_event)


func _on_damaged(hit: HitData) -> void:
	super(hit)
	emotion.refresh()


func _on_tickled(hit: HitData) -> void:
	super(hit)
	if fatigue_bursting or not is_controlled():
		return  # 这一下挠痒把疲倦挠满、刚刚爆发：说疲倦爆发的台词，不说普通受挠台词
	var key := ReactionDB.key_of(hit.source)
	if _play_first_encounter(key):
		return
	if hit.special:
		# 暴击：被猛地挠中，打断普通台词冷却，控制不住地大笑 + 惊讶
		GameState.emote("surprise", 0.8)
		_say(ReactionDB.special(key), "special")
		if not GameState.has_flag("hint_first_special"):
			GameState.set_flag("hint_first_special")
			GameState.notify(ReactionDB.hint("first_special"))
		return
	_react_to_tickle(key, _variant_of(hit.source))
	if not GameState.has_flag("hint_tickled"):
		GameState.set_flag("hint_tickled")
		GameState.notify(ReactionDB.hint("first_tickled"))


func _on_laugh_level_changed(level: LaughMeter.Level) -> void:
	super(level)
	if not is_controlled():
		return
	if level == LaughMeter.Level.HELPLESS:
		GameState.set_flag("was_helpless")
		GameState.notify(ReactionDB.hint("helpless"))
	elif level == LaughMeter.Level.CALM and GameState.has_flag("was_helpless") and not GameState.has_flag("seen_laugh_recover"):
		GameState.set_flag("seen_laugh_recover")
		Dialogue.start("laugh_recover")


func _on_laugh_overflow() -> void:
	super()
	if is_controlled():
		GameState.notify(ReactionDB.hint("overflow"))


func _on_died() -> void:
	if is_controlled():
		GameState.princess_reacted.emit("", 0.0)
	super()
	if is_controlled():
		GameState.emote("sad", 0.0)


func revive() -> void:
	last_tickle_key = ""
	_reaction_cooldown = 0.0
	_last_reaction = ""
	_reaction_stage = ""
	GameState.princess_reacted.emit("", 0.0)
	battle_damaged = false
	super()
	emotion.reset()


func _on_laugh_value_changed(value: float, _maximum: float) -> void:
	if value > laugh.helpless_threshold:
		battle_damaged = true
	emotion.refresh()
	var voice := "laugh" if value > laugh.helpless_threshold else ("giggle" if value > laugh.giggle_threshold else "")
	if is_controlled():
		Audio.set_voice_state(voice if is_alive() else "")


func _on_respawned() -> void:
	if not is_controlled():
		return
	if _after_cg:
		_after_cg = false
		return
	Dialogue.start("respawn")


## 被挠到笑倒（闷笑值满把最后一点血扣光）：播笑倒 CG（data/cgs.json），然后在检查点复活。
## 被拖进怪物巢穴：播这种巢穴的过场 CG（data/cgs.json 的 nest 表），然后在检查点复活。
func _play_death_cutscene() -> bool:
	var cg := get_node_or_null("/root/CG")
	if cg != null and dragged_into != "":
		var nest_kind := dragged_into
		dragged_into = ""
		_nest_cg(cg, nest_kind)
		return true
	dragged_into = ""
	if cg == null or not is_laugh_defeat():
		return false
	_death_cg(cg, defeat_source_key())
	return true


## 被巢穴怪物拖进巢穴（MonsterNest._swallow 调用）：倒下并播巢穴过场。
func dragged_into_nest(nest: MonsterNest) -> void:
	if not is_alive():
		return
	dragged_into = nest.kind
	if sprite:
		var tw := create_tween()
		tw.tween_property(sprite, "modulate:a", 0.0, 0.3)
	health.damage(health.hp)


func _nest_cg(cg: Node, nest_kind: String) -> void:
	await get_tree().create_timer(0.6).timeout
	if sprite:
		sprite.modulate.a = 0.0
	await cg.play_nest(nest_kind)
	_after_cg = true
	respawn()


## 选笑倒 CG 用的来源键：最后一次挠痒的来源 → 本条命里记录的挠痒来源 → 致命一击的怪物。
func defeat_source_key() -> String:
	if last_tickle and is_instance_valid(last_tickle.source):
		var key := ReactionDB.key_of(last_tickle.source)
		if key != "":
			return key
	if last_tickle_key != "":
		return last_tickle_key
	if last_hit and is_instance_valid(last_hit.source):
		return ReactionDB.key_of(last_hit.source)
	return ""


func _death_cg(cg: Node, key: String) -> void:
	await get_tree().create_timer(0.8).timeout  # 先倒下停一会儿
	if sprite:
		sprite.modulate.a = 0.0
	await cg.play_death(key)
	_after_cg = true
	respawn()


func _tick(delta: float) -> void:
	_reaction_cooldown = maxf(0.0, _reaction_cooldown - delta)
	super(delta)


## 第一次被某个来源挠痒：播放 sources[key].first_encounter 的剧情对话（会暂停战斗），返回是否播放。
func _play_first_encounter(key: String) -> bool:
	if key == "" or GameState.in_dialogue or Dialogue.is_active():
		return false
	var flag := "met_" + key
	if GameState.has_flag(flag):
		return false
	GameState.set_flag(flag)
	var lines := ReactionDB.first_encounter(key)
	if lines.is_empty():
		return false
	Dialogue.start_lines(lines, "first_" + key)
	return true


func _laugh_stage() -> String:
	if laugh.value > laugh.helpless_stage2_threshold:
		return "helpless_2"
	if laugh.value > laugh.helpless_threshold:
		return "helpless_1"
	if laugh.value > laugh.giggle_threshold:
		return "giggle"
	return "calm"


func _react_to_tickle(key := "", variant := "") -> void:
	if GameState.in_dialogue:
		return
	var stage := _laugh_stage()
	# 新的闷笑阶段可以打断冷却；同阶段连续被挠不会刷屏；刚被困住的那句先说完
	if _reaction_cooldown > 0.0 and (stage == _reaction_stage or _reaction_stage == "grabbed"):
		return
	_say(ReactionDB.lines(key, stage, variant), stage)


## 来源的台词变体（落穴洞：洞里住的怪物）。
static func _variant_of(source: Variant) -> String:
	if source != null and is_instance_valid(source) and source.has_method("reaction_variant"):
		return str(source.reaction_variant())
	return ""


func _say(candidates_in: Array, stage: String) -> void:
	var candidates := candidates_in.duplicate()
	if candidates.is_empty():
		return
	if candidates.size() > 1:
		candidates.erase(_last_reaction)
	_last_reaction = str(candidates.pick_random())
	_reaction_stage = stage
	_reaction_cooldown = float(ReactionDB.setting("cooldown_seconds", 1.6))
	GameState.princess_reacted.emit(_last_reaction, float(ReactionDB.setting("display_seconds", 2.4)))


func _on_magic_event(event: String, tier: int) -> void:
	if GameState.in_dialogue or not is_controlled():
		return
	match event:
		"fatigue_burst":
			_on_fatigue_burst()
		"channel":
			if not GameState.has_flag("hint_magic_exposed"):
				GameState.set_flag("hint_magic_exposed")
				GameState.notify(ReactionDB.hint("magic_exposed"))
			_say(ReactionDB.magic("channel"), "magic")
		"interrupted":
			GameState.emote("angry", 1.2)
			_say(ReactionDB.magic("interrupted"), "magic")
		"fizzle":
			_say(ReactionDB.magic("fizzle"), "magic")
		"burst":
			GameState.emote("happy", 1.2)
			_say(ReactionDB.magic("burst_full" if tier >= channel_tiers.size() else "burst"), "magic")


# ------------------------------------------------------------------ 魔力疲倦
var _fatigue_warned := false


func _on_fatigue_changed(_value: float, _max: float) -> void:
	if fatigue.is_near_full() and not _fatigue_warned and is_alive() and is_controlled():
		_fatigue_warned = true
		_say(ReactionDB.fatigue("warning"), "fatigue")


## 疲倦爆发：非常疲倦但一口气清空的舒服解脱感。第一次播一小段剧情，之后随机一句，几秒后再补一句。
func _on_fatigue_burst() -> void:
	_fatigue_warned = false
	GameState.emote("happy", 2.0)  # 失控时失控表情仍然优先（resolve_visual）
	if not GameState.has_flag("seen_fatigue_burst"):
		GameState.set_flag("seen_fatigue_burst")
		var lines := ReactionDB.fatigue("first")
		if not lines.is_empty():
			Dialogue.start_lines(lines, "fatigue_first")
			return
	_say(ReactionDB.fatigue("burst"), "fatigue")
	await get_tree().create_timer(3.0).timeout
	if is_alive() and not GameState.in_dialogue:
		_say(ReactionDB.fatigue("after"), "fatigue")


## 组合技触发时由 ComboTracker 调用。
func say_combo(id: String) -> void:
	if GameState.in_dialogue or not is_controlled():
		return
	GameState.emote("surprise", 1.0)
	_say(ReactionDB.combo(id).get("lines", []), "combo")


func _on_grabbed(source: Node) -> void:
	if not is_controlled():
		return
	if not GameState.has_flag("hint_grabbed"):
		GameState.set_flag("hint_grabbed")
		GameState.notify(ReactionDB.hint("grabbed"))
	if not GameState.in_dialogue:
		_say(ReactionDB.lines(ReactionDB.key_of(source), "grabbed", _variant_of(source)), "grabbed")

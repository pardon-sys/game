class_name Princess
extends PlayableCharacter
## 公主：通用操作逻辑都在 PlayableCharacter，这里只放公主特有的反应（表情、台词、提示）。


## 受挠台词统一放在 data/princess_reactions.json（通过 ReactionDB 读取）。
var battle_damaged := false
## 最后一次挠到公主的来源键（选笑倒 CG 用；组合技、余痒这类没有来源键的挠痒不覆盖它）。
var last_tickle_key := ""
## 刚播完笑倒 CG：这次复活不再播"复活"对话。
var _after_cg := false
var _reaction_cooldown := 0.0
var _last_reaction := ""
var _reaction_stage := ""


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


## 魔法姿态：未战损只有一套（没有"未战损憋笑吟诵"的素材）；战损时按闷笑值 >50 区分闷笑版。
func magic_visual(releasing: bool) -> String:
	var pose := "burst" if releasing else "chant"
	if not battle_damaged:
		return pose
	return ("damaged_giggle_" if laugh.value > laugh.giggle_threshold else "damaged_") + pose


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
	GameState.enemy_defeated.connect(func(_e: Node): GameState.emote("happy", 1.5))
	if status:
		status.grabbed.connect(_on_grabbed)
	magic_event.connect(_on_magic_event)


func _on_damaged(hit: HitData) -> void:
	super(hit)
	emotion.refresh()


func _on_tickled(hit: HitData) -> void:
	super(hit)
	if fatigue_bursting:
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
	_react_to_tickle(key)
	if not GameState.has_flag("hint_tickled"):
		GameState.set_flag("hint_tickled")
		GameState.notify(ReactionDB.hint("first_tickled"))


func _on_laugh_level_changed(level: LaughMeter.Level) -> void:
	super(level)
	if level == LaughMeter.Level.HELPLESS:
		GameState.set_flag("was_helpless")
		GameState.notify(ReactionDB.hint("helpless"))
	elif level == LaughMeter.Level.CALM and GameState.has_flag("was_helpless") and not GameState.has_flag("seen_laugh_recover"):
		GameState.set_flag("seen_laugh_recover")
		Dialogue.start("laugh_recover")


func _on_laugh_overflow() -> void:
	super()
	GameState.notify(ReactionDB.hint("overflow"))


func _on_died() -> void:
	GameState.princess_reacted.emit("", 0.0)
	super()
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
	Audio.set_voice_state(voice if is_alive() else "")


func _on_respawned() -> void:
	if _after_cg:
		_after_cg = false
		return
	Dialogue.start("respawn")


## 被挠到笑倒（闷笑值满把最后一点血扣光）：播笑倒 CG（data/cgs.json），然后在检查点复活。
func _play_death_cutscene() -> bool:
	var cg := get_node_or_null("/root/CG")
	if cg == null or not is_laugh_defeat():
		return false
	_death_cg(cg, defeat_source_key())
	return true


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


func _react_to_tickle(key := "") -> void:
	if GameState.in_dialogue:
		return
	var stage := _laugh_stage()
	# 新的闷笑阶段可以打断冷却；同阶段连续被挠不会刷屏
	if _reaction_cooldown > 0.0 and stage == _reaction_stage:
		return
	_say(ReactionDB.lines(key, stage), stage)


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
	if GameState.in_dialogue:
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


func _on_fatigue_changed(value: float, _max: float) -> void:
	if value >= 450.0 and not _fatigue_warned and is_alive():
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
	if GameState.in_dialogue:
		return
	GameState.emote("surprise", 1.0)
	_say(ReactionDB.combo(id).get("lines", []), "combo")


func _on_grabbed(source: Node) -> void:
	if not GameState.has_flag("hint_grabbed"):
		GameState.set_flag("hint_grabbed")
		GameState.notify(ReactionDB.hint("grabbed"))
	if not GameState.in_dialogue:
		_say(ReactionDB.lines(ReactionDB.key_of(source), "grabbed"), "grabbed")

class_name Princess
extends PlayableCharacter
## 公主：通用操作逻辑都在 PlayableCharacter，这里只放公主特有的反应（表情、台词、提示）。


## 受挠台词统一放在 data/princess_reactions.json（通过 ReactionDB 读取）。
var battle_damaged := false
var _reaction_cooldown := 0.0
var _last_reaction := ""
var _reaction_stage := ""


## Called by EmotionComponent; no action-state changes are made here.
## 优先级：魔法姿态（吟唱 / 释放中）> 失控2 > 失控1 > 憋笑 > 事件表情（剧情/开箱等请求，requested 非空）> 战损 > 普通。
## 事件结束（请求松开）后回到战损。
func resolve_visual(requested: String) -> String:
	if not is_alive():
		return "damaged" if battle_damaged else "sad"
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
	var key := ReactionDB.key_of(hit.source)
	if _play_first_encounter(key):
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
	Dialogue.start("respawn")


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

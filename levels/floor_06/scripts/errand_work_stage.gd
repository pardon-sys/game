class_name ErrandWorkStage
extends TrainingStage
## 第六层劳动委托 / 补罚小游戏的共用底子（穿链、剪毛、棚布、筛叶、灯轮、报幕都继承它）：来源、对白、临时状态的生命周期，
## 加上几个游戏都一样的流程——
##   开演：prepare_work → 搭舞台 → start_work（开场 / 续做对白 → 第一段；进度已满就只补收尾）→ work_result。
##   推进：advance_step（完成数 +1 → save_progress → 到阶段末尾演转换对白 → 下一段）；做完 _finish_work（收尾对白 → 成功）。
##   一帧：work_clock(dt) 推进干扰时钟（WorkInterference）：加强时按 phases[].tools 轮换道具，命中时 tickle(tickler, tickle_zone)。
##   闷笑满 → recover：闷笑回到 RESET_LAUGH、当前这一段从头（_reset_segment），停 RECOVER_TIME 秒，文本 full。
##   魔力疲倦满 → release：魔力自动释放——人会觉得舒服（闪光、文本 release 的描写 / 舒服的反应 / 挠她的人的一句），疲倦清空、闷笑不变、
##     进度不退，停 RELEASE_TIME 秒；之后 SENSITIVE_TIME 秒「释放后敏感」：work_laugh ×SENSITIVE_MULT、反应换 sensitive 那一套。
## 子类重写：work_text / phase_limits / save_progress / _begin_segment / _reset_segment / _stop_input / _on_phase_changed / _before_finish。
## Esc、读档、换图只释放这个舞台持有的锁和状态，不保存当前段的部分计时。
## 测试：dialogue_quiet（跳对白，保留计时和数值）、dialogue_blocks（数对白段数）、releases（释放了几次）。

const RECOVER_TIME := 1.5
const RELEASE_TIME := 1.8
const RESET_LAUGH := 0.45
const SENSITIVE_TIME := 5.0
const SENSITIVE_MULT := 1.5
const RELEASE_GLOW := Color(1, 0.92, 0.65, 0.8)

var completed := 0
var phase := 0
var elapsed := 0.0
var active_tool := ""
var tickler := ""
var tickle_zone := "sole"
var recovery_left := 0.0
var sensitive_left := 0.0
var releases := 0
var interference := WorkInterference.new()
var dialogue_quiet := false
var dialogue_blocks := 0

var _done := false
var _success := false
var _cancelled := false
var _restored := false
var _source: Node
var _main: Node
var _start_damaged := false
var _laugh_processing := true
var _had_tutorial_guard := false
var _old_tutorial_guard: Variant
var _line_id := ""
var _action_caption: Label
var _prepared := false
var _caption_owned := ""
var _event_last := -1
var _event_phase := -1


# ------------------------------------------------------------------ 子类重写
func work_text() -> Dictionary:
	return {}


## 每个阶段结束时的累计完成数（最后一项 = 总数）
func phase_limits() -> Array:
	return [1]


func save_progress() -> void:
	pass


func _begin_segment() -> void:
	busy = false


## 闷笑满：当前这一段从头来（已完成的不退）
func _reset_segment() -> void:
	pass


## 停下手上的操作（按住的键、拿着的工具）
func _stop_input() -> void:
	pass


func _on_phase_changed() -> void:
	pass


## 收工前（摆回站姿之类）
func _before_finish() -> void:
	pass


# ------------------------------------------------------------------ 共用流程
func total() -> int:
	return int(phase_limits()[-1])


func phase_info() -> Dictionary:
	return work_text()["phases"][phase]


func phase_of(step: int) -> int:
	var limits := phase_limits()
	for i in limits.size():
		if step < int(limits[i]):
			return i
	return limits.size() - 1


## 这一阶段之前已经完成了几步
func phase_start() -> int:
	return 0 if phase == 0 else int(phase_limits()[phase - 1])


func start_work() -> bool:
	busy = true
	if completed >= total():
		await _finish_work()
		return _alive()
	var text := work_text()
	await _lines((text.get("resume", []) if completed > 0 else text.get("intro", [])) + phase_info().get("start", []))
	if not _alive():
		return false
	_begin_segment()
	return true


func advance_step() -> void:
	if busy or completed >= total():
		return
	busy = true
	_stop_input()
	completed += 1
	save_progress()
	work_reaction(work_text(), phase, active_tool, tickler, "success_react")
	if completed >= total():
		await _finish_work()
		return
	if completed >= int(phase_limits()[phase]):
		var transition: Array = phase_info().get("end", [])
		phase += 1
		_on_phase_changed()
		await _lines(transition + phase_info().get("start", []))
		if not _alive():
			return
	_begin_segment()


func _finish_work() -> void:
	busy = true
	_stop_input()
	_punish_request = ""
	recovery_left = 0.0
	sensitive_left = 0.0
	clear_feedback()
	# 收工后先恢复平静表情，结尾对白的害羞 / 生气不被模拟闷笑盖住。
	if player.laugh:
		player.laugh.clear()
	if player.get("battle_damaged") != null:
		player.set("battle_damaged", _start_damaged)
	_before_finish()
	_update_bars()
	await _lines(work_text()["done"])
	if not _alive():
		return
	_success = true
	_done = true
	playing = false


## 一帧的共用部分：推进干扰时钟和敏感计时；返回 WorkInterference.advance 的结果（加强时已经换好道具）。
func work_clock(dt: float) -> Dictionary:
	var event := interference.advance(dt)
	elapsed = interference.elapsed
	sensitive_left = maxf(0.0, sensitive_left - float(event["dt"]))
	if event["strong"]:
		rotate_tool()
	if event["fx"]:
		tickle(tickler, tickle_zone)
	return event


## 换到这一阶段的下一种道具（phases[].tools 按加强次数轮换；没写时刷子 / 手轮换）
func rotate_tool() -> void:
	var tools: Array = phase_info().get("tools", ["brush", "hand"])
	if tools.is_empty():
		return
	active_tool = str(tools[interference.strong_count % tools.size()])
	var a: CGActor = actors.get(tickler)
	if a:
		a.hit_fx = _tool_fx(active_tool)


func _tool_fx(tool: String) -> String:
	for e in work_text().get("feedback", []):
		if str(e.get("tool", "")) == tool:
			return str(e.get("fx", "hand"))
	return "brush" if tool == "brush" else "hand"


## 挠痒带来的闷笑（释放后敏感时加倍）
func work_laugh(amount: float) -> void:
	add_laugh(amount * (SENSITIVE_MULT if sensitive_left > 0.0 else 1.0))


## 满了的数值在每一帧开头处理：疲倦 → 释放，闷笑 → 恢复。返回是否处理了。
func handle_overflow() -> bool:
	if _punish_request == "":
		return false
	var kind := _punish_request
	_punish_request = ""
	_stop_input()
	if kind == "fatigue":
		release()
	else:
		recover()
	return true


func recover() -> void:
	_reset_segment()
	recovery_left = RECOVER_TIME
	if player.laugh:
		player.laugh.set_value(laugh_max() * RESET_LAUGH)
	var full: Dictionary = work_text().get("full", {})
	narrate(str(full.get("desc", work_text().get("recover", ""))), RECOVER_TIME, true)
	_pop_random(full.get("react", []), PINK, RECOVER_TIME)


## 魔力疲倦满：自动释放。痒意一下子化开、人觉得舒服；进度不退，之后几秒格外敏感。
func release() -> void:
	releases += 1
	recovery_left = RELEASE_TIME
	sensitive_left = SENSITIVE_TIME
	if player.fatigue:
		player.fatigue.clear()
	flash(RELEASE_GLOW, 0.7)
	Audio.play("star_burst", -4.0)
	var r: Dictionary = work_text().get("release", {})
	var desc: Array = r.get("desc", [])
	if not desc.is_empty():
		narrate(str(desc[rng.randi_range(0, desc.size() - 1)]), RELEASE_TIME + 1.2, true)
	_pop_random(r.get("react", []), GOLD, RELEASE_TIME)
	var lines: Array = r.get("tickler", [])
	if not lines.is_empty() and actors.has(tickler):
		say(tickler, str(lines[rng.randi_range(0, lines.size() - 1)]))
	var p: CGActor = actors.get("princess")
	if p:
		p.set_pose("happy")
		var ref: WeakRef = weakref(p)
		get_tree().create_timer(RELEASE_TIME).timeout.connect(func():
			var pp: CGActor = ref.get_ref()
			if pp:
				pp.set_pose("normal"))


## 圆 / 菱 / 星三种图案（灯轮的灯罩、报幕的节目卡）
static func draw_shape(ci: CanvasItem, at: Vector2, kind: int, col: Color) -> void:
	if kind == 0:
		ci.draw_arc(at, 5, 0, TAU, 16, col, 2)
	elif kind == 1:
		ci.draw_polyline(PackedVector2Array([at + Vector2(0, -6), at + Vector2(6, 0), at + Vector2(0, 6), at + Vector2(-6, 0), at + Vector2(0, -6)]), col, 2)
	else:
		for i in 5:
			ci.draw_line(at, at + Vector2.from_angle(i * TAU / 5 - PI / 2) * 7, col, 2)


func _pop_random(lines: Array, col: Color, time: float) -> void:
	if not lines.is_empty():
		pop(actors.get("princess"), str(lines[rng.randi_range(0, lines.size() - 1)]), col, time)


# ------------------------------------------------------------------ 舞台和文字
func _build_ui() -> void:
	super()
	# 人物台词 / 反应飘字在演员、机关、特效及舞台装饰上方绘制。
	overlay.z_index = 100
	overlay.z_as_relative = false
	count_label.z_index = 110
	hint_label.z_index = 110
	# 原反应框占 112,218 至 350,263；操作区移到右侧，保留模板边框、字体和长文滚动。
	_action_caption = Dialogue.reaction_text
	_action_caption.z_index = 110
	_action_caption.z_as_relative = false
	Dialogue.show_reaction("", 0.0)
	count_label.position = Vector2(356, 218)
	count_label.size = Vector2(116, 14)
	count_label.add_theme_font_size_override("font_size", 7)
	hint_label.position = Vector2(356, 232)
	hint_label.size = Vector2(116, 37)
	hint_label.add_theme_font_size_override("font_size", 7)


## 长描述至少滚完一轮，不被每 3 秒的新反应反复顶回开头；force 的（满值 / 释放）直接换上。
func narrate(line: String, duration := 2.4, force := false) -> void:
	if not force and _caption_owned != "" and Dialogue.reaction_panel.visible and Dialogue.reaction_text.text == _caption_owned and Dialogue._reaction_time > 0.8:
		return
	_caption_owned = line
	super(line, duration)


## 挠痒的反应：按阶段、道具挑一组（不连着重复），描写进下方反应框，她的反应按闷笑分档飘在头上（释放后敏感时用 sensitive）；
## 这组的部位 / 特效成为之后命中的部位。context 不为空时只从那个池子（success_react / error_react ……）挑一句。
func work_reaction(data: Dictionary, at_phase: int, tool: String, who: String, context := "") -> void:
	if context != "":
		var lines: Array = data.get(context, [])
		_pop_random(lines, PINK, 1.8)
		return
	var events: Array = data.get("feedback", []).filter(func(e): return int(e["phase"]) == at_phase and str(e["tool"]) == tool)
	_play_event(events, who)


## 从 events 里挑一组演出来（剪毛的舔脚、灯轮的踏板刷也走这里）。
func _play_event(events: Array, who: String) -> void:
	if events.is_empty():
		return
	if _event_phase != phase:
		_event_phase = phase
		_event_last = -1
	var index := rng.randi_range(0, events.size() - 1)
	if index == _event_last and events.size() > 1:
		index = (index + 1) % events.size()
	_event_last = index
	var e: Dictionary = events[index]
	var ratio := player.laugh.ratio() if player.laugh else 0.0
	var tier := "light" if ratio < 0.4 else ("mid" if ratio < 0.75 else "heavy")
	var replies: Array = e["react"][tier]
	if sensitive_left > 0.0:
		replies = work_text().get("sensitive", {}).get(tier, replies)
	_pop_random(replies, PINK, 1.8)
	narrate(str(e["caption"]), 3.2)
	tickle_zone = str(e.get("zone", tickle_zone))
	var a: CGActor = actors.get(who)
	if a:
		a.hit_fx = str(e.get("fx", "hand"))


# ------------------------------------------------------------------ 生命周期
func prepare_work(seed_value: int, quiet_mode: bool) -> bool:
	_source = _level()
	_main = get_tree().get_first_node_in_group("main")
	player = GameState.player
	if not is_instance_valid(_source) or not is_instance_valid(player):
		return false
	_line_id = "work_" + str(get_instance_id())
	dialogue_quiet = quiet_mode
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	layer = 14
	_start_laugh = player.laugh.value if player.laugh else 0.0
	_start_fatigue = player.fatigue.value if player.fatigue else 0.0
	_start_damaged = player.get("battle_damaged") == true
	if player.laugh:
		_laugh_processing = player.laugh.is_processing()
		player.laugh.set_process(false)
	_had_tutorial_guard = player.has_meta("suppress_laugh_tutorials")
	_old_tutorial_guard = player.get_meta("suppress_laugh_tutorials", false)
	player.set_meta("suppress_laugh_tutorials", true)
	if player.laugh:
		player.laugh.clear()
	if player.fatigue:
		player.fatigue.clear()
	_prepared = true
	return true


func work_result() -> bool:
	while not _done and _alive():
		await get_tree().process_frame
	if not _alive():
		cancel()
		return false
	_restore_runtime()
	root.hide()
	finished.emit()
	return _success


func _alive() -> bool:
	return not _cancelled and is_inside_tree() and is_instance_valid(_source) and _source.is_inside_tree() and _level() == _source \
		and is_instance_valid(player) and GameState.player == player


func _lines(lines: Array) -> void:
	if lines.is_empty() or not _alive():
		return
	dialogue_blocks += 1
	if dialogue_quiet:
		return
	busy = true
	while _alive() and Dialogue.is_active() and Dialogue._id != _line_id:
		await get_tree().process_frame
	if not _alive():
		return
	Dialogue.start_lines(lines, _line_id)
	while _alive() and Dialogue.is_active() and Dialogue._id == _line_id:
		await get_tree().process_frame
	if _alive():
		GameState.in_dialogue = true


func _suspended() -> bool:
	return get_tree().paused or CG.is_busy() or GameState.in_cutscene or Cutscene.is_playing() or Dialogue.is_active()


func press(k: String) -> void:
	if not _suspended():
		super(k)


func quit() -> void:
	if not busy:
		cancel()


func cancel() -> void:
	if _restored:
		return
	_cancelled = true
	_done = true
	playing = false
	if Dialogue.is_active() and Dialogue._id == _line_id:
		Dialogue._end()
	_restore_runtime()
	if is_instance_valid(root):
		root.hide()


func _restore_runtime() -> void:
	if _restored:
		return
	_restored = true
	playing = false
	if not _prepared:
		return
	_release_hold()
	if is_instance_valid(player):
		if player.laugh:
			player.laugh.set_value(_start_laugh)
		if player.fatigue:
			player.fatigue.set_value(_start_fatigue)
		if player.get("battle_damaged") != null:
			player.set("battle_damaged", _start_damaged)
		if player.laugh:
			player.laugh.set_process(_laugh_processing)
	if is_instance_valid(player) and GameState.player == player:
		GameState.emote("", 0.0, false)
		if not CG.is_busy() and not GameState.in_cutscene:
			clear_feedback()
		# main 已在淡出前暂存过小游戏中的数值；换图退出时改回原值。读档会先清掉 player，故不会覆盖读入的新状态。
		if is_instance_valid(_main) and bool(_main.get("_busy")):
			GameState.save_player_state()
	if is_instance_valid(player):
		if _had_tutorial_guard:
			player.set_meta("suppress_laugh_tutorials", _old_tutorial_guard)
		else:
			player.remove_meta("suppress_laugh_tutorials")
	if _music_was != "" and Audio.music_id == MINIGAME_MUSIC:
		Audio.play_music(_music_was, 0.8)
	GameState.in_dialogue = GameState.dialogue_holds > 0 or Dialogue.is_active() or Dialogue.runner.is_running() or GameState.in_cutscene


func clear_feedback() -> void:
	if _caption_owned != "" and Dialogue.reaction_text.text == _caption_owned:
		Dialogue.show_reaction("", 0.0)
	_caption_owned = ""
	for l in _floating:
		if is_instance_valid(l):
			l.queue_free()
	_floating.clear()
	_bubbles.clear()
	if is_instance_valid(fx_root):
		for n in fx_root.get_children():
			n.queue_free()
	Dialogue.portrait_fx.clear()


func _update_count() -> void:
	pass   # 各游戏的状态由自己的 _refresh 统一显示，不沿用训练成功计数。


func _exit_tree() -> void:
	cancel()
	super()

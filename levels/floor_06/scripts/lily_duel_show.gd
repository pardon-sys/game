class_name LilyDuelShow
extends ErrandWorkStage
## 支线「骑士救公主」第三处：和小莉莉比「谁先笑」，两人坐在鹅卵石小路尽头，光着脚轮流挠对方的脚心。台词 knight_quests.json 的 shoes.duel。
##   挠她（TURN_TIME 秒）：她的弱点每回合换一处（脚趾 / 脚心 / 脚跟），回合开始时她会喊漏嘴（weak_hint）；
##     A / S / D 挠脚趾 / 脚心 / 脚跟：挠中弱点 莉莉的笑 +HIT，挠错 +MISS；两下之间至少隔 PRESS_COOL 秒。
##   忍住（TURN_TIME 秒）：莉莉挠回来，闷笑每秒 +DEFEND_RATE；每 POKE_EVERY 秒亮一次「！」（WARN 秒）然后狠狠一下（+POKE_LAUGH），
##     亮着的时候按 J 缩脚就躲开这一下。
##   莉莉笑满 = 赢；她先笑满（ErrandWorkStage 的闷笑满）= 这一局输，两人回到 ROUND_RESET 重来。魔力释放见 ErrandWorkStage。不存档。
## 测试：quiet、fixed_seed、press()、simulate()、lily_laugh、turn、weak、warn_left。

const TURN_TIME := 5.0
const HIT := 0.14
const MISS := 0.03
const PRESS_COOL := 0.35
const DEFEND_RATE := 0.035
const POKE_EVERY := 1.4
const WARN := 0.55
const POKE_LAUGH := 0.1
const ROUND_RESET := 0.25
const SPOT_KEYS := {"A": 0, "S": 1, "D": 2}

static var quiet := false
static var fixed_seed := -1
static var _text := {}

var lily_laugh := 0.0
var turn := "attack"
var turn_left := TURN_TIME
var weak := 0
var rounds := 1
var warn_left := 0.0
var _poke := POKE_EVERY
var _press := 0.0
var _info: Label
var _rig: DuelRig


static func data() -> Dictionary:
	if _text.is_empty():
		var d: Dictionary = KnightQuests.info("shoes").get("duel", {})
		_text = {"name": d.get("name", "谁先笑"), "hint": d.get("hint", ""), "phases": [{"name": d.get("name", "")}],
			"intro": d.get("intro", []), "done": [{"speaker": "", "text": str((d.get("win", [""]) as Array)[0])}],
			"full": {"desc": str((d.get("lose", [""]) as Array)[0]), "react": d.get("pink_react", [[], [], []])[2]}, "duel": d}
	return _text


func duel() -> Dictionary:
	return data().get("duel", {})


func work_text() -> Dictionary:
	return data()


func phase_limits() -> Array:
	return [1]


func panel_title() -> String:
	return str(data().get("name", ""))


func stage_cast() -> Dictionary:
	return {"princess": {"kind": "princess", "character": "pink", "at": [-20, 6], "visual": "normal", "anim": "idle", "dir": "right"},
		"lily": {"kind": "npc:kid", "at": [20, 6], "dir": "left"}}


func play() -> bool:
	if not prepare_work(fixed_seed, quiet):
		return false
	tickler = "lily"
	active_tool = "finger"
	_build_ui()
	hint_label.text = str(data()["hint"])
	_info = _label(TEXT, 8)
	_info.size = panel_body.size
	panel_body.add_child(_info)
	_enter_game()
	_rig = DuelRig.new()
	_rig.stage = self
	view.add_child(_rig)
	if not await start_work():
		return false
	return await work_result()


func _begin_segment() -> void:
	busy = false
	_start_turn("attack")


func _start_turn(t: String) -> void:
	turn = t
	turn_left = TURN_TIME
	warn_left = 0.0
	_poke = POKE_EVERY
	if t == "attack":
		weak = rng.randi_range(0, 2)
		var spot := str(duel()["spots"][weak])
		var hints: Array = duel()["weak_hint"].get(spot, [])
		if not hints.is_empty():
			say("lily", str(hints[rng.randi_range(0, hints.size() - 1)]))
		narrate(str(duel()["turn_attack"]), 1.6, true)
	else:
		narrate(str(duel()["turn_defend"]), 1.6, true)
	_refresh()


func _on_key(k: String) -> void:
	if recovery_left > 0.0 or busy:
		return
	if turn == "attack" and SPOT_KEYS.has(k):
		tickle_lily(int(SPOT_KEYS[k]))
	elif turn == "defend" and k == "J":
		tuck()


## 挠莉莉的一处（0 脚趾 / 1 脚心 / 2 脚跟）
func tickle_lily(spot: int) -> void:
	if _press > 0.0:
		return
	_press = PRESS_COOL
	var good := spot == weak
	lily_laugh = minf(1.0, lily_laugh + (HIT if good else MISS))
	var pool: Array = duel()["hit" if good else "miss"]
	narrate(str(pool[rng.randi_range(0, pool.size() - 1)]), 1.2, true)
	if good:
		var r: Array = duel()["lily_react"]
		say("lily", str(r[rng.randi_range(0, r.size() - 1)]))
	if lily_laugh >= 1.0:
		advance_step()
	_refresh()


## 莉莉挠回来时亮「！」：按 J 缩脚躲开这一下
func tuck() -> bool:
	if warn_left <= 0.0:
		return false
	warn_left = 0.0
	_poke = POKE_EVERY
	var ok: Array = duel()["tuck_ok"]
	narrate(str(ok[rng.randi_range(0, ok.size() - 1)]), 1.0, true)
	_refresh()
	return true


## 她先笑满：这一局输，两人都回到起点重来
func recover() -> void:
	rounds += 1
	lily_laugh = ROUND_RESET
	recovery_left = RECOVER_TIME
	if player.laugh:
		player.laugh.set_value(laugh_max() * ROUND_RESET)
	var lose: Array = duel()["lose"]
	narrate(str(lose[0]), RECOVER_TIME + 0.6, true)
	_start_turn("attack")


func _process(delta: float) -> void:
	if playing and not _alive():
		cancel()
		return
	if not playing or busy or _done or _suspended():
		return
	if handle_overflow():
		_refresh()
		return
	_update_bars()
	simulate(delta * time_scale)


func simulate(delta: float) -> void:
	if not _alive() or busy or _done or _suspended():
		return
	var dt := clampf(delta, 0.0, WorkInterference.MAX_DELTA)
	elapsed += dt
	sensitive_left = maxf(0.0, sensitive_left - dt)
	_press = maxf(0.0, _press - dt)
	if recovery_left > 0.0:
		recovery_left = maxf(0.0, recovery_left - dt)
		return
	turn_left -= dt
	if turn == "defend":
		work_laugh(laugh_max() * DEFEND_RATE * dt)
		if warn_left > 0.0:
			warn_left -= dt
			if warn_left <= 0.0:
				_poke_now()
		else:
			_poke -= dt
			if _poke <= 0.0:
				warn_left = WARN
	if turn_left <= 0.0:
		_start_turn("defend" if turn == "attack" else "attack")
	_refresh()


func _poke_now() -> void:
	_poke = POKE_EVERY
	work_laugh(laugh_max() * POKE_LAUGH)
	tickle("lily", "sole")
	var desc: Array = duel()["tickle_desc"]
	narrate(str(desc[rng.randi_range(0, desc.size() - 1)]), 1.4)
	var tiers: Array = duel()["pink_react"]
	var tier: Array = tiers[clampi(int(player.laugh.ratio() * 3.0) if player.laugh else 0, 0, 2)]
	_pop_random(tier, PINK, 1.2)


func _refresh() -> void:
	if not is_instance_valid(_info):
		return
	var r := player.laugh.ratio() if player and player.laugh else 0.0
	_info.text = str(duel()["panel"]) % [rounds, str(duel()["turn_attack" if turn == "attack" else "turn_defend"]), int(r * 100.0), int(lily_laugh * 100.0)]
	count_label.text = "%d%%" % int(lily_laugh * 100.0)
	if _rig:
		_rig.queue_redraw()


## 莉莉伸过来的两只脚（挠她时三处亮着，被挠时她的小手）、两个人的笑条、亮着的「！」
class DuelRig extends Node2D:
	var stage: LilyDuelShow

	func _draw() -> void:
		draw_rect(Rect2(-40, -40, 80, 5), Color("3a3043"))
		draw_rect(Rect2(-40, -40, 80 * stage.lily_laugh, 5), Color("f6a6c8"))
		if stage.turn == "attack":
			for i in 3:
				var at := Vector2(4 + i * 6, 14)
				draw_circle(at, 2.5, Color("ffd7c4"))
				draw_string(ThemeDB.fallback_font, at + Vector2(-3, 10), ["A", "S", "D"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("e9dcf0"))
		elif stage.warn_left > 0.0:
			# 莉莉要狠狠挠一下了：她脚边亮一个黄圈「!」
			draw_circle(Vector2(-20, -18), 7.0, Color("ffd166"))
			draw_string(ThemeDB.fallback_font, Vector2(-22, -13), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("3a2030"))

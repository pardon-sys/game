class_name LilyDuelShow
extends ErrandWorkStage
## 支线「骑士救公主」第三处：和小莉莉比「谁先笑」，两人坐在鹅卵石小路尽头，光着脚轮流挠对方的脚心。台词 knight_quests.json 的 shoes.duel。
##   挠她（TURN_TIME 秒）：她的弱点每回合换一处（脚趾 / 脚心 / 脚跟）。回合开始时只给动作暗示（weak_hint：脚趾蜷紧、缩脚心、脚跟往回收……），
##     有 FAKE_HINT_CHANCE 的机会是假动作（暗示的是别处，fake_hint 记着）；她嘴上只会逞强（bluff）。
##     A / S / D 挠脚趾 / 脚心 / 脚跟：挠中弱点 莉莉的笑 +HIT；同一个弱点挠中 GUARD_AFTER 次，她护住那里、弱点换地方（guard）。
##     挠错 = 被反挠：小莉莉趁机抓住她的脚挠回来（闷笑 +MISS_BACKLASH，莉莉缓过来 −MISS_RELIEF，backlash 描写 / 三档反应）。两下之间至少隔 PRESS_COOL 秒。
##   忍住（TURN_TIME 秒）：莉莉挠回来，闷笑每秒 +DEFEND_RATE；每 POKE_EVERY 秒亮一次「！」（WARN 秒）然后狠狠一下（+POKE_LAUGH），
##     亮着的时候按 J 缩脚就躲开这一下。
##   她第一次笑满：魔力疲倦释放（星光、释放声、burst 立绘；闷笑回到 BURST_LAUGH），之后 BURST_SENSITIVE 秒全身更敏感，
##     莉莉追着挠（直接换成忍住回合，「！」间隔 ×CHASE_POKE，描写和反应换 sensitive 那一套）；这一局里第二次笑满才算输，两人回到 ROUND_RESET 重来。
##   莉莉笑满 = 赢。魔力疲倦自己满了的释放见 ErrandWorkStage（文本同一套 release）。不存档。
## 测试：quiet、fixed_seed、press()、simulate()、lily_laugh、turn、weak、warn_left、fake_hint、weak_hits、bursts、sensitive_left。

const TURN_TIME := 5.0
const HIT := 0.14
## 挠错被反挠：她的闷笑涨多少（× 闷笑上限）、莉莉的笑回落多少
const MISS_BACKLASH := 0.08
const MISS_RELIEF := 0.04
## 同一个弱点挠中几次后她护住、换地方
const GUARD_AFTER := 3
## 回合开始的暗示是假动作的机会
const FAKE_HINT_CHANCE := 0.25
## 第一次笑满时魔力释放：闷笑回到多少、之后敏感几秒、追着挠时「！」的间隔倍数
const BURST_LAUGH := 0.55
const BURST_SENSITIVE := 6.0
const CHASE_POKE := 0.6
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
## 这回合的暗示是不是假动作
var fake_hint := false
## 当前弱点被挠中了几次
var weak_hits := 0
## 这一局里笑满后已经魔力释放过几次（每局第一次释放、第二次才输）
var bursts := 0
var _poke := POKE_EVERY
var _press := 0.0
var _info: Label
var _rig: DuelRig


static func data() -> Dictionary:
	if _text.is_empty():
		var d: Dictionary = KnightQuests.info("shoes").get("duel", {})
		_text = {"name": d.get("name", "谁先笑"), "hint": d.get("hint", ""), "phases": [{"name": d.get("name", "")}],
			"intro": d.get("intro", []), "done": [{"speaker": "", "text": str((d.get("win", [""]) as Array)[0])}],
			"full": {"desc": str((d.get("lose", [""]) as Array)[0]), "react": d.get("pink_react", [[], [], []])[2]},
			"release": d.get("release", {}), "sensitive": d.get("sensitive", {}), "duel": d}
	return _text



func _init() -> void:
	follow_laugh = true   # 木偶跟着闷笑换姿势


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
		_pick_weak(-1)
		_hint()
		var bluff: Array = duel().get("bluff", [])
		if not bluff.is_empty():
			say("lily", str(bluff[rng.randi_range(0, bluff.size() - 1)]))
	else:
		narrate(str(duel()["turn_defend"]), 1.6, true)
	_refresh()


## 换一个弱点（不和 avoid 一样）
func _pick_weak(avoid: int) -> void:
	weak = rng.randi_range(0, 2)
	while weak == avoid:
		weak = rng.randi_range(0, 2)
	weak_hits = 0


## 回合开始的动作暗示：FAKE_HINT_CHANCE 的机会暗示的是别处
func _hint() -> void:
	fake_hint = rng.randf() < FAKE_HINT_CHANCE
	var shown := weak
	if fake_hint:
		shown = (weak + rng.randi_range(1, 2)) % 3
	var hints: Array = duel()["weak_hint"].get(str(duel()["spots"][shown]), [])
	var cue := str(hints[rng.randi_range(0, hints.size() - 1)]) if not hints.is_empty() else ""
	narrate(str(duel()["turn_attack"]) + "　" + cue, 2.4, true)


func _on_key(k: String) -> void:
	if recovery_left > 0.0 or busy:
		return
	if turn == "attack" and SPOT_KEYS.has(k):
		tickle_lily(int(SPOT_KEYS[k]))
	elif turn == "defend" and k == "J":
		tuck()


## 挠莉莉的一处（0 脚趾 / 1 脚心 / 2 脚跟）：挠中弱点她笑，挠错被她反挠
func tickle_lily(spot: int) -> void:
	if _press > 0.0:
		return
	_press = PRESS_COOL
	if spot != weak:
		backlash()
		return
	lily_laugh = minf(1.0, lily_laugh + HIT)
	weak_hits += 1
	tickle("princess", "sole", false, "lily", "hand")
	var pool: Array = duel()["hit"]
	narrate(str(pool[rng.randi_range(0, pool.size() - 1)]), 1.2, true)
	var r: Array = duel()["lily_react"]
	say("lily", str(r[rng.randi_range(0, r.size() - 1)]))
	if lily_laugh >= 1.0:
		advance_step()
	elif weak_hits >= GUARD_AFTER:
		# 挠中太多次：她护住那里，弱点换地方（新的地方给一个真的暗示）
		_pick_weak(weak)
		var g: Array = duel().get("guard", [])
		var hints: Array = duel()["weak_hint"].get(str(duel()["spots"][weak]), [])
		narrate((str(g[rng.randi_range(0, g.size() - 1)]) if not g.is_empty() else "") + "　"
			+ (str(hints[rng.randi_range(0, hints.size() - 1)]) if not hints.is_empty() else ""), 2.4, true)
		fake_hint = false
	_refresh()


## 挠错了：小莉莉趁机抓住她的脚挠回来
func backlash() -> void:
	lily_laugh = maxf(0.0, lily_laugh - MISS_RELIEF)
	work_laugh(laugh_max() * MISS_BACKLASH)
	tickle("lily", "sole")
	var caps: Array = duel().get("backlash", duel()["miss"])
	narrate(str(caps[rng.randi_range(0, caps.size() - 1)]), 1.6, true)
	var taunt: Array = duel().get("backlash_taunt", [])
	if not taunt.is_empty():
		say("lily", str(taunt[rng.randi_range(0, taunt.size() - 1)]))
	_pop_random(_react_tier(), PINK, 1.2)
	_refresh()


## 她现在该用哪一档反应（释放后敏感时换 sensitive 那一套）
func _react_tier() -> Array:
	var i := clampi(int(player.laugh.ratio() * 3.0) if player.laugh else 0, 0, 2)
	if sensitive_left > 0.0:
		var sens: Dictionary = duel().get("sensitive", {})
		var tier: Array = sens.get(["light", "mid", "heavy"][i], [])
		if not tier.is_empty():
			return tier
	return duel()["pink_react"][i]


## 莉莉挠回来时亮「！」：按 J 缩脚躲开这一下
func tuck() -> bool:
	if warn_left <= 0.0:
		return false
	warn_left = 0.0
	_poke = POKE_EVERY * (CHASE_POKE if sensitive_left > 0.0 else 1.0)
	var ok: Array = duel()["tuck_ok"]
	narrate(str(ok[rng.randi_range(0, ok.size() - 1)]), 1.0, true)
	_refresh()
	return true


## 她笑满了：这一局第一次 = 魔力疲倦释放、之后更敏感被莉莉追着挠；第二次 = 这一局输，两人都回到起点重来
func recover() -> void:
	if bursts == 0:
		burst()
		return
	bursts = 0
	rounds += 1
	lily_laugh = ROUND_RESET
	recovery_left = RECOVER_TIME
	sensitive_left = 0.0
	if player.laugh:
		player.laugh.set_value(laugh_max() * ROUND_RESET)
	var lose: Array = duel()["lose"]
	narrate(str(lose[0]), RECOVER_TIME + 0.6, true)
	_start_turn("attack")


## 第一次笑满：魔力疲倦释放（星光、释放声、burst 立绘），痒意化开一下，然后全身更敏感、莉莉追着挠
func burst() -> void:
	bursts += 1
	release()
	Audio.play("water_release", -6.0)
	sensitive_left = BURST_SENSITIVE
	if player.laugh:
		player.laugh.set_value(laugh_max() * BURST_LAUGH)
	var p: CGActor = actors.get("princess")
	if p:
		p.set_pose("burst", "cast")
	Dialogue.shake_portrait(4.0, 0.4)
	turn = "defend"
	turn_left = RELEASE_TIME + BURST_SENSITIVE
	warn_left = 0.0
	_poke = POKE_EVERY * CHASE_POKE
	_refresh()


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
				warn_left = WARN * (CHASE_POKE if sensitive_left > 0.0 else 1.0)
	if turn_left <= 0.0:
		_start_turn("defend" if turn == "attack" else "attack")
	_refresh()


func _poke_now() -> void:
	_poke = POKE_EVERY * (CHASE_POKE if sensitive_left > 0.0 else 1.0)
	work_laugh(laugh_max() * POKE_LAUGH)
	tickle("lily", "sole")
	var desc: Array = duel()["tickle_desc"]
	if sensitive_left > 0.0:
		desc = duel().get("sensitive", {}).get("desc", desc)
	narrate(str(desc[rng.randi_range(0, desc.size() - 1)]), 1.4)
	_pop_random(_react_tier(), PINK, 1.2)


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

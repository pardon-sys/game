class_name TaskKnightBoss
extends Node2D
## 骑士篇 F Boss「痒铠骑士」（骑士篇的空小镇 floor_06_knight_chase 的广场）：被诅咒附身的盔甲在广场上追着人打，骑士本人不掉血。
## 台词 data/after/knight_finale.json 的 boss（← knight_text/finale.py）；场上的东西画在 KnightBossFx 里；屏幕上方的耐久条 KnightBossHud。
## 四个阶段，每个阶段拆掉一套盔甲（部件 BossPart，跟着本体走）：0 铁手套 → 1 护腿 → 2 胸甲 → 3 头盔笑面（拆不掉，最后靠「全镇的笑声」净化）。
##   部件平时诅咒太硬打不动：被蓝色公主冻住（J，FREEZE_R 以内，冻 FREEZE_TIME 秒，冷却 FREEZE_COOL）、护腿跺完 / 冲撞完 / 跳完卡住（stuck）、
##   骑士清醒（lucid）的时候，谁的普通攻击都能打（PART_HP 下掉）。
##   **会动**：平时朝目标走（WALK_SPEED，保持 KEEP_DIST），隔一阵侧跳（SIDESTEP）；出招前站定 WINDUP 秒、身上发光（这是攻击的空当）；
##     不会在换阶段时瞬移回中间。广场上有木箱（KnightBossFx.Crate，挡人挡甲片）：冲撞撞上去箱子碎、盔甲卡住。
##   **每招都躲得开**：都有预警（新招第一次用时预警时间 ×FIRST_SLOW）；冲刺无敌的时候什么都打不中；
##     呼唤骑士之名先蓄力 NAME_WINDUP 秒，冲击波有 RING_GAPS 个缺口（KnightBossFx.Ring.GAP）；护心磁吸半径 MAGNET_R、吸力比走路慢，往外走就走得掉。
##   出招（每 attack_interval() 秒一招：ATTACK_EVERY × 这一阶段剩下的耐久越少越快；从 SKILLS 里挑，不连着用同一招；粉色公主贴近 SOFT_R 以内时变慢；
##     这一阶段第二招起有 COMBO_CHANCE 接一招）：
##     铁手套：扑抓 / 扫腿 / 弹指 / 十指痒网；护腿：跺地痒波 + 召手印 / 冲撞 / 踢沙 / 跳起来砸地（leap：落点影子 LEAP_WARN 秒）；
##     胸甲：诅咒穿戴 / 护心磁吸 / 甲片飞散 / 跳起来砸地；笑面：吐笑气 / 呼唤骑士之名 / 镜面笑脸。
##   反击——挠骑士：每掉一个部件（还有卡住、喊完骑士之名、千手解放、完美闪避）露出破绽（WeakSpot）WEAK_TIME 秒，打破绽 = 骑士的笑 +KNIGHT_TICKLE；
##     满了：骑士清醒 LUCID_TIME 秒（第一次清醒时有安神香的话自动点上，再多 INCENSE_BONUS 秒）；笑面阶段挠满：触手全缩回去、每盏没亮的灯笼 +LUCID_LANTERN。
##   **换阶段不黑屏**（_transition）：清场 → 部件炸开（Burst、顿帧 HITSTOP、震屏）→ 骑士踉跄 TRANS_STAGGER 秒、喊一句、两位公主各一句 → 下一阶段（左上角提示）。
##   **最后阶段「全镇的笑声」**：广场四角四盏被吸暗的灯笼（LANTERNS）。站在灯笼旁按住 Y 故意笑（KnightLaugh）→ 灯笼每秒 +LANTERN_RATE；
##     做过的支线（KnightQuests.helpers：灯笼顺序 shoes / samples / spear / fence）那个人跑到他那盏灯笼下陪着笑：×HELPER_MULT，没人在也自己慢慢亮（HELPER_SOLO）。
##     笑面每 TENTACLE_EVERY 秒伸一条触手（Tentacle）爬向一盏没亮的灯笼，缠住以后每秒 −TENTACLE_DRAIN；蓝色公主 J 冻住它（碎）、千手解放全缩回去。
##     骑士照样出招，随时可以离开灯笼去躲。四盏都亮 → 光柱汇到盔甲上 → 过场 knight_purify（手帕）→ 胜利。
##   场上的人（Victim）：逃跑的镇民、被挠倒的队员、护着镇民的队员。在掩体（COVERS）之间乱跑、躲着探头，盔甲靠近就逃。
##     手印会贴上去（最多 MAX_CURSED 个，每 CURSE_EVERY 秒一个）：走到身边按住 E 1 秒（AI 搭档站在旁边也算）或者蓝色公主冻住它 = 救下来：
##     冻结冷却马上好，被救的队员替公主挡一次扑抓 / 冲撞（shield）；有人被贴着超过 ENRAGE_AFTER 秒没人管：诅咒变强（出招间隔 ×ENRAGE）。
##     没被贴的人短按 E 说话（talk）：奶奶递薄荷糖（闷笑 −TALK_MINT）、队员替你挡一下（shield，每人每阶段一次）、其他人喊一句提示。
##   支线的帮手：「队长的旧剑术」→ 完美闪避（命中前 PERFECT 秒内才冲刺）露出破绽，开场 shield +1（队长挡一次）；「手印样本」→ 安神香。
##   被抓 / 绊倒累计 CATCHES 次 = 失败（按阶段的四幕小剧场 fail_theater），从这个阶段重来（打碎的部件不回来）。这段能换人（C，只在两位公主之间）。
##   没被操控的那位由 AI 控制（KnightAI，ai_plan + Hooks）：两人都躲预警；AI 蓝色公主冻没冻的部件、去冻贴着人的手印、去冻触手、合适的时候放千手解放；
##     AI 粉色公主贴近本体（出招变慢）、有破绽 / 冻住的部件就去打、搭档身上有诅咒装备就去扯、被抓住自己连按挣开；最后阶段两人都去没亮的灯笼下笑。
## **最后阶段在「笑雾之中」**（KnightStory 步骤 boss → boss_fog）：广场上胸甲打完（_transition 到第 3 阶段）不在广场打笑面——
##   PHASE_KEY 记成 3、发 finished(true) 结束这一步（_split_to_fog）→ 过场 knight_fog_rise → 换到等距的新图 floor_06_knight_fog（广场的倒影，坐标一样）→
##   同一个脚本从第 3 阶段接着打（on_fog()）：配乐 knight_fog；骑士被黑雾托在半空（floating：画 npcs/knight_possessed.png 的浮空帧、周围飘笑声字，打不到）；
##   外圈黑雾 KnightFogRing 慢慢收紧（圈外痒、挂 fog_tickle；每亮一盏灯笼往外推）；点灯照旧（帮手、触手、诅咒）。
##   四盏都亮 → 骑士落地 → 驱散 KnightDispel（粉色公主吟唱、玩家操控蓝色公主拦黑气小手、小窗看读条）：读满 → 净化（_purify）；
##   粉色公主闷笑第二次满 → 失败（DISPEL_KEY 记着，失败小剧场 knight_fail_fog，重来时灯笼直接亮着、从驱散开始）。
## 状态 vars.task_boss_phase（0~3）、task_boss_caught、task_boss_dispel（驱散阶段失败过：重来从驱散开始）。
##   **诅咒爆发 / 盯上镇民**（KnightCurse，curse）：每个阶段开始一次、耐久掉一半一次，爆发期间部件打不动、靠近闷笑狂涨、吸到笑声回耐久，
##     每个阶段破解办法不同（手印风暴 / 痒波地脉 / 护心诅咒；笑面阶段是定时的「吸笑」，站进亮灯笼的光里）；平时隔一阵盯上一个镇民去偷笑声，按住 Y 笑把它引回来。
## 测试：curse、parts、phase、lanterns、tentacles、crates、freeze_part()、hit_part()、grab(角色)、mash()、stomp()、flick()、net()、charge()、sand()、leap()、
##   throw_gear()、wear_gear()、magnet()、shards()、name_call()、mirrors()、send_tentacle()、tickle_knight()、curse_victim()、rescue()、talk_to()、
##   durability()、ai_plan()、ai_enabled、skip_cutscenes、windup_left、body_mode。

signal finished(ok: bool)

const CENTER := Vector2i(41, 22)
const ARENA := Vector2(140, 100)
const PART_HP := 6
const FREEZE_R := 44.0
const FREEZE_TIME := 4.0
const FREEZE_COOL := 5.0
const SOFT_R := 40.0
const SOFT_SLOW := 1.6
const PHASES := 4
const PHASE_NAMES := ["铁手套", "护腿", "胸甲", "笑面"]
## 每个阶段有几个部件（耐久条按它分段）
const PHASE_PARTS := [2, 2, 2, 1]
const SKILLS := [["grab", "sweep", "flick", "net"], ["stomp", "charge", "sand", "leap"], ["gear", "magnet", "shards", "leap"], ["gas", "name", "mirror"]]
const ATTACK_EVERY := [3.0, 3.2, 3.0, 3.6]
const COMBO_CHANCE := 0.35
const FIRST_SLOW := 2.0
## 走路 / 侧跳 / 出招前站定
const WALK_SPEED := 30.0
const KEEP_DIST := 46.0
const SIDESTEP_EVERY := 3.5
const SIDESTEP_TIME := 0.45
const SIDESTEP_SPEED := 80.0
const WINDUP := 0.4
const GRAB_WARN := 0.9
const GRAB_R := 14.0
const GRAB_TIME := 3.5
const MASH := 7
const HARD_LAUGH := 0.12
const SOFT_LAUGH := 0.04
## 粉色公主被抱住：疲倦另外乘的倍数（普通流程疲倦 = 闷笑 × 0.5；原来手写每秒 +10% 疲倦，换算下来约 16 倍）
const SOFT_FATIGUE_MULT := 16.0
const SWEEP_LEN := 200.0
const SWEEP_W := 14.0
const WAVE_R := 110.0
const WAVE_TIME := 1.1
const WAVE_LAUGH := 0.1
const STUCK_TIME := 2.2
const SUMMON := 3
const GAS_R := 26.0
const GAS_RATE := 0.08
const GAS_LIFE := 6.0
const CATCHES := 4
## 跳起来砸地
const LEAP_WARN := 0.9
const LEAP_R := 26.0
const LEAP_LAUGH := 0.1
const LEAP_STUCK := 1.2
## 反击：破绽、骑士的笑、清醒
const WEAK_TIME := 4.0
const KNIGHT_TICKLE := 0.25
const LUCID_TIME := 5.0
const INCENSE_BONUS := 3.0
const PERFECT := 0.25
## 弹指 / 诅咒装备 / 甲片 / 痒尘 / 冲击波 / 镜面笑脸
const FLICK_SPEED := 130.0
const FLICK_LAUGH := 0.08
const NET_DELAY := 0.12
const NET_LAUGH := 0.1
const CHARGE_WARN := 0.8
const CHARGE_LEN := 170.0
const CHARGE_SPEED := 260.0
const DUST_RATE := 0.06
const GEAR_SPEED := 110.0
const GEAR_LAUGH := 0.05
const GEAR_TEARS := 8
const GEAR_PULL := 1.0
const GEARS := {"equip_t_feather_socks": "sole", "equip_t_toe_brush": "sole", "equip_t_thigh_ring": "thigh",
	"equip_t_feather_shackles": "sole", "equip_t_bell_anklet": "sole"}
const MAGNET_TIME := 2.0
const MAGNET_R := 90.0
const MAGNET_PULL := 40.0
const SHARDS := 6
const SHARD_LAUGH := 0.07
const RING_LAUGH := 0.08
const RING_PUSH := 40.0
const RING_GAPS := 3
const NAME_WINDUP := 0.8
const MIRRORS := 3
const MIRROR_RATE := 0.1
## 场上的人和救人
const MAX_CURSED := 2
const CURSE_EVERY := 10.0
const RESCUE_R := 22.0
const RESCUE_TIME := 1.0
const ENRAGE_AFTER := 15.0
const ENRAGE := 0.75
const BURST_STAGGER := 2.0
const TALK_R := 22.0
const TALK_COOL := 8.0
const TALK_MINT := 0.15
## 换阶段（场内）
const TRANS_STAGGER := 1.6
const HITSTOP := 0.06
## 最后阶段：灯笼、帮手、触手
const LANTERN_R := 22.0
const LANTERN_RATE := 0.09
const LANTERN_AI_RATE := 0.06
const HELPER_MULT := 2.0
const HELPER_SOLO := 0.03
const LUCID_LANTERN := 0.15
const TENTACLE_EVERY := 7.0
const TENTACLE_TRAVEL := 1.5
const TENTACLE_DRAIN := 0.08
const TENTACLE_FREEZE_R := 30.0
## AI 被抓 / 被穿上诅咒装备时多久挣一下
const AI_MASH_EVERY := 0.18
## 召出来的小手：活 HAND_LIFE 秒自己散；爬进亮着的灯笼光里就化掉；被扫帚扫（BROOM_R）
const HAND_LIFE := 15.0
const BROOM_R := 56.0
const PHASE_KEY := "task_boss_phase"
const CAUGHT_KEY := "task_boss_caught"
const SHEET := preload("res://assets/generated/npcs/knight_cursed.png")
## 笑雾之中
const FOG_FLOOR := "floor_06_knight_fog"
const DISPEL_KEY := "task_boss_dispel"
const POSSESSED_SHEET := preload("res://assets/generated/npcs/knight_possessed.png")
const POSSESSED_CELL := 80
## 浮空的高度、上下浮动的幅度；落地动画的秒数
const FLOAT_H := 30.0
const FLOAT_BOB := 4.0
const LAND_TIME := 1.2
## 场上的人：[人物图, 样子, 相对广场中间的位置]
const VICTIMS := [["guard", "fallen", Vector2(-92, 40)], ["guard", "fallen", Vector2(96, -34)], ["guard", "guard", Vector2(-104, -40)],
	["kid", "runner", Vector2(-120, 70)], ["granny", "runner", Vector2(120, 70)],
	["merchant", "runner", Vector2(-150, -10)], ["miner", "runner", Vector2(150, -50)], ["maid", "runner", Vector2(40, 100)],
	["supervisor", "runner", Vector2(-40, -70)], ["kid", "runner", Vector2(60, -80)]]
## 广场上的木箱（相对广场中间）
const CRATES := [Vector2(-80, -16), Vector2(80, -32), Vector2(-48, 64), Vector2(80, 64)]
## 镇民躲的地方（相对广场中间：木箱后面、长椅后面、灯柱边）
const COVERS := [Vector2(-80, -4), Vector2(80, -20), Vector2(-48, 76), Vector2(80, 76), Vector2(-16, -10), Vector2(112, -10),
	Vector2(-64, 18), Vector2(160, 30), Vector2(-120, 30), Vector2(16, 90),
	Vector2(-160, -40), Vector2(150, -70), Vector2(-30, -80), Vector2(60, 110)]
## 四盏灯笼（相对广场中间：东北、西北、西南、东南——和支线帮手的顺序对应：shoes、samples、spear、fence）
const LANTERNS := [Vector2(112, -64), Vector2(-112, -64), Vector2(-112, 96), Vector2(112, 96)]
const HELPER_ORDER := ["shoes", "samples", "spear", "fence"]
## 墙根爬着的诅咒小手（装饰，相对广场中间）
const DECOR := [Vector2(-150, -80), Vector2(-130, -96), Vector2(150, -84), Vector2(170, -60), Vector2(-170, 40), Vector2(-160, 110),
	Vector2(165, 110), Vector2(180, 20), Vector2(-60, -100), Vector2(60, -104), Vector2(0, 124), Vector2(-100, 124)]

static var _data := {}
## 测试：不演 knight_purify
static var skip_cutscenes := false

var aborted := false
var started := false
var pink: PlayableCharacter
var blue: PlayableCharacter
var phase := 0
var parts: Array = []
var hands: Array = []
var gases: Array = []
var fx: Array = []
var victims: Array = []
var crates: Array = []
var lanterns: Array = []
var tentacles: Array = []
var helpers: Array = []
var transitioning := false
var finale := false
var freeze_cool := 0.0
var attack_t := 2.0
var stuck_left := 0.0
var wave_left := 0.0
var wave_r := 0.0
var grabbed: PlayableCharacter
var grab_left := 0.0
var mashes := 0
var warn: Dictionary = {}
var knight_laugh := 0.0
var weak_left := 0.0
var weak_spot: Node2D
var lucid_left := 0.0
var charge_dir := Vector2.ZERO
var charge_left := 0.0
var magnet_left := 0.0
var shield := 0
var curse_t := CURSE_EVERY * 0.5
var enraged := false
var last_skill := ""
## 本体在干什么：walk 走 / sidestep 侧跳 / windup 出招前站定 / leap 跳在空中 / stagger 换阶段踉跄
var body_mode := "walk"
var windup_left := 0.0
var pending_skill := ""
var leap_left := 0.0
var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO
var tentacle_t := TENTACLE_EVERY * 0.5
var used_skills := {}
var phase_attacks := 0
var incense_used := false
var _perfect_cool := 0.0
var _side_t := SIDESTEP_EVERY
var _side_left := 0.0
var _side_dir := Vector2.ZERO
var _home := Vector2.ZERO
var _voice_t := 4.0
var _emitted := false
var _music_was := ""
var _lv: Node
var _was_no_switch := false
var _had_switch := false
var _body: Node2D
var _shadow: KnightBossFx.LeapShadow
var _decor: KnightBossFx.Decor
var _hud: KnightBossHud
var _t := 0.0
var _tips := {}
var curse: KnightCurse
## 做过支线的人在场上帮忙（KnightHelpers）
var field_helpers: KnightHelpers
## 笑雾之中：浮在半空 / 落地动画剩下的秒数 / 雾圈 / 驱散
var floating := false
var land_left := 0.0
var fog_ring: KnightFogRing
var dispel: KnightDispel
var _split := false
## 右上角另一位公主的状态面板（千手战的 PartnerPanel，不用 Duo）；Boss 战里关掉跟随瞬移（记下原来的 follow）
var partner_panel: PartnerPanel
var _follow_was := {}
var _ai_hooks: BattleAIHooks


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/after/knight_finale.json")) if FileAccess.file_exists("res://data/after/knight_finale.json") else null
		_data = parsed if parsed is Dictionary else {}
	return _data.get("boss", {})


static func caught() -> int:
	return int(GameState.vars.get(CAUGHT_KEY, 0))


## 失败小剧场按阶段换（AfterStory.play_task 问）：铁手套 / 护腿 → knight_fail_boss，胸甲 → _2，笑面 → _3
static func fail_theater() -> String:
	if bool(GameState.vars.get(DISPEL_KEY, false)):
		return "knight_fail_fog"
	var p := int(GameState.vars.get(PHASE_KEY, 0))
	return "knight_fail_boss" if p <= 1 else "knight_fail_boss_%d" % (p)


static func reset_items() -> void:
	GameState.vars[CAUGHT_KEY] = 0


static func status_text() -> String:
	var p := clampi(int(GameState.vars.get(PHASE_KEY, 0)), 0, PHASES - 1)
	var tips: Array = data().get("phase_tips", [])
	return "%s　被抓 %d / %d%s" % [PHASE_NAMES[p], caught(), CATCHES, ("\n" + str(tips[p])) if p < tips.size() else ""]


func _ready() -> void:
	_lv = get_parent().get_parent()
	for n in _lv.find_children("*", "PlayableCharacter", true, false):
		if n is BluePrincess:
			blue = n
		elif not n is BonfireHost:
			pink = n
	_was_no_switch = bool(_lv.get("no_switch"))
	_had_switch = _lv.get_meta(&"free_switch", false)
	_lv.set("no_switch", false)
	_lv.set_meta(&"free_switch", true)
	Duo._bind_tab()   # 骑士篇的小镇图写了 no_switch，C 键原来没绑上
	_home = Cutscene.cell_to_world(CENTER)
	_body = Body.new()
	(_body as Body).task = self
	get_parent().add_child(_body)
	_body.global_position = _home
	for off in CRATES:
		var c := KnightBossFx.Crate.new()
		get_parent().add_child(c)
		c.global_position = _home + (off as Vector2)
		crates.append(c)
	_decor = KnightBossFx.Decor.new()
	get_parent().add_child(_decor)
	_decor.global_position = _home
	_decor.spots.assign(DECOR.map(func(o): return _home + (o as Vector2)))
	_spawn_victims()
	curse = KnightCurse.new()
	curse.task = self
	get_parent().add_child(curse)
	curse.global_position = Vector2.ZERO
	add_to_group(PantsBurst.KNIGHT_GROUP)
	# 支线「队长的旧剑术」：到时候我会在——队长替她挡一次
	shield = 1 if KnightQuests.is_done("spear") else 0
	phase = clampi(int(GameState.vars.get(PHASE_KEY, 0)), 0, PHASES - 1)
	_enter_phase(phase)
	var hooks := Hooks.new()
	hooks.task = self
	_ai_hooks = hooks
	KnightAI.install([pink, blue], ai_plan, hooks)
	field_helpers = KnightHelpers.new()
	field_helpers.task = self
	add_child(field_helpers)
	field_helpers.setup()
	_hud = KnightBossHud.new()
	_hud.task = self
	add_child(_hud)
	partner_panel = PartnerPanel.new()
	partner_panel.pair = [pink, blue]
	partner_panel.top = 52.0   # 让开顶部的耐久条
	add_child(partner_panel)
	# Boss 战里不瞬移：离太远时 AI 自己走过去（剧情跟随的瞬移在 _exit_tree 恢复）
	for c in [pink, blue]:
		if is_instance_valid(c):
			_follow_was[c] = c.follow
			c.follow = false
	_music_was = Audio.music_id
	Audio.play_music("knight_fog" if on_fog() else "knight_boss")
	if on_fog() and phase == PHASES - 1:
		_setup_fog()
	started = true


func _exit_tree() -> void:
	for c in _follow_was:
		if is_instance_valid(c):
			c.follow = bool(_follow_was[c])
	Engine.time_scale = 1.0
	if _music_was != "" and Audio.music_id in ["knight_boss", "knight_fog"]:
		Audio.play_music(_music_was)
	_clear_field(true)
	if is_instance_valid(field_helpers):
		field_helpers.cleanup()
	for n in parts + victims + crates + lanterns + helpers + [_body, _decor, _shadow, curse]:
		if is_instance_valid(n):
			n.queue_free()
	KnightAI.uninstall()
	if is_instance_valid(_lv):
		_lv.set("no_switch", _was_no_switch)
		_lv.set_meta(&"free_switch", _had_switch)
	if is_instance_valid(pink) and GameState.player != pink and is_instance_valid(GameState.player):
		GameState.switch_control(pink)


func _enter_phase(p: int) -> void:
	phase = p
	GameState.vars[PHASE_KEY] = p
	for part in parts:
		if is_instance_valid(part):
			part.queue_free()
	parts.clear()
	knight_laugh = 0.0
	lucid_left = 0.0
	phase_attacks = 0
	_close_weak()
	var ids: Array = [[["gauntlet_l", Vector2(-22, -10)], ["gauntlet_r", Vector2(22, -10)]],
		[["greave_l", Vector2(-10, 12)], ["greave_r", Vector2(10, 12)]],
		[["plate_l", Vector2(-11, -18)], ["plate_r", Vector2(11, -18)]],
		[["mask", Vector2(0, -34)]]][p]
	for spec in ids:
		var part := BossPart.new()
		part.task = self
		part.id = str(spec[0])
		part.offset = spec[1]
		part.hp = PART_HP
		get_parent().add_child(part)
		part.global_position = _body.global_position + part.offset
		parts.append(part)
	attack_t = 2.0
	last_skill = ""
	body_mode = "walk"
	var lines: Array = data().get("phase_intro", [])
	if p < lines.size() and not (lines[p] as Array).is_empty():
		GameState.princess_reacted.emit(str(lines[p][0]), 3.0)
	if p == PHASES - 1:
		_start_lanterns()
	if is_instance_valid(curse):
		curse.phase_started(p)
	if is_instance_valid(field_helpers):
		field_helpers.phase_started(p)


## 现在是不是在「笑雾之中」那张图
func on_fog() -> bool:
	return is_instance_valid(_lv) and str(_lv.get("floor_id")) == FOG_FLOOR


func level() -> Node:
	return _lv


## 骑士本体的位置（驱散时粉色公主要站到他身边）
func body_pos() -> Vector2:
	return _body.global_position if is_instance_valid(_body) else _home


## 进了笑雾：骑士浮起来、外圈黑雾、提示；驱散失败过的话灯笼直接亮着、马上驱散
func _setup_fog() -> void:
	floating = true
	fog_ring = KnightFogRing.new()
	fog_ring.task = self
	get_parent().add_child(fog_ring)
	fog_ring.global_position = _home
	var tip := str(data().get("fog", {}).get("tip", ""))
	if tip != "":
		GameState.notify(tip)
	if bool(GameState.vars.get(DISPEL_KEY, false)):
		for l in lanterns:
			if is_instance_valid(l) and not l.lit:
				_light(l, 1.0)


## 广场上胸甲打完：这一步到这里结束（PHASE_KEY 留在 3），剧情演笑雾涌起、换图，在雾里接着打
func _split_to_fog() -> void:
	_split = true
	GameState.vars[PHASE_KEY] = PHASES - 1
	_emit(true)


## 四盏灯笼都亮了（雾里）：骑士落地 → 驱散
func _start_dispel() -> void:
	if is_instance_valid(dispel) or finale:
		return
	floating = false
	land_left = LAND_TIME
	GameState.vars[DISPEL_KEY] = true
	if is_instance_valid(fog_ring):
		fog_ring.frozen = true
	for tn in tentacles:
		if is_instance_valid(tn):
			tn.queue_free()
	tentacles.clear()
	var lines: Array = data().get("fog", {}).get("land", [])
	if not lines.is_empty():
		GameState.princess_reacted.emit(str(lines[0]), 3.0)
	_shake(0.4, 3.0)
	dispel = KnightDispel.new()
	dispel.task = self
	add_child(dispel)


func _dispel_done() -> void:
	GameState.vars[DISPEL_KEY] = false
	await _purify()


func _dispel_failed() -> void:
	_emit(false)


## 拆完一套：清场 → 部件炸开（顿帧、震屏）→ 骑士踉跄、喊一句 → 下一阶段（不黑屏、不演过场）
func _transition(p: int) -> void:
	transitioning = true
	_clear_field()
	if grabbed:
		_release_grab()
	body_mode = "stagger"
	KnightFx.play(get_parent(), "curse_burst", _body.global_position + Vector2(0, -20), {"size": 120.0, "fps": 12.0, "z": 5})
	var info: Array = data().get("transition", [])
	var tr: Dictionary = info[p] if p < info.size() else {}
	_burst(_body.global_position + Vector2(0, -20), KnightBossFx.PURPLE)
	# 换阶段：贴在镇民身上的手印也一起散掉、墙根的诅咒小手淡一截
	for v in victims:
		if is_instance_valid(v) and v.cursed:
			v.cursed = false
			v.cursed_t = 0.0
			v.rescue = 0.0
	enraged = false
	if is_instance_valid(_decor):
		_decor.fade = minf(_decor.fade, 1.0 - 0.2 * float(p))
	_shake(0.4, 4.0)
	_hitstop()
	if str(tr.get("stagger", "")) != "":
		GameState.princess_reacted.emit(str(tr["stagger"]), TRANS_STAGGER + 1.0)
	if str(tr.get("bark", "")) != "":
		SpeechBubble.say(_body, str(tr["bark"]), 46.0, TRANS_STAGGER)
	await get_tree().create_timer(TRANS_STAGGER * 0.5).timeout
	if not is_inside_tree() or _emitted:
		return
	for pair in [[pink, "pink"], [blue, "blue"]]:
		if is_instance_valid(pair[0]) and str(tr.get(pair[1], "")) != "":
			SpeechBubble.say(pair[0], str(tr[pair[1]]), 30.0, 2.0)
	await get_tree().create_timer(TRANS_STAGGER * 0.5).timeout
	if not is_inside_tree() or _emitted:
		return
	if p == PHASES - 1 and not on_fog():
		_split_to_fog()
		return
	_enter_phase(p)
	transitioning = false


## 清场；quiet：整个任务收走的时候（不冒烟、不加特效）
func _clear_field(quiet := false) -> void:
	_clear_warn()
	if is_instance_valid(curse):
		curse.end(true)
		curse._end_hunt()
	for h in hands:
		if is_instance_valid(h):
			if quiet:
				(h as Node).queue_free()
			else:
				(h as CurseHand).puff()
	for n in gases + fx + tentacles:
		if is_instance_valid(n):
			n.queue_free()
	hands.clear()
	gases.clear()
	fx.clear()
	tentacles.clear()
	_close_weak()
	if is_instance_valid(_shadow):
		_shadow.queue_free()
	_shadow = null
	charge_left = 0.0
	magnet_left = 0.0
	wave_left = 0.0
	leap_left = 0.0
	windup_left = 0.0
	pending_skill = ""
	for c in _players():
		_take_gear(c)


func _process(delta: float) -> void:
	if _emitted or not started or transitioning or GameState.in_dialogue or GameState.in_cutscene or not is_instance_valid(pink):
		return
	advance(delta)


func advance(delta: float) -> void:
	_t += delta
	freeze_cool = maxf(0.0, freeze_cool - delta)
	stuck_left = maxf(0.0, stuck_left - delta)
	lucid_left = maxf(0.0, lucid_left - delta)
	_perfect_cool = maxf(0.0, _perfect_cool - delta)
	if weak_left > 0.0:
		weak_left -= delta
		if weak_left <= 0.0:
			_close_weak()
	if Input.is_action_just_pressed("attack"):
		var me := GameState.player
		if grabbed and me == grabbed:
			mash()
		elif me.has_meta(&"knight_gear"):
			tear_gear(me)
		elif me == blue:
			freeze_part(blue)
	if Input.is_action_just_pressed("interact"):
		talk_near(GameState.player)
	_tick_gears(delta)
	_tick_victims(delta)
	if is_instance_valid(curse) and not grabbed:
		curse.tick(delta)
	if is_instance_valid(field_helpers):
		field_helpers.tick(delta)
	if grabbed:
		_grab_tick(delta)
		return
	_tick_warn(delta)
	_tick_wave(delta)
	_tick_gas(delta)
	_tick_fx(delta)
	_tick_charge(delta)
	_tick_magnet(delta)
	_tick_leap(delta)
	_tick_hands()
	_voice(delta)
	if phase == PHASES - 1:
		_tick_lanterns(delta)
		if finale or _emitted:
			return
	_move(delta)
	if body_mode == "windup":
		windup_left -= delta
		if windup_left <= 0.0:
			body_mode = "walk"
			use_skill(pending_skill)
		return
	var busy := not warn.is_empty() or stuck_left > 0.0 or charge_left > 0.0 or magnet_left > 0.0 or leap_left > 0.0
	attack_t -= delta * (1.0 / SOFT_SLOW if _pink_near() else 1.0) / (ENRAGE if enraged else 1.0)
	if attack_t <= 0.0 and not busy:
		attack_t = attack_interval()
		_attack()


## 这一招到下一招隔几秒：这一阶段剩下的耐久越少越快
func attack_interval() -> float:
	return float(ATTACK_EVERY[phase]) * (0.65 + 0.35 * phase_hp_ratio())


## 这一阶段的部件还剩多少耐久（0~1）
func phase_hp_ratio() -> float:
	var total := PART_HP * int(PHASE_PARTS[phase])
	var left := 0
	for part in parts:
		if is_instance_valid(part) and not part.broken:
			left += part.hp
	return float(left) / float(total) if total > 0 else 0.0


## 整套盔甲的耐久（0~1，耐久条读）：前面阶段的部件全碎，后面阶段的全满；笑面那一段按灯笼亮了几盏算
func durability() -> float:
	var total := 0.0
	var left := 0.0
	for i in PHASES:
		var seg := float(PHASE_PARTS[i])
		total += seg
		if i > phase:
			left += seg
		elif i == phase:
			left += seg * (lantern_left() if i == PHASES - 1 else phase_hp_ratio())
	return left / total


## 笑面那一段还剩多少（没亮的灯笼占比）
func lantern_left() -> float:
	if lanterns.is_empty():
		return 1.0
	var lit := lanterns.filter(func(l): return is_instance_valid(l) and l.lit).size()
	return 1.0 - float(lit) / float(lanterns.size())


func _pink_near() -> bool:
	return pink.global_position.distance_to(_body.global_position) <= SOFT_R + 16.0


func _players() -> Array:
	return [pink, blue].filter(func(c): return is_instance_valid(c))


func _target() -> PlayableCharacter:
	var ps := _players()
	return ps[randi() % ps.size()] if not ps.is_empty() else pink


## 第一次出现的机制：演一段介绍过场（knight_intro_<key>，战斗跟着暂停——_process 碰到 in_cutscene 就停）。
## 看过就不再演（标记 knight_intro_seen_<key>）；不再出黄字。追逃也用它（throw）。测试关掉：intros = false。
static var intros := true


static func intro(key: String) -> bool:
	var id := "knight_intro_" + key
	var flag := "knight_intro_seen_" + key
	if not intros or skip_cutscenes or GameState.has_flag(flag) or not Cutscene.has_cutscene(id):
		return false
	GameState.set_flag(flag)
	Cutscene.play(id)
	return true


func _tip(key: String) -> void:
	if _tips.has(key):
		return
	_tips[key] = true
	intro(key)


## 招式的分量（技能 → 特效 / 音效的对照表在 ARCHITECTURE.md 骑士 Boss 一节）：
## 重击（跺地 / 落地 / 撞墙）：SiegeFx.impact 裂地 + 碎石 + 尘土（strong 时震屏 + 顿帧）、白闪一下、音效；轻的只有圈和音效。
const IMPACT_COL := Color(0.85, 0.55, 1.0)


func _impact(at: Vector2, r: float, strong: bool, sound := "wall_crash", vol := -2.0) -> void:
	SiegeFx.impact(get_parent(), at, r, strong, IMPACT_COL)
	if strong:
		_flash_body()
	if sound != "":
		Audio.play(sound, vol, 0.06)


## 出招 / 重击时盔甲白闪一下
func _flash_body() -> void:
	if is_instance_valid(_body):
		_body.modulate = Color(2.2, 2.0, 2.4)
		_body.create_tween().tween_property(_body, "modulate", Color.WHITE, 0.18)


## 招式起手：音效 + 紫色的蓄力圈往里收（让人一眼看出「要来了」）
func _windup_fx(sound: String, r := 34.0, vol := -4.0) -> void:
	if sound != "":
		Audio.play(sound, vol, 0.05)
	var ringn := SiegeFx.ring(get_parent(), _body.global_position + Vector2(0, -4), r, Color(0.9, 0.45, 1.0, 0.9), 0.45, 0.1)
	if ringn:
		ringn.scale = Vector2(1.6, 1.2)
		ringn.create_tween().tween_property(ringn, "scale", Vector2(0.6, 0.45), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _shake(time: float, power: float) -> void:
	for c in _players():
		if c == GameState.player:
			c.shake_camera(time, power)


## 顿帧：部件碎的那一下停一小会儿
func _hitstop() -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(HITSTOP, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _burst(at: Vector2, col: Color) -> void:
	var b := KnightBossFx.Burst.new()
	b.col = col
	get_parent().add_child(b)
	b.global_position = at
	Fx.burst(get_parent(), at, "spark", 14, 80.0, 0.6, Vector2(0, 60), Color(1, 0.8, 1.0))


# ------------------------------------------------------------------ 走位
func _move(delta: float) -> void:
	if body_mode in ["windup", "stagger"] or stuck_left > 0.0 or charge_left > 0.0 or leap_left > 0.0 or magnet_left > 0.0 or not warn.is_empty():
		return
	var at := _body.global_position
	var step := Vector2.ZERO
	if _side_left > 0.0:
		_side_left -= delta
		step = _side_dir * SIDESTEP_SPEED * delta
	else:
		var goal := _focus().global_position
		if at.distance_to(goal) > KEEP_DIST:
			step = at.direction_to(goal) * WALK_SPEED * delta
		_side_t -= delta
		if _side_t <= 0.0:
			_side_t = SIDESTEP_EVERY + randf_range(-0.8, 0.8)
			_side_left = SIDESTEP_TIME
			_side_dir = at.direction_to(goal).orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	# 绕开木箱
	for c in crates:
		if is_instance_valid(c) and (at + step).distance_to(c.global_position) < KnightBossFx.Crate.R + 14.0:
			step = step.slide(at.direction_to(c.global_position)) if step != Vector2.ZERO else step
	_body.global_position = _clamp_arena(at + step)


## 往哪儿走：盯上了镇民就走向他，不然跟着玩家
func _focus() -> Node2D:
	if is_instance_valid(curse) and is_instance_valid(curse.hunt):
		return curse.hunt
	return GameState.player if is_instance_valid(GameState.player) else pink


func _clamp_arena(p: Vector2) -> Vector2:
	var lim := Rect2(_home - ARENA, ARENA * 2.0)
	return Vector2(clampf(p.x, lim.position.x, lim.end.x), clampf(p.y, lim.position.y, lim.end.y))


# ------------------------------------------------------------------ 出招
func _attack() -> void:
	var pool: Array = (SKILLS[phase] as Array).duplicate()
	if pool.size() > 1:
		pool.erase(last_skill)
	var skill: String = str(pool.pick_random())
	last_skill = skill
	phase_attacks += 1
	# 出招前站定、发光（攻击的空当）
	body_mode = "windup"
	windup_left = WINDUP
	pending_skill = skill
	# 这一阶段第二招起：偶尔接一招
	if phase_attacks >= 2 and randf() < COMBO_CHANCE:
		attack_t = WINDUP + 0.8
		_say(data().get("combo", []))


## 预警时间的倍数：新招第一次用时慢一倍
func _warn_mult(skill: String) -> float:
	if used_skills.has(skill):
		return 1.0
	used_skills[skill] = true
	var line := str(data().get("first_use", ""))
	if line != "":
		SpeechBubble.say(_body, line, 46.0, 1.6)
	return FIRST_SLOW


func use_skill(skill: String) -> void:
	match skill:
		"grab": _warn_grab(_target())
		"sweep": _warn_sweep(_target())
		"flick": flick(_target())
		"net": net(_target())
		"stomp": stomp()
		"charge": charge(_target())
		"sand": sand(_target())
		"leap": leap(_target())
		"gear": throw_gear(_target())
		"magnet": magnet()
		"shards": shards()
		"gas": _gas()
		"name": name_call()
		"mirror": mirrors()


func _warn_grab(who: PlayableCharacter) -> void:
	var at := who.global_position
	warn = {"kind": "grab", "at": at, "left": GRAB_WARN * _warn_mult("grab"), "node": _danger_circle(at, GRAB_R)}


func _warn_sweep(who: PlayableCharacter) -> void:
	var c := who.global_position
	var rect := Rect2(c.x - SWEEP_LEN * 0.5, c.y - SWEEP_W * 0.5, SWEEP_LEN, SWEEP_W)
	var node := CursedArmor.WarnLine.new()
	node.rect = rect
	node.add_to_group("danger")
	node.set_meta("rect", rect)
	get_parent().add_child(node)
	node.global_position = Vector2.ZERO
	warn = {"kind": "sweep", "rect": rect, "left": GRAB_WARN * _warn_mult("sweep"), "node": node}
	_say(data().get("sweep", []))


func _tick_warn(delta: float) -> void:
	if warn.is_empty():
		return
	warn["left"] = float(warn["left"]) - delta
	if float(warn["left"]) > 0.0:
		return
	match str(warn["kind"]):
		"grab":
			for c in _players():
				if c.global_position.distance_to(warn["at"]) <= GRAB_R and not _dodged(c):
					grab(c)
					break
		"sweep":
			var node: Variant = warn.get("node")
			if is_instance_valid(node):
				(node as CursedArmor.WarnLine).sweep()
			for c in _players():
				if (warn["rect"] as Rect2).has_point(c.global_position) and not _dodged(c):
					_say(data().get("trip", []))
					grab(c)
					break
		"charge":
			charge_left = CHARGE_LEN / CHARGE_SPEED
			_say(data().get("charge_go", []))
		"name":
			_ring()
	_clear_warn()


func _clear_warn() -> void:
	var node: Variant = warn.get("node")
	if is_instance_valid(node) and not (node is CursedArmor.WarnLine and (node as CursedArmor.WarnLine)._swept >= 0.0):
		(node as Node).queue_free()
	warn = {}


func _danger_circle(at: Vector2, r: float) -> Node2D:
	var n := DangerCircle.new()
	n.radius = r
	n.add_to_group("danger")
	get_parent().add_child(n)
	n.global_position = at
	return n


func _add_fx(n: Node2D, at: Vector2) -> Node2D:
	get_parent().add_child(n)
	n.global_position = at
	fx.append(n)
	return n


## 这一下躲开了没有：冲刺无敌就躲开；刚刚才冲刺的 = 完美闪避（学过队长的旧剑术）→ 骑士露出破绽
func _dodged(c: PlayableCharacter) -> bool:
	if not (c.is_dashing() or c.is_fully_invulnerable()):
		return false
	if KnightQuests.is_done("spear") and c == GameState.player and _perfect_cool <= 0.0 \
			and (Time.get_ticks_msec() - c.last_dash_msec) / 1000.0 <= PERFECT and weak_left <= 0.0 and phase < PHASES - 1:
		_perfect_cool = 3.0
		_say(data().get("perfect", []))
		open_weak(Vector2(0, -6))
	return true


## 打中一下：闷笑上涨 + 那个部位的挠痒特效（冲刺中躲得开）
func _hit(c: PlayableCharacter, laugh: float, zone := "sole") -> bool:
	if not is_instance_valid(c) or _dodged(c):
		return false
	# 走普通挠痒流程：部位、装备、疲倦加成、暴击都算，魔力疲倦跟着涨（KnightTickle）
	KnightTickle.hit(c, laugh, _body, zone)
	ZoneFx.play(zone, c.get_parent(), ZoneFx.body_point(c, zone), 0.9, false)
	return true


## 铁手套：弹指——三发扇形
func flick(who: PlayableCharacter) -> void:
	var from := _body.global_position + Vector2(0, -10)
	var dir := from.direction_to(who.global_position)
	for a in [-0.3, 0.0, 0.3]:
		var p := KnightBossFx.Bolt.new()
		p.vel = dir.rotated(a) * FLICK_SPEED
		p.set_meta("kind", "flick")
		_add_fx(p, from)
	_windup_fx("swing", 26.0)
	_flash_body()
	_say(data().get("flick", []))


## 铁手套：十指痒网——目标脚下 3×3 格，一格一格冒指头
func net(who: PlayableCharacter) -> void:
	var c := who.global_position
	var mult := _warn_mult("net")
	var i := 0
	for y in [-1, 0, 1]:
		for x in [-1, 0, 1]:
			var cell := KnightBossFx.NetCell.new()
			cell.warn = GRAB_WARN * mult + i * NET_DELAY
			cell.add_to_group("danger")
			cell.set_meta("radius", KnightBossFx.NetCell.SIZE * 0.6)
			_add_fx(cell, c + Vector2(x, y) * KnightBossFx.NetCell.SIZE)
			i += 1
	_windup_fx("web", 30.0)
	_say(data().get("net", []))


## 护腿：跺地——一圈痒波；跺完护腿卡住（破绽：膝盖窝）；召出手印
func stomp() -> void:
	wave_left = WAVE_TIME
	wave_r = 0.0
	stuck_left = STUCK_TIME + WAVE_TIME
	_shake(0.45, 5.0)
	_impact(_body.global_position, WAVE_R * 0.6, true)
	KnightFx.play(get_parent(), "shockwave", _body.global_position, {"size": WAVE_R * 2.4, "squash": 0.6, "z": 0})
	_say(data().get("stomp", []))
	_tip("hands")
	for i in SUMMON:
		var h := CurseHand.new()
		get_parent().add_child(h)
		h.global_position = _body.global_position + Vector2.from_angle(randf() * TAU) * 30.0
		var ps := _players()
		if not ps.is_empty():
			h.seek(ps[i % ps.size()])
		h.life = HAND_LIFE
		hands.append(h)


func _tick_wave(delta: float) -> void:
	if wave_left <= 0.0:
		return
	var before := wave_r
	wave_left -= delta
	wave_r = WAVE_R * (1.0 - maxf(0.0, wave_left) / WAVE_TIME)
	for c in _players():
		var d: float = c.global_position.distance_to(_body.global_position)
		if d > before and d <= wave_r and _hit(c, WAVE_LAUGH) and c.status:
			c.status.apply_slow(0.6, 1.2)
	if wave_left <= 0.0:
		_say(data().get("stuck", []))
		open_weak(Vector2(0, 12))


## 护腿：冲撞——预警线 → 直冲过去，撞到人就抓住；撞到木箱 / 场边卡住（破绽）
func charge(who: PlayableCharacter) -> void:
	charge_dir = _body.global_position.direction_to(who.global_position)
	if charge_dir == Vector2.ZERO:
		charge_dir = Vector2.RIGHT
	var a := _body.global_position
	var line := CursedArmor.WarnLine.new()
	var w := 18.0
	# 预警线：沿冲的方向（只画成横 / 竖的矩形，取主方向）
	var rect := Rect2(a.x, a.y - w * 0.5, CHARGE_LEN * signf(charge_dir.x), w) if absf(charge_dir.x) >= absf(charge_dir.y) \
		else Rect2(a.x - w * 0.5, a.y, w, CHARGE_LEN * signf(charge_dir.y))
	rect = rect.abs()
	charge_dir = Vector2(signf(charge_dir.x), 0) if absf(charge_dir.x) >= absf(charge_dir.y) else Vector2(0, signf(charge_dir.y))
	line.rect = rect
	line.add_to_group("danger")
	line.set_meta("rect", rect)
	get_parent().add_child(line)
	line.global_position = Vector2.ZERO
	warn = {"kind": "charge", "left": CHARGE_WARN * _warn_mult("charge"), "node": line}
	_windup_fx("cart_rumble", 30.0, -6.0)
	_say(data().get("charge", []))


func _tick_charge(delta: float) -> void:
	if charge_left <= 0.0:
		return
	charge_left -= delta
	var to := _body.global_position + charge_dir * CHARGE_SPEED * delta
	var clamped := _clamp_arena(to)
	_body.global_position = clamped
	(_body as Body).trail(clamped)
	for c in _players():
		if c.global_position.distance_to(_body.global_position) <= 16.0 and not _dodged(c):
			charge_left = 0.0
			grab(c)
			return
	var hit_crate := false
	for c in crates.duplicate():
		if is_instance_valid(c) and c.global_position.distance_to(_body.global_position) <= KnightBossFx.Crate.R + 10.0:
			(c as KnightBossFx.Crate).smash()
			crates.erase(c)
			hit_crate = true
	if charge_left <= 0.0 or clamped != to or hit_crate:
		charge_left = 0.0
		stuck_left = STUCK_TIME
		_shake(0.5, 6.0)
		_impact(_body.global_position + charge_dir * 10.0, 40.0, true)
		Audio.play("break", -4.0)
		_say(data().get("crate" if hit_crate else "charge_stuck", []))
		open_weak(Vector2(0, 12))


## 护腿：踢沙——三团痒尘
func sand(who: PlayableCharacter) -> void:
	for i in 3:
		var d := KnightBossFx.Dust.new()
		_add_fx(d, who.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0, 24))
	Audio.play("wind", -4.0, 0.06)
	Fx.burst(get_parent(), _body.global_position + Vector2(0, -2), "dust", 22, 70.0, 0.7, Vector2(0, 20), Color(0.85, 0.75, 0.6))
	_say(data().get("sand", []))


## 护腿 / 胸甲：跳起来砸地——目标脚下亮影子（LEAP_WARN 秒），盔甲在空中飞过去，落地砸一圈；落地后卡住一会儿
func leap(who: PlayableCharacter) -> void:
	leap_from = _body.global_position
	leap_to = _clamp_arena(who.global_position)
	leap_left = LEAP_WARN * _warn_mult("leap")
	_shadow = KnightBossFx.LeapShadow.new()
	_shadow.radius = LEAP_R
	_shadow.total = leap_left
	_shadow.left = leap_left
	get_parent().add_child(_shadow)
	_shadow.global_position = leap_to
	_windup_fx("swish", 30.0)
	_say(data().get("leap", []))


func _tick_leap(delta: float) -> void:
	if leap_left <= 0.0:
		return
	leap_left -= delta
	var total: float = _shadow.total if is_instance_valid(_shadow) else LEAP_WARN
	var k := 1.0 - clampf(leap_left / maxf(0.01, total), 0.0, 1.0)
	_body.global_position = leap_from.lerp(leap_to, k)
	(_body as Body).hop = sin(k * PI) * 40.0
	if is_instance_valid(_shadow):
		_shadow.left = leap_left
	if leap_left > 0.0:
		return
	(_body as Body).hop = 0.0
	if is_instance_valid(_shadow):
		_shadow.queue_free()
	_shadow = null
	_shake(0.55, 6.5)
	_impact(leap_to, LEAP_R * 1.4, true)
	Audio.play("break", -4.0)
	Fx.burst(get_parent(), leap_to, "dust", 16, 70.0, 0.6, Vector2.ZERO, Color(0.8, 0.7, 0.6))
	KnightFx.play(get_parent(), "dust_land", leap_to, {"size": LEAP_R * 2.6, "squash": 0.75, "z": 0})
	_say(data().get("land", []))
	for c in _players():
		if c.global_position.distance_to(leap_to) <= LEAP_R and _hit(c, LEAP_LAUGH, "sole") and c.status:
			c.status.apply_slow(0.6, 1.0)
	stuck_left = LEAP_STUCK


## 胸甲：诅咒穿戴——甩出一件痒痒装备
func throw_gear(who: PlayableCharacter) -> void:
	var from := _body.global_position + Vector2(0, -18)
	var id: String = GEARS.keys().pick_random()
	var p := KnightBossFx.Bolt.new()
	p.vel = from.direction_to(who.global_position) * GEAR_SPEED
	p.icon = ItemDB.get_item(id).icon if ItemDB.get_item(id) else null
	p.set_meta("kind", "gear")
	Audio.play("hook_throw", -3.0, 0.06)
	p.set_meta("item", id)
	p.life = 3.0
	_add_fx(p, from)
	_say(data().get("gear", []))


## 诅咒装备穿到她身上（测试也直接调）
func wear_gear(c: PlayableCharacter, id := "") -> void:
	if not is_instance_valid(c) or c.has_meta(&"knight_gear"):
		return
	if id == "":
		id = GEARS.keys().pick_random()
	var g := KnightBossFx.Gear.new()
	g.who = c
	g.item_id = id
	g.zone = str(GEARS.get(id, "sole"))
	var item := ItemDB.get_item(id)
	g.icon = item.icon if item else null
	get_parent().add_child(g)
	c.set_meta(&"knight_gear", g)
	var name := item.display_name if item else id
	GameState.princess_reacted.emit(str(data().get("gear_on", "（%s被穿到了身上！）")) % name, 2.6)
	_tip("gear")


## 被穿着诅咒装备的人连按 J：挣掉
func tear_gear(c: PlayableCharacter) -> void:
	var g: Variant = c.get_meta(&"knight_gear") if c.has_meta(&"knight_gear") else null
	if not is_instance_valid(g):
		return
	g.tears += 1
	c.shake(0.08)
	if g.tears >= GEAR_TEARS:
		_take_gear(c, "gear_torn")


func _take_gear(c: PlayableCharacter, say := "") -> void:
	if not is_instance_valid(c) or not c.has_meta(&"knight_gear"):
		return
	var g: Variant = c.get_meta(&"knight_gear")
	c.remove_meta(&"knight_gear")
	if is_instance_valid(g):
		(g as Node).queue_free()
	if say != "":
		_say(data().get(say, []))


func _tick_gears(delta: float) -> void:
	for c in _players():
		var g: Variant = c.get_meta(&"knight_gear") if c.has_meta(&"knight_gear") else null
		if not is_instance_valid(g):
			continue
		KnightTickle.over(c, GEAR_LAUGH, delta, _body, "gear", "waist")
		if c.status and fmod(_t, 0.3) < delta:
			c.status.apply_slow(0.7, 0.4)
		if randf() < delta * 2.0:
			ZoneFx.play(g.zone, c.get_parent(), ZoneFx.body_point(c, g.zone), 0.8, false)
		# 搭档在身边：按住 E（AI 搭档站在旁边就算）把它扯下来
		var other: PlayableCharacter = blue if c == pink else pink
		var pulling := is_instance_valid(other) and other.global_position.distance_to(c.global_position) <= RESCUE_R \
			and ((other == GameState.player and Input.is_action_pressed("interact")) or (other != GameState.player and ai_enabled))
		g.pull = minf(1.0, g.pull + delta / GEAR_PULL) if pulling else maxf(0.0, g.pull - delta)
		if g.pull >= 1.0:
			_take_gear(c, "gear_pulled")
			continue
		# 被穿着的是 AI 搭档：自己挣
		if c != GameState.player and ai_enabled:
			_ai_mash_t -= delta
			if _ai_mash_t <= 0.0:
				_ai_mash_t = AI_MASH_EVERY * 1.5
				tear_gear(c)


## 胸甲：护心磁吸——把身边的人往中间吸（比走路慢，往外走就走得掉），吸到跟前就抓住
func magnet() -> void:
	magnet_left = MAGNET_TIME
	Audio.play("rumble", -2.0)
	# 往里收的吸力圈（两圈错开）
	for k in 2:
		var ringn := SiegeFx.ring(get_parent(), _body.global_position, MAGNET_R, Color(0.95, 0.4, 0.8, 0.8), MAGNET_TIME, 0.06)
		if ringn:
			ringn.create_tween().tween_property(ringn, "scale", Vector2(0.15, 0.15), MAGNET_TIME * (0.6 + 0.4 * k)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_say(data().get("magnet", []))


func _tick_magnet(delta: float) -> void:
	if magnet_left <= 0.0:
		return
	magnet_left -= delta
	for c in _players():
		var d: float = c.global_position.distance_to(_body.global_position)
		if d <= MAGNET_R and d > 1.0 and not c.is_dashing():
			c.global_position += c.global_position.direction_to(_body.global_position) * minf(MAGNET_PULL * delta, d)
	if magnet_left <= 0.0:
		for c in _players():
			if c.global_position.distance_to(_body.global_position) <= 24.0 and not _dodged(c):
				grab(c)
				break


## 胸甲：甲片飞散——六片在场上弹来弹去
func shards() -> void:
	for i in SHARDS:
		var s := KnightBossFx.Shard.new()
		s.vel = Vector2.from_angle(i * TAU / SHARDS + randf_range(-0.2, 0.2)) * 90.0
		s.bounds = Rect2(_home - ARENA, ARENA * 2.0)
		_add_fx(s, _body.global_position + Vector2(0, -16))
	_impact(_body.global_position + Vector2(0, -8), 36.0, false, "break", -3.0)
	_flash_body()
	_say(data().get("shards", []))


## 笑面：呼唤骑士之名——先蓄力（盔甲脚下亮一圈，标出缺口的方向），冲击波往外扩、有缺口；喊完露出破绽（脖子）
func name_call() -> void:
	var gaps := []
	var a0 := randf() * TAU
	for i in RING_GAPS:
		gaps.append(a0 + TAU * i / RING_GAPS)
	var node := NameWarn.new()
	node.gaps = gaps
	get_parent().add_child(node)
	node.global_position = _body.global_position
	warn = {"kind": "name", "left": NAME_WINDUP * _warn_mult("name"), "node": node, "gaps": gaps}
	_windup_fx("rumble", 46.0, -1.0)
	_say(data().get("name_call", []))


func _ring() -> void:
	var r := KnightBossFx.Ring.new()
	r.set_meta("kind", "ring")
	r.gaps = warn.get("gaps", [])
	_add_fx(r, _body.global_position)
	KnightFx.play(get_parent(), "shockwave", _body.global_position, {"size": 240.0, "squash": 0.6, "z": 0})
	_impact(_body.global_position, 60.0, true, "wall_crash", -1.0)
	_shake(0.5, 5.0)
	open_weak(Vector2(0, -26))


## 笑面：镜面笑脸——三张笑脸先绕圈再去追人
func mirrors() -> void:
	for i in MIRRORS:
		var m := KnightBossFx.Mirror.new()
		m.center = _body
		m.angle = i * TAU / MIRRORS
		m.target = _players()[i % _players().size()]
		_add_fx(m, _body.global_position)
	_windup_fx("brush_spin", 40.0)
	_say(data().get("mirror", []))


func _gas() -> void:
	var g := GasCloud.new()
	get_parent().add_child(g)
	g.global_position = _target().global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	gases.append(g)
	Audio.play("puff", -2.0, 0.08)
	Fx.burst(get_parent(), g.global_position, "dust", 14, 40.0, 0.8, Vector2(0, -10), Color(0.8, 0.5, 0.95))
	_say(data().get("gas", []))


func _tick_gas(delta: float) -> void:
	for g in gases.duplicate():
		if not is_instance_valid(g):
			gases.erase(g)
			continue
		for c in _players():
			if c.global_position.distance_to(g.global_position) <= GAS_R and c.laugh and not c.is_dashing():
				KnightTickle.over(c, GAS_RATE, delta, _body, "gas", "waist")


## 场上的弹幕：碰到谁
func _tick_fx(delta: float) -> void:
	for n in fx.duplicate():
		if not is_instance_valid(n):
			fx.erase(n)
			continue
		if n is KnightBossFx.Bolt:
			if n.hit:
				fx.erase(n)
				continue
			for c in _players():
				if c.global_position.distance_to(n.global_position) <= n.radius + 8.0 and not _dodged(c):
					n.hit = true
					if str(n.get_meta("kind", "")) == "gear":
						wear_gear(c, str(n.get_meta("item", "")))
					elif _hit(c, FLICK_LAUGH, "waist") and c.status:
						c.status.apply_slow(0.7, 0.8)
					break
		elif n is KnightBossFx.NetCell:
			if n.active > 0.0 and not n.has_meta("hit"):
				for c in _players():
					if absf(c.global_position.x - n.global_position.x) <= KnightBossFx.NetCell.SIZE * 0.5 \
							and absf(c.global_position.y - n.global_position.y) <= KnightBossFx.NetCell.SIZE * 0.5 and _hit(c, NET_LAUGH):
						n.set_meta("hit", true)
						if c.status:
							c.status.apply_root(0.5)
		elif n is KnightBossFx.Dust:
			for c in _players():
				if c.global_position.distance_to(n.global_position) <= KnightBossFx.Dust.RADIUS and c.laugh and not c.is_dashing():
					KnightTickle.over(c, DUST_RATE, delta, _body, "dust", "sole")
					if c.status and fmod(_t, 0.3) < delta:
						c.status.apply_slow(0.75, 0.4)
		elif n is KnightBossFx.Shard:
			for crate in crates:
				if is_instance_valid(crate) and n.global_position.distance_to(crate.global_position + Vector2(0, -6)) <= KnightBossFx.Crate.R:
					n.vel = -n.vel
			for c in _players():
				if c.global_position.distance_to(n.global_position) <= 9.0 and not n.has_meta("hit_%d" % c.get_instance_id()):
					if _hit(c, SHARD_LAUGH, "waist"):
						n.set_meta("hit_%d" % c.get_instance_id(), true)
		elif n is KnightBossFx.Ring:
			for c in _players():
				var d: float = c.global_position.distance_to(n.global_position)
				if absf(d - n.r) <= 8.0 and not n.has_meta("hit_%d" % c.get_instance_id()):
					n.set_meta("hit_%d" % c.get_instance_id(), true)
					# 站在缺口的方向上：冲击波从身边过去
					if not n.in_gap(n.global_position.direction_to(c.global_position).angle()) and _hit(c, RING_LAUGH, "waist"):
						c.global_position += c.global_position.direction_to(n.global_position) * RING_PUSH
		elif n is KnightBossFx.Mirror:
			for c in _players():
				if c.global_position.distance_to(n.global_position) <= 12.0 and c.laugh and not c.is_dashing():
					KnightTickle.over(c, MIRROR_RATE, delta, _body, "mirror", "waist")
					if randf() < delta * 2.0:
						ZoneFx.play("waist", c.get_parent(), ZoneFx.body_point(c, "waist"), 0.7, false)


func _tick_hands() -> void:
	for h in hands.duplicate():
		if not is_instance_valid(h) or h.state == "gone":
			hands.erase(h)
			continue
		# 爬进亮着的灯笼光里：化掉
		if lights().any(func(l): return l.global_position.distance_to(h.global_position) <= KnightCurse.LIGHT_SAFE_R):
			h.puff()
			hands.erase(h)
			continue
		# 说过话的商人 / 奶奶：这一阶段帮你扫一次身边的小手
		for v in victims:
			if is_instance_valid(v) and v.broom and v.global_position.distance_to(h.global_position) <= BROOM_R:
				sweep(v)
				break


## 镇民拿扫帚扫掉身边的小手（每个阶段一次，和他说过话以后）
func sweep(v: KnightBossFx.Victim) -> int:
	v.broom = false
	var n := 0
	for h in hands.duplicate():
		if is_instance_valid(h) and h.state != "gone" and h.global_position.distance_to(v.global_position) <= BROOM_R:
			h.puff()
			hands.erase(h)
			n += 1
	SpeechBubble.say(v, str((data().get("broom", ["去去去！别碰她！"]) as Array).pick_random()), 30.0, 1.6)
	Audio.play("swish", -4.0)
	return n


func _voice(delta: float) -> void:
	if phase == 0:
		return
	_voice_t -= delta
	if _voice_t <= 0.0:
		_voice_t = randf_range(6.0, 9.0)
		var pool: Array = data().get("voice", [])
		if not pool.is_empty():
			SpeechBubble.say(_body, str(pool.pick_random()), 46.0, 2.0)


# ------------------------------------------------------------------ 反击：破绽、挠骑士、清醒
## 部件掉下来 / 卡住 / 喊完：露出破绽（at：相对本体的位置）
func open_weak(at: Vector2) -> void:
	if finale:
		return
	_close_weak()
	weak_left = WEAK_TIME
	var w := KnightBossFx.WeakSpot.new()
	w.task = self
	var spots: Array = data().get("weak_spots", [])
	w.spot = str(spots[phase]) if phase < spots.size() else ""
	get_parent().add_child(w)
	w.global_position = _body.global_position + at
	weak_spot = w
	_tip("weak")
	if w.spot != "":
		GameState.princess_reacted.emit(str(data().get("weak", "（露出破绽了——%s！）")) % w.spot, 2.0)


func _close_weak() -> void:
	weak_left = 0.0
	if is_instance_valid(weak_spot):
		weak_spot.queue_free()
	weak_spot = null


## 打破绽 = 挠骑士：骑士的笑涨；满了骑士清醒（所有部件不冻也打得动；笑面阶段：触手缩回去、灯笼亮一截）
func tickle_knight() -> bool:
	if weak_left <= 0.0 or finale:
		return false
	knight_laugh = minf(1.0, knight_laugh + KNIGHT_TICKLE)
	ZoneFx.play("waist", get_parent(), weak_spot.global_position if is_instance_valid(weak_spot) else _body.global_position, 1.0, false)
	SpeechBubble.say(_body, str(data().get("knight_laugh", ["噗……！"]).pick_random()), 46.0, 1.0)
	if knight_laugh >= 1.0:
		knight_laugh = 0.0
		_close_weak()
		_say(data().get("lucid", []))
		lucid_left = LUCID_TIME
		# 支线「手印样本」的安神香：第一次清醒时自动点上，多清醒一会儿
		if not incense_used and GameState.inventory.count("calm_incense") > 0:
			incense_used = true
			lucid_left += INCENSE_BONUS
			GameState.princess_reacted.emit(str(data().get("incense", "")), 2.6)
		if phase == PHASES - 1:
			for tn in tentacles:
				if is_instance_valid(tn):
					tn.queue_free()
			tentacles.clear()
			for l in lanterns:
				if is_instance_valid(l) and not l.lit:
					_light(l, LUCID_LANTERN)
		else:
			_tip("lucid")
	return true


# ------------------------------------------------------------------ 最后阶段：全镇的笑声
func _start_lanterns() -> void:
	if not lanterns.is_empty():
		return
	for i in LANTERNS.size():
		var l := KnightBossFx.Lantern.new()
		l.index = i
		l.target = _body
		get_parent().add_child(l)
		l.global_position = _home + (LANTERNS[i] as Vector2)
		lanterns.append(l)
	_say(data().get("lanterns_start", []))
	_tip("lantern")
	if is_instance_valid(field_helpers):
		field_helpers.to_lanterns()
	# 做过的支线：那个人跑到他那盏灯笼下陪着笑
	var info: Dictionary = data().get("helpers", {})
	for i in HELPER_ORDER.size():
		var id: String = HELPER_ORDER[i]
		if not KnightQuests.is_done(id):
			continue
		var h := KnightBossFx.Helper.new()
		var hi: Dictionary = info.get(id, {})
		h.sheet = load("res://assets/generated/npcs/%s.png" % str(hi.get("npc", "kid")))
		h.line = str(hi.get("line", ""))
		get_parent().add_child(h)
		h.global_position = _home + (LANTERNS[i] as Vector2) * 1.6
		h.goal = _home + (LANTERNS[i] as Vector2) + Vector2(14, 6)
		h.set_meta("quest", id)
		h.set_meta("lantern", i)
		helpers.append(h)


func _helper_at(i: int) -> bool:
	return helpers.any(func(h): return is_instance_valid(h) and int(h.get_meta("lantern", -1)) == i and h.arrived)


func _tick_lanterns(delta: float) -> void:
	if lanterns.is_empty() or finale or is_instance_valid(dispel):
		return
	var me := GameState.player
	var near_cursed := victims.any(func(v): return is_instance_valid(v) and v.cursed and is_instance_valid(me) and v.global_position.distance_to(me.global_position) <= RESCUE_R)
	var laughing := KnightLaugh.tick(me, delta, not near_cursed) if is_instance_valid(me) and not grabbed else false
	for l in lanterns:
		if not is_instance_valid(l) or l.lit:
			continue
		var rate := 0.0
		if laughing and me.global_position.distance_to(l.global_position) <= LANTERN_R:
			rate += LANTERN_RATE
			if randf() < delta * 0.8:
				SpeechBubble.say(me, str((data().get("laugh_lantern", ["哈哈……！"]) as Array).pick_random()), 30.0, 1.0)
		# AI 搭档站在灯笼下：陪着笑
		for c in _players():
			if c != me and ai_enabled and c.global_position.distance_to(l.global_position) <= LANTERN_R:
				rate += LANTERN_AI_RATE
				if c.laugh:
					c.laugh.add(c.laugh.max_value * KnightLaugh.RATE * 0.5 * delta)
		if _helper_at(l.index):
			rate = rate * HELPER_MULT + HELPER_SOLO
		# 笑面吸笑的时候：灯笼不长（KnightCurse 让没亮的往下掉）
		if is_instance_valid(curse) and curse.surge == "drain":
			rate = minf(rate, 0.0)
		var stolen := tentacles.any(func(tn): return is_instance_valid(tn) and tn.attached and tn.lantern == l and not tn.frozen)
		l.stealing = stolen
		if stolen:
			rate -= TENTACLE_DRAIN
			if randf() < delta * 0.3:
				_say(data().get("tentacle_steal", []))
		_light(l, rate * delta)
	# 触手
	tentacle_t -= delta
	if tentacle_t <= 0.0:
		tentacle_t = TENTACLE_EVERY
		send_tentacle()
	for tn in tentacles.duplicate():
		if not is_instance_valid(tn) or not is_instance_valid(tn.lantern) or tn.lantern.lit:
			if is_instance_valid(tn):
				tn.queue_free()
			tentacles.erase(tn)
	if lanterns.all(func(l): return is_instance_valid(l) and l.lit):
		if on_fog():
			_start_dispel()
		else:
			_purify()


## 灯笼亮一截（amount 可以是负的：被触手偷）；满了就亮
func _light(l: KnightBossFx.Lantern, amount: float) -> void:
	l.progress = clampf(l.progress + amount, 0.0, 1.0)
	if l.progress >= 1.0 and not l.lit:
		l.lit = true
		if is_instance_valid(fog_ring):
			fog_ring.push()
		var lit := lanterns.filter(func(x): return is_instance_valid(x) and x.lit).size()
		var lines: Array = data().get("lantern_lit", [])
		if lit - 1 < lines.size():
			GameState.princess_reacted.emit(str(lines[lit - 1]), 2.6)
		Audio.play("star_burst", -4.0)
		Fx.burst(get_parent(), l.global_position + Vector2(0, -28), "spark", 16, 60.0, 0.8, Vector2(0, -20), Color(1, 0.9, 0.6))
		var pillar := KnightFx.play(get_parent(), "lantern_pillar", l.global_position + Vector2(0, -34), {"size": 64.0, "loop": true, "fps": 10.0})
		if pillar:
			fx.append(pillar)
		if is_instance_valid(_decor):
			_decor.fade = 1.0 - float(lit) / float(lanterns.size())


## 笑面伸一条触手，爬向一盏没亮的灯笼（优先亮得最多的）
func send_tentacle() -> KnightBossFx.Tentacle:
	var pool: Array = lanterns.filter(func(l): return is_instance_valid(l) and not l.lit and not tentacles.any(func(tn): return is_instance_valid(tn) and tn.lantern == l))
	if pool.is_empty():
		return null
	pool.sort_custom(func(a, b): return a.progress > b.progress)
	var tn := KnightBossFx.Tentacle.new()
	tn.lantern = pool[0]
	tn.from = _body
	tn.travel = TENTACLE_TRAVEL
	tn.left = TENTACLE_TRAVEL
	get_parent().add_child(tn)
	tn.global_position = Vector2.ZERO
	tentacles.append(tn)
	_say(data().get("tentacle", []))
	return tn


## 冻住身边的触手（蓝色公主 J）
func _freeze_tentacles(who: PlayableCharacter) -> bool:
	var hit := false
	for tn in tentacles.duplicate():
		if is_instance_valid(tn) and not tn.frozen and tn.head().distance_to(who.global_position) <= TENTACLE_FREEZE_R:
			tn.frozen = true
			hit = true
			tentacles.erase(tn)
			_say(data().get("tentacle_frozen", []))
			var tw: Tween = tn.create_tween()
			tw.tween_property(tn, "modulate:a", 0.0, 0.4)
			tw.tween_callback(tn.queue_free)
	return hit


## 四盏都亮：光柱汇到盔甲上 → 手帕 → 净化
func _purify() -> void:
	if finale:
		return
	finale = true
	_clear_field()
	if grabbed:
		_release_grab()
	for l in lanterns:
		if is_instance_valid(l):
			l.finale = true
	KnightFx.play(get_parent(), "purify", _body.global_position + Vector2(0, -24), {"size": 200.0, "fps": 9.0, "z": 5})
	_shake(0.6, 3.0)
	if not skip_cutscenes and Cutscene.has_cutscene("knight_purify"):
		await get_tree().create_timer(0.8).timeout
		if not is_inside_tree() or _emitted:
			return
		await Cutscene.play("knight_purify")
	_emit(true)


# ------------------------------------------------------------------ 场上的人：救人、说话
func _spawn_victims() -> void:
	var covers := COVERS.map(func(o): return _home + (o as Vector2))
	for spec in VICTIMS:
		var v := KnightBossFx.Victim.new()
		v.sheet = load("res://assets/generated/npcs/%s.png" % spec[0])
		v.kind = str(spec[1])
		v.who = str(spec[0])
		v.covers = covers
		v.threat = _body
		get_parent().add_child(v)
		v.global_position = _home + (spec[2] as Vector2)
		victims.append(v)


## 手印贴上一个人（测试也直接调）
func curse_victim(v: KnightBossFx.Victim = null) -> KnightBossFx.Victim:
	if v == null:
		var free: Array = victims.filter(func(x): return is_instance_valid(x) and not x.cursed)
		if free.is_empty():
			return null
		v = free.pick_random()
	v.cursed = true
	v.cursed_t = 0.0
	v.rescue = 0.0
	SpeechBubble.say(v, str(data().get("victim_laugh", ["哈哈哈……救、救命……！"]).pick_random()), 30.0, 1.6)
	_tip("rescue")
	return v


func _tick_victims(delta: float) -> void:
	if finale:
		return
	curse_t -= delta
	var cursed: Array = victims.filter(func(x): return is_instance_valid(x) and x.cursed)
	if curse_t <= 0.0:
		curse_t = CURSE_EVERY
		if cursed.size() < MAX_CURSED:
			curse_victim()
	var was := enraged
	enraged = cursed.any(func(x): return x.cursed_t > ENRAGE_AFTER)
	if enraged and not was:
		_say(data().get("enrage", []))
	for v in cursed:
		var helping := false
		for c in _players():
			if c.global_position.distance_to(v.global_position) <= RESCUE_R:
				if (c == GameState.player and Input.is_action_pressed("interact")) or (c != GameState.player and ai_enabled):
					helping = true
		# 做过「骑士救公主」：小孩们跑过来帮着扒（快一倍；没人在扒也会慢慢扒下来）
		var kids := is_instance_valid(field_helpers) and field_helpers.kid_near(v.global_position)
		var rate := (1.0 if helping else 0.0) + (KnightHelpers.KID_RESCUE - 1.0 if kids else 0.0)
		v.rescue = minf(1.0, v.rescue + delta / RESCUE_TIME * rate) if rate > 0.0 else maxf(0.0, v.rescue - delta * 0.5)
		if v.rescue >= 1.0:
			rescue(v)


## 救下来：冻结冷却马上好；被救的队员替公主挡一次扑抓 / 冲撞
func rescue(v: KnightBossFx.Victim) -> void:
	if not is_instance_valid(v) or not v.cursed:
		return
	v.cursed = false
	v.cursed_t = 0.0
	v.rescue = 0.0
	freeze_cool = 0.0
	shield = maxi(shield, 1)
	enraged = victims.any(func(x): return is_instance_valid(x) and x.cursed and x.cursed_t > ENRAGE_AFTER)
	SpeechBubble.say(v, str(data().get("thanks", ["谢、谢谢！下一下我替你挡！"]).pick_random()), 30.0, 2.0)
	Audio.play("star_burst", -8.0)


## 短按 E：和身边没被手印贴着的人说话
func talk_near(who: PlayableCharacter) -> KnightBossFx.Victim:
	if not is_instance_valid(who):
		return null
	var best: KnightBossFx.Victim = null
	for v in victims:
		if is_instance_valid(v) and not v.cursed and v.global_position.distance_to(who.global_position) <= TALK_R:
			if best == null or v.global_position.distance_to(who.global_position) < best.global_position.distance_to(who.global_position):
				best = v
	if best:
		talk_to(best, who)
	return best


## 和场上的人说话：喊一句提示；奶奶递薄荷糖、队员替你挡一下（每人每阶段一次）
func talk_to(v: KnightBossFx.Victim, who: PlayableCharacter) -> String:
	if v.cursed:
		return ""
	if v.who in ["granny", "merchant"] and v.broom_phase != phase:
		# 扫帚：这一阶段帮你扫一次身边的小手（不看说话的冷却）
		v.broom_phase = phase
		v.broom = true
		if hands.any(func(h): return is_instance_valid(h) and h.state != "gone" and h.global_position.distance_to(v.global_position) <= BROOM_R):
			sweep(v)
	if v.talk_cool > 0.0:
		return ""
	v.talk_cool = TALK_COOL
	var key := "fallen" if v.kind == "fallen" else v.who
	var pool: Array = data().get("talk", {}).get(key, data().get("talk", {}).get("guard", []))
	if not pool.is_empty():
		SpeechBubble.say(v, str(pool.pick_random()), 30.0, 2.4)
	var got := "line"
	if v.who == "granny" and not v.helped and who.laugh:
		v.helped = true
		who.laugh.set_value(maxf(0.0, who.laugh.value - who.laugh.max_value * TALK_MINT))
		GameState.princess_reacted.emit(str(data().get("talk_mint", "")), 2.4)
		got = "mint"
	elif v.who == "guard" and v.kind != "fallen" and not v.helped:
		v.helped = true
		shield = maxi(shield, 1)
		GameState.princess_reacted.emit(str(data().get("talk_shield", "")), 2.4)
		got = "shield"
	return got


## 蓝色公主的千手解放：骑士踉跄 BURST_STAGGER 秒、露出破绽（离得够近才算），全场贴在人身上的手印都被扒下来，触手全缩回去
func on_pants_burst(burst: PantsBurst) -> void:
	if _emitted or transitioning or finale:
		return
	for v in victims:
		if is_instance_valid(v) and v.cursed:
			v.cursed = false
			v.cursed_t = 0.0
			v.rescue = 0.0
	enraged = false
	for tn in tentacles:
		if is_instance_valid(tn):
			tn.queue_free()
	tentacles.clear()
	for part in parts:
		if is_instance_valid(part) and not part.broken and part.global_position.distance_to(burst.global_position) <= PantsBurst.RADIUS + 20.0:
			part.freeze_left = maxf(part.freeze_left, FREEZE_TIME)
	if is_instance_valid(_body) and _body.global_position.distance_to(burst.global_position) <= PantsBurst.RADIUS + 24.0:
		stuck_left = maxf(stuck_left, BURST_STAGGER)
		open_weak(Vector2(0, -14))
		_say(data().get("burst", ["（千手痒痒裤的小手一下子缠住了盔甲——它踉跄着，动不了了）"]))


## 蓝色公主的冰晶结界（L，IceBarrier）：范围里的部件冻住（冻住能打）、触手冻碎、心核冻住、被贴着的镇民救下来。小手自己（CurseHand.on_ice_barrier）冻。
func on_ice_barrier(center: Vector2, r: float, time: float) -> void:
	if _emitted or transitioning or finale:
		return
	for part in parts:
		if is_instance_valid(part) and not part.broken and part.global_position.distance_to(center) <= r + 20.0:
			part.freeze_left = maxf(part.freeze_left, maxf(time, FREEZE_TIME))
	for tn in tentacles.duplicate():
		if is_instance_valid(tn) and not tn.frozen and tn.head().distance_to(center) <= r:
			tn.frozen = true
			tentacles.erase(tn)
			var tw: Tween = tn.create_tween()
			tw.tween_property(tn, "modulate:a", 0.0, 0.4)
			tw.tween_callback(tn.queue_free)
	if is_instance_valid(curse):
		curse.freeze_cores_at(center, r)
	for v in victims:
		if is_instance_valid(v) and v.cursed and v.global_position.distance_to(center) <= r:
			rescue(v)


## 被救的队员冲上来挡一下（扑抓 / 冲撞 / 磁吸抓人之前问）
func _block(c: PlayableCharacter) -> bool:
	if shield <= 0:
		return false
	shield -= 1
	Fx.burst(c.get_parent(), c.global_position + Vector2(0, -8), "dust", 10, 40.0, 0.5, Vector2.ZERO, Color(0.7, 0.9, 1.0))
	_say(data().get("block", []))
	return true


# ------------------------------------------------------------------ 被抓
func grab(who: PlayableCharacter) -> void:
	if grabbed or _emitted or finale:
		return
	if _block(who):
		return
	grabbed = who
	grab_left = GRAB_TIME
	mashes = 0
	Audio.play("hand_grab", -2.0, 0.05)
	_shake(0.25, 3.5)
	_flash_body()
	body_mode = "walk"
	GameState.vars[CAUGHT_KEY] = caught() + 1
	if who.status:
		who.status.apply_root(GRAB_TIME)
	var soft := who == pink
	_say(data().get("grab_soft" if soft else "grab", []))
	if caught() >= CATCHES:
		_emit(false)


func _grab_tick(delta: float) -> void:
	grab_left -= delta
	_body.global_position = _body.global_position.lerp(grabbed.global_position + Vector2(0, -6), 0.2)
	# 抓住的是 AI 搭档：自己连按挣开
	if ai_enabled and grabbed != GameState.player:
		_ai_mash_t -= delta
		if _ai_mash_t <= 0.0:
			_ai_mash_t = AI_MASH_EVERY
			mash()
			if not grabbed:
				return
	var soft := grabbed == pink
	# 粉色公主被抱住：闷笑涨得慢、疲倦涨得快（手印认得她）——疲倦另乘 SOFT_FATIGUE_MULT
	KnightTickle.over(grabbed, SOFT_LAUGH if soft else HARD_LAUGH, delta, _body, "grab",
		"" if soft else ("thigh" if grabbed is BluePrincess else "waist"), 1.0, SOFT_FATIGUE_MULT if soft else 1.0)   # 抱粉色公主是轻轻的：不按部位放大
	if randf() < delta * 2.0:
		var zone := "sole" if soft else ("thigh" if grabbed is BluePrincess else "waist")
		ZoneFx.play(zone, grabbed.get_parent(), ZoneFx.body_point(grabbed, zone), 0.8 if soft else 1.1, soft)
	if grab_left <= 0.0:
		_release_grab()


func mash() -> void:
	if not grabbed:
		return
	mashes += 1
	grabbed.shake(0.1)
	if mashes >= MASH:
		_release_grab()


func _release_grab() -> void:
	if grabbed and grabbed.status:
		grabbed.status.clear_root()
	if grabbed:
		# 挣开：把盔甲推开一点，给她跑的空当
		_body.global_position = _clamp_arena(_body.global_position + grabbed.global_position.direction_to(_body.global_position) * 24.0)
	grabbed = null
	attack_t = maxf(attack_t, 1.5)


# ------------------------------------------------------------------ AI 搭档
## 测试：关掉 AI 搭档（没被操控的那位原地不动）
var ai_enabled := true
var _ai_mash_t := 0.0


## 没被操控的那位这一帧干什么（KnightAI 的 plan）；被抓住、被穿上诅咒装备时的挣扎在 _grab_tick / _tick_gears 里
func ai_plan(ai: PlayableCharacter) -> Dictionary:
	if is_instance_valid(dispel) and not dispel.done:
		return dispel.ai_plan(ai)
	var r := _ai_move(ai)
	if ai == blue and _ai_burst():
		r = r.duplicate()
		r["skill"] = true
	return r


## AI 蓝色公主放千手解放：粉色公主被抓住、场上有两个人被手印贴着、触手缠住了灯笼，或者盔甲就在身边而且没有破绽的时候
func _ai_burst() -> bool:
	if not ai_enabled or _emitted or transitioning or finale or not is_instance_valid(_body) or not is_instance_valid(blue) or not PantsBurst.learned():
		return false
	if PantsBurst.cooldown_left(blue) > 0.0 or grabbed == blue:
		return false
	var cursed := victims.filter(func(x): return is_instance_valid(x) and x.cursed).size()
	var stolen := tentacles.any(func(tn): return is_instance_valid(tn) and tn.attached)
	var close := blue.global_position.distance_to(_body.global_position) <= PantsBurst.RADIUS
	return grabbed == pink or cursed >= 2 or stolen or (close and stuck_left <= 0.0 and weak_left <= 0.0)


func _ai_move(ai: PlayableCharacter) -> Dictionary:
	if not ai_enabled or _emitted or transitioning or finale or not is_instance_valid(_body) or grabbed == ai:
		return {"hold": true}
	var other: PlayableCharacter = blue if ai == pink else pink
	# 搭档身上有诅咒装备：过去扯下来（站在旁边就在扯）
	if is_instance_valid(other) and other.has_meta(&"knight_gear"):
		return {"to": other.global_position, "near": RESCUE_R * 0.6, "dash": true}
	if ai == blue and is_instance_valid(curse) and curse.surge == "heart":
		# 护心诅咒：去冻还没冻住的那颗核心
		for c in curse.cores:
			if float(c["frozen"]) <= 0.0:
				var cp := curse.core_pos(c)
				if cp.distance_to(blue.global_position) <= KnightCurse.CORE_FREEZE_R - 4.0:
					freeze_part(blue)
					return {"hold": true}
				return {"to": cp, "near": 4.0, "dash": true}
	if ai == blue:
		# 触手缠着灯笼：去冻
		for tn in tentacles:
			if is_instance_valid(tn) and not tn.frozen and freeze_cool <= 0.0:
				if tn.head().distance_to(blue.global_position) <= TENTACLE_FREEZE_R - 6.0:
					freeze_part(blue)
					return {"hold": true}
				return {"to": tn.head(), "near": 8.0, "dash": true}
		var cursed: Array = victims.filter(func(x): return is_instance_valid(x) and x.cursed)
		if not cursed.is_empty() and freeze_cool <= 0.0:
			var v: Node2D = cursed[0]
			if v.global_position.distance_to(blue.global_position) <= FREEZE_R - 8.0:
				freeze_part(blue)
				return {"hold": true}
			return {"to": v.global_position, "near": 8.0, "dash": true}
		var p := _nearest_part(blue, func(x): return x.freeze_left <= 0.0 and not _soft(x))
		if p and freeze_cool <= 0.0:
			if p.global_position.distance_to(blue.global_position) <= FREEZE_R - 6.0:
				freeze_part(blue)
				return {"hold": true}
			return {"to": p.global_position + Vector2(0, 18), "near": 6.0, "dash": true}
	# 最后阶段：去没亮的灯笼下陪着笑（离玩家远的那盏）
	if phase == PHASES - 1 and not lanterns.is_empty():
		var l := _ai_lantern(ai)
		if l:
			return {"to": l.global_position + Vector2(0, 8), "near": LANTERN_R * 0.5, "dash": true}
	if ai == blue:
		return {}
	if soft_target() != null:
		return {}
	# 粉色公主贴近本体：诅咒认得她，出招变慢
	return {"to": _body.global_position + Vector2(0, 26), "near": SOFT_R * 0.6}


func _ai_lantern(ai: PlayableCharacter) -> KnightBossFx.Lantern:
	var best: KnightBossFx.Lantern = null
	var me := GameState.player
	for l in lanterns:
		if not is_instance_valid(l) or l.lit:
			continue
		if is_instance_valid(me) and me != ai and me.global_position.distance_to(l.global_position) <= LANTERN_R * 2.0:
			continue
		if best == null or l.global_position.distance_to(ai.global_position) < best.global_position.distance_to(ai.global_position):
			best = l
	return best


## 现在打得动的：破绽（挠骑士）优先，再是冻住 / 卡住 / 骑士清醒时的部件
func soft_target() -> Node2D:
	if weak_left > 0.0 and is_instance_valid(weak_spot):
		return weak_spot
	return _nearest_part(GameState.player, func(x): return _soft(x))


func _soft(part: BossPart) -> bool:
	return part.freeze_left > 0.0 or lucid_left > 0.0 or (phase == 1 and stuck_left > 0.0)


func _nearest_part(from: Node2D, ok: Callable) -> BossPart:
	var best: BossPart = null
	var best_d := INF
	for part in parts:
		if is_instance_valid(part) and not part.broken and part.id != "mask" and ok.call(part):
			var d: float = part.global_position.distance_to(from.global_position) if is_instance_valid(from) else 0.0
			if d < best_d:
				best_d = d
				best = part
	return best


## AI 的导演提示：先打破绽 / 冻住 / 卡住的部件
class Hooks extends BattleAIHooks:
	var task: TaskKnightBoss

	func priority_target() -> Variant:
		if is_instance_valid(task) and is_instance_valid(task.dispel) and not task.dispel.done:
			return task.dispel.nearest_hand(task.pink)
		return task.soft_target() if is_instance_valid(task) else null

	func engage_range() -> float:
		return 220.0


# ------------------------------------------------------------------ 部件
## 蓝色公主 J：冻住身边的部件（贴在镇民身上的手印也一起冻掉 = 救下来；最后阶段冻住触手）
func freeze_part(who: PlayableCharacter) -> bool:
	# 护心诅咒：冻核心不吃冷却（三秒内要冻两颗）
	if is_instance_valid(curse) and is_instance_valid(who) and curse.freeze_cores(who):
		Audio.play("chime", -4.0)
		return true
	if freeze_cool > 0.0 or not is_instance_valid(who):
		return false
	var reach := freeze_reach()
	var hit := _freeze_tentacles(who)
	if is_instance_valid(dispel) and dispel.freeze_hands(who, reach):
		hit = true
	for part in parts:
		if is_instance_valid(part) and not part.broken and part.global_position.distance_to(who.global_position) <= reach:
			part.freeze_left = FREEZE_TIME
			hit = true
	for h in hands:
		if is_instance_valid(h) and h.global_position.distance_to(who.global_position) <= reach:
			h.freeze()
			hit = true
	for v in victims:
		if is_instance_valid(v) and v.cursed and v.global_position.distance_to(who.global_position) <= reach:
			rescue(v)
			return true
	if hit:
		freeze_cool = FREEZE_COOL
		Audio.play("chime", -4.0)
		Fx.burst(who.get_parent(), who.global_position, "drop", 8, 30.0, 0.4, Vector2(0, -10), Color(0.8, 0.95, 1.0))
	return hit


## 蓝色公主 J 的冻结范围（做过「点灯笼的小姑娘」：大一圈）
func freeze_reach() -> float:
	return FREEZE_R * (KnightHelpers.BLUE_REACH if KnightQuests.is_done("blue") else 1.0)


## 亮着的光：四盏灯笼里亮了的 + 做过「点灯笼的小姑娘」的旧石灯笼（一开场就亮）
func lights() -> Array:
	var out: Array = lanterns.filter(func(l): return is_instance_valid(l) and l.lit)
	if is_instance_valid(field_helpers) and is_instance_valid(field_helpers.old_lantern):
		out.append(field_helpers.old_lantern)
	return out


## 打部件（测试也直接调）：冻住了 / 护腿卡住了 / 骑士清醒时才打得动；掉一个露出破绽，一套拆完换阶段
func hit_part(part: BossPart) -> bool:
	if not is_instance_valid(part) or part.broken:
		return false
	if is_instance_valid(curse) and curse.invulnerable():
		GameState.notify("诅咒爆发中，打不动！先破解诅咒", 1.0)
		return false
	if part.id == "mask" or not _soft(part):
		GameState.notify("诅咒太硬了……先冻住它！", 1.0)
		return false
	part.hp -= 1
	part.flash = 0.15
	if part.hp <= 0:
		part.broken = true
		var lines: Array = data().get("break", [])
		if not lines.is_empty():
			GameState.princess_reacted.emit(str(lines[0]) % str(data().get("parts", {}).get(part.id, "")), 2.0)
		Audio.play("break", -4.0)
		_burst(part.global_position, Color(0.75, 0.8, 0.9))
		KnightFx.play(get_parent(), "part_break", part.global_position, {"size": 64.0, "z": 5})
		_shake(0.2, 3.0)
		_hitstop()
		if parts.all(func(p): return not is_instance_valid(p) or p.broken or p.id == "mask"):
			if phase < PHASES - 1:
				_transition(phase + 1)
		else:
			open_weak(part.offset)
	return true


func _say(pool: Array) -> void:
	if not pool.is_empty():
		GameState.princess_reacted.emit(str(pool.pick_random()), 2.4)


func _emit(ok: bool) -> void:
	if _emitted:
		return
	_emitted = true
	Engine.time_scale = 1.0
	if grabbed:
		_release_grab()
	for c in _players():
		_take_gear(c)
	if ok and not _split:
		GameState.vars[PHASE_KEY] = 0
		GameState.vars[DISPEL_KEY] = false
	finished.emit(ok)


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and not _emitted:
		aborted = true
		_emit(false)


## 盔甲本体（放大的 knight_cursed）：周身的诅咒光、出招前发光、冲撞的残影、跳起来的高度、踉跄时发白、笑面阶段的光
class Body extends Node2D:
	var task: TaskKnightBoss
	var hop := 0.0
	var _trail: Array = []
	var _t := 0.0
	## 行走图：朝向（行 0 下 / 1 左 / 2 右 / 3 上）、走路的帧（动了才换帧）
	var _row := 0
	var _walk := 0.0
	var _last := Vector2.INF

	func _ready() -> void:
		z_index = 2

	## 这一帧的源矩形：按移动方向挑行，走着的时候按走过的路换帧，站着停在第 0 帧
	func frame() -> Rect2:
		var col := 0 if _walk <= 0.0 else int(_walk / 7.0) % 4
		return Rect2(col * 32, _row * 32, 32, 32)

	func trail(at: Vector2) -> void:
		_trail.append({"at": at, "t": 0.0})

	func _process(delta: float) -> void:
		_t += delta
		var step := Vector2.ZERO if _last == Vector2.INF else global_position - _last
		_last = global_position
		if step.length() > 0.05 and hop <= 0.0:
			if absf(step.x) > absf(step.y):
				_row = 1 if step.x < 0 else 2
			else:
				_row = 3 if step.y < 0 else 0
			_walk += step.length()
		else:
			_walk = 0.0
		for p in _trail:
			p["t"] = float(p["t"]) + delta
		_trail = _trail.filter(func(p): return float(p["t"]) < 0.35)
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(task):
			return
		if task.on_fog() and task.phase == PHASES - 1:
			_draw_possessed()
			return
		# 冲撞的残影
		for p in _trail:
			var a := 0.35 * (1.0 - float(p["t"]) / 0.35)
			draw_texture_rect_region(SHEET, Rect2((p["at"] as Vector2) - global_position + Vector2(-32, -60), Vector2(64, 64)), frame(), Color(0.8, 0.5, 1.0, a))
		# 影子（跳起来的时候留在地上）
		draw_circle(Vector2(0, 2), 14.0 - hop * 0.12, Color(0.1, 0.05, 0.15, 0.35))
		var up := Vector2(0, -hop)
		# 周身的诅咒光：几缕往上飘的紫火
		var aura := Color(0.6, 0.3, 0.9, 0.2)
		if task.phase == PHASES - 1:
			aura = Color(0.85, 0.35, 0.9, 0.25 + 0.1 * sin(_t * 6.0))
		draw_circle(up + Vector2(0, 4), 26 + sin(_t * 3.0) * 2.0, aura)
		for i in 5:
			var k := fmod(_t * 0.8 + i * 0.2, 1.0)
			var x := sin(i * 2.1 + _t * 2.0) * 14.0
			draw_circle(up + Vector2(x, -8 - k * 40.0), 3.0 * (1.0 - k), Color(0.75, 0.4, 1.0, 0.5 * (1.0 - k)))
		var tint := Color.WHITE
		if task.body_mode == "windup":
			tint = Color(1.4, 1.1, 1.4)
		elif task.body_mode == "stagger":
			tint = Color(1.6, 1.6, 1.6) if int(_t * 16.0) % 2 == 0 else Color.WHITE
		draw_texture_rect_region(SHEET, Rect2(up + Vector2(-32, -60), Vector2(64, 64)), frame(), tint)
		if task.body_mode == "windup":
			draw_arc(up + Vector2(0, -26), 30, 0, TAU, 24, Color(1, 0.6, 0.9, 0.7), 2.0)
		# 骑士的笑（挠破绽涨）：头顶一条金色的条；清醒的时候整个身子发金光
		if task.knight_laugh > 0.0 or task.weak_left > 0.0:
			draw_rect(Rect2(up.x - 20, up.y - 72, 40, 4), Color(0.15, 0.1, 0.2, 0.8))
			draw_rect(Rect2(up.x - 20, up.y - 72, 40 * task.knight_laugh, 4), Color(1, 0.85, 0.4))
		if task.lucid_left > 0.0:
			draw_circle(up + Vector2(0, -20), 30 + sin(_t * 8.0) * 3.0, Color(1, 0.9, 0.5, 0.18))
		if task.enraged:
			draw_arc(up + Vector2(0, -20), 34, 0, TAU, 24, Color(0.9, 0.3, 0.6, 0.5 + 0.3 * sin(_t * 12.0)), 2.0)


	## 笑雾之中：被黑雾托在半空的骑士（npcs/knight_possessed.png：上排浮空 4 帧、下排落地被解脱 4 帧），周围飘笑声字
	func _draw_possessed() -> void:
		var cell := float(POSSESSED_CELL)
		var src := Rect2()
		var up := Vector2.ZERO
		if task.floating:
			up = Vector2(0, -FLOAT_H - sin(_t * 2.0) * FLOAT_BOB)
			src = Rect2(int(_t * 6.0) % 4 * cell, 0, cell, cell)
		else:
			# 落地：0→1 帧；驱散时按读条 1→3 帧（黑雾越来越淡）
			var col := 0
			if task.land_left > 0.0:
				task.land_left = maxf(0.0, task.land_left - get_process_delta_time())
				col = 0 if task.land_left > LAND_TIME * 0.5 else 1
				up = Vector2(0, -FLOAT_H * task.land_left / LAND_TIME)
			elif is_instance_valid(task.dispel):
				col = 1 + int(clampf(task.dispel.progress, 0.0, 0.99) * 3.0)
			src = Rect2(col * cell, cell, cell, cell)
		draw_circle(Vector2(0, 2), 16.0, Color(0.08, 0.03, 0.12, 0.45))
		draw_texture_rect_region(POSSESSED_SHEET, Rect2(up + Vector2(-cell / 2.0, -cell + 6.0), Vector2(cell, cell)), src)
		if task.floating:
			# 飘着的笑声字
			var words: Array = TaskKnightBoss.data().get("fog", {}).get("words", ["哈哈"])
			for i in 6:
				var k := fmod(_t * 0.35 + i / 6.0, 1.0)
				var at := up + Vector2(sin(i * 2.3 + _t * 0.8) * 46.0, -40.0 - k * 50.0)
				draw_string(ThemeDB.fallback_font, at, str(words[i % words.size()]), HORIZONTAL_ALIGNMENT_CENTER, -1, 10,
					Color(0.9, 0.7, 1.0, 0.7 * sin(k * PI)))


## 诅咒部件：平时打不动（诅咒太硬），冻住（或护腿卡住）以后普通攻击就能打碎；跟着本体走
class BossPart extends CharacterBody2D:
	var task: TaskKnightBoss
	var id := ""
	var offset := Vector2.ZERO
	var hp := PART_HP
	var broken := false
	var freeze_left := 0.0
	var flash := 0.0
	var faction := Faction.Type.ENEMY
	var _t := 0.0

	func _ready() -> void:
		add_to_group("enemy")
		collision_layer = 4
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 9.0
		shape.shape = c
		add_child(shape)
		z_index = 3
		set_meta("hit_radius", 9.0)

	func is_alive() -> bool:
		return not broken

	func receive_hit(_hit: HitData) -> bool:
		return is_instance_valid(task) and task.hit_part(self)

	func _process(delta: float) -> void:
		_t += delta
		freeze_left = maxf(0.0, freeze_left - delta)
		flash = maxf(0.0, flash - delta)
		if is_instance_valid(task) and is_instance_valid(task._body):
			var hop: float = (task._body as Body).hop
			global_position = task._body.global_position + offset + Vector2(sin(_t * 2.0 + offset.x) * 2.0, -hop)
		queue_redraw()

	func _draw() -> void:
		if broken:
			return
		var col := Color(0.75, 0.92, 1.0) if freeze_left > 0.0 else Color(0.72, 0.45, 0.95)
		if is_instance_valid(task) and task.lucid_left > 0.0 and freeze_left <= 0.0:
			col = Color(1, 0.85, 0.5)
		if flash > 0.0:
			col = Color.WHITE
		match id:
			"mask":
				var glow := 0.5 + 0.3 * sin(_t * 5.0)
				draw_circle(Vector2.ZERO, 14, Color(0.9, 0.4, 1.0, 0.2 * glow))
				draw_circle(Vector2.ZERO, 10, Color(0.55, 0.3, 0.75, 0.9))
				draw_arc(Vector2(0, 2), 5, 0.2, PI - 0.2, 8, Color(1, 0.8, 1.0), 2)
				draw_circle(Vector2(-4, -3), 1.5, Color(1, 0.85, 1.0))
				draw_circle(Vector2(4, -3), 1.5, Color(1, 0.85, 1.0))
			"plate_l", "plate_r":
				# 半块胸甲：圆角的甲片 + 中间一道护心的纹
				var sx := -1.0 if id == "plate_l" else 1.0
				draw_rect(Rect2(-7, -8, 14, 16), col)
				draw_line(Vector2(-7 * sx, -8), Vector2(-7 * sx, 8), Color(col.darkened(0.3)), 2)
				draw_circle(Vector2(-5 * sx, -2), 2.0, Color(1, 0.7, 0.9))
			_:
				draw_rect(Rect2(-7, -6, 14, 12), col)
				for i in 4:
					draw_line(Vector2(-5 + i * 3.3, -6), Vector2(-5 + i * 3.3, -11), col, 2)
		for i in hp:
			draw_rect(Rect2(-6 + i * 5, 9, 4, 2), Color(1, 0.6, 0.8))
		if freeze_left > 0.0:
			draw_arc(Vector2.ZERO, 12, 0, TAU, 16, Color(0.8, 0.95, 1.0, 0.8), 1.5)


## 地上的预警圈：先淡后深，外圈一直闪
class DangerCircle extends Node2D:
	var radius := 12.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var col := Color(0.75, 0.35, 1.0)
		var k := minf(1.0, _t / 0.9)
		draw_circle(Vector2.ZERO, radius * (0.3 + 0.7 * k), Color(col, 0.15 + 0.25 * k))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 20, Color(col, 0.6 + 0.3 * sin(_t * 14.0)), 1.5)


## 呼唤骑士之名的蓄力：盔甲脚下一圈预警，缺口的方向画成亮的扇形（站在那个方向上安全）
class NameWarn extends Node2D:
	var gaps: Array = []
	var _t := 0.0

	func _ready() -> void:
		z_index = 0
		add_to_group("danger")

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		# 外圈：冲击波会扫到的范围（红），缺口的方向画成亮绿的扇形 + 描边（站在那个方向上安全）
		var r := KnightBossFx.Ring.MAX_R
		var steps := 72
		for i in steps:
			var a0 := TAU * i / steps
			var a1 := TAU * (i + 1) / steps
			var mid := (a0 + a1) * 0.5
			if gaps.any(func(g): return absf(angle_difference(mid, float(g))) <= KnightBossFx.Ring.GAP):
				continue
			draw_arc(Vector2.ZERO, r, a0, a1, 2, Color(1, 0.3, 0.45, 0.55 + 0.3 * sin(_t * 12.0)), 2.0)
		draw_arc(Vector2.ZERO, 24 + fmod(_t * 60.0, r - 24.0), 0, TAU, 40, Color(1, 0.5, 0.8, 0.5), 1.5)
		for g in gaps:
			var a := float(g)
			var pts := PackedVector2Array([Vector2.ZERO])
			for i in 9:
				pts.append(Vector2.from_angle(a - KnightBossFx.Ring.GAP + i * KnightBossFx.Ring.GAP * 2.0 / 8.0) * r)
			draw_colored_polygon(pts, Color(0.45, 1.0, 0.7, 0.28 + 0.1 * sin(_t * 10.0)))
			draw_polyline(pts + PackedVector2Array([Vector2.ZERO]), Color(0.6, 1.0, 0.8, 0.9), 1.5)


## 笑面吐出来的笑气（GAS_LIFE 秒后散掉）
class GasCloud extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= GAS_LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var a := 0.35 * (1.0 - _t / GAS_LIFE)
		for i in 5:
			var p := Vector2.from_angle(i * TAU / 5.0 + _t) * 10.0
			draw_circle(p, 12, Color(0.95, 0.6, 0.9, a))

class_name BluePrincess
extends Princess
## 蓝色的公主：和公主同一套可操作角色（行走、表情、受挠、失控、魔法），用自己的精灵图 / 魔法图 / 立绘（portrait_set = "blue"）。
## 平时由 WanderController（AI）在小镇里溜达；走近按 E 和她说话（Dialogue.talk(dialogue)），说话时停下、转向公主。
## 测试模式按 F2（switch_character）切换成玩家操控（GameState.switch_control）。
## 图例：X = blue_princess [dialogue=…] [show_flag=…]；过场里 spawn kind=npc:blue_princess 生成的是 ai = false 的演员。

@export var dialogue := "floor_06/blue_princess"
## 有这个剧情标记才出现（开场之后）。
@export var show_flag := "f6_opening_done"
## 有其中任何一个标记时不出现（带主角参观小镇时由过场演员代替、夜里在家、她自己当主角之后）。
@export var hide_flags: Array[String] = ["f6_touring", "night", "blue_is_hero"]
## false = 过场演员：不溜达，位置由过场控制。
@export var ai := true
## true = 她是主角（第七层起，剧情标记 blue_is_hero）：玩家操控、相机跟着她、没有对话提示。关卡载入时由 level.gd 换上。
@export var hero := false

var talking := false
## 千手痒痒裤（状态 thousand_pants）：每 PANTS_TICK 秒发作一下（来源键 thousand_pants），每次随机一种手法，
## 挠对应的部位、说对应的台词（maze_lines.json 的 pants_<手法>）：
##   knead 揉腿根 / climb 沿大腿内侧往上爬 / pinch 轮流捏屁股 / scrape 大腿和屁股交界处轻刮
## 她是操控的角色：台词显示在立绘旁；跟着走时：头顶气泡（至少隔 PANTS_BUBBLE_GAP 秒一次，不刷屏）。
const PANTS_TICK := 6.0
const PANTS_TICKLE := 1.5
const PANTS_BUBBLE_GAP := 14.0
const PANTS_WAYS := {"knead": "thigh", "climb": "thigh", "pinch": "butt", "scrape": "butt"}
var _pants_t := PANTS_TICK
var _pants_src: Node2D
var _pants_bubble_t := 0.0
## 最近一次发作的手法（测试用）
var pants_way := ""


func _setup() -> void:
	portrait_set = "blue"
	character_id = "blue"
	# 千手痒痒裤（夜迷宫里身上超过 8 只手之后一直穿着）：剧情标记 blue_tickle_pants → 永久状态
	if GameState.has_flag("blue_tickle_pants") and not has_buff("thousand_pants"):
		add_buff("thousand_pants")
	if hero:
		ai = false
		dialogue = ""
		show_flag = ""
		hide_flags.clear()
		set_faction(Faction.Type.PLAYER)
		if not (controller is PlayerInputController or controller is ScriptedController):
			set_controller(PlayerInputController.new())
		super()
		if camera:
			camera.enabled = true
			camera.make_current()
		var talk_area := get_node_or_null("Talk") as Interactable
		if talk_area:
			talk_area.enabled = false
		return
	if follow:
		set_controller(make_ai_controller())
		super()
		start_following()
		return
	# 场景里自带的是玩家输入：换成 AI（过场演员换成脚本控制）
	if not (controller is WanderController or controller is ScriptedController):
		set_controller(make_ai_controller())
	super()
	if camera and not is_controlled():
		camera.enabled = false
	var it := get_node_or_null("Talk") as Interactable
	if it:
		it.interacted.connect(func(p: Node): talk(p))
	GameState.flag_changed.connect(func(_f: String): _refresh_visibility())
	_refresh_visibility()


## 千手痒痒裤：时不时挠一下大腿 / 屁股（小人上不画出来）。
func _process(delta: float) -> void:
	var on := has_buff("thousand_pants")
	if not on or not is_alive() or GameState.in_dialogue or GameState.in_cutscene or CG.is_busy():
		return
	_pants_t -= delta
	_pants_bubble_t = maxf(0.0, _pants_bubble_t - delta)
	if _pants_t <= 0.0:
		_pants_t = PANTS_TICK * randf_range(0.8, 1.2)
		pants_flare()


## 痒痒裤发作一下：随机一种手法，挠对应的部位，说这种手法的台词。返回手法。
func pants_flare(way := "") -> String:
	if way == "":
		way = PANTS_WAYS.keys().pick_random()
	pants_way = way
	if _pants_src == null:
		_pants_src = HandCover.Source.new()
		_pants_src.reaction_key = "thousand_pants"
		add_child(_pants_src)
	var h := HitData.make_tickle(_pants_src, PANTS_TICKLE)
	h.zone = str(PANTS_WAYS.get(way, "thigh"))
	receive_hit(h)
	var line := MazeLines.pick("pants_" + way)
	if line != "":
		if is_controlled():
			GameState.princess_reacted.emit(line, 2.4)
		elif _pants_bubble_t <= 0.0:
			_pants_bubble_t = PANTS_BUBBLE_GAP
			SpeechBubble.say(self, line, 28.0)
	return way


## 千手痒痒裤让魔法失败：魔力散掉的一瞬间，裤子里的手指一起动起来——她憋不住大笑（轻笑声 + 台词 + 闷笑 +15）。
func _on_magic_fail(_tier: int) -> void:
	shake(0.5)
	if laugh:
		laugh.add(15.0)
	Audio.play_crack()
	var line := MazeLines.pick("pants_fail")
	if line != "":
		if is_controlled():
			GameState.princess_reacted.emit(line, 2.8)
			GameState.hint("魔法失败了！千手痒痒裤……")
		else:
			SpeechBubble.say(self, line, 28.0)


## 她的魔法是冰晶结界（冻住范围内的怪物和陷阱，期间自己不涨闷笑），不是星光爆发。
func cast_magic(tier: int) -> void:
	IceBarrier.cast(self, tier)


## 疲倦爆发：原来的疲倦星光爆发 + 冰晶结界的一半控制（满蓄力的范围、冻一半的时间）。
func cast_fatigue_burst() -> void:
	StarBurst.cast_fatigue(self)
	var full := IceBarrier.params(IceBarrier.TIERS.size() - 1)
	IceBarrier.cast_with(self, full["radius"], full["time"] * 0.5)


## 她的魔力疲倦爆发立绘是立绘图的最后一格（战损憋笑释放）。
func fatigue_burst_visual() -> String:
	return "damaged_giggle_burst"


## 跟着玩家操控的角色走（不溜达、一直显示；普通的对话关掉，partner_talk 给了就能聊 / 换人）；挣扎也会自己做。
func start_following(talk_file := "") -> void:
	ai = false
	dialogue = ""
	show_flag = ""
	hide_flags.clear()
	var it := get_node_or_null("Talk") as Interactable
	if it:
		it.enabled = false
	super(talk_file)
	_refresh_visibility()


func make_ai_controller() -> CharacterController:
	if follow:
		return super()
	if Duo.active:
		return CompanionController.new()
	return WanderController.new() if ai else ScriptedController.new()


func display_name() -> String:
	return "蓝色的公主"


func _refresh_visibility() -> void:
	var show := show_flag == "" or GameState.has_flag(show_flag) or not ai
	if ai and not is_controlled() and hide_flags.any(func(f): return GameState.has_flag(f)):
		show = false
	visible = show
	process_mode = Node.PROCESS_MODE_INHERIT if show else Node.PROCESS_MODE_DISABLED
	var it := get_node_or_null("Talk") as Interactable
	if it:
		it.enabled = show and dialogue != "" and not is_controlled()


func talk(player: Node) -> void:
	if talking or dialogue == "" or is_controlled() or Dialogue.runner.is_running():
		return
	talking = true
	var wc := controller as WanderController
	if wc:
		wc.paused = true
		wc.path.clear()
	if player is Node2D:
		var d := (player as Node2D).global_position - global_position
		if d.length() > 0.1:
			facing = d.normalized()
	await Dialogue.talk(dialogue)
	talking = false
	if wc and is_instance_valid(wc):
		wc.paused = false
	_refresh_visibility()

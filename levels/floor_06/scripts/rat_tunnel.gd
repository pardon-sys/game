class_name RatTunnel
extends Node2D
## 反省篇第二章·鼠洞（floor_06_rat_tunnel，等距；布局 tools/build/quest_maps.py 的 _tunnel；台词 tools/build/penance_text/tunnel.py）。
## 粉色公主穿着鼠鼠装（Equipment.outfit = mouse：挠脚鼠时不时乱窜暴击、鼠味引怪）一路往里爬：
##   三段挠脚鼠的小剧场（纯小剧场）：走到标记点 thigh / sole / shaft 就演 tunnel_thigh / tunnel_sole / tunnel_shaft（各一次）；
##     shaft 是本章章末大段（四幕 + CG），演完接过场 tunnel_out（章末画面）。
##   滴水管（drips）：每 DRIP_EVERY 秒滴一滴（先 DRIP_WARN 秒地上出影子），滴到她（DRIP_R 以内）→ 惊动挠脚鼠，鼠鼠装发作一次（暴击）。
##   检查点（checkpoints）：走过就记下；被猫追上后回到最近走过的那个。
##   猫咪追逐：走到 cat_start → 橘猫从身后（最近的检查点）追出来（CAT_SPEED，比走路快、比冲刺慢），跑到 cat_end 的小洞就安全；
##     追上了 → 小剧场 tunnel_cat_first（第一次，长一点）/ tunnel_cat，然后回检查点重跑。
##   老鼠窝（nest）、刻字的死胡同（clue）：按 E 调查（对话 floor_06/tunnel_nest、tunnel_clue）。
##   洞里的老鼠（地图里的 monster type=rat）全打倒 → 小剧场 tunnel_revenge（CG：裤子里的挠脚鼠叫来一群挠脚鼠报复，REVENGE_FLAG）。
## 等距地图：滴水管、猫都挂在 Entities（导演的父节点）下面，各自投影；导演自己只管逻辑。
## 测试：triggered、checkpoint、drips、cat、chasing、safe、caught_count、drip_hit(i)、catch_now()。

const MAP := "floor_06_rat_tunnel"
const SCENES := {"thigh": "tunnel_thigh", "sole": "tunnel_sole", "shaft": "tunnel_shaft"}
const DONE_FLAG := "tunnel_done"
const TRIGGER_R := 14.0
const CHECK_R := 14.0
const DRIP_EVERY := Vector2(2.2, 3.4)
const DRIP_WARN := 0.8
const DRIP_R := 12.0
const CAT_SPEED := 92.0
const CAT_CATCH_R := 10.0
const CAT_START_R := 14.0
const SAFE_R := 14.0
const REVENGE_FLAG := "tunnel_mice_revenge"

var lv: Node
var triggered := {}
var checkpoint := Vector2.ZERO
var drips: Array = []
var cat: TunnelCat
var chasing := false
var safe := false
var caught_count := 0
var _cps: Array = []
static var _data := {}


## 玩法里的短台词（tools/build/penance_text/tunnel.py → data/after/tunnel.json）：cat_start 猫追出来、drip 被滴到
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/after/tunnel.json"))
		_data = parsed if parsed is Dictionary else {}
	return _data


func _ready() -> void:
	lv = get_parent()
	while lv and lv.get_node_or_null("Floor") == null and lv.get_parent():
		lv = lv.get_parent()
	for c in QuestMaps.cells(MAP, "drips"):
		var d := Drip.new()
		d.tunnel = self
		d.left = randf_range(DRIP_EVERY.x, DRIP_EVERY.y)
		get_parent().add_child.call_deferred(d)
		d.position = Cutscene.cell_to_world(c)
		drips.append(d)
	for c in QuestMaps.cells(MAP, "checkpoints"):
		_cps.append(Cutscene.cell_to_world(c))
	checkpoint = Cutscene.cell_to_world(QuestMaps.cell(MAP, "start"))
	for pair in [["nest", "floor_06/tunnel_nest"], ["clue", "floor_06/tunnel_clue"]]:
		var sp := PrisonOddities.Spot.new()
		sp.dialogue = str(pair[1])
		add_child(sp)
		sp.global_position = Cutscene.cell_to_world(QuestMaps.cell(MAP, str(pair[0])))
	# 等距地图：每个要单独投影的东西都得是 Entities 的直接子节点（挂在导演下面会跟着导演的投影位置偏）
	cat = TunnelCat.new()
	cat.tunnel = self
	get_parent().add_child.call_deferred(cat)
	cat.hide()
	safe = GameState.has_flag("tunnel_cat_safe")
	# 跳关进来（没经过牢房的换装）：补穿鼠鼠装
	if GameState.has_flag("penance_mouse_dev") and not PenanceCell.wearing_mouse():
		PenanceCell.wear_mouse()


var _rats_seen := false


## 洞里还活着的老鼠（地图里放的那几只）
func rats_left() -> int:
	var n := 0
	for m in lv.find_children("*", "Monster", true, false) if lv else []:
		if (m as Monster).is_alive():
			n += 1
	if n > 0:
		_rats_seen = true
	return n


func _busy() -> bool:
	return GameState.in_dialogue or GameState.in_cutscene or CG.is_busy() or Dialogue.is_active()


func _process(delta: float) -> void:
	var p := GameState.player
	if not is_instance_valid(p) or _busy():
		return
	var at := p.global_position
	# 三段挠脚鼠的小剧场
	for k in SCENES:
		if not triggered.has(k) and not GameState.has_flag("cg_seen_theater:" + str(SCENES[k])) \
				and at.distance_to(Cutscene.cell_to_world(QuestMaps.cell(MAP, k))) <= TRIGGER_R:
			triggered[k] = true
			_stop_chase()
			CG.play_theater(str(SCENES[k]))
			return
	# 洞里的老鼠全打倒：挠脚鼠们的报复
	if not GameState.has_flag(REVENGE_FLAG) and rats_left() == 0 and _rats_seen:
		GameState.set_flag(REVENGE_FLAG)
		_stop_chase()
		CG.play_theater("tunnel_revenge")
		return
	# 竖井那段演完：章末过场
	if GameState.has_flag("cg_seen_theater:tunnel_shaft") and not GameState.has_flag(DONE_FLAG):
		GameState.set_flag(DONE_FLAG)
		Cutscene.play("tunnel_out")
		return
	# 检查点
	for c in _cps:
		if at.distance_to(c) <= CHECK_R:
			checkpoint = c
	# 滴水管
	for d in drips:
		(d as Drip).tick(delta, p)
	# 猫咪追逐
	if not safe:
		if not chasing and at.distance_to(Cutscene.cell_to_world(QuestMaps.cell(MAP, "cat_start"))) <= CAT_START_R:
			_start_chase()
		if chasing:
			cat.step(p, delta)
			if at.distance_to(Cutscene.cell_to_world(QuestMaps.cell(MAP, "cat_end"))) <= SAFE_R:
				_reach_safe()
			elif cat.global_position.distance_to(at) <= CAT_CATCH_R:
				catch_now()


func _start_chase() -> void:
	chasing = true
	cat.show()
	cat.global_position = _cps[1] if _cps.size() > 1 else checkpoint
	cat.reset_path()
	Audio.play("bat_flap", -6.0, 0.0, 0.7)
	SpeechBubble.say(cat, "喵——！！", 24.0, 1.4)
	var lines: Array = (RatTunnel.data().get("cat_start", []) as Array)
	if not lines.is_empty():
		GameState.princess_reacted.emit(str(lines.pick_random()), 2.2)


func _stop_chase() -> void:
	chasing = false
	cat.hide()


func _reach_safe() -> void:
	safe = true
	chasing = false
	GameState.set_flag("tunnel_cat_safe")
	SpeechBubble.say(cat, "喵……", 24.0, 1.4)
	var tw := cat.create_tween()
	tw.tween_property(cat, "modulate:a", 0.0, 0.8)
	tw.tween_callback(cat.hide)
	tw.tween_property(cat, "modulate:a", 1.0, 0.0)


## 被猫追上：小剧场（第一次长一点）→ 回到最近走过的检查点重跑
func catch_now() -> void:
	chasing = false
	caught_count += 1
	var id := "tunnel_cat_first" if not GameState.has_flag("cg_seen_theater:tunnel_cat_first") else "tunnel_cat"
	await CG.play_theater(id)
	cat.hide()
	var p := GameState.player
	if is_instance_valid(p):
		p.global_position = checkpoint
		if p.get("camera"):
			p.camera.reset_smoothing()


## 测试用：这一格的滴水管马上滴一滴
func drip_hit(i: int) -> bool:
	return (drips[i] as Drip).splash(GameState.player)


## 滴水管：天花板上的水滴，落地前地上先出一个影子
class Drip extends Node2D:
	var tunnel: RatTunnel
	var left := 2.0
	var warn := 0.0
	var _splash := 0.0

	func _ready() -> void:
		z_index = 1

	func tick(delta: float, p: Node2D) -> void:
		_splash = maxf(0.0, _splash - delta)
		if warn > 0.0:
			warn -= delta
			if warn <= 0.0:
				splash(p)
				left = randf_range(RatTunnel.DRIP_EVERY.x, RatTunnel.DRIP_EVERY.y)
		else:
			left -= delta
			if left <= 0.0:
				warn = RatTunnel.DRIP_WARN
		queue_redraw()

	## 落下来：她在旁边 → 惊动挠脚鼠（鼠鼠装发作一次）。返回滴没滴到她
	func splash(p: Node2D) -> bool:
		_splash = 0.35
		warn = 0.0
		Audio.play("puddle", -10.0, 0.1, 1.4)
		var pc := p as PlayableCharacter
		if pc == null or p.global_position.distance_to(global_position) > RatTunnel.DRIP_R:
			return false
		var fx := EquipFx.of(pc)
		if fx and Equipment.outfit(pc.character_id) == "mouse":
			fx.flare(["equip_mouse_shorts", "equip_mouse_paw_shoes"].pick_random(), ["thigh", "sole"].pick_random())
		else:
			pc.receive_hit(HitData.make_tickle(self, 4.0))
		var lines: Array = (RatTunnel.data().get("drip", []) as Array)
		if not lines.is_empty():
			GameState.princess_reacted.emit(str(lines.pick_random()), 2.0)
		return true

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, IsoView.ground_scale())
		draw_circle(Vector2.ZERO, 8.0, Color(0.35, 0.55, 0.8, 0.55))
		draw_arc(Vector2.ZERO, 8.0, 0, TAU, 20, Color(0.7, 0.85, 1.0, 0.7), 1.0)
		if warn > 0.0:
			var k := 1.0 - warn / RatTunnel.DRIP_WARN
			draw_circle(Vector2.ZERO, 3.0 + 7.0 * k, Color(0.05, 0.05, 0.15, 0.35 + 0.35 * k))
		if _splash > 0.0:
			draw_arc(Vector2.ZERO, 10.0 - 20.0 * _splash, 0, TAU, 16, Color(0.7, 0.85, 1.0, 0.9), 1.5)
		draw_set_transform(Vector2.ZERO)
		if warn > 0.0:
			var k2 := 1.0 - warn / RatTunnel.DRIP_WARN
			draw_circle(Vector2(0, -40.0 + 40.0 * k2), 2.0, Color(0.7, 0.85, 1.0, 0.9))


## 追人的橘猫：沿格子路追她
class TunnelCat extends Node2D:
	var tunnel: RatTunnel
	var _spr: Sprite2D
	var _path: Array[Vector2] = []
	var _repath := 0.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 2
		_spr = Sprite2D.new()
		_spr.texture = load("res://assets/generated/cat_run.png")
		_spr.hframes = 4
		_spr.offset = Vector2(0, -8)
		_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_spr)

	func reset_path() -> void:
		_path.clear()
		_repath = 0.0

	func step(target: Node2D, delta: float) -> void:
		_t += delta
		_repath -= delta
		if _repath <= 0.0 or _path.is_empty():
			_repath = 0.3
			_path = GridPath.find(tunnel.lv, global_position, target.global_position)
			_path.append(target.global_position)
		var before := global_position
		GridPath.follow(self, _path, RatTunnel.CAT_SPEED, delta)
		var d := global_position - before
		if absf(d.x) > 0.01:
			_spr.flip_h = IsoView.screen_dir(d).x < 0.0
		_spr.frame = int(_t * 10.0) % 4

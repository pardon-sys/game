class_name EquipFx
extends Node
## 负面装备的发作反应（装备模块的一部分；PlayableCharacter 在 _setup 里挂上，节点名 EquipFx）：
##   穿着的负面装备（诅咒的、被强制穿上的，见 Equipment.is_negative）每隔 interval 秒发作一次：
##   按 amount 挠一下对应部位（来源键 = 装备 id），发 flared(装备 id, 部位) 信号；
##   操控的人：立绘抖动 + 部位贴片 + 按闷笑阶段飘字（平静时也飘）；跟着走的那个：头顶小气泡 + 小人抖一下。
## 反应数据单独一个文件，分角色：粉色公主 data/equip_reactions.json，蓝色公主 data/characters/blue/equip_reactions.json
##   {装备 id: {interval: [最短, 最长], amount, zones: [部位], shake, words: {calm, giggle, helpless}, lines: [台词],
##              driven: true（自己不计时，由别的逻辑调 flare：千手痒痒裤由 BluePrincess.pants_flare 驱动），
##              ways: {手法: {zone, words: [...]}}（driven 的装备按手法换飘字）}}
## 加成 add_mod(键, 频率倍数, 力度倍数, 秒)：攻防战的狂欢图腾（一直有效）、千手痒痒裤吸收临时装备（20 秒）……
##   rate_mul / power_mul 是所有加成的乘积；千手痒痒裤的发作间隔 / 力度也读它们。
## 被强制穿上的临时装备也在这里倒计时（Equipment.tick_forced）。
## 反应数据里 crit = true（鼠鼠装：挠脚鼠乱窜）：这一下是暴击（HitData.special：金色暴击星环 + 暴击音效），魔力疲倦按 fatigue_mult 倍积累。
## 装备 special = mouse_scent（鼠鼠短裤）：每 SCENT_EVERY 秒把 SCENT_R 以内的怪引过来（Monster.rally_to）。

signal flared(id: String, zone: String)

const PATH := "res://data/equip_reactions.json"
## 跟着走的那个人：头顶气泡至少隔这么久一次
const BUBBLE_GAP := 6.0
## 发作那一下的闷笑倍数（原来的 amount 太小，几乎看不出涨）
const FLARE_MULT := 2.5
## 装备 → 手法特效（HitFx 的种类）
const SCENT_EVERY := 1.5
const SCENT_R := 90.0
const WAY_FX := {"feather": ["feather_socks", "fluff", "feather_shackles"], "brush": ["toe_brush"], "pinch": ["pinch_pad", "knead"],
	"hand": ["thigh_ring", "thigh_strap", "pants"], "bubble": ["bell"], "curse": ["mark"]}

static var _cache := {}

var who: PlayableCharacter
var rate_mul := 1.0
var power_mul := 1.0
## {键: [频率倍数, 力度倍数, 剩余秒（<0 = 一直有效）]}
var _mods := {}
var _timers := {}
var _bubble_t := 0.0
var _src: Dictionary = {}
## 最近一次发作（测试用）：[装备 id, 部位, 飘的字]
var last := []


static func data(char_id: String) -> Dictionary:
	if not _cache.has(char_id):
		var p := Characters.path("equip_reactions.json", PATH, char_id)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else {}
		_cache[char_id] = parsed if parsed is Dictionary else {}
	return _cache[char_id]


static func entry(char_id: String, id: String) -> Dictionary:
	var e: Variant = data(char_id).get(id, {})
	return e if e is Dictionary else {}


static func of(c: Node) -> EquipFx:
	return c.get_node_or_null("EquipFx") as EquipFx if c else null


func _ready() -> void:
	name = "EquipFx"
	who = get_parent() as PlayableCharacter


func add_mod(key: String, rate: float, power: float, sec := -1.0) -> void:
	_mods[key] = [rate, power, sec]
	_refresh_mods()


func remove_mod(key: String) -> void:
	_mods.erase(key)
	_refresh_mods()


func has_mod(key: String) -> bool:
	return _mods.has(key)


func _refresh_mods() -> void:
	rate_mul = 1.0
	power_mul = 1.0
	for k in _mods:
		rate_mul *= float(_mods[k][0])
		power_mul *= float(_mods[k][1])


func _process(delta: float) -> void:
	_bubble_t = maxf(0.0, _bubble_t - delta)
	var expired := false
	for k in _mods.keys():
		if float(_mods[k][2]) >= 0.0:
			_mods[k][2] = float(_mods[k][2]) - delta
			if float(_mods[k][2]) <= 0.0:
				_mods.erase(k)
				expired = true
	if expired:
		_refresh_mods()
	if who and not GameState.in_cutscene and not CG.is_busy():
		Equipment.tick_forced(who.character_id, delta)
	_bell_move(delta)
	_mouse_scent(delta)
	if who == null or not who.is_alive() or GameState.in_dialogue or GameState.in_cutscene or CG.is_busy():
		return
	var live := {}
	for it in Equipment.items_of(who.character_id):
		if not Equipment.is_negative(who.character_id, it.id):
			continue
		var e := entry(who.character_id, it.id)
		if e.is_empty() or bool(e.get("driven", false)):
			continue
		live[it.id] = true
		if not _timers.has(it.id):
			_timers[it.id] = _next_interval(e)
		_timers[it.id] = float(_timers[it.id]) - delta * rate_mul
		if float(_timers[it.id]) <= 0.0:
			_timers[it.id] = _next_interval(e)
			var zones: Array = e.get("zones", it.slots)
			flare(it.id, str(zones.pick_random()) if not zones.is_empty() else "")
	for id in _timers.keys():
		if not live.has(id):
			_timers.erase(id)


var _bell_t := 0.0


## 铃铛脚链（临时装备 special = bell_move）：走动时每隔一会儿叮铃一声，把附近的怪引过来。
func _bell_move(delta: float) -> void:
	_bell_t -= delta
	if who == null or _bell_t > 0.0 or who.velocity.length() < 12.0 or not Equipment.has_special(who.character_id, "bell_move"):
		return
	_bell_t = 1.6
	if who.has_method("_ring_bell"):
		Audio.play("bell_jingle", -8.0, 0.1)
		who.call("_ring_bell")


var _scent_t := 0.0


## 鼠鼠短裤（special = mouse_scent）：身上的鼠味把附近一小圈的怪引过来。返回引过来几只（测试用）。
func _mouse_scent(delta: float) -> int:
	_scent_t -= delta
	if who == null or _scent_t > 0.0 or not who.is_alive() or not Equipment.has_special(who.character_id, "mouse_scent"):
		return 0
	_scent_t = SCENT_EVERY
	return scent_now()


func scent_now() -> int:
	var n := 0
	for m in who.get_tree().get_nodes_in_group("enemy"):
		if m is Monster and (m as Node2D).global_position.distance_to(who.global_position) <= SCENT_R:
			(m as Monster).rally_to(who)
			n += 1
	return n


func _next_interval(e: Dictionary) -> float:
	var iv: Variant = e.get("interval", [8.0, 12.0])
	if iv is Array and iv.size() >= 2:
		return randf_range(float(iv[0]), float(iv[1]))
	return float(iv)


## 发作一次。tickle = false：只出反应（挠痒已经由调用的一方做了）；way：手法（换飘字）。返回飘的字。
func flare(id: String, zone: String, way := "", tickle := true) -> String:
	if who == null:
		return ""
	var e := entry(who.character_id, id)
	var amount := float(e.get("amount", 0.0)) * power_mul
	# 攻防战：裁缝的厚棉衣让临时装备的发作减半
	var sd := SiegeDirector.current
	if sd and sd.town and Equipment.is_forced(who.character_id, id):
		amount *= sd.town.mul("equip_power")
	# 羽毛袜：跑得越快挠得越重
	if bool(e.get("move_scale", false)):
		amount *= 1.0 + who.velocity.length() / 50.0
	var fx_kind := fx_of(id)
	if tickle and amount > 0.0:
		var h := HitData.make_tickle(_source(id), amount * FLARE_MULT)
		h.zone = zone
		h.ignore_block = true   # 装备自己挠自己：防护装备挡不住
		if bool(e.get("crit", false)):
			h.special = true
			h.fatigue_mult = float(e.get("fatigue_mult", 2.0))
			Audio.play("tickle_special", -4.0, 0.08)
		who.receive_hit(h)
		# 小人身上那个部位：手法特效 + 抖一下
		if who.is_inside_tree():
			HitFx.play(fx_kind, who.get_parent(), ZoneFx.body_point(who, zone) if zone != "" else who.global_position + Vector2(0, -10))
			who.shake(0.15)
	var text := _pick_words(e, way)
	last = [id, zone, text]
	flared.emit(id, zone)
	if who.is_controlled():
		var fx: PortraitFx = Dialogue.portrait_fx
		if fx:
			fx.equip_flare(zone, text, float(e.get("shake", 2.0)), fx_kind)
		var lines: Array = e.get("lines", [])
		if not lines.is_empty() and randf() < float(e.get("line_chance", 0.25)):
			GameState.princess_reacted.emit(str(lines.pick_random()), 2.2)
	else:
		who.shake(0.2)
		if text != "" and _bubble_t <= 0.0:
			_bubble_t = BUBBLE_GAP
			SpeechBubble.say(who, text, 28.0, 1.6)
	return text


## 装备用哪种手法特效。
static func fx_of(id: String) -> String:
	for k in WAY_FX:
		for part in WAY_FX[k]:
			if id.contains(part):
				return k
	return "feather"


func _pick_words(e: Dictionary, way: String) -> String:
	if way != "":
		var w: Variant = e.get("ways", {}).get(way, {})
		if w is Dictionary and not (w.get("words", []) as Array).is_empty():
			return str((w["words"] as Array).pick_random())
	var words: Variant = e.get("words", {})
	var stage := who.laugh.stage() if who.laugh else "calm"
	var key := "helpless" if stage.begins_with("helpless") else stage
	if words is Dictionary:
		var arr: Array = words.get(key, words.get("calm", []))
		return str(arr.pick_random()) if not arr.is_empty() else ""
	return str((words as Array).pick_random()) if words is Array and not words.is_empty() else ""


func _source(id: String) -> Node2D:
	if not _src.has(id) or not is_instance_valid(_src[id]):
		var s := HandCover.Source.new()
		s.reaction_key = id
		who.add_child(s)
		_src[id] = s
	return _src[id]

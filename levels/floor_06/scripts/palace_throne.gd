class_name PalaceThrone
extends PalaceRoom
## 第四章⑩·王座间 Boss「封笑的女王画像」（floor_06_palace_throne；台词 penance_text/palace3.py；配乐 palace_boss）：
##   破绽在王座前（weak_point()）：站在 HIT_R 里攻击扣一格。三层画布：
##   第一层（layer 0，LAYER_HP[0]）：颜料泼洒（PaintPool：先出预警圈（danger 组，AI 会躲）再变成颜料坑，踩进去脚底沾颜料 → 画笔追着刷 PAINTED 秒）
##     + 画像小手（离画像太近被抓：定身 + 挠腋窝）；破了 → 过场 throne_layer_1（胡话）→
##   第二层（layer 1）：墙上四幅小画像（SmallPortrait，各 SMALL_HP）醒来、隔一会儿甩出画出来的手（PaintHand 飞过来）；小画像全打掉 → 大画像露出破绽 VULN_TIME 秒
##     （之后小画像又醒过来）；破了 → 过场 throne_layer_2 →
##   第三层（layer 2）：画像把玩家操控的那个人拉进画里（paint_start，旁边 paint_gate 一直挡着）：在画里自己躲开画笔（brushes 巡逻）跑到画框出口（paint_exit）
##     → 出来 → 过场 throne_finale（两人各释放一次、画布烧穿）→ 胜利；
##     失败（闷笑满 / 超过 PAINT_TIME）→ 小剧场 throne_painting_trapped（CG）→ 画框变强（empowered，FRAME_HP、颜料更快），换外面的人操控；
##     把变强的画框打破 → 画里的人出来 → throne_finale → 胜利。
##   胜利：BOSS_FLAG → 过场 palace_end（另半枚徽章、摇篮曲、章末「第四章　旧王宫　完」）。
##   两个都倒下：按在哪一层输播不同的小剧场（都有 CG）：第一层 throne_fail_paint（被涂成画）、第二层 throne_fail_tea（小画像的茶会）、
##     第三层画框变强以后 throne_fail_frame（两个人都被画进画里）、第三层其他时候 throne_fail（画像小手按在王座台阶上）→ 回入口，当前这一层回满。
##   逃出画：小剧场 throne_escape（短）→ throne_finale。
## 第四轮（会动的画像）：
##   大画像：第一层沿北墙左右滑（SLIDE_SPEED，破绽跟着画像走、在画像正下方的王座前）；第二层离开墙面飘起来慢慢追人（FLOAT_SPEED）；
##     第三层飘到场地中央转圈（ORBIT_R）。破绽一直在画像脚下（weak_point()；_weak = WeakMark，金色光圈，AI 的优先目标）。
##   小画像：第二层醒来就从墙上飞下来、飘着追人（保持 SMALL_KEEP 的距离甩手），被打掉 → 飞回墙上睡觉，再醒来重新飞下来。
##   颜料小人（PaintImp，图 paint_imp.png）：第一、二层从颜料坑里冒出来（IMP_EVERY 秒一只，最多 IMP_MAX），追人挠腰，一下就打掉。
##   伸长的手（StretchHand）：每 STRETCH_EVERY 秒对离画像远的人：地上先出预警线（danger 组，AI 会躲）→ 手顺着地面伸过去 →
##     抓到 = status.grab（连按挣扎），拖回破绽前挠腋窝。
##   Boss 血条：GameState.boss_changed.emit(self)（BossBar 读 boss_name() / boss_ratio()）。
##   特效：throne_fx.gd（颜料飞溅、画布碎片、金色笔触、闪屏、画里的水彩滤镜）。
## 测试：layer、hp、vulnerable()、hit(n)、pools、small、pull()、inside、escape()、fail_inside()、empowered、frame_hp、win、
##   imps、spawn_imp(at)、stretch(pc)、portrait_pos()、boss_ratio()、boss_name()。

const MAP := "floor_06_palace_throne"
## 第四章尾声：打完 Boss 两半徽章合在一起（BADGE_FLAG，道具 joined_badge）→ 画前按 E 进画（floor_06_palace_memory）→ 出来以后 EPILOGUE_FLAG
const BADGE_FLAG := "palace_badge_joined"
const EPILOGUE_FLAG := "palace_memory_done"
const MEMORY_OUT := "palace_memory_out_seen"
const CLEAN_TEX := "res://assets/generated/portrait_clean.png"
const BOSS_FLAG := "palace_boss_done"
const LAYER_HP := [20, 18]
const HIT_R := 34.0
const HIT_COOL := 0.35
const PAINT_EVERY := 4.5
const PAINT_EVERY_ANGRY := 2.6
const POOL_WARN := 1.0
const POOL_LIFE := 6.0
const POOL_R := 14.0
const PAINTED := 3.0
const HAND_EVERY := 5.0
const HAND_R := 70.0
const SMALL_HP := 6
const SMALL_SHOT := 3.5
const VULN_TIME := 9.0
const PULL_DELAY := 1.5
const PAINT_TIME := 40.0
const BRUSH_SPEED := 46.0
const FRAME_HP := 18
const SLIDE_SPEED := 26.0
const SLIDE_CELLS := Vector2i(23, 47)          # 第一层沿北墙滑动的 x 范围（格）
const ARENA := Rect2i(18, 14, 35, 22)          # 第二层飘着追人的范围（格）
const FLOAT_SPEED := 15.0
const HOVER := 26.0
const ORBIT_R := 44.0
const ORBIT_SPEED := 0.55
const IMP_EVERY := 6.0
const IMP_MAX := 6
const IMP_HIT_R := 20.0
const STRETCH_EVERY := 6.5
const STRETCH_WARN := 0.9
const STRETCH_SPEED := 230.0
const SMALL_FLY := 30.0
const SMALL_KEEP := 34.0
const SMALL_HIT_R := 38.0                          # 小画像的受击半径（量到它画出来的位置）
const SMALL_STAGGER := 0.8                         # 被打中以后僵住：不退、不甩手，可以连打
## 第五轮加难（throne_parts.gd）：强化画框以后各种技能的间隔 × ANGRY_K
const ANGRY_K := 0.6
const MAZE := Rect2i(70, 8, 29, 41)              # 画中世界的迷宫（离大厅很远，中间全是墙）
const SUCK_EVERY := 11.0                          # 画框吸引
const SUCK_SPEED := 46.0
const SUCK_R := 30.0
const WAVE_EVERY := 15.0                          # 颜料浪潮（第二层起）
const CLONE_EVERY := 17.0                         # 临摹分身（第二层起）
const SOLDIER_EVERY := 12.0                       # 画框小兵（一列三只）
const BRUSHSP_EVERY := 10.0                       # 羽毛画笔精（第二层起）
const BRUSHSP_MAX := 3
const MINION_HIT_R := 22.0
const MONSTER_SCENES := ["res://scenes/actors/monsters/flying_book.tscn", "res://scenes/actors/monsters/ghost_glove.tscn",
		"res://scenes/actors/monsters/dance_doll.tscn"]
const SMALL_REVIVE := 8.0                         # 小画像被打掉以后，没在这么久里全打掉 → 被别的画回来
const DIVE_EVERY := Vector2(6.0, 9.0)
const SMALL_KINDS := ["red", "blue", "gold", "green"]
## 追加事件：女王的八音盒（石像问答的奖励，背包里放在 R 键上）：每场 BOX_USES 次，画像发呆 BOX_TIME 秒、一直露破绽，不泼颜料不伸手
const PORTRAIT_BACK := "palace_portrait_back"
var _frame_view: Node2D
const BOX_TIME := 8.0
const BOX_USES := 2
var box_t := 0.0
var box_used := 0

var layer := 0
var hp := 12
var started := false
var win := false
var pools: Array = []
var painted := {}
var small: Array = []
var vuln_t := 0.0
var inside: PlayableCharacter
var inside_t := 0.0
var empowered := false
var frame_hp := 0
var brushes: Array = []
var _paint_t := 2.0
var _hand_t := HAND_EVERY
var _hit_cool := {}
var _pull_t := -1.0
var _portrait: PortraitView
var _gate: StaticBody2D
var _gib_t := 12.0
var imps: Array = []
var _imp_t := IMP_EVERY * 0.5
var _stretch_t := STRETCH_EVERY
var _slide_dir := 1.0
var _orbit := 0.0
var _weak: WeakMark
var _water: ThroneFx.Watercolor
var _bar_on := false
var minions: Array = []          # 画框小兵 / 画笔精 / 分身（有 hurt()）
var monsters: Array = []         # 从画框里放出来的原有怪物（真正的 Monster）
var slides := {}                 # 踩到蓝框滑颜料的人 → [方向, 剩下的秒]
var world_view: ThroneParts.PaintWorld
var _suck_t := SUCK_EVERY * 0.6
var _wave_t := WAVE_EVERY
var _clone_t := CLONE_EVERY
var _soldier_t := SOLDIER_EVERY * 0.5
var _brushsp_t := BRUSHSP_EVERY
var _vortex: ThroneParts.Vortex
var partner_panel: PartnerPanel
var shield_told := false


func map_id() -> String:
	return MAP


func _ready() -> void:
	super()
	win = GameState.has_flag(BOSS_FLAG)
	_portrait = PortraitView.new()
	_portrait.room = self
	_portrait.position = world(cells("portrait")[0]) + Vector2(0, 8)
	add_view(_portrait)
	_weak = WeakMark.new()
	_weak.room = self
	_weak.set_meta("hit_radius", 10.0)
	_weak.position = weak_point()
	add_view(_weak)
	_gate = StaticBody2D.new()
	_gate.collision_layer = 1
	var sh := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 16)
	sh.shape = r
	_gate.add_child(sh)
	add_child(_gate)
	_gate.global_position = PalaceRoom.cell_pos(cells("paint_gate")[0])
	var i := 0
	for c in cells("small_portraits"):
		var s := SmallPortrait.new()
		s.room = self
		s.idx = i
		s.position = world(c)
		s.home = s.position
		add_view(s)
		small.append(s)
		i += 1
	for c in cells("brushes"):
		var b := Brush.new()
		b.room = self
		b.home = world(c)
		b.position = b.home
		add_view(b)
		brushes.append(b)
	hp = LAYER_HP[0]
	# 追加事件·失窃的小画像：带着「迷路的小画像」进来就挂回空画框；挂回去以后它安安静静地睡着，第二层只剩三幅小画像醒来
	if not cells("empty_frame").is_empty():
		_frame_view = sheet_view(PalaceRoom.PROPS4, 6, 4, cells("empty_frame")[0], [], 0.8)
		if GameState.inventory.has("lost_portrait") and not GameState.has_flag(PORTRAIT_BACK):
			GameState.inventory.remove("lost_portrait", 1)
			GameState.set_flag(PORTRAIT_BACK)
			GameState.notify("把迷路的小画像挂回了空画框——它打了个哈欠，又睡着了")
	if GameState.has_flag(PORTRAIT_BACK) and small.size() >= 4:
		(small[3] as SmallPortrait).calm = true
		if is_instance_valid(_frame_view):
			_frame_view.modulate = Color(1, 1, 1, 0.0)   # 画回到墙上了，画框不再空着
	_ready_epilogue.call_deferred()
	if GameState.inventory.has("queen_music_box") and not win:
		GameState.set_hotkey("use_special", "queen_music_box")
		GameState.notify("「女王的八音盒」放在 R 键上了（每场能用 %d 次）" % BOX_USES)


## 破绽：一直在画像脚下。第一层画像挂在北墙上滑动 → 破绽在它正下方的王座前；飘起来以后就在它影子上
func weak_point() -> Vector2:
	if _portrait == null:
		return world(cells("throne")[0]) + Vector2(0, -6)
	if layer == 0 and not empowered:
		return Vector2(_portrait.position.x, _portrait.position.y + 48.0)   # 挂在北墙上：破绽在它正下方三格
	return _portrait.position + Vector2(0, 14)


func portrait_pos() -> Vector2:
	return _portrait.position


# ------------------------------------------------------------------ Boss 血条（BossBar 鸭子类型）
func boss_name() -> String:
	if empowered:
		return "封笑的女王画像·变强的画框"
	return "封笑的女王画像·第%s层画布" % ["一", "二", "三"][clampi(layer, 0, 2)]


func boss_ratio() -> float:
	if win:
		return 0.0
	if empowered:
		return float(frame_hp) / FRAME_HP
	if layer < 2:
		return float(hp) / float(LAYER_HP[layer])
	if inside:
		return 1.0 - inside_t / PAINT_TIME   # 画里：剩下的时间
	return 1.0


func _bar(on: bool) -> void:
	if on == _bar_on:
		return
	_bar_on = on
	GameState.boss_changed.emit(self if on else null)


func _exit_tree() -> void:
	for m in members():
		(m as PlayableCharacter).roam = false
	if _bar_on:
		GameState.boss_changed.emit(null)
	if is_instance_valid(_water):
		_water.queue_free()
	super()


func vulnerable() -> bool:
	if win or inside != null and not empowered:
		return false
	if box_t > 0.0:
		return true
	if layer == 1:
		return vuln_t > 0.0
	return true


func _process(delta: float) -> void:
	if is_instance_valid(_weak):
		_weak.position = weak_point()
	_tick_water()
	if win:
		_pick_t -= delta
		if _pick_t <= 0.0:
			_pick_t = 1.5
			GameState.vars["palace_portrait_pick"] = randi() % 4
		return
	if busy():
		return
	if not started:
		started = true
		# Boss 战里两个人都不会被「拉回玩家身边」（不然被拉进画里时，外面的搭档会被瞬移进画里）
		for m in members():
			(m as PlayableCharacter).roam = true
		# 右上角另一位公主的状态面板（同千手战 / 骑士战），让开顶上的 Boss 血条
		if partner_panel == null:
			partner_panel = PartnerPanel.new()   # 和右上角的头像并列（同第八层）
			add_child(partner_panel)
		return
	_bar(true)
	_tick_move(delta)
	_tick_imps(delta)
	_tick_minions(delta)
	_tick_hits(delta)
	box_t = maxf(0.0, box_t - delta)
	if box_t <= 0.0:
		_tick_paint(delta)
		_tick_hands(delta)
		_tick_stretch(delta)
		_tick_skills(delta)
	if layer == 1:
		vuln_t = maxf(0.0, vuln_t - delta)
		if vuln_t <= 0.0 and small.all(func(s): return not (s as SmallPortrait).alive()):
			for s in small:
				(s as SmallPortrait).revive()
	if layer == 2:
		if _pull_t > 0.0:
			_pull_t -= delta
			if _pull_t <= 0.0:
				pull()
		if inside and not empowered:
			inside_t += delta
			if is_instance_valid(world_view):
				world_view.step(delta)
			for b in brushes:
				(b as Brush).step(delta)
			if inside.global_position.distance_to(world(cells("paint_exit")[0])) <= 14.0 and (not is_instance_valid(world_view) or world_view.exit_open()):
				escape()
			elif inside_t >= PAINT_TIME or Downed.is_downed(inside) or inside.laugh.value >= inside.laugh.max_value * 0.95:
				fail_inside()
	_gib_t -= delta
	if _gib_t <= 0.0:
		_gib_t = randf_range(10.0, 16.0)
		var gib: Array = (PalaceRoom.data().get("gibberish", [""]) as Array).duplicate()
		if GameState.has_flag(PORTRAIT_BACK):
			gib.append_array(PalaceRoom.data().get("portrait_back_gibberish", []) as Array)   # 挂回小画像以后多几句
		SpeechBubble.say(_portrait, str(gib.pick_random()), 40.0, 2.5)


## 打开八音盒：放出很久以前的笑声，画像发呆露破绽（被拉进画里的时候没用）
func use_music_box() -> bool:
	if win or box_used >= BOX_USES or (inside != null and not empowered):
		GameState.notify("八音盒的发条转不动了……" if box_used >= BOX_USES else "现在打开它没有用……")
		return false
	box_used += 1
	box_t = BOX_TIME
	_clear_pools()
	Audio.play("music_box", -2.0)
	SpeechBubble.say(_portrait, str((PalaceRoom.data().get("box_gibberish", ["……这个声音……"]) as Array).pick_random()), 40.0, 3.0)
	GameState.notify("八音盒响了——画像发起呆来（还能用 %d 次）" % (BOX_USES - box_used))
	return true


# ------------------------------------------------------------------ 打破绽
func _tick_hits(delta: float) -> void:
	for k in _hit_cool.keys():
		_hit_cool[k] = maxf(0.0, float(_hit_cool[k]) - delta)
	for m in members():
		var pc := m as PlayableCharacter
		if pc == inside and not empowered:
			continue
		if pc.state != PlayableCharacter.State.ATTACK and pc.state != PlayableCharacter.State.CAST:
			continue
		var k := pc.get_instance_id()
		if float(_hit_cool.get(k, 0.0)) > 0.0:
			continue
		# 颜料小人：一下就打掉
		for im in imps:
			if is_instance_valid(im) and pc.global_position.distance_to((im as Node2D).position) <= IMP_HIT_R:
				_hit_cool[k] = HIT_COOL * 0.5
				(im as PaintImp).pop()
				break
		if float(_hit_cool.get(k, 0.0)) > 0.0:
			continue
		# 画框小兵 / 画笔精 / 分身
		for mn in minions:
			if is_instance_valid(mn) and pc.global_position.distance_to((mn as Node2D).position) <= MINION_HIT_R:
				_hit_cool[k] = HIT_COOL * 0.6
				mn.call("hurt")
				break
		if float(_hit_cool.get(k, 0.0)) > 0.0:
			continue
		# 小画像
		for s in small:
			var sp := s as SmallPortrait
			if sp.alive() and minf(pc.global_position.distance_to(sp.position), pc.global_position.distance_to(sp.drawn_pos())) <= SMALL_HIT_R:
				_hit_cool[k] = HIT_COOL
				sp.hurt()
				if layer == 1 and small.all(func(x): return not (x as SmallPortrait).alive()):
					vuln_t = VULN_TIME
					PalaceRoom.say_random(pc, "weak")
					release_monsters(2)
				break
		if float(_hit_cool.get(k, 0.0)) > 0.0:
			continue
		if vulnerable() and pc.global_position.distance_to(weak_point()) <= HIT_R:
			_hit_cool[k] = HIT_COOL
			hit(1)


func hit(n: int) -> void:
	ThroneFx.gold(get_parent(), weak_point())
	ThroneFx.splash(get_parent(), weak_point() + Vector2(randf_range(-8, 8), -4), randf() < 0.5, 0.7)
	if empowered:
		frame_hp -= n
		_portrait.flash()
		if frame_hp <= 0:
			_free_inside()
		return
	if layer >= 2:
		return
	hp -= n
	_portrait.flash()
	Audio.play("gate", -6.0, 0.0, 1.5)
	if hp <= 0:
		_break_layer()


func _break_layer() -> void:
	_clear_pools()
	_clear_imps()
	_clear_minions()
	ThroneFx.shards(get_parent(), _portrait.position + Vector2(0, -_portrait.hover), 14)
	ThroneFx.gold(get_parent(), _portrait.position)
	ThroneFx.flash(get_tree(), Color(1, 0.95, 0.9, 0.8), 0.5)
	for m in members():
		(m as PlayableCharacter).shake_camera(0.5, 4.0)
	var id := "throne_layer_%d" % (layer + 1)
	layer += 1
	await Cutscene.play(id)
	while Cutscene.is_playing():
		await get_tree().process_frame
	if layer == 1:
		hp = LAYER_HP[1]
		for s in small:
			(s as SmallPortrait).revive()
		PalaceRoom.say_random(GameState.player, "small_up")
	elif layer == 2:
		for s in small:
			(s as SmallPortrait).sleep()
		_pull_t = PULL_DELAY


# ------------------------------------------------------------------ 颜料 / 画像小手
func _tick_paint(delta: float) -> void:
	_paint_t -= delta
	if _paint_t <= 0.0:
		_paint_t = PAINT_EVERY_ANGRY if empowered else PAINT_EVERY
		for m in members():
			if m == inside and not empowered:
				continue
			spawn_pool((m as Node2D).global_position + Vector2(randf_range(-30, 30), randf_range(-20, 20)))
	for p in pools:
		if not is_instance_valid(p):   # 已经被释放的颜料池：先判断再 cast（cast 已释放的对象会报错）
			continue
		var pool := p as PaintPool
		if not pool.active():
			continue
		for m in members():
			if (m as Node2D).global_position.distance_to(pool.position) <= pool.r:
				if float(painted.get(m, 0.0)) <= 0.0:
					PalaceRoom.say_random(m, "paint")
				painted[m] = PAINTED
	pools = pools.filter(func(p): return is_instance_valid(p))
	for m in painted.keys():
		if not is_instance_valid(m):
			painted.erase(m)
			continue
		painted[m] = float(painted[m]) - delta
		if float(painted[m]) > 0.0:
			tickle(m, "painted", 0.6, 3.0, "sole", delta)


func spawn_pool(at: Vector2) -> PaintPool:
	var p := PaintPool.new()
	p.host = get_parent()
	p.position = at
	p.add_to_group("danger")
	p.set_meta("rect", Rect2(at - Vector2(POOL_R, POOL_R), Vector2(POOL_R, POOL_R) * 2.0))
	add_view(p)
	pools.append(p)
	return p


func _clear_pools() -> void:
	for p in pools:
		if is_instance_valid(p):
			(p as Node).queue_free()
	pools.clear()
	painted.clear()


func _tick_hands(delta: float) -> void:
	_hand_t -= delta
	if _hand_t > 0.0:
		return
	_hand_t = HAND_EVERY
	for m in members():
		var pc := m as PlayableCharacter
		if pc != inside and pc.global_position.distance_to(weak_point()) <= (HAND_R if layer == 0 else HAND_R * 0.6):
			pc.status.apply_root(1.0)
			var h := HitData.make_tickle(self, 6.0)
			h.zone = "armpit"
			pc.receive_hit(h)
			PalaceRoom.say_random(pc, "hand")
			_portrait.reach(pc.global_position)


# ------------------------------------------------------------------ 画像移动
func _tick_move(delta: float) -> void:
	if box_t > 0.0:
		_portrait.hover_to = 0.0 if layer == 0 and not empowered else HOVER * 0.6   # 八音盒：发呆，不动
		return
	var pos := _portrait.position
	if layer == 0 and not empowered:
		# 第一层：挂在北墙上左右滑
		_portrait.hover_to = 0.0
		var x0 := world(Vector2i(SLIDE_CELLS.x, 7)).x
		var x1 := world(Vector2i(SLIDE_CELLS.y, 7)).x
		pos.x += _slide_dir * SLIDE_SPEED * delta
		if pos.x >= x1:
			pos.x = x1
			_slide_dir = -1.0
		elif pos.x <= x0:
			pos.x = x0
			_slide_dir = 1.0
	elif layer == 1:
		# 第二层：离开墙面，慢慢飘过去追人
		_portrait.hover_to = HOVER
		var near := _nearest_member(pos)
		if near:
			pos = pos.move_toward(near.global_position + Vector2(0, -10), FLOAT_SPEED * delta)
	else:
		# 第三层：飘到场地中央转圈
		_portrait.hover_to = HOVER
		_orbit += ORBIT_SPEED * delta
		var c := world(cells("arena")[0])
		pos = pos.move_toward(c + Vector2(cos(_orbit), sin(_orbit) * 0.7) * ORBIT_R, 60.0 * delta)
	var lo := world(ARENA.position)
	var hi := world(ARENA.end)
	if layer >= 1 or empowered:
		pos = pos.clamp(lo, hi)
	_portrait.position = pos


func _nearest_member(from: Vector2) -> PlayableCharacter:
	var best: PlayableCharacter = null
	for m in members():
		var pc := m as PlayableCharacter
		if pc == inside or Downed.is_downed(pc):
			continue
		if best == null or pc.global_position.distance_to(from) < best.global_position.distance_to(from):
			best = pc
	return best


# ------------------------------------------------------------------ 颜料小人
func _tick_imps(delta: float) -> void:
	imps = imps.filter(func(x): return is_instance_valid(x))
	for im in imps:
		(im as PaintImp).step(delta)
	if layer >= 2 or empowered or box_t > 0.0:
		return
	_imp_t -= delta
	if _imp_t > 0.0:
		return
	_imp_t = IMP_EVERY * (0.8 if layer == 1 else 1.0)
	if imps.size() >= IMP_MAX:
		return
	var src: Array = pools.filter(func(p): return is_instance_valid(p) and (p as PaintPool).active())
	if src.is_empty():
		return
	spawn_imp((src.pick_random() as Node2D).position)


func spawn_imp(at: Vector2) -> PaintImp:
	var im := PaintImp.new()
	im.room = self
	im.position = at
	add_view(im)
	imps.append(im)
	ThroneFx.splash(get_parent(), at, randf() < 0.5, 0.6)
	return im


func _clear_imps() -> void:
	for im in imps:
		if is_instance_valid(im):
			(im as Node).queue_free()
	imps.clear()


# ------------------------------------------------------------------ 伸长的手
func _tick_stretch(delta: float) -> void:
	if layer >= 2 and not empowered:
		return
	_stretch_t -= delta
	if _stretch_t > 0.0:
		return
	_stretch_t = STRETCH_EVERY * (0.7 if empowered else 1.0)
	var far: Array = members().filter(func(m): return m != inside and not Downed.is_downed(m as PlayableCharacter) \
			and (m as Node2D).global_position.distance_to(weak_point()) > HAND_R)
	if not far.is_empty():
		stretch(far.pick_random() as PlayableCharacter)


## 对着 pc 现在站的地方伸一只手：先出预警线，再伸过去，抓到就拖回破绽前挠
func stretch(pc: PlayableCharacter) -> StretchHand:
	var h := StretchHand.new()
	h.room = self
	h.position = pc.global_position
	h.from = _portrait.position + Vector2(0, 6)
	add_view(h)
	return h


# ------------------------------------------------------------------ 第五轮：技能 / 小怪 / 原有怪物
func _k() -> float:
	return ANGRY_K if empowered else 1.0


func _tick_skills(delta: float) -> void:
	if layer >= 2 and not empowered:
		return
	# 画框吸引（第一、二层、强化画框）
	_suck_t -= delta
	if _suck_t <= 0.0:
		_suck_t = SUCK_EVERY * _k()
		frame_suck()
	if is_instance_valid(_vortex) and _vortex.active():
		for m in members():
			var pc := m as PlayableCharacter
			if pc == inside or Downed.is_downed(pc):
				continue
			var to := weak_point() - pc.global_position
			if to.length() > SUCK_R:
				ThroneParts.shove(pc, to.normalized() * SUCK_SPEED * delta)
			else:
				tickle(pc, "suck", 0.25, 2.5, "armpit", delta)
	# 画框小兵（一列三只，从墙上的画框里走出来）
	_soldier_t -= delta
	if _soldier_t <= 0.0:
		_soldier_t = SOLDIER_EVERY * _k()
		spawn_soldiers()
	if layer >= 1 or empowered:
		_wave_t -= delta
		if _wave_t <= 0.0:
			_wave_t = WAVE_EVERY * _k()
			paint_wave()
		_clone_t -= delta
		if _clone_t <= 0.0:
			_clone_t = CLONE_EVERY * _k()
			spawn_clones()
		_brushsp_t -= delta
		if _brushsp_t <= 0.0:
			_brushsp_t = BRUSHSP_EVERY * _k()
			if minions.filter(func(x): return is_instance_valid(x) and x is ThroneParts.BrushSprite).size() < BRUSHSP_MAX:
				spawn_brush_sprite()


func _tick_minions(delta: float) -> void:
	minions = minions.filter(func(x): return is_instance_valid(x))
	monsters = monsters.filter(func(x): return is_instance_valid(x) and (not x.has_method("is_alive") or x.is_alive()))
	for mn in minions:
		mn.call("step", delta)
	# 踩到滑颜料：顺着方向滑出去
	for pc in slides.keys():
		if not is_instance_valid(pc):
			slides.erase(pc)
			continue
		var sl: Array = slides[pc]
		sl[1] = float(sl[1]) - delta
		ThroneParts.shove(pc, (sl[0] as Vector2) * 120.0 * delta)
		if float(sl[1]) <= 0.0:
			slides.erase(pc)


## 画框吸引：画像脚下出一个旋涡，预警以后把两个人往破绽拖（冲刺能挣开），拖到跟前连挠腋窝
func frame_suck() -> ThroneParts.Vortex:
	if is_instance_valid(_vortex):
		return _vortex
	_vortex = ThroneParts.Vortex.new()
	_vortex.room = self
	_vortex.position = weak_point()
	add_view(_vortex)
	SpeechBubble.say(_portrait, "……过、来……", 40.0, 1.2)
	return _vortex


## 颜料浪潮：从南墙往北推一整排颜料，留一两个缺口
func paint_wave() -> ThroneParts.PaintWave:
	var w := ThroneParts.PaintWave.new()
	w.room = self
	w.x0 = world(Vector2i(ARENA.position.x, 0)).x
	w.x1 = world(Vector2i(ARENA.end.x, 0)).x
	w.y0 = world(Vector2i(0, ARENA.end.y - 1)).y
	w.y1 = world(Vector2i(0, ARENA.position.y - 4)).y
	var gw := 40.0
	var g1 := randf_range(w.x0 + 20.0, w.x1 - 20.0 - gw)
	w.gaps = [[g1, g1 + gw]]
	if randf() < 0.5:
		var g2 := fposmod(g1 - w.x0 + (w.x1 - w.x0) * 0.5, w.x1 - w.x0 - gw) + w.x0
		w.gaps.append([g2, g2 + gw])
	add_view(w)
	Audio.play("water_release", -4.0, 0.0, 0.8)
	return w


## 临摹分身：每个人（画外的）身边冒出一个颜料做的自己，追着本体挠
func spawn_clones() -> Array:
	var out: Array = []
	for m in members():
		var pc := m as PlayableCharacter
		if pc == inside or Downed.is_downed(pc):
			continue
		var c := ThroneParts.PaintClone.new()
		c.room = self
		c.owner_pc = pc
		c.position = pc.global_position + Vector2.from_angle(randf() * TAU) * 40.0
		add_view(c)
		minions.append(c)
		out.append(c)
	if not out.is_empty():
		SpeechBubble.say(_portrait, "……临、摹……", 40.0, 1.2)
	return out


func spawn_soldiers() -> Array:
	var out: Array = []
	var fc: Vector2i = cells("frames").pick_random() if not cells("frames").is_empty() else cells("arena")[0]
	var start := world(fc) + Vector2(0, 14)
	var dir := (world(cells("arena")[0]) - start).normalized()
	for i in 3:
		var sd := ThroneParts.FrameSoldier.new()
		sd.room = self
		sd.position = start - dir * (i * 14.0)
		sd.delay = i * 0.35
		add_view(sd)
		minions.append(sd)
		out.append(sd)
	ThroneFx.shards(get_parent(), start, 4)
	return out


func spawn_brush_sprite() -> ThroneParts.BrushSprite:
	var b := ThroneParts.BrushSprite.new()
	b.room = self
	b.position = _portrait.position
	add_view(b)
	minions.append(b)
	return b


## 画笔精的颜料轨迹：小一点、马上就是颜料、留得短
func spawn_trail(at: Vector2) -> PaintPool:
	var p := spawn_pool(at)
	p.r = 7.0
	p.t = POOL_WARN
	p.life = 4.0
	p.remove_from_group("danger")
	return p


## 从墙上的画框里放出一小波原有的怪（飞书 / 幽灵手套 / 舞会人偶）
func release_monsters(n: int) -> Array:
	var out: Array = []
	for i in n:
		var path := str(MONSTER_SCENES.pick_random())
		if not ResourceLoader.exists(path):
			continue
		var mo: Node2D = load(path).instantiate()
		get_parent().add_child(mo)
		var fc: Vector2i = cells("frames").pick_random() if not cells("frames").is_empty() else cells("arena")[0]
		mo.global_position = world(fc) + Vector2(randf_range(-10, 10), 16)
		monsters.append(mo)
		out.append(mo)
		ThroneFx.splash(get_parent(), mo.global_position, randf() < 0.5, 0.7)
	if n > 0:
		GameState.notify("墙上的画框里，有东西跑出来了！", 1.5)
	return out


func _clear_minions() -> void:
	for mn in minions + monsters:
		if is_instance_valid(mn):
			(mn as Node).queue_free()
	minions.clear()
	monsters.clear()
	slides.clear()
	if is_instance_valid(_vortex):
		_vortex.queue_free()


## 战败重置前：小画像松手、伸长的手缩回、旋涡 / 滑颜料清掉（不然复活以后人还被抓着，不能动也不能切人）
func _release_all() -> void:
	for s in small:
		(s as SmallPortrait)._release()
	for n in get_parent().get_children():
		if n is StretchHand:
			(n as StretchHand)._end()
	slides.clear()
	painted.clear()
	if is_instance_valid(_vortex):
		_vortex.queue_free()
	for m in members():
		var pc := m as PlayableCharacter
		if pc.status.is_grabbed():
			pc.status.release()


func gold_alive() -> bool:
	return small.any(func(s): return (s as SmallPortrait).kind == "gold" and (s as SmallPortrait).alive())


# ------------------------------------------------------------------ 画中世界
func _build_world() -> void:
	_clear_world()
	world_view = ThroneParts.PaintWorld.new()
	world_view.setup(self)
	add_view(world_view)
	var mi := ThroneParts.MirrorSelf.new()
	mi.room = self
	mi.position = world(cells("mirror_start")[0]) if not cells("mirror_start").is_empty() else world(cells("paint_start")[0])
	add_view(mi)
	world_view.mirror = mi


func _clear_world() -> void:
	if is_instance_valid(world_view):
		world_view.queue_free()
	world_view = null


# ------------------------------------------------------------------ 画里的水彩滤镜（只在操控的人被拉进画里时）
func _tick_water() -> void:
	var on := inside != null and not empowered and GameState.player == inside and not win
	if on and not is_instance_valid(_water):
		_water = ThroneFx.Watercolor.new()
		get_tree().root.add_child(_water)
	elif not on and is_instance_valid(_water):
		_water.queue_free()
		_water = null


# ------------------------------------------------------------------ 拉进画里
func pull() -> void:
	var p := GameState.player as PlayableCharacter
	if not is_instance_valid(p) or inside:
		return
	inside = p
	inside_t = 0.0
	PalaceRoom.say_random(p, "pulled")
	ThroneFx.flash(get_tree(), Color(1, 0.75, 0.9, 0.85), 0.6)
	ThroneFx.splash(get_parent(), p.global_position, false, 1.4)
	Fx.burst(get_parent(), p.global_position + Vector2(0, -10), "dust", 16, 50.0, 0.6, Vector2(0, -10), Color(0.9, 0.6, 0.9))
	p.global_position = world(cells("paint_start")[0])
	if p.get("camera"):
		p.camera.reset_smoothing()
	var other := Duo.partner_of(p) if Duo.active else null
	if other:
		other.status.apply_root(0.5)
	PalaceRoom.say_random(p, "inside")
	_build_world()


func escape() -> void:
	var p := inside
	inside = null
	_clear_world()
	if is_instance_valid(p):
		p.global_position = weak_point() + Vector2(-20, 50)
		if p.get("camera"):
			p.camera.reset_smoothing()
		PalaceRoom.say_random(p, "escape")
	await CG.play_theater("throne_escape")
	await _finale()


func fail_inside() -> void:
	if empowered or _defeat_busy:
		return
	_defeat_busy = true
	if Downed.is_downed(inside):
		(inside.get_node("Downed") as Downed).revive_now()
	await CG.play_theater("throne_painting_trapped")
	empowered = true
	frame_hp = FRAME_HP
	_clear_world()
	release_monsters(3)
	inside.status.apply_root(999.0)
	inside.modulate.a = 0.4
	var other := Duo.partner_of(inside) if Duo.active else null
	if other and GameState.player != other:
		GameState.switch_control(other)
	_defeat_busy = false


func _free_inside() -> void:
	empowered = false
	var p := inside
	inside = null
	if is_instance_valid(p):
		p.status.clear_root()
		p.modulate.a = 1.0
		p.laugh.set_value(0.0)
		p.global_position = weak_point() + Vector2(20, 50)
	await _finale()


func _finale() -> void:
	if is_instance_valid(partner_panel):
		partner_panel.queue_free()
	_clear_pools()
	_clear_imps()
	_clear_minions()
	_clear_world()
	_bar(false)
	ThroneFx.shards(get_parent(), _portrait.position + Vector2(0, -_portrait.hover), 20)
	ThroneFx.flash(get_tree(), Color(1, 0.9, 0.95, 0.9), 0.8)
	win = true
	_portrait.burned = true
	await Cutscene.play("throne_finale")
	while Cutscene.is_playing():
		await get_tree().process_frame
	GameState.set_flag(BOSS_FLAG)
	await PalaceRoom.try_memory()   # 徽记台已经换过发饰：先看女王的回忆
	while Cutscene.is_playing():
		await get_tree().process_frame
	Cutscene.play("palace_end")
	while Cutscene.is_playing():
		await get_tree().process_frame
	give_joined_badge()
	_ready_epilogue()


# ------------------------------------------------------------------ 战败
func defeat_theater() -> String:
	if layer == 0:
		return "throne_fail_paint"
	if layer == 1:
		return "throne_fail_tea"
	return "throne_fail_frame" if empowered else "throne_fail"


func on_defeat(reason: String) -> void:
	if _defeat_busy:
		return
	_defeat_busy = true
	await CG.play_theater(defeat_theater())
	_clear_pools()
	_clear_imps()
	_clear_minions()
	_clear_world()
	_release_all()
	if inside:
		inside.status.clear_root()
		inside.modulate.a = 1.0
		inside = null
	empowered = false
	if layer < 2:
		hp = LAYER_HP[layer]
	else:
		_pull_t = PULL_DELAY
	reset_to(world(cells("start")[0]) + Vector2(0, -24))
	_defeat_busy = false


func ai_hooks() -> BattleAIHooks:
	return ThroneHooks.new(self)


# ------------------------------------------------------------------ 第四章尾声
var portrait_spot: Node2D
var _pick_t := 0.0


## 打完以后：画像留在原地（进画前：烧穿的样子；出来以后：干干净净、闭着眼睛）；画前一个调查点；搭档可以聊天
func give_joined_badge() -> void:
	if GameState.has_flag(BADGE_FLAG):
		return
	GameState.set_flag(BADGE_FLAG)
	var it := ItemDB.get_item("joined_badge")
	if it:
		GameState.give_item(it, 1)
	for m in members():
		(m as PlayableCharacter).add_buff("badge_glow", -1.0)
	GameState.notify("得到「合在一起的两半徽章」（带着它：移动快一点、闷笑消得快一点）")


func _ready_epilogue() -> void:
	if not win or is_instance_valid(portrait_spot):
		return
	_refresh_portrait()
	portrait_spot = PrisonOddities.Spot.new()
	portrait_spot.dialogue = "floor_06/throne_portrait_after" if GameState.has_flag(EPILOGUE_FLAG) else "floor_06/throne_portrait_enter"
	add_child(portrait_spot)
	portrait_spot.prompt_y = -30.0
	portrait_spot.global_position = world(cells("portrait")[0] + Vector2i(0, 2))
	for m in members():
		var pc := m as PlayableCharacter
		pc.partner_talk = PalaceAnte.HINT_FILE
		pc.roam = true
		pc.refresh_partner_area()
		pc.hint_partner_area()
	# 从画里出来：先演尾声（画像闭着眼睛 → 章末）
	if GameState.has_flag(EPILOGUE_FLAG) and not GameState.has_flag(MEMORY_OUT):
		GameState.set_flag(MEMORY_OUT)
		await get_tree().process_frame
		Cutscene.play("palace_memory_out")


func _refresh_portrait() -> void:
	if not is_instance_valid(_portrait):
		return
	_portrait.burned = true
	_portrait.position = world(cells("portrait")[0]) + Vector2(0, 8)
	_portrait.hover_to = 0.0
	if GameState.has_flag(EPILOGUE_FLAG) and ResourceLoader.exists(CLEAN_TEX):
		_portrait.clean = true


## 进画（对话 call palace_memory_enter）：被吸进去的过场 → 画里的记忆
func enter_memory() -> void:
	await Cutscene.play("palace_memory_enter")
	while Cutscene.is_playing():
		await get_tree().process_frame
	GameState.pending_spawn = ""
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("change_level"):
		main.change_level(Floors.scene(PalaceMemory.MAP))


class ThroneHooks extends BattleAIHooks:
	var r: PalaceThrone

	func _init(room: PalaceThrone) -> void:
		r = room

	## 小画像醒着 → 打最近的一幅；露破绽 → 打破绽（WeakMark 跟着画像走）
	func priority_target() -> Variant:
		if r.layer == 1 and not r.vulnerable():
			var best: Node2D = null
			var lead := GameState.player
			for s in r.small:
				var sp := s as SmallPortrait
				if sp.alive() and (best == null or (is_instance_valid(lead) and sp.position.distance_to(lead.global_position) < best.position.distance_to(lead.global_position))):
					best = sp
			if best:
				return best
		if r.vulnerable() and is_instance_valid(r._weak):
			return r._weak
		return null

	## 颜料小人 / 画框小兵 / 画笔精 / 分身不是 Actor：这里交给 AI（离得近的先打掉；追着自己的分身最优先）
	func nearest_enemy(ai: PlayableCharacter, rad: float) -> Variant:
		var best: Node2D = null
		var bd := minf(rad, 70.0)
		for mn in r.minions:
			if is_instance_valid(mn) and mn is ThroneParts.PaintClone and (mn as ThroneParts.PaintClone).owner_pc == ai:
				return mn
		for im in r.imps + r.minions:
			if is_instance_valid(im):
				var d := (im as Node2D).position.distance_to(ai.global_position)
				if d < bd:
					bd = d
					best = im
		return best

	## 有人被拉进画里的时候：外面的那个不跟着玩家跑（会卡在隐藏通道口）——没东西打就守在破绽前
	func objective_for(ai: PlayableCharacter) -> Variant:
		if r.inside == null or ai == r.inside:
			return null
		if priority_target() != null or nearest_enemy(ai, 150.0) != null:
			return null
		return r.weak_point() + Vector2(0, 30)

	## 画里的那个人不算搭档（不去救、不去跟）
	func partner_of(ai: PlayableCharacter) -> PlayableCharacter:
		var o := Duo.partner_of(ai)
		return null if o == r.inside else o


# ------------------------------------------------------------------ 画面
class PortraitView extends Node2D:
	const SHEET := "res://assets/generated/portrait_boss.png"
	var room: PalaceThrone
	var burned := false
	var _flash := 0.0
	var _reach := 0.0
	var _reach_to := Vector2.ZERO
	var _spr: Sprite2D
	var hover := 0.0
	var hover_to := 0.0
	var clean := false
	var _t := 0.0
	var _drip := 0.6

	func _ready() -> void:
		z_index = 1   # 画在北墙前面
		if ResourceLoader.exists(SHEET):
			_spr = Sprite2D.new()
			_spr.texture = load(SHEET)
			_spr.hframes = 3
			_spr.offset = Vector2(0, -40)
			add_child(_spr)

	func flash() -> void:
		_flash = 0.15

	func reach(to: Vector2) -> void:
		_reach = 0.6
		_reach_to = to - position

	func _process(d: float) -> void:
		_flash = maxf(0.0, _flash - d)
		_reach = maxf(0.0, _reach - d)
		_t += d
		hover = move_toward(hover, hover_to, 30.0 * d)
		if _spr:
			_spr.offset = Vector2(0, -40 - hover + (sin(_t * 2.0) * 2.5 if hover > 1.0 else 0.0))
		# 飘起来以后一路往下滴颜料
		if hover > 4.0 and room and not room.win and not burned:
			_drip -= d
			if _drip <= 0.0:
				_drip = randf_range(0.25, 0.5)
				Fx.burst(get_parent(), position + Vector2(randf_range(-14, 14), -hover - 8), "drop", 2, 10.0, 0.6, Vector2(0, 60), Color.from_hsv(randf(), 0.5, 1.0))
		if _spr and clean and _spr.hframes != 1:
			_spr.texture = load(PalaceThrone.CLEAN_TEX)
			_spr.hframes = 1
		if _spr and clean:
			_spr.frame = 0
		elif _spr:
			_spr.frame = 2 if burned else (1 if room and (room.layer >= 1 or room.empowered) else 0)
			_spr.modulate = Color(1.6, 1.3, 1.6) if _flash > 0.0 else (Color(1.2, 0.9, 1.3) if room and room.empowered else Color.WHITE)
		queue_redraw()

	func _draw() -> void:
		if hover > 1.0:
			# 飘起来时地上的影子（越高越小越淡）
			draw_set_transform(Vector2(0, 2), 0.0, Vector2(1, 0.4))
			draw_circle(Vector2.ZERO, 22.0 - hover * 0.2, Color(0.15, 0.05, 0.15, 0.35))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if room and room.empowered:
			# 变强的画框：一圈不安的紫光
			draw_arc(Vector2(0, -40 - hover), 36.0 + sin(_t * 6.0) * 3.0, 0, TAU, 32, Color(0.85, 0.4, 1.0, 0.5), 3.0)
		if not _spr:
			var r := Rect2(-22, -80, 44, 60)
			draw_rect(r.grow(4), Color(0.8, 0.62, 0.25))
			draw_rect(r, Color(0.55, 0.3, 0.4) if _flash <= 0.0 else Color(1, 0.8, 0.9))
			draw_circle(Vector2(0, -62), 9.0, Color(0.85, 0.78, 0.75))
			draw_rect(Rect2(-12, -52, 24, 28), Color(0.8, 0.4, 0.5))
			if burned:
				draw_circle(Vector2(0, -50), 12.0, Color(0.1, 0.05, 0.08))
				draw_arc(Vector2(0, -50), 12.0, 0, TAU, 20, Color(1, 0.8, 0.3), 2.0)
		if _reach > 0.0:
			draw_line(Vector2(0, -40 - hover), _reach_to, Color(0.9, 0.6, 0.8, 0.8), 3.0)
			draw_circle(_reach_to, 4.0, Color(0.95, 0.85, 0.8))
		if room and not room.win:
			var total: int = PalaceThrone.FRAME_HP if room.empowered else (PalaceThrone.LAYER_HP[room.layer] if room.layer < 2 else 1)
			var cur: int = room.frame_hp if room.empowered else (room.hp if room.layer < 2 else 1)
			for i in total:
				draw_rect(Rect2(-total * 2.5 + i * 5, -4, 4, 3), Color(0.95, 0.3, 0.45) if i < cur else Color(0.3, 0.2, 0.25))


class SmallPortrait extends Node2D:
	const SHEET := "res://assets/generated/small_portraits4.png"   # 红 / 蓝 / 金 / 绿，各「睡着 + 醒着」两帧
	const DIVE_WARN := 0.8
	const FRAME_TIME := 2.0
	var room: PalaceThrone
	var idx := 0
	var kind := "red"        # red 连甩三只手 / blue 留滑颜料 / gold 给别的加护盾 / green 召唤颜料小人
	var hp := 0
	var home := Vector2.ZERO
	var revive_t := 0.0      # 被打掉以后倒数；到 0 时别的小画像还醒着 → 把它画回来
	var held: PlayableCharacter
	var _lift := 0.0
	var _shot := 0.0
	var _special := 0.0
	var _dive := 0.0
	var _dive_phase := ""    # "" / warn / swoop / hold
	var _dive_at := Vector2.ZERO
	var _dive_t := 0.0
	var _tick := 0.0
	var _spr: Sprite2D
	var _shield: Sprite2D
	var _t := 0.0

	## 挂回来的那幅（失窃的小画像）：一直睡着，不参战
	var calm := false

	func alive() -> bool:
		return hp > 0

	func _ready() -> void:
		kind = str(PalaceThrone.SMALL_KINDS[idx % 4])
		_shot = PalaceThrone.SMALL_SHOT * (0.5 + idx * 0.25)
		_special = 2.0 + idx
		_dive = randf_range(PalaceThrone.DIVE_EVERY.x, PalaceThrone.DIVE_EVERY.y)
		if ResourceLoader.exists(SHEET):
			_spr = Sprite2D.new()
			_spr.texture = load(SHEET)
			_spr.hframes = 8
			_spr.offset = Vector2(0, -22)
			_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_spr)
		_shield = ThroneParts.fx_sprite(5, 0.6)
		_shield.offset = Vector2(0, -36)
		_shield.visible = false
		add_child(_shield)

	func revive(amount := -1) -> void:
		if calm:
			return
		var was := alive()
		hp = PalaceThrone.SMALL_HP if amount < 0 else amount
		revive_t = 0.0
		if not was and room:
			# 被「画回来」：一圈金色的描线
			ThroneFx.gold(room.get_parent(), position + Vector2(0, -_lift))

	func sleep() -> void:
		hp = 0
		revive_t = 0.0
		_release()

	func shielded() -> bool:
		return kind != "gold" and room != null and room.gold_alive()

	## 画出来的位置（飘起来的高度换成逻辑坐标里往北一点）
	func drawn_pos() -> Vector2:
		return position + Vector2(0, -_lift * 0.5)

	var stagger := 0.0

	func hurt() -> void:
		stagger = PalaceThrone.SMALL_STAGGER
		if shielded():
			Audio.play("chime", -8.0, 0.0, 2.0)
			ThroneFx.gold(get_parent(), position + Vector2(0, -20 - _lift))
			if room and not room.shield_told:
				room.shield_told = true
				GameState.notify("金色的光罩着它——先打金色的那幅！", 2.0)
				PalaceRoom.say_random(room._nearest_member(position), "weak")
			return
		hp -= 1
		Audio.play("gate", -8.0, 0.0, 1.9)
		ThroneFx.splash(get_parent(), position + Vector2(0, -_lift), kind == "blue", 0.5)
		modulate = Color(1.8, 1.6, 1.8)
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)
		_release()   # 抓着人的时候被打 → 松手
		if hp <= 0:
			revive_t = PalaceThrone.SMALL_REVIVE
			ThroneFx.shards(get_parent(), position + Vector2(0, 10 - _lift), 5)
			Fx.burst(get_parent(), position + Vector2(0, -20 - _lift), "dust", 10, 40.0, 0.5, Vector2(0, -8), Color(0.9, 0.7, 0.4))

	func _release() -> void:
		if is_instance_valid(held) and held.status.is_grabbed_by(self):
			held.status.release()
		held = null
		if _dive_phase == "hold" or _dive_phase == "swoop":
			_dive_phase = ""

	func _nearest() -> PlayableCharacter:
		return room._nearest_member(position) if room else null

	func _process(d: float) -> void:
		_t += d
		if _spr:
			_spr.frame = idx % 4 * 2 + (1 if alive() else 0)
			_spr.modulate.a = 1.0 if alive() or room == null or room.layer != 1 else 0.45
			_spr.offset = Vector2(0, -22 - _lift + (sin(_t * 3.0 + idx) * 2.0 if _lift > 1.0 else 0.0))
		if _shield:
			_shield.visible = alive() and shielded()
			_shield.offset = Vector2(0, (-36 - _lift) / 0.6)
		queue_redraw()
		if room == null or room.busy() or room.win:
			return
		# 被打掉：飞回墙上；过 SMALL_REVIVE 秒，别的还醒着就被画回来（半血）
		if not alive():
			position = position.move_toward(home, 70.0 * d)
			_lift = move_toward(_lift, 0.0, 40.0 * d)
			if revive_t > 0.0 and room.layer == 1:
				revive_t -= d
				if revive_t <= 0.0 and room.small.any(func(x): return x != self and (x as SmallPortrait).alive()):
					revive(PalaceThrone.SMALL_HP / 2)
					SpeechBubble.say(self, "……画、回来了……", 30.0, 1.0)
			return
		_tick_dive(d)
		if _dive_phase != "":
			return
		# 被打中：僵住一下（不退、不甩手）
		if stagger > 0.0:
			stagger -= d
			return
		_lift = move_toward(_lift, 18.0, 30.0 * d)
		var tgt := _nearest()
		if tgt:
			var dist := tgt.global_position.distance_to(position)
			var dir := (tgt.global_position - position).normalized()
			if dist > PalaceThrone.SMALL_KEEP + 10.0:
				position += dir * PalaceThrone.SMALL_FLY * d
			elif dist < PalaceThrone.SMALL_KEEP - 14.0:
				position -= dir * PalaceThrone.SMALL_FLY * 0.6 * d
			else:
				position += dir.orthogonal() * sin(_t * 0.8 + idx) * PalaceThrone.SMALL_FLY * 0.5 * d
			position = position.clamp(room.world(PalaceThrone.ARENA.position) - Vector2(16, 16), room.world(PalaceThrone.ARENA.end) + Vector2(16, 16))
		# 甩手（红框连甩三只）
		_shot -= d
		if _shot <= 0.0:
			_shot = PalaceThrone.SMALL_SHOT
			if tgt:
				var base := (tgt.global_position - position).angle()
				for a in ([-0.35, 0.0, 0.35] if kind == "red" else [0.0]):
					var h := PaintHand.new()
					h.room = room
					h.position = position + Vector2(0, -6)
					h.vel = Vector2.from_angle(base + a) * 90.0
					room.add_view(h)
		# 各自的专长
		_special -= d
		if _special <= 0.0:
			match kind:
				"blue":
					_special = 0.5
					var sl := ThroneParts.SlipPaint.new()
					sl.room = room
					sl.position = position + Vector2(0, 4)
					room.add_view(sl)
				"green":
					_special = 6.0
					if room.imps.size() < PalaceThrone.IMP_MAX:
						room.spawn_imp(position + Vector2(randf_range(-10, 10), 10))
				_:
					_special = 99.0

	## 俯冲抓人：地上先出预警圈 → 俯冲下去 → 碰到的人被「框」住 FRAME_TIME 秒挠痒（搭档打它能救）
	func _tick_dive(d: float) -> void:
		match _dive_phase:
			"":
				_dive -= d
				if _dive <= 0.0:
					_dive = randf_range(PalaceThrone.DIVE_EVERY.x, PalaceThrone.DIVE_EVERY.y)
					var tgt := _nearest()
					if tgt:
						_dive_at = tgt.global_position
						_dive_phase = "warn"
						_dive_t = DIVE_WARN
						var mk := ThroneParts.DiveMark.new()
						mk.position = _dive_at
						mk.life = DIVE_WARN
						room.add_view(mk)
			"warn":
				_dive_t -= d
				if _dive_t <= 0.0:
					_dive_phase = "swoop"
					_dive_t = 0.3
			"swoop":
				position = position.move_toward(_dive_at, 260.0 * d)
				_lift = move_toward(_lift, 0.0, 120.0 * d)
				_dive_t -= d
				if _dive_t <= 0.0:
					_dive_phase = ""
					for m in room.members():
						var pc := m as PlayableCharacter
						if pc != room.inside and not Downed.is_downed(pc) and pc.global_position.distance_to(position) <= 16.0:
							if pc.status.grab(self, FRAME_TIME, 8):
								held = pc
								_dive_phase = "hold"
								_dive_t = FRAME_TIME
								_tick = 0.0
								Audio.play("grab", -4.0)
								ThroneFx.gold(room.get_parent(), pc.global_position)
								PalaceRoom.say_random(pc, "framed")
							break
			"hold":
				_dive_t -= d
				if not is_instance_valid(held) or not held.status.is_grabbed_by(self) or _dive_t <= 0.0:
					_release()
					_dive_phase = ""
					return
				position = held.global_position + Vector2(0, -2)
				_tick -= d
				if _tick <= 0.0:
					_tick = 0.3
					var h := HitData.make_tickle(self, 2.5)
					h.zone = "waist"
					held.receive_hit(h)

	func _draw() -> void:
		if _lift > 1.0:
			draw_set_transform(Vector2(0, 2), 0.0, Vector2(1, 0.4))
			draw_circle(Vector2.ZERO, 9.0, Color(0.15, 0.05, 0.15, 0.3))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 框住人的时候：一圈金框
		if _dive_phase == "hold":
			draw_rect(Rect2(-13, -34, 26, 36), Color(1, 0.85, 0.35, 0.85), false, 2.0)
		# 俯冲时拖一道残影
		if _dive_phase == "swoop":
			draw_line(Vector2(0, -10), Vector2(0, -46), Color(1, 0.8, 0.5, 0.5), 3.0)
		# 醒着的时候脚下一条小血条
		if alive():
			var w := 20.0
			draw_rect(Rect2(-w * 0.5 - 1, 5, w + 2, 4), Color(0.1, 0.05, 0.1, 0.8))
			draw_rect(Rect2(-w * 0.5, 6, w * float(hp) / PalaceThrone.SMALL_HP, 2), Color(0.95, 0.35, 0.5))
		elif revive_t > 0.0 and room and room.layer == 1:
			# 正在被「画回来」：一圈慢慢画满的描线
			draw_arc(Vector2(0, -22), 12.0, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - revive_t / PalaceThrone.SMALL_REVIVE), 24, Color(1, 0.85, 0.4, 0.8), 1.5)


## 小画像甩出来的「画出来的手」
class PaintHand extends Node2D:
	var room: PalaceThrone
	var vel := Vector2.ZERO
	var life := 2.5

	func _process(d: float) -> void:
		if room == null or room.busy():
			return
		life -= d
		position += vel * d
		queue_redraw()
		for m in room.members():
			var pc := m as PlayableCharacter
			if pc != room.inside and pc.global_position.distance_to(position) <= 10.0:
				pc.status.apply_root(0.5)
				var h := HitData.make_tickle(self, 5.0)
				h.zone = "waist"
				pc.receive_hit(h)
				queue_free()
				return
		if life <= 0.0:
			queue_free()

	func _draw() -> void:
		CurseHand.draw_hand(self, Vector2(0, -8), 0.5, Color(0.95, 0.75, 0.9), Color(0.7, 0.4, 0.6), 0.9, sin(life * 10.0), vel.angle())


## 颜料坑：先出预警圈，再变成一滩颜料
class PaintPool extends Node2D:
	var t := 0.0
	var r := PalaceThrone.POOL_R
	var life := PalaceThrone.POOL_LIFE
	var col := Color.from_hsv(randf(), 0.55, 1.0)
	var host: Node
	var _landed := false

	func active() -> bool:
		return t >= PalaceThrone.POOL_WARN

	func _process(d: float) -> void:
		t += d
		if active() and not _landed:
			_landed = true
			ThroneFx.splash(host if host else get_parent(), position, col.h > 0.45 and col.h < 0.75, 0.8)
		if t >= PalaceThrone.POOL_WARN + life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if not active():
			draw_arc(Vector2.ZERO, r, 0, TAU, 20, Color(col, 0.8), 1.5)
			return
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.6))
		draw_circle(Vector2.ZERO, r, Color(col, 0.75))
		draw_circle(Vector2(r * 0.4, -r * 0.2), r * 0.35, Color(col.lightened(0.3), 0.8))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 画里巡逻的画笔：在出生点附近来回，离得近就追；碰到 = 闷笑涨 + 弹开
class Brush extends Node2D:
	var room: PalaceThrone
	var home := Vector2.ZERO
	var _t := 0.0
	var _cool := 0.0

	func step(d: float) -> void:
		_t += d
		_cool = maxf(0.0, _cool - d)
		var p := room.inside
		var target := home + Vector2(sin(_t * 1.3) * 40.0, 0)
		var rush := is_instance_valid(room.world_view) and room.world_view.seen_t > 0.0
		if is_instance_valid(p) and (rush or p.global_position.distance_to(position) < 70.0):
			target = p.global_position
		position = position.move_toward(target, PalaceThrone.BRUSH_SPEED * (2.0 if rush else 1.0) * d)
		queue_redraw()
		if is_instance_valid(p) and _cool <= 0.0 and p.global_position.distance_to(position) <= 10.0:
			_cool = 1.0
			var h := HitData.make_tickle(self, 7.0)
			h.zone = "waist"
			p.receive_hit(h)
			p.global_position += (p.global_position - position).normalized() * 14.0

	func _draw() -> void:
		var a := sin(_t * 5.0) * 0.4
		draw_line(Vector2(0, -6), Vector2(0, -26).rotated(a), Color(0.55, 0.38, 0.2), 2.0)
		draw_circle(Vector2(0, -6), 3.5, Color.from_hsv(fposmod(_t * 0.2, 1.0), 0.6, 1.0))


## 破绽的位置（跟着画像走）：露破绽时一圈金光（AI 的优先目标）
class WeakMark extends Node2D:
	var room: PalaceThrone
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		if room == null or room.win or not room.vulnerable():
			return
		var a := 0.55 + sin(_t * 6.0) * 0.25
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
		draw_arc(Vector2.ZERO, 16.0 + sin(_t * 4.0) * 2.0, 0, TAU, 28, Color(1, 0.85, 0.35, a), 2.0)
		draw_arc(Vector2.ZERO, 10.0, _t * 2.0, _t * 2.0 + PI, 14, Color(1, 0.95, 0.7, a), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 3:
			var ang := _t * 1.5 + i * TAU / 3.0
			var p := Vector2(cos(ang) * 14.0, sin(ang) * 7.0 - 6.0 - fposmod(_t * 10.0 + i * 4.0, 12.0))
			draw_circle(p, 1.2, Color(1, 0.95, 0.6, a))


## 颜料小人：从颜料坑里冒出来，摇摇摆摆追最近的人，碰到就挥小刷子挠腰；一下就打掉（碎成一滩颜料）
class PaintImp extends Node2D:
	const SHEET := "res://assets/generated/paint_imp.png"
	const SPEED := 30.0
	const REACH := 12.0
	var room: PalaceThrone
	var _t := 0.0
	var _cool := 0.8
	var _swing := 0.0
	var _rise := 0.4
	var _spr: Sprite2D

	func _ready() -> void:
		z_index = 1
		if ResourceLoader.exists(SHEET):
			_spr = Sprite2D.new()
			_spr.texture = load(SHEET)
			_spr.hframes = 4
			_spr.offset = Vector2(0, -11)
			_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_spr)

	func step(d: float) -> void:
		_t += d
		_cool = maxf(0.0, _cool - d)
		_swing = maxf(0.0, _swing - d)
		if _rise > 0.0:
			_rise -= d
			if _spr:
				_spr.scale = Vector2(1.0, 1.0 - _rise * 2.0).clamp(Vector2(0.2, 0.2), Vector2.ONE)
			return
		var near: PlayableCharacter = room._nearest_member(position)
		if near == null:
			return
		var to := near.global_position - position
		if to.length() > REACH:
			position += to.normalized() * SPEED * d
		elif _cool <= 0.0:
			_cool = 1.4
			_swing = 0.35
			var h := HitData.make_tickle(self, 3.0)
			h.zone = "waist"
			near.receive_hit(h)
			PalaceRoom.say_random(near, "imp")
		if _spr:
			_spr.frame = 3 if _swing > 0.0 else int(_t * 6.0) % 3
			_spr.flip_h = to.x < 0.0
			_spr.scale = Vector2(1.0 + sin(_t * 12.0) * 0.05, 1.0 - sin(_t * 12.0) * 0.05)

	func pop() -> void:
		Audio.play("bubble_pop", -4.0)
		ThroneFx.splash(get_parent(), position, randf() < 0.5, 0.7)
		queue_free()

	func _draw() -> void:
		if _spr == null:
			draw_circle(Vector2(0, -8), 7.0, Color(1, 0.5, 0.7))


## 伸长的手：地上先出一道预警线（danger 组：AI 会躲），然后手顺着地面伸过去；
## 抓到人 = status.grab（连按挣扎），一路拖回破绽前、挠腋窝，挣开 / 时间到就松手缩回去
class StretchHand extends Node2D:
	const TEX := "res://assets/generated/paint_fx.png"
	const DRAG_SPEED := 70.0
	const HOLD := 3.0
	var room: PalaceThrone
	var from := Vector2.ZERO        # 画像的位置（世界坐标）
	var phase := "warn"             # warn / reach / drag / back
	var victim: PlayableCharacter
	var _t := 0.0
	var _tip := 0.0                 # 0 = 在画像那里，1 = 伸到目标点
	var _tick := 0.0
	var _spr: Sprite2D

	func _ready() -> void:
		z_index = 2
		add_to_group("danger")
		set_meta("radius", 16.0)
		if ResourceLoader.exists(TEX):
			_spr = Sprite2D.new()
			_spr.texture = load(TEX)
			_spr.hframes = 6
			_spr.frame = 5
			_spr.scale = Vector2(0.5, 0.5)
			_spr.visible = false
			_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(_spr)
		Audio.play("paper", -6.0, 0.0, 0.7)

	func tip_pos() -> Vector2:
		if phase == "drag" and is_instance_valid(victim):
			return victim.global_position
		return from.lerp(position, _tip)

	func _process(d: float) -> void:
		if room == null or room.win:
			_end()
			return
		if room.busy():
			return
		_t += d
		queue_redraw()
		match phase:
			"warn":
				if _t >= PalaceThrone.STRETCH_WARN:
					phase = "reach"
					remove_from_group("danger")
			"reach":
				_tip = minf(1.0, _tip + PalaceThrone.STRETCH_SPEED * d / maxf(1.0, from.distance_to(position)))
				var tp := tip_pos()
				for m in room.members():
					var pc := m as PlayableCharacter
					if pc != room.inside and not Downed.is_downed(pc) and pc.global_position.distance_to(tp) <= 14.0:
						if pc.status.grab(self, HOLD, 8):
							victim = pc
							phase = "drag"
							_t = 0.0
							Audio.play("grab", -4.0)
							PalaceRoom.say_random(pc, "stretch")
							ThroneFx.splash(get_parent(), tp, false, 0.6)
						break
				if phase == "reach" and _tip >= 1.0:
					phase = "back"
			"drag":
				if not is_instance_valid(victim) or not victim.status.is_grabbed_by(self):
					phase = "back"
					_tip = 1.0
					position = victim.global_position if is_instance_valid(victim) else position
					victim = null
					return
				var dest := room.weak_point() + Vector2(0, 12)
				victim.global_position = victim.global_position.move_toward(dest, DRAG_SPEED * d)
				_tick -= d
				if _tick <= 0.0:
					_tick = 0.3
					var h := HitData.make_tickle(self, 2.5)
					h.zone = "armpit"
					victim.receive_hit(h)
			"back":
				_tip = maxf(0.0, _tip - 4.0 * d)
				if _tip <= 0.0:
					_end()

	func _end() -> void:
		if is_instance_valid(victim) and victim.status.is_grabbed_by(self):
			victim.status.release()
		queue_free()

	func _draw() -> void:
		var o := from - position
		if phase == "warn":
			# 预警线：从画像到目标点的一道虚线，目标点一个闪烁的圈
			var a := 0.4 + 0.4 * absf(sin(_t * 12.0))
			var n := 12
			for i in n:
				if i % 2 == 0:
					draw_line(o.lerp(Vector2.ZERO, float(i) / n), o.lerp(Vector2.ZERO, float(i + 1) / n), Color(1, 0.35, 0.55, a), 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
			draw_arc(Vector2.ZERO, 14.0, 0, TAU, 20, Color(1, 0.35, 0.55, a), 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if _spr:
				_spr.visible = false
			return
		var tp := tip_pos() - position
		# 颜料画出来的长胳膊：粗线 + 几滴往下滴
		draw_line(o, tp, Color(0.55, 0.2, 0.35), 6.0)
		draw_line(o, tp, Color(0.98, 0.6, 0.75), 4.0)
		for i in 4:
			var p := o.lerp(tp, (i + 0.5) / 4.0)
			draw_circle(p + Vector2(0, 3 + fposmod(_t * 8.0 + i * 3.0, 6.0)), 1.5, Color(0.98, 0.6, 0.75, 0.8))
		if _spr:
			_spr.visible = true
			_spr.position = tp + Vector2(0, -6)
			_spr.rotation = (tp - o).angle() - PI * 0.35
		else:
			draw_circle(tp, 5.0, Color(0.98, 0.75, 0.85))

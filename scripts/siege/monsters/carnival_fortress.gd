class_name CarnivalFortress
extends SiegeBoss
## Giant hull owns geometry, HP and crew. Skill jobs use the battle clock.
const MAX_CREW := 48
const MAX_CARTS := 20
const GOLD := Color(1.0,0.78,0.3)
const HALF := Vector2(588,200)
var mechanisms: FortressMechanisms
var expanded := false
var expand_left := 0.0
var phase_count := 0
var empowered := false # One stolen-tower shell, consumed at the next cannon charge.
var healed_total := 0
var reserved_crew := 0
var crew: Array[WeakRef] = []
var carts: Array[WeakRef] = []
var recoil := Vector2.ZERO
var crush_clock := {}
var crush_fraction := {}
var wall_clock := 3.0
var _introduced := false
var ending := false
var _layers: Array[Sprite2D] = []
var _hit_flash := 0.0
var _dust_left := 0.0
var _blocker: StaticBody2D
var _protected := {}
var _occluded: Array[PlayableCharacter] = []

func _setup() -> void:
	super()
	knockback_resist = 0.6
	max_bats = 0
	summon_interval = 99999.0
	slam_chance = 0.0
	collision_mask = 0
	if sprite: sprite.visible = false
	for key in ["hull","deck"]:
		var layer := Sprite2D.new()
		layer.texture = load("res://assets/generated/siege/fortress_v2_%s.png" % key)
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.name = key
		layer.visible = key == "hull"
		if key == "deck": layer.position = Vector2(0,-70)
		add_child(layer)
		_layers.append(layer)
	_blocker = StaticBody2D.new()
	_blocker.collision_layer = 1
	_blocker.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = HALF*2
	shape.shape = rectangle
	_blocker.add_child(shape)
	add_child(_blocker)
	mechanisms = FortressMechanisms.new()
	mechanisms.boss = self
	add_child(mechanisms)
	add_to_group("fortress")
	set_meta("siege_alert",true)

func footprint(at := Vector2.INF) -> Rect2:
	return Rect2((global_position if at == Vector2.INF else at)-HALF,HALF*2)

func attack_point(from: Vector2) -> Vector2:
	var rect := footprint()
	var p := from.clamp(rect.position,rect.end)
	if rect.has_point(from):
		var choices := [Vector2(rect.position.x,from.y),Vector2(rect.end.x,from.y),Vector2(from.x,rect.position.y),Vector2(from.x,rect.end.y)]
		choices.sort_custom(func(a,b): return a.distance_squared_to(from)<b.distance_squared_to(from))
		p = choices[0]
	return p

func shoulder(side: int) -> Vector2:
	return global_position+Vector2(side*520,-70)

func safe_exterior(at: Vector2, margin := 24.0) -> Vector2:
	if footprint().grow(margin).has_point(at):
		return attack_point(at)+(attack_point(at)-global_position).normalized()*margin
	return director.clamp_in_map(at,margin)

func _tick(delta: float) -> void:
	if ending or director == null or director.state != "fight" or SiegeTools.paused(): return
	if not _introduced:
		_introduced = true
		GameState.boss_changed.emit(self)
		SiegeFx.big_title(self,"狂欢攻城堡垒",GOLD,"持续增援！救回冰塔 · 蓄力时攻击核心")
		SiegeFx.camera_peek(self,global_position,1.8,0.30)
		Audio.play("boss_roar",-2)
	_t += delta
	_stun_left = maxf(0,_stun_left-delta)
	if not expanded and health.hp <= 1400:
		expanded = true
		raged = true
		phase_count += 1
		expand_left = 1.5
		mechanisms.cancel_all()
		for side in [-1,1]: mechanisms.burst(shoulder(side),80,"crane")
		SiegeFx.big_title(self,"展开平台：双重追猎",GOLD,"巨手巡航 · 交叉空降 · 双钩重炮")
	if expand_left > 0:
		expand_left = maxf(0,expand_left-delta)
	else:
		velocity = Vector2(0,-4 if expanded else -8) if not is_stunned() else Vector2.ZERO
		# Impulses may retreat or move sideways, never accelerate the slow march.
		recoil.y = maxf(0.0,recoil.y)
		velocity += recoil
		recoil = recoil.move_toward(Vector2.ZERO,160*delta)
		var next := global_position+velocity*delta
		next.x = clampf(next.x,HALF.x+240,director.map_size().x-HALF.x-240)
		next.y = clampf(next.y,director.wall_foot_y()+HALF.y,director.map_size().y-HALF.y-20)
		if _push_clear(next): global_position = next
		_crush(delta)
		if footprint().position.y <= director.wall_foot_y()+1:
			wall_clock -= delta
			if wall_clock <= 0:
				wall_clock = 3
				director.damage_wall(director.segment_at(global_position.x),60)
		else: wall_clock = 3
		mechanisms.tick(delta)
	_hit_flash = maxf(0,_hit_flash-delta)
	_layers[1].visible = expanded
	_layers[1].scale.y = clampf(1.0-expand_left/1.5,0.05,1) if expanded else 1.0
	for layer in _layers:
		layer.modulate = Color(1.6,1.5,1.3) if _hit_flash>0 else (Color(1,0.75,0.65) if health.hp<700 else Color.WHITE)
	_dust_left -= delta
	if _dust_left <= 0:
		_dust_left = 0.25
		if director.on_screen(global_position,650):
			for side in [-1,1]: Fx.burst(get_parent(),global_position+Vector2(side*500,185),"dust",2,20,0.4,Vector2(0,20),GOLD)
	queue_redraw()

func _push_clear(next: Vector2) -> bool:
	var rect := footprint(next).grow(10)
	for c in [director.pink,director.blue]:
		if not SiegeTools.alive(c) or not rect.has_point(c.global_position): continue
		if not c.is_physics_processing() or c.status.is_grabbed(): return false
		var p: Vector2 = c.global_position
		var options := [Vector2(rect.position.x-2,p.y),Vector2(rect.end.x+2,p.y),Vector2(p.x,rect.position.y-2),Vector2(p.x,rect.end.y+2)]
		options.sort_custom(func(a,b): return a.distance_squared_to(p)<b.distance_squared_to(p))
		c.add_collision_exception_with(_blocker)
		var moved := false
		for goal in options:
			# Never recover a blocked frontal push by dragging through the entire hull.
			if goal.distance_to(p)>maxf(24.0,next.distance_to(global_position)+14.0): continue
			if goal.y<director.wall_foot_y()+12 or goal.y>director.map_size().y-12: continue
			if c.test_move(c.global_transform,goal-p): continue
			c.move_and_collide(goal-p)
			moved = not rect.has_point(c.global_position)
			if moved: break
		c.remove_collision_exception_with(_blocker)
		if not moved: return false
	return true

func _crush(delta: float) -> void:
	for n in get_tree().get_nodes_in_group("siege_tower"):
		var tower := n as IceTower
		if not SiegeTools.alive(tower) or tower.has_meta("fortress_lift"): continue
		var off := tower.global_position-global_position
		var id := tower.get_instance_id()
		if absf(absf(off.x)-500)>70 or absf(off.y)>180:
			crush_clock.erase(id)
			continue
		crush_clock[id] = float(crush_clock.get(id,0))+delta
		if crush_clock[id]>=0.5:
			crush_clock[id]-=0.5
			var total := float(crush_fraction.get(id,0))+tower.health.max_hp*0.25
			crush_fraction[id] = total-floorf(total)
			tower.set_meta("fortress_keep_pad",true)
			tower.raid_hit(int(total),self)

func apply_knockback(from: Vector2, force: float) -> void:
	var dir := from.direction_to(global_position)
	if dir == Vector2.ZERO: dir = Vector2.DOWN
	recoil += Vector2(dir.x,maxf(0.0,dir.y))*maxf(0.0,force)*(1.0-knockback_resist)

func _on_damaged(_hit: HitData) -> void:
	_hit_flash = 0.15

func protected(c: PlayableCharacter) -> bool:
	return _t < float(_protected.get(c.get_instance_id(),-INF))

func protect(c: PlayableCharacter, seconds: float) -> void:
	_protected[c.get_instance_id()] = maxf(float(_protected.get(c.get_instance_id(),0)),_t+seconds)

func strike_tools(c: PlayableCharacter, amount: float, part: String, variant: String) -> bool:
	if not SiegeTools.alive(c) or ending or protected(c): return false
	var hit := HitData.make_tickle(self,amount)
	hit.zone = part
	hit.reaction_variant = variant
	var accepted := c.receive_hit(hit)
	if accepted: protect(c,0.8)
	return accepted

func mechanism_damage(amount: int) -> void:
	if not ending and is_alive(): health.damage(amount)

func reserve_crew(wanted: int) -> int:
	crew = crew.filter(func(ref): return SiegeTools.alive(ref.get_ref()))
	var got := mini(wanted,maxi(0,MAX_CREW-crew.size()-reserved_crew))
	reserved_crew += got
	return got

func land_crew(at: Vector2, count: int, on_wall := false, ticket := -1, keys: Array = []) -> Array:
	reserved_crew = maxi(0,reserved_crew-count)
	var made: Array = []
	if ending or director.state!="fight": return made
	for i in count:
		var key := str(keys[i%keys.size()]) if not keys.is_empty() else ("rat" if i%2==0 else "squirrel")
		var m := director.spawn(key,"",at+Vector2(i*12-6,0),ticket)
		if m:
			crew.append(weakref(m))
			m.set_meta("fortress_crew",get_instance_id())
			m.set_meta("rocket_landed",true)
			if on_wall: TeamworkEffects.put_on_wall(m,m.global_position)
			made.append(m)
	return made

func heal_from_engineers(amount: int) -> int:
	var actual := mini(amount,mini(336-healed_total,health.max_hp-health.hp))
	if actual>0 and not ending:
		health.heal(actual)
		healed_total += actual
		return actual
	return 0

func _draw() -> void:
	if ending: return
	# World-space actor outline remains visible above the giant hull.
	for c in [director.pink,director.blue]:
		if SiegeTools.alive(c) and footprint().grow(20).has_point(c.global_position):
			draw_arc(to_local(c.global_position)+Vector2(0,-10),16,0,TAU,20,Color(0.45,0.9,1) if c.character_id=="blue" else Color(1,0.5,0.8),3)
	for side in [-1,1]:
		var p := Vector2(side*500,160)
		for i in 9:
			draw_line(p+Vector2(-50,i*4+int(_t*12)%4),p+Vector2(50,i*4+int(_t*12)%4),Color(0.65,0.48,0.25,0.4),2)

func _on_died() -> void:
	if ending: return
	ending = true
	mechanisms.cancel_all()
	reserved_crew = 0
	GameState.boss_changed.emit(null)
	if is_instance_valid(director) and director.state=="fight": director.final_boss_defeated(self)
	else: queue_free()

func _exit_tree() -> void:
	if is_instance_valid(mechanisms): mechanisms.cancel_all()
	reserved_crew = 0

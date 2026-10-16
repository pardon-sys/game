class_name FortressTarget
extends Actor
## The only two attack-operated mechanisms: cable and cannon core.
var manager: FortressMechanisms
var kind := ""
var job: Dictionary = {}
var hp := 6
var index := 0
var frozen_left := 0.0
var closed := false
var label := ""
var color := Color(0.5,0.9,1)
var _hit_gap := 0.0
func _setup() -> void:
	set_faction(Faction.Type.ENEMY)
	collision_layer=4
	collision_mask=0
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius=20 if kind=="core" else 14
	collider.shape=shape
	add_child(collider)
	add_to_group("siege_temp")
	add_to_group("fortress_target")
	z_index=20
func _tick(delta: float) -> void:
	if closed or not is_instance_valid(manager) or not manager.valid(): close(); return
	if SiegeTools.paused(): return
	_hit_gap=maxf(0,_hit_gap-delta)
	queue_redraw()
func receive_hit(hit: HitData) -> bool:
	if closed or not visible or SiegeTools.paused() or not is_instance_valid(manager) or not manager.valid() or hit.kind!=HitData.Kind.ATTACK or hit.from_tower or not is_instance_valid(hit.source) or not hit.source is PlayableCharacter or _hit_gap>0: return false
	_hit_gap=0.12
	manager.target_hit(self,hit.damage)
	return true
func close() -> void:
	if closed: return
	closed=true
	collision_layer=0
	visible=false
	queue_free()
func _draw() -> void:
	if closed: return
	var col := Color(1,0.85,0.35) if kind=="core" else color
	draw_circle(Vector2.ZERO,20,Color(0.1,0.08,0.15))
	if kind=="cable":
		draw_line(Vector2(0,-35),Vector2(0,20),col,4)
		draw_circle(Vector2.ZERO,12,col,false,3)
	else:
		var points := PackedVector2Array()
		for i in 6: points.append(Vector2.from_angle(TAU*i/6)*19)
		draw_colored_polygon(points,col)
		draw_circle(Vector2.ZERO,10,Color(0.3,0.12,0.18))
	var font := ThemeDB.fallback_font
	draw_string_outline(font,Vector2(-40,-30),label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,3,Color.BLACK)
	draw_string(font,Vector2(-40,-30),label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,col)
	if kind=="cable": draw_string(font,Vector2(-12,36),str(hp),HORIZONTAL_ALIGNMENT_LEFT,-1,12,col)

class_name WarTown
extends Node2D
## 地下小镇·战时（floor_06_war）的导演：
##   两个公主都能跟随、都能被搭话（PARTNER 对话：「换我来」切换操控 / 聊两句）；这张图 no_switch，C 键不能换。
##   第一次进来（还没有 f6w_arrived）：放队长的过场 f6w_arrive（有千手痒痒裤时 f6w_arrive_pants）。
## 图例：X = f6war

const PARTNER := "floor_06/war_partner"
const FLAG := "f6w_arrived"


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	setup_partners()
	if not GameState.has_flag(FLAG):
		await Cutscene.play(cutscene_id())
		GameState.set_flag(FLAG)
		setup_partners()


static func cutscene_id() -> String:
	return "f6w_arrive_pants" if GameState.has_flag("blue_tickle_pants") else "f6w_arrive"


func _level() -> Node:
	var n := get_parent()
	while n and not n.has_node("Walls"):
		n = n.get_parent()
	return n


func setup_partners() -> void:
	var lv := _level()
	if lv == null:
		return
	for n in lv.find_children("*", "PlayableCharacter", true, false):
		var c := n as PlayableCharacter
		# 从攻防战回来：镜头倍数恢复默认
		if c.camera:
			c.camera.zoom = Vector2.ONE
			c.camera.top_level = false
		c.follow = true
		c.partner_talk = PARTNER
		if c.is_controlled():
			c._refresh_partner_area()
		else:
			c.start_following(PARTNER)

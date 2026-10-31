class_name Party
extends RefCounted
## 同行的人：背包状态页左右切换能看谁、按 C / F2 换人能换到谁，都由地图元数据决定（以前是同一关卡里所有可操作角色都算）。
##   算同行的：
##     1. 当前操控的角色；
##     2. 跟着走的同行者（PlayableCharacter.follow，例如跟着粉色公主的蓝色公主）；
##     3. 地图 [level] 段 party = 人物 id,…（PlayableCharacter.character_id：pink / blue / bonfire_host）里列出的可操作角色——
##        「只有特定场景才能切到派对主人」就在那张图写 party = bonfire_host；
##     4. 允许换人的场景（关卡 meta free_switch、双人同行 Duo.active）里能换的角色（switchable）。
##   其余在地图上闲逛的可操作角色（小镇里的派对主人等）不算同行：状态页看不到，C 换不过去。
##   测试模式（DevConfig）按 F2 不受限，仍可在同一关卡的所有可操作角色间循环。
## 测试：members(player)、listed(level, id)。


## 角色所在的关卡根节点（往上找带 Walls 的节点）
static func level_of(n: Node) -> Node:
	var lv := n.get_parent() if n else null
	while lv and not lv.has_node("Walls"):
		lv = lv.get_parent()
	return lv


## 地图的 party 里有没有这个人物 id
static func listed(level: Node, id: String) -> bool:
	if level == null:
		return false
	var p: Variant = level.get("party")
	return p is PackedStringArray and (p as PackedStringArray).has(id)


## 同行的人：操控的角色在前，其余按场景树顺序
static func members(player: PlayableCharacter) -> Array[PlayableCharacter]:
	var out: Array[PlayableCharacter] = []
	if not is_instance_valid(player):
		return out
	out.append(player)
	var lv := level_of(player)
	if lv == null:
		return out
	var open: bool = lv.get_meta(&"free_switch", false) or Duo.active
	for n in lv.find_children("*", "PlayableCharacter", true, false):
		var c := n as PlayableCharacter
		if c == null or c == player or not c.visible or not c.is_alive() or c.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		if c.follow or listed(lv, c.character_id) or (open and c.switchable):
			out.append(c)
	return out


## 按 C 能不能换到 c（同行、没倒下；地图 party 里列出的人即使 switchable 关着也能换）
static func can_switch_to(player: PlayableCharacter, c: PlayableCharacter) -> bool:
	if c == player or Downed.is_downed(c):
		return c == player
	return members(player).has(c) and (c.switchable or listed(level_of(c), c.character_id))

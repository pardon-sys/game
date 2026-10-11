class_name Equipment
extends RefCounted
## 装备系统（静态工具；数据在 GameState.equipment / equip_charges，随存档保存）：
##   GameState.equipment     = {角色 id: {部位: 装备 id}}（一件占多个部位时每个部位都记它）
##   GameState.equip_charges = {角色 id: {部位: 剩余挡下次数}}
## 解锁：剧情标记 UNLOCK_FLAG（战乱的小镇里和篝火派对的主人说话）。没解锁时什么都不生效、界面上也看不到。
## 两人各穿各的；同一件装备同一时间只能一个人穿（背包里只有一件）。
## 千手痒痒裤：蓝色公主有剧情标记 blue_tickle_pants 时，大腿 + 屁股两格固定是它（诅咒，脱不下；效果由状态 thousand_pants 提供，这里不重复算）。
## 效果怎么生效：
##   属性 → Actor.stat_add / stat_mul（PlayableCharacter 把 stat_add(角色, 属性) / stat_mul 也算进去）
##   部位敏感度 → Sensitivity.zone_total 加上 zone_mod(角色, 部位)
##   挡挠痒 → PlayableCharacter._tickle_multiplier 里 try_block(角色, 部位)
##   铃铛 → PlayableCharacter 被挠到时 ring_bell


const UNLOCK_FLAG := "equip_unlocked"
const PANTS_ID := "thousand_pants"
const PANTS_FLAG := "blue_tickle_pants"
const PANTS_SLOTS := ["thigh", "butt"]


static func unlocked() -> bool:
	return GameState.has_flag(UNLOCK_FLAG)


## 这个角色穿着的 {部位: 装备 id}（包括固定的千手痒痒裤）。
static func worn(who: String) -> Dictionary:
	var out: Dictionary = (GameState.equipment.get(who, {}) as Dictionary).duplicate()
	if who == "blue" and GameState.has_flag(PANTS_FLAG):
		for z in PANTS_SLOTS:
			out[z] = PANTS_ID
	return out


static func item_at(who: String, zone: String) -> EquipData:
	var id := str(worn(who).get(zone, ""))
	return ItemDB.get_item(id) as EquipData if id != "" else null


## 穿着的装备（每件一次）。没解锁时是空的。
static func items_of(who: String) -> Array[EquipData]:
	var out: Array[EquipData] = []
	if not unlocked() and not (who == "blue" and GameState.has_flag(PANTS_FLAG)):
		return out
	var seen := {}
	for z in worn(who):
		var id := str(worn(who)[z])
		if seen.has(id):
			continue
		seen[id] = true
		var it := ItemDB.get_item(id) as EquipData
		if it:
			out.append(it)
	return out


static func is_worn_by(id: String) -> String:
	for who in ["pink", "blue"]:
		if worn(who).values().has(id):
			return who
	return ""


## 这件装备现在这个角色能不能穿；返回原因（"" = 能）。
static func why_not(who: String, id: String) -> String:
	var it := ItemDB.get_item(id) as EquipData
	if it == null:
		return "这不是装备"
	if not GameState.inventory.has(id):
		return "还没有这件"
	if not it.can_wear(who):
		return "只有%s能穿" % ("蓝色的公主" if it.owner_id == "blue" else "公主")
	var other := is_worn_by(id)
	if other != "" and other != who:
		return "另一个人正穿着"
	for z in it.slots:
		var cur := item_at(who, z)
		if cur and cur.id != id and cur.cursed:
			return "%s被%s占着（脱不下）" % [TickleZones.zone_name(z), cur.display_name]
	return ""


static func equip(who: String, id: String) -> bool:
	if why_not(who, id) != "":
		return false
	var it := ItemDB.get_item(id) as EquipData
	var mine: Dictionary = GameState.equipment.get(who, {})
	# 先脱掉占着这些部位的旧装备（整件脱）
	for z in it.slots:
		var cur := str(mine.get(z, ""))
		if cur != "" and cur != id:
			_remove(mine, cur)
	for z in it.slots:
		mine[z] = id
	GameState.equipment[who] = mine
	var ch: Dictionary = GameState.equip_charges.get(who, {})
	for z in it.block:
		ch[z] = int(it.block[z])
	GameState.equip_charges[who] = ch
	GameState.set_flag("wearing_%s_%s" % [who, id])
	_notify(who)
	return true


## 脱掉这个部位上的装备（整件）。诅咒的脱不下。
static func unequip(who: String, zone: String) -> bool:
	var it := item_at(who, zone)
	if it == null or it.cursed:
		return false
	var mine: Dictionary = GameState.equipment.get(who, {})
	_remove(mine, it.id)
	GameState.equipment[who] = mine
	GameState.set_flag("wearing_%s_%s" % [who, it.id], false)
	_notify(who)
	return true


static func _remove(mine: Dictionary, id: String) -> void:
	for z in mine.keys():
		if str(mine[z]) == id:
			mine.erase(z)


static func _notify(who: String) -> void:
	GameState.equipment_changed.emit(who)


# ------------------------------------------------------------------ 效果
static func stat_add(who: String, stat: String) -> float:
	var total := 0.0
	if Buff.stat_kind(stat) != "add":
		return total
	for it in items_of(who):
		if it.modifiers.has(stat):
			total += float(it.modifiers[stat])
	return total


static func stat_mul(who: String, stat: String) -> float:
	var total := 1.0
	if Buff.stat_kind(stat) != "mul":
		return total
	for it in items_of(who):
		if it.modifiers.has(stat):
			total *= float(it.modifiers[stat])
	return total


static func zone_mod(who: String, zone: String) -> float:
	var total := 0.0
	for it in items_of(who):
		total += float(it.zone_mods.get(zone, 0.0))
	return total


static func charges(who: String, zone: String) -> int:
	return int((GameState.equip_charges.get(who, {}) as Dictionary).get(zone, 0))


## 这一下挠到 zone：有装备能挡就挡下（扣一次），返回挡没挡。
static func try_block(who: String, zone: String) -> bool:
	if zone == "" or not unlocked():
		return false
	var it := item_at(who, zone)
	if it == null or not it.block.has(zone) or charges(who, zone) <= 0:
		return false
	GameState.equip_charges[who][zone] = charges(who, zone) - 1
	return true


## 休息（篝火 / 存档点）：挡下次数全部恢复。
static func restore_charges() -> void:
	for who in ["pink", "blue"]:
		var ch := {}
		for it in items_of(who):
			for z in it.block:
				ch[z] = int(it.block[z])
		GameState.equip_charges[who] = ch


static func has_special(who: String, special: String) -> bool:
	return items_of(who).any(func(it: EquipData) -> bool: return it.special == special)


## 装备组合认的键：穿着的装备（挡下次数用光的再加一个 "<键>:spent"）。
static func combo_keys(who: String) -> Array:
	var out := []
	for it in items_of(who):
		out.append(it.key())
		if not it.block.is_empty() and it.block.keys().all(func(z) -> bool: return charges(who, z) <= 0):
			out.append(it.key() + ":spent")
	return out


## 装备合计说明（装备页底部）：好处 / 代价各一行。
static func summary(who: String) -> Array[String]:
	var pros: Array[String] = []
	var cons: Array[String] = []
	for it in items_of(who):
		if it.pros != "" and it.pros != "（无）":
			pros.append(it.pros)
		if it.cons != "":
			cons.append(it.cons)
	return ["、".join(pros), "、".join(cons)]

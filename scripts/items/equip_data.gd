class_name EquipData
extends ItemData
## 可装备的东西（装备系统：每个可挠部位一个装备格；Equipment 管谁穿着什么）。在 ItemDB.PATHS 注册，放 data/items/equip_*.tres。
##   slots      占哪些部位格（TickleZones 的部位 id；可以占多个，比如千手痒痒裤 = 大腿 + 屁股）
##   owner_id   谁能穿（"" = 都能，"pink" / "blue" = 专用）
##   modifiers  属性 {属性: 数值}：合并方式同 data/buffs.json 的 stat_kinds（add 相加 / mul 相乘），
##              例如 speed 0.95、laugh_gain -0.1、attack 1.2、magic_cd 0.85、laugh_decay 0.2、struggle 0.3
##   zone_mods  部位敏感度加减 {部位: ±数值}
##   block      挡下挠痒的次数 {部位: 次数}（在篝火 / 存档点休息时恢复）
##   cursed     诅咒：穿上就脱不下
##   combo_key  装备组合（combos.json 的 equip）认的键，默认就是 id
##   special    特殊效果：bell = 被挠到时叮铃响，附近的怪都朝她过来
##   pros / cons  装备页上显示的好处 / 代价
##   temporary  临时痒痒装备（攻防战里被敌人强制穿上，Equipment.force；不卖、不进背包）
##   kind       临时装备的类别：tickle 挠痒 / bind 束缚 / curse 负面（装备页、情报里显示）

@export var slots: Array[String] = []
@export var owner_id := ""
@export var modifiers := {}
@export var zone_mods := {}
@export var block := {}
@export var cursed := false
@export var combo_key := ""
@export var special := ""
@export var pros := ""
@export var cons := ""
@export var temporary := false
@export var kind := ""


func _init() -> void:
	category = Category.EQUIP
	stackable = false
	show_in_hud = false


func can_wear(who: String) -> bool:
	return owner_id == "" or owner_id == who


func key() -> String:
	return combo_key if combo_key != "" else id


func can_use(_user: Node) -> bool:
	return false

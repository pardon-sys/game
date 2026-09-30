class_name MonsterStats
extends Resource
## 怪物数值（数据资源，放在 data/monsters/*.tres，在检查器里调）。

@export var display_name := ""
## 在 data/princess_reactions.json 的 sources 里对应的键（公主台词、首次遭遇对话、怪物回嘴）。
@export var reaction_key := ""
## 挠痒成功时头顶冒出回嘴短句的概率。
@export_range(0.0, 1.0) var taunt_chance := 0.35
## Boss：遭遇时 HUD 顶部显示血条。
@export var is_boss := false
@export_group("生存")
@export var max_hp := 3
@export var knockback_taken := 170.0
@export_group("移动")
@export var wander_speed := 18.0
@export var chase_speed := 40.0
@export var detect_range := 88.0
@export var lose_range := 150.0
@export var hurt_time := 0.35
@export_group("攻击（扣血）")
@export var attack_damage := 1
@export var attack_knockback := 170.0
@export var attack_cooldown := 1.2
@export_group("挠痒（加闷笑值）")
@export var tickle_amount := 10.0
@export var tickle_cooldown := 0.6
## 两种行动都可用时选择挠痒的概率。
@export_range(0.0, 1.0) var tickle_weight := 0.75
## 挠痒果冻音效的音高（1 = 原调，越小越低沉）。
@export var tickle_pitch := 1.0
@export_group("掉落")
@export var drops: Array[ItemDrop] = []

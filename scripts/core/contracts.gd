class_name Contracts
extends RefCounted
## 接口约定。GDScript 没有 interface 关键字，本项目用"方法约定 + 这里的检查函数"表达接口。
## 详细说明见 docs/ARCHITECTURE.md。
##
##   Damageable   receive_hit(hit: HitData) -> bool       可被攻击/挠痒（Actor、木桶）
##   Tickleable   Actor 且带 LaughMeter 组件               可被挠痒、累积闷笑值
##   Interactable 子节点 Interactable + on_interact(actor)  可按 E 交互（宝箱、门、拉杆…）
##   Switchable   set_active(on: bool)                    可被拉杆等机关开关（铁栅门、陷阱）
##   Controllable CharacterController 子节点               可被键盘/脚本/AI 操控（PlayableCharacter）
##   Usable       ItemData.can_use(user) / use(user)       可使用的物品
##   MagicReactive on_magic_burst(tier, caster)           对公主的星光爆发有反应（粉雾被吹散、藤蔓被清除…），
##                加入 "magic_reactive" 组；可选属性 magic_radius 扩大判定

const DAMAGEABLE: Array[StringName] = [&"receive_hit"]
const SWITCHABLE: Array[StringName] = [&"set_active"]
const INTERACTABLE: Array[StringName] = [&"on_interact"]
const MONSTER: Array[StringName] = [&"receive_hit", &"attack", &"tickle"]
const ALLY: Array[StringName] = [&"receive_hit", &"follow", &"engage", &"assist"]
const PLAYABLE: Array[StringName] = [&"receive_hit", &"attack", &"dash", &"interact", &"use_item", &"set_controller"]
const TRAP: Array[StringName] = [&"set_active", &"trigger"]
const ITEM: Array[StringName] = [&"can_use", &"use"]
const MAGIC_REACTIVE: Array[StringName] = [&"on_magic_burst"]


static func missing(obj: Object, methods: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for m in methods:
		if obj == null or not obj.has_method(m):
			out.append(m)
	return out


static func implements(obj: Object, methods: Array[StringName]) -> bool:
	return missing(obj, methods).is_empty()


static func is_damageable(obj: Object) -> bool:
	return obj != null and is_instance_valid(obj) and obj.has_method(&"receive_hit")


static func is_magic_reactive(obj: Object) -> bool:
	return obj != null and is_instance_valid(obj) and obj.has_method(&"on_magic_burst")


static func is_tickleable(obj: Object) -> bool:
	return obj is Actor and (obj as Actor).laugh != null


static func is_switchable(obj: Object) -> bool:
	return obj != null and obj.has_method(&"set_active")

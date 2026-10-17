class_name ShieldCrab
extends SiegeMonster
## 盾甲螃蟹：举着大钳子挡住正面（朝着城墙的那一面）——从前面 / 上面来的冰锥、冰塔、法术都打不动；
## 只有从背后（下面）打才有用，所以要粉色公主绕到后面去；冰晶共鸣的电弧、冰陨星台的陨石挡不住（HitData.ignore_block）。
## 走到墙下用钳子夹墙（伤害更高）。


func block_hit(hit: HitData) -> bool:
	if hit.source == null or not is_instance_valid(hit.source) or not (hit.source is Node2D):
		return false
	# 正面 = 朝上（城墙那边）：攻击来源在自己上方就挡住
	var from := (hit.source as Node2D).global_position
	return from.y < global_position.y - 6.0

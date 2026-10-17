class_name ShieldCrab
extends SiegeMonster
## 盾甲螃蟹：举着一对大钳子当盾牌。冰塔、塔弹、蓝色公主的法术、冰陨星台的陨石、士兵——全都打不动；
## 只有冰晶共鸣塔的电弧打得动（tag = RESONANCE_TAG），而且只有 RESONANCE_MULT 的伤害（至少 1）；
## 粉色公主的锤子绕到背后（下面）打才有用，正面（朝城墙那一面）照样挡住。走到墙下用钳子夹墙（伤害更高）。

const RESONANCE_TAG := "resonance"
const RESONANCE_MULT := 0.1


func block_hit(hit: HitData) -> bool:
	if hit.tag == RESONANCE_TAG:
		hit.damage = maxi(1, int(ceil(hit.damage * RESONANCE_MULT)))
		return false
	var src := hit.source
	if hit.from_tower or src == null or not is_instance_valid(src) or not (src is PlayableCharacter):
		return true
	if (src as PlayableCharacter).character_id != "pink":
		return true
	# 粉色公主：正面 = 朝上（城墙那边），她在自己上方就挡住
	return (src as Node2D).global_position.y < global_position.y - 6.0

"""生成攻城怪的场景（scenes/siege/monsters/<场景>.tscn；可以反复运行，覆盖写）。
每个场景：CharacterBody2D（脚本 scripts/siege/monsters/<场景>.gd，继承 SiegeMonster）+ Sprite（闪白材质，图在 siege/monsters.png，
脚本里按 sprite_key 取区域）+ Shape + Health + HitArea；MonsterStats 写成场景里的子资源（数值在下面的表里）。
用法：python tools/build/gen_siege_monsters.py
"""
import os
from pathlib import Path

os.chdir(Path(__file__).resolve().parents[2])

# 场景名: (脚本名, sprite_key, 显示名, reaction_key, hp, wander, chase, detect, atk, tickle, tickle_cd, tickle_weight, hit_fx, 身体半径, 接触半径)
MONSTERS = {
    "siege_cart": ("siege_cart", "cart", "攻城痒痒车", "cart", 14, 0, 0, 0, 3, 10.0, 1.0, 0.2, "hand", 12, 14),
    "hook_climber": ("hook_climber", "hook", "钩索怪", "hook", 4, 20, 46, 70, 1, 9.0, 0.7, 0.8, "hand", 5, 8),
    "bind_vine": ("bind_vine", "vine", "捆绑藤怪", "bind_vine", 5, 14, 30, 90, 1, 8.0, 0.8, 0.95, "feather", 5, 9),
    "wall_gecko": ("wall_gecko", "gecko", "爬墙壁虎", "gecko", 2, 30, 64, 60, 1, 7.0, 0.5, 0.85, "hand", 4, 7),
    "shield_crab": ("shield_crab", "shield_crab", "盾甲螃蟹", "shield_crab", 7, 14, 30, 80, 2, 9.0, 0.8, 0.5, "hand", 7, 10),
    "feather_bat_swarm": ("feather_bat_swarm", "bat_swarm", "羽毛蝠群", "bat_swarm", 3, 30, 56, 999, 1, 7.0, 0.5, 0.95, "feather", 6, 10),
    "carrier_imps": ("carrier_imps", "carrier", "搬运小鬼队", "carrier", 6, 22, 44, 90, 1, 6.0, 0.8, 0.9, "hand", 8, 10),
    "warm_slime": ("warm_slime", "warm_slime", "暖炉史莱姆", "warm_slime", 6, 16, 34, 60, 1, 8.0, 0.8, 0.85, "goo", 6, 8),
    "thigh_spider": ("thigh_spider", "thigh_spider", "腿根爬爬蛛", "thigh_spider", 3, 26, 52, 60, 1, 9.0, 0.6, 0.95, "hand", 5, 8),
    "hug_bear": ("hug_bear", "hug_bear", "拥抱小熊", "hug_bear", 6, 18, 40, 100, 1, 10.0, 0.7, 0.95, "hand", 6, 9),
    "suck_jelly": ("suck_jelly", "suck_jelly", "魔力吸吸水母", "suck_jelly", 4, 20, 40, 999, 1, 7.0, 0.7, 0.95, "goo", 5, 9),
    "twin_ghost": ("twin_ghost", "twin_ghost_a", "双子痒痒鬼", "twin_ghost", 5, 20, 42, 90, 1, 9.0, 0.6, 0.85, "hand", 5, 9),
}

TPL = """[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/siege/monsters/{script}.gd" id="1"]
[ext_resource type="Shader" path="res://shaders/flash.gdshader" id="flash"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="health"]
[ext_resource type="Script" path="res://scripts/actors/monsters/monster_stats.gd" id="stats_script"]

[sub_resource type="Resource" id="stats"]
script = ExtResource("stats_script")
display_name = "{name}"
reaction_key = "{key}"
max_hp = {hp}
wander_speed = {wander}.0
chase_speed = {chase}.0
detect_range = {detect}.0
lose_range = {lose}.0
attack_damage = {atk}
tickle_amount = {tickle}
tickle_cooldown = {tcd}
tickle_weight = {tw}
hit_fx = "{fx}"

[sub_resource type="ShaderMaterial" id="mat"]
resource_local_to_scene = true
shader = ExtResource("flash")
shader_parameter/flash = 0.0
shader_parameter/flash_color = Color(1, 1, 1, 1)

[sub_resource type="CircleShape2D" id="body"]
radius = {body}.0

[sub_resource type="CircleShape2D" id="hit"]
radius = {reach}.0

[node name="{node}" type="CharacterBody2D"]
collision_layer = 4
collision_mask = 5
motion_mode = 1
script = ExtResource("1")
stats = SubResource("stats")
sprite_key = "{sprite}"
faction = 3
hurt_invuln_time = 0.1
flash_color = Color(1, 1, 1, 1)

[node name="Sprite" type="Sprite2D" parent="."]
material = SubResource("mat")

[node name="Shape" type="CollisionShape2D" parent="."]
position = Vector2(0, -3)
shape = SubResource("body")

[node name="Health" type="Node" parent="."]
script = ExtResource("health")
max_hp = {hp}

[node name="HitArea" type="Area2D" parent="."]
position = Vector2(0, -5)
collision_layer = 0
collision_mask = 2
monitorable = false

[node name="Shape" type="CollisionShape2D" parent="HitArea"]
shape = SubResource("hit")
"""

out = Path("scenes/siege/monsters")
out.mkdir(parents=True, exist_ok=True)
for scene, (script, sprite, name, key, hp, wander, chase, detect, atk, tickle, tcd, tw, fx, body, reach) in MONSTERS.items():
    node = "".join(w.capitalize() for w in scene.split("_"))
    (out / (scene + ".tscn")).write_text(TPL.format(script=script, name=name, key=key, hp=hp, wander=wander, chase=chase, detect=detect,
                                                     lose=max(detect + 80, 160), atk=atk, tickle=tickle, tcd=tcd, tw=tw, fx=fx, body=body,
                                                     reach=reach, node=node, sprite=sprite))
print("攻城怪场景：%d 个" % len(MONSTERS))

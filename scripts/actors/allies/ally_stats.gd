class_name AllyStats
extends Resource
## 友军数值（data/allies/*.tres）。

@export var max_hp := 6
@export var move_speed := 70.0
## 跟随时与领队保持的距离。
@export var follow_distance := 22.0
## 领队或自己附近多远内的敌人会被攻击。
@export var engage_range := 90.0
@export var attack_range := 16.0
@export var attack_damage := 1
@export var attack_knockback := 150.0
@export var attack_cooldown := 0.8
## 领队闷笑值超过此值时去帮忙。
@export var assist_threshold := 50.0
@export var assist_range := 18.0
## 每次帮忙降低的闷笑值。
@export var assist_amount := 25.0
@export var assist_cooldown := 1.2

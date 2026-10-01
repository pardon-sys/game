# 架构说明

本文说明游戏里的基类、接口、组件，以及如何新增怪物、物品、友军、陷阱和可操作角色。

## 总览

```
Actor（角色基类，CharacterBody2D）
├── PlayableCharacter（可操作角色）
│   └── Princess
├── Monster（怪物）
│   ├── Slime            史莱姆
│   ├── FeatherBat       羽毛蝙蝠（盘旋 → 俯冲挠痒 → 退开）
│   ├── TickleGhost      痒痒幽灵（穿墙；火把照亮才显形、才能被打）
│   ├── TickleSpider     挠痒蜘蛛（吐丝减速 + 贴身三连挠）
│   ├── TickleTroll      挠痒巨魔（小 Boss：抓取 / 僵直 / 重击）
│   ├── FootRat          挠脚鼠（成群、快；公主动不了时挠痒 ×2）
│   ├── PincerCrab       钳钳蟹（横着走，夹脚定身）
│   ├── SplitSlime       分裂史莱姆（倒下分裂成 2 只小的；3 档星光打倒不分裂）
│   ├── Mimic            宝箱怪（伪装，打开即抓住挠痒）
│   ├── FairySwarm       羽毛小精灵群（只挠痒，70% 闪开普通攻击，魔法必中）
│   ├── TentacleBoss     痒痒触手怪（第三层 Boss：落点预警 → 抓住拉近多触手挠）
│   ├── ManaJelly        魔力水母（疲倦 ×3，被打散留水液）
│   ├── BubbleFish       泡泡鱼（保持距离吐泡泡 BubbleShot，命中关进泡泡牢笼持续挠）
│   ├── GhostGlove       幽灵手套（pair= 成对；两只凑齐必暴击 + 搭档补挠）
│   ├── BrushHedgehog    刷刷刺猬（同行 / 同列蜷缩滚过来，必暴击 + 击退；滚动时只怕爆发）
│   └── JellyQueen       魔力水母女王（第四层 Boss：召唤水母、留水液、半血魔力雨）
└── Ally（友军）
	└── Knight（示例）

Trap（陷阱基类，Area2D）
├── SpikeTrap         尖刺（PERIODIC）
├── FeatherTrap       羽毛陷阱（ON_STEP）
├── PowderVent        痒痒粉喷口（PERIODIC，喷出 TickleCloud）
├── FeatherBrush      旋转羽毛刷（CONTINUOUS）
├── GrabHand          机关手（MANUAL，由压力板触发，抓取）
├── TickleVine        痒痒藤蔓（ON_STEP，缠脚定身；可砍断、会长回）
├── FeatherFan        羽毛风扇（CONTINUOUS，风道推人、卷起粉雾）
├── TickleConveyor    痒痒传送带（CONTINUOUS，多格，送走任何阵营）
├── FrenzyTotem       狂热图腾（CONTINUOUS 光环：怪物狂热；可打碎，任意档星光直接碎）
├── HexRune           诅咒符文（ON_STEP：易痒 + 疲倦）
├── Stocks            足枷台（ON_STEP 抓取，滚轮挠脚心，超时最后一下必暴击）
├── StickyCarpet      黏黏毛毯（CONTINUOUS，多格 w×h：黏黏减速，站着不动被黏住）
└── FeatherArm        伸缩羽毛臂（墙面 ON_STEP：预警后横扫前方 length 格）

Projectile（投射物基类，Area2D）
├── WebShot           蛛丝（减速 + 少量挠痒）
└── BubbleShot        泡泡（命中由泡泡鱼关进泡泡牢笼）
TickleCloud（会停留的粉雾，Area2D；可被风吹动、被星光吹散）
StarBurst（星光爆发：范围判定 + 特效；cast_fatigue = 疲倦爆发档）
FatiguePuddle（疲倦水液，Area2D：怪物在里面获得力量）
Buff（增益 / 减益实例，data/buffs.json）

ItemData（物品基类，Resource）
├── HealItem          心
├── LaughReliefItem   薄荷糖
├── KeyItem           铜/金钥匙
└── CurrencyItem      金币
```

角色的能力拆成**组件**（子节点），基类按节点名查找，缺哪个就少哪个能力：

| 组件 | 节点名 | 作用 |
|---|---|---|
| `HealthComponent` | `Health` | 血量（1 点 = 半颗心），信号 `changed / damaged / died` |
| `LaughMeter` | `Laugh` | 闷笑值 0–150；**有它的角色才能被挠痒** |
| `StatusComponent` | `Status` | 状态效果：减速、被抓住、定身、余痒、易痒、拉扯；有它才能被抓 |
| `ComboTracker` | `Combo` | 组合技追踪（公主身上），见下文 |
| `EmotionComponent` | `Emotion` | 表情行 + 头顶气泡 |
| `SpriteSheetAnimator` | `Animator` | 按 `SpriteSheetConfig` 数据驱动精灵表动画 |
| `HitboxComponent` | `Hitbox` | 近战挥击判定 |
| `CharacterController` | `Controller` | 输入来源（键盘 / 脚本 / AI） |
| `Interactable` | `Interactable` | 可按 E 交互的区域 |

数值都放在**数据资源**（`.tres`）里，在 Godot 检查器中直接调：

| 资源 | 位置 |
|---|---|
| `MonsterStats` | `data/monsters/*.tres`（含 `display_name`、`is_boss`、`tickle_pitch` 果冻音高） |
| `AllyStats` | `data/allies/*.tres` |
| `ItemData` 及其子类 | `data/items/*.tres` |
| `SpriteSheetConfig` | `data/actors/*.tres` |
| `ItemDrop`（掉落表项） | 嵌在怪物数值或木桶场景中 |
| 组合技表 | `data/combos.json`（机制）+ `data/princess_reactions.json` 的 `combos`（名称、说明、台词） |

## 接口

GDScript 没有 `interface` 关键字，本项目用**方法约定 + `Contracts` 检查函数**表示接口（`scripts/core/contracts.gd`）：

| 接口 | 约定 | 实现者 |
|---|---|---|
| Damageable | `receive_hit(hit: HitData) -> bool` | 所有 Actor、木桶 |
| Tickleable | 是 Actor 且有 `Laugh` 组件 | 公主 |
| Interactable | 子节点 `Interactable` + 父节点 `on_interact(actor)` | 宝箱、门、铁栅门、拉杆、火把、石碑、信 |
| Switchable | `set_active(on: bool)` | 铁栅门、所有陷阱（拉杆调用） |
| Controllable | 子节点 `Controller`（CharacterController） | PlayableCharacter |
| Usable | `ItemData.can_use(user)` / `use(user) -> bool` | 所有物品 |
| Triggerable | `trigger()` | 所有陷阱（压力板对目标组调用） |
| Grabbable | Actor 且有 `Status` 组件，`can_be_grabbed()` | 公主 |
| MagicReactive | `on_magic_burst(tier, caster)`，加入 `magic_reactive` 组，可选 `magic_radius` | 粉雾、藤蔓、小精灵群、触手怪 |

所有伤害和挠痒都打包成 **`HitData`**（`kind` = `ATTACK` 或 `TICKLE`，以及 `damage / tickle / knockback / source`，星光爆发另带 `tag = "magic_1~3"`），只通过 `receive_hit` 传递。攻击方不需要知道对方是谁：

```gdscript
target.receive_hit(HitData.make_attack(self, 1, 170.0))   # 扣 1 点血
target.receive_hit(HitData.make_tickle(self, 10.0))        # 闷笑值 +10
```

**阵营**（`Faction`：NEUTRAL / PLAYER / ALLY / ENEMY）决定谁打谁：公主和友军是一边，怪物是另一边，中立物体（木桶、陷阱）不属于任何一边。

## 核心规则

**无敌**
- 受到攻击后有 1 秒无敌，但只挡攻击，不挡挠痒。挠痒的频率由怪物自己的冷却控制。
- 冲刺时的无敌攻击和挠痒都挡。

**闷笑值**（`LaughMeter`，所有数值都可在检查器里调）。阶段和恢复量都是**上限 `max_value` 的比例**（`giggle_ratio` / `helpless_ratio` / `stage2_ratio` / `overflow_reset_ratio` / `decay_ratio` / `struggle_ratio`），旧名字 `giggle_threshold` 等是按比例算出的只读属性；以后提高上限只改 `max_value`。`percent()`、`stage()`、`stage_name()`、`stage_desc()` 给背包状态页用。
- 超过 35%：进入 GIGGLING，移动速度 ×0.5，每隔 1–2.5 秒发出一次笑声（音效 `giggle` + 气泡）。
- 超过 55%：进入 HELPLESS（失控 1），不能移动、攻击或交互，音效 `laugh` 在独立通道原生循环。超过 70% 时切为失控 2 姿势，仍属 HELPLESS；降回 70% 以下切回失控 1。
  - 连按攻击键或交互键挣扎，每按一次 -2%。
- 满 100%：笑到脱力，扣 1 点血（半颗心），闷笑值回落到 70%。
- 受到任何攻击或挠痒后，2 秒内闷笑值不下降；之后每秒 -6.7%。
- 薄荷糖一次 -27%（`LaughReliefItem.ratio`，`LaughMeter.reduce_ratio`）；友军骑士帮忙时每次 -17%（`AllyStats.assist_ratio`），领队超过 35% 时出手。怪物挠痒量是固定值。

**减速与抓取**（`StatusComponent`）
- 减速：`apply_slow(倍率, 秒)`，与闷笑倍率相乘。蛛丝减速 50% 持续 2 秒。
- 抓取：`grab(抓人者, 最长秒数, 挣脱次数)`。被抓时 PlayableCharacter 进入 `GRABBED`，不能行动；连按 J/E 同时计入挣脱次数和 `struggle()`（-2% 闷笑值）。挣脱或超时后 0.6 秒全无敌；松开时仍在失控则直接进入失控。冲刺无敌时抓不住。
- `extend_grab(秒, 次数)`：当前抓取延长 / 挣脱多按几次（组合技 `grab_extend` / `grab_presses`）；`grab_time_left()`；`root_after_release(秒)`：被抓着时等松开后再定身（足枷台的锁定 ACTIVE 阶段会跟着延长）。
- 抓人者负责持续挠痒（巨魔每 0.5 秒 8，机关手每 0.5 秒 6），被抓期间形象、台词、笑声照常按闷笑值切到失控 1 / 2。

**定身、余痒、易痒、拉扯、外力**（`StatusComponent` / `Actor`）
- `apply_root(秒)`：定身，不能移动和冲刺，仍可攻击，公主播放挣扎动画（藤蔓、钳钳蟹、组合技）。
- `add_dot(每秒, 秒, 来源)`：余痒，每 0.5 秒结算一次挠痒。
- `add_tickle_multiplier(倍率, 秒)`：易痒，同时有多个时取最大；由 `Actor._tickle_multiplier(hit)` 乘到每次挠痒上。
- `add_pull(来源, 速度, 秒)`：被拉向来源。
- `Actor.add_push(向量)`：只作用一帧的外力（风扇、传送带、拉扯），`move_with_push()` 移动时叠加、不累积进速度。
- `is_immobile()`：被抓或定身；`PlayableCharacter.is_immobile()` 另外算上吟唱和失控。

**星光爆发魔法**（`PlayableCharacter` 的 `CHANNEL` 状态 + `StarBurst`）
- 按住 `magic`（L / 鼠标右键 / 手柄 LB）吟唱：不能移动、冲刺。按住 0.6 / 1.2 / 2.0 秒分别到 1 / 2 / 3 档，满 2 秒自动释放；不到 0.6 秒松开 = 落空。
- 1 档半径 36 伤害 2；2 档半径 52 伤害 3；3 档半径 72 伤害 4，并让怪物僵直 1.5 秒（`Monster.stun`），对 MagicReactive 生效（吹散粉雾、清除藤蔓、击散小精灵、触手怪收触手僵直 2 秒）。
- 弱点暴露：吟唱时 180px 内的怪物立即锁定公主、追击 ×1.3；公主受到的挠痒 ×1.5（`_tickle_multiplier`，陷阱也算）。HUD 显示"弱点暴露！"。
- 限制：失控（闷笑值 >55%）不能开始；吟唱中进入失控、被抓、受到攻击都会打断（`interrupt_channel`）；失控以下被挠痒不打断。星光糖（`MagicResetItem`）调用 `reset_magic_cooldown()`。释放后冷却 6 秒，落空/打断 1.5 秒。
- 解锁：剧情标记 `magic_unlocked`（第三层开场对话的 `set_flag`）。数值都是 `PlayableCharacter` 的导出参数（`channel_tiers`、`magic_cooldown` …），档位半径伤害在 `StarBurst.TIERS`。
- 事件信号 `magic_event(event, tier)`：`channel / tier / burst / fizzle / interrupted`，公主据此说 `princess_reactions.json` 的 `magic` 段台词。

**组合技**（`ComboTracker`，公主的 `Combo` 节点；63 个组合，其中 25 个三来源）
- 监听 `Actor.tickled(hit)`，记录最近挠到公主的来源键（`ReactionDB.key_of`）。来源不分先后，同一来源只算一次；`"*"` 匹配 `groups.monster` 里的任意怪物，`"*trap"` 匹配 `groups.trap` 里的任意陷阱。
- `keys` 可以有 2 个或 3 个槽位。两来源默认窗口 1.5 秒、冷却 4 秒；三来源默认窗口 2.5 秒、冷却 8 秒；每个组合可以写自己的 `window` / `cooldown`。
- 匹配顺序（`sorted_combos()`）：三来源 > 指定来源的两来源 > 带通配的两来源。两来源组合用过的记录标成 `chained`：不能再凑两来源，但能和新来源凑成三来源（`last_upgraded`，横幅显示「连锁升级」）。三来源用过的记录直接删掉。
- 连锁：上一个组合 `CHAIN_WINDOW`（10 秒）内再触发，`chain` +1；`burst` / `dot` 按 `chain_mult()` = 1 + 0.2 ×(chain − 1) 加强。
- 匹配到就触发：施加效果、HUD 横幅（`GameState.combo_triggered`；HUD 读 `combo.chain` / `last_upgraded` 显示连锁数和升级，三来源加大字标题、全屏闪光和 0.3 秒慢动作 `HUD.slow_motion`）、提示音、公主台词。三来源第一次触发时 `CG.play_scene(id)` 播 `data/combo_scenes.json` 里的小演出（`ComboTracker.play_scenes` 可关，测试里关掉）。
- 效果类型：`burst` 额外挠痒、`dot` 余痒、`root` 定身（`extend` 延长、`after_release` 挣脱后再定身）、`multiplier` 易痒、`slow` 减速、`pull` 拉向来源、`hit_multiplier` 本次挠痒倍率；`fatigue` 魔力疲倦 +percent%、`debuff` 给公主加状态（buff、duration）、`seal` 封魔、`special_next` 接下来 count 次挠痒必暴击、`buff_monsters` 给 radius 内的怪物加增益、`puddle` 在脚下生成疲倦水液；`grab_extend` 抓取延长、`grab_presses` 挣脱多按几次；三来源专属的 `lift` 抬起（本节点抓住公主、挣脱次数 9999、加 `lifted` 状态和余痒，小人上浮）、`confuse` 晕头转向（`dizzy` 状态，`invert_controls`）、`crit_storm` 全场暴击（`crit_storm` 状态，`Actor.receive_hit` 里把有来源键的挠痒都变成暴击）、`rally` 召集（`Monster.rally_to`）、`focus` 镜头聚焦（`PlayableCharacter.focus_camera`，停止被挠 1 秒后还原）。
- 条件型组合（有 `condition` 字段）由代码触发 `combo.trigger(id, 来源, force_effects)`：扑粉蝙蝠（`FeatherBat` 飞过粉雾）、粉末旋风（`FeatherFan` 卷起的粉雾挠到公主）、趁手打劫（`ComboTracker.hit_multiplier`：被机关手抓着时怪物挠痒 ×1.5）、狂热连击（`ComboTracker._on_tickled`：暴击来自带狂热 / 力量的怪物）、牢笼里的暴击（`_on_tickled`：被抓着时被暴击）、魔力反噬（`PlayableCharacter.fatigue_burst`：爆发时身边有怪物）。

**增益 / 减益**（`Actor` 基类 + `Buff` + `data/buffs.json`）
- `buffs.json`：`stat_kinds` 定义每种属性的合成方式（`add` 相加 / `mul` 相乘 / `flag` 开关，取最小值）；`buffs` 定义每种状态 `{name, icon, debuff, duration, max_stacks, modifiers}`，`duration = -1` 表示永久。
- 接口：`add_buff(id, 秒 = 默认, 层数 = 1)`（再次添加刷新时间、叠层到上限）、`remove_buff`、`clear_buffs(only_timed)`、`has_buff`、`buff_stacks`、`stat_add(属性)` / `stat_mul(属性)` / `stat_flag(属性)`、信号 `buffs_changed`。
- 属性生效位置：`laugh_gain` 在 `Actor._tickle_multiplier`；`tickle_cd`、`special_chance` 在 `Monster`；`speed` 在移动；`can_channel` 在 `PlayableCharacter.can_cast()`。
- 计时在 `_physics_process`，对话中暂停；复活清掉限时状态、保留永久状态；`GameState.save_player_state` 跨层保存永久状态。
- 表现：HUD `buff_row`（公主，图标 `buff_icons.png` 的第 `icon` 格）；怪物有增益时头顶 `BuffMark`。

**特殊挠痒（暴击）**（`Monster.make_tickle` / `deliver_tickle`）
- 怪物的所有挠痒（普通挠痒、抓住后的持续挠痒、蛛丝连挠、泡泡牢笼……）都要走 `deliver_tickle(目标, 量, 必暴击 = false, 击退 = 0)`，不要直接 `HitData.make_tickle`。
- 判定顺序：必暴击参数 → 目标身上的 `forced_specials`（组合技、手套）→ `stats.special_chance + stat_add("special_chance")`。暴击时量 × `stats.special_mult`，`HitData.special = true`。
- 暴击表现 `Monster.special_feedback(目标)`（音效 `tickle_special`、金色「暴击！」、镜头轻震），陷阱的暴击也调用它；子类钩子 `_on_special_tickle`、`_force_special`。
- 公主按 `ReactionDB.special(来源键)` 说暴击台词。测试需要精确数值时设 `Monster.random_specials = false`。

**魔力疲倦**（`MagicFatigue`，公主的 `Fatigue` 节点）
- 每次被挠：`挠痒量 × (暴击 ? special_rate 2 : normal_rate 0.5) × hit.fatigue_mult`（魔力水母 3）；符文、魔力雨、组合技按上限的百分比 `add_percent()`。不随时间、复活消散。
- 闷笑加成 `laugh_bonus()`：`curve`（疲倦比例 → 加成）数据点之间线性插值，由 `PlayableCharacter._tickle_multiplier` 乘上；`next_tier()` 给状态页；超过 `warn_ratio`（90%）提醒。
- 满值发 `full` → `PlayableCharacter.fatigue_burst()`：`StarBurst.cast_fatigue`（`StarBurst.FATIGUE` 档，不触发 MagicReactive）、`FatiguePuddle.spawn`、`fatigue_scar` 永久减益、`magic_event("fatigue_burst")`；台词在 `data/princess_fatigue.json`（`ReactionDB.fatigue(段)`）。
- `FatiguePuddle`：生成在关卡的 `FloorObjects` 层；怪物在里面持续获得 `strength`。测试需要精确数值时设 `MagicFatigue.accumulate = false`。
- 组合技自己造成的挠痒来源是 `ComboTracker`（`reaction_key` 为空），不会被再次记录。

**怪物行动**
- 敌人进入接触范围（`HitArea`）时，怪物按 `tickle_weight` 的概率选择挠痒，否则攻击。新怪物都 ≥ 0.85（幽灵 1.0），史莱姆 0.75。
- 挠痒时播放合成的果冻"啵叽"声（`Audio.play("tickle", 音量, 抖动, stats.tickle_pitch)`）。
- 如果选中的行动做不成（比如目标正处于攻击无敌），就改做另一种。
- 每次行动后进入对应的冷却时间。

## 如何新增……

### 怪物
1. 写脚本 `scripts/actors/monsters/xxx.gd`，`extends Monster`。按需重写以下钩子，不需要重写的可以省略：
   - `_move(dir, speed, delta)`：移动方式
   - `_animate(delta)`：动画表现
   - `_choose_action(target)`：返回 `"attack"` 或 `"tickle"`
   - `_on_attack_performed` / `_on_tickle_performed`：行动时的动画和音效
   - `can_act()`：什么时候允许行动（蝙蝠只在俯冲时）
   - `_perform(action, target)`：行动的具体做法（巨魔把"挠痒"变成抓取、把"攻击"变成蓄力重击）
   - 需要额外行为（吐丝、显形）时重写 `_tick(delta)` 并调用 `super(delta)`
2. 新建数值资源 `data/monsters/xxx.tres`（类型选 MonsterStats），填好血量、攻击、挠痒、挠痒概率、掉落表。
3. 场景以 `scenes/actors/monsters/slime.tscn` 为模板，需要这些节点：
   - 根节点：CharacterBody2D，挂 xxx.gd，`stats` 指向上一步的资源
	 - `faction = ENEMY`
	 - `collision_layer = 4`，`collision_mask = 5`
   - 子节点：`Sprite`（带 flash 材质）、`Health`、`HitArea`（Area2D，`mask = 2`）
4. 在 `tools/build/build_level.gd` 的 `TYPED_SCENES["monster"]` 里注册，然后在关卡图例里加一行：`X = monster type=xxx`。

### 物品
1. 如果现有类型能满足需求，直接新建 `.tres`，选择对应的物品类（HealItem / LaughReliefItem / KeyItem / CurrencyItem）即可。
2. 如果需要新的效果：写 `scripts/items/xxx_item.gd`，`extends ItemData`，重写 `can_use(user)` 和 `use(user) -> bool`（返回值表示物品是否被消耗）。
3. 填好 `id`、名称、图标、类别等字段：
   - `auto_use_on_pickup`：拾取时立即使用，不进背包
   - `show_in_hud`：是否显示在 HUD 背包栏
   - `pickup_emotion`：获得时公主的表情
4. 在 `scripts/items/item_db.gd` 的 `PATHS` 里注册。
5. 放进关卡有三种方式：
   - 地上：图例写 `X = item id=xxx`
   - 宝箱：图例写 `X = chest item=xxx amount=n`
   - 掉落：在怪物或木桶的掉落表里加一个 `ItemDrop`

HUD 背包栏会根据物品数据自动显示，不需要改 UI 代码。

### 友军
1. 写脚本 `extends Ally`。三种行为都可以重写：
   - `follow(leader, delta)`：跟随领队
   - `engage(enemy, delta)`：攻击附近的敌人
   - `assist(leader, delta)`：领队闷笑值过高时去帮忙

   行为的优先级由 `_choose_behavior()` 决定，也可以重写。表现相关的钩子有 `_animate`、`_on_attack_performed`、`_on_assist_performed`。
2. 新建数值资源 `data/allies/xxx.tres`（类型选 AllyStats）。
3. 场景参照 `scenes/actors/allies/knight.tscn`：
   - `faction = ALLY`，`collision_layer = 2`（和公主同层，怪物的接触范围能检测到友军）
   - 友军默认不会被挠痒；想让它也能被挠痒，给它加一个 `Laugh` 节点即可。
4. 在 `TYPED_SCENES["ally"]` 里注册，然后在图例里加：`X = ally type=xxx`。

### 陷阱
1. 写脚本 `extends Trap`。常用的做法是只在场景里改导出参数，脚本里只重写表现钩子（`_on_idle`、`_on_warn`、`_on_activate`、`_on_switched`）。可调的参数有：
   - `trigger_mode`：PERIODIC 周期 / ON_STEP 踩踏 / MANUAL 手动（压力板或代码调用 `trigger()`）/ CONTINUOUS 一直生效
   - `hit_kind`：攻击或挠痒，以及对应数值
   - 影响哪些阵营
   - 各阶段时长
2. 特殊效果（比如减速、传送）可以重写 `_apply_effect(target) -> bool`。
3. 场景参照 `scenes/traps/spike_trap.tscn`：根节点是 Area2D，`collision_mask = 6`（能检测玩家、友军和怪物）。
4. 在 `TYPED_SCENES["trap"]` 里注册，图例写：`X = trap type=xxx offset=0.5`。
5. 想让拉杆控制它：把陷阱加入拉杆 `target` 对应的组。`switch_disables` 决定拉杆通电时陷阱是关闭还是开启。
6. 想让压力板触发它：设为 MANUAL，把陷阱加入组（如机关手的 `group_name`），压力板图例写 `q = plate target=组名`。
7. 装在墙上的陷阱（如机关手）在图例里用 `walltrap` 类型：`1 = walltrap type=hand group=hand1`，放在墙面格上（和火把一样）。
8. 陷阱挠痒默认也播放果冻声，音高用 `tickle_pitch` 调。
9. 多格陷阱：图例 `w=` / `h=` 映射到 `tiles_w` / `tiles_h`（黏黏毛毯，从所在格向右下铺）；`len=` 映射到 `length`（传送带、风扇、墙面羽毛臂），`dir=` 同名属性。
10. 新陷阱如果覆盖多个格子，记得在 `tests/level_design_test.gd` 的 `hazard_cells()` 里补上覆盖范围，强制段检查才准。

### 组合技
1. 时间窗口组合：在 `data/combos.json` 的 `combos` 里加一项 `{"id", "category", "keys": [[来源键…], [来源键…]], "effects": [...]}`。每个槽位可以写多个备选键，`"*"` 表示任意怪物、`"*trap"` 任意陷阱；写 3 个槽位就是三来源组合（`category` 写「怪+怪+怪」等，效果里加 `{"type": "focus"}`）。
2. 在 `data/princess_reactions.json` 的 `combos` 段加同 id 的 `name`（横幅）、`description`、`lines`（公主台词）。
3. 三来源组合：运行 `python tools/build/gen_combo_scenes.py` 生成小演出（手写的演出放进脚本的 `CUSTOM`）。
4. 条件型组合：写 `"condition": "说明"`，在满足条件的代码里调用 `player.combo.trigger("id", 来源)`（冷却中也要施加效果时传 `force_effects = true`）。
5. `tests/floor3_test.gd` 会自动为每个时间窗口组合跑一遍触发测试（其它组合先进冷却），并检查它有名称和台词。

### 背包与快捷键
- 背包界面 `Backpack`（`scenes/ui/backpack.tscn`，CanvasLayer 第 25 层，`PROCESS_MODE_ALWAYS`）：`GameState.has_backpack()`（剧情标记 `got_backpack`，`BackpackItem` 拾取即设置）之后输入 `backpack`（Tab / I / L3）打开并暂停；`_input` 先于暂停菜单截获 Esc。物品页 `use_selected()` / `assign_selected(hotkey)`，状态页读 `LaughMeter` / `MagicFatigue` / `Actor.buffs`（`buffs.json` 的 `desc`）/ `StatusComponent`。
- 快捷键绑定在 `GameState.hotkeys`（`use_item` = Q、`use_special` = R，默认 `DEFAULT_HOTKEYS`，`set_hotkey` 冲突时交换，信号 `hotkeys_changed`）；`PlayableCharacter.use_item(hotkey)` → `Inventory.use_hotkey`。`ItemData.hotkey` 只是默认值说明。

### HUD 道具栏与立绘反馈
- HUD 道具栏（`HUD._refresh_inventory`）：最多 `BAR_SLOTS`（3）格；`GameState.hotkeys` 绑定且有货的道具固定在前（`pinned_items`），其余进轮播（`carousel_items`，裁剪窗口里的长条每 `CAROUSEL_TIME` 秒滑一格，末尾补开头几格无缝循环）；新增 / 数量增加的道具直接转到窗口。`visible_item_ids()`、`more_count()` 给测试用。
- 立绘反馈 `PortraitFx`（`scripts/ui/portrait_fx.gd`，`Dialogue.portrait_fx`）：`Dialogue` 在 `player_registered` 时连接 `tickled` / `died`，并监听 `GameState.combo_triggered`。`on_tickled(hit, laugh)`：`Dialogue.shake_portrait`（现在常驻立绘也会抖，幅度按 `LaughMeter.stage()`）、`self_modulate` 闪光、按 `HitFx.kind_of` 在立绘锚点放大播放命中特效、失控时「哈哈」飘字、暴击金色星环；`on_combo(triple)` 爆开 `particle_heart` 心形；`_process` 让立绘下的径向渐变光晕跟着闷笑比例变浓。笑倒 CG 中、横版大框时不处理；倒下 / 换层 / CG 接管时 `clear()`。

### 攻击特效
- 命中特效 `HitFx.play(kind, parent, pos)`（`assets/generated/hit_fx.png`，10 种 × 6 帧）：`Actor.receive_hit` 生效后调用 `_play_hit_fx`——挠痒按来源选（`MonsterStats.hit_fx`、`Trap.hit_fx`，投射物看发射者），攻击一律 `slash`，暴击再叠 `crit`。新怪物 / 陷阱在 `.tres` / 场景里写 `hit_fx`。
- 粒子：`Fx.emitter(parent, kind, amount, lifetime, opts)` 持续发射（跟着父节点），`Fx.burst(parent, pos, kind, …)` 一次性爆开后自动删除；粒子贴图 `particle_{ember,goo,dust,chip,drop}.png`。

### 增益 / 减益状态
1. 在 `data/buffs.json` 的 `buffs` 里加一项，`modifiers` 只能用 `stat_kinds` 里有的属性；新属性要先在 `stat_kinds` 声明，再在读取它的代码里用 `stat_add / stat_mul / stat_flag`。
2. 在 `tools/art/gen_expansion.py` 的 `buff_icon` 里画一个 12×12 图标，`icon` 填它的序号。
3. 施加：`actor.add_buff("id", 秒)`；组合技用 `debuff` / `buff_monsters` 效果。

### 可操作角色
1. 写脚本 `extends PlayableCharacter`。通用的移动、攻击、冲刺、交互、闷笑逻辑都已经在基类里。子类只写这个角色特有的反应，例如重写 `_on_damaged`、`_on_tickled`、`_on_laugh_level_changed`、`_on_respawned`，写法可参考 `princess.gd`。
2. 场景参照 `scenes/actors/playable/princess.tscn`，复制后换掉精灵表和 `SpriteSheetConfig`（`data/actors/princess_sprites.tres`）。
3. 换一种控制方式：用 `set_controller(...)` 传入一个 CharacterController 子类。
   - `PlayerInputController`：键盘和手柄
   - `ScriptedController`：测试和过场动画
   - 以后也可以接 AI 或第二玩家

## 楼层与切换

每层一个文件夹，改某一层只需动这一个文件夹：

```
levels/floor_01/  map.txt  dialogues.json  floor.tscn
levels/floor_02/  ...
data/floors.json  楼层顺序 [{id, name, scene}]（读取入口 scripts/core/floors.gd：Floors.ids / scene / next_of）
data/dialogues.json  只放通用对话（复活、上锁提示、钥匙、失控恢复、铁栅门）
```

- `map.txt`：可选的 `[level]` 段（`intro` 开场对话、`ambient` 环境光）、`[legend]` 图例、`[map]` 地图。
- 构建：`build_level.gd -- floor=floor_02` 构建一层，`-- all` 构建 floors.json 里的全部楼层；产物 `floor.tscn` 的根节点名为 `Floor02`，并记录 `floor_id`。
- 对话：楼层根节点（`scripts/level.gd`）进入时调用 `Dialogue.load_floor(floor_id)`，把本层 `dialogues.json` 合并到通用对话上；离开后上一层的专属对话卸载。对话 id 全局唯一，与通用对话重名会报错。
- `scripts/main.gd`（主场景，组名 `main`）提供 `change_level(path)`：淡出 → 保存公主状态（`GameState.save_player_state()`：血量、闷笑值、战损）→ 换关卡 → 新关卡的公主注册时恢复 → 淡入。背包与剧情标记本来就在 GameState 中。
- 图例 `exit target=next dialogue=… w=… h=…` 放置 `LevelExit`：走进去先播对话，再切换到 floors.json 中的下一层（`target=floor_03` 可直接指定楼层）。
- 新增一层：建 `levels/floor_0N/` 的 `map.txt` 和 `dialogues.json`，在 `data/floors.json` 追加一项，运行构建器。
- 图例常用参数：陷阱 `dir=left/right/up/down`、`len=格数`、`lever=组名`（加入拉杆组）；拉杆 `target=组1,组2`；铁栅 `inverted=true`（通电关、断电开）；火把 `target=组名`（点亮时激活该组，如暗墙 `secret`）；怪物 `open_on_death=组名`。
- 对话行可以带 `"set_flag": "标记"`，显示这一行时设置剧情标记。
- 第一层 `floor_01`：牢房 → 火把走廊 → 守卫室（旁边兵器库）→ 储藏室 → 书房（火把照出暗墙 → 秘密储物间）→ 尖刺走廊 → 宝库 → 出口；走廊南侧有拉杆谜题间。
- 第二层 `floor_02`：落脚点 → 蝙蝠巢穴（东侧喷口回廊 → 蛛丝幽灵房）→ 幽灵长廊（点火把）→ 蜘蛛窝 → 机关走廊（北侧休息室；旋转刷、压力板 + 机关手）→ 巨魔大厅（Boss，掉落金钥匙）→ 金锁门 → 出口楼梯（通往第三层）。
- 第三层 `floor_03`：落脚点（学会星光爆发）→ 鼠窝 → 藤蔓迷道 → 蟹池 → 传送带工坊（西侧可选的组合试炼间）→ 风洞走廊（东侧宝物间有宝箱怪）→ 史莱姆与精灵厅 → 触手怪大厅（Boss，倒下开门）→ 出口楼梯（通往第四层）。
- 第四层 `floor_04`（地图由临时脚本生成，强制段都对应组合技）：落脚点（石碑讲暴击 / 疲倦 / 三重组合）→ 储藏室（背包）→ 水母池 → 诅咒符文走廊 → 泡泡水道（毛毯路）→ 足枷长廊 → 刑台广场（战斗房）→ 刺猬滚道（南边诅咒回廊通往可选的手套展厅）→ 图腾大厅 → 魔力水母女王大厅（Boss，倒下开门）→ 出口楼梯（第四章完，`chapter4_clear`）。

## 笑倒 CG

公主"笑倒"（`Actor.is_laugh_defeat()`：闷笑值溢出致死 `died_from_laugh`，或死时失控 >80 / 被抓住 / `LAUGH_DEFEAT_WINDOW` 2 秒内被挠过）时，`Princess._play_death_cutscene()` 接管死亡流程：倒下停 0.8 秒 → `CG.play_death(Princess.defeat_source_key())`（最后一次挠痒来源 → 本条命记录的挠痒来源 → 致命一击的怪物）→ `respawn()`（这次不播"复活"对话）。被攻击打死仍走原来的淡出复活。最后一次挠痒在 `Actor.receive_hit` 加闷笑值**之前**记录（`last_tickle`），所以致命的那一下也能查到来源。

- **播放器**：Autoload `CG`（`scenes/ui/cg_player.tscn` + `scripts/cg/cg_player.gd`），CanvasLayer 第 15 层（HUD 10 之上、对话框 20 之下）。画面右上是一个独立的像素小舞台（`dungeon.tres` 铺的地牢房间 + 径向聚光 + 边框），基础放大 2 倍；对话和立绘沿用 `Dialogue`。
- **冻结**：播放期间 `GameState.in_cutscene` 与 `in_dialogue` 都为真；`Dialogue._end()` 在 cutscene 中不交还控制权，所以一行行台词之间游戏不会动。
- **演员**：`scripts/cg/cg_actor.gd`。公主用 `princess.png` + `SpriteSheetAnimator`（按视觉状态名选行）；怪物只复制怪物场景里的 `Sprite`（不带 AI），挠痒音高取该怪物 `MonsterStats.tickle_pitch`。
- **跳过**：播完设剧情标记 `cg_seen_<id>`；再次播放时角落提示「Esc 跳过」，`CG._input` 先于暂停菜单截获 Esc。
- **横版 CG 图**：`portraits` 里写 `"wide": true` 的立绘（第三幕 `<来源键>_3`，有第二张图时第四幕 `<来源键>_4`）用 `Dialogue.set_portrait_override(tex, true)` 显示：立绘框动画变成对话框上方左侧的横版大框（高 180、宽按图片比例），挠痒时 `Dialogue.shake_portrait()` 跟着抖；舞台用 `camera` 的 `anchor` 把演员移到右侧可见处。缺素材时退回占位立绘、不用大框。CG 图由 `tools/art/import_cg.py` 从 `assets/generated/CG/<来源键>.png`（或 `<来源键>_1` / `_2`）生成（保持比例、高 360、每张单独调色板像素化）。`data/cgs.json` 由 `tools/build/gen_cgs.py` 生成：CG 图文件存在时自动加 `wide`，有 `_4` 时多一幕。
- **组合演出**：`data/combo_scenes.json`（`scenes`：组合 id → `{name, cast, steps}`，格式同 `cgs`）由 `CG.play_scene(id)` 播放，台词按键推进、随时可跳过；`CG.validate()` 一起检查。由 `tools/build/gen_combo_scenes.py` 生成（每个组合手写出场顺序和 5–6 句台词）。
- **陷阱演员**：`cgs.json` 的 `trap_actors`（`gen_cgs.py` 生成）定义陷阱的贴图、待机 / 发动帧、`tiles` 多格、`spin` 旋转、`arm` 羽毛臂；cast 里 `kind = trap:<来源键>`（`CGActor.make_trap`）。`tickle` 指令的 `by` 指到陷阱演员时它 `activate()` 发动。舞台地面在 z 0，演员层 `cast_root` 在 z 2，铺在脚下的陷阱用相对 z -1。
- **来源栏**：指令 `sources`（`list = [{kind, key, name}]`，舞台顶部三格先暗着）和 `light`（`index` 点亮第几格，`all` 三格一起闪）；`CG.source_lit(i)` 给测试用。
- **立绘接口**：`Dialogue.set_portrait_override(tex)` 替换常驻立绘（按比例放进立绘框，公主表情不会覆盖它，null 恢复）。`CG.portrait_texture(id)`：`portraits[id].file` 存在（导入过的资源或直接读 png）就用它，否则用 `placeholder` 指定的公主状态立绘。

### `data/cgs.json` 格式（一个总文件）
| 段 | 内容 |
|---|---|
| `portraits` | 立绘 id → `{file, placeholder}` |
| `actors` | 来源键 → `{scene 怪物场景, sprite: {hframes, region [x,y,w,h], scale, offset, frame}}` |
| `death` | `{by_source: {来源键: CG id}, default: CG id}` |
| `cgs` | CG id → `{name, cast, steps}` |

- `cast`：演员名 → `{kind, at [x,y], dir, hidden, scale, visual, anim}`；`kind` = `princess` / `monster:<来源键>` / `source`（致死的那只怪）。坐标以舞台地面中心为原点（像素）。
- `steps` 每一步：`portrait`（立绘 id，保持到下次更换，`none` 隐藏）、`actions`（同时开始的演绎指令）、`speaker` / `text` / `emotion`（台词，等玩家推进；`auto` 秒后自动前进）、`wait`（无台词时停留秒数，默认等指令演完）、`await_actions`（先演完指令再出台词）。
- 指令 `do`：`enter`（at, from, time）、`exit`、`move`（to, time）、`hop`（count, height）、`shake`、`face`（dir）、`pose`（公主 visual / anim / dir；怪物 style = idle / wiggle / bounce）、`tickle`（who, by, repeat, interval, fx = lines / feather / hand / heart）、`bubble`（kind）、`say`（text）、`taunt`（该怪物的随机回嘴）、`sfx`（sound, volume, pitch）、`voice`（laugh / giggle / 空）、`camera`（zoom 1 = 2 倍、1.5 = 3 倍、2 = 4 倍，focus 演员名或 [x,y]，time）、`flash`、`fade_in`、`fade_out`、`wait`。
- `CG.validate()` 检查所有引用（立绘 id、演员、指令、音效、姿势状态、death 表），`tests/cg_test.gd` 会跑它。

### 新增一段 CG
1. 在 `tools/build/gen_cgs.py` 里加一段（`add(...)`，两张 CG 图时传 `act4`），运行它重新生成 `data/cgs.json`；立绘 id 会自动登记（先用 placeholder 占位）。
2. 要按来源自动触发：在 `death.by_source` 里把来源键指到它；新怪物演员要在 `actors` 里登记场景。
3. 跑 `cg_test` 检查引用，`capture_cg -- only=<id>` 看截图。
4. 正式立绘：把 png 按立绘 id 命名放进 `assets/cg/portraits/`。

## 关卡设计：强制遭遇与锁门战斗房

- **锁门战斗房**：`scripts/objects/arena_zone.gd`（`ArenaZone`），图例 `X = arena group=<铁栅组> w=<格> h=<格>` 放在房间中央，铁栅用 `gate group=<同组> is_open=true`。触发范围比房间内部小一圈（保证公主已走过门口）；统计怪物时外扩 `margin`，战斗中新出现在范围里的怪物也要打倒。公主 `died` → 开门重置。检查点要放在战斗房外。
- **强制遭遇的做法**：风扇风道 / 传送带铺满通道宽度把人送进陷阱区（拉杆放在危险区另一侧）；羽毛、藤蔓铺满通道宽度且长度超过冲刺距离（约 41 像素）；出口摆能打组合技的怪物。
- **检查方法**：`tests/level_design_test.gd` 的 `FORCED` 表列出每个强制段的起点 / 终点格。`hazard_cells()` 从关卡里收集所有陷阱覆盖的格子（风扇 `in_lane` 的风道、传送带整条、机关手下方、压力板、其它陷阱所在格）。洪泛：允许踩危险格能走到、避开就走不到，才算"躲不开"。新增强制段时在 `FORCED` 里加一行。

## 公主状态与换美术素材

- **魔法姿态**：`princess_visuals.json` 的 `magic_order`（`chant / burst / damaged_chant / damaged_giggle_chant / damaged_burst / damaged_giggle_burst`）。`GameState.EMOTIONS` 仍是 11 种可请求的表情；`MAGIC_VISUALS` 只由 `Princess.resolve_visual()` 在 `CHANNEL`（吟唱）/ `CAST`（释放定住 `cast_time` 0.5 秒）状态下选用，优先级最高。选用规则：未战损 → 普通版；战损且闷笑值 ≤50 → 战损版；>50 → 战损闷笑版。`VISUALS = EMOTIONS + MAGIC_VISUALS` 是立绘、头像和 `EmotionComponent.row()` 的顺序。`magic_portrait_alias` 让战损闷笑释放借用战损释放的立绘。
- **多图集动画**：`SpriteSheetConfig.sheets` 定义额外图集（texture、hframes、vframes、offset、directions、row_names）。动画写 `"sheet": "magic"` 就换用该图集，行号按当前视觉状态名在它的 `row_names` 里找；不写 `sheet` 时恢复 Sprite 原来的图集。`"progress": true` 的动画帧号取 `SpriteSheetAnimator.progress`（0~1），吟唱时由 `PlayableCharacter` 设为蓄力进度。
- 魔法图集 `princess_magic.png`：48×48，每行一种魔法姿态，列 = 下/左/右/上各 8 帧；Sprite offset (0, -24)，与 32 格行走帧 (0, -16) 的脚底对齐。
- `data/actors/princess_visuals.json` 是11状态顺序的单一来源。Python导入器及 `GameState.EMOTIONS` 共同读取；对话按生成的 `portraits.json` 顺序寻址，并验证与注册表一致。
- `Princess.battle_damaged` 在实际伤害或闷笑值超过80时置位；治疗不清除，`revive()` 清除。`resolve_visual(requested)` 依次解析失控2（>100）、失控1（>80）、憋笑（>50）、战损和剧情表情；死亡独立定格。
- `EmotionComponent` 保留请求表情与时限，`current` 始终为解析后的最终状态，HUD和常驻左侧的公主立绘监听同一个变化信号。闷笑数值变化立即刷新，因此 100 边界无需新增行动等级。
- `SpriteSheetAnimator` 支持 `left` / `right` 独立方向，旧 `side` 配置继续镜像。公主图集11行×16列，方向顺序下/左/右/上，每方向4帧。
- `tools/art/import_princess2.py --preview` 从四张原图重新生成图集和预览。行走精灵用面积平均缩小（保持粉色发色）+ 只对眼睛做特征优先（`SpritePixelizer`）；立绘仍用加权众数 + 五官保护（`Pixelizer`）。失控2每方向源图两帧重复为四帧。攻击和冲刺复用对应方向帧与原有效果；死亡不用大笑姿势。
  - **表格自动定位**：用粉色格线找方向/状态分块和行，块内的帧按空白间隙切；立绘按空白列切。检测失败时退回脚本里的固定坐标。`tools/.cache/p2/grid_*.png` 显示切格结果。
  - **五官保护缩图**：源图轻度锐化；脸部区域（`princess_visuals.json` 的 `head_boxes`，默认上半身中部）内的睫毛深色、虹膜蓝、嘴、泪滴颜色固定进调色板，缩小时占比达到阈值就优先保留。
  - **立绘 2 倍像素密度**：`portraits.png` 每格 228×304、`portrait_heads.png` 每格 64×64，`portraits.json` 记录 `density: 2`。画面拉伸模式是 `canvas_items`：地图和角色仍按 480×270 整数放大，立绘在同样的显示尺寸里多一倍像素。
- `Audio.set_voice_state()` 在>80时立即启动大笑。`AudioStreamWAV.LOOP_FORWARD` 在音频线程循环，53秒附近的自然笑声经去长停顿和循环交叉淡化制成5.34秒片段。`play_voice()` 拒绝重复启动；降档、死亡或暂停停止，解除暂停恢复。来源见 `assets/third_party/moxobna_voice/License.txt`，轻笑保留cicifyre素材。
- `data/princess_reactions.json` 是**所有受挠台词的唯一文件**，由 `ReactionDB`（`scripts/core/reaction_db.gd`）读取：
  - `lines`：通用台词，按闷笑阶段 `calm / giggle / helpless_1 / helpless_2 / grabbed` 分组；`hints` 是系统提示。
  - `sources`：按来源分组，键名 = 怪物 `MonsterStats.reaction_key` 或陷阱的 `reaction_key`（粉雾继承喷口、蛛丝继承发射的蜘蛛）。每组可写 `name`、`first_encounter`（第一次被它挠痒时播放的剧情对话，格式同对话文件，会暂停战斗）、各阶段台词（缺哪档就回退到通用 `lines`）、`taunts`（怪物挠痒时按 `taunt_chance` 在头顶冒出的回嘴，`SpeechBubble` 显示）。
  - 新增怪物/陷阱的台词：给它设 `reaction_key`，在 `sources` 里加一段即可，不用改代码。
  - 公主字幕通过 `GameState.princess_reacted(text, duration)` 广播，由 `Dialogue` 的 Reaction 面板显示，不暂停战斗；同阶段 1.6 秒内不刷新，跨阶段立即更新。
  - 首次遭遇用剧情标记 `met_<key>` 记录（重新开始游戏会重置）。剧情对话期间陷阱、粉雾、投射物、抓取挠痒和状态计时都会暂停。
- 史莱姆资源明确配置 `tickle_weight=0.75`、`tickle_cooldown=0.6`、`attack_cooldown=1.2`；不可挠痒的目标仍使用普通攻击。
- 怪物挠痒动画仍写在各怪物的 `_on_tickle_performed()`；羽毛陷阱、薄荷糖由 `tools/art/gen_misc.py` 生成。

## 目录

```
scripts/core/         HitData、Faction、Contracts、ReactionDB、Floors
scripts/components/   各组件
scripts/controllers/  输入来源
scripts/actors/       Actor、PlayableCharacter、Monster、Ally 及具体角色
scripts/traps/        Trap 与具体陷阱
scripts/combat/       Projectile、WebShot、TickleCloud、StarBurst
scripts/fx/           Fx、MagicCircle
scripts/items/        ItemData 体系、Inventory、ItemDB、WorldItem、ItemDrop
scripts/objects/      宝箱、门、铁栅门、拉杆、火把、木桶、石碑、检查点、对话触发、暗墙、HitRelay
scripts/autoload/     GameState（玩家引用、背包、标记、事件总线）、Audio
levels/floor_0N/      每层的地图、对话、场景
data/                 楼层表、通用对话、组合技表、增益减益表、受挠台词、疲倦爆发台词、物品、怪物/友军数值、动画配置
tests/smoke_test.gd   冒烟测试（含11状态、音频生命周期与接口约定检查）
tests/floor2_test.gd  第二层：关卡切换、减速/抓取、新怪物、新陷阱、立绘密度
tests/floor3_test.gd  楼层表与扩充房间、魔法、状态效果、组合技、第三层怪物/陷阱、第三层流程
tests/cg_test.gd      笑倒 CG：cgs.json 校验、16 种怪物真实 AI 触发、三幕切换（横版大框、抖动）、复活、跳过、立绘接口
tests/level_design_test.gd  强制遭遇段绕不过去、锁门战斗房、各层连通
tests/floor4_test.gd  增益减益、暴击、魔力疲倦、第四层怪物 / 陷阱、组合技（三来源 / 连锁 / 新效果 / 演出）、背包、第四层流程
tools/art/import_cg.py      CG 图像素化（第三幕）
scripts/cg/           CGPlayer（Autoload CG）、CGActor
tools/art/gen_sfx.py  合成果冻挠痒、吟唱、爆发、组合技等音效
tools/art/gen_expansion.py  扩展内容占位图（魔法、第三 / 四层怪物与陷阱、状态图标、疲倦水液、暗墙、武器架）
```

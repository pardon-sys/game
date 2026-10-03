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
├── FeatherArm        伸缩羽毛臂（墙面 ON_STEP：预警后横扫前方 length 格）
├── TickleVortex      吸痒漩涡（CONTINUOUS：半径内往中心吸，冲刺可挣开）
├── BouncePad         弹弹床（ON_STEP：沿 dir 弹出 length 格，force_move bounce）
└── SoapFloor         滑溜肥皂地板（CONTINUOUS 多格：force_move slide，滑到墙 / 地板尽头 / stops_slide 陷阱）

MonsterNest（怪物巢穴基类，StaticBody2D：定时生成、吟唱联动、拖进巢穴）
└── RatHole / FairyFlower / SlimePool / JellyEgg / ChestPile

Projectile（投射物基类，Area2D；发射时记下 shooter_faction，发射者被释放后仍按它判断敌我）
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
10. 新陷阱如果覆盖多个格子，记得在 `tests/level_design_test.gd` 的 `hazard_cells()` 和 `_trap_cover()` 里补上覆盖范围，强制段和三来源触发点的检查才准。
11. 强制位移陷阱用 `PlayableCharacter.force_move(速度, 秒, kind)`：`bounce`（弹在空中，`is_airborne()`，`Trap._affects` 会跳过空中的目标）/ `slide`（撞墙停，`extend_forced_move` 续时，`end_forced_move` 结束）；期间不能操作、不能冲刺，被抓 / 定身 / 失控会打断。吸痒漩涡只用 `Actor.add_push`（冲刺中不吸）。会抓人 / 定身的陷阱设 `stops_slide = true`（加入 `slide_stopper` 组），滑行碰到就停。
12. 同一格叠放多个实体：图例用 " + " 连接，例如 `7 = trap type=stocks + trap type=vortex radius=3`。

### 部位挠痒与敏感值（数据驱动）
- **部位表** `data/actors/princess_ticklish.json`：`base_sensitivity`、`by_stage`（越笑越敏感）、`streak`（同部位连续加成）、`damaged`（战损），`zones` 每个部位 `{name, sensitivity, chance, anchor, words, icon, fx, body}`。**新增部位只改这里**，代码里不写死部位 id。现在 8 个：脚心、腋下、腰、脖子、大腿、肚子、屁股、胸。
- **新增一个部位的步骤**：① 部位表加一项；② 露出图标画在 `tools/art/gen_expansion.py` 的 `zone_icon`（`BUFF_ICON_COUNT` +1），专属特效画在 `tools/art/gen_zone_art.py` 的 `ZONE_FX`（`ZoneFx.ROWS` +1），部位表写 `icon` / `fx` / `body`；③ `data/tickle_zones.json` 给来源分配；④ 需要的话给来源写 `portrait_words.<部位>`；⑤ 跑 `tools/build/check_zones.py`。
- **来源 → 部位** `data/tickle_zones.json`：`sources.<来源键>` 是 `{部位: 权重}`，`follow_exposed` 的来源（逗弄器、转轮）总是挠露出的部位。单个怪物 / 陷阱可以用导出属性 `tickle_zones` 覆盖（图例 `zones=sole:2,armpit:1`）；都没写时按部位表的 `chance`。
- `TickleZones`（`scripts/core/tickle_zones.gd`，静态）：`pick(来源, 露出部位)`、`zone_multiplier`（含 `modifier(部位)`：被动的 `zone_sensitivity` 加减）、`body_multiplier(阶段, 战损)`、`anchor` / `words`、`validate()`（smoke 测试检查；`tools/build/check_zones.py` 列出没分配部位的来源）。`TickleZones.enabled = false` 关掉（旧测试要精确数值）。
- `Sensitivity`（`PlayableCharacter.sensitivity`）：连续加成、露出部位（`expose(来源, {部位: 倍率})` / `unexpose`，同时挂通用状态 `exposed`，`Buff.display()` 按部位动态显示名字和图标）、战损；`apply(hit, actor)` 在 `PlayableCharacter._tickle_multiplier` 里抽部位写进 `hit.zone` 并返回倍率；挠到露出部位发 `weak_point`（头上跳「弱点！」）。复活 `reset()`。
- **部位专属特效** `ZoneFx`（`scripts/fx/zone_fx.gd`，`zone_fx.png` 每行一个部位，行号 = 部位表 `fx`）：`Actor._play_hit_fx` 在 `hit.zone` 不为空时于身上 `body` 偏移处播放，`PortraitFx._zone_sticker` 在立绘 anchor 处播放（×2）；`hit.weak`（`Sensitivity.apply` 挠到露出部位时设置）时再 ×1.5、变亮。
- `TickleZones.pick` 先看来源的 `zone_focus`（部位列表：挑第一个露出的，都没露出就用最后一个；肚脐羽毛钻 `["belly", "waist"]`），再看 `follow_exposed` 和权重。
- 台词：`ReactionDB.lines(来源, 阶段, variant)`，variant 是来源的 `reaction_variant()`（落穴洞洞里的怪物，查 `sources[key].lines_by_content`）。束缚类来源的台词由 `tools/build/gen_trap_lines.py` 生成（被困时是挠痒反应，不写「放开 / 站不起来」这类陈述）。
- `PortraitFx` 按 `hit.zone` 放贴片（部位 anchor），飘字 `ReactionDB.portrait_words(来源, 阶段, 部位)`：来源按部位写的 → 来源自己的 → 部位默认 → 全局。

### 被动技能
- 数据 `data/passives/passives.json`：`id → {name, icon（passive_icons.png 的格）, max_level, levels: [{value, desc, ...}]}`；`PassiveDB.value(id)` / `value_dict(id, 字段)` 读当前等级。
- 等级存在 `GameState.passives`（换层保留、重新开始清空）；`GameState.grant_passive(id)` / `upgrade_passive(id)`，信号 `passive_changed`；对话行写 `"grant_passive": "<id>"` 也能获得。
- 「挣脱强化」`struggle_plus`：`PlayableCharacter.struggle()` 降闷笑 ×(1 + value)。背包 `Backpack.PAGES = 物品 / 被动技能 / 状态`（`PAGE_*` 常量）。

### 测试模式
- `dev_config.json`（项目根目录）+ `DevConfig`（`scripts/core/dev_config.gd`，静态）：`enabled()`（`DevConfig.override` 可在测试里强制开关）、`skip_points()`、`rewards_for(跳关点)`（`floor_rewards` 里排在目标楼层前面的各层，`rewards_through` 连这一层）、`skip_to(跳关点)`（补奖励 → `main.change_level` → 有 `cell` 时放到那一格并设检查点）。
- 暂停菜单（`scripts/ui/pause_menu.gd`）测试模式下显示 `skip_button`，展开 `skip_box` 列表。
- 背包 `PAGE_GALLERY`：`Backpack.gallery_entries()`（`death_*`、`nest_*` CG 和 `CG.scenes`）、`gallery_unlocked(条目)`（测试模式或看过：`cg_seen_<播放 id>`）、`play_selected()`。

### 地图内过场动画
- Autoload `Cutscene`（`scripts/cutscene/cutscene_player.gd`，CanvasLayer 12；章节结束画面在 30 层）。数据 `data/cutscenes/<楼层组>/<id>.json`（启动时递归建 `id → 路径` 索引，id 就是文件名，全局唯一）：`{name, skippable, hide_hud, steps}`，步骤格式同 CG；步骤还可以写 `"talk": {"file", "node"}`（await 人物对话，可以带选项）和 `"theater": id`（await 小剧场）。动作 `hold`（`who` 刑具，`on`、`place`）：合上刑具、把公主放上去、摆刑具的 `pose_offset / pose_rotation`、强制播被困动画（`PlayableCharacter.puppet_anim`），直到 `on=false`；`spawn kind=npc:<人物>` 生成一个不溜达的居民当演员；`chapter_end` 带 `next` 时结束画面显示「按 E 继续」（`continue_chapter()` 换到那一层）。演员：`princess`、关卡节点名（构建器命名为 `<类型>_<x>_<y>`，如 `Snare_10_7`、`Imp_68_64`）、`spawn` 生成的临时演员（`shadow` = 公主精灵蒙黑）。动作列表见脚本开头的注释；`validate(id)` 检查动作名。
- 播放时 `GameState.in_cutscene` + `in_dialogue` 为真（对话框不会在过场中途清掉 `in_dialogue`），所有用 `in_dialogue` 判断暂停的陷阱 / 怪物 / 状态自动暂停；公主被 `move` 时 `puppet_walking` 播走路动画。镜头动的是公主身上的 Camera2D（结束时还原到原位置和缩放）。
- 跳过：看过的过场按 Esc，剩下步骤里的 `set_flag / chapter_end / spawn / despawn / move / carry / pose / face` 立即生效。
- 触发：关卡 `[level]` `intro_cutscene`（`Level._ready`）、`DialogueTrigger.cutscene`（图例 `trigger cutscene=<id>`）、`TrapRoomZone.cutscene`、`Cutscene.play(id)` / `play_data(id, 数据)`。

### 人物对话（DialogueRunner）
- `DialogueRunner`（`scripts/dialogue/dialogue_runner.gd`）挂在 `Dialogue` 下：`await Dialogue.talk("floor_06/captain"[, 起始节点])`。台词复用对话框（`Dialogue.start_lines`），选项用 `ChoiceMenu`（`scripts/ui/choice_menu.gd`，`await ask(选项文本, 提示) -> 序号`）。
- 文件 `data/dialogues/<楼层组>/<人物>.json`（每个人物一个文件；`Dialogue.load_floor` 合并普通对话时跳过带 `nodes` 的文件）：
  ```json
  {"name": "保卫队队长", "npc": "captain",
   "entries": [{"if": {"not": "f6_opening_done"}, "node": "opening_question"}, {"if": {"eq": {"f6_attitude": "beg"}}, "node": "hello_beg"}, {"node": "hello_honest"}],
   "nodes": {
	 "hub": {"lines": [...], "prompt": "要聊什么？", "choices": [
	   {"text": "营地是做什么的？", "next": "camp", "return": true},
	   {"text": "……你还在生气吗？", "next": "still_angry", "return": true, "if": {"eq": {"f6_attitude": "defiant"}}, "once": true},
	   {"text": "没事了，再见", "next": "bye"}]},
	 "camp": {"lines": [...], "cutscene": "f6_camp_tour"},
	 "punish": {"goto": [{"if": {"eq": {"f6_attitude": "defiant"}}, "node": "punish_defiant"}, {"node": "punish_honest"}]}
   }}
  ```
  - 整段 `talk()` 期间 `GameState.in_dialogue` 保持为真（台词和选项之间、弹出选项时公主和居民都不动），结束 0.12 秒后交还控制权。
  - 选项 `return: true` = 这个分支演完回到选项页；没有 = 一路 `next` 走到结束。`if` 不满足不显示；`once` 选过一次就不再显示。
  - 节点：`lines`（`speaker` 省略 = 这个人物，`"公主"`、`""` 旁白）、`set` 效果、`cutscene` / `theater` 演绎（`perform_before` 在台词前播）、`choices`、`next`、`goto` 条件跳转。
  - 条件：`flag`、`not`、`eq {变量: 值}`、`var {变量: [">=", 数]}`、`seen "文件:节点"`、`any [...]`。效果：`flags`、`vars`、`add`、`give_item`、`coins`、`passive`、`call`（await `Dialogue` 上的 `open_shop / open_training / rest`）。
  - **选择记忆**：关键选择写进 `GameState.vars`（随存档保存），别的人物用 `entries` / `goto` / 选项的 `if` 读它。看过的节点记 `dlg_<文件>_<节点>`，选过的选项记 `dlg_<文件>_<节点>_<序号>`。
  - 检查：`python tools/build/check_dialogues.py`（节点跳转、过场 / 小剧场引用、`call` 名、读了没人写的变量；列出每个选择变量被哪些人物读取）。
- 人物表 `data/actors/npcs.json`：`{id: {name, sprite（4×4 的 32px 行走图：下 / 左 / 右 / 上）, portrait（半身立绘）, portrait_region?, princess_sheet?（用公主的行走图布局，如蓝色的公主）}}`。说话人名字和人物表里的名字一样（或台词带 `npc`）时，对话框右边显示半身立绘，左边公主立绘变暗；没有立绘的普通居民只显示名字。
- 小剧场 `data/theater/<楼层组>/<id>.json`：CG 舞台格式（`cast` + `steps`），演员 `kind` 可以写 `npc:<人物>`；`CG.play_theater(id)`，看过的可以跳过（`cg_seen_theater:<id>`）。

### 存档与主界面
- `SaveSystem`（`scripts/core/save_system.gd`，静态）：`user://saves/slot_<1~3>.json`。`save(存档位, 地点)`、`info / latest / delete`、`load_slot(存档位)`（`apply_state` 放回 GameState → `main.change_level(场景, keep_state = true)` → 站到存档位置）。测试里改 `SaveSystem.dir`。
- 主界面 `scenes/title.tscn`（`run/main_scene`）：新游戏 → `GameState.reset()` 后进 `main.tscn`；继续 / 读取 → `GameState.pending_load = 存档位` 后进 `main.tscn`，`main._ready` 黑屏读档（关卡见 `pending_load` 不播开场）。
- 存档点 `scenes/objects/save_point.tscn`（图例 `savepoint place=<地点名>`）：交互 → `SlotMenu`（`scripts/ui/slot_menu.gd`，`await choose("save"/"load") -> 存档位 / -1`，覆盖要确认）→ 保存 + 回满生命。暂停菜单 `to_title()` 回主界面。
- `GameState.play_time`（有公主且没暂停时累加）、`vars`（对话选择）、`flag_changed` 信号。

### 小镇：居民、道具、楼梯
- `Resident`（`scripts/actors/allies/resident.gd`，继承 Actor，友军，不打不挠）：图例 `npc id=<人物> dialogue=<楼层组>/<文件> wander=<格> dir=<朝向> show_flag=… hidden_flag=…`。在出生点 `wander` 格内溜达，按 E `talk()`：停下、转向公主、`Dialogue.talk(dialogue)`。`show_flag / hidden_flag` 按剧情标记出现 / 消失（监听 `GameState.flag_changed`）。
- `Prop`（`scripts/objects/prop.gd`，图例 `prop type=<种类> action=…`）：种类在 `assets/generated/town_props.json`（贴图区域、碰撞、灯光、动画）；`action`：`heal`（`Town.rest`）、`shop:<商店>`（`Town.open_shop`）、`training`（`Town.open_training`）、`talk:<文件>`、`read:<对话 id>`。
- `Town`（`scripts/core/town.gd`）：`rest(公主)`、`open_shop(id)`（`ShopUI`，`data/shop/<id>.json`，金币，库存记在 `vars["shop_<商店>_<物品>"]`）、`open_training()`（`TrainingDB`：`data/training/trainings.json`，小游戏场景 `scenes/training/<id>.tscn` 存在时 `start(id)` 返回它，现在都「还没开放」；过关奖励 `grant(id)`）。
- 楼梯 `scenes/objects/stairs.tscn`（`LevelExit` + 楼梯外观；图例 `stairs target=<楼层 id> spawn=<到达点> down=true/false`）：走进去 → `GameState.pending_spawn` → 目标关卡 `Level._ready` 把公主放到同名的 `SpawnPoint`（图例 `spawn id=…`）并设为检查点。`exit … locked=true` 是封住的入口（只播对话）。
- 楼层组：`data/floors.json` 的 `group`（`Floors.group(id)`）；同组地图共用 `data/dialogues/<组>/`（`Floors.dialogue_dir`）。

### 束缚陷阱与第五层机关
- `RestraintTrap`（`scripts/traps/restraint_trap.gd`）：`mode = grab`（`StatusComponent.grab`）或 `hobble`（`StatusComponent.hobble`：可以慢慢走、不能冲刺、攻击 / 交互键挣扎）；`exposed`（露出部位）、`self_tickle`、`group_name`（配套机关同组）、`pose_offset / pose_rotation`（`PlayableCharacter` 的姿势，`_update_lift` 里应用）、`regrab_delay`、`reach`（默认 1：触发区每边外扩 1 格，外扩那一圈要看得见——中间没墙；扣住时 `TrapReach.pull` 把人拉到 `_pull_target()`，grab 拉到扣住的位置、hobble 拉到陷阱格上；`Stocks` 同样用 `TrapReach`，并有 `regrab_delay`）。子类：`SnareTrap`、`CuffsTrap`、`ClampTrap`、`WardrobeTrap`（墙面，`sprite_hidden`）、`LegLoopTrap`、`MudTrap`（多格、越陷越慢）、`BootsTrap`、`BindingTrap`；新部位：`SupineTrap`（仰卧，`pose_rotation` −90°）、`CushionTrap`、`ProneTrap`、`PitTrap`（`content` 洞里的怪物，`extra_combo_keys` 算那种怪物）、`SpinWheelTrap`（每 `spin_time` 扫一次；放开后等她能行动时 `force_move(..., "bounce")` 甩出 `fling` 格，`landing_point()`）、`VestTrap`（hobble）。`would_grab(人)`：现在踩上来会不会被困（空闲、没在冷却、不在 regrab 免疫里）。
- 位移 / 墙面：`ChuteTrap`（痒痒滑梯，多格 + `dir`；按人的脚底位置判断在哪一段，每帧 `force_move(..., "slide")` / 延长，拐角由下一段改方向；站在 `would_grab` 的束缚陷阱上停下，刚放开的继续滑；滑行中每 `brush_interval` 秒挠一下）、`DusterWall`（墙面，探测区是墙前一行 `length` 格，`_on_warn` 按人进来的那端定 `order`，每 `step_time` 秒伸出一个掸子，扫到她所在格就挠）。关卡测试里 `_forced_maps()["chute"]` 让 `_moves` / `_flow` 顺着滑梯走。
- 配套：`TeaserTrap`（content 五种，`drill` 有 `zone_focus`）、`WheelTrap`、`ShowerTrap`（MANUAL，同组束缚困人时自动触发）。它们实现 `extra_combo_keys()`，`ComboTracker` 把这些键也记进最近挠痒（一次挠痒可以同时算多个来源）。
- 触发：`CageTrap`（PERIODIC 或加入 group 后 MANUAL；aim 跟着公主；slime / tentacle 放出 `Slime` / `MiniTentacle`）、`TripwireTrap`（公主或怪物碰到触发 targets 组；冲刺 / 空中不触发）、`PressurePlate.by_monsters`。绊线和怪物压力板在 `monster_switch` 组，`MachineImp` 会跑去踩；拉杆管的组里有被关掉的陷阱时它会去拨回来；被打就逃向拉杆。
- 构建器：图例字典参数 `exposed=sole:1.5`、`zones=...`；`trap group=` → `group_name`；`traproom`（`TrapRoomZone`）。
- 第五层迷宫（`gen_floor05.py` 的 `maze_room`）：3 格网格上的树形迷宫，主干 = 入口门 → 连锁小厅串（`hall_specs` 模板：束缚陷阱在小厅出口角，叠一条长 6 格的传送带送到下一个小厅的束缚陷阱旁边）→ 出口门（支线房间是主路尽头的宝箱）；其余节点长成死胡同，最深的放宝箱；挨着门口的其它节点不挖，免得绕开小厅。`design.json` 的 `maze_rooms`（`halls`、`door_in`、`goal`）和 `chains`（`unavoidable: true`）给关卡测试检查「小厅必经」「躲不开」「中招就连锁」。石碑由 `place_signs` 放在到新机制最短路上 SIGN_GAP 步附近，避开 `_hazard_cells()`（陷阱覆盖格、位移通道和落点、漩涡、束缚陷阱的拉人范围）和小厅车道。

### 吸附类怪物
- `LatchMonster extends Monster`（`scripts/actors/monsters/latch_monster.gd`）：自由 → 扑上（`lunge_range` 内冲刺 `lunge_time`，碰到就 `latch`）→ 吸住（`host`）。吸住时关碰撞、每帧摆到 `host` 脚下（精灵挪到 `_latch_sprite_pos()`），每 `latch_interval` 秒 `deliver_tickle(host, _latch_amount())`。`shake_once()` 计抖，够 `shake_presses` 次 `detach(方向, 晕)`；`detach()` 不带参数就是松开不晕。`anchored`：不追人、`_move` 爬回 `_home`（第一帧记下）。
- 子类：`SuctionOctopus`、`Caterpillar`（`CLIMB` 路线每 `climb_time` 换部位，靠改 `tickle_zones` 实现）、`Barnacle`（anchored）。
- 公主一侧（`PlayableCharacter`）：`latchers`、`can_be_latched()`、`add_latcher / remove_latcher`（挂 / 摘通用状态 `latched`，`Buff.display` 显示 `latch_label()`）、`latch_speed_mult()`（移速相乘）、`struggle()` 里 `shake_latchers()`（有东西吸着时攻击 / 交互键就是挣扎）、`dash()` 按 `latch_dash_chance` 甩一只、满蓄力 `release_magic` 和 `fatigue_burst` 调 `fling_latchers()`、被抓 / 倒下 / 复活 `drop_latchers()`。

### 长舌蛙、刷尾松鼠
- `TongueFrog`：`Lick` 状态 NONE → CHARGE（蓄力时锁定方向 `lick_dir`）→ OUT（`Line2D` 舌头伸出再缩回，`Geometry2D.get_closest_point_to_segment` 判定，舔中 `force_move(..., "pull")` 拉近）。
- `BrushSquirrel`：追击时目标点是 `behind_point(公主)`（在前面 / 侧面时先绕到侧面），`is_behind` 且贴身就 `_brush`，然后 `hop_time` 秒跳开。

### 怪物巢穴
`MonsterNest`（`scripts/objects/monster_nest.gd`，StaticBody2D，墙层 + breakable 层）是可复用的基类：子类在 `_configure()` 里设 `kind`（过场 CG 用）、`monster_scene`、`sheet_row`（`nests.png` 的行），需要时重写 `_prepare(怪物)`（例如 `ChestPile` 让宝箱怪 `awake`）。场景放在 `scenes/objects/nests/`，在 `TYPED_SCENES["nest"]` 注册，图例 `X = nest type=rat`（`slime` 可加 `split=true`）。
- 生成的怪物记 `Monster.home_nest`、加入 `nest_spawn` 组；吟唱额外生成的另加 `nest_extra` 组（`_update_surge`：`p.is_channeling()` 且在 `expose_radius` 内；`surge_start / surge_mult / surge_min / surge_max / surge_linger`）。
- 拖进巢穴：失控 + 贴身（`contact_dist`）→ `status.grab(nest, 0, drag_presses)`，每帧 `move_and_collide` 往 `mouth()` 拖（拖动期间和巢穴有碰撞例外），拖人的怪物跟着平移；到 `swallow_dist` 内调 `Princess.dragged_into_nest(nest)` → `dragged_into = kind` → 倒下 → `_play_death_cutscene` 播 `CG.play_nest(kind)`（`cgs.json` 的 `nest` 表）→ 复活。
- `receive_hit`（剑）扣血；`on_magic_burst`（MagicReactive）3 档直接 `smash()`、低档扣 2。`ArenaZone._collect` 也追踪没打碎的巢穴（`is_alive()`）。

### 组合技
1. 时间窗口组合：在 `data/combos.json` 的 `combos` 里加一项 `{"id", "category", "keys": [[来源键…], [来源键…]], "effects": [...]}`。每个槽位可以写多个备选键，`"*"` 表示任意怪物、`"*trap"` 任意陷阱；写 3 个槽位就是三来源组合（`category` 写「怪+怪+怪」等，效果里加 `{"type": "focus"}`）。
2. 在 `data/princess_reactions.json` 的 `combos` 段加同 id 的 `name`（横幅）、`description`、`lines`（公主台词）。
3. 三来源组合：在 `tools/build/gen_combo_scenes.py` 的 `SCENES` 里写 `(出场顺序, [阶段 1, 阶段 2, 阶段 3, 高潮 1..5])` 后运行它生成小演出。写法：开头旁白自动报组合名；阶段句是公主正被这一阶段的来源挠、边笑边说出它的手法（不说「XX 来了 / 加入了」，不直接点名）；高潮 5 句三种手法交替叠加，最后笑到说不完整（`floor4_test` 会检查句数和陈述词）。
4. 在地图上给它一个「踩不开」的触发点，并在 `tests/level_design_test.gd` 的 `COMBO_SPOTS` 里登记（见「关卡设计」）。
5. 条件型组合：写 `"condition": "说明"`，在满足条件的代码里调用 `player.combo.trigger("id", 来源)`（冷却中也要施加效果时传 `force_effects = true`）。
6. `tests/floor3_test.gd` 会自动为每个时间窗口组合跑一遍触发测试（其它组合先进冷却），并检查它有名称和台词。

### 背包与快捷键
- 背包界面 `Backpack`（`scenes/ui/backpack.tscn`，CanvasLayer 第 25 层，`PROCESS_MODE_ALWAYS`）：`GameState.has_backpack()`（剧情标记 `got_backpack`，`BackpackItem` 拾取即设置）之后输入 `backpack`（Tab / I / L3）打开并暂停；`_input` 先于暂停菜单截获 Esc。物品页 `use_selected()` / `assign_selected(hotkey)`，状态页读 `LaughMeter` / `MagicFatigue` / `Actor.buffs`（`buffs.json` 的 `desc`）/ `StatusComponent`。
- 快捷键绑定在 `GameState.hotkeys`（`use_item` = Q、`use_special` = R，默认 `DEFAULT_HOTKEYS`，`set_hotkey` 冲突时交换，信号 `hotkeys_changed`）；`PlayableCharacter.use_item(hotkey)` → `Inventory.use_hotkey`。`ItemData.hotkey` 只是默认值说明。

### HUD 道具栏与立绘反馈
- HUD 道具栏（`HUD._refresh_inventory`）：最多 `BAR_SLOTS`（3）格；`GameState.hotkeys` 绑定且有货的道具固定在前（`pinned_items`），其余进轮播（`carousel_items`，裁剪窗口里的长条每 `CAROUSEL_TIME` 秒滑一格，末尾补开头几格无缝循环）；新增 / 数量增加的道具直接转到窗口。`visible_item_ids()`、`more_count()` 给测试用。
- 粉色光晕：`shaders/portrait_glow.gdshader` 挂在 `Dialogue.portrait` 上（`PortraitFx.setup` 创建 ShaderMaterial）。mode 0 在透明处沿 12 方向 × 4 圈采样周围像素的透明度画外发光，采样限制在 `region`（`PortraitFx.glow_region()`：AtlasTexture 的格子 UV 范围）内；mode 1（横版大框）在四边内侧画晕光。`PortraitFx._update_glow` 每帧设 `strength`（`glow_target()`：游戏中按闷笑在憋笑与失控 2 之间插值，CG 中按 `CG_GLOW[cg_level]`，平滑跟随）、`pulse`（失控 / CG 中呼吸）、`mode`、`region`。注意 fragment 里的 `COLOR` 已经乘过贴图颜色，顶点色用 varying 传进来。
- 立绘反馈 `PortraitFx`（`scripts/ui/portrait_fx.gd`，`Dialogue.portrait_fx`）：`Dialogue` 在 `player_registered` 时连接 `tickled` / `died`，并监听 `GameState.combo_triggered`。`on_tickled(hit, laugh)`：`Dialogue.shake_portrait`（现在常驻立绘也会抖，幅度按 `LaughMeter.stage()`）、`self_modulate` 闪光、按 `HitFx.kind_of` 在立绘锚点放大播放命中特效、失控时飘字（`ReactionDB.portrait_words(来源键, 阶段)`：`sources[key].portrait_words` 数组或按阶段的字典，缺省回退顶层 `portrait_words[阶段]`）、暴击金色星环；`on_combo(triple)` 爆开 `particle_heart` 心形。游戏中笑倒 CG 播放时、横版大框时不处理；倒下 / 换层 / CG 换立绘时 `clear()`。
- CG 里同一套反馈：`CGPlayer._play_cg` 调 `portrait_fx.begin_cg()`，结束时 `end_cg()`；强度 `set_cg_level`：每换一张 CG 立绘（醒来除外）+1，第二幕起切幕 `cg_crit()`（金色星环，横版图放在大框右上角）；组合演出从 1 开始，公主变成失控 2 时至少 2，`light all` 高潮时 3 并 `on_combo(true)` 爆开心形。`tickle` 指令每挠一下调 `cg_tickle(来源键, hit_fx)`：来源键和贴片种类取挠她的演员（`CGActor.reaction_key` / `hit_fx`：怪物来自 `MonsterStats.hit_fx`，陷阱来自 `trap_actors[key].hit_fx`），没有演员时用致死来源键和指令的 `fx`。横版 CG 图（`Dialogue.is_portrait_wide()`）用轻量版：贴片放在图的四周（`_wide_point()`，离中心至少 `WIDE_STICKER_MARGIN`，放大 2.5 倍）、泛粉很淡、飘字沿大框两边；CG 里飘字间隔 ×1.8。没写 `portrait` 的演出（组合演出）立绘跟着舞台上公主的 `pose` 走（`CGPlayer._follow_pose`，开始用 cast 里的 `visual`）。

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

- 第五层 `floor_05`（`tools/build/gen_floor05.py` 生成地图、对话和 design.json，再运行 `build_level.gd -- floor=floor_05`）：结局过场的 `chapter_end` 设 `chapter5_clear`，带 `next: floor_06_prison`，按 E 进入第六层。
- 第六层 `floor_06_prison / upper / camp / mine`（同属 `floor_06` 组；`tools/build/gen_floor06.py` 生成四张地图、人物对话、过场、小剧场，再分别构建）：开场过场 `f6_wake`（营地地牢），之后是可以长期往返的小镇，没有敌人。

每层一个文件夹，改某一层只需动这一个文件夹：

```
levels/floor_01/  map.txt  floor.tscn
levels/floor_02/  ...
data/floors.json  楼层顺序 [{id, name, scene, group?}]（读取入口 scripts/core/floors.gd：Floors.ids / scene / next_of / group / dialogue_dir）
data/dialogues/common.json          通用对话（复活、上锁提示、钥匙、失控恢复、铁栅门）
data/dialogues/<楼层组>/signs.json  石碑；story.json 剧情；<人物>.json 人物对话（DialogueRunner）
data/cutscenes/<楼层组>/  地图内过场；data/theater/<楼层组>/  小剧场
```

- `map.txt`：可选的 `[level]` 段（`intro` 开场对话、`ambient` 环境光）、`[legend]` 图例、`[map]` 地图。
- 构建：`build_level.gd -- floor=floor_02` 构建一层，`-- all` 构建 floors.json 里的全部楼层；产物 `floor.tscn` 的根节点名为 `Floor02`，并记录 `floor_id`。
- 对话：楼层根节点（`scripts/level.gd`）进入时调用 `Dialogue.load_floor(floor_id)`，把 `data/dialogues/<楼层组>/` 里的普通对话文件合并到通用对话上；离开后上一层的专属对话卸载。对话 id 全局唯一，与通用对话重名会报错。
- `scripts/main.gd`（主场景，组名 `main`）提供 `change_level(path)`：淡出 → 保存公主状态（`GameState.save_player_state()`：血量、闷笑值、战损）→ 换关卡 → 新关卡的公主注册时恢复 → 淡入。背包与剧情标记本来就在 GameState 中。
- 图例 `exit target=next dialogue=… w=… h=…` 放置 `LevelExit`：走进去先播对话，再切换到 floors.json 中的下一层（`target=floor_03` 可直接指定楼层）。
- 新增一层：建 `levels/floor_0N/map.txt` 和 `data/dialogues/floor_0N/`，在 `data/floors.json` 追加一项，运行构建器。
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
- **组合演出**：`data/combo_scenes.json`（`scenes`：组合 id → `{name, cast, steps}`，格式同 `cgs`）由 `CG.play_scene(id)` 播放，台词按键推进、随时可跳过；`CG.validate()` 一起检查。由 `tools/build/gen_combo_scenes.py` 生成（每个组合手写出场顺序和 8 句台词：三段各 1 句 + 高潮 5 句，开头一句旁白）。
- **最后一幕「魔力爆发」**：所有 CG / 巢穴过场 / 组合演出的最后一幕（醒来之前）由 `tools/build/burst_lines.py` 的 `burst_steps(台词, 怪物名, 被震开的演员, fx)` 生成，步骤都标 `"act": "burst"`；爆发那一步写 `portrait: fatigue_burst`（`placeholder: damaged_burst`）、`sfx star_burst` + `water_release`。组合演出没有 portrait 时立绘跟着姿势走（`_auto_portrait` 只看不带 act 的步骤），遇到这一步之后改成固定立绘。
- **播放队列**：`play` / `play_death` / `play_nest` / `play_scene` 在已经有 CG 在播时排进 `_queue`（`_request` 等到轮到并播完才返回），播完一段接下一段；笑倒 CG（`play_death`）插到队首，组合演出同一段不会重复排队；`combo_scene_<id>` 标记在真正开始播时才设（`_run`）。`is_busy()` / `queued()`。
- **巢穴过场**：单独的文件 `data/nest_cgs.json`（`portraits` / `cgs` / `nest` 表：巢穴种类 → `{cg, source}`），`CGPlayer._load` 把它合并进 `data`，`CG.play_nest(kind)` 播放。由 `tools/build/gen_nest_cgs.py` 生成：它 import `gen_cgs.py`（写文件在 `main()` 里，import 时不会覆盖 cgs.json）的 `standard(..., foe=怪物键)` 生成三幕，`add_crowd()` 让第三幕 10 只同类怪物从两边涌上来、之后每句 3 只一起挠；第三幕立绘 `nest_<种类>_3`。
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
- **三来源组合的触发点**：`COMBO_SPOTS` 每个三来源组合至少一行。通道型 `[楼层, 组合, 起点, 终点, 中心]`：组合里每一种陷阱单独都必须绕不开——`_route_ok` 在格子图上 BFS，`_moves` 按强制位移建边（踩弹弹床直接到落点、飞过的不算碰到；踩肥皂地板沿方向滑到离开地板 / 撞墙 / `slide_stopper`，滑过的都算碰到），禁止碰到该陷阱的覆盖格（`_trap_cover`：风道、整条传送带、毛毯、羽毛臂扫的格、机关手下方、旋转刷 3×3……）后从起点走不到终点才算；需要的怪物在中心 `SPOT_RADIUS`（8）格内，巢穴按生成的怪物、触手怪 / 巨魔 / 水母女王按召唤的小怪算，`*` 只看数量。战斗房型 `[楼层, 组合, "arena:<组>"]`：陷阱覆盖格和怪物在 `room_rect()` 里；有足枷台的组合要求房里有漩涡中心 / 弹弹床落点 / 肥皂地板滑到的地方是足枷台。最后检查每个三来源组合都登记了。
- **第五层的 design.json**：`tools/build/gen_floor05.py` 生成 `levels/floor_05/design.json`。`combo_areas`：组合区域里要有组合的每种陷阱和怪物（落笼的 slime / tentacle 内容算对应怪物）；`chains`：`start → goal` 存在不碰静态束缚 / 位移陷阱（`_static_hazards`：束缚、传送带、弹弹床、肥皂、漩涡、风扇、足枷、毛毯、符文、藤蔓）的路（可躲），`links` 依次是束缚陷阱格，`_flow`（弹弹床落点、传送带、风道、漩涡中心）从前一个能到下一个（中招就连锁）。
- **新机制的介绍石碑**：`MECHANIC_SIGNS` 列出 `[机制, 第一次出现的楼层, 石碑对话 id]`。逐层检查：机制第一次出现的楼层要对得上，石碑对话第一句以「【机制名】」开头，从楼层起点按步数（`_distances`）石碑比机制先走到，且相差不超过 `MECHANIC_SIGN_STEPS`。新增机制时在这里加一行并在地图上放石碑（`X = sign dialogue=<id>`，对话写在该层的 `dialogues.json`）。

## 公主状态与换美术素材

- **魔法姿态**：`princess_visuals.json` 的 `magic_order`（`chant / burst / damaged_chant / damaged_giggle_chant / damaged_burst / damaged_giggle_burst`）。`GameState.EMOTIONS` 仍是 11 种可请求的表情；`MAGIC_VISUALS` 只由 `Princess.resolve_visual()` 在 `CHANNEL`（吟唱）/ `CAST`（释放定住 `cast_time` 0.5 秒）状态下选用，优先级最高。选用规则（`Princess.magic_visual`）：闷笑值超过憋笑阈值（35%）→ 战损闷笑版（不管有没有战损，没有未战损的闷笑素材）；否则战损 → 战损版、未战损 → 普通版。吟唱中闷笑变化会 `emotion.refresh()` 立即切换。`VISUALS = EMOTIONS + MAGIC_VISUALS` 是立绘、头像和 `EmotionComponent.row()` 的顺序。`magic_portrait_alias` 让战损闷笑释放借用战损释放的立绘。
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
scripts/core/         HitData、Faction、Contracts、ReactionDB、Floors（Faction / Contracts / ReactionDB.key_of / HitFx.kind_of 的参数不标类型、先判 is_instance_valid：可能传入已释放的对象，例如投射物的发射者）
scripts/components/   各组件
scripts/controllers/  输入来源
scripts/actors/       Actor、PlayableCharacter、Monster、Ally 及具体角色
scripts/traps/        Trap 与具体陷阱
scripts/combat/       Projectile、WebShot、TickleCloud、StarBurst
scripts/fx/           Fx、MagicCircle
scripts/items/        ItemData 体系、Inventory、ItemDB、WorldItem、ItemDrop
scripts/objects/      宝箱、门、铁栅门、拉杆、火把、木桶、石碑、检查点、对话触发、暗墙、HitRelay
scripts/autoload/     GameState（玩家引用、背包、标记、事件总线）、Audio
levels/<楼层>/        每张地图的 map.txt 和场景
scripts/dialogue/     DialogueRunner（人物对话、选项、条件、选择记忆）
scripts/training/     TrainingDB（训练小游戏接口）
scripts/core/         …… SaveSystem（存档）、Town（小镇设施）
scripts/ui/           …… ChoiceMenu、SlotMenu、ShopUI、TitleScreen
tests/systems_test.gd 人物对话、选择记忆、存档读档、存档点、主界面、文件迁移
tests/floor6_test.gd  第六层地图、楼梯、居民、设施、开场三种选择、第五层 → 第六层
tools/build/gen_floor06.py  第六层地图、对话、过场、小剧场
tools/build/check_dialogues.py  人物对话检查
tools/art/gen_town_art.py  小镇道具、居民、关键人物立绘、蓝色的公主、检查点、存档点
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

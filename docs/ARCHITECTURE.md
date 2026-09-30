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
│   └── TickleTroll      挠痒巨魔（小 Boss：抓取 / 僵直 / 重击）
└── Ally（友军）
	└── Knight（示例）

Trap（陷阱基类，Area2D）
├── SpikeTrap         尖刺（PERIODIC）
├── FeatherTrap       羽毛陷阱（ON_STEP）
├── PowderVent        痒痒粉喷口（PERIODIC，喷出 TickleCloud）
├── FeatherBrush      旋转羽毛刷（CONTINUOUS）
└── GrabHand          机关手（MANUAL，由压力板触发，抓取）

Projectile（投射物基类，Area2D）
└── WebShot           蛛丝（减速 + 少量挠痒）
TickleCloud（会停留的粉雾，Area2D）

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
| `StatusComponent` | `Status` | 状态效果：减速、被抓住；有它才能被抓 |
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

所有伤害和挠痒都打包成 **`HitData`**（`kind` = `ATTACK` 或 `TICKLE`，以及 `damage / tickle / knockback / source`），只通过 `receive_hit` 传递。攻击方不需要知道对方是谁：

```gdscript
target.receive_hit(HitData.make_attack(self, 1, 170.0))   # 扣 1 点血
target.receive_hit(HitData.make_tickle(self, 10.0))        # 闷笑值 +10
```

**阵营**（`Faction`：NEUTRAL / PLAYER / ALLY / ENEMY）决定谁打谁：公主和友军是一边，怪物是另一边，中立物体（木桶、陷阱）不属于任何一边。

## 核心规则

**无敌**
- 受到攻击后有 1 秒无敌，但只挡攻击，不挡挠痒。挠痒的频率由怪物自己的冷却控制。
- 冲刺时的无敌攻击和挠痒都挡。

**闷笑值**（`LaughMeter`，所有数值都可在检查器里调）
- 超过 50：进入 GIGGLING，移动速度 ×0.5，每隔 1–2.5 秒发出一次笑声（音效 `giggle` + 气泡）。
- 超过 80：进入 HELPLESS（失控 1），不能移动、攻击或交互，音效 `laugh` 在独立通道原生循环。超过 100 时切为失控 2 姿势，仍属 HELPLESS；降回 100 以下切回失控 1。
  - 连按攻击键或交互键挣扎，每按一次 -3。
- 满 150：笑到脱力，扣 1 点血（半颗心），闷笑值回落到 100。
- 受到任何攻击或挠痒后，2 秒内闷笑值不下降；之后每秒 -10。
- 薄荷糖（Q 键使用）一次 -40；友军骑士帮忙时每次 -25。

**减速与抓取**（`StatusComponent`）
- 减速：`apply_slow(倍率, 秒)`，与闷笑倍率相乘。蛛丝减速 50% 持续 2 秒。
- 抓取：`grab(抓人者, 最长秒数, 挣脱次数)`。被抓时 PlayableCharacter 进入 `GRABBED`，不能行动；连按 J/E 同时计入挣脱次数和 `struggle()`（-3 闷笑值）。挣脱或超时后 0.6 秒全无敌；松开时闷笑值仍超过 80 则直接进入失控。冲刺无敌时抓不住。
- 抓人者负责持续挠痒（巨魔每 0.5 秒 8，机关手每 0.5 秒 6），被抓期间形象、台词、笑声照常按闷笑值切到失控 1 / 2。

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

### 可操作角色
1. 写脚本 `extends PlayableCharacter`。通用的移动、攻击、冲刺、交互、闷笑逻辑都已经在基类里。子类只写这个角色特有的反应，例如重写 `_on_damaged`、`_on_tickled`、`_on_laugh_level_changed`、`_on_respawned`，写法可参考 `princess.gd`。
2. 场景参照 `scenes/actors/playable/princess.tscn`，复制后换掉精灵表和 `SpriteSheetConfig`（`data/actors/princess_sprites.tres`）。
3. 换一种控制方式：用 `set_controller(...)` 传入一个 CharacterController 子类。
   - `PlayerInputController`：键盘和手柄
   - `ScriptedController`：测试和过场动画
   - 以后也可以接 AI 或第二玩家

## 关卡与切换

- 每层是一个 `tools/build/<level>.txt`：可选的 `[level]` 段（`intro` 开场对话、`ambient` 环境光）、`[legend]` 图例、`[map]` 地图。
- `scripts/main.gd`（主场景，组名 `main`）提供 `change_level(path)`：淡出 → 保存公主状态（`GameState.save_player_state()`：血量、闷笑值、战损）→ 换关卡 → 新关卡的公主注册时恢复 → 淡入。背包与剧情标记本来就在 GameState 中。
- 图例 `exit target=dungeon_02 dialogue=… w=… h=…` 放置 `LevelExit`：走进去先播对话，再切换关卡。
- 第二层 `dungeon_02`：落脚点 → 蝙蝠巢穴（喷口）→ 幽灵长廊（点火把）→ 蜘蛛窝 → 机关走廊（旋转刷、压力板 + 机关手）→ 巨魔大厅（Boss，掉落金钥匙）→ 金锁门 → 出口楼梯（第二章完）。

## 公主状态与换美术素材

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
  - `sources`：按来源分组，键名 = 怪物 `MonsterStats.reaction_key` 或陷阱的 `reaction_key`（粉雾继承喷口、蛛丝继承发射的蜘蛛）。每组可写 `name`、`first_encounter`（第一次被它挠痒时播放的剧情对话，格式同 dialogues.json，会暂停战斗）、各阶段台词（缺哪档就回退到通用 `lines`）、`taunts`（怪物挠痒时按 `taunt_chance` 在头顶冒出的回嘴，`SpeechBubble` 显示）。
  - 新增怪物/陷阱的台词：给它设 `reaction_key`，在 `sources` 里加一段即可，不用改代码。
  - 公主字幕通过 `GameState.princess_reacted(text, duration)` 广播，由 `Dialogue` 的 Reaction 面板显示，不暂停战斗；同阶段 1.6 秒内不刷新，跨阶段立即更新。
  - 首次遭遇用剧情标记 `met_<key>` 记录（重新开始游戏会重置）。剧情对话期间陷阱、粉雾、投射物、抓取挠痒和状态计时都会暂停。
- 史莱姆资源明确配置 `tickle_weight=0.75`、`tickle_cooldown=0.6`、`attack_cooldown=1.2`；不可挠痒的目标仍使用普通攻击。
- 怪物挠痒动画仍写在各怪物的 `_on_tickle_performed()`；羽毛陷阱、薄荷糖由 `tools/art/gen_misc.py` 生成。

## 目录

```
scripts/core/         HitData、Faction、Contracts
scripts/components/   各组件
scripts/controllers/  输入来源
scripts/actors/       Actor、PlayableCharacter、Monster、Ally 及具体角色
scripts/traps/        Trap 与具体陷阱
scripts/combat/       Projectile、WebShot、TickleCloud
scripts/items/        ItemData 体系、Inventory、ItemDB、WorldItem、ItemDrop
scripts/objects/      宝箱、门、铁栅门、拉杆、火把、木桶、石碑、检查点、对话触发
scripts/autoload/     GameState（玩家引用、背包、标记、事件总线）、Audio
data/                 对话、物品、怪物/友军数值、动画配置
tests/smoke_test.gd   冒烟测试（含11状态、音频生命周期与接口约定检查）
tests/floor2_test.gd  第二层：关卡切换、减速/抓取、新怪物、新陷阱、立绘密度
tools/art/gen_sfx.py  合成果冻挠痒等音效
```

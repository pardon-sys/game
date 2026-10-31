# 架构说明

本文说明游戏里的基类、接口、组件，以及如何新增怪物、物品、友军、陷阱和可操作角色。
最前面的「接手须知」写给后续接手开发的人 / AI：工作流程、规范、用户的偏好、项目现状和剧情伏笔。动手之前先读完这一节。

## 接手须知

### 工作流程
- **分支**：每一批改动开一个功能分支（`feature/<区域>-<批次>`，例如 `feature/f6-after-b7`），做完、测试通过后 `git merge --no-ff` 合并进 `main`。
  合并提交写「合并 feature/xxx：一句话概括」。提交说明用中文，第一行概括，下面分条列；末尾加 `Co-Authored-By` 行（按当时的约定）。
  只在用户要求时提交 / 合并 / 推送。
- **永远不提交**：`dev_config.json`、`export_presets.cfg`（本地改动）、用户自己放的音频 `assets/generated/blue_princess/蓝色憋不住笑*.mp3`
  （和对应的 `.import`）、`.claude/`。提交前用 `git add -A` 后再 `git reset` 掉这些，确认暂存区里没有它们。
- **密钥**：`.env` 里的 TRIPO / ElevenLabs / GEMINI 等密钥不打印、不写进代码或提交；脚本从环境变量读。
- **环境**：Godot 4（本机路径 `/Users/zxcvbzzy1/Desktop/Godot.app/Contents/MacOS/Godot`）、Python（conda 环境 `test_for_master`）。
- **生成 → 构建 → 导入**（改了地图 / 台词 / 数据后）：
  1. 跑对应的生成器（`tools/build/gen_*.py`，例如七日赎罪是 `gen_floor06_after.py`），它从 `tools/build/<区域>_text/*.py` 读文本，写 `data/` 和 `levels/<图>/map.txt`。
  2. `python tools/build/check_dialogues.py`（对话里新增的 `call` 名要加进它的 `CALLS`）；攻防战文本另有 `check_siege_text.py`。
  3. 改了地图：`Godot --headless --script tools/build/build_level.gd -- floor=<id>`。
  4. 新增 `class_name` 脚本后 `Godot --headless --import` **跑两遍**（第一遍登记类名，第二遍才能解析引用）；导入会改动 `assets/tilesets/dungeon.tres`，
	 之后 `git checkout assets/tilesets/dungeon.tres`。
  5. 编译检查：临时写 `tests/_check_scripts.gd/.tscn`（`load` 每个改过的脚本、打印 `can_instantiate()`），跑完删掉。
- **测试**：`Godot --headless --path . res://tests/<名字>.tscn`，输出最后一行「全部通过 / 有失败 (N 项失败)」，失败项以 `[失败]` 开头。
  - 七日赎罪的改动跑 `f6_after_test`；每批合并前回归 `cg_test story_test f6_war_test level_design_test training_test siege3_test`。
  - **不要跑第 1~5 层的测试**（`floor2~5_test`，又慢又和现在的内容无关）。
  - 测试很慢（f6_after 十几分钟），放后台跑；一个测试单独一行命令，别把 `rm` 和测试串在一条里（zsh 通配符没匹配会让整条命令失败）。
  - 截图脚本放 `tests/_shots_*.gd`，输出到 `tools/.cache/shots/`（不进仓库）；临时文件 `tests/_check_scripts.*`、`tests/_shots_*`、`tests/_probe_*`
	提交前全部删掉。
- **素材**：缺的图用 Python 画像素风（`tools/art/gen_*.py`）或 Godot 内置绘制（`_draw`、粒子、tween）做；音乐用 ElevenLabs（`tools/audio/gen_music.py` 的 `TRACKS`
  加一首；生成后自动切循环：前奏只放一次，循环起点 B = 拍点网格上之后 2 秒响度回到正常的小节线（试 4 个），终点 T = B 之后节奏、和声最像的半句边界
  （波形互相关精确到采样），文件最后一拍（0.4~0.9 秒）和 B 之前的一拍交叉淡化，尾声丢掉；`--reloop` 用缓存的原始音频重新切。
  循环在 `.wav.import` 的导入设置里开（脚本写 `edit/loop_begin = B`），运行时不改流；配乐一律无损导入 `compress/mode=0`——QOA 有损压缩会给高频多的曲子添沙沙声。
  提示词别写卡祖笛、沙锤、滑哨、镲片这类嗡嗡沙沙的音色，游戏里听着像杂音；换曲时 `Audio.play_music` 旧曲淡出到 `MUSIC_OVERLAP`（三成）时新曲才从头淡入，只在都很轻时短暂重叠；淡入淡出补线性振幅、正弦缓入缓出）；第三方素材写清楚来源和许可（`assets/third_party/*/License.txt`）。
- **共性优化需求**：`docs/POLISH_RULES.md`（UI 文字不出框、超出滚动且滚动条在顶端；小剧场 / CG 立绘和精灵动态、挠痒特效叠在图上、流程长、至少一次魔力释放后被挠；
  生成人物图的服装与画风）。做 UI、演出、生成人物图前先过一遍；用户再提共性要求就追加进去。本机的 Claude Code 技能 `.claude/skills/polish-rules/` 指向它。
- **文档**：每做完一批，把新系统 / 新规则补进本文对应的章节（七日赎罪的写在「七日赎罪」一节），过时的描述直接改掉，不留两种说法；
  跳关点（`tools/build/gen_dev_skips.py`）把新加的变量 / 标记补上。

### 和用户协作的偏好
- 回复用中文、简洁；先说结果，再说要注意的事。用户会手动审核每一步操作。
- 用户试玩后会一次给一长串问题和想法：先把明确的 bug / 优化直接做，有歧义或涉及剧情走向的设计**先问**（选项式提问），再写计划。
  长的设计说明写在消息正文里——提问工具的预览框显示不全。
- 用户给定的台词**一字不改**（生成器文件开头会注明，例如 `after_text/d1.py`、`tasks.py` 里队长的「花猫样」）。
- 用户希望玩法「和挠痒结合紧」、「流程长一点」：新任务要有多个阶段、多种挠法 / 部位、反应分档，文本量充足（一个任务一般上百句）。
- 做不到 / 不做的内容直接说明原因并给替代方案，不要悄悄换掉。

### 内容准则
- 两位公主都是**成年人**（人物表 `profile`）。
- **粉色公主**：重点写脚（脱鞋袜、掰脚趾挠趾缝、刮脚心、沿足弓刷、捏脚跟）；开朗、倔强、会叫嚷反抗、边笑边求饶。
- **蓝色公主**：重点写大腿 / 屁股（揉腿根打圈、沿大腿内侧上移到腿根为止、轮流捏屁股、交界处轻刮）；寡言嘴硬、短句带省略号，越痒句子越碎，
  破防后小声服软；不用固定口头禅、不重复同一句。她身上的「千手痒痒裤」会自己动、挠她。
- 每段挠痒都用那个人 / 怪 / 陷阱**自己的工具**写具体手法；反应按闷笑分三档 `light / mid / heavy`（释放后另有 `sensitive`），同一档里给足变化。
- 简体中文，不要繁体字、日文假名；旁白用全角括号「（……）」。

### 代码规范
- **跟着周围的写法**：缩进用 Tab；注释和文档注释用中文，脚本开头 `##` 注释写清这个节点的玩法、数值常量的含义、存档变量、测试接口（参照 `task_sweep.gd`）。
  常量大写写在开头（数值都做成常量，方便调）。
- **文本不写死在 `.gd` 里**：台词、描写、反应字写在 `tools/build/<区域>_text/*.py`，生成到 `data/**.json`，脚本用静态 `data()` 读（缓存在 `static var`）。
  `data/` 下生成的 JSON 不手改，改源文件再生成。
- **测试接口**：小游戏 / 任务提供 `static var quiet`（不演对话）、`auto_*`（自动选择）和直接调用的方法（`press(键)`、`hit_once()`、`sweep(秒)`……），
  测试不模拟真实按键时序。
- **弥补任务节点**的约定：`signal finished(ok)`、`aborted`、`started`，静态 `reset_items()` / `status_text()`；离开场景树没发信号 = `aborted`。
  「小游戏画面」型继承 `TrainingStage`，`await play()` 返回结果。
- **输入锁**：剧情 / 小游戏期间靠 `GameState.in_dialogue`；小游戏和选项页要 `GameState.dialogue_holds += 1`（结束 −1），否则对话框收尾会把 `in_dialogue` 清掉。
  角色的 meta：`busy_hands`（不攻击 / 冲刺 / 施法）、`no_dash`（只禁冲刺）。
- **命名冲突**：子类成员别和父类 / 引擎重名（踩过的坑：`Node2D.hidden`、`TrainingStage._spot` / `_bar`），否则报「already exists in parent class」。
- 可复用的放 `scripts/`（组件、UI、训练框架、`RhythmLane` 这类），只属于一段剧情的放 `levels/<楼层>/scripts/`。

### 代码组织
```
scripts/            通用系统（角色、组件、陷阱、UI、对话、过场、训练框架、攻防战 scripts/siege/）
levels/<图>/        map.txt（生成）+ floor.tscn（构建）；levels/floor_06/scripts/ 是第六层组（小镇、战后七日）的剧情脚本和任务节点
data/               运行时读的数据（大多由生成器写）：dialogues/ cutscenes/ theater/ after/ siege/ characters/blue/ ……
tools/build/        生成器 gen_*.py + 文本 after_text/ siege_text/ + 检查 check_*.py + build_level.gd
tools/art/          像素图生成 / 导入；tools/audio/ 音乐音效；tools/authoring/ 写作辅助（不在生成流程里）
tests/              每个区域一个 *_test.gd/.tscn；夹具 tests/helpers/；截图 capture_*.gd
docs/ARCHITECTURE.md  本文
docs/POLISH_RULES.md  共性优化需求（UI / 演出 / 生成图的通用要求）
```

### 项目现状（截至 2026-10）
- **剧情顺序**：第 1~5 层地牢（粉色公主往上逃）→ 第 6 层地下小镇（被保卫队抓住、失忆、住进蓝色公主的小屋、训练营、潜入）→ 第 7 层升天回廊 →
  第 8 层千手之间（Boss 千手痒痒魔盘、巨石追逐、小房间过夜、蓝色公主的千手夜迷宫；之后蓝色公主身上一直穿着千手痒痒裤）→ 第 7 层归途（两人往下走、
  互问名字）→ 战时小镇 → 小镇攻防战（12 波）→ 战后的七日赎罪。
- **七日赎罪已完成**：第 1~7 天白天的事件和弥补任务、第 2/3/4/6 天晚上的任务、第 5 天夜里小汤姆的恶作剧、镇民委托、补罚任务、两位公主的玩闹；
  第 7 天修图腾柱（减 20 工时），工时还清之前停在第 7 天补罚（见「最后一天的工时」）。
- **七日赎罪的结局**：第 7 天晚上工时还清后的**庆功宴**（领舞 + 邀舞、五个摊位、放烟花 →「七日赎罪 完」），见「庆功宴」。
  庆功宴在单独的庆典广场 `floor_06_festival` 开，每个人都有庆功宴专属的对话，摊位有奖品、通关后广场换装扮。
- **骑士篇已完成**（还在地下小镇，约一层的量，序章：只埋伏笔）：发现骑士 → 醒来吼「凶手」→ 以笑为饵 → 夜探地牢 →
  诅咒失控·镇中追逃 → Boss「痒铠骑士」（四个阶段，最后一个阶段在「笑雾之中」：点亮四盏笑声灯笼、驱散骑士身上的黑雾）→ 尾声（半枚徽章「交给真正的殿下」）。两天，主线每一步都要交互才开始；
  中间穿插六个可选支线（骑士救公主、手印样本、队长的旧剑术、夜里的栅栏、没有名字的生日、点灯笼的小姑娘；每个约 20 分钟），做过的人会在最后一战来帮忙。用骑士篇自己的三张小镇图，追逃和 Boss 里没被操控的那位由 AI 搭档控制。
  之后的剧情待定，先问用户。

### 剧情伏笔（已经埋下的，写新剧情时要接得上）
下表只记录**已经写进游戏的台词和画面**，不代表结论；真相内核见表格下面（只给开发看）。
| 伏笔 | 位置 | 内容 |
|---|---|---|
| 失忆 | `gen_floor06.py` 队长审问 | 「既然什么都不记得，那就好好笑一笑，看能不能笑出点记忆来」 |
| 矿道深处的旧门 | `gen_floor06.py`、`d1.py`、`mine.py` | 封了很多年、门后偶尔有笑声、「门后面不是地面，是更深的地方」；攻防战的怪物最先从那里涌出——是粉色公主用钥匙打开的（她以为是往上的路）；矿道里的人说那扇门一直在漏光 |
| 钥匙是蓝色公主的 | `d1.py` 宣判（用户给定台词） | 「……那扇门，钥匙是我的——」被打断，没说完 |
| 千手是旧识 | `gen_floor08.py` | 蓝色公主和千手是旧识，带着惋惜和自责，从不说出它是谁 |
| 「小时候」 | `d1.py` 梦话、`tasks.py` 队长「花猫样」口误、`potion.py` 药剂师、`mine.py`、`town.py` | 蓝色公主梦话「小时候……也是……这样」；队长「你小时候一赌气去钻管道，出来也是这副花猫样」；药剂师「你和小时候的那孩子一样，喝药总皱鼻子」；蓝色公主说小时候走过矿道；队长「小时候是涂鸦，现在是裤子」 |
| 两个手拉手的小女孩 | `drain.py` 管壁涂鸦、队长的手帕 | 卷发和直发的两个小女孩手拉手，名字被苔藓盖住；队长的手帕角上绣着同样的图案 |
| 很会笑的小姑娘 | `night.py` 笑声灯笼 | 镇长：「以前每年点灯笼的，都是一位很会笑的小姑娘」 |
| 七天之后 | `drill.py`「第七天的前夜」 | 「庆功宴之后呢？」——两人对之后的去向没有说破 |
伏笔都是**点到为止**：角色只露一句、立刻岔开，粉色公主每次反问「……小时候？」都没人回答。

| 哼歌 | `festival_night.py` 烟花 | 粉色公主随口哼的小调，蓝色公主：「……这首歌，你从哪听来的。」「不知道，就会唱。」 |
| 冰雕 | `stall_ice.py` 自由创作 | 蓝色公主「手自己会动」，刻出两个手拉手的小女孩，刻完不再看它 |
| 那一天 | 骑士篇支线 ①④⑤⑥ | 镇民对「那一天」（小镇来到地下的那件事）一律避讳：小孩的「灯全灭了」被奶奶骂、奶奶回头看蓝色公主一眼；工匠的爷爷封了旧会堂；派对主人「找到我的那一天」大家不说话 |
| 两个孩子 | 支线 ③ 守夜 | 队长：「那天我从塌了的地方抱出来两个孩子。一个一直哭，一个一直笑。」 |
| 手帕的来历 | 支线 ③ 二对一 | 「……一个很爱笑的小姑娘给的。」蓝色公主问图案从哪来 |
| 点灯笼的小姑娘 | 支线 ⑥ | 蓝色公主小时候每年点西南角的旧石灯笼，以前很爱笑；井边练冰魔法时有人在旁边笑得比她还大声；储物间里「抱着它就不怕了」的布偶；小桥上手拉手的人；灯笼底座被磨掉的字只剩「给」 |
| 发卡 | 支线 ① 宝贝盒 | 小莉莉在派对主人帐篷后面捡的旧发卡，花纹和派对主人的花冠一样（她说不是她的） |
| 结尾的暗线（第四轮） | 六个支线的大图过场 | 只点到、可以误导：「骑士，不会被人认错」「派对姐姐又不是公主」（①）；奶奶「怎么想，都对不上了」看了两位公主（②）；队长说手帕上的两个小女孩「不像」你们，一个头发短、一个笑起来眯眼（③）；工匠的爷爷给「一个小姑娘」做了石灯笼（④）；派对主人和粉色都不记得生日、镇长「今天，本来就是……」被欢呼盖过（⑤）；蓝色公主记得陪她点灯的人会唱一首歌，粉色哼起了摇篮曲（⑥） |
| 摇篮曲 | 支线 ② 熬药、⑤ 八音盒 | 奶奶：「那首歌……现在只有派对那个丫头还会从头唱到尾」；派对主人从小攥着的八音盒放的就是粉色公主哼的那首（蓝色公主听完走开）；药方本里撕掉的一页「……退烧……殿……」 |

**真相内核（只给开发看，游戏里不揭开；用户给定，2026-10）**——写新剧情时按它埋线索，但台词里不要说破：
- **时间轮回，同一个人在不同时间线**：蓝色公主 = 还没有获得时间能力的粉色公主。顺序是：蓝色公主（在小镇长大）→ 获得时间能力，成为粉色公主 →
  抚养（另一条时间线上的自己）蓝色公主长大 → 经过某些事变成千手 → 千手死亡 → 变成失去全部记忆的粉色公主 → 回到圈里。
- **时间线**：小镇才是整个故事的起点，前五层地牢的时间线在小镇**之后**。第 8 层打败千手 = 一次「千手死亡」；第五层结尾把失忆的她抱走的黑影，把她带到了过去的小镇。
- **循环版的小镇来历（2026-10 用户确认）**：王国诞生在地下（这座小镇是它的前身）→ 后来搬到地面 →「那件事」又让小镇回到了地下；现在的镇民是从地面下来的一代。
  游戏里**暂时不出现地上的情节**；「那件事」镇民一律避讳，只暗示和蓝色公主有关（所以镇上的人管蓝色公主叫「殿下」）。
- **派对主人是王国真正的公主**（2026-10 用户给定）：她自己不知道，蓝色 / 粉色公主也不知道，没有任何人知道；她在那场灾难里被替代了。
  这是**整个游戏都不揭晓**的暗线：主线不提，只在支线里零碎地、间接地点到（目前只有发卡花纹、摇篮曲两处），不直接写、不让任何人说破；也可以埋误导。
- **骑士 = 未来的保卫队队长**：未来保护粉色公主时被她的「时间震荡」震进另一条时间线，在那里看到王国覆灭（所以从「来救你」变成「你是凶手」），
  又被那条时间线里的粉色公主送回来。
- **待定（不要自己定）**：她怎么变成千手、王国怎么覆灭、黑影是谁；旧门后面是什么、钥匙为什么在蓝色公主手里。
- **骑士篇的写法**：玩家能看到的「答案」都是误导（K2：「那天晚上有两个殿下，其中一个是冒牌货」）；真线索只埋三条，埋得很轻：
  骑士 = 队长（褪色的手帕、「又是这副花猫样」、剑术起手式让队长沉默）；她抚养了蓝色公主（哼歌）；千手 = 她（诅咒手印碰到粉色公主会变温和）。
  **不埋**：王国在地下、时间能力（怀表、钟停之类）。

新写的台词可以继续埋同类伏笔（一句带过、不解释），但不要替真相下结论。

## 总览

```
Actor（角色基类，CharacterBody2D）
├── PlayableCharacter（可操作角色）
│   └── Princess
│       ├── BluePrincess（蓝色公主）
│       └── BonfireHost（派对主人）
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

所有伤害和挠痒都打包成 **`HitData`**（`kind` = `ATTACK` 或 `TICKLE`，以及 `damage / tickle / knockback / source`，星光爆发另带 `tag = "magic_1~3"`；
`ignore_block` = 格挡 / 防护装备挡不住，例如装备自己发作挠自己；`tag` 可以给接收方认来源，例如盾甲螃蟹只认冰晶共鸣的 `resonance` 和冰陨星台的 `meteor`），只通过 `receive_hit` 传递。攻击方不需要知道对方是谁：

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
- 属性生效位置：`laugh_gain` 在 `Actor._tickle_multiplier`；`tickle_cd`、`special_chance` 在 `Monster`；`speed` 在移动；`can_channel` 在 `PlayableCharacter.can_cast()`；`damage_dealt`（mul）在 `HitData.make_attack` 构造时只结算一次，普通攻击与伤害魔法均生效，复制／代理转发不再乘。原 `attack` 仍只作用近战。
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
- `dev_config.json`（项目根目录）+ `DevConfig`（`scripts/core/dev_config.gd`，静态）：`enabled()`（`DevConfig.override` 可在测试里强制开关）、`skip_points()`（`dev_config.json` 的 + `data/dev/skip_points_more.json` 的：第八层之后的新内容，`tools/build/gen_dev_skips.py` 生成，每出一段新内容就加；`flags` 里 `!标记` 是清掉）、`rewards_for(跳关点)`（`floor_rewards` 里排在目标楼层前面的各层，`rewards_through` 连这一层）、`skip_to(跳关点)`（补奖励 → `main.change_level` → 有 `cell` 时放到那一格并设检查点）。
- 暂停菜单（`scripts/ui/pause_menu.gd`）测试模式下显示 `skip_button`，展开 `skip_box` 列表。
- 背包 `PAGE_GALLERY`：`Backpack.gallery_entries()`（`death_*`、`nest_*` CG 和 `CG.scenes`）、`gallery_unlocked(条目)`（测试模式或看过：`cg_seen_<播放 id>`）、`play_selected()`。

### 地图内过场动画
- Autoload `Cutscene`（`scripts/cutscene/cutscene_player.gd`，CanvasLayer 12；章节结束画面在 30 层）。数据 `data/cutscenes/<楼层组>/<id>.json`（启动时递归建 `id → 路径` 索引，id 就是文件名，全局唯一）：`{name, skippable, hide_hud, steps}`，步骤格式同 CG；步骤还可以写 `"talk": {"file", "node"}`（await 人物对话，可以带选项）和 `"theater": id`（await 小剧场）。动作 `hold`（`who` 刑具，`on`、`place`）：合上刑具、把公主放上去、摆刑具的 `pose_offset / pose_rotation`、强制播被困动画（`PlayableCharacter.puppet_anim`），直到 `on=false`；`spawn kind=npc:<人物>` 生成一个不溜达的居民当演员；`chapter_end` 带 `next` 时结束画面显示「按 E 继续」（`continue_chapter()` 换到那一层）；结束画面亮着时 `in_dialogue` 一直为真（`keep_screen`），人物不能动、按 E 不会顺手和身边的人说话。演员：`princess`、关卡节点名（构建器命名为 `<类型>_<x>_<y>`，如 `Snare_10_7`、`Imp_68_64`）、`spawn` 生成的临时演员（`shadow` = 公主精灵蒙黑）。动作列表见脚本开头的注释；`validate(id)` 检查动作名。
- 播放时 `GameState.in_cutscene` + `in_dialogue` 为真（对话框不会在过场中途清掉 `in_dialogue`），所有用 `in_dialogue` 判断暂停的陷阱 / 怪物 / 状态自动暂停；公主被 `move` 时 `puppet_walking` 播走路动画。镜头动的是公主身上的 Camera2D（结束时还原到原位置和缩放）。
- 跳过：看过的过场按 Esc，剩下步骤里的 `set_flag / chapter_end / spawn / despawn / move / carry / pose / face` 立即生效。
- 触发：关卡 `[level]` `intro_cutscene`（`Level._ready`）、`DialogueTrigger.cutscene`（图例 `trigger cutscene=<id>`）、`TrapRoomZone.cutscene`、`Cutscene.play(id)` / `play_data(id, 数据)`。
- **背景大图过场（剧情回顾）**：动作 `bg`（`img` = `assets/generated/story_scenes/<名字>.png`，`pan` = in / out / left / right / up / none）摆上整屏一张高清插画，
  `bg_clear` 收起（过场结束也自动收起）。`StoryBackdrop`（`scripts/ui/story_backdrop.gd`，Cutscene 的子节点，CanvasLayer 19，对话框 20 在它上面）：
  按 16:9 铺满、线性过滤 + mipmap（高清图不按像素放大）、慢慢推近 / 平移、换图交叉淡入淡出。只有大图和台词、id 以 `story_` 开头的过场 = **剧情回顾**：
  背包 CG 图鉴的「剧情回顾」分组（`Backpack.gallery_entries`，按过场数据的 `order` 排，看过的标记就是 `cutscene_seen_<id>`），任何时候都能回放。
  大图用 codex 内置 image_gen 生成（`tools/art/src/story_scenes/prompts.md`，参考图 `ref_style.png` 画风、`ref_characters.png` 人物），
  `tools/art/import_story_scenes.py` 裁成 1536×864；骑士篇的大图过场写在 `tools/build/knight_text/story_cg.py`（`story_base.story()` 包一层 bg / bg_clear）。

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
- 人物表 `data/actors/npcs.json`：`{id: {name, sprite（4×4 的 32px 行走图：下 / 左 / 右 / 上）, portrait（半身立绘）, portrait_region?, portrait_set?（立绘套装，按表情取格子）, princess_sheet?（用公主的行走图布局，如蓝色的公主）, light?（身上的灯光颜色）, scene?（可操作角色的场景）, profile?（角色设定：年龄 / 性格 / 怕痒的部位，写文本时照着写；两位公主都是成年人）}}`。说话人名字和人物表里的名字一样（或台词带 `npc`）时，对话框右边显示半身立绘，左边公主立绘变暗；没有立绘的普通居民只显示名字。
- 小剧场 `data/theater/<楼层组>/<id>.json`：CG 舞台格式（`cast` + `steps`），演员 `kind` 可以写 `npc:<人物>`；`CG.play_theater(id)`，看过的可以跳过（`cg_seen_theater:<id>`）。

### 存档与主界面
- `SaveSystem`（`scripts/core/save_system.gd`，静态）：`<数据根目录>saves/slot_<1~3>.json`。数据根目录 `DevConfig.data_root()`：导出的正式游戏 `user://`，在编辑器里运行 / 测试模式 `user://<dev_config.json 的 dev_data_dir>/`（隔离调试存档；以后别的玩家数据也放这下面）。`save(存档位, 地点)`、`info / latest / delete`、`load_slot(存档位)`（`apply_state` 放回 GameState → `main.change_level(场景, keep_state = true)` → 站到存档位置）。测试里改 `SaveSystem.dir`。
- 主界面 `scenes/title.tscn`（`run/main_scene`）：新游戏 → `GameState.reset()` 后进 `main.tscn`；继续 / 读取 → `GameState.pending_load = 存档位` 后进 `main.tscn`，`main._ready` 黑屏读档（关卡见 `pending_load` 不播开场）。
- 存档点 `scenes/objects/save_point.tscn`（图例 `savepoint place=<地点名>`）：交互 → `SlotMenu`（`scripts/ui/slot_menu.gd`，`await choose("save"/"load") -> 存档位 / -1`，覆盖要确认）→ 保存 + 回满生命。暂停菜单 `to_title()` 回主界面。
- `GameState.play_time`（有公主且没暂停时累加）、`vars`（对话选择）、`flag_changed` 信号。

### 小镇：居民、道具、楼梯
- `Resident`（`scripts/actors/allies/resident.gd`，继承 Actor，友军，不打不挠）：图例 `npc id=<人物> dialogue=<楼层组>/<文件> wander=<格> dir=<朝向> show_flag=… hidden_flag=…`。在出生点 `wander` 格内溜达，按 E `talk()`：停下、转向公主、`Dialogue.talk(dialogue)`。`show_flag / hidden_flag` 按剧情标记出现 / 消失（监听 `GameState.flag_changed`）。
- `Prop`（`scripts/objects/prop.gd`，图例 `prop type=<种类> action=…`）：种类在 `assets/generated/town_props.json`（贴图区域、碰撞、灯光、动画）；`action`：`heal`（`Town.rest`）、`shop:<商店>`（`Town.open_shop`）、`training`（`Town.open_training`）、`talk:<文件>`、`read:<对话 id>`。
- `Town`（`scripts/core/town.gd`）：`rest(公主)`、`open_shop(id)`（`ShopUI`，`data/shop/<id>.json`，金币，库存记在 `vars["shop_<商店>_<物品>"]`）、`open_training()`（`TrainingMenu` 选项目 / 部位 → `await TrainingDB.run(id, 部位)`，见下面「保卫队训练营」）。
- 楼梯 `scenes/objects/stairs.tscn`（`LevelExit` + 楼梯外观；图例 `stairs target=<楼层 id> spawn=<到达点> down=true/false`）：走进去 → `GameState.pending_spawn` → 目标关卡 `Level._ready` 把公主放到同名的 `SpawnPoint`（图例 `spawn id=…`）并设为检查点。`exit … locked=true` 是封住的入口（只播对话）。
- 楼层组：`data/floors.json` 的 `group`（`Floors.group(id)`）；同组地图共用 `data/dialogues/<组>/`（`Floors.dialogue_dir`）。

### 剧情调度、睡觉、潜入、角色档案
- `StoryDirector`（`scripts/story/story_director.gd`，main.gd 创建）：监听人物对话结束、过场结束、换地图，交给各层剧情脚本（`F6Story`、`AfterStory`）。`run_sequence([{level, spawn, cutscene, flag, keep_state}, …])`：跨地图的过场序列。
- `F6Story`（`scripts/story/f6_story.gd`）：话题问完 → 参观（`f6_tour_*` 过场）→ 小屋（`night`）→ 家具对话 `floor_06/house_objects`（骑马刷凳 → `f6_house_saddle` 小剧场 → `f6_blue_quiet` → 钥匙）→ 床 `call: sleep` → 早上 `f6_escape`；`on_caught()`（`StealthDirector.on_caught = f6`）→ 地牢惩罚 → 回小屋 → `Sleep`；`f7_pink_run` 结束 → `start_blue_arc()`（`blue_is_hero`）→ 出门 `f7_blue_argue` → 第七层。
- `Sleep`（`scripts/story/sleep.gd`）：`sleep(早上的过场, title, on_dawn)` / `sleep_later(…)`（对话里用）；`vars.day`、关掉 `night`、回满状态；`title` 换掉黑幕上的「第 N 天」，`on_dawn` 在黑着的时候调（`DayClock` 在这里换时间），`show_title = false` 不显示黑幕上的字（骑士篇）。对话 handler `sleep()`。
- 潜入（`scripts/stealth/`）：`VisionCone`（`sees(目标)`、墙 = 碰撞层 1、`lights` 暗处视野减半、扇形用射线截断）、`PatrolGuard`（图例 `guard_patrol path=x,y;… loop wait speed view_range view_angle investigate_speed check_chance`；`investigate(位置)` 用 `GridPath` 寻路）、`StealthDirector`（图例 `stealth active_flag on_caught alert_rate alert_decay`；`alert`、`toggle_hide`（`prop action=hide`，出来时 `exit_spot` 按下 / 上 / 左 / 右找站得下、不卡墙的位置）、`throw_stone`（输入动作 `throw`，运行时加上，F 键）、`noise(位置)`、`caught` 信号）。
- 出口 `LevelExit` 的 `lock_flag / unlock_flag / locked_dialogue / open_dialogue`（走进来那一刻正好有对话、或者 main 正在换图，人还站在出口里就等空下来再试，不会卡住）；关卡 `night_ambient`（`[level]` 段，剧情标记 `night` 时换上）；`Prop` 的 `talk:<文件>#<节点>`、`hide`、`lift`（挂墙的东西）、地面道具（`floor`）挪到 FloorObjects（`under` 铺最底下）。
- 角色档案 `Characters`（`scripts/core/characters.gd`）：按当前操控角色的 `character_id` 选数据文件——`ReactionDB`（reactions / fatigue）、`TickleZones`（ticklish）、`CG.data / CG.scenes`（cgs / nest_cgs / combo_scenes，属性按角色缓存）；`CGActor.make_princess` 按既有 `Dialogue.NPC_CHARACTER` 映射使用角色自身精灵图，并从人物表 `scene` 的Animator读取原有贴图覆盖。蓝色公主的数据在 `data/characters/blue/`（`gen_blue_character.py` 生成），派对主人在 `data/characters/bonfire_host/`（`gen_bonfire_host_character.py` 生成；基础档案与通用演出，不复制蓝色专属剧情）。
- 蓝色公主当主角：剧情标记 `blue_is_hero`；`level.gd` 载入时把粉色公主换成 `hero = true` 的 `BluePrincess`（玩家操控、相机、没有对话提示）；`main._restore_main_character` 按当前剧情主角ID恢复（该标记存在时恢复蓝色，否则粉色）；`Princess.fatigue_burst_visual()`（她是 `damaged_giggle_burst`）；`TrainingStats.zone_modifier` 只对粉色公主生效。
- 第七层 `tools/build/gen_floor07.py`：之字形高塔、`design.json` 的 8 组组合区域、两个战斗房、`f7_pink_run / f7_blue_arrive` 过场；小屋楼上 `floor_06_house_up` 和 `f7_blue_wake / f7_blue_argue` 在 `gen_floor06.py`。

### 滚动文字面板
- `ScrollTextBox`（`scripts/ui/scroll_text_box.gd`，ScrollContainer）：`make(Rect2)` 固定大小、只竖向滚动；`add_line / add_row(图标, 文字) / set_text / clear`（Label 自动换行，宽度 = 面板宽 − 滚动条）、`scroll_by(方向) / scroll_to_top / is_scrollable`。静态 `style_scrollbar(滚动条)` 是统一的像素风滚动条（对话框、暂停菜单的跳关列表也用它）。用在训练菜单（列表 + 说明，←→ 翻说明）、背包状态页（↑↓）、物品 / 被动说明。
- `DialogueRunner.end_conversation()`：当前节点演完就结束这段人物对话（不回到选项页）。

### 保卫队训练营
- 数据 `data/training/trainings.json`：`cost`（每轮金币）、`trainings[]`（`id / name / kind / desc / per_zone / per_success / bonus / stages[]`）、`zone_devices`（部位 → 刑具场景名）。`stages[i]`：`unlocked`、`caps`（这一阶段各数值的累计上限，部位类是每个部位的上限）和演出参数（训练一的 `guards / start_time / min_time`，`punish` 惩罚小剧场列表）。
- `TrainingStats`（`scripts/training/training_stats.gd`，静态）：数值存在 `GameState.vars`（`train_fatigue_up / train_fatigue_down / train_burst_power / train_resist_<部位> / train_sens_<部位>`）。`add(键, 量)` 截到当前阶段上限并返回实际加了多少；`zone_modifier(部位)`（`TickleZones.modifier` 里加上）、`laugh_bonus / hp_bonus / melee_bonus`（按 `TickleZones.zone_ids()` 均分）、`melee_damage(基础)`（`HitboxComponent`）、`fatigue_max()`、`burst_mult()`（`StarBurst.cast_fatigue`）；`apply(公主)` 套上疲倦 / 闷笑 / 生命上限（`Princess._setup` 和每轮结算调用）。
- `TrainingMenu`（`scripts/ui/training_menu.gd`）：`await choose() -> {id, zone}`，部位类先选部位；`blocked_reason(训练, 部位)`（未开放 / 金币不够 / 练满）。列表和说明都是 `ScrollTextBox`。
- 入口：训练台 prop → `Town.open_training()`（选完直接 await 训练）；人物对话的 `call: open_training` → `Dialogue.open_training()` 只 await `Town.choose_training()`，选好后 `runner.end_conversation()` 结束这段对话、`Town.start_training_later(选择)`（不 await，等对话收尾再 `TrainingDB.run`）。**训练不能在对话 runner 里 await**：runner 在跑时 `Dialogue._end()` 不会复位 `in_dialogue`，训练里读石碑 / 第一次被陷阱挠之后地图就停住了。`TrainingDB.run` 开头也会等 runner 结束。
- `TrainingDB.run(id, 部位)`：扣金币 → 创建 `scripts/training/<kind>.gd`（挂在 root 下，`TrainingDB.current`）→ `await run(训练, 部位) -> {successes, gained}` → `TrainingStats.apply` → 提示收获。
- `TrainingStage`（`scripts/training/training_stage.gd`，CanvasLayer 14）：训练一 / 三 / 四的基类。地图过场（`Cutscene.play_data`：走到营地训练位置、刑具演出版 `active = false` 摆在地图上、`hold` 固定、生成两名卫兵）→ 小游戏画面（右边 CGActor 小舞台，左上面板，下面疲倦 / 闷笑条；舞台上的台词 / 飘字在不缩放的 overlay 层）→ 数值满了 `_punish`：`CG.play_theater_subst(id, {zone, zone_name, device, device_x, device_y})` → Esc `quit()` → 结束过场，疲倦 / 闷笑恢复到训练前。训练中 `GameState.in_dialogue = true`（地图暂停），数值用 `set_value` 直接改（不触发真正的疲倦爆发 / 笑倒）。子类：`world_devices / stage_cast / intro_lines / _tick / _on_key / _after_punish / mood_ratio`；测试用 `press(键名)`、`time_scale`。
  - `qte_endure.gd`（训练一）：`PARTS`（部位 → 键）、`queue`（只有队首倒计时）、`to_call`（卫兵连喊）；`item_time / call_gap / burst_len` 随成功次数变化。
  - `qte_resist.gd`（训练三）：阶段 `rest → windup → sweep → result`，`pointer / green_c / green_w / fake`。
  - `qte_sensitize.gd`（训练四）：一段 `pending` 冲动，`current` 处理中，`DIRS[方向].opposite`。
- `maze_release.gd`（训练二，CanvasLayer 12，不继承 TrainingStage）：营地走到迷宫入口 → `GameState.pending_spawn = "maze_start"` 换到 `floor_06_training`（出口楼梯 `_used = true`，由训练判断逃离）→ `ComboTracker.play_scenes = false`，监听 `combo.triggered`（`COMBOS` 里的才算）、`magic_event("fatigue_burst")`（`DEVOTION_WINDOW` 秒内 → 再补 4 份并播 `train_release_<组合>`）、`died`。逃离冲动：`EscapeController`（继承 `WanderController`，BFS 跑向 `maze_exit` 到达点，`pace` 由 `pace_now()` 按最近 1 秒的空格次数打折，方向键加拽力），直接换 `player.controller`（不经过 `set_controller`，原控制器不释放）。结束后 `pending_spawn = "from_training"` 回营地。
- 新陷阱的特效 `TrapFx`（`scripts/fx/trap_fx.gd`，静态，Line2D / 粒子 / tween 现场画）：`snap`（十字 / X 夹合闪光）、`feather_puff`、`arc_trail`、`stroke`、`speed_lines`、`boing`、`BristleRing`（绕腿转的刷毛光环）；粒子贴图 `particle_feather / particle_bristle`（`Fx.PARTICLES`）。`LegTrap` 的钩子 `_fx_restrain / _fx_free / _fx_cycle / _fx_struggle / _fx_tick / _fx_close` 由子类重写。
- 新陷阱 `LegTrap`（`scripts/traps/leg_trap.gd`，继承 RestraintTrap）：`zone_cycle + cycle_time` 轮流挠几个部位、`struggle_speedup / struggle_extend`（轮询 `status.presses_left()` 算挣扎次数）、`ramp`、`rhythm_on / rhythm_off`（`is_armed()` 为假时 `_victims()` 为空）、`swing / lift / bob` 姿势、`bubbles`；`lock_zone(部位)` 训练用。九个子类只改导出参数（羽毛秋千加绳子、大腿刷环换帧）。
- 训练迷宫 `levels/floor_06_training/`（`gen_floor06.py` 生成，`design.json` 的 `combo_areas` 给 level_design_test）；小剧场 `data/theater/floor_06/train_endure_punish_1~3 / train_zone_punish_1~2 / train_release_<组合>`（也是 `gen_floor06.py` 生成）。

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
- 背包界面 `Backpack`（`scenes/ui/backpack.tscn`，CanvasLayer 第 25 层，`PROCESS_MODE_ALWAYS`）：`GameState.has_backpack()`（剧情标记 `got_backpack`，`BackpackItem` 拾取即设置）之后输入 `backpack`（Tab / I / L3）打开并暂停；`_input` 先于暂停菜单截获 Esc。物品页 `use_selected()` / `assign_selected(hotkey)`（物品格放在能滚动的框里，一次显示 `GRID_ROWS` 两行，选中的那格自动滚进来，不压到说明文字），状态页读 `LaughMeter` / `MagicFatigue` / `Actor.buffs`（`buffs.json` 的 `desc`）/ `StatusComponent`；←→ 只在同行的人之间切换（`status_members()` = `Party.members`，见「可操作角色」）。
- 设置菜单 P（`SettingsMenu`，见「公主状态与换美术素材」）。快捷键绑定在 `GameState.hotkeys`（`use_item` = Q、`use_special` = R，默认 `DEFAULT_HOTKEYS`，`set_hotkey` 冲突时交换，信号 `hotkeys_changed`）；`PlayableCharacter.use_item(hotkey)` → `Inventory.use_hotkey`。`ItemData.hotkey` 只是默认值说明。

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
   - `WanderController`：AI，在关卡 `wander_spot` 组的点（图例 `spot`）之间溜达（Walls + 静态物体的格子 BFS 寻路，卡住换点，到点停一会儿、偶尔做表情，公主在旁边时看她；`paused` / 对话 / 过场时不动）。`configure_area(center, radius, use_world_spots=false)` 可限定中心周围若干格，区内寻路不越界，区外先沿路返回；默认未配置时保持原行为。
4. **蓝色公主**（`BluePrincess extends Princess`，场景 `blue_princess.tscn` 继承 `princess.tscn`）：精灵图换成 `princess_blue.png`，魔法图通过 Animator 的 `texture_overrides`（`{"magic": 路径}`）换成 `princess_blue_magic.png`，`portrait_set = "blue"`；默认阵营 ALLY、相机关闭、`WanderController`；`Talk` 交互区按 E 对话；`show_flag` 控制出现；`ai = false` 时是过场演员（`spawn kind=npc:blue_princess` 生成，人物表里写了 `scene`）。
   - 场景里同时有两个可操作角色时，只有 `GameState.player` 那个是「玩家」：`Princess.is_controlled()` 为假的一方不触发台词气泡、提示、语音、剧情对话；`EmotionComponent.is_global()` 只让玩家那一个响应 `GameState.emote` 并广播 `emotion_changed`。
   - **同行的人** `Party`（`scripts/core/party.gd`）：背包状态页能看谁、按 C 能换到谁由地图元数据决定——操控的角色、跟着走的同行者（`follow`）、
	 地图 `[level]` 段 `party = 人物 id,…`（`character_id`：pink / blue / bonfire_host，构建器写进 `level.gd` 的 `party`）列出的人、
	 允许换人的场景（关卡 meta `free_switch`、`Duo.active`）里 `switchable` 的人。小镇里闲逛的派对主人等不算同行；`party` 里列出的人即使 `switchable` 关着也能换。
	 测试模式 F2 不受限。现在没有地图写 `party`（需要「这一段能切到派对主人」时在那张图的生成器 `[level]` 头里加）。
   - `GameState.switch_control(to)`（测试模式 F2，`main.switch_character()`，按场景候选顺序循环，支持第三角色；正常模式候选 = `Party.members` 里 `Party.can_switch_to` 的人）：两边交换阵营（`Actor.set_faction` 同时换节点组）、控制器（原来的那个用 `make_ai_controller()`）、相机，`player_registered` 让 HUD / 对话框重新绑定；不搬运血量 / 闷笑。换关卡前自动切回公主。
   - 立绘套装：`Dialogue.PORTRAIT_SETS`（pink / blue / bonfire_host），`portrait_for(表情, 套装)` / `head_for`；不写套装时用当前玩家的 `portrait_set`。人物表里写了 `portrait_set` 的人物（蓝色公主）说话时，右侧立绘按台词的 `emotion` 取格子。


5. **派对主人**（`BonfireHost extends Princess`，`scenes/actors/playable/bonfire_host.tscn`继承公主场景）：`character_id`／`portrait_set`均为`bonfire_host`，原`WanderController`／`ScriptedController`及`Talk`交互；F2可选中；按 C 换人不会换到她（`PlayableCharacter.switchable`，她默认 `host_switchable = false`，测试模式照旧能选），业务继续遵守`no_switch`。角色生成器定向写`data/characters/bonfire_host/`、人物表对应项和两种Buff；不会执行蓝色生成器或复制其冰魔法／裤子／迷宫剧情。弱点腋下、腰侧各1.4，其余1.0；基础数值沿用公主，魔法冷却12秒。普通、战时与战后地图构建器注册`bonfire_host`图例；战后日程沿用`AfterTown.place`，派对角色交给自身`place_schedule`与原闲逛控制器，蓝色只按真实ID识别。战时导演只配置粉蓝同行，不把她带进双人队伍。
   - **彩带普攻** `FestivalRibbon extends Projectile`：面向投掷，144像素、240像素/秒、2.5秒寿命；最多两枚、间隔0.6秒；去／回程每目标各2基础伤害和45击退，按原受击规则判定。墙体去程折返、回程阻挡消散，10像素内回收；中立木桶沿原Damageable规则可破坏，敌塔代理按原实例去重。保留Hitbox节点的原命中信号，但不再扫描近战框。独立攻击图集使用原SpriteSheetAnimator.sheets机制。
   - **随身祭典光环** `FestivalAura`：三档64／88／112像素、4／6／8秒，跟随施法者。每0.2秒给范围内单位刷新0.3秒、最多1层Buff；友方角色／士兵／雪人`festival_ally`＝移速×1.2、普攻与伤害魔法×1.4；敌方Monster含Boss的`festival_enemy`＝移速×1.2、挠痒强度×1.35。建筑和陷阱不受影响，攻击频率、机制反伤不变。退出范围自然过期；结束／死亡／换图清理，暂停／对白／CG冻结，F2不取消。重复施法取更大范围和更长剩余时间；疲倦释放为最大范围4秒，不缩短已有更长效果。Buff图标追加23／24，原图标不换序。
   - **资源与文本**：`import_bonfire_host.py`复用既有像素化器，32px四向11状态、48px六种施法、17张228×304全身立绘与64px头像；地图精灵源图和提示词在`tools/art/src/bonfire_host/`；立绘现改用用户提供的`assets/generated/bonfire_host_portraits/portraits1.PNG`与`portraits2.PNG`。第一表按普通、开心、难过、惊讶、愤怒、害羞、吟唱、释放切入既有状态顺序；第二表余下八张覆盖憋笑、战损、战损憋笑、两级失控及战损魔法。战损与两级失控按新源图裸足，战损憋笑释放共用战损释放；坐姿／横卧头像独立裁框，去白底和标签。`--portraits-only`只更新立绘及头像，地图精灵保留原源与鞋装；固定映射在导入器与manifest中。分开生成的施法源表先按同组中位高度归一，避免第六行缩放跳变。普通NPC兼容图仍导出4×4格式，原镇民生成器优先从新角色图集导出。立绘、CG、过场通过原人物映射、portrait_set及Animator.texture_overrides处理第三角色，不新增magic_sprite等第二套配置。专属长篇CG未制作，通用笑倒与空扩展集合防止误回退其他角色内容。
   - **专项**：`tests/bonfire_host_test.tscn`；截图`tests/capture_bonfire_host.tscn`。参数、失败修复、生成与截图索引见`doc/bonfire_host_character_upgrade.md`，实时进度见同目录`bonfire_host_character_upgrade_progress.md`。

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

- `map.txt`：可选的 `[level]` 段（`intro` 开场对话、`ambient` 环境光、`no_switch` 不能换人、`party` 同行的人、`style` / `iso_theme` 画面风格、`carry_light = false` 不挂冷光）、`[legend]` 图例、`[map]` 地图。
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

## 小镇攻防战（scripts/siege/）

提示时长：黄字都用默认时长（`GameState.hint` 1.6 秒、通知 `notify` 按长度 2.4~5 秒）；规则介绍走 `GameState.rule(...)`（`RULE_HOLD`，现在也是默认）。
攻防战的按键说明是一条情报（`controls`），进入攻防战、开场过场放完后自动弹出。

战时小镇城门「出发！」→ `floor_06_siege`（`tools/build/gen_floor06_siege.py` 生成地图 + `data/siege/{waves,towers,enemy_towers,intel}.json`）。
- **导演 `SiegeDirector`**（图例 `siege`）：12 波（`total_waves()`）。只有第 1 波前 / 失败重来时有准备阶段；一波的怪出完后倒计时
  `countdown`（15 秒，`next_left`）自动进下一波，场上的怪留着，提前清完立刻进；最后一波出完并清空才赢。城墙总血量归零 → 清场 → 失败小剧场
  `data/theater/siege/siege_fail_<N>[_pants].json` → 从这一波重来（冰塔保留）；第 12 波（最终波）打倒狂欢要塞 → 胜利演出 → `siege_won`。
  不设同时在场上限（`alive_cap` 写了才限制）；`ability_rate`（3）= 怪物特殊能力 / 敌塔 / 配合技冷却的缩短倍数（`SiegeDirector.ability_rate()`）。
  怪物挂 `SiegeMind`（行军大脑，`Monster.mind`），攻城怪继承 `SiegeMonster`（`siege_wander` / `block_hit` / `climb_wall`）。
  三来源组合的攻防战效果（`siege_lockup` / `siege_knockoff` / `siege_fx`）走 `combo_effect_handler`。
- **城墙** `SiegeWall` ×8（共用总血量，裂缝 3 档，冰墙加固）；梯子 `SiegeLadder`；号角 `SiegeHorn`。
- **两位公主**：`Duo` + `PlayableCharacter.ai_factory`（蓝色公主 `SiegeMageController`：城墙法师；粉色公主 `CompanionController` + `SiegeAIHooks`）；
  倒下走 `death_override`（笑倒 CG 按她自己的版本；粉色公主城门复活，蓝色公主 `Downed.timeless` + `revive_after` 40 秒兜底，
  `call_bearers` 叫士兵把她抬上城墙 / 扶起来 → `revive_blue`）。L 是她自己的魔法；城墙法术用 1~4（`SpellAim`，`pose_channel` / `pose_cast` 只摆姿势）。
  没目标时都会闲逛：`CompanionController` 的 `wander`（锚点 `BattleAIHooks.wander_anchor`）、`SiegeMageController` 墙顶巡逻、雪人、士兵。
- **友军士兵** `SiegeSoldier`（`SiegeDirector.ROSTER`：长矛兵 ×10、弓箭手 ×6、盾兵 ×3（嘲讽 `lure`、挡攻城车 `block_cart`）、医护兵 ×2、工匠 ×2、冰吟诵学徒 ×5、冰筑工匠 ×1；
  被挠撑不住就撤回城门；`add_soldiers` 增派、`bench_soldiers` 全部下场；和公主互相穿过去）。
- **自主建塔支援**：`SiegeBuilder`是冰筑工匠的订单组件，全部已解锁塔种、无数量上限；共用玩家冰晶且付款后保留30，完成后冷却30秒，只在fight自动下单，优先空基座，再查合法落点。塔种按数量少→解锁波次新→原表序选择，同时只处理一个订单，不升级或拆玩家塔。`BuildPad.request(kind, upgrade=false, reserve_crystals=0, announce=true)`统一校验付款；普通调用默认不变。学徒半速、工匠与蓝色同速，按实际在场人员`build_rate()`求和，最多两名地面协作者。`can_build()`拒绝撤退、冻结／定身、停止物理；位移离开工位停止贡献。暂停／对白／CG冻结冰光进度及自动冷却。撤退保留付费订单，学徒可接续。兵种情报由`gen_siege_support.py`定向更新，源`siege_text/build_support.py`；像素图使用`gen_siege_art.py`的builder角色。专项`siege_build_support_test.tscn`，不运行完整攻防战。
- **镇民支援** `TownBuffs`（`data/siege/town_buffs.json`，12 个：开局一个、之后每进一波一个；`mul` / `add` 读数 + 给友军挂 `town_*` 状态）
  + 过场 `TownBuffShow`（暂停、镜头推到城门 → 拉远看光点飞到友军；`TownBuffShow.enabled` 测试里关掉）。
- **小 Boss**：都继承 `SiegeBoss`（`scripts/siege/monsters/siege_boss.gd`，它继承 `TickleTroll` 的抓取 / 挣脱 / 僵直）：
  | 波 | Boss | 文件 | 技能 |
  |---|---|---|---|
  | 3 | 攻城巨魔将军 | `troll_general.gd` | 抓挠脚心 / 三连扫掌 / 地震 / 投掷上墙 / 攻城锤 / 跳劈 / 战吼 / 痒痒军旗 `TrollBanner` / 就地搭塔 / 半血狂暴 |
  | 6 | 狂风熊统领 | `gale_bear.gd` + `monsters/gale_bear/`（`GaleWind` 风弹 / 风场、`GaleVortex` 风眼） | 八向龙卷 / 风眼 / 追痒 / 风盾 / 三岔风道 / 运兵 / 熊掌 |
  | 9 | 狂欢挠痒魔偶师 | `puppet_master.gd`（机关在 `SiegeTools`） | 提线 / 换位 / 刷挠 / 刷具阵 / 痒感线 / 吊起 / 接力 / 绞盘 |
  | 12 | 狂欢攻城堡垒（最终 Boss） | `carnival_fortress.gd` + `scripts/siege/fortress/` | 六个机关（见下）+ 船员协作 |
  - `SiegeBoss` 的共用规则：冰塔 / 小雪人伤害 ×0.25（飞行中的塔弹 `HitData.from_tower`）、狂暴前只在下半场（`min_y`）、被建筑卡住先绕再穿（`_unstick`）、
	有 Boss 的波打倒它才进下一波（`SiegeDirector.boss_alive`）。
  - 共用的技能框架：数据在 `data/siege/bosses.json`（`tools/build/gen_siege_bosses.py` 生成：技能名 / 冷却 / 预警 / 喊话、出场 / 狂暴 / 打倒横幅、奖励），
	`boss_key` 选段；`skill_name / skill_cd / skill_warn / skill_shout`、`cds` + `tick_cooldowns / put_on_cooldown / mark_used`、
	预警 `track_warn`、场地 `register_field`（`clear_warns / clear_fields`，出树时自动收）、机关工具 `strike_tools`（走 `make_tickle`）、
	`announce("intro" / "rage" / "defeat")`、护卫 `spawn_escorts`（波次表的 `boss_escort`）、`reward_defeat`。测试用 `SiegeBoss.cd_table / warn_table`。
  - 预警用 `SiegeFx.warn`（敌方的传 `danger = true`），命中用 `SiegeFx.impact`（震屏 + 顿帧 `hitstop`）；立绘是 codex 生成后像素化的 `tools/art/src/siege_*`。
- **狂欢要塞**（`scripts/siege/fortress/`）：`FortressRules`（`data/siege/fortress.json` + 巨型目标几何 `point / distance`）、
  `FortressJobs`（机关调度：成对 `pairs`、增援预约、命中 / 爆炸、`FortressTarget` 吊索 / 核心、取消、`safe_pair`）←
  `FortressMechanisms`（六个机关：巡航弹 / 伸缩巨手 / 火箭运兵 / 双钩劫塔 / 交叉车阵 / 三连重炮 + 绘制）、`FortressOrdnance`（制导飞行）、
  `FortressSkills`（第十轮新增，继承 `FortressMechanisms`：龙卷发射器、传送门空降、烟花弹幕、磁吸车头，以及不进轮换的 auto 机关——
  护盾发生柱（剩 75% / 45% 血各立一次，柱子没倒完母车受伤 ×0.2，`receive_hit` 里乘）、车头舱门（每 16 秒放一排 10 辆车；登场时先排 8 辆 `release_carts`））、
  `FortressCooperation`（船员协作，名字 / 冷却在 bosses.json）、`FortressFx`（像素爆发）、`FinalReinforcements`（最终波增援配额，所有出怪来源共用；
  不经过 spawn 的子怪走 `track_child`）、`FortressFinale`（胜利演出）。
  第十轮加强（数据都在 `fortress.json`）：血量 6000 / 展开 2000、原六个机关冷却 ×0.7、机关时间线按 `1 / warn_mult` 加快（`FortressJobs.pace`，测试设回 1）、
  巨手 `hand_reach` / `hand_speed`、索敌优先站着不动最久的公主（`target_score`）；成对轮换扩成五对；剩 30% 血进**超载**（`overdrive`：每轮三个机关、
  冷却再 ×0.6、增援直接最高档）。最终波由数据决定：`SiegeDirector.is_final_fortress()`（波次表里有 `fortress_config`）。
- **攻防战配合技**：通用组件 `MonsterTeamwork` / `TeamworkEffects` 不认识攻防战；攻防战在开场注入
  `cd_divisor`（ability_rate）、`allowed_func`（siege_only 的要在战斗中、到 `min_wave`）、`can_start_func`（联合配合 `SiegeCooperation.can_start`）、
  `formation_gate_func`（最终波增援配额），并用 `SiegeTeamEffects.register()` 把自己的效果登记进 `TeamworkEffects.handlers / spawn_handlers / joint_handler`：
  `SiegeTeamEffects`（黏住 / 缠住包围、钩索接力、护卫阵、送暖炉、熊统领空运 / 滚球、魔偶师接力；先预警 `CoordinatedAction`，运送 `_transfer`）、
  `SiegeCooperation`（十种怪物 + 敌塔的联合配合，`tools/build/siege_cooperation_data.py`）；地面小队 `SiegeTeamEffects._ankle_team`（夹脚脱鞋 / 夹脚缠腿 /
  史莱姆弹射 / 熊抱触手，够不着城墙上的人）。每个配合技发动时离得最近的公主走字幕说一句：导演在 `teamwork.triggered` 里调 `SiegeTeamEffects.say_near`，
  读来源 `team_<id>` 的 `trigger`（粉 / 蓝各一套，`tools/build/siege_text/team_lines.py`；`say` 有 `SAY_GAP` 冷却，效果落下时再叫也不会说两遍）。
- **开发工具**：暂停菜单「测试：攻防战」页（`scripts/dev/siege_dev_tools.gd`，只在 `DevConfig` 打开时）：跳波次、摆 / 升级 / 清空测试冰塔。
- **法术** `SiegeSpells`（冰锥雨 / 冰晶结界 / 清凉雪花 / 冰墙加固 / 暴风雪 `Blizzard` / 冰川突刺 / 冰镜分身 `IceMirror`，1~7 键，射程 640；
  瞄准时镜头跟着准星：`PlayableCharacter.camera_bias`；大震屏走 `shake_camera`）；**镜头** `SiegeCamera`（滚轮 / - / = 缩放，V 全景）；**HUD** `SiegeHud`；**情报** `SiegeIntel`（H / 点击）。
- **冰塔** `BuildPad`（运行时基座：粉色公主按 B `try_build`，`build_blocked` 判断能不能建；存 `vars.siege_towers = [{x, y, kind, level}]`）+ `IceTower`（6 种 × 2 级）；
  **敌塔** `EnemySite`（全地图 30 个地基）+ `EnemyTower`（10 种）：地精工兵 `GoblinEngineer` 挑最近的空地基搭（进度条，冻住暂停 / 倒退），怪物聚集 5 只也会搭；
- **怪物配合技**（可复用组件，不限攻防战）：`MonsterTeamwork`（`scripts/components/`，读 `data/teamwork.json`，`tools/build/gen_teamwork.py` 生成）
  每 0.5 秒凑齐就发动，`spawn_formation(id, at)` 成套生成；效果在 `TeamworkEffects`（按 `effect.type` 分派：投掷、合体、举手、脱鞋、吸盘、
  舞会、泡泡、充能、滚球、活梯子 `LivingLadder`、护卫阵、空投、工兵护送）。波次 `groups` 里写 `formation` 项；墙顶通用行为在 `SiegeMind.wall_top`。
  **陷阱** `scripts/siege/hazards/`（龙卷风、泡泡潮、痒感连线、羽毛扫帚、迷雾；城墙爬藤 / 黏网 + 冰链 = 牺牲互救，`SiegeDirector.rescue`）。
  大型强制位移陷阱（第 3~12 波，`gen_floor06_siege.py` 的 `NEW_HAZARDS`）：天降抓娃娃机 `HazardClaw`（影子追人 → 落下抓住 `status.grab` → 吊着运到怪最多处、
  爪子里的刷子一路挠 → 放下）、挠痒流沙旋涡 `HazardQuicksand`（吸向中心、陷住挠；挂 `siege_dragged / siege_dragger`，冰链救援调 `release_drag`）、
  弹弹蘑菇阵 `HazardMushrooms`（9 颗蘑菇，最多拐两次弯，踩到就 `force_move("bounce")` 连弹进怪堆）、挠痒传送门 `HazardPortalPair`（双向：公主和怪走进哪扇门
  都从另一扇出来；法术落在门上 `SiegeHazard.notify_spell` → `on_spell` 冰封一会儿，蓝色公主的 AI 会用冰锥雨封门）。能不能卷 / 吸 / 弹怪统一看 `SiegeTools.displaceable`。
  第十轮：大型陷阱频率约 ×2（第 3 波 3 个 → 第 12 波 7 个）、范围 ×1.4；**陷阱和怪物的配合**（共用工具在 `SiegeHazard`：`fling_to_wall` 把怪甩上墙顶、
  `fling_to`、`ambush` 放伏兵，伏兵挂 meta `siege_hazard_spawn`）：龙卷风卷怪（冻住的也卷）全部甩到粉色公主身边；抓娃娃机没抓到公主就抓一把怪
  运到墙顶 / 公主头顶扔下；流沙每 3 秒钻出伏兵、公主陷住时附近的怪全围过来；蘑菇把怪一路弹到尽头弹上墙；传送门每 4 秒从一扇门涌出小怪；
  黏网罩住公主时爆出伏兵（粉色公主挠脚鼠 / 蓝色公主腿根爬爬蛛）。
  战场：怪物出生钻地 `SiegeFx.burrow`（`quiet_spawn` 关掉）、`SiegeMind` 斜着走向目标墙段（`march_x`）+ 触须避障（`avoid`）、
  `_clamp_monsters` 不出地图、`enemies_near` 用空间网格；城墙 `z_index -1` + 墙脚挡人窄条（`FOOT_STRIP`）；
  冰塔加篝火（`torch` 组，幽灵现形）/ 冰棱弩炮（穿透 + 末端冰花、打敌塔 ×3）/ 热可可摊；冰锥 / 寒霜 / 雪球都有范围伤害；
  随波次解锁（`unlock_wave`）：冰霜迫击炮、冰风旋涡、冰晶共鸣、冰陨星台、温泉治疗泉、冰灯（敌塔变慢 `lamp_slow_at`）、冰盾发生器（`ice_shield`）；
  所有塔 3 级（`IceTower.MAX_LEVEL`）；活梯子 `LivingLadder` 是敌方 Actor（`siege_enemy_tower` 组，受击范围高过墙顶，转给离攻击者最近的壁虎 / 正在爬梯子的怪 meta `ladder_of`）；
  每波特色 `WaveFeatures`（`waves.json` 顶层 `features` 定义 + 每波 `features` 列表；`SiegeDirector.features`，开打时 `begin`）：迷雾之夜变暗、攻城大队、狂风、
  抢掠小队（`RaiderMind` 拆冰塔 `IceTower.raid_hit`、基座留着）、羽毛暴风雪、狂欢节、工兵狂潮 / 痒痒装备日的倍率 `WaveFeatures.mul_of`；HUD 小地图下挂标签；
  配合技冷却 `MonsterTeamwork.cd_scale` 随波次变小；配合技 / 陷阱组合不进情报；攻防战里的旧 Boss 当小怪（`SiegeDirector._as_minion`），不掉钥匙；
  小 Boss 冰塔伤害 ×0.25、狂暴前待在下半场（`TrollGeneral.min_y`）；蓝色公主看门狗 `_blue_watchdog`、`downed_never_fails`；
  活梯子打倒一只就散（`LivingLadder.start_count`）；有小 Boss 的波打倒它才进下一波（`SiegeDirector.boss_alive`）；小 Boss 被建筑挡住先绕、再穿过去（`TrollGeneral._unstick`）；
  蓝色公主的 AI `SiegeMageController` 继承 `CompanionController`（挣扎 / 闪避 / 打墙顶的怪 / 墙下救人）；敌方预警 `SiegeFx.warn/lane(..., danger = true)` 进 `danger` 组；
  冰吟诵学徒（士兵 `mage`）帮忙放冰光：`BuildPad` 改成进度制（蓝色公主 1 / 秒、学徒 `HELPER_RATE` 0.5 / 秒，`reserve` 认领位置）；基座贴图在 `SiegeDirector.decals()` 层；
  城墙灯 `SiegeWall.WallLight`（火盆在 `torch` 组）；
  物理被关掉的 Actor（活梯子里的壁虎）由接管方调用 `Actor.tick_timers` 走受击无敌 / 增益倒计时；
  蓝色公主 AI 放法术更勤（`THINK` 0.2、门槛降低，AI 施法冷却 / 疲倦 × `SiegeSpells.AI_CD` / `AI_FATIGUE`），粉色公主吟唱时 `JOIN_PINK` 50% 跟着放（`join_pink`）；敌塔整个塔身可打（`HurtProxy`）、血条、范围 / 蓄力 / 崩塌特效。
  陷阱和怪物配合：龙卷风卷怪、迷雾里的怪打不到（meta `in_fog`，`enemies_near(..., false)`）、泡泡运兵；陷阱组合 `spawn_hazard_combo`（波次 `hazards` 里写 `combo`）。
- **难度**：怪物血量 / 挠痒保持原值，难度走机制（怪物挑薄弱墙段、号手指挥官，见下）；`waves.json` 顶层 `difficulty {build, team_cd}`
  （`SiegeDirector.difficulty(键)`）——怪物搭敌塔 ×1.3（`EnemySite`）、配合技冷却 ×0.75（`cd_divisor`）。
- **怪物挑薄弱处**：`SiegeDirector.wall_weakness()`（每段墙 `1 / (1 + 守备)`：射程覆盖墙中心的冰塔数、冰盾 +2、蓝色公主站在这段 +1.5，缓存 `WEAK_GAP` 4 秒）、
  `pick_weak_x(from_x)`（按薄弱分² / 距离加权随机挑一段）；`SiegeMind.march` 离墙脚还远（`REPICK_Y`）时每 4 秒重挑 `march_x`，成套小队（meta `march_lock`）不换。
- **号手指挥官** `HornBugler`（配合技 `bugler_squad`，第 4 波起成套出现）：号手在前、其余 10 只排成每排 4 个跟着（`SiegeTeamEffects._bugler_formation`，`escort_of`）；
  号手离墙脚 `RALLY_Y` 以内吹冲锋号，整组挂 `siege_rally`（城墙伤害 ×1.2 走 `stat_mul("wall_damage")`、移速 ×1.15，每 3 秒续），散开冲到号手那段墙下；
  号手倒下整组挂 meta `scatter_until`（3 秒乱走，`SiegeMind.wander`），之后各自重新挑墙段。
- **蘑菇吸附**：`HazardMushrooms` 每颗蘑菇把 `PULL_R`（帽子外一格）以内的公主（冲刺中不吸）和可推动的怪往帽上吸（`add_push`，吸力很大、走路挣不开），吸到帽上照常弹走。
- **撤退**（暂停菜单）：`retreat()` 先 `_busy` + 切 `retreat` 状态再清场，存档 `siege_wave` 保持当前波（从准备阶段重来，不会被当成清完了跳到下一波）。
- **攻城车**：冲锋路上 `SMASH_R` 以内的冰塔（诱饵冰雕除外）每次扣最大生命25%（整数向上取整），摧毁后基座留着，车撞晕 3 秒（`SMASH_DAZE`）后重新瞄准再冲；撞到粉色公主闷笑 +50%（`PINK_LAUGH`）。
  攻城大队每 14 秒两排共 9~11 辆（`WaveFeatures.CORPS_*`）；最终波固定开着攻城大队和狂欢节（`FINAL_FIXED`，开打 2 秒就来）。
- **盾甲螃蟹**：冰塔 / 塔弹 / 法术 / 士兵全挡；只有冰晶共鸣的电弧和冰陨星台的陨石（`HitData.tag` 是 `ShieldCrab.RESONANCE_TAG` / `METEOR_TAG`）打得动、造成100%伤害；
  粉色公主的锤子背后打得动、正面挡。
- **暖炉史莱姆**：冰晶共鸣与冰陨星台的标签攻击造成100%伤害；仍免疫其他冰塔及蓝色公主的攻击，仍冻不住／不减速，贴塔融化规则保留。专项 `siege_special_tower_damage_test.tscn`；修订记录 `doc/siege_special_tower_damage.md`。
- **拆塔投石车**（敌塔 `catapult`，第 6 波起）：挑射程里血最多的冰塔，落点影子亮 1.2 秒后砸下（`CatapultStone`），影子里的冰塔掉 60% 血上限；
  粉色公主站进影子替塔挡下（石头碎成羽毛挠她一下）。
- **狂欢要塞的巡航弹 / 巨手**：巡航弹炸到人时闷笑直接涨上限的一半（`FortressOrdnance.MISSILE_LAUGH`，`explode(…, laugh_ratio)`）；
  巨手抓住人后强制拖走 `HAND_DRAG`（往这只手那一侧斜着拖，`SiegeTools.Hold` 的 `speed` / `slide`：碰到障碍顺着滑开），松手时顺着拖的方向再甩 `HAND_FLING`。
- **胜利后**：`TownBuffs.clear_all()` 撤掉 12 个镇民支援（友军身上的 `town_*`、`vars.siege_town_buffs`）；`stage_victory()` 把操控切回粉色公主、
  两个人摆到城门前（`VICTORY_CELL` 两侧，蓝色公主节点改名 `SiegeBlue`）→ 过场 `siege_won`（`gen_floor06_siege.py` 的 `CHEERS`）：镜头拉远到整个战场，
  十二位激励镇民按波次顺序从城门出来、各说一句、站成半圆（演员 `cheer_<激励 id>`，行走图用 `town_buffs.json` 的 `sheet`），镇长宣布祭典，
  烟花（过场动作 `fireworks`：`at` 格子列表、`count`、`time`）→ 战后的小镇（`floor_06_after`，见「七日赎罪」）。
- **临时痒痒装备**：`Equipment.force` / `release` / `tick_forced`（`GameState.equip_forced`），负面装备由 `EquipFx` 定时发作 + 立绘反应（`data/equip_reactions.json`，分角色）。
- **战败 CG**（失败小剧场第 4 幕的横版大图，一波一张）：原图 `assets/generated/SIEGE_CG/siege_fail_<N>.png`（codex 内置 image_gen 生成，1536×1024，
  提示词和参考图在 `tools/art/src/siege_fail/`：两人释放过魔力、被这一波的怪接着挠——粉色被挠光脚、蓝色被挠大腿；服装照立绘，不画千手痒痒裤，`_pants` 版也用同一张）
  → `tools/art/import_cg.py --siege` 像素化到 `assets/cg/portraits/siege_fail_<N>.png` → `gen_cgs.py` 登记立绘 id（有图时 `wide`）。
- 内容生成器：`gen_siege_monsters.py`（场景）、`gen_siege_cgs.py`（笑倒 CG，粉 / 蓝两版）、`gen_siege_scenes.py`（三来源组合小演出）、
  `gen_siege_theaters.py`（失败小剧场）、`gen_siege_reactions.py`（受挠台词）、`gen_siege_bosses.py`（Boss 技能 / 横幅、要塞数据）、
  `gen_teamwork.py`（配合技，联合配合的数据在 `siege_cooperation_data.py`）、`tools/art/gen_siege_art.py`（像素图）、`gen_fortress_v2.py`（要塞美术）。
  文本在 `tools/build/siege_text/`（生成器只负责拼装，见下面「攻防战文本」）；`tools/authoring/rewrite_siege_gemini.py` 是不在生成流程里的写作辅助
  （提示词在 `tools/authoring/prompts/`，读 `siege_text` 的 Boss 文本，审过的定稿写到 `tools/.cache/` 由人手合并）。
- **攻防战文本**（`tools/build/siege_text/`，全部手写，粉色 / 蓝色公主各一版）：
  | 文件 | 内容 | 拼装 |
  |---|---|---|
  | `cgs_1/2/3.py`、`cgs_bosses.py` | 16 段笑倒 CG（12 种攻城怪约 29 句、4 个 Boss 约 40 句） | `gen_siege_cgs.py` → `data/siege_cgs.json`（+ 蓝色版） |
  | `theaters.py` | 12 段失败小剧场（30 句，照每一波的特色写：泡泡潮 / 空降 / 巨魔军团 / 迷雾 / 攻城大队 / 狂风 / 装备日 + 藤蔓 / 工兵 + 抢掠 / 魔偶师 + 羽毛雪 / 狂欢节 / 风卷巨魔泡泡 / 要塞操作台；蓝色公主的句子另有千手痒痒裤版；两人爆发、怪回来以后有一段「释放后被接着挠」：怪用自己的工具专挑弱点，粉色边笑边求饶、蓝色越说越碎） | `gen_siege_theaters.py` → `data/theater/siege/`（被抓住后公主说话的每一句自动补 `tickle`；立绘按幕换表情 `EMOTION`；第 4 幕第一步换上战败 CG `siege_fail_<N>`） |
  | `scenes_1/2/3.py` | 23 组三来源组合演出（约 32 句；机制在 `gen_siege_scenes.py` 的 `MECH`） | `gen_siege_scenes.py` → `data/siege_scenes.json`（+ 蓝色版）、`combos.json` |
  | `reactions_1/2.py`、`reactions_bosses.py` | 攻城怪 / 敌塔 / 陷阱 / 临时装备 / Boss（按技能）的受挠台词 | `gen_siege_reactions.py`（`siege_sources(who)`）→ 两份 `reactions.json` |
  | `team_lines.py` | 39 个配合技的发动字幕 + 怪物回嘴 | 同上 |
  - **四幕**（CG / 小剧场 / 组合演出的每一步都标 `act`）：1 被抓住、嘴硬 → 2 弱点被找到、开始破功 → 3 魔力疲倦满了、爆发（`act = "burst"`，
	立绘 `fatigue_burst`、星光 + 释放声、怪被震开再回来），爆发后全身更敏感、被接着挠 → 4 彻底笑倒、认输。失败小剧场里两个人各爆发一次。
	CG 立绘按幕换：`defeat_1 → defeat_2 → fatigue_burst → defeat_2`；组合演出只在爆发那一步写立绘，其余跟着姿势走。
  - **手法和性格**：两位公主都是成年人（人物表 `profile`），文本写痒、笑、害羞和嘴硬。粉色公主写脚（脱鞋袜、掰脚趾挠趾缝、扳住脚背刮脚心、
	沿足弓刷、捏脚跟），开朗倔强、叫嚷反抗、边笑边求饶；蓝色公主写大腿 / 屁股（揉腿根打圈、指尖沿大腿内侧上移到腿根为止、左右轮流捏屁股、
	两者交界处来回轻刮），寡言嘴硬、短句带省略号，越痒句子越碎，破防后小声服软，不用固定口头禅、不重复同一句。每段都用那只怪 / 陷阱自己的工具来写。
	组合被谁触发就播谁的版本；主要针对另一位的组合，换成针对这一位弱点的写法。
  - 检查：`python tools/build/check_siege_text.py [--top]`（四幕和句数、两人的手法词、蓝色公主重复句 / 「不痒」次数、繁体字 / 日文假名）。
- 测试：`siege_test` / `siege2_test` / `siege3_test` / `siege5_test`（攻防战各轮），Boss 和机关的 `siege_w6_bear_test` / `siege_w9_puppet_test` /
  `siege_w12_fortress_test`、`siege_cooperation_test`、`siege_dev_test`、`siege_revision_test`（都直接继承夹具 `tests/helpers/siege_fixture.gd`）；
  `siege3_test` 的第十轮测四个大型陷阱和四个地面配合技、第十一轮测难度倍率 / 陷阱配合 / 双向传送门 / 攻城车撞塔撞人 / 投石车 / 胜利清空支援、
  第十二轮测攻城车撞晕 / 蘑菇吸附 / 挑薄弱墙段 / 号手阵型和散乱 / 撤退不跳波；`siege_test` 的胜利段测镜头拉远、十二位镇民出场、之后去战后的小镇；
  第九轮测螃蟹规则、CG 段测四幕结构和配合技字幕；`siege_w12_fortress_test` 的 `_round10` 测要塞的新机关、护盾柱、超载和最终波车队；`siege5_test` 的组合段把 23 组三来源组合给两位公主各触发一遍
  （穿着千手痒痒裤时大腿 / 屁股的临时装备会被裤子吸收，测试按组合临时开关 `Equipment.PANTS_FLAG`）；
  截图 `capture_siege*.gd` 输出到 `tools/.cache/shots/`。

## 七日赎罪：战后的小镇（levels/floor_06/scripts/after_*.gd）
攻防战胜利的过场 `siege_won` 最后 goto `floor_06_after`（`from_siege`）。`tools/build/gen_floor06_after.py` 生成三张地图、日程、对话和过场，台词在 `tools/build/after_text/`
（`d1.py` 第 1 天的过场、`d2.py` 第 2 天的足枷示众、`punish.py` 受罚转盘的四段小剧场、`town.py` 镇民 / 告示板、`house.py` 小屋家具和梦游的手印；生成器只负责拼装）。
- **地图**：`floor_06_after`（和战时小镇同样的布局：脚手架、木料、歪掉的狂欢图腾柱、宣判台、告示板、广场足枷、彩旗；no_switch，蓝色公主跟着）、
  `floor_06_after_house`（小屋楼下，夜里门锁上 = 宵禁）、`floor_06_after_house_up`（楼上，`after_house_up_open` 之后才能上）。新道具在 `tools/art/gen_town_art.py`
  （`house_scaffold_*`、`lumber`、`totem_tilted`、`podium`、`notice_board`、`stocks_plaza`、`pants_hand`、`handprint`、`bunting`），镇长的行走图 `npcs/mayor.png`。
- **时钟 `DayClock`**（`scripts/story/day_clock.gd`）：`vars.after_day`（1~7）+ `vars.after_slot`（0 早 / 1 午 / 2 夜，夜里开 `night`）；`set_time` 之后
  `GameState.flag_changed` 发 `DayClock.TICK`。`pass_time(时段)`：黑幕 +「第 N 天·下午」，黑着的时候换时间、揭掉过场留下的黑幕；`sleep()`：`Sleep` 到第二天早上。
  日程 `data/after/schedule.json`：`npcs` 镇民（键 = 对话文件名）按 default → 时段 → `d<N>.all` → `d<N>.<时段>` → 做完后的 `<时段>_done` 逐层覆盖
  `{at, dir, wander, hidden, dialogue}`；`days.d<N>.<时段>` = `{event, task, hours}`。做完记 `after_done_d<N>_<时段>`（`done` / `mark_done`）。
- **赎罪簿 `PenanceBook`**（`scripts/story/penance_book.gd`）：宣判时 `start()`（`penance_book`，100 工时），`add(差值, 原因)` 记 `vars.penance_log` 并提示；
  背包的「赎罪簿」页（`Backpack.PAGE_PENANCE`，有赎罪簿后插在「物品」后面；庆功宴开始以后（`AfterFestival.ON`）和骑士篇里不显示）读 `page_rows()`：剩余工时、今天的安排（✔ / ▶）、最近的记录、受罚记录。没有失败结局。
  `punish(文字, 小剧场)` 记受罚（`vars.penance_punish`）；`fail(任务名, 小剧场, 罚工时)`：弥补任务办砸了 → 失败小剧场 → 罚工时 → 记受罚（任务自己再从头来）。
  受罚的小剧场放在 `data/theater/after/`（id 以 `after_` 开头），看过后在背包「CG 图鉴」的「七日赎罪」分组里重看。
- **受罚转盘 `PenanceRoulette`**（`scripts/story/penance_roulette.gd`，盘面 `roulette_wheel.gd`）：`await spin(原因)` 转盘越转越慢停在四种刑具之一
  （刑床 / 足枷 / 转轮 / 刷子凳，`forced` 测试用）→ 小剧场 `after_roulette_<刑具>` → 记受罚。
- **忍笑选择 `EndureChoice`**（`scripts/ui/endure_choice.gd`，过场步骤 `endure`）：忍笑条 `time` 秒涨满（`time_by` 按上一次的结果换），期间一直被挠；
  `delay` 秒后弹出应对选项，条满前没选 = `burst`（`burst_var` 计数）；结果写进 `vars[var]`，后面的步骤用 `if` 分支（过场步骤的 `if` 条件同人物对话）。
  `auto_pick` 测试用（-1 = 等到笑出声）。目前还没有剧情在用（示众改成了小游戏），留给之后的日常事件。
- **剧情 `AfterStory`**：推进方式是「自由活动 → 走到目标地点 → 演事件 → 推进时段」。`EVENTS` 事件 id → `where` 哪张图、`auto`（进图就演：开场、
  夜里进小屋）或 `spot [格x, 格y, 半径格]`（走进圈才演，导演 `_process` 里检测 → `trigger(图)`）、`objective` 目标文字、过场。`objective(图)` 给导演的目标
  （别的图上指向小屋门口 / 门；没有事件的时段是「自由活动，床上可以休息」）。事件开始记 `after_ev_<id>`；`finish_slot()` 还工时 → `advance_slot()`：
  早上 → 下午、下午 → 夜晚（宵禁）、夜里 → 回楼下的床上睡（`go_to_bed`）。夜里的事件进行中开 `after_night_busy`（床不能睡）。
  床：夜里 `call: after_sleep`，白天 `call: after_rest`（`rest()`：这个时段还有事件 / 委托没做完时不让休息）。旧存档（打赢攻防战还在战时小镇）进战时小镇时直接送过来。
- **目标提示 `ObjectiveMarker`**（`scripts/story/objective_marker.gd`）：目标格上的光圈 + 上下跳的箭头，目标在画面外时屏幕边缘的指向箭头，右下角
  「第 N 天·时段 / 目标 / 实时状态（`extra`）」（8 号字、宽 190 自动换行、往上长）；过场 / 对话 / 黑幕时藏起来。
- **镇民委托 `AfterErrands`**（`levels/floor_06/scripts/after_errands.gd`，数据 `data/after/errands.json` ← `after_text/errands.py`）：有赎罪簿以后、白天、到了
  `from` 的时段且满足可选的 `requires` 前置委托后开放（`errand_<id>_open`，委托人头上冒「！」，对话 entries 最前面接委托：`set {vars: {errand_req}, call: errand_start}`）；接下 `_active`；七日赎罪结束以后（第 7 天以后、骑士篇里）不再挂委托，骑士篇里补罚也不再开放。
  导演摆上玩法节点（`errand_cookies.gd` 送饼干、`errand_apples.gd` 捡苹果）；`complete` 减工时，`fail` 当场被挠一下、回到能接。一次只能接一个。
  - 闲逛的小孩 `AfterKid`（`after_kid.gd`，场景 `levels/floor_06/scenes/after_kid.tscn`）：`lure` 成立且公主在视野里 → 跑过去挠（闷笑最多 97%，小镇里不会笑晕）
	→ `on_catch`；冲刺甩开 / 按 E（`on_shoo`）。`pick_zone` / `caption` 给部位和详细字幕（装备回收按穿着的装备写配合挠法）。
  - 痒痒草 `TickleGrass`（`tickle_grass.gd`）：踩进去被藤蔓缠住（定身）挠腰和脚心，冲刺躲得开。
  - 第 3 天起白天都能接的四个委托（台词各一个文件 `after_text/errand_<id>.py` → `data/after/errand_<id>.json`，反应字按闷笑分三档 light / mid / heavy）：
	- 「小游戏画面」型（`kind: show`）：走到 `target` 格 → `ErrandShow`（`errand_show.gd`）开演 `show` 脚本（继承 `TrainingStage`，`await play()`）→ 完成。
	  **扶梯子**（工匠，`LadderShow`）：光脚爬梯子补屋檐，平衡条（← → 往回拨，自己会晃，闷笑越高越晃）+ 干活提示键；三个阶段（爬上去 / 修屋檐 / 下梯子），
	  工匠的手指和刷子、小孩的草叶和羽毛轮流挠脚（第一次出现时暂停演几句），平衡到头摔进干草堆（演一段，这一段重来）；完成后工匠夸她的脚，不了了之。
	  **足底按摩**（派对主人，`MassageShow`）：「忍住别踢」节奏条（指针扫到绿区按 J），六种手法依次越来越难，踢中三次「重来！」；完成清空疲倦、加状态 `foot_light`。
	  **篝火舞会排练**（派对主人，`DanceShow` + 可复用的音游条 `RhythmLane`（`scripts/ui/rhythm_lane.gd`：↑↓←→ 音符从右往左滑进判定圈，perfect / good / miss，
	  `make_chart(bpm, 拍数, 种子)`、`jitter`））：教学四拍 → 双人舞（失误挠腰）/ 举手转圈（腋下）/ 踩影子（被小孩按倒挠脚心），羽毛围巾不时扫脖子让音符抖；
	  闷笑满这一段重跳，总分不到 60% 整首重跳。
	- **赶蘑菇羊回圈**（女仆，`ErrandGoats` + `MushroomGoat`（`mushroom_goat.gd` / `.tscn`，行走图 `npcs/goat.png`））：先追叼走鞋的小羊羔，然后抱着盐块把羊一只只引回
	  东边的羊圈（门口 `PEN_GATE`）。跟着的羊排成一串；冲刺 / 离太远 → 最前面那只不黏人的掉队（后面的跟着它走）；站着不动 → 跟着的羊追上来舔（部位按性格轮换：
	  脚心 / 脚趾缝 / 手心 / 后颈 / 膝盖窝 / 腰），怕生的要站着等它；闷笑满绊倒、盐块掉地上（捡起来接着赶）。五只进圈 → 门口的「谢礼」→ 完成。
	- 同一个委托人有两个委托时，做完以后的话排在所有「能接 / 正在做」后面（`errands.inject`），不挡住下一个。
	- **劳动委托 / 补罚小游戏的共用底子 `ErrandWorkStage`**（继承 `TrainingStage`；穿链、剪毛、棚布、筛叶、灯轮、报幕都继承它，一个游戏一个脚本、一个文本文件
	  `after_text/errand_<id>.py` → `data/after/errand_<id>.json`，报幕的文本在 `penalty.py`）：来源 / 对白 / 输入锁 / 临时闷笑疲倦的生命周期（Esc、读档、换图只释放自己持有的，
	  `suppress_laugh_tutorials` 期间不触发世界的失控教学），加上共用流程：`start_work`（开场 / 续做对白 → 第一段；进度已满只补收尾）、`advance_step`（完成数 +1 →
	  `save_progress` → 阶段末尾演转换对白）、`_finish_work`；子类重写 `work_text / phase_limits / save_progress / _begin_segment / _reset_segment / _stop_input / _on_phase_changed`。
	  - 连续干扰 `WorkInterference`（`scripts/training/`，只在可操作时推进）：每 6 秒加强（提前 0.6 秒预告），0.65 秒一次命中特效，3 秒一次反应；`work_clock(dt)` 推进它，
		加强时按 `phases[].tools` 轮换道具，命中时 `tickle(tickler, tickle_zone)`。挠痒事件 `feedback`（`common.event(阶段, 道具, 描写, 反应…, zone, fx)`：描写进下方反应框，
		反应按闷笑分 light / mid / heavy 飘在头上），部位和特效由事件决定，不写死在代码里。只在开场、两次阶段转换、收尾演阻塞对白。
	  - 闷笑满 → `recover`：闷笑回到 45%、当前这一段从头（文本 `full`）。魔力疲倦满 → `release`：**魔力自动释放，人会觉得舒服**（闪光、`release` 的描写 / 舒服的反应 /
		挠她的人一句），疲倦清空、进度不退，停 1.8 秒；之后 5 秒「释放后敏感」：`work_laugh` ×1.5、反应换 `sensitive`。都不记补罚。
	  - 四个以脚为主的游戏（粉色公主单人，手法针对脚底；蓝色公主不参与，只在报幕结尾当观众说两句）：
		- **城门底下重新穿链**（工匠，第 4 天起白天，城门内侧 `[31,38]`，`GateChainShow`）：她仰面躺进检修槽穿链，光脚伸在槽口外。穿链 3 / 入轮 6 / 试拉 3 步，←→ 对准、J / K 力度、E 确认；
		  道具：清灰刷 / 羽毛掸 → 润滑油刷 / 链环滚趾缝 → 手指刮脚心 / 齿轮刷滚足弓。**缩脚**（S）：预告亮着时按，这一下闷笑减半，但链头往反方向偏 ×1.5。`errand_gate_chain_step`（0~12）。
			  不另画脚底图（用户要求）：舞台上只有转了 -90° 趴着的公主人物图，`ToolRig` 把道具画在人物图的脚上，缩脚时人物图往槽里缩一点。
			  失误超过 `FAIL_ERRORS`（4）次：墙面倒塌的失败小剧场 `after_fail_gate_chain`（只露出一双脚，工匠借口拉脚挠脚心，三次魔力释放把墙震开；墙 `gate_wall_full / half / broken.png`），
			  演完失误清零、扣好的节点保留、接着做。
		- **蘑菇羊剪毛**（女仆，第 4 天起白天、赶羊之后，羊圈门口 `[57,33]`，`ShearingShow`）：脚底抹了盐，咕咕边被剪毛边舔脚。梳 3 结 / 剪 4 区 / 收 3 堆，←→ 转工具、按住 J 沿箭头工作；
		  **盐量**：盐越多咕咕越乖（抖毛间隔 9 + 盐 ×5 秒、预告更早）但舔得越勤越痒，K 擦掉一些盐，每阶段女仆再抹；装袋阶段小羊羔挤过来和咕咕轮流舔另一只脚。`errand_shearing_step`（0~10）。
		- **脚踏灯轮校准**（派对主人，第 4 天起白天、篝火舞排练之后，篝火边 `[44,26]`，`LampCalibrationShow`）：光脚踩调光踏板，单灯 / 双灯 / 图案各 4 项，亮斑稳 3 秒；
		  **踏板刷**：踩得越深灯越亮、滚轮毛刷也越痒（闷笑按踩下的深度额外涨）。道具：羽毛 / 彩带流苏 → 流苏 / 灯芯草钻趾缝 → 灯芯草 / 手指掰脚趾。`errand_lamp_calibration_step`（0~12）。
		- **忍笑报幕练习**（派对主人的补罚，`AnnouncerShow`，见「补罚任务」）。
	  - 棚布补漏（商贩，坏摊棚南侧 `[15,28]`，`CanopyShow`）：挂 3 角 / 描 4 道缝 / 张紧 3 次，`errand_canopy_step`（0~10）。筛叶风选（药剂师奶奶，工房门外 `[17,12]`，`SiftingShow`）：
		跟拍筛 12 拍 / 调风分 24 片叶 / 装 3 袋，`errand_sifting_step`（0~5）。这两个的挠法还是腰侧，文本没重写。
	  - 测试：`f6_after_test.tscn -- --gate-chain-only / --shearing-only / --work-errands-only（穿链 + 剪毛）/ --workshop-only / --town-workshop-only（四项）/ --festival-only（灯轮 + 报幕）`，
		辅助脚本 `tests/helpers/f6_*.gd`；截图 `tests/capture_f6_{gate_chain,work_errands,workshop,festival}.tscn`。
- **两位公主的玩闹 `AfterPlay`**（`after_play.gd`，台词 `data/after/play.json` ← `after_text/play.py`）：和蓝色公主说话「逗她笑一笑」（`call: after_play`），
  千手痒痒裤的小手按住她；最多 3 次选部位，今天的弱点（`weak_spot()` 按天变）以外的部位台词透露远近，挠中后节奏连击（`KeySequenceQTE`）成功就破功；
  失败可当天重试，获胜后当天不再重玩；成功 `blue_bond` +1，每天最多一次。`vars.after_play_day` 记尝试、`after_play_win_day` 记获胜、`after_play_bond_day` 记奖励日期；旧记录无法判断胜负时允许重试，当天不补发不确定的旧关系奖励。
- **蓝色公主自由活动 `AfterBlueRoutine`**（`levels/floor_06/scripts/after_blue_routine.gd`）：仅管理战后小镇的 `AfterBlue`，默认不跟随。日程 `schedule.json` 的 `npcs.after_blue` 由 `gen_floor06_after.py` 生成：早上训练室外 `[12,14]`、下午井边 `[33,18]`、晚上篝火旁 `[41,25]`，周围 2 格内闲逛；时段切换在时钟黑幕中换位。`BluePrincess.start_wandering()` 接回 `Talk`，`start_following()` 接回 `PartnerTalk`，避免重复交互。
  当天挑战获胜后，对话可邀请同行或结束同行；`vars.after_blue_follow_day` 保存主动同行日期，重进小镇恢复，次日需重新获胜。`after_blue_can_follow` / `after_blue_following` 仅为对话菜单派生标记。结束同行沿路返回活动区。任务／委托优先恢复原同行，过场和CG期间不接管；第二天早上示众前仍离场。其他地图保留原导演安排。
- **导演**：`AfterTown`（图例 `f6after`）把蓝色公主改名 `AfterBlue` 交给 `AfterBlueRoutine`、镇民改名成对话文件名（过场里直接用），按日程摆（`place`：藏起来 = `show_flag` 设成
  永远没有的标记）；过场放完重新摆、揭开 `end_dark` 的黑幕（紧接着 `pass_time` 时交给它）。`AfterHouse`（图例 `f6afterhouse`，楼上楼下共用）：楼下进门 → `enter_house`，
  梦游进行中摆出三处可调查的手印（`CLUES`）；楼上蓝色公主（`AfterBlue`）夜里躺床上，三处手印都看过 → `run_upstairs()`。
- **第 1 天**：早 `after_d1_open`（千手痒痒裤当众发作、队长要砍裤子、私下特训 / 搬砖）→ 午 `after_d1_verdict`（镇长主持、队长宣读，「……那扇门，钥匙是我的」被打断，
  发赎罪簿）→ 回小屋天黑 → 夜 `after_d1_night`（被裤子的手挠脚心挠醒）→ 手印 `after_house_objects#clue_bed / clue_tea`，最后 `clue_stairs`（→ `after_d1_clues`、
  `after_house_up_open`）→ 楼上 `after_d1_night_end` → 第 2 天早上。
- **第 2 天早上** 足枷示众：走到广场足枷（地图上的 `trap type=stocks active=false`）→ 开场过场 `after_d2_stocks`（镇民夸她的脚、队长讲规矩）
  → 小游戏 `StocksShow`（`levels/floor_06/scripts/stocks_show.gd`，继承训练小游戏 `TrainingStage` 的画面）→ 结局过场。
  - 120 秒倒计时，孩子按 `TOOLS` 轮换（羽毛 / 狗尾巴草 / 小刷子 / 一群小孩），每个孩子按 `PICK_WEIGHTS` 挑一个部位（`PARTS`：前脚掌 / 脚心 / 脚趾缝 / 脚弓，
	闷笑每秒涨的比例、魔力疲倦倍率、挠多久各不同；挠完脚弓下一个孩子工具升级）。
  - J / E 挣扎降闷笑 2.5%（挠的手停 0.3 秒；同一部位连挣 6 次孩子换部位）；1~4 花求情（3 次）换部位，倒计时 +2 秒。
  - 孩子换人的间隙三选一（1 装没事「硬撑」挣扎减半 / 2 求饶「丢脸」闷笑 +25%、下一个时间 −30%、求情 +1 / 3 顶嘴「挑衅」两只脚一起挠、疲倦 +30%、挣扎 ×1.5、求情 −1），
	限时 3 秒，不选算装没事。
  - 闷笑满 = 笑出声（回到 40%，结算时一次 +2 工时，3 次以上去受罚转盘）；魔力疲倦满 = 自动释放，队长「不符合管教，加时！」+15 秒。
  - 撑到 0 秒 → `after_d2_stocks_end`（蓝色公主最后一个来，千手痒痒裤的小手偷戳脚心「不算」，送鞋）；释放超过 5 次笑晕 → `after_d2_stocks_faint`
	（醒来后蓝色公主绘声绘色地描述她昏过去以后孩子们怎么挠她的脚心）。跟着的 `AfterBlue` 开场挪走、结局放回。
  - 演出：孩子登场、换人的应对、笑出声、魔力释放都暂停示众（`busy`），在对话框里演一小段——台词 `data/after/stocks.json`（← `after_text/stocks.py`）：
	前四个孩子是原来过场里的戏份（登场、应对的提问和三个选项、三种反应），之后的孩子从池子里挑；开挠时有「工具 × 部位」的挠法描写和公主的第一句；
	应对用对话的选项页（选项后面带负面状态名，效果写在下面）；挠的过程中公主的反应用立绘旁的反应字（`GameState.princess_reacted`，不暂停）和头顶气泡。
  - 测试接口：`press("J")`、`plead(部位)`、`respond(id)`、`auto_respond`、`quiet`（不演对话，直接测数值）、`time_scale`。
  - 第 2 天早上示众之前：蓝色公主不在身边（`AfterTown.blue_away()`，一早去了训练室），镇民有等着示众的话（`d2_wait`），示众之后 / 笑晕之后各一套（`d2` / `d2_faint`）。
- **弥补任务**（`AfterStory.TASKS`：事件 id → 玩法节点脚本、失败小剧场、罚工时、收尾过场、失败后回到哪一格）：`run_task(ev)` 摆上玩法节点，等它发
  `finished(ok)`；失败 → `PenanceBook.fail`（失败小剧场 + 罚工时 + 记受罚）→ `reset_items()` → 重来；任务进行中开 `after_task_active`（委托接不了、小屋的门锁上）。
  玩法节点没做完就离开场景树（换图 / 读档 / 测试跳关）→ `aborted`，清掉标记，走回触发点重新开始（`recover_task` / `reset_runtime`）。
  目标下面的实时状态读脚本的静态 `status_text()`（`AfterStory.status_text`，没任务时是委托的）。文本在 `after_text/tasks.py`、`potion.py`、`equip_kids.py`。
  - **痒痒装备回收**（第 2 天下午，`TaskEquip`，`task_equip.gd`）：8 件临时痒痒装备（`ItemSpot`）走过去就被强制穿上（`Equipment.force`），同部位再捡一件旧的掉在脚下；
	送到补给站（`DEPOT`）全部卸下。路上 4 个 `AfterKid`：闷笑超过 40%、装备刚发作（`EquipFx.flared`）、或戴着铃铛脚链 / 痒痒印记臀贴时跑过来，
	按穿着的装备配合着挠（`EquipKids.caption / zone_for`，两件一起有组合挠法；描写走立绘旁的反应字）。长椅歇脚 / 井边洗脸降闷笑，被挠时 J 挣扎、E 哄走、冲刺甩掉。
	闷笑到 90% = 失败（`after_fail_equip`）。
  - **药剂师的试药员**（第 3 天早上，药剂师工房 `floor_06_after_pharmacy`，`TaskPotion`）：配方本（水渍盖住的配方 + 记下的反应）→ 六味药草挑三味 → 奶奶用羽毛试，
	配方里没有的药草各有一种可推理的反应（`data/after/potion.json`）；错三碗 = 失败（`after_fail_potion`），换下一张配方。配对 → 「薄荷止痒药」（`MintPotionItem`：
	10 秒 `frost_guard`，闷笑不涨）。
  - **拆除哑火的攻城车**（第 3 天下午，城门外的战场 `floor_06_after_field`，城门 `after_field_open` 这时才开；`TaskCart` + `DormantCart`，图例 `f6cart index dir sweep speed range_px`）：
	车灯（`VisionCone`）左右扫，被照到累计 0.4 秒或在附近冲刺就醒 → 捞进车斗挠 → `KeySequenceQTE` 挣扎，挣不开 = 失败（`after_fail_cart`）；车尾按住 E 三秒拆车轴。
	蓝色公主（这张图能换人）在车旁按住技能键冻住车轮（冻着的车灯不扫），冻久了千手痒痒裤反弹（解冻、她被挠、5 秒冻不了）。
	三辆拆完 → `after_d3_cart_done`：队长递手帕的「花猫样」口误（用户给定的台词）。
  - **裁缝的试衣模特·找漏风**（第 5 天早上，裁缝铺里间 `floor_06_after_tailor`，`TaskTailor`，文本 `after_text/tailor.py`）：量尺寸（暖场）→ 腋下 / 腰 / 脚心（棉袜）
	各四个点，裁缝拿羽毛挨个试（漏风 = 好痒、挨着没缝的漏风点 = 有一点点、别的没感觉；闷笑 ≥ 60% 时挨着的点一半可能也说好痒）→ 选项页标点（部位图 `TailorChart`
	同步显示）→ 缝：标错的「仔细检查」（挠一阵）；可以再试一遍、喝茶降闷笑（3 次）。部位图使用 `assets/generated/after/tailor_{armpit,waist,sole}.png`：棉衣肩腋接缝、前后腰并排、正常成年女性脚型的贴合棉袜底面。源图与提示词在 `tools/art/src/tailor_charts/`，`gen_tailor_charts.py` 规范化为 384×256；数据 `chart.texture / points_uv` 配置编号位置，颜色、选中圈和已缝 X 由界面独立覆盖。图与选项分栏，`ChoiceMenu.ask(texts, prompt, layout=Rect2())` 可指定布局，省略时保持原布局。验收走过三个羽毛人台（`FeatherMannequin`），漏补的部位被挠、回去重找；
	闷笑 97% = 失败（`after_fail_tailor`，漏风点重新随机）。完成得到装备「防痒棉衣」（`equip_tailor_coat`：腋下 / 腰 / 脚心各挡 2 次）。台词行里写 `"tickle": 部位`
	时任务节点顺手挠一下（对话框的 `line_shown` 信号）。
  - **矿车护送·双人轨道**（第 5 天下午，受损的矿道 `floor_06_after_mine`，东北角的矿道门 `after_mine_open` 这时才开；`TaskMine`，文本 `after_text/mine.py`）：
	程序画的矿车（蓝色公主坐在上面）沿第 6 行的轨道走；按住 → 推（闷笑越高越没力，人过不去车），上坡段要连按 →、不推往回溜。C 冰封模式（车刹住）+ J 冻住车前方
	的陷阱 5 秒（喷口的粉雾一起清掉）。上坡段残党小鬼（`CartImp`，机关小工匠的贴图染红）跳上车挠蓝色公主的大腿，车上每只让推力 ×0.6，车旁按 J 拍下去。
	闷笑满车溜回这一段的起点，溜三次 = 失败（`after_fail_mine`）。四段（装车 / 喷口 / 刷子 / 上坡）之间两人聊矿道和小时候；到营地 → 旧门的传闻。
  - **修补狂欢图腾柱**（第 7 天早上开始、做到傍晚，图腾柱废地 `floor_06_after_totem`，西边的小路 `after_totem_open` 这时才开；`TaskTotem`（`TaskShow`）→ `TotemResonanceShow`，文本 `after_text/totem.py`）：
	「图腾共鸣·双人符文」：两人并排站在底座前的符文圈里（粉色光脚踩足印符文 = 玩家的闷笑；蓝色站腿环符文 = 舞台上模拟的 `blue_laugh`）。
	共鸣判定抽成可复用的 `ResonanceMeter`（`scripts/training/resonance_meter.gd`）：两人闷笑同时在 [0.4, 0.75] 里才充能，任意一人到 0.92 → 符文裂开（这一道重刻、两人回到 30%），
	同一道裂三次 = 失败（`after_fail_totem`，刻好的不用重刻）。A / D 绷紧 / 张开脚趾、J / K 冰封 / 松开裤子（再按一次回平常）。痒感连线：加强挠一个人，另一个人涨一半（`LINK`）。
	三道符文的挠法（`phases[].tools` + `tool_who`）：羽毛扫脚 / 小手揉大腿 → 小手顺着连线掰脚趾挠趾缝 / 符文刷子刷大腿内侧 → 笑脸光带舔脚心刮脚跟 / 小手捏屁股（充到七成「持续加强」）。
	魔力释放 = 舒服的释放 + 共鸣爆发（充 25%）。每道之间歇脚（镇民送水、蓝色公主数这七天）。`TASKS` 的 `day_end`：先还这个时段的工时再演收尾（收尾过场按还没还清分支），
	早上、下午都算做完，然后 `end_of_day()`。状态 `vars.task_totem_runes` / `task_totem_cracks`。`TrainingStage.tickle` 多了 `target`（挠哪个演员）和 `fx` 参数。
  - **最后一天的工时**（`AfterStory.SETTLE_DAY` = 7，`must_settle()`：第 7 天、工时 > 0）：图腾柱做完后，晚上有事（日程的夜间事件，或 `errands.json` 里 `night: true` 的委托，
	`night_has_content()`）就天黑、停在晚上，否则停在下午；欠工时时床不让休息 / 睡觉（`rest` / `sleep_later` 提示 `settle_text()`），目标提示改成补罚，晚上不宵禁，
	事件写了 `needs_clear` 的（庆功宴）工时还清才开。补罚这一天不看受罚记录、工时大于 0 就能接（`AfterPenance.settle_mode`，对话入口 `penalty_offer_d7`，标记 `penalty_d7`），
	报幕晚上也能接，一次减 `settle_hours()`：开始补的时候欠的工时（`vars.penance_d7_debt`，中途又加了就按新的算）的三分之一、至少 `hours_d7`（5），
	欠多少都是三次还清；有没抵的受罚时顺便抵一条。跳关点「第 7 天（修补图腾柱）」给 20 工时（图腾柱刚好还清），曾经给 100 导致要补 16 次。
  - **庆功宴**（第 7 天晚上的事件 `d7_festival`，`needs_clear`：工时还清才开；广场篝火边 `[40, 24]`；`AfterFestival`，文本 `after_text/festival_night.py`、`stall_<id>.py`）：
	开场过场 `after_d7_festival` → `AfterFestival.begin()`（标记 `after_festival_on` + `after_night_busy`，床不能睡）→ 自由活动，摊主和派对主人的对话最前面换成庆功宴的入口
	（`festival_night.inject`，对话 `call: festival_dance / festival_stall（vars.stall_req） / festival_finale`）。
	- **庆典广场** `floor_06_festival`（`gen_floor06_after.py` 的 `fe`）：从小镇篝火西边的入口 `[40, 24]` 进（`after_festival_open` 之后才开），战后百废待兴的样子
	  （补了一半的城墙、脚手架、打补丁的帐篷、碎石堆上的笑声灯笼、木箱摊位、修好的图腾柱）。小镇上只留接补罚的市场监督和派对主人，庆功宴一开始也走（`AfterTown.apply_schedule`）。
	- **广场上的人**：每人一个庆功宴专属的对话文件 `after_fest_<人>`（`after_text/festival_talk.py`，身上不挂委托）：摊主 = 摊位入口 / 通关后的纪念 / 领舞以后的闲聊；
	  其他人 = 领舞前 / 领舞后 / 五个摊位都通关。队长、市场监督、队员、小莉莉的话和蓝色公主同行的搭话都换成庆功宴的。
	- **奖品和装扮**：摊位通关后摊主先说两句奖品（`stall_<id>.py` 的 `REWARD` → `festival_night.json` 的 `reward_lines`），再进背包（`rewards`：饼干 ×3、薄荷糖 ×2、
	  木头小羊、冰雕小羊、足疗鱼小盆、咕咕的铃铛项圈）。广场装扮用道具的 `show_flag / hidden_flag = stall_<id>_done`：饼干串灯、彩色发绳、三块冰 → 三座冰雕、足疗鱼盆，
	  还有戴发绳跑来跑去的小孩、戴铃铛的咕咕。小镇道具也支持 `show_flag / hidden_flag`。
	- **篝火领舞**（必做，`FestivalDanceShow`，复用 `RhythmLane`）：领舞（光脚，失误 → 围观的人挠脚心）→ 邀舞（蓝色公主的嘴硬值，`ChoiceMenu` 选部位，大腿 / 屁股接一串短谱面连击，
	  脚心不怕；每次挠完千手痒痒裤的小手帮倒忙挠粉色）→ 双人舞（失误 → 小手挠粉色的趾缝或蓝色的大腿）→ 全镇一起跳。每段得分 < 50% 重跳，闷笑满脚下一绊重跳。→ `festival_dance_done`。
	- **五个摊位**（可选，都继承 `ErrandWorkStage`，不存档，通关记 `stall_<id>_done`）：脚底猜猜乐（奶奶，`StallGuessShow`：脚伸进帘子后的箱子，挠一阵四选一，连对三次）/
	  忍笑套圈（商人，`StallRingShow`：准星左右晃，闷笑越高越乱，柜台下的小孩加强时准星猛偏，12 个圈套中 6 个）/ 冰雕摊（工匠，`StallIceShow`：操控蓝色公主按方向刻冰，
	  粉色公主和小手挠她的大腿屁股，J 冰封压笑有冷却，笑满冰雕塌）/ 捞痒痒鱼（小汤姆，`StallFishShow`：光脚泡在盆里被鱼啄，← → 挪网 J 捞，网会湿会破，K 抬脚鱼散开）/
	  舔盐耐力赛（女仆，`StallLickShow`：和派对主人比谁先笑，J 绷住耗体力、K 放松，自己的闷笑停在临界点时主人那边涨得更快）。
	- **放烟花**（领舞以后找镇长）：`FestivalFireworks`（纯 `_draw` 烟花；过场里镜头拉远到 0.55，烟花跟着铺满画面）+ 过场 `after_d7_finale`（哼歌伏笔、队长合上赎罪簿）
	  → `chapter_end`「七日赎罪　完」→ 按 E 回小屋，进门直接接骑士篇的早上（`AfterStory.enter_house` → `KnightStory.begin()`，不用再上床）。放完烟花以后庆功宴的入口都不再出现。
	  领舞的舞台（`FestivalDanceShow`）：踩中一拍，台上的粉色公主、派对主人（邀舞以后还有蓝色公主）跟着跳一步（`CGActor.dance_move`：跳 / 转一圈 / 踏步 / 摇摆，完美是大动作）。
	  测试：`f6_after_test.tscn -- --festival-night-only`（`tests/helpers/f6_festival_night.gd`：五个摊位、奖品和装扮、放烟花 → 结局画面 → 回小屋 → 骑士篇开始）。
  - **疏通排水管**（第 4 天早上，排水管 `floor_06_after_drain`，南边排水口 `after_drain_open`；`TaskDrain`，文本 `after_text/drain.py`）：一格宽的管道迷宫里趴着爬
	（meta `busy_hands` + 状态 `crawl`）；绒苔球（`TaskDrain.MossBall`）贴在腿上蹭、按住 E 擦掉；管口外的小孩抓脚（定身 + 挠，J 蹬 5 下挣开）；三段开场（第二段管壁上
	两个手拉手的小女孩涂鸦，伏笔）、三处堵塞（`Clog`，按住 E 擦）、拉总闸放水。闷笑满 = 被拖出管子（`after_fail_drain`，通了的不用重通）。收尾队长递手帕「又是这副样子」，
	手帕角上绣着两个手拉手的小人；最后 `goto` 回小镇。
  - **蓝色公主的特训**（队长的训练室 `floor_06_after_drill`，西北角那座房子 `after_drill_open`；`TaskDrill`，文本 `after_text/drill.py`）：操控蓝色公主
	（`switch_control`，结束换回）。共同底子 `DrillShow`（继承 `TrainingStage`）：魔力疲倦满自动释放 → 「释放后敏感」15 秒（挠痒 ×2、反应字换 sensitive 那套、
	队长加码）；一节课释放超过 3 次重来（补课小剧场 `after_fail_drill`）。蓝色公主和粉色公主在舞台上用公主精灵图（`CGActor.make_princess`）。
	- 第 4 天下午：第一课 `IceSitShow` 冰封静坐（身体图 Q W E / A S D，亮起来的地方冻住；寒冷值满发抖全化开；表情掉光记一笔，三笔重来；假动作）→ 课间 →
	  第二课 `PantsTameShow` 驯裤（小手的手势 → W 按住 / A 安抚 / S 冻住 / D 随它去；假手势；听话度满出师）。
	- 第 6 天下午：第三课「借手」`PantsHandShow`（小游戏画面：飞来的羽毛 ← → ↑ 挡、拉杆亮起 A / D 拉、粉色公主偷袭 ↓ 抓；每个指令花听话度，
	  不够 = 小手造反挠她自己，漏掉 = 被挠；处理够 12 个过关；训练室只有一间）→ 考核 `DrillExamShow`（继承 `IceSitShow`：QWEASD 实际冻结对应六部位，考核和第一课共用 `after_text/drill.py` 的 `ICE_SPOTS`，避免考核数据漏配；粉色公主挠，J 小手挡、U 千手解放，释放 = 失控加时；笑出声三次不及格，
	  不算失败、结局台词不同）→ 学会被动「冰封自制」（`ice_composure`：`PlayableCharacter._extra_stat_*` 里减闷笑涨幅、减轻千手痒痒裤）和主动技能
	  「千手解放」（`PantsBurst`，输入 `skill` = U：范围内的怪定身 3 秒、陷阱暂停；副作用 5 秒小手挠自己 + 状态 `pants_backlash`；冷却 15 秒；剧情标记 `skill_pants_burst`）。
  - **陷阱验收**（第 6 天早上，保卫队训练营 `floor_06_after_proving`，东边的门 `after_proving_open`；`TaskInspect` + `InspectShow`，文本 `after_text/inspect.py`）：
	一条走廊（`TaskInspect.COURSE`）：五个挠痒陷阱的踏板（羽毛帘 / 地洞挠挠手 / 脚趾分隔刷 / 单脚吊环架 / 跪台脚心朝天，各自的挣脱方式见 `InspectShow`）+ 三个辅助设施
	（泡脚盆「泡软」、精油踏板「滑溜」、冷敷石板清状态，踏板整条走廊宽、走过去强制施加），按顺序走。体验完报「太强 / 刚好 / 太弱」——要报陷阱本身的强度（屏幕给出涨了多少闷笑和身上的状态）；评「太弱」被加强、评「太强」被削弱但要再体验一次。
	五个评完 → 综合演练（按评分调整过强度、闷笑不清零），笑倒 = 失败（`after_fail_inspect`，重来直接综合演练）。
- **弥补任务的 CG**（白天 10 个主线委托，每个一张成功、一张失败；第 6 天考核的失败和第 4 天特训共用）：原图 `assets/generated/AFTER_CG/after_<任务>_ok / _fail.png`
  （codex image_gen，提示词和参考图 `tools/art/src/after_cg/`，规则见 `docs/POLISH_RULES.md`）→ `import_cg.py --after` → `gen_cgs.py` 登记立绘 id。
  `gen_floor06_after.py` 的 `AFTER_CG_FAIL` / `AFTER_CG_DONE` 自动挂上：失败小剧场最后一次换 `defeat_2` 的那一步（高潮）换成这张大图（没有的取六成处），
  收尾过场 `after_d*_done` 六成处的台词前加 `{"do": "cg", "key": ...}`（横版大框），最后一步收回。
- 小游戏画面的描写：`TrainingStage.narrate(文字)` 发 `GameState.princess_reacted`，显示在画面下方的反应框（不放舞台顶部，那里看不清）；人物头上的气泡只放说的话。
  示众的应对选项不透露效果。选项页（`ChoiceMenu.ask`）打开期间 `in_dialogue = true`（`dialogue_holds`），人物不跟着上下键走、速度清零。
- 装备回收的小孩（`AfterKid`）：看得更远（160）、一次挠 4 秒、冲刺甩不掉；刚贴上来时暂停演一小段对话（小孩的话 + 挠法描写 + 公主的反应 `react_pool`），
  两段之间至少隔 7 秒（后来的只冒气泡）。
- 扶梯子：每完成一步（上一级 / 钉一下 / 下一级）演那一步专属的挠痒情节（`errand_ladder.py` 的 `EPISODES`，共 20 段），平衡安全区从 0.8 缩到 0.32。
- 配药：八味药草，每味配错时走一段试药流程（`TaskPotion._run_trial`：开场 → `PotionTrial` 的 timing / mash / rhythm 或猜痒感转移 / 三选一 → 成功 / 失败的几句），
  配对后成品测试（`final`）。
- **晚上的弥补任务**（第 2 / 3 / 4 / 6 天晚上，宵禁前在镇上做；晚上的事没做完床不让睡（`AfterStory.sleep_later`），小屋的门只在没有夜里任务时才锁（`after_curfew`）；
  委托人那天晚上留在外面（日程 `d<N>.night`）；做完自动回小屋睡到天亮）。台词 `after_text/night.py` → `data/after/night.json`（`AfterNight`）。
  - 第 2 天 面包店奶奶「羽毛大扫除」（`TaskSweep`，小镇东边的烤炉后院）：按住 J 扫羽毛堆；起风时羽毛钻进脚趾缝（K 抖脚、按住 E 抠），奶奶拿鸡毛掸子「帮忙」。
  - 第 3 天 药剂师奶奶「逃跑的痒痒鼠」（`TaskMice` → `MouseShow`）：身体图 Q W E / A S D，小鼠在格子间乱窜，拍对地方抓住，最后一只钻进鞋里连按 D。
  - 第 4 天 小孩们「挠痒捉人」（`TaskTag` + `TaskTag.TagKid`）：姐姐当鬼（追上去 J 挠）/ 孩子当鬼（被摸到按倒挠）/ 大家一起当鬼。
  - 第 6 天 镇长「笑声灯笼」（`TaskLantern` → `LanternShow`）：↑↓ 调欢笑踏板的刷子强度，闷笑停在每盏灯要的范围里几秒点亮，笑过头灯泡炸；疲倦释放只随机吹灭 1–2 盏已亮灯笼（`MIN_LOSS/MAX_LOSS`），不损坏、可以重亮，无亮灯不扣，全部完成优先。
  「小游戏画面」型的任务用 `TaskShow`（`make_show()` → `await play()`）。
- **第 5 天夜里 小汤姆的恶作剧**（`AfterStory` 的 `d5_tom`：进小屋就开演 `TomPrankShow`，扮演小汤姆，文本选择）：痒 / 舒服两条（借闷笑条 / 疲倦条显示），
  四段（观察 / 轻挠 / 橘子上场 / 一起来），脚趾缝的揉法又痒又舒服；痒满笑醒被抓，舒服满魔力释放时选加大强度 = 笑晕（fainted），住手 = 被惊醒；做完都没满 = 悄悄溜走。
  结果 `vars.tom_prank_result` + 标记 `tom_prank_<结果>`，第 6 天小汤姆的话按结局变（`after_text/tom.py`）。
- **补罚任务**（`AfterPenance`，台词 `after_text/penalty.py`）：赎罪簿上的受罚比已经抵掉的（`vars.penance_settled`）多时开 `penalty_open`，市场监督 / 篝火派对的主人冒「！」，
  对话里 `call: after_penalty`（`vars.penalty_req`）：`ModelShow` 活体模特（顾客轮流「试试效果」，A / D 保持姿势、J 绷住表情，动了 / 笑了加时）/
  `PenaltyDanceShow` 罚跳舞（音游，跳错一拍围观的人挠一下，错太多加一段）/ `AnnouncerShow` **忍笑报幕练习**（第 4 天白天起、篝火舞排练之后，`penalty_announcer_open`）：
  她光脚站在报幕台后，主人蹲在台下挠脚（羽毛 → 手指钻趾缝 → 掰脚趾 / 刮脚心交替）；1~3 选节目卡、指针进框按 J 鸣铃，闷笑 ≥ 70% 时鸣铃一半机会笑场重报，K 深呼吸降闷笑但下一下更狠；
  只在当场有效，十二个报完才结算。补罚的脚本表 `AfterPenance.SHOWS`。做完抵一条、减 3 工时。
- 小游戏共同：`TrainingStage` 开演时 `GameState.dialogue_holds` +1（对话框收尾时不清 `in_dialogue`，人物不动、按 E 不会去和人说话），选项页也一样；
  飘字（`pop` / `say`）互相错开、夹在舞台框里；挠法描写（`narrate`）进画面下方的反应框（劳动小游戏的描写框字号小一号，滚到底时最后一行完整显示）；
  背景音乐切到 `minigame`（`tools/audio/gen_music.py` 生成）。舞台演员可以写 `character`（pink / blue）指定用谁的精灵图，不写 = 现在操控的角色。
  抬担架、以笑为饵、图腾柱的失败小剧场里只出现千手的手。
  弥补任务进行中跟着的蓝色公主不能对话（`AfterStory._mute_partner`：先由自由日程交接为同行，静音／恢复均刷新交互区，避免只清文本却留下 E 提示）；没写 `no_switch` 的小场景按 C 换人（`AfterRoom` 设 `free_switch`）。
- 小场景导演 `AfterRoom`（图例 `f6afterroom`）：目标提示、目标圈触发、进图自动演的事件、镇民改名、蓝色公主跟着。`AfterStory.TOWN_DOORS / ROOM_EXITS` 指路。
- 小剧场 / 舞台上的字（`SpeechBubble`）画在最前面（`z_as_relative = false`、`z_index = 4000`）；训练小游戏舞台上气泡垫在飘字下面。
- 测试：`tests/f6_after_test`（胜利去向、开场 → 宣判、日程摆位、赎罪簿和背包页、宵禁锁门、手印顺序、楼上结尾 → 第 2 天、示众小游戏（挣扎 / 求情 / 应对 / 笑出声 / 释放加时 / 笑晕）/ 罚工时 / 转盘、委托、玩闹、各个弥补任务（完成 / 失败小剧场 / 重来）、第 3 天起的四个委托、
  晚上的四个任务、小汤姆的恶作剧、补罚任务、小游戏输入锁、床上休息、日程逐层覆盖、旧存档、跳关）。测试一路从第 1 天走到第 7 天，
  新加的白天 / 夜里事件要插进 `_run_*` 的顺序里（夜里任务做完会自动睡到天亮，`_sleep_night` 见到已经是早上就跳过）。
  本批日常优化专项：`res://tests/f6_after_test.tscn -- --daily-polish-only`（`tests/helpers/f6_after_daily_polish.gd`，56 项：灯笼边界、考核六键、限区日程、失败重试、每日奖励、同行重进、任务交接和旧存档、裁缝布局与输入锁）；截图入口 `tests/capture_f6_daily_polish.tscn`。实施记录、资源来源和截图索引见 `doc/f6_after_daily_polish.md` 与进度文档。

## 骑士篇（七日赎罪之后，还在地下小镇；levels/floor_06/scripts/knight_story.gd）
序章，只埋伏笔（写法见「剧情伏笔」的真相内核）。两天：**主线每一步都要玩家主动交互才开始**（和人说话 / 调查道具），中间能自由活动、做支线；
沿用七日赎罪的小屋、工房、导演（`AfterHouse` / `AfterRoom`）、目标提示和任务循环：
骑士篇开始以后（标记 `knight_started`），`AfterStory` 的 `objective` / `_try`（进图）/ `rest` / `sleep` / `status_text` / `recover_task` 都转给 `KnightStory`；
夜里不宵禁，蓝色公主一直跟着（`AfterBlueRoutine.invited_today`），没有赎罪簿和工时，镇民不挂委托、不开补罚。文本在 `tools/build/knight_text/`（`story.py` 过场和地牢里骑士的对话，
`tasks.py` A~D 的玩法文本 `data/after/knight.json` 和失败小剧场，`finale.py` E~G 的 `data/after/knight_finale.json`、过场和失败小剧场，
`townsfolk.py` 镇民的对话、主线触发的注入和调查道具 `after_k_objects`），由 `gen_floor06_after.py` 一起生成。
- **三张骑士篇的小镇**（`KnightStory.TOWNS`；生成器把战后小镇的布局抽成 `town_layout(m, kind)`，三张图布局相同、图腾柱已经修好、`no_switch`，导演 `AfterRoom`）：
  `floor_06_knight_day` 白天（第一天早上 / 下午、第二天早上；对话 `after_k_*`）/ `floor_06_knight_night` 夜里（镇民都在广场上，`after_kn_*`）/ `floor_06_knight_chase` 追逃和 Boss（一个镇民都没有）。
  从小屋 / 工房 / 地牢回「小镇」时，换图会转到这一步对应的那张：`main.change_level` → `StoryDirector.redirect_level` → `AfterStory.redirect_level`
  （步骤的 `where` 是小镇图就用它，不然用步骤的 `town`）。小镇图虽然写了 `no_switch`，以笑为饵 / 追逃 / Boss 期间任务开 `free_switch`，按 C 只在两位公主之间换。
- **推进**：`KnightStory.STEPS` 按顺序（`vars.knight_step` = 下标）：第一天早上 found（和地牢入口的队员说话 → 抬担架）→ wake（工房里醒来，接着是下午）
  → afternoon（下午自由活动，小屋的床上休息到晚上）→ bait（夜里调查广场上暗掉的灯笼 → 以笑为饵）→ sneak（调查营地楼梯的路障 → 通风口）→ cell（地牢）
  → sleep（回小屋睡觉）→ 第二天早上 report（和营地楼梯口的队员说话 → 诅咒失控）→ chase → boss。
  每步 `where` / `town` / `slot` / `objective` / `away` / `trigger` / `cutscene` / `task`（同 `AfterStory.TASKS` 的写法，由 `AfterStory.play_task` 跑：失败放小剧场、
  `reset_items`、回 `respawn` 重来；骑士篇不记赎罪簿）/ `done` / `goto`。`trigger`：
  - `talk`（`npc` 是对话文件名，头上冒「！」——`AfterRoom._sync_marks` 读 `KnightStory.marked_npcs()`，标记用共用的 `AfterTown.set_mark`）/ `inspect`（道具 `talk:floor_06/after_k_objects#节点`）：
	`townsfolk.py` 往那个人的对话最前面插一句、道具节点用 `goto`，条件都是 `eq knight_step = 下标`（`STEP_IDS` 要和 `STEPS` 一一对应，测试核对），台词说完 `call: knight_go` → `KnightStory.go()`；
	`cell` 是目标提示指的格子（不是走进去就演的圈）。
  - `auto`：进图就演，只留给连续的剧情（醒来、溜进地牢以后的牢房、追逃接 Boss）。
  - `rest`：白天在小屋的床上休息（`AfterStory.rest` → `KnightStory.rest_now`，`DayClock.pass_time` 到下一个时段）；`sleep`：夜里在床上睡觉（`sleep_now`，`Sleep.sleep(show_title = false)`）。
  **时间自然变化**：做完一步，下一步的时段在同一天里更晚的话直接换过去（醒来以后已经是下午）；进小镇图时也按这一步的 `slot` 对齐（`sync_slot`）。
  旧存档（`vars.knight_steps_v` 不是 `VERSION`）按 `OLD_IDS` 把第一版的下标换成同一步在新列表里的下标。
  时钟：`DayClock` 的第几天从 `KnightStory.DAY`（8）起，标签写「骑士篇·时段」。开始：第 7 天庆功宴放完烟花按 E 回小屋，进门 `AfterStory.enter_house` → `KnightStory.begin()`
  （黑幕 → 小屋里醒来 `knight_morning`，没人敲门 → 自由活动；`AfterStory.sleep` 里也留着兜底）。测试 / 跳关用 `KnightStory.jump(步骤 id)`。
  任务进行中的目标提示：任务节点有 `target_cell()` 的话指过去（追逃：下一座信标 / 广场）。
- **「故意笑」用 Y**（输入动作 `laugh`；`KnightLaugh`，`levels/floor_06/scripts/knight_laugh.gd`）：按住超过 `HOLD`（0.25）秒就捂着嘴偷偷笑，闷笑每秒 +`RATE`；
  E 只管互动。任务要先拿这一下做别的时 `tick(allow = false)`。K 一直是冲刺。测试用 `KnightLaugh.force_hold`。
  背包最后一页是「键位」（`Backpack.PAGE_KEYS`，按 `KEY_ROWS` 从 InputMap 读键名，`ScrollTextBox` 可以 ↑↓ 滚动；页签一行放不下时自动缩字）。
- **蓝色公主在骑士篇的小镇上闲逛**（`AfterRoom` 在 `KDAY` / `KNIGHT_N` 给她挂 `AfterBlueRoutine`，日程同 `after_blue`）：说话「一起走吧」/「你先去忙吧」
  （`after_partner` 的 `k_talk`，标记 `knight_blue_follow`，不用先赢玩闹）；主线任务（`TASK_FLAG`）和要她帮忙的支线（`KNIGHT_QUESTS`：手印样本、夜里的栅栏）自己跟上，做完回去闲逛。
  追逃 / Boss 的 `floor_06_knight_chase` 和其他小图上她照旧跟着。
- **骑士的行走图**（`tools/art/gen_knight_art.py`）：腿甲 + 铁靴从披风下露出来，迈步看得清；Boss 本体（`TaskKnightBoss.Body`）按移动方向选行、走着才换帧。
- **特效图**（`KnightFx`，`levels/floor_06/scripts/knight_fx.gd`）：codex 生成的一排帧（`assets/generated/fx/`，来源和提示词 `tools/art/src/fx/prompts.md`，
  导入 `tools/art/import_knight_fx.py`）。`KnightFx.play(父节点, 名字, 位置, {size, rot, loop, fps, color, z, squash})`。
  训练室：刺击光刃 / 扫腿弧光 / 命中；追逃：投掷拖尾 / 陷阱落地 / 信标点亮；Boss：诅咒爆发光环 / 冲击波 / 落地尘浪 / 部件碎裂 / 吸笑光带 / 灯笼光柱 / 净化。
- **蓝色公主的千手解放在骑士篇里也生效**：骑士篇的诅咒都不是 `Monster`，放进 `PantsBurst.KNIGHT_GROUP`（`knight_cursed`）组、实现 `on_pants_burst(burst)`：
  `CurseHand` 被扒下来、冻住（能收瓶）；`CurseMark` 暂停；`CursedArmor` 定住 3 秒（和 J 的冻住分开算冷却）；Boss 踉跄 `BURST_STAGGER` 秒、露出破绽，全场贴人的手印扒下来。
  `KnightAI` 的 plan 可以带 `skill: true`（这一帧按技能键）：追逃 / Boss 里的 AI 蓝色公主在合适的时候放（`_ai_burst`）。
- **六个支线 `KnightQuests`**（`levels/floor_06/scripts/knight_quests.gd`，数据 `data/after/knight_quests.json` ← `tools/build/knight_text/quests.py`）：可选，
  串成一条线「被偷走的笑声」——诅咒手印偷的是笑声；每个支线做完（`kq_<id>_done`），那个人在 Boss 最后阶段来帮忙点亮一盏笑声灯笼（`KnightQuests.helpers()`）。
  - 开放（`kq_<id>_open`，委托人头上冒「！」）：步骤下标在 `[opens_at, closes_at)`、时段在 `slots` 里、没做完、没有别的支线在做（一次只做一个）。
	注意 JSON 读出来的数字是 float，比时段要逐个 `int()`（`Array.has` 不把 0 和 0.0 当成一样）。
  - 接下 / 报告 / 先放一放：`quests.inject` 往委托人对话最前面插 offer（`call: kq_start`）/ busy（选项「先放一放」`call: kq_abandon`）/
	最后一段 `report` 的 `call: kq_report`；`dialogue_box` 的 `kq_start / kq_report / kq_abandon`（`vars.kq_req`）。进行中：`kq_<id>_active` + `kq_active`，阶段 `vars.kq_<id>_stage`。
	做支线时主线的触发不出现（对话条件 `not kq_active`），`KnightStory.go()` 也拒绝，床上不能休息 / 睡觉（`KnightStory.bed_text()`）。错过时间窗口的进行中支线自动放下。
  - 每一段 `stages[]`：`where` / `cell` / `text`（目标提示，`KnightQuests.objective`，别的图上用 `KnightStory.guide` 指路：训练室、地窖先指工房的门、工房里指活板门）、
	`unlock`（这一段才开的门的标记，比如 `kq_samples_cellar`）、`report`（回去找委托人）。主线目标后面挂「（支线：…）」（`open_text`）。
  - **剧情**（每个支线一个文件 `tools/build/knight_text/kq_<id>.py`，`quests.py` 的 `_merge_more` 合进去）：
	每一段的 `enter`（进这一段的过场 → `kq_<id>_to<i>`，`stages[].enter_cut`；`KnightQuests.advance` 先演完再进下一段，演的时候再推进不算）、
	`busy`（这一段里找委托人说的话，生成器按段注入，排在通用 busy 前面）、`chat`（玩的时候的闲聊：`[["p" / "b", 台词]…]`，
	`QuestRunner` 每 11 秒按顺序冒一句头顶气泡，蓝色公主要在身边，说到哪记在 `vars.kq_chat_<id>_<段>`）；替换的过场 `CUTS`；
	收尾 `done_cut` 演完接着演背景大图过场 `story_kq_<id>`（`KnightQuests.complete`）。Boss 开场 `knight_boss_open` 之后、开打之前演 `story_knight_boss`
	（主线步骤的 `story` 字段）。暗线只在结尾点到（间接或误导），见上面的伏笔表。
  - **夜里支线的专属图都是等距画面**（`style = iso`）：城墙 `rampart`（矮垛口，墙高 12）、储物间 `storage_wood`、小桥 `drain_water`（两边矮墙当水渠）、
	裂缝 `crack_cave`、旧会堂 `old_hall`（`carry_light = false`，只靠任务给的火把）；加上暗巷 `alley_brick`。主题在 `tools/art/gen_iso_theme.py` 的 `THEMES`。
	等距下的写法：在本地坐标里画「地面上的线 / 圈」用 `IsoView.offset` / `ground_scale`（房檐手印的落点圈、旧刷子的扫动、桥板缝），抬高的东西放精灵 offset（守夜的队长），
	`CurseHand` / `HandShard` 被墙挡住不穿过去（追人改走 `GridPath`），`ZoneFx.body_point`、目标箭头（`ObjectiveMarker`）、任务手提灯的光圈、挂画的 `lift` 都按等距换算。
	守夜蒙眼时不能转镜头（`IsoView.can_rotate`）。
  - 等距走廊的墙角辅助 `IsoMover.corner`：只沿一个轴走被墙角卡住、前面那一格是通的 → 往那一格的中线挪（1 格宽的口子没对准也钻得进去）；等距楼层道具碰撞盒收窄到 `Prop.ISO_BODY_MAX`。
	**空气墙的教训**：CG / 训练小游戏舞台里铺的地牢 TileMapLayer 在 CanvasLayer 里，可 CanvasLayer 不隔开物理——图块碰撞会在关卡同一坐标留下空气墙（守夜城墙卡住过）。
	运行时为画面铺的图块（CG 舞台、训练舞台、IsoTerrain）一律 `collision_enabled = false`（`cg_test` 检查）。
  - **小地图**（小巷、草药洞、地窖、城墙、裂缝、旧会堂、旧仓库、储物间、小桥）：`tools/build/quest_maps.py` 用 ASCII 画（`#` 墙、`.` 地面、小写 = 道具、
	大写 = 标记点），生成时检查每个标记点从入口走得到；标记点按从入口走过去的远近排，写进 `data/after/quest_maps.json`，
	玩法节点用 `QuestMaps.cells(图, 名字)`（`levels/floor_06/scripts/quest_maps.gd`）读（`QuestHide.SPOTS`、`QuestCrack.NAILS` 这些都是 static var）。
	改布局只改 `quest_maps.py`，再跑生成器和 `build_level`；目标格（`stages[].cell`）也从标记点取（`quests.py` 的 `QM`）。
  - 这一段才开的门（`unlock`）开了以后到做完 / 放下都开着（以前过了那一段就关，套着的图走不进去：地窖 → 草药洞、裂缝 → 旧会堂）。
  - **阶段门槛** `gate`（`quests.py` 的 `GATES`）：上一段做完不马上开演，`vars.kq_<id>_gate = i` 记着「这一段在等门槛」——没有玩法节点（不演开场、不开玩法）、
	目标指向门槛；`{"cell", "r"}` 走进圈里（`AfterRoom` / `AfterTown._process` 看到目标的 `quest_gate` 调 `KnightQuests.pass_gate`），
	`{"talk": 对话文件, "lines"}` 找这个人说话（注入到他的对话最前面，`call: kq_gate`，头上冒「!」）。阶段编号不变（runner 里写死的阶段号不受影响）。
	现在的门槛：骑士救公主 宝贝盒前找小莉莉、队长的旧剑术 第一次进训练室和二对一前找队长、没有名字的生日 排练前和许愿前找派对主人、
	点灯笼的小姑娘 逗她笑前找蓝色公主、井边那段走到井边。转阶段的过场（`enter_cut`）还在上一段做完时演（交代下一步去哪），开场 / 玩法在过门槛以后。
  - 段落还可以写：`runner`（这一段换一个玩法节点脚本）、`where = "town"`（现在这一步的骑士篇小镇，白天夜里都行）、
	`talk: {npc, lines, cut}`（找某人说话推进，注入 `call: kq_next`；找委托人自己的排在「进行中」闲话前面）、多个 `report`。
	接下以后只在步骤范围外才自动放下（多段的支线会跨白天黑夜）。套着的图（地窖 → 草药洞、裂缝 → 旧会堂）指路一层一层往里指（`KnightStory.NESTED`）。
	玩法节点做完 / 换段以后用 `live()` 判断，不再触发东西（以前熬药做完还会再开一局，漏掉对话锁）。
  - 玩法节点：`AfterRoom._sync_quest` 在这一段所在的图上摆 `KnightQuests.make_runner`（`RUNNERS[id]`，节点名 `Quest_<id>`，脚本的静态 `runs_on(图, 阶段)`）；
	共用底子 `QuestRunner`（`quest_runner.gd`：`setup()` 摆东西、`cleanup()` 还原、`put()` 摆的东西跟着收走、阶段变了重新 setup 或者自己收走、`status()` 显示在目标下面）。
  - ① **骑士救公主**（小汤姆、小莉莉，第一天早上起，`QuestShoes`）：孩子们抢走鞋（`kq_shoes_start`），光着脚（meta `barefoot` + 状态 `barefoot`）找三处：
	草垛（按住 E 翻）→ 彩带（站在羽毛堆上按住 E 够）→ 鹅卵石小路尽头和小莉莉比「谁先笑」（`LilyDuelShow`：A / S / D 挠她的弱点——回合开始只给动作暗示（脚趾蜷紧 / 缩脚心 / 脚跟往回收），
	`FAKE_HINT_CHANCE` 是假动作；同一弱点挠中 `GUARD_AFTER` 次她护住、换地方；挠错被反挠（闷笑 +`MISS_BACKLASH`、莉莉 −`MISS_RELIEF`）；被挠时亮「!」按 J 缩脚；
	她第一次笑满 = 魔力疲倦释放（`burst()`：星光、释放声、burst 姿势，之后 `BURST_SENSITIVE` 秒更敏感、莉莉追着挠，「!」间隔 ×`CHASE_POKE`），这一局第二次笑满才算输）
	→ 鞋还回来、邀请去小巷 → 「那一天的躲猫猫」（没有灯的小巷 `floor_06_knight_alley`：等距画面 `style = iso`、暖褐砖墙主题 `alley_brick`、主路和岔口都只有一格宽，
	`carry_light = false` 不挂冷光；`QuestHide`：提着小灯找 `FIND`（6）个小孩，`FOUND_R` 以内且中间没隔墙（`GridPath.clear_line`）才算找到，找到的扑上来挠脚心、
	再沿着巷子寻路走回巷口（`GridPath.find` + `GridPath.follow`，不穿墙；重新藏时 `Hider.stop()`），
	笑出声小孩们换地方、笑满重来，灯芯一阵一阵变暗、黑里的 `ShadowHand` 趁机挠（伸过去 / 缩回去也沿格子路走）；奶奶「谁教你们玩这个的！」）→ 「小莉莉的宝贝盒」（集市，`QuestBox`：
	搬着碎片的手印 `HandShard.tease` 躲在货摊布帘下，笑着引出来、挠一下以后抱着碎片晃悠时按 E 抢回来；发卡）
	→ 骑士勋章（`knight_medal`）+ 小汤姆说地牢入口捡到「真骑士的红绳」。前三段一直摆着三片光脚地面和三个举羽毛「长矛」偷袭的小孩（`AfterKid`）。
  - ② **手印样本**（药剂师奶奶，骑士醒来以后，`QuestSamples`）：石板路 / 地牢铁门（几块石头只有一块藏着碎片）/ 工房的地窖（新地图 `floor_06_after_cellar`，
	工房的活板门 `[12, 8]` 只在这一段开；一团手印 `HandCluster`）→ 回去交给奶奶 → 笑声做的、一直往盔甲那边爬 → 还缺三味药 →
	「旧药方」（地窖最里面的小门 → 草药洞 `floor_06_after_herbcave`，`QuestHerbs`：光着脚，`HerbPatch` 笑铃草 / 软须苔 / 哈欠花各 3 株，打哈欠时手印扑上来，笑满撒一株）
	→ 「熬药」（工房的药锅，`BrewShow`：节拍搅锅、药味冲上来按方向压住、溢锅 4 次重熬；奶奶的摇篮曲）→ 安神香（`calm_incense`，要用真心的笑声点燃）。
  - ③ **队长的旧剑术**（队长，骑士醒来以后，`QuestSpear`，训练室 `floor_06_after_drill`：骑士篇小镇的训练室门一直开着；
	做完以后找训练室里的队长「再来一次」→ `QuestSpear.start_replay()`（节点 `Replay_spear`，同样三轮，不推进支线、不给奖励）；
	队长出招时换上出招图 `npcs/captain_cast.png`（`tools/art/gen_captain_cast.py`：行 = 朝向，列 = 蓄力 / 刺 / 扫 / 收招））：
	第一次进门演起手式的开场（`kq_spear_start`，「我也不知道我为什么会」）；三轮（刺击线 / 扫腿圈 / 实战）躲预警，挨打够上限重来这一轮，
	命中前 `PERFECT`（0.25）秒内冲刺 = 完美闪避反挠队长；实战轮要 2 次完美闪避 → 「守夜」（南边城墙的梯子 → 城墙上 `floor_06_knight_wall`，`QuestWatch`：
	房檐手印，哨塔下蒙眼听声躲矛——画面全黑，矛杆在哪边响就往另一边躲，8 下躲 6 下、挨 3 下重来；「两个孩子」）→ 「二对一」（训练室，`QuestDuo`：
	两个人一起练，躲开后的空档挠他、蓝色公主 J 冻住木矛，队长的忍笑满了；手帕）→ 护手绳、「到时候我会在」。
  - ④ **夜里的栅栏**（工匠，以笑为饵以后、只在第一天夜里，`QuestFence`）：城墙脚下的木板堆（`QuestFence.LumberPile`，自带 `Interactable` 出「E」；
	以前木板点和地图上会调查的木料道具重在一起，按 E 先开了调查的对话）扛木板（`busy_hands` + `carry_stone`）→ 三个路口钉门
	（`RhythmLane`，6 个音符命中 4 个；就是追逃里的三道栅栏 `TaskArmorChase.GATES`）→ 广场边的裂缝漏紫光（`kq_fence_crack`）→
	「广场底下的裂缝」（`floor_06_after_crack`，`QuestCrack`：趴着爬、软苔小球按住 E 擦、缝里的手印按 J 抖掉、节拍敲回三根封印钉）→
	「旧会堂」（`floor_06_after_oldhall`，`QuestOldHall`：火把会烧完、旧烛台按 E 续，光里的手印退开、火灭了一起扑；高台下的手印团碎片收齐；
	壁画上的人像全被刮花了——什么也不埋）→ 回去找工匠。房檐上 5 只爬墙手印。
  - ⑤ **没有名字的生日**（派对主人，骑士醒来以后的白天，站在骑士篇白天小镇的篝火边，`after_k_host`）：借东西（`QuestBorrow`，三个人身边的「借」：
	`PartyShow` 试羽毛掸子 A/S/D 绷住 / 不许笑的试吃 E 吃、亮「！」按 J / 脚底按摩器节拍）→ 八音盒坏了（`kq_host_box`）→ 找工匠 →
	训练室后面的旧仓库（`floor_06_after_warehouse`，`QuestWarehouse`：八音盒一阵响一阵停，`WindupHand` 音乐停了才动，躲在箱子旁边看不见；三个零件）→
	八音盒的曲子（`kq_host_lullaby`）→ 生日舞排练 → 忍笑许愿（撑到蓝色公主先笑）→ 「希望明年也有人记得今天」。
  - ⑥ **点灯笼的小姑娘**（蓝色公主，夜里，面包店奶奶 `after_kn_granny` 说她往西南角去了）：冰晶脚印（`QuestFootprints`，这一段她站在旧石灯笼前，
	`AfterBlueRoutine`）→ 逗她笑（`BlueTickleShow` tickle：A/S/D 挠弱点、亮「！」按 J 缩手不然被冻住）→ 笑声不够亮 → 三处回忆：
	井边的冰面（`QuestWell`：滑溜地板、笑声铃铛、雪堆）/ 储物间（`floor_06_knight_storage`，`QuestStorage`：`OldBrush` 旧痒痒刷、旧布偶）/
	排水渠小桥（`floor_06_knight_bridge`，`QuestBridge`：`BridgeHand` 桥下手印，被抓 3 次 / 冲刺 / 笑过头就松手、退回桥头）→ 一起笑（both）→ 灯笼亮了。
- **新陷阱 / 怪物**（都在 `PantsBurst.KNIGHT_GROUP`，千手解放能定住；也实现 `on_ice_barrier`，蓝色公主的冰晶结界 L 能冻）：
  - `ShadowHand`（影子小手，小巷）：只在黑里出现，灯照到就缩回去；灯暗下去时伸出来挠脚背。
  - `HerbPatch`（草药洞的药草）：笑铃草挠脚心、软须苔缠住脚趾（定身）、哈欠花喷粉打哈欠（定身，附近的手印扑上来）。
  - `WindupHand`（发条小手，旧仓库）：音乐响着一动不动，停了看得见她就爬过来挠；躲在箱子 / 木桶旁边它看不见。
  - `OldBrush`（旧痒痒刷，储物间）：挂在墙上，一阵一阵往下扫（先抖一下预警），扫到刷子底下那一竖条里的人。
  - `BridgeHand`（桥下手印，小桥）：从桥板缝冒泡（预警）再伸上来抓脚。
  - `BareFloor`（光脚地面，只对光着脚的粉色公主；铺在关卡的 `FloorObjects`）：稻草垫每走 10 像素闷笑 +1.5%；羽毛堆每秒 +4%、状态 `feather_floor`（×0.6）；
	鹅卵石每秒在「闷笑 +3%」和「疲倦 +3%（舒服）」之间换。图用小镇道具图集的 `straw_mat` / `feather_pile` / `pebble_path`。
  - `HandShard`（手印碎片）：躲在石头 / 木桶底下（走近会晃）；粉色公主 60 像素内故意笑 → 探头 2 秒 → 爬到她脚边拍拍脚背、进瓶子（伏笔）；
	蓝色公主走到 40 像素内就逃，追着逃 1.5 秒还贴着 → 扑上去挠她的大腿（+8%）；冻住 5 秒，走过去按 E 装瓶。
  - `HandCluster`（手印团）：冻住 / 拍散 / 千手解放 → 裂成 3 块碎片；靠近会伸手挠一下。
  - `EaveHand`（爬墙手印）：从房檐底下走 → 落点亮影子 0.8 秒 → 掉下来抓脚（定身 2 秒、每秒闷笑 +5%），连按 J 5 下挣开，6 秒冷却。
  - 诅咒小手统一用 `CurseHand.draw_hand` 画。新道具 `barrel` / `trapdoor` / `straw_mat` / `pebble_path` / `plank_bundle` / `fence_gate` 和两个图标在 `tools/art/gen_knight_quest_art.py`
	（`gen_town_art.gen_props` 加在图集最后，前面道具的位置不变）。
  - 测试：`f6_after_test.tscn -- --knight-quests-only`（`tests/helpers/f6_knight_quests.gd`）；截图 `tests/capture_knight_quests.tscn` → `tools/.cache/shots/knight_quests/`。
- **人物**：骑士 `knight`（`data/actors/npcs.json`，生成器写入）：行走图 `tools/art/gen_knight_art.py`（Python 像素，`npcs/knight.png`，被诅咒附身的 `knight_cursed.png`），
  立绘 `tools/art/src/knight/`（codex 内置 image_gen 生成，提示词见 `prompts.md`）→ `import_knight_portrait.py` 像素化成 `npc_portraits/knight.png`。
- **AI 搭档 `KnightAI`**（`levels/floor_06/scripts/knight_ai.gd`）：追逃和 Boss 里没被操控的那位公主。复用 `CompanionController` 的挣扎 / 躲预警（`danger` 组）/ 打怪 / 跟随，
  中间插一个 task 行为：每帧问任务给的 `plan`（`Callable(ai) -> Dictionary`）：`{to, near, dash}` 走过去、`{hold: true}` 原地不动、`{}` 交给后面的行为。
  冻住、挣扎之类的动作由任务在 plan 里直接调（AI 不按键，任务的按键只认玩家）。`KnightAI.install([粉色, 蓝色], plan, hooks, behaviours)`：换人时没被操控的那位自动用它
  （`PlayableCharacter.ai_factory`）；任务结束 `uninstall()` 换回平时的跟随。挣开、重来时用 `clear_root` 解开定身（`apply_root(0)` 不生效）。
- **A 发现骑士 + 抬担架**（白天小镇东北角地牢入口 `[53, 8]`，和入口边的队员 `after_k_guard_dungeon` 说话才开始，`TaskStretcher`）：队员抬前面沿 `PATH` 走，她抬后面（`busy_hands` + `carry_stone`，离太远队员停下等）；
  诅咒手印（`CurseHand`）从骑士身上爬出来扑向队员——挡在中间，手印碰到粉色公主只是拍拍脚背就散（伏笔），碰到队员他笑倒、担架一歪；歪三次失败（`knight_fail_stretcher`）。
  不会一口气连歪：歪了以后队员笑 `DROP_TIME` + `DROP_GRACE` 秒内不再算，新爬出来的手印过 `ARM_TIME` 秒才算数，多爬出来的那只等缓冲过了才扑。
  抬到工房门口 → `knight_carry_done` → 进工房。
- **B 醒来**（工房，过场 `knight_wake`）：「你这个害王国破灭的凶手！」→ 抓起长矛的起手式让队长沉默（伏笔）→ 被挠痒压制、关进地牢；掉出的旧手帕被她捡起来（伏笔）→ 已经下午了，自由活动。
- **C 以笑为饵**（夜里调查广场上暗掉的灯笼 `[34, 26]` 才开始，`TaskBait`）：手印贴在镇民身上偷笑声；手印怕人，只被粉色公主的笑声引来（闷笑 ≥ 25% 时 30 + 闷笑 × 150 像素内），
  笑到 85% 全图扑来，身上同时贴 5 只失败（`knight_fail_bait`）。让自己笑起来：粉色公主按住 E「偷偷笑」（`KnightLaugh`）；
  蓝色公主身边没有手印时在她身边按 J 挠她一下；痒痒草 / 诅咒地纹（`CurseMark`：轻挠 + 招手印，夜里也看得清、放大）。
  蓝色公主 J 冻住身边的手印（U 千手解放一下子扒下一圈），冻住的走过去按 E 收进瓶子（两个人都能收），收够 6 只。手印贴在粉色身上挠得很轻、疲倦涨得多（伏笔），贴在蓝色身上狠挠大腿。
- **D 夜探地牢**（调查东南角营地楼梯的路障 `[58, 38]` → 通风口 → `floor_06_after_prison`，`TaskSneak`；中途从地牢出口出来了，再调查通风口「钻回去」`call: knight_reenter` → `KnightStory.reenter()`，任务从入口重新开始）：`StealthDirector` / `PatrolGuard` / 木箱躲藏（守卫视野 64、角度 55、走得慢，
  警觉 `alert_rate` 1.6 / `alert_decay` 0.6；从木箱出来找站得下的位置）；被发现 → 挠痒审问椅
  `InterrogationChairShow`（继承 `ErrandWorkStage`：撑过 14 秒，J 挣扎，笑出声加时）→ 送回通风口。走到最里面的牢房 → 对话 `after_knight` 的 `cell`：他把她当灭国的凶手（「来灭口吗，凶手」），
  三个问题（误导证词：十三下钟声、一千只手的笑声和你一样、封印前站着的是你）**最多回答一个**（`knight_answered`），之后一律「凶手，没资格再问」（`knight_refused`）；
  拿出醒来时捡到的手帕（`knight_asked_hanky`）他一把抢回去、说漏一句（「殿下亲手缝的，那时候她才这么高」）。回答过一个或拿出过手帕以后身后才有脚步声：
  蓝色公主走出来 → 他懵了（「两个……一样的脸……」），以为是幻术、喊守卫，不下跪也不叫殿下 → 过场 `knight_cell_end`（「又是这副花猫样」说完自己愣住、
  没拿出过手帕的话她从栏杆塞进去被他夺走；蓝色公主认出手帕和队长那块一样）→ 回小屋门口 → 自己上床睡（sleep）→ 第二天早上自由活动。
- **E 诅咒失控·镇中追逃**（第二天早上，和营地楼梯口的队员 `after_k_guard_camp` 说话 → `knight_erupt` → `floor_06_knight_chase` 的 `knight_chase_open`，`TaskArmorChase` + `CursedArmor`）：盔甲（`CharacterBody2D`，撞墙会滑、
  直线比她快一点、转弯慢）开局在营地楼梯口挣扎 2.5 秒；按顺序点亮四座分在镇上各处的笑声灯笼信标（东北 / 西北 / 西边市场 / 南边城墙，按住 E 1.6 秒，
  亮的一瞬间盔甲被晃停 1.5 秒；目标提示一路指过去），四座都亮了再跑回广场图腾柱下。
  **扔陷阱**（开局每 `THROW_EVERY` 3.2 秒，亮的信标越多越快，全亮 `THROW_FAST` 2.2 秒；亮 2 座一次扔 2 个、3 座以后扇形 3 个，场上最多 `MAX_TRAPS` 8 个；
  落点预判 `aim_points`：她的位置 + 速度 × 飞行时间、拦在去下一座信标的路上、刚冲刺完落在冲刺终点）：盔甲把地牢里的陷阱（`THROWS`：绊索连落笼、地洞（小触手）、痒痒粉喷口、藤蔓、泥沼、黏黏毯子、落笼、倒吊绳套）扔到她前面的路上——
  落点先亮影子 `THROW_FLY` 秒（`Throw`），落地是真的陷阱场景（`scenes/traps/*.tscn`），`TRAP_LIFE` 秒后收走；第一次扔某一种时粉色公主吐槽（`throw_first`）。
  盔甲每隔一阵在她那一行 / 列亮预警线（`danger` 组）再用铁手横扫（挠一下、减速）；盔甲走近栅栏点而她已经跑开时，镇民关上栅栏挡 5 秒（每处一次）；
  蓝色公主 J 冻住盔甲 3 秒（冷却 12 秒）。被抱住：轻挠——闷笑涨得慢、疲倦涨得快（伏笔），连按 J 挣开；抓 3 次失败（`knight_fail_chase`），点亮的信标不灭。
  栅栏只有做过支线「夜里的栅栏」才有（同一批格子 `GATES`）；做过「队长的旧剑术」队长替她挡一次抱住（`captain_block`）；冲刺无敌的时候抓不住、横扫扫不到。
  AI：蓝色公主跟着、盔甲靠近粉色公主时冲过去，冷却一好就冻住它；粉色公主背着盔甲跑开。
- **F Boss「痒铠骑士」**（广场，`knight_boss_open`，`TaskKnightBoss`；场上的东西都是程序画的，放在 `knight_boss_fx.gd` 的 `KnightBossFx`：`Bolt` / `NetCell` / `Dust` / `Shard` /
  `Ring`（有缺口）/ `Mirror` / `Gear` / `WeakSpot` / `Victim` / `Crate` / `LeapShadow` / `Lantern` / `Tentacle` / `Helper` / `Decor` / `Burst`，伤害判定由 `TaskKnightBoss` 每帧问它们；
  屏幕上方的耐久条 `KnightBossHud`）：骑士本人不掉血，只能打诅咒部件（`BossPart`，跟着本体走：`receive_hit` → `hit_part`）。
  - **四个阶段**：铁手套 → 护腿 → 胸甲 → 头盔笑面。部件平时打不动：被蓝色公主冻住（J）、护腿跺完 / 冲撞完 / 跳完卡住（`stuck`）、骑士清醒（`lucid`）时谁的普通攻击都能打。
	**换阶段不黑屏**（`_transition`）：清场 → 部件炸开（`Burst`、顿帧 `HITSTOP`、震屏）→ 骑士踉跄 `TRANS_STAGGER` 秒、喊一句、两位公主各一句（台词 `transition`）→ 下一阶段。
	原来的换阶段过场 `knight_boss_p1~p3` 删掉了。耐久条按部件分段（`PHASE_PARTS`），笑面那一段按灯笼亮了几盏往下掉（`durability()`）。
  - **会动**：平时朝她走（`WALK_SPEED`，保持 `KEEP_DIST`），隔一阵侧跳；出招前站定 `WINDUP` 秒、身上发光（攻击的空当，`body_mode = "windup"`）；
	跳起来砸地（`leap`：落点影子 `LEAP_WARN` 秒，落地砸一圈后卡住）；冲撞撞到木箱（`CRATES`，挡人挡甲片）箱子碎、盔甲卡住。被抓挣开以后盔甲被推开一点。
  - **出招**（每 `attack_interval()` 秒：`ATTACK_EVERY` × 这一阶段剩下的耐久越少越快；不连着用同一招；粉色公主贴近 `SOFT_R` 以内时变慢；第二招起 `COMBO_CHANCE` 接一招）：
	铁手套：扑抓 / 扫腿 / 弹指 / 十指痒网；护腿：跺地痒波 + 召手印 / 冲撞 / 踢沙 / 跳起来砸地；胸甲：诅咒穿戴 / 护心磁吸 / 甲片飞散 / 跳起来砸地；
	笑面：吐笑气 / 呼唤骑士之名 / 镜面笑脸。
  - **每招都躲得开**：新招第一次用时预警时间 ×`FIRST_SLOW`（骑士头上冒「新招！」）；冲刺无敌的时候什么都打不中（`_dodged`）；
	呼唤骑士之名先蓄力 `NAME_WINDUP` 秒，脚下画出 `RING_GAPS` 个绿色的缺口扇形（`NameWarn`），站在缺口方向上冲击波扫不到；护心磁吸半径 `MAGNET_R`、吸力 `MAGNET_PULL` 比走路慢。
  - **反击 = 挠骑士**：掉一个部件 / 卡住 / 喊完骑士之名 / 千手解放 / 完美闪避（学过支线「队长的旧剑术」：命中前 `PERFECT` 秒内才冲刺，
	看 `PlayableCharacter.last_dash_msec`）→ 露出破绽（`WeakSpot`：手腕 / 膝盖窝 / 腰侧 / 脖子）`WEAK_TIME` 秒，打破绽 = 骑士的笑 +`KNIGHT_TICKLE`；
	满了骑士清醒 `LUCID_TIME` 秒（有安神香的话第一次清醒自动点上，多 `INCENSE_BONUS` 秒）；笑面阶段挠满：触手全缩回去、每盏没亮的灯笼 +`LUCID_LANTERN`。
  - **最后阶段在「笑雾之中」**（`floor_06_knight_fog`，剧情步骤 `boss` → `boss_fog`）：广场上胸甲打完不在广场打笑面——`_split_to_fog` 把 `PHASE_KEY` 记成 3、
	发 `finished(true)` 结束 `boss` 这一步 → 过场 `knight_fog_rise`（笑雾和黑雾从石板缝里涌出，把两位公主和帮手吞进去）→ 换图 → `knight_fog_open` →
	`boss_fog` 用同一个 `TaskKnightBoss` 从第 3 阶段接着打（`on_fog()`）。新图是诅咒失控小镇的同一个格局（坐标、掩体、灯笼位都一样），等距 `laugh_fog` 主题、不能转镜头、不挂冷光；
	配乐 `knight_fog`（原曲 + 宿命、战斗、危险、诡异）。骑士被黑雾托在半空（`floating`：画 `npcs/knight_possessed.png` 上排的浮空帧、周围飘笑声字；笑面本来就打不动），
	新立绘 `npc_portraits/knight_possessed.png`（人物表 `knight_possessed`）。外圈黑雾 `KnightFogRing`：半径从 `R0` 每秒收 `SHRINK`，每亮一盏灯笼推回 `PUSH`，
	圈外的人闷笑涨、挂 `fog_tickle`（`buffs.json`）。点灯规则照下面的「全镇的笑声」。
	四盏都亮 → 骑士落地（下排帧）→ **驱散** `KnightDispel`：粉色公主站在骑士身边吟唱（`DISPEL_TIME`，玩家操控她时要站着不动），玩家操控蓝色公主拦黑气小手
	（`FogHand`，从雾圈边上沿格子路扑向粉色公主；攻击 / J 冻碎，AI 蓝色贴近就拍散），右上角 `SideWindow` 小窗看粉色公主读条（C 换人时小窗换成看另一个）。
	小手碰到粉色公主：读条 −`HIT_SETBACK`、闷笑涨、`INTERRUPT` 秒后重新起唱；粉色公主闷笑第一次满 = 魔力释放（小手全散、之后更敏感），第二次满 = 失败
	（`task_boss_dispel` 记着 → 小剧场 `knight_fail_fog` → 重来时灯笼直接亮着、从驱散开始）。读满 → `_purify`（原来的净化过场和结局）。
	`SideWindow` 在等距楼层里镜头跟着投影后的位置。跳关点有「笑雾之中（点灯）/（驱散）」两个。
  - **骑士战败 CG**：四个失败小剧场（`knight_fail_boss` / `_2` / `_3` / `_fog`）的高潮那一步换上横版大图（`assets/generated/KNIGHT_CG/`，codex 生成，
	提示词 `tools/art/src/knight_cg/`，`import_cg.py --knight`；`gen_floor06_after.py` 的 `AFTER_CG_FAIL` 挂上）。
  - **「全镇的笑声」（点灯）**（替换了原来的符文圈共鸣）：四角四盏被吸暗的笑声灯笼（`LANTERNS`），站在旁边按住 E 故意笑（`KnightLaugh`）→ 每秒 +`LANTERN_RATE`；
	AI 搭档站在灯笼下陪着笑（+`LANTERN_AI_RATE`）；做过的支线（`KnightQuests.helpers()`，灯笼顺序 shoes / samples / spear / fence）那个人跑到他那盏灯笼下：
	×`HELPER_MULT`，没人在也自己慢慢亮（`HELPER_SOLO`）。笑面每 `TENTACLE_EVERY` 秒伸一条触手爬向亮得最多的那盏，缠住以后每秒 −`TENTACLE_DRAIN`；
	蓝色公主 J 冻碎、千手解放全缩回去。骑士照样出招，随时可以离开灯笼去躲。四盏都亮 → 光柱汇到盔甲上 → 过场 `knight_purify`（他攥着的手帕从铁手套里飘出来，
	粉色公主接住：「那你就为了她——醒过来啊！」）→ 胜利 → 尾声。
  - **场上的人**（`Victim`）：被挠倒的队员躺着；镇民和护着镇民的队员在掩体（`COVERS`：木箱后、长椅后）之间乱跑、躲着探头，盔甲靠近就逃到最远的掩体。
	手印会贴上去（最多 `MAX_CURSED` 个）：按住 E 1 秒或者蓝色公主冻一下 = 救下来（冻结冷却马上好、被救的队员替她挡一次 `shield`）；有人被贴着超过 `ENRAGE_AFTER` 秒没人管诅咒变强。
	没被贴的短按 E 说话（`talk_to`，有冷却）：奶奶递薄荷糖（闷笑 −`TALK_MINT`）、护着镇民的队员替你挡一下（每人一次），其他人喊一句提示。
	做过支线「队长的旧剑术」：开场 `shield` = 1（队长挡一次）。
  - **沉浸感**：骑士边打边喊（`voice`）、两位公主的应答、墙根爬满诅咒小手（`Decor`，灯笼亮一盏少一点）、重击震屏、部件碎时顿帧、盔甲周身的紫火、
	出招前发光、冲撞残影、跳起来的影子、笑面发光。
  - AI 搭档（`KnightAI`）：两人都躲预警；蓝色公主冻没冻的部件 / 贴着人的手印 / 触手，合适的时候放千手解放；粉色公主贴近本体、打破绽和冻住的部件、去扯搭档身上的诅咒装备；
	最后阶段两人都去离玩家远的那盏没亮的灯笼下笑。
  - **小手**（跺地召的 `CurseHand`）：每只活 15 秒（`HAND_LIFE`），爬进亮着的灯笼光里化掉，说过话的商人 / 奶奶每阶段扫一次（`sweep`），换阶段全部散掉、镇民身上的手印一起清。
	**冰晶结界 L**：部件冻住能打、触手冻碎、心核冻住、被贴的镇民救下来、小手冻住；千手解放 U 也冻部件。
	**机制介绍**：第一次出现时演短过场（`TaskKnightBoss.intro`，`knight_intro_*`，战斗暂停），台词按做过的主线 / 支线换版本；不再出黄字。耐久条在最上层、有深色底板。
  - **帮手**（`KnightHelpers`，`knight_helpers.gd`，做过哪个支线那个人从第一阶段起就在场上）：① 小汤姆、小莉莉（每阶段一次把盯镇民的盔甲引开、帮着扒手印）/
	② 药剂师奶奶（闷笑过七成扔薄荷糖、安神香的烟让小手变慢）/ ③ 队长（每 25 秒挡一次、打冻住的部件）/ ④ 工匠（每阶段打两根木桩、修木箱）/
	⑤ 派对主人（`bonfire_host` 场景 + `KnightAI`，和蓝色公主同一套 AI；每 25 秒放八音盒，全场小手停住、骑士慢一拍）/ ⑥ 旧石灯笼（第五盏灯，一开场就亮，`lights()`）+ 蓝色公主的冻结范围 ×1.3。
	最后阶段 ①～④ 的人跑去自己那盏灯笼下（原来的 `Helper`）。场上的镇民 10 个。
  - **诅咒爆发 / 盯上镇民**（`KnightCurse`，`levels/floor_06/scripts/knight_curse.gd`）：部件耐久 `PART_HP` = 6。铁手套 / 护腿 / 胸甲阶段开始 2.5 秒后、耐久掉到一半时各爆发一次：
	部件打不动，周身 `SURGE_R` 一圈里闷笑每秒 +25%，有人在圈里（笑声被吸）每 1.5 秒给部件回 1 点耐久。破解：铁手套「手印风暴」（三个镇民被贴上，都救下来）/
	护腿「痒波地脉」（地脉 + 镇民搬来三根木桩 `Crate.stake`；粉色公主在 `LURE_R` 以内按住 Y 笑引它冲撞，躲开让它撞断三根）/
	胸甲「护心诅咒」（两颗心核绕胸口转，粉色公主贴着时转得慢；蓝色公主 J 冻住一颗 3 秒，两颗同时冻着就破，冻心核不吃冷却）。破了露出破绽。
	笑面阶段：有灯笼亮了以后每 14 秒「吸笑」4 秒——不站在亮灯笼的光里（`LIGHT_SAFE_R`）闷笑涨、没亮的灯笼掉进度，这段时间灯笼不长。
	没在爆发时每 `HUNT_EVERY` 秒盯上一个镇民（缩在原地、头上紫色「！」，盔甲朝他走）：走到了偷笑声、部件回 `HUNT_HEAL`；粉色公主按住 Y 笑把它引回来。
	耐久条在爆发时罩紫色、写破解进度。测试用 `KnightCurse.auto = false` 关掉自动爆发，再直接调 `start()` / `start_hunt()`。
  - 被抓 / 绊倒累计 `CATCHES` 次失败，从这个阶段重来；失败小剧场按阶段换（`TaskKnightBoss.fail_theater()`，`AfterStory.play_task` 先问任务脚本）。
	战败小剧场都是四幕（①被抓 ②加码：粉色公主挠脚心、蓝色公主挠大腿和屁股 ③两人魔力疲倦满了自动释放，舒服得软下来还在被挠 ④有人赶来 / 盔甲失神）：
	`knight_fail_chase`（追逃）/ `knight_fail_boss`（铁手套、护腿：按在地上）/ `knight_fail_boss_2`（胸甲：诅咒装备）/ `knight_fail_boss_3`（笑面：笑声被吸走）。
	追逃和 Boss 放 `knight_boss` 曲。状态 `vars.task_boss_phase`、`task_boss_caught`。
	截图 `tests/capture_knight_boss.tscn` → `tools/.cache/shots/knight_boss/`。
- **G 尾声**（`knight_epilogue`）：骑士清醒，只对蓝色公主说话，留下半枚王国徽章「交给真正的殿下」；粉色公主「……难道我才是那个『另一个』？」→ `chapter_end`「骑士篇　完」→ 小屋。
  之后的步骤还没做（目标提示「骑士篇的后续还在制作中」）。
- 测试：`f6_after_test.tscn -- --knight-only`（A~D，`tests/helpers/f6_knight.gd`）、`--knight-finale-only`（E~G，`f6_knight_finale.gd`：每招、破绽、救人、诅咒装备、AI 搭档、四个阶段）；
  跳关点「骑士篇·开头」「骑士篇·诅咒失控」。

## 公主状态与换美术素材

- **角色画风（精细像素 / 原像素）**：粉色 / 蓝色公主、派对主人各有一套精细像素图集 `*_hd.png`（行走 256 格、魔法 384 格，派对主人另有攻击图；原 32 格像素图一张不动，随时切回）。
  源图是 **codex 直接画的像素风**（`tools/art/src/px64/`，提示词同目录 `prompts.md`；用户确认过的画风是 `ref_style_walk.png`）：每个角色 6 张——走路 4×4、站着的表情 2×4、
  战损走路 + 战损憋笑 5×4、失控 2×4、魔法 3×6 两张（派对主人再加攻击 4×3）。侧面走路四帧左右脚交替（不是平移）。
  `tools/art/import_sprites_px64.py` 直接导入（源图本身就是像素风，不再压成一个色块一个像素）：切帧（`import_sprites_v2.Sheet`）→ 按人物身体高度把各张源表统一到 `BODY_H`（216，最近邻、缩放比接近 1）→ 排进 256 格。
  运行时 `SpriteSheetAnimator._use_sheet` 按 `UserSettings.styled_path` 换成同名 `_hd.png`（缺图回退原像素图），Sprite 缩到 `HD_ENLARGE`（1.25）/ `HD_SCALE`（8）——人物比原像素图大一圈，offset 放大 `HD_SCALE` 倍（脚底不变），线性过滤（画面按窗口分辨率渲染，缩小时细节不丢），
  `UserSettings.revision` 变了下一帧重选；CG 舞台的公主演员走同一套。`princess.tscn` 的贴图引用 `princess.png`（以前是内嵌的导入贴图，找不到同名图）。
- **设置菜单**（P，动作 `settings`）：`SettingsMenu`（`scripts/ui/settings_menu.gd`，`main.gd` 进场时加上，CanvasLayer 31，打开时暂停；对话 / 过场 / 别的菜单开着时不响应）：
  「角色画风：精细像素 / 原像素」「显示常驻立绘：开 / 关」。设置在 `UserSettings`（`scripts/core/user_settings.gd`，settings.cfg 的 `[display]` 段，先读再改、不覆盖 Audio 的 `[audio]`）。
  关掉常驻立绘：`Dialogue.resident_hidden()`（游戏中、不在对话 / CG / 横版大图 / 过场时）把立绘透明掉，`PortraitFx.active()` 也不放贴片；对话、CG、小剧场里照常。测试 `tests/settings_test`。
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
scripts/training/     TrainingDB、TrainingStats、TrainingStage（训练一 / 三 / 四的基类）、qte_endure / qte_resist / qte_sensitize / maze_release
scripts/core/         …… SaveSystem（存档）、Town（小镇设施）
scripts/ui/           …… ChoiceMenu、SlotMenu、ShopUI、TitleScreen、TrainingMenu、ScrollTextBox（滚动文字面板）
tests/systems_test.gd 人物对话、选择记忆、存档读档、存档点、主界面、文件迁移
tests/floor6_test.gd  第六层地图、楼梯、居民、设施、开场三种选择、第五层 → 第六层
tests/training_test.gd 训练数值与上限、菜单、Esc 跳关列表、新陷阱和组合、四项训练、训练迷宫
tests/story_test.gd   立绘避让、第六层后续剧情、潜入、蓝色公主当主角、第七层
tools/build/gen_floor06.py  第六层地图、对话、过场、小剧场
tools/build/check_dialogues.py  人物对话检查
tools/art/gen_town_art.py  小镇道具、居民和三个关键人物的地图行走图、检查点、存档点
tools/art/import_sprites_v2.py    公主 / 蓝色公主第二版精灵图和魔法图（白底精灵表 → 32px / 48px 图集）
tools/art/import_portraits_v2.py  蓝色公主立绘 / 头像、三个关键人物的半身像素立绘
scripts/controllers/wander_controller.gd  AI 溜达（蓝色公主）
scripts/actors/playable/blue_princess.gd  蓝色公主（可操作角色）
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

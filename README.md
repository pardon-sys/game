# 公主地牢冒险

Godot 4.7 · 2D 俯视角像素游戏。粉发蓝眼、头戴金色小皇冠的公主被关进地牢，需要一路解谜、战斗逃出去。

## 操作

| 按键 | 手柄 | 作用 |
| --- | --- | --- |
| WASD / 方向键 | 左摇杆 / 十字键 | 8 方向移动 |
| E | A | 交互（开箱、开门、拉杆、点火把、读石碑/信）/ 推进对话 |
| J / 鼠标左键 | X | 挥动权杖攻击（可打碎木桶） |
| K / Shift | B / RB | 冲刺（短暂无敌，可穿过尖刺、躲开挠痒） |
| Q | Y | 使用薄荷糖（降低闷笑值） |
| Esc | Start | 暂停菜单（继续 / 重新开始 / 退出） |

## 关卡流程

牢房（拉杆开牢门）→ 火把走廊（点亮火把）→ 守卫室（史莱姆、铜钥匙宝箱）→ 储藏室（木桶）→ 书房（骑士的情书、拉杆开铁栅）→ 尖刺走廊（冲刺穿越，铜锁门）→ 宝库（金钥匙）→ 金锁大门 → 出口楼梯（第一章完）→ **第二层**：落脚点 → 蝙蝠巢穴（羽毛蝙蝠、痒痒粉喷口）→ 幽灵长廊（点火把让痒痒幽灵显形）→ 蜘蛛窝（吐丝减速、多足连挠）→ 机关走廊（旋转羽毛刷、压力板 + 机关手）→ 巨魔大厅（小 Boss 挠痒巨魔，掉落金钥匙）→ 出口楼梯（第二章完）。

## 闷笑值

怪物除了攻击（扣血），还会**挠痒**（累积闷笑值，HUD 心形下方的粉色条）。史莱姆优先选择挠痒：概率75%，冷却0.6秒；普通攻击概率25%，冷却1.2秒。

- 超过 50：移动变慢，时不时发笑
- 超过 80：失控状态1，无法行动，持续大笑；**连按 J / E 挣扎**
- 超过 100：失控状态2，行动限制相同；降回 100 以下切回状态1
- 满 150：笑到脱力，扣半颗心，回落到 100
- 2 秒没有被攻击后自动下降；薄荷糖（Q）立即 -40
- 被抓住（巨魔、机关手）：不能行动，连按 J / E 挣脱，同时降低闷笑值；挣脱后巨魔会僵直一会儿
- 第二层的怪物更爱挠痒：蝙蝠 90%、幽灵 100%、蜘蛛与巨魔 85%；挠痒时有合成的果冻"啵叽"声

## 架构

基类、接口、组件和"如何新增怪物/物品/友军/陷阱/可操作角色"见 **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**。

## 表情系统

11 种状态：普通 / 开心 / 生气 / 难过 / 惊讶 / 害羞 / 战损 / 非战损憋笑 / 战损憋笑 / 失控1 / 失控2。公主全身立绘常驻屏幕左侧，离开对话后仍显示；小人、立绘和HUD头像使用同一个最终显示状态；气泡复用对应情绪符号。

受到实际伤害或闷笑值超过80后，本次生命永久战损，回血不会修复，复活清除。显示优先级：失控2 > 失控1 > 憋笑（按战损区分）> 战损 > 剧情表情 > 普通；死亡定格淡出。旧剧情“大笑”已迁移为“开心”。

- 事件自动触发：开箱/金钥匙/击败敌人→请求开心，读情书→请求害羞；受伤→战损，异常状态优先于这些剧情请求。
- 对话脚本逐句指定：`data/dialogues.json` 中每句的 `emotion` 字段。
- 代码中调用：`GameState.emote("shy", 2.0)`（时长 ≤0 表示一直保持）。

## 修改内容

- **对话**：直接编辑 `data/dialogues.json`。
- **地图**：编辑 `tools/build/dungeon_01.txt`（`[legend]` 定义字符含义，`[map]` 为地图），然后重新构建：
  ```
  Godot --headless --path . --script res://tools/build/build_level.gd -- level=dungeon_01
  ```
  也可以直接在编辑器里打开 `scenes/levels/dungeon_01.tscn` 修改（注意重新构建会覆盖编辑器里的改动）。
- **公主精灵与立绘**：保留原始 `princess2.png` / `princess3.png` / `portraits2.png` / `portraits3.png`。`tools/art/import_princess2.py` 去除白底、表格和标签，输出 `princess.png`（32×32，11行×16列）、`portraits.png`（113×152每格）和 `portrait_heads.png`（32×32每格）。图集顺序由 `data/actors/princess_visuals.json` 统一定义，运行时与导入器共同读取。
  - 每行依次为下、左、右、上，每方向4帧；左右使用独立素材。失控2原图每方向只有两幅宽姿势，按1、2、1、2重复为四帧，完整保留横卧身体。
  - 攻击/冲刺复用状态帧与既有刀光/残影；受击闪白，死亡定格淡出，没有新增绘画素材。
  - 立绘和头像按姿势取景，预览包含状态、方向和帧编号。
  ```sh
  conda activate test_for_master
  python tools/art/import_princess2.py --preview
  ```
  预览输出到 `tools/.cache/p2/`；四张原图不会被覆盖。
- **受挠台词**：全部在 `data/princess_reactions.json`。`lines` 是通用台词（平静、憋笑、失控1、失控2、被抓）；`sources` 按怪物/陷阱分别写：第一次被它挠痒时的剧情对话 `first_encounter`、各阶段专属台词（没写的阶段自动用通用台词）、怪物头顶的回嘴 `taunts`。台词出现在常驻立绘旁，不暂停战斗；同档 1.6 秒内不刷新，跨档立即更新，2.4 秒后消失。
- **公主笑声**：轻笑使用 cicifyre 的CC0素材；闷笑值>80使用 moxobna 的CC0自然笑声，去除长停顿、交叉淡化接缝后连续循环。专用单通道避免叠音，降至80及以下、死亡或暂停停止，恢复游戏后仍处于失控则继续。来源与处理记录见两处音频目录中的 `License.txt`。
  - `assets/third_party/cicifyre_voice/`：轻笑及旧单次大笑素材。
  - `assets/third_party/moxobna_voice/laugh_loop.wav`：当前使用的连续大笑；可用 `tools/art/build_laugh_loop.py` 从源文件重新制作。
- **立绘细节**：立绘以 2 倍像素密度生成（画面拉伸模式 `canvas_items`），脸部区域的眼睛、嘴、泪滴颜色会被优先保留；表格位置自动检测，重画素材只要保持表格形式即可重新运行导入脚本。
- **音效**：`tools/art/gen_sfx.py` 合成果冻挠痒声（4 种）以及吐丝、喷粉、刷子、抓取声，输出到 `assets/generated/sfx/`。
- **第二层地图**：`tools/build/dungeon_02.txt`，构建命令 `... build_level.gd -- level=dungeon_02`。
- **其它像素美术**：`tools/art/gen_misc.py` 另外生成第二层机关占位图（`new_props.png`、`grab_hand.png`、`feather_brush.png`）；`tools/art/gen_misc.py` 生成表情气泡、道具、机关、墙体拼接图集（`gen_princess.py` / `gen_portraits.py` 是最初程序绘制的版本，现在只输出 `*_procedural.png` 备用）。

## 测试

```
Godot --headless --path . res://tests/smoke_test.tscn   # 检查交互、11状态、音频、战斗、物品和复活，退出码0为通过
Godot --headless --path . res://tests/floor2_test.tscn  # 第二层：关卡切换、减速/抓取、新怪物、新陷阱、立绘密度
Godot --path . res://tests/capture.tscn                 # 11 种状态截图到 tools/.cache/shots/
Godot --path . res://tests/capture_floor2.tscn          # 第二层各房间截图
```

## 目录

```
scenes/   main.tscn、levels/、actors/{playable,monsters,allies}/、traps/、items/、objects/、ui/
scripts/  core/、components/、controllers/、actors/、traps/、combat/、items/、objects/、autoload/、ui/、fx/、main.gd
data/     dialogues.json、items/、monsters/、allies/、actors/（数值与动画配置资源）
docs/     ARCHITECTURE.md
assets/   generated/（自绘）、third_party/（Kenney）、fonts/、tilesets/、lights/
tools/    art/（Python 美术生成）、build/（关卡构建、工程设置脚本）
tests/    冒烟测试与截图脚本
```

## 素材与许可

- [Kenney Tiny Dungeon](https://kenney.nl/assets/tiny-dungeon)、[Kenney RPG Audio](https://kenney.nl/assets/rpg-audio)：CC0
- [Fusion Pixel Font 缝合像素字体](https://github.com/TakWolf/fusion-pixel-font)：SIL OFL 1.1（见 `assets/fonts/OFL.txt`）
- 公主小人与立绘：项目作者提供（princess2/3.png / portraits2/3.png）
- 公主笑声：cicifyre / moxobna，CC0，详见各自目录随附 License.txt
- 表情气泡、道具、机关、墙体拼接图块、第二层机关占位图：本项目用 Python 生成
- 挠痒果冻声等音效：本项目用 Python 合成（tools/art/gen_sfx.py）

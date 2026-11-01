# 共性优化需求

用户反复提到的、所有新内容都要满足的要求。做 UI、对话框、提示框、小剧场、CG、演出时先过一遍这份清单；
用户再提新的共性需求，就追加到对应的一节（写清楚是什么、为什么、怎么检查），不要另起文件。
本机的 Claude Code 技能 `.claude/skills/polish-rules/` 会让 Claude 在这些场合先读本文（`.claude/` 不进仓库，规则正文以本文为准）。

## 1. UI 文字不出框

**要求**：对话框、提示框、选项菜单、情报、背包说明、商店、训练面板……所有文字都不能超出它的方框。放不下的部分改成**滚动**，
而且每次打开 / 换内容时滚动条在**最上面**（从第一行开始看）。

**怎么做**：
- 多行文字优先用 `ScrollTextBox`（`scripts/ui/scroll_text_box.gd`）：`ScrollTextBox.make(Rect2)` 固定大小、自动换行、内容高了出现像素风滚动条；
  换内容先 `clear()` 再加，最后 `scroll_to_top()`（或 `scroll_vertical = 0`）。
- 自己写的 `ScrollContainer` / `RichTextLabel`：换内容时把 `scroll_vertical` 设回 0（`RichTextLabel` 用 `scroll_to_line(0)`）；
  只有「刷新同一页的数值」（例如背包状态页每帧刷新）才保留原来的滚动位置。
- 滚动条样式统一用 `ScrollTextBox.style_scrollbar(bar)`。
- 不要用 `clip_text`、`visible_characters` 截断或缩小字号来塞进框里；单行标题放不下就换行或加宽框。
- 键盘 / 手柄能滚：↑↓（`scroll_by`）或翻页键；鼠标滚轮可滚。

**检查**：用最长的那条文字截图看一遍（`tests/_shots_*.gd` → `tools/.cache/shots/`）；打开、关掉再打开，确认滚动条回到顶端。

## 2. 小剧场 / CG / 演出的演绎

**要求**：
1. **立绘和精灵图都是动态的**：
   - 舞台上的人物要走位、蹦、抖、换姿势（`enter / move / hop / shake / pose`）；
   - 立绘跟着剧情换表情（`portrait` / `emotion`），不要一张立绘从头站到尾。
   - **精灵图一定要动，不能定格在一帧**：失控、憋笑、被挠的人播循环动画（`helpless` / `giggle`，`princess_sprites.tres` 里 4 帧循环）。
     - `CGActor.set_pose` 换到失控 / 憋笑类视觉状态（`CGActor.LOOP_ANIM`）时没指定动画，会自动配上循环动画；
     - `tickle` 时被挠的人如果站着没在笑，自动换成憋笑循环（`CGActor.start_giggle`）；
     - 公主以 npc 形式上场（`kind: npc:blue_princess` 等）也套用 cast 里的 `visual` / `anim`；
     - **不要**给失控 / 憋笑状态写 `anim: idle`（idle 只有一帧）。
     - 教训（攻防战失败小剧场的精灵定格过）：`cg_player._build_cast` 的 npc 分支以前忽略 `visual` / `anim`，`CGActor.make_npc` 强制 `idle`（只有一帧），`pose` 动作只换行不换动画。
     - 自动检查：`cg_test` 的「小剧场里的精灵都会动」遍历所有 `data/theater/**`。
   - **小剧场里要有角色的笑声**：憋笑放憋笑声（`voice giggle`），失控一 / 失控二放大笑声（`voice laugh`）。
     - 笑声是靠步骤里的 `voice` 动作放的（这个设计保留）：**新写的小剧场要写 `voice`**——开头 `giggle`，换成失控 / 魔力释放那一步 `laugh`，结尾 `""`；
     - 生成器兜底：`gen_floor06_after.py` 的 `_with_voice` 给换成失控（`pose helpless_*`）/ 魔力释放（`act = burst`）而没写 `voice` 的那一步补 `voice laugh`、换成憋笑的补 `voice giggle`；
     - 运行时再兜底：`CGPlayer._auto_voice` 在换姿势和被挠以后按舞台上公主的姿势往上切（默认设置）；剧场自己写的 `voice` 照旧生效；
     - 教训：以前只有开头那句 `voice giggle`，人物笑到失控了还是憋笑声，听起来像没在笑。
     - 自动检查：`cg_test` 的「小剧场的笑声跟着姿势」。
   - **小游戏窗口里的人物也要跟着闷笑度换姿势**（憋笑 → 失控一 → 失控二）：
     - 小游戏（`TrainingStage` / `ErrandWorkStage` 子类）里的人物是 `CGActor` 木偶，开场摆个 `normal` 以后不会自己变；
     - 打开 `follow_laugh = true`（在 `_init` 里设），`TrainingStage._update_bars` 每帧按 `actor_laugh_ratio(id)` 同步姿势（`sync_actor_poses`）；
     - 玩家那位（`princess`）默认读真闷笑；双人的小游戏覆盖 `actor_laugh_ratio`，让另一位跟她自己的数值（如 `blue_laugh`）；
     - 爆发、施法等特殊姿势不会被覆盖。
     - 教训：骑士篇支线的熬药 / 派对 / 点灯笼 / 莉莉对决开场 `set_pose("normal")` 以后一直不变，而且覆盖了 `_punish`，连失控姿势都没有。
2. **挠痒特效、抖动都要出现在图上**：
   - 每一句「正在挠」的台词，都配一条 `tickle` 指令（`who / by / repeat / interval / fx`）；
   - 横版 CG 大图上的命中贴片、抖动、飘字由 `cg_tickle` / `Dialogue.shake_portrait` 自动处理，前提是那一步有 `tickle`；
   - 爆发时配 `flash`、`sfx`。
3. **流程要长**：
   - 一段完整的挠痒演绎参照现有长度：笑倒 CG 约 29 句，攻防战失败小剧场约 34 句（CG 前约 12、CG 后约 22），七日赎罪的失败小剧场约 30 句（CG 前约 10、CG 后约 20）；
   - **CG 放出后要有大量文本**（大头在 CG 后），CG 前的正常状态少一点；
   - 不要三五句就结束。
4. **至少有一次魔力疲倦满了释放、释放后被接着挠**，按四幕走（每一步标 `act`）：
   1. 被抓住、嘴硬；
   2. 弱点被找到、开始破功；
   3. 魔力疲倦满、爆发：用 `tools/build/burst_lines.py` 的 `burst_steps(...)`，`act = "burst"`，立绘 `fatigue_burst`，`sfx star_burst` + `water_release`，怪被震开再回来。爆发后全身更敏感，被接着挠；
   4. 彻底笑倒、认输。
   - 两个人同框时，两个人各爆发一次。
   - 立绘按幕换：`defeat_1 → defeat_2 → fatigue_burst → defeat_2`。
   - 参照：笑倒 CG（`gen_cgs.py`）、组合演出（`gen_combo_scenes.py`）、攻防战失败小剧场（`siege_text/theaters.py`）。
5. **人物性格和弱点**照 `ARCHITECTURE.md`「内容准则」：
   - **粉色公主**写脚（脱鞋袜、掰脚趾挠趾缝、刮脚心、沿足弓刷、捏脚跟）。开朗倔强，叫嚷反抗，边笑边求饶。
   - **蓝色公主**写大腿 / 屁股（揉腿根打圈、沿大腿内侧上移到腿根为止、轮流捏屁股、交界处轻刮）。寡言嘴硬，短句带省略号，越痒句子越碎，破防后小声服软，不用固定口头禅、不重复同一句。
   - 每段都用那个人 / 怪 / 陷阱**自己的工具**写具体手法；反应分 `light / mid / heavy`（释放后 `sensitive`）三档，同一档给足变化。
6. 细节（几幕、谁先爆发、哪张 CG 放哪一幕）不确定时，先用选项式提问向用户确认。

**检查**：
- `CG.validate()`（`cg_test`）检查引用；攻防战文本跑 `check_siege_text.py`。
- 截图看一遍每一幕：大图有没有抖、贴片有没有出来、立绘有没有换。

## 3. 生成的人物图

- 服装照立绘：两位公主和派对主人都穿露肩装、前短的裙子（正面能看到一点大腿）。
  - 粉色：白色中长筒袜、粉色蝴蝶结玛丽珍鞋；
  - 蓝色：白色荷叶边短袜、蓝鞋、两侧小发髻；
  - 派对主人：红色绑带凉鞋、金色小王冠配红花。
- **光脚看场景**：和挠痒相关的场景（被挠的人）光着脚；和挠痒无关的场景照常穿鞋袜（照立绘）。**不要特意把脱下的鞋袜摆在旁边当道具**。
  光脚时**脚和脚趾要画对**——每只脚五个脚趾、比例自然、脚心足弓清楚，没有多 / 少 / 粘连的脚趾。提示词里写明，出图后在总览里逐张检查脚，画错的重画。
- **人体正确**：每个人只有两条腿、两只脚（一左一右，大脚趾在内侧，和身体朝向一致）、两只手；四肢分开、不交叠成一团，不画多余的腿 / 脚 / 手。
  构图别太复杂，保证每条腿、每只脚都看得清。提示词里写明，出图后逐张放大检查（攻防战第 2 / 6 / 8 / 11 波返修过：左右脚反了、多一条腿）。
- **姿态多样**：同一组 CG 的姿势、表情、动作要各不相同（趴着蹬脚、背靠背被绑、跪坐埋脸、仰躺大笑、咬唇憋笑、合十求饶……），
  在提示词里逐张写明，不要让模型默认成「两人坐着抱膝捂脸笑」。
- 参考图用立绘：`assets/generated/portraits.png`、`assets/generated/blue_princess/魔法吟诵.png`、`assets/generated/bonfire_host_portraits/portraits1.PNG`。
- 画风：
  - 地图上的像素图走 Q 版像素风，不要写实；精细像素（256 格）= **codex 直接画的像素风，直接导入**（只按人物高度统一大小，不压成一个色块一个像素、不做程序像素化 / 平滑），游戏里人物比原像素图大一圈；
    走路帧要左右脚交替（侧面四帧：左脚在前 → 交错 → 右脚在前 → 交错），不能只是平移；
  - 剧情大图 / CG 走**高清精致的日系插画**（参照 `assets/generated/BOSS_CG/`）：线稿细腻干净、头发皮肤眼睛有柔和的高光、明亮的糖果色、柔光和闪光点；
    **完整人物构图**：画到的人物从头顶到脚尖都在画面里，不被边缘切掉。
  - 都是成年人，姿势自然、不性化。
- 新图先拼一张总览给用户确认服装和弱点，再导入游戏。原图保留，方便回退。

# Pixel Observatory 版本历史

本文档记录 Pixel Observatory / Starlight Observatory 从早期原型到当前教学版本的主要演进。所有版本统一使用“目标、功能与内容、修复与调整、验证”四个部分；历史版本没有独立验收记录时会明确注明，不补写无法确认的结果。

日期说明：早期版本沿用开发记录中的版本标签；2026-07-06 之后的条目尽量使用实际修改日期。已有历史条目全部保留，新增条目继续使用相同格式，不以新版本覆盖旧记录。

## v0.1 - 项目替换与 MVP 基础

**目标**

将原射击测试项目替换为 2D 像素天文观测教学游戏，并建立可运行的最小主循环。

**功能与内容**

- 项目更名为 Pixel Observatory，主入口切换为 `main_menu.tscn`。
- 建立 `GameManager`、`SaveManager`、`MissionManager`、`AssemblyManager`、`TelescopeMath` 和 `ObservationSystem`。
- 建立 `telescope_parts.json`、`celestial_objects.json`、`levels.json` 和 `localization.json`。
- 跑通 Main Menu、Observatory Room、Telescope Assembly、Sky Observation、Telescope View、Learning Card 和 Learning Journal。

**修复与调整**

- 明确早期界面过度文字化、主观测室空间感不足、交互点和任务流程不清楚等后续改造方向。

**验证**

- 历史原型版本，当时未保存独立自动化验收报告。

## v0.2 - Observatory Room 初版

**目标**

将纯 UI 流程改造成玩家可以实际走动和探索的 2D 主基地。

**功能与内容**

- 新增可移动玩家角色，支持 WASD、方向键和靠近后按 E 交互。
- 增加 Mission Board、Parts Cabinet、Assembly Table、Observatory Door、Telescope Pad、Learning Journal 和 Stats Terminal。
- 支持鼠标点击交互点。
- 顶部 HUD 显示 Level、Credits、Telescope Status 和 Mission，底部提示随附近物体变化。

**修复与调整**

- 记录农场/工坊素材拼接导致主题不统一、地板边缘混乱和路线不明确的问题，作为后续主观测室重做依据。

**验证**

- 历史原型版本，当时未保存独立自动化验收报告。

## v0.3 - 主观测室重做

**目标**

将户外拼贴场景改造成可信的学校天文社和小型天文台基地。

**功能与内容**

- Observatory Room 改为天文社基地布局，新增 `observatory_interior.tscn`。
- Observatory Door 与 Telescope Pad 均可作为观星入口。
- 未组装望远镜时引导玩家前往 Assembly Table；完成组装后引导前往观测入口。

**修复与调整**

- 减少切片家具重新拼接造成的透视错误，为“完整背景图 + 透明交互层”方案做准备。

**验证**

- 历史场景版本，当时未保存独立自动化验收报告。

## v0.4 - Assembly Table 可玩化

**目标**

将望远镜组装台从调试按钮页改造成清晰的核心玩法界面。

**功能与内容**

- 形成左侧 Parts Tray、中间 Assembly Blueprint、右侧 Inspector / Stats 的三栏结构。
- 零件卡片显示图标、双语名称和安装状态。
- 支持“选择零件 -> 点击蓝图槽位 -> 完成安装”的交互。
- 增加安装顺序、错误槽位、wrong attempts 和 Finish Assembly 完整性检查。

**修复与调整**

- 修复早期零件图标溢出卡片的问题。
- 安装状态改为读取 `GameManager.progress["assembly_state"]`，不再错误地使用 unlocked 状态。

**验证**

- 历史组装版本，当时未保存独立自动化验收报告。

## v0.5 - 第一关完整流程

**目标**

跑通 New Game、月球任务、观测识别、学习卡和日志记录的完整闭环。

**功能与内容**

- New Game 默认 `telescope_ready = false`，完成五个核心部件后设为 true。
- Mission Board 显示 L1 Moon 任务，Sky Observation 可查找并选择 Moon。
- Identify Moon 后完成任务，Learning Card 显示知识内容，Learning Journal 写入记录。
- 完成 L1 后增加 credits 并推进 current level。

**修复与调整**

- 移除识别前直接暴露目标真实名称的行为。
- 减少星图目标看起来像普通按钮的视觉问题。

**验证**

- 首条完整手动流程通过；当时未保存独立自动化验收报告。

## v0.6 - Sky Observation 视觉升级

**目标**

让观星界面成为教学型像素星空，而不是普通按钮列表。

**功能与内容**

- Moon、Polaris、Sirius、Betelgeuse、Mars、Jupiter、Orion Nebula 和 Andromeda 使用不同视觉表现。
- 透明 Button 仅作为点击热区，选中目标显示金色细框。
- 右侧面板显示任务提示、选择状态、Observe 和 Back。

**修复与调整**

- 识别前不在星图上显示真实名称，避免提前泄题。

**验证**

- 历史视觉版本，当时未保存独立自动化验收报告。

## v0.7 - Telescope View 视觉升级

**目标**

让正式观测阶段更接近通过真实镜筒观察天体的体验。

**功能与内容**

- 中央改为圆形望远镜视场，外部使用深色遮罩和金属镜筒边缘。
- 不同天体使用不同图像。
- Excellent、Good、Fair、Poor 和 Failed 质量影响清晰度、亮度与噪点。
- Identify 保留真实名称作为答题选项，选错不会完成任务。

**修复与调整**

- 将“观察到什么”和“识别出什么”拆分为两个阶段。

**验证**

- 历史视觉版本，当时未保存独立自动化验收报告。

## v0.8 - Parts Cabinet 与 Assembly Table 分离

**目标**

修正信息架构，避免零件仓库和组装操作混在同一个界面。

**功能与内容**

- Parts Cabinet 仅查看库存、说明和状态。
- Assembly Table 负责进入 `telescope_assembly.tscn` 并执行安装。
- `GameManager` 增加 parts 场景映射。
- 组装完成后明确引导玩家前往 Telescope Pad 或 Observatory Door。

**修复与调整**

- 组装台左栏统一命名为 Parts Tray / Available Parts。

**验证**

- 历史信息架构版本，当时未保存独立自动化验收报告。

## v0.9 - 主观测室完整背景图方案

**目标**

停止拆分家具素材重拼，使用完整背景图承载稳定的空间关系。

**功能与内容**

- 使用完整 Observatory Room 背景图。
- 玩家、透明交互层和 HUD 叠加在背景上。
- 靠近交互点时只显示细边框，并保留返回位置逻辑。

**修复与调整**

- 修正 Telescope Pad、Stats Terminal 和 Learning Journal 等交互框尺寸。
- 调整玩家 spritesheet、显示比例和脚底锚点。

**验证**

- 历史场景版本，当时未保存独立自动化验收报告。

## v1.0 - 玩家角色动画规范化

**目标**

解决方向错误、串帧、头部残影和脚底锚点漂移。

**功能与内容**

- 新增 `player_observer_4dir_clean.png`，采用 4 列 x 4 行布局。
- 行顺序统一为 down、left、right、up；每行第一帧 idle，后三帧 walk。
- 视觉尺寸和碰撞尺寸分离，交互检测改用脚底位置。

**修复与调整**

- 固定角色脚底锚点，消除不同方向动画的位移跳动。

**验证**

- 历史角色版本，当时未保存独立自动化验收报告。

## v1.1 - 真实星体位置系统

**目标**

让 Sky Observation 根据当前观测时间和地点计算天体方位。

**功能与内容**

- 新增 `SkyPositionService.gd`、`celestial_catalog.json` 和 `observing_config.json`。
- Moon、Mars、Jupiter 支持 AstronomyAPI 在线位置。
- Polaris、Sirius、Betelgeuse、Orion Nebula 和 Andromeda 使用本地 RA/Dec 计算。
- 在线请求失败时自动使用离线 fallback，目标低于地平线时也不会阻断主线。

**修复与调整**

- API secret 仅从本地 `data/local_api_keys.json` 读取，该文件加入 `.gitignore`。
- 禁止在脚本中写死密钥。

**验证**

- 在线与离线回退路径完成手动验证；当时未保存独立自动化报告。

## v1.2 - 教学节奏调整

**目标**

让原理讲解出现在第一次实际操作之前，而不是只在任务完成后出现。

**功能与内容**

- 新增并强化 `TeachingFlowManager` 与 Concept Brief。
- 分离 seen teaching steps、seen concept briefs 和 completed concept cards。
- Assembly、Sky Observation 和 Telescope View 可触发不同的操作前教学。
- 任务完成后仍保留 Mission Complete 和学习卡总结。

**修复与调整**

- 避免教学提示与任务完成状态混用。

**验证**

- 历史教学版本，当时未保存独立自动化验收报告。

## v1.3 - Focus Knob 成为真实部件

**目标**

让调焦能力来自实际安装的部件，而不是无条件出现的 UI。

**功能与内容**

- 新增 Basic Focus Knob，Assembly Table 支持安装。
- `TelescopeMath` 新增 `focus_control_score`。
- Sky Observation 与 Telescope View 显示方位角、俯仰角和 DMS 信息。

**修复与调整**

- 未安装 Focus Knob 时明确提示无法完成精确调焦。

**验证**

- 历史调焦版本，当时未保存独立自动化验收报告。

## v1.4 - Learning Card 图解放大

**目标**

让学习图解成为主要教学内容，而不是难以阅读的缩略图。

**功能与内容**

- Concept Brief 图解放大到页面主视觉区域。
- Mission Complete 中的 Concept learned 图获得更大阅读面积。
- 光路、焦平面和调焦图解统一使用 `STRETCH_KEEP_ASPECT_CENTERED`。

**修复与调整**

- 保持原图比例，避免图解拉伸和裁切。

**验证**

- 历史学习卡版本，当时未保存独立自动化验收报告。

## v1.5 - Orion Nebula 通关体验修正

**目标**

解决玩家在早期深空关卡中感觉“怎么调焦都没有用”的问题。

**功能与内容**

- L7 Orion Nebula 允许 Fair 质量通关，L8 再要求 Good 以教学大口径集光。
- UI 区分焦点未对准、焦点正确但设备不足、已经可以识别三种状态。

**修复与调整**

- 更新 `focus_nebula_test`、`flow_test` 和 `v2_progression_test`。
- 避免将设备能力不足错误描述成调焦失败。

**验证**

- 对应调焦和流程测试通过。

## v1.6 - Main Menu 正式化

**目标**

将简陋按钮菜单改造成完整的 Starlight Observatory 首页。

**功能与内容**

- 使用完整主菜单背景，统一为 1024x768。
- New Game、Continue、Settings、Language 和 Quit 使用透明按钮热区。
- Hover 显示轻微金色高亮，Pressed 状态轻微变暗。

**修复与调整**

- Continue 无存档时仅提示 No save found yet，不再用黑色遮罩破坏按钮颜色。

**验证**

- 历史主菜单版本，当时未保存独立自动化验收报告。

## v1.7 - Sky Observation 模式按钮统一

**目标**

统一 Eye、Finder、Scope 三个模式按钮的视觉和状态。

**功能与内容**

- 接入统一按钮素材并预处理为 `sky_view_mode_buttons_uniform_250x76.png`。
- 使用透明点击热区，当前模式显示细金色边框。

**修复与调整**

- 不再用互相冲突的底色表示 unavailable 和 inactive。

**验证**

- 历史模式按钮版本，当时未保存独立自动化验收报告。

## v1.8 - Jupiter 观测贴图升级

**目标**

让 Jupiter 的正式观测画面能够体现观测质量变化。

**功能与内容**

- 新增 `jupiter_clear.png`、`jupiter_blurry.png` 和 `jupiter_dim.png`。
- Excellent / Good 使用 clear，Fair 使用 blurry，Poor / Failed 使用 dim。
- 保留 `jupiter_large.png` 作为 fallback。

**修复与调整**

- 统一质量结果与 `visual_effect` 对贴图状态的选择逻辑。

**验证**

- Jupiter 三状态截图与对应观测流程完成验证。

## v1.9 - 高级望远镜、交互动画与完整观测 HUD

**日期**

- 2026-07-19
- 功能提交范围：`cb9f5c8..c254d56`

**目标**

将 45 关教学框架、牛顿式望远镜流程、装配反馈、调焦与环境效果、观测 HUD 和首次教学整合成可连续调试的版本，并解决近期截图中出现的图层、瞄准框、锁定反馈、乱码和素材背景问题。

**功能与内容**

- 关卡与开发调试扩展到当前 45 关数据，等号键开发者面板可跳转和调整已实现关卡。
- 扩展牛顿式、多布森式、卡塞格林/格里高利式、红外、射电和多波段观测框架。
- 牛顿式流程增加折射镜色差动机、反射原理讲解、镜筒子装配、准直、正式装配和后续观测。
- L22-L25 使用折射镜展示织女星等远距离目标的色差，后续牛顿镜流程展示无色差对比。
- 接入织女星正式观测贴图，并保留 clear、blurry、dim 和色差演示状态。
- Advanced Assembly 主装配与镜筒子装配显示真实透明零件 PNG；安装槽位、贴图、完成边框、OK 标志和点击区域按正确层级排列。
- Tripod、Mount、Finder Scope 复用折射式正式贴图，Newtonian OTA 使用 `newtonian_tube_complete.png`。
- 零件安装增加卡片高亮、移动、吸附、成功、错误返回和具体原因反馈。
- 准直界面增加光轴变化、分数反馈、阈值提示和完成状态动画。
- 新增统一 `InteractionFeedback`，为重要按钮提供 hover、press、success、error 和页面切换反馈。
- Eye、Finder、Scope 切换增加克制的缩放、淡入和目标尺寸过渡，不改变真实坐标。
- 调焦旋钮、追踪旋钮、寻星镜校准、目标锁定、云层、视宁度和地球自转漂移增加连续视觉反馈。
- 增加“减少动画”设置，关闭大幅移动和呼吸效果时仍保留必要状态反馈。
- 第一次进入观测、组装、镜筒子装配、准直、寻星镜、调焦、云层、漂移和新望远镜家族时提供一次性高亮教学。
- 识别题在答题前显示天体特征指南，A-D 正确答案随机分布，不再固定为 A。
- 调焦接近最佳值但多次失败时触发新手引导，说明继续微调的方法和当前差距。

**观测 HUD 与素材接入**

- 正式接入 `C:/Users/tntsg/Downloads/tw/suc` 的深蓝、黄铜、像素拟真观测 UI。
- 原始素材不覆盖，完整复制到 `assets/ui/observation/suc/source/`。
- 运行时素材位于 `assets/ui/observation/suc/processed/`，使用 nearest-neighbor、透明裁切和尺寸上限。
- `asset_manifest.json` 记录源文件名、SHA-256、原始尺寸、透明通道、裁切范围、运行时名称和尺寸。
- 顶部方位角刻度与左侧俯仰角刻度由素材外壳、动态刻度纹理和 Godot 实时数字共同组成。
- 方位角支持 359/0 度连续循环；俯仰角限制在合法范围；指针与 Az/Alt、键盘和鼠标输入同步。
- Eye 使用新绘制的 `eye_precise_reticle.png`，以 `410x410` 一比一显示；外圈半径 `196 px`，中心视觉圈和真实锁定半径统一为 `64 px`。
- 天体提示环、鼠标命中区域与锁定反馈统一使用同一目标派生尺寸，避免提示环与实际检测范围错位。
- Finder 使用 `finder_second_ring.png`，只保留从外向内第二个圆圈，移除中心金色区域、小十字和其他圆圈。
- Scope 使用 `scope_center_tolerance.png`，中央参考框为正圆，不再出现纵向椭圆。
- 详细 Telescope View 移除外部镜筒装饰框、中央十字和中心小圈，保留天体、云层、视宁度、漂移和调焦效果。
- 准直台新增实时“聚焦恒星像”：镜轴偏移时显示方向一致的彗差拖尾，达到阈值后显示对称艾里斑与衍射环。
- 主望远镜成像正式读取准直分数；低分时恒星产生单向彗尾，行星、月球、星云和星系出现偏心重影与细节损失，满分时效果消失。
- 调焦与准直诊断分离：机械焦点正确但存在彗差时，界面明确提示返回准直镜面，不再误导玩家继续调焦。
- 重新接入透明版 azimuth/altitude pointer、Eye icon、tracking knob、target approach ring 和 target lock ring。

**目标反馈最终规则**

- Target approach ring 和 target lock ring 跟随天体实际投影位置，不固定在屏幕中心。
- 两种环使用相同的目标派生尺寸，切换状态时不跳变。
- 环尺寸为 `target diameter + max(12 px, 25%)`。
- Eye、Finder、Scope 的最小直径分别为 40、44、48 px，保证可见但不覆盖主视野。
- 接近状态使用透明中心青色细环和 0.72-0.92 的轻微亮度呼吸。
- 锁定状态使用高对比金色细环；中心始终透明，不遮挡星体。
- Observe 的可用状态、方向提示、目标环位置和真实锁定判定使用同一套目标数据。

**修复与调整**

- 修复 `InteractionFeedback` 未声明导致 `advanced_assembly.gd` 编译失败。
- 修复装配槽位显示错误零件贴图和已安装槽位只显示 OK、不显示零件的问题。
- 修复牛顿式观测选项无法选择、错误要求 Basic Mount 和调焦部件识别不一致的问题。
- 修复 Eye/Finder/Scope 瞄准 UI 在部分关卡消失，以及 Scope 框位于行星下层的问题。
- 修复 Coordinate Navigation 中目标进入视野后没有接近/锁定提示的问题。
- 修复 Telescope View 教学弹窗、识别指南、调焦控件和其他 Modal 互相覆盖的问题。
- 修复英文模式混入中文、乱码双语文本和底部操作提示缺失的问题。
- 修复云层、视宁度、大气扰动、色差、漂移和追踪视觉与关卡数据不同步的问题。
- 修复选择框代码在尺寸辅助函数 `return` 后不可达的回归。
- 保持旧存档结构、核心关卡顺序、剧情条件和真实观测计算不变。

**验证**

- Godot 4.7 headless editor/import：通过，退出码 0。
- Observation UI acceptance：通过。
- L25 reticle regression：通过。
- Newtonian reticle regression：通过。
- Newtonian observation parity：通过。
- Identification quiz and scope layering：通过。
- Telescope modal layer regression：通过。
- Coordinate lock feedback：通过。
- Animation feedback and reduced-motion acceptance：通过。
- Environmental focus effects：通过。
- Focus novice guidance：通过。
- Assembly texture regression：通过。
- Advanced Newtonian、nested tube assembly 和 slot texture checks：通过。
- Story、teaching、core task 和 full flow 回归：通过。
- 1024x768 与 1280x720 截图验收完成；完整报告位于 `artifacts/observation_ui_acceptance/report.md`。

## v2.0 - Web、观测 HUD 与移动输入整合（2026-07-19 至 2026-07-20）

**目标**

将观测界面从静态信息面板提升为具有明确瞄准、锁定、调焦、准直和环境反馈的可操作系统，并提供浏览器与触控设备的运行入口。

**功能与内容**

- 统一 Eye、Finder、Scope 三种视野的目标投影、瞄准环、锁定环和模式切换。
- 加入动态方位/高度刻度、DMS 数值、目标接近提示、目标锁定提示和 Observe 可用状态。
- 加入折射镜色差、牛顿镜准直、调焦、云层、视宁度、地球自转漂移、追踪和暗适应等观测反馈。
- 增加 Web 构建、Cloudflare Worker/R2 资源服务和 `pixelobservatorygame.com` 自定义域名入口。
- 增加移动端虚拟摇杆、互动按钮、拖动转镜头、捏合切换视野、触控调焦和准直方向控制。

**修复与调整**

- 让显示中的目标环与真实判定半径、点击区域和目标投影使用同一组坐标。
- 修复观测 HUD、弹窗、组装槽位和目标标记之间的图层覆盖与错位。
- 修复主线跳关、旧存档迁移和未解锁设备提前出现在装配流程中的一致性问题。
- 明确线上 Web 构建与本地工作区的区别：文档、代码或素材提交后仍需重新导出和部署才能更新网站。

**验证**

- 已有观测 HUD、准直、动画反馈、流程、剧情、教学和移动端专项测试记录在 `tools/` 与 `artifacts/`。
- 2026-07-20 检查 `https://pixelobservatorygame.com` 返回 HTTP 200，页面标题为 `Pixel Observatory`。
- 当前版本仍需在真实手机上验证不同屏幕比例和触控布局，并继续审计扩展关卡的首次引导和文本一致性。

## v0.9.8 - 第 26 关组装修复（2026-10-02，网页版本）

**目标**

修复玩家反馈的牛顿镜筒与入门镜筒同时显示为已装备、组装台却只显示入门镜筒的问题。

**功能与内容**

- 关卡推进和旧存档加载时，为当前关卡选择正确的组装镜型。
- 零件柜按当前镜型显示可装备零件，并保留同关手动选择镜型的能力。

**修复与调整**

- 切换镜型时清理不兼容零件；牛顿镜关卡不再允许装备入门折射镜筒。

**验证**

- Godot 定向回归覆盖第 25 关进入第 26 关、旧存档、组装台、零件柜与后续镜型切换；编辑器项目和发布源码均通过。

## 当前待办

**目标**

继续提高内容完整度、发布稳定性和素材可追溯性。

**功能与内容**

- 为更多天体补齐 clear、blurry、dim 和更精细的专用贴图。
- 继续平衡 L10-L45 的任务难度、设备门槛和教学节奏。
- 完善高级望远镜家族的非占位素材和独立玩法。

**修复与调整**

- 清理旧 shooter / BulletUpHell / Starfall 残留资源和无关插件报错。
- 继续排查中文编码与历史文本质量。
- 优化 Godot 导出配置、最终素材授权和 `CREDITS.md`。

**验证**

- 每次发布前继续执行 headless 编译、核心流程、观测、装配、教学和旧存档回归。

# Pixel Observatory 项目交接（2026-08-05）

## 1. 首要结论

- **当前主开发仓库是 `E:\godot\ai-game-0628`。**
- `E:\godot\pixel-observatory-site-random` 是独立 worktree/实验分支，不是本次应继续修改的目录。
- GitHub：`https://github.com/tntsg1/Pixel-Observatory.git`
- 正式网站：`https://pixelobservatorygame.com/`
- 浏览器游戏：`https://pixelobservatorygame.com/game/`
- GitHub Pages 是部署镜像；玩家访问的正式站由 Cloudflare Worker + Static Assets + R2 提供。

接手后先执行只读检查，禁止立即切分支、重置或批量暂存。共享工作区包含用户和多个 Agent 的未提交成果。

## 2. 当前 Git 状态

交接生成时的真实状态：

- 工作目录：`E:\godot\ai-game-0628`
- 当前分支：`agent/maya-npc-companion`
- 当前 HEAD：`58ea70616ad1a2f432905a45342920a066b17e21`
- `origin/main`：`750d6f62531c8778f88912c6e9bc8499c3e9e5bc`
- 当前分支相对 `origin/main`：有 1 个独立归档提交，同时落后 3 个提交。
- 状态条目约 855 项，其中绝大多数是 `artifacts/`、截图、日志和导入产物；tracked 修改约 22 项。
- 当前没有理由把 `pixel-observatory-site-random` 当作主仓库。

接手检查命令：

```powershell
Set-Location -LiteralPath 'E:\godot\ai-game-0628'
git status --short
git branch -vv
git log --oneline --decorate -12
git log --oneline HEAD..origin/main
git log --oneline origin/main..HEAD
```

### Git 安全规则

1. 不得使用 `git reset --hard`、`git clean`、`git checkout -- .`。
2. 不得使用 `git add .` 或 `git add -A`。只能逐文件选择性暂存。
3. 不得把 `.dev.vars`、cookies、Wrangler 日志、`.wrangler/`、`.godot/`、浏览器配置、临时数据库、PID、npm cache 或大批 `artifacts/` 提交。
4. 当前分支已与 `origin/main` 分叉。在弄清本地未提交改动归属前，不要直接 rebase、merge 或切换分支。
5. 推送或部署前必须得到用户明确指令；“上传 GitHub”和“发布正式网站”是两个不同动作。

旧交接可供历史参考：`E:\godot\ai-game-0628\AGENT_HANDOFF_2026-07-29.md`。其中的分支、HEAD、脏文件数量和部分发布说明已经过期，以本文件及实际配置为准。

## 3. 项目结构

这是 Godot 4.7 项目，入口为：

- `project.godot`
- 主菜单场景：`scenes/main_menu.tscn`
- 游戏数据：`data/`
- 玩法和全局系统：`scripts/systems/`
- UI/场景控制：`scripts/ui/`
- 游戏美术：`assets/`
- 自动测试与截图脚本：`tools/`
- 网站源文件：`web/landing/`
- Cloudflare Worker/API：`cloudflare/worker.mjs`
- D1 数据库迁移：`migrations/`
- GitHub Web 构建工作流：`.github/workflows/deploy-web.yml`
- Cloudflare 配置：`wrangler.jsonc`
- 导出配置：`export_presets.cfg`
- 更新日志：`docs/CHANGELOG.md`、`docs/VERSION_HISTORY.md`

游戏核心包括光学望远镜组装与观测、真实星空位置、空间红外望远镜、FAST 射电观测、任务/教程/学习卡、毕业后自由模式、账号云存档和网站社交功能。

## 4. GitHub 提交流程

GitHub 的正式远端是 `origin`。正常提交必须满足：

1. 先跑与修改范围对应的专项测试。
2. 检查 `git diff -- <file>`，逐文件确认来源。
3. 只暂存本次有意修改的源代码、数据、资源、测试和更新日志。
4. 创建范围清楚的 commit。
5. 在把分支内容安全整合到最新 `main` 后，才推送 `origin/main`。
6. 推送 `main` 会触发 `.github/workflows/deploy-web.yml`，构建 Godot Web 并发布 GitHub Pages 镜像。

工作流会：拉取 Git LFS 美术、安装 Godot 4.7、准备兼容渲染、导出 Web、审计退役版权音频、构建资源包、加入自定义加载壳并上传 Pages artifact。

注意：仅推送 GitHub 并不自动等于更新 `pixelobservatorygame.com` 的 Cloudflare 正式站。

## 5. 正式网站发布链路

### 5.1 网站与游戏壳

- 官网和账号/社区 UI 源码：`web/landing/`
- 根页面由 `web/landing/promo.html` 生成。
- `/game/` 不是 Godot 默认页面；`tools/build_web_shell.mjs` 会把品牌加载动画、游戏框架、账号/好友/反馈侧栏套在 Godot 导出外层。
- 禁止把 Godot 默认 `index.html` 直接覆盖正式 `/game/`，否则会重新出现 Godot Logo、灰屏或丢失网站侧栏。

### 5.2 Cloudflare 组件

- `cloudflare/worker.mjs`：路由、账号、登录、云存档、反馈、私信、好友、社区、排行榜、在线状态、观测分享和管理员 API。
- D1 数据库 `pixel-observatory`：账号、会话、云存档元数据、反馈、社交、时长、观测分享。
- R2 bucket `pixel-observatory-game-assets`：体积较大的 `index.pck`、`index.wasm` 和独立资源包。
- Durable Object `VISITOR_COUNTER`：访客计数。
- Workers AI：反馈感谢信等受控文本生成。
- Turnstile：注册/反自动化验证。密钥只放 Cloudflare secret，绝不写入仓库或交接文档。

当前迁移文件为 `0001` 到 `0010`。只有新增迁移时才执行：

```powershell
npx wrangler d1 migrations apply pixel-observatory --remote
```

不得重复手工修改已经应用的旧迁移，也不得把生产数据库凭据写进 Git。

### 5.3 本地构建与 Cloudflare 发布

以 `.github/workflows/deploy-web.yml` 和以下脚本为事实来源：

- `tools/prepare_web_export.mjs`
- `tools/build_web_resource_packs.mjs`
- `tools/build_web_shell.mjs`
- `tools/verify_web_game_shell.mjs`
- `tools/build_cloudflare_release.mjs`
- `tools/publish_cloudflare_release.mjs`

典型发布顺序是：

1. 使用 Godot 4.7 导入并导出到 `build/web/.godot-export/`。
2. 构建独立资源包。
3. 运行 `build_web_shell.mjs`，生成 `build/web/`。
4. 运行 shell、资源包和缓存 contract tests。
5. 运行 `build_cloudflare_release.mjs`，生成不含大 PCK/WASM 的 `build/cloudflare-public/`。
6. 运行 `publish_cloudflare_release.mjs`：先把不可变版本运行时和资源包上传 R2，再执行 Wrangler deploy。
7. 用无痕/冷缓存分别验收 `/`、`/game/`、登录、云存档、声音、社交侧栏和移动端。

不要凭记忆手写发布命令；先读脚本和当前配置。不要发布陈旧的 `build/`。每次必须由同一源码 HEAD 重新导出、生成壳、上传 R2 和 Worker 静态资源。

## 6. 测试方式

本机 Godot 4.7 控制台常用路径：

```powershell
& 'E:\godot\godot47\Godot_v4.7-stable_win64_console.exe' `
  --headless --path 'E:\godot\ai-game-0628' `
  --script 'res://tools/<test>.gd'
```

测试必须串行。不得关闭用户正在使用的 Godot 编辑器。只有确认某个明确的无头测试长期无输出且已卡死时，才可终止该测试进程。

完成标准不是“代码可编译”，而是：专项测试通过、完整流程可达、截图/录屏能证明 UI 状态、Web 冷缓存可运行、控制台没有新错误。

## 7. 当前本地未提交工作

### 7.1 玛雅大厅 NPC

当前玛雅 NPC 工作仍在本地，主要文件未提交：

- `assets/characters/maya/hall_npc/`
- `data/maya_hall_npc_dialogue.json`
- `scripts/ui/maya_hall_npc.gd`
- `tools/build_maya_hall_atlas.py`
- `tools/maya_hall_npc_test.gd`
- `tools/capture_maya_hall_npc*.gd`
- `tools/capture_maya_postgraduate_work.gd`

最近已做的本地修正：

- 自由活动目的地不再每帧重抽，解决左右疯狂转向、卡顿和随机事件连发。
- 活动点改为非重复轮换：组装台、中央望远镜、电脑、日志桌、零件柜。
- 到站后按工作台方向稳定站立，不持续追着玩家翻面。
- 日常气泡与行走路线解耦并降低频率；气泡只提供简短情绪价值。
- 添加组装台俯身工作的动作 `assembly_work`，并生成验收 GIF：
  `E:\godot\ai-game-0628\artifacts\maya_postgraduate_work\maya_assembly_work.gif`

专项测试 `tools/maya_hall_npc_test.gd` 和一次无头导入/编译此前通过，但接手 Agent 必须在继续修改前重新运行，不得只引用口头结果。

### 7.2 其他混合来源的 tracked 修改

当前 tracked 修改包括但不限于：

- `data/advanced_levels.json`
- `data/assembly_dependencies.json`
- `docs/CHANGELOG.md`
- `scripts/systems/game_manager.gd`
- `scripts/systems/observation_system.gd`
- `scripts/systems/radio_signal_model.gd`
- `scripts/ui/advanced_assembly.gd`
- `scripts/ui/developer_console.gd`
- `scripts/ui/observatory_room.gd`
- `scripts/ui/parts_cabinet.gd`
- `scripts/ui/radio_observation.gd`
- `scripts/ui/telescope_view.gd`
- 一批对应 `tools/` 测试

这些改动涉及 FAST 78 关以后流程、FAST 装配蓝图和零件、射电折叠阶段、最终报告选项、光学显示、开发者控制台等。来源混合，必须逐文件审计，不能把它们和玛雅 NPC 一起盲目提交。

## 8. 当前重点验收清单

接手后优先确认：

1. 第 78 关 FAST 折叠/捕获完成三次后，能可靠进入第 5 阶段。
2. FAST 最终报告至少有一个与证据一致、可归档的正确结论。
3. FAST 装配任务会明确要求安装，左侧零件、中央蓝图贴图、槽位和状态一致。
4. 玛雅第一关头像/头部不缺失，像素角色高度约比主角高一个头。
5. 玛雅与玩家不互相阻挡，不在工作台边闪烁，不毕业后原地左右旋转，不高频触发随机气泡。
6. 玛雅只在大厅可见；进入组装台、观测界面等子场景后不可见也不单独发言。
7. 游戏内语言选择、声音、Web 加载壳、云存档、排行榜时长、好友/反馈侧栏不得被回归破坏。

## 9. 接手后的第一条回复

请先只读检查并回复：

1. 你确认的真实仓库路径、当前分支、HEAD、`origin/main`。
2. 当前分支相对 `origin/main` 的 ahead/behind 情况。
3. 你识别出的未提交生产文件、测试文件和纯 artifacts。
4. 你准备先验收哪一个问题，以及对应测试命令。

在完成这四点前不要改代码、不要切分支、不要提交、不要推送、不要部署。

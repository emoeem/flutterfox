# phase-1-mobile 截图目录内容说明（勘误）

本目录沿袭 Phase 1 计划的目录名 `phase-1-mobile`，但**内容全部是 Linux 桌面
（Xvfb 受控显示器 :3 / :5，无 WM，UI 视口 1440x900）的实机运行证据**，不是手机
形态证据。Android 真机/模拟器在本环境不可用（无 JDK、SDK 无 emulator/system-images，
用户已明确搁置 Android 验证），§10.1/§12.4 的手机/平板矩阵零运行时覆盖，
`AndroidInsets`/`MobileShell` 仅有 widget 契约测试层覆盖。

- 命名仍按指南 §12.5：`<platform>-<page>-<viewport>-<state>.png`，
  platform=linux，viewport=1440x900（`VOICEFOX_START_SIZE=1440x900` 请求即所得，
  与 phase-0 基线同口径；Xvfb 无 WM 下 GTK 窗口自居中到 (-132,-132)、尺寸 1704x1164，
  但 GL/UI 内容锚定 (0,0)-(1440,900)，截图按实际 UI 视口命名）。
- 全部为 release bundle 真实运行画面 + 真实数据（真实音源搜索/播放、真实本地导入、
  离线 netns 实例的真实网络失败），无 mock/摆拍。
- `*-error-retry.png` 系列采自 root `unshare -n`（仅回环）网络命名空间实例：
  搜索/歌单请求真实失败，页面级「重试」按钮可见；同 HOME 重启为在线实例后
  同一查询 259 结果恢复（recovered 系列佐证）。
- 发现页/歌单页错误框中直出的原始 URL 缺口（BrowseResult.error，`_applyBrowseEvent`
  page=0 分支未经净化）已于 2026-11-11 QA 第 2 轮修复：错误与 notice 在
  `_applyBrowseEvent` 源头净化（app_model.dart，单点收口全部浏览消费面）；
  `linux-discover-1440x900-error-retry.png` 已用离线 netns 实例复拍为净化后
  状态（错误框显示 `([URL]`，原始 URL 仅在 stderr 日志）。搜索页同类缺口于
  QA 第 1 轮修复（`search_page.dart` 渲染前净化，回归见 `search_page_test.dart`）。

## 2026-11-11 QA 复拍勘误（repeat 模式证据）

- **旧 `linux-search-1440x900-repeat-mode-1/2.png`（QA 04:32/04:34 采集）已作废**：
  当时两档循环共用 `Icons.repeat` 且同为 primary 色，蓝/蓝/灰时间线无法证明
  任何一档归属；且采集点击使用硬编码坐标，实测 PlayerBar 控制列随歌名宽度
  位移（±45px），点击可能落在旧位置。旧文件已被复拍覆盖/勘误，不复为证。
- **`linux-search-1440x900-repeat-mode-1.png`（复拍 2026-11-11 03:17）**：
  真实播放中（L-O-V-E/汽水走带）、`config.toml` 地面真值 `play_mode="list-loop"`、
  repeat 图标 primary 蓝（#9AB7EA 采样）、hover tooltip「列表循环」确认。
- **`linux-search-1440x900-repeat-mode-2.png` + `-glyph.png`（复拍 03:36）**：
  `config.toml` 地面真值 `play_mode="single-loop"`（经应用真实持久层设定后重启
  读取），repeat 槽位渲染 `Icons.repeat_one` 字形（disabled 态、灰色）；tooltip
  「单曲循环」已在同 boot hover 确认。**激活态（primary 蓝色）实机截图未取得**：
  本会话播放启动点击在多轮 boot 间歇性失效（hover 正常、渲染走带、事件流正常，
  但 ButtonPress 无效，属 P0-01 同域输入不稳定，已登记矩阵）；激活态颜色逻辑由
  `repeat_mode_test.dart` 4 项（经真实 PlayerBar/VxPlayerControls 代码）锁定，
  真机激活态截图待 P0-01 定位后补拍。
- 环境勘误：增量 release 构建的 MaterialIcons 字体子集可能陈旧（复拍中发现
  `Icons.repeat_one` 字形缺失，otf 时间戳早于代码改动）；`flutter clean` 后
  重建恢复。涉及图标字形改动的构建需 clean 或验证字体子集时间戳。

## 2026-11-11 修复后复验轮（运行验证员·Phase1，flutter clean 全量重建）

缺陷修复（P1-10/P1-11）并入后，按同一矩阵对**受影响视口**在
`flutter clean` + 全量 release 重建的 bundle 上重截（全部 XTEST 实机交互 +
真实数据，非摆拍）：

- **`linux-search-1440x900-repeat-singleloop-active.png`（新增）**：P1-10
  修复会话未能取得的**单曲循环激活态**实机截图已补齐。真实播放中双击搜索
  行起播，repeat 点击一档（list-loop→single-loop），`repeat_one` 字形
  primary 蓝激活态；`config.toml` 地面真值 `play_mode="single-loop"` 同时
  落盘核对。激活态不再仅由测试锁定。
- **`linux-search-1440x900-error-retry.png`（覆盖）**：P1-11 修复后重截：
  离线 netns 实例搜索失败，错误框 detail 已全部为 `[URL]` 占位（原 migu
  URL 不再直出），截断 140 以 `…` 收尾；重试按钮在位。
- **`linux-discover-1440x900-error-retry.png`（重截，QA 第 2 轮修复后）**：
  发现页 `BrowseResult.error` 直出原始 URL 的残余已在源头修复
  （`_applyBrowseEvent` 对错误走 `_logAndSanitize`、notice 过
  `sanitizeUserFacingMessage`，单点收口覆盖 discover/playlist/leaderboard/
  library 全部消费面；04 矩阵 P1-11「同类残余」已改判已修复）：离线 netns
  实例错误框现显示 `([URL]` 占位，原始 URL 仅存在于 stderr 日志
  （`voicefox error(raw): … qukudata.kuwo.cn …` 实测在位）。
- **`linux-playlist-1440x900-detail-a-gufeng.png` / `-detail-b-jingdian.png`
  / `-reenter-a-isolated.png`（覆盖）**：歌单隔离对照三连在重建 bundle 上
  重截：A（古风戏腔 104 首）、B（经典老歌 183 首）曲目零交叉，重进 A 内容
  与首进一致（无 B 残留）。
- **`linux-search-1440x900-recovered-results.png`（覆盖）**：同 HOME 离线
  失败 → 在线重启 → 同查询 259 结果恢复，重试闭环证据保持成立。
- 复验轮门禁：`flutter analyze --no-pub --fatal-infos` 0 issue；
  `flutter test` 全套 **246 passed / 0 failed**（QA 第 2 轮修复后含
  repeat_mode_test 4 项、search_page_test「P1-07 同类缺口回归」、
  playlist_detail_isolation 9 项（新增 §8.1 序列 7：A 触底分页在途切 B，
  迟到页 2 只落 A 槽 + P1-11 回归）、search_pagination 4 项）；
  `cargo test -p voicefox-runtime -p voicefox-application` 72+40 passed
  （Rust 零改动）；`flutter clean` + `flutter build linux --release`
  exit 0（cargo 需在 PATH：CMake 钩子 `find_program(cargo)` 依赖 PATH，
  缺失时 bundle 静默缺 libvoicefox_ffi.so）。

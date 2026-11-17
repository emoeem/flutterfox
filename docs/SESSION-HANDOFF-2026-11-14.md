# 会话交接：第三轮工程演进（Batch A/B 已收口，Batch C 进行至 4/8）

> 状态：生效中 · 交接日期：2026-11-14 · 交接 HEAD：`a2b377f`（feat/ui-redesign，已推送 GitHub，与本地完全同步） · 接收方：Windows 端执行 AI · 上游计划书：`docs/redesign/second-round/PLAN-rust-ffi-and-ui-evolution.md`（本仓内副本，原文件在原执行机 /home/emo/Downloads/）

## 一、给 Windows AI 的开工指令（直接复制执行）

```
继续执行《Flutterfox 跨平台工程演进计划书》（docs/redesign/second-round/PLAN-rust-ffi-and-ui-evolution.md）。
先按顺序阅读：1) docs/SESSION-HANDOFF-2026-11-14.md（本交接，当前状态与红线）；
2) 计划书全文（Phase 0/Batch A/B 已完成，不要重做）；3) docs/redesign/04-defect-matrix.md（FFI-R 登记）；
4) docs/redesign/second-round/01-implementation-audit.md；5) docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md（UI 唯一规格）。
然后从 Batch C-C 开始：C-04 歌单详情手机页 + C-08 曲库核验收口 + C-07 帮助页手机形态（上一批 C-A/C-B 已完成发现/搜索/下载/本地音乐 4 页，
实施模式照抄 pages/mobile_search_page.dart 与 mobile_local_music_page.dart；shared 控制器提炼模式照抄 discover_shared.dart）。
C-C 后接 C-D（Settings 手机分组 + 滚动底部 padding 统一 + 360/390/430 视口矩阵验收），随后 Batch D→E→F→G→H→I 按计划书顺序逐批。
纪律：每批先审计后修改；门禁全绿才提交；逐批单独 commit（消息沿用仓库现有风格）；推送走 HTTPS；Android 无用户明确授权不构建 APK/Gradle/AVD；
Linux 专属验证项（桌面 bundle 实跑/Xvfb 截图/niri P2-04）在 Windows 上不可执行，一律如实标注「未验证」；
不得删除或削弱既有测试断言；计划书 §13 固定流程与附录 B 禁止捷径全程有效。
```

## 二、当前状态（实测）

| 项 | 值 |
| --- | --- |
| 分支/HEAD | feat/ui-redesign @ `a2b377f`，工作区干净，已推 GitHub（draft PR #12 持续承载 CI） |
| 测试基线 | flutter test 全量 **466 passed / 0 failed**（C-B 后）；cargo test --workspace **838 passed / 0 failed**；analyze --fatal-infos 零问题 |
| 工具链 | Flutter 3.47.9 stable（必须，CI 与本地一致）· Dart 3.13.7 · rustc 1.99.0 · flutter_rust_bridge 2.13.0（pubspec 与 Cargo 均**精确锁**，勿升级） |
| 远端 | https://github.com/emoeem/flutterfox.git（HTTPS 推送；偶发 TLS 抖动重试即过） |

## 三、已完成内容（勿重做）

| 批次 | commit | 内容 |
| --- | --- | --- |
| 第二轮收口 | 911826c 之前的历史 | 第一轮 UI 重构 Phase 0-7 + 清尾 L1/L2 + 门禁恢复批次（CI SDK 固定 3.47.9、analyze/test 拆独立 job、P2-17×P2-18 交叉修复），详见 04 缺陷矩阵更新行 |
| 第三轮 Phase 0 | f56e08b | 基线复核 + Batch A FFI 审计（R01-R12 判定）+ SR-11 右键菜单口径修正 |
| Batch A-1 | f56e08b | 移动播放命令链五项修复（R01 订阅前 Play 补投/R07 看门狗/R03 重同步/R06 两项） |
| Batch A-1b | 5e6f066 | 命令契约升级：8 变体 command_id + 歌曲域 generation + hostPlayerAck + pending 表（FRB 再生成） |
| Batch A-2 | 9304b86 | 事件与快照：尾随 StateChanged 移除、_refreshState 单飞+追尾、attach 先订阅、streamDead/restartEventLoop、local_songs 拆出 state()（新 FFI localSongs）、downloads 1s 节流 |
| Batch A-3 | 092fd92 | PlayerState::as_protocol_str 单源、pubspec 精确锁、ci.yml codegen-check job、gate 脚本 clippy 对齐 |
| Batch B1 | d2822f4 | buildAppTheme 统一主题构建器（显式 ColorScheme + VxPalette 扩展 + VxTypography textTheme + fallback）+ ThemeProvider 委托 + 44 预设投影修复（28 套失效修复 + flex 亮度 bug） |
| Batch B2 | 871513a | main.dart 内联 fromSeed 移除 + guard 字面量禁令 |
| Batch B4 | a718a44 | dynamicColor 单源（useCoverDynamicColor 改名迁移 + 默认对齐 Rust false + 死壳 tile 退役） |
| Batch B3+B5 | c5ae5d5 | 壳层/播放器/组件 14 处颜色消费切 scheme/VxPalette + VxChrome 删除 + misansTextTheme 退役 |
| Batch C-A | 911826c | 发现页/搜索页手机独立页面（mobile_discover_page + mobile_search_page + discover_shared/search_shared 控制器提炼 + form 分叉接线） |
| Batch C-B | a2b377f | 下载页/本地音乐页手机独立页面（mobile_downloads_page + mobile_local_music_page + 接线） |

## 四、下一步任务队列（按序）

1. **Batch C-C**（未开始）：C-04 歌单详情手机页（沉浸 Hero+移动行+PlaylistKey 隔离保持，手机端歌单详情 push 入口全部改推手机版）+ C-08 曲库核验收口（<512 补丁 360/390/430 完整性核验，增补 mobile_library_page_test 用例，不强建第二页面）+ C-07 帮助页手机形态（过滤桌面快捷键段，app_shell help 槽 form 分叉）。
2. **Batch C-D**：Settings 手机分组列表（桌面 208 双栏不照搬）+ 全部手机页滚动底部 padding 统一（现状固定 24dp，应联动 MiniPlayer+NavigationBar+bottom inset，参照 shell/android_insets.dart 契约）+ 360/390/430 三视口矩阵验收（viewport_matrix_test 扩充）。
3. **Batch D**：桌面体验完善（§7：DesktopContentConstraint 限宽、右键菜单缺口精查（SR-11 残余=网格卡面，勿重复实现已有 showSongMenu）、键盘焦点 FocusTraversalGroup、Header 搜索双向同步、首页歌单入口进详情）。
4. **Batch E**：下载可靠性（§8：Rust 状态机审计、字节口径、P3-09 桌面侧收口）。
5. **Batch F**：队列排序协议（QueueMove 等业务命令先行）+ Linux MPRIS（复用 TUI 既有 D-Bus 逻辑，Windows 上只能实现与单测，运行时验证留 Linux）。
6. **Batch G/H**：既有缺陷运行时闭环（P1-20/P2-16/P2-17/P2-18 真机证据）+ 稳定性诊断（P0-01/P1-05 需 Linux 长会话，Windows 不可做）。
7. **Batch I**：Golden 基线、无障碍、性能基准、观测性。

## 五、环境与命令（Windows 适配注意）

| 命令 | 说明 |
| --- | --- |
| `cd flutter && flutter pub get` | 先跑；pubspec.lock 已提交，FRB 2.13.0 精确锁勿动 |
| `dart format --output=none --set-exit-if-changed lib test`（flutter/ 下） | 格式门禁 |
| `flutter analyze --fatal-infos`（flutter/ 下） | analyze 门禁 |
| `flutter test`（flutter/ 下） | 全量 466 基线，任何回退都要查 |
| `cargo fmt --all -- --check` / `cargo clippy --workspace --all-targets -- -D warnings -A clippy::double_must_use` | Rust 门禁；**必须用 CI 同款 clippy 命令**（30 条 double_must_use 基线为 async_trait 宏展开固有豁免；带 --all-features 或缺豁免的旧口径会误报） |
| `cargo test --workspace` | Rust 838 基线 |
| `flutter_rust_bridge_codegen generate` | 改 FFI API 后必须跑；版本必须 2.13.0；**生成后先 `cargo fmt --all` 再提交**（use 导入会被 fmt 重排，CI codegen-check 按已 fmt 版本比对） |
| `git push https://github.com/emoeem/flutterfox.git feat/ui-redesign` | 推送（TLS 抖动重试即可）；不 push main、不 force、不打 tag |
| `bash scripts/redesign-gate.sh all` | 聚合门禁（Linux/bash；Windows 可在 Git Bash/WSL 里跑，或逐条手跑上表命令） |

Windows 差异提示：Linux 构建与 bundle 实跑（build-linux job、桌面实机验证、Xvfb 截图、niri P2-04、MPRIS 运行时验证）在 Windows 不可执行，相关验收项如实标「未验证」并留给 Linux 会话；Windows 本机可跑 flutter test/analyze、cargo 全套、Android 相关仍受计划书 §0.4.10 约束（无用户授权不构建）。

## 六、开放项与已知陷阱（坏消息单列）

1. **CI codegen-check job**：092fd92 至 a718a44 的 run 因「本地提交版经 cargo fmt 重排 use 导入、CI 原始 codegen 输出未 fmt」误报不同步；**修复已随 911826c 落地**（job 内 generate 后先 cargo fmt 再比对）。接收方应核验 911826c 之后的最新 CI run 是否 9/9 全绿；若仍红，按 job 日志里的 git diff 输出对账。
2. f9b2ac8 是一个仅含 codegen-check 调试输出增强的 ci 提交（保留，日志可观测性有价值）。
3. 旧 prefs key `useDynamicColor` 是死键（B4 迁移保留可逆）；封面取色开关（useCoverDynamicColor）当前无 UI 入口、默认 false，功能代码保留。
4. 手机搜索行单击即播整列、chips 横滚末位折叠线外为已登记的设计取舍；本地音乐手机页复制了桌面页约 12 行补扫描/差分算法（有交叉注释）。
5. R02 慢 Play 分流、per-command ack 的业务消费、sync cancelled 字段化、结构化 FfiError 均为已登记的后续批（见 ffi-reliability-design.md）。
6. 运行时/真机证据（P2-16/17/18/P1-20、断连看门狗、大曲库卡顿）全部维持「需设备验证」，Windows 会话同样不构成该证据。
7. 第二轮执行计划书原文在原执行机 Downloads（未入库），但其内容已被 01-implementation-audit.md 与本交接覆盖；第三轮计划书副本已入库（见头部）。

## 七、Git 纪律（全程有效）

只动 feat/* 分支；不 push main、不 force、不打 tag、不 merge、不发 release；提交逐批（沿用仓库长消息风格：类型(范围): 摘要 + 实测门禁数据 + 如实登记未做项）；push 走 HTTPS 并容忍 TLS 抖动重试；计划书 §0.4.9：提交/推送需用户当前授权（本交接会话中用户已授权「完成后续全部内容」，接收方开工前仍应与用户确认授权口径）。

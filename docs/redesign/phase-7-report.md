# Phase 7 Report（全平台质量收敛与最终报告）

- 日期：2026-11-13（报告员独立复跑轮）
- 分支：`feat/ui-redesign`；本轮工作区改动：`flutter/lib/main.dart`（Phase 7 执行批次 uiOnly 起始参数 + 报告员 dart format 规范化）+ `docs/redesign/screenshots/final/` 13 张最终截图（执行批次 6 张 + 报告员本轮替换 7 张，详见「视觉 QA 结果」）
- 依据：`docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` §14 模板 + §16 最终总结 + §13 Phase 7 退出条件（:1186-1197）；缺陷状态以 `docs/redesign/04-defect-matrix.md` 为准

## 范围

Phase 7（全平台质量收敛）：全部测试与截图回归、最终质量报告、§17 追踪表收尾。工作清单中的性能 profiling 与无障碍专项检查本轮**未执行**（无 profiling 工具会话、无无障碍审计会话，如实登记于「未解决问题」）；浅色/深色主题维持 widget 层证据（chrome_theme_test 5 项 + 设计 token 双源），运行时整页浅色走查仍未做（P1-09 收口口径自 Phase 1 维持）。

本报告同时按 §16 最终总结要求给出：完成项 / 真机验证项 / 仅自动化项 / 未验证项 / P0-P3 计数 / 测试命令与退出码 / 各平台构建状态 / 许可证合规结论。

## 修改文件

| 文件 | 改动 | 执行者 |
|---|---|---|
| `flutter/lib/main.dart` | +9/-1：kUiOnly 分支 `runApp` 补传 `initialDestination/searchSeed/libraryTab/settingsSection`（`_startDestinationFromEnv` 等 4 个既有 env helper，main.dart:58-98），使 uiOnly 验收截图可指定起始页/曲库档/设置分组；报告员补 dart format（调用处换行规范化，语义零变化） | Phase 7 执行批次 + 报告员 format |
| `docs/redesign/screenshots/final/*-uionly.png`（13 张） | 执行批次产出 13 张；报告员逐张目检后**替换 7 张**（1 张视口标注失实 + 6 张 phone 实为 560 宽），以真实视口重截件替换，逐张见「视觉 QA 结果」 | Phase 7 执行批次 + 报告员重截 |
| `docs/redesign/phase-7-report.md` | 新建（本报告） | 报告员 |
| `docs/redesign/04-defect-matrix.md` | Phase 7 收口轮条目 + P1-19/P2-15/P3-10 登记 | 报告员 |
| `docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` §17 | Phase 7 行收尾 + 执行状态段更新 | 报告员 |

Rust 侧零改动（`git diff HEAD --stat -- runtime/ application/ ffi/ source/ core/ app/` 输出为空，报告员实测）。

## 关键设计决策

1. **uiOnly 截图管线（无 Rust 后端的壳层渲染模式）**：`kUiOnly = bool.fromEnvironment('VOICEFOX_UI_ONLY') && kDebugMode`（main.dart:53），本轮起支持 `VOICEFOX_START_PAGE/SEARCH/TAB/SECTION` 指定起始目的地，页面呈现真实空/错误态（发现页「没有可用的音源」、曲库「还没有收藏」），不伪造数据（§15「禁止硬编码假数据」合规）。
2. **报告员证据修正而非带病收口**：目检发现 7 张最终截图视口标注与实际渲染不符（§12.4 视口矩阵的交付物质量缺陷）。按 04 矩阵先例（Phase 3 证据重截未登记判 P1 登记即关闭）登记 **P1-19 并以真实视口重截件替换**，根因定位到 uiOnly 分支不应用 `VOICEFOX_START_SIZE`（见 P3-10），未改生产代码（真实分支的 WindowOptions/minimumSize 链路不受影响）。
3. **诚实收口口径**：§13 Phase 7 退出条件「P0/P1 为 0」**字面未满足**（P0-01 未复现未定位开放；P1-05/16/17 真实开放；P1-06 环境阻断），本报告如实判定「Linux 桌面目标可收口、Android 目标与 P0/P1 清零在当前环境与遗留缺陷下不成立」，不降低评级口径（§12.7）。

## 数据流/交互变化

- 仅 uiOnly 验收管线新增 env → 起始目的地透传（`VoicefoxApp.initialDestination/searchSeed/libraryTab/settingsSection`，main.dart:336-341 与 396-405 两条壳构造路径共用）；真实引导分支（main.dart:127-130）此前已传同参，运行时行为零变化。
- 生产（非 uiOnly）代码路径零改动；Rust 零改动；无新增/删除 FfiCommand。

## 执行命令与退出码

以下全部为报告员本轮（2026-11-13）在 `/home/emo/code/voicefox-gui` 实跑，逐条记录：

| # | 命令 | 退出码 | 结果 |
|---|---|---|---|
| 1 | `dart format --output=none --set-exit-if-changed lib test`（flutter/ 下，`/home/emo/flutter/bin/dart`） | **1 → 0** | 首跑 exit 1：`Changed lib/main.dart`（Phase 7 执行批次改动未格式化，251 files 1 changed）；对 main.dart 执行机械化 format（语义零变化，`git diff` 逐行核对仅调用处换行）后复跑 **exit 0**（`Formatted 251 files (0 changed)`） |
| 2 | `flutter analyze --fatal-infos` | **0** | `No issues found! (ran in 4.0s)` |
| 3 | `flutter test`（全量） | **0** | `00:25 +375: All tests passed!` |
| 4 | `cargo fmt --all -- --check` | **0** | 无输出（零格式偏差） |
| 5 | `cargo test --workspace` | **0** | 826 passed / 0 failed（10 个单测二进制 + 各 crate doc-tests 0 项；全量日志 `/tmp/p7_reporter_cargo_test_full.log`） |
| 6 | `cargo clippy --workspace --all-targets --all-features -- -D warnings`（§12.1 门禁原样） | **101** | `error: failed to run custom build command for libmpv2 v6.0.0` → `thread 'main' panicked at libmpv2-6.0.0/build.rs:23:41: env var MPV_SOURCE not set: NotPresent`，与 Phase 0 基线登记一致（基线问题，非本轮回归；报告员本轮实测复现） |
| 7 | `cargo clippy --workspace --all-targets --all-features`（降级、无 `-D warnings`） | **101** | 同一 libmpv2 构建失败；失败前采集 lint：**lx-core 28 条**（`#[must_use]` attribute with no message，28 unique）+ crate 汇总 1 条，与基线「lx-core 28」吻合 |
| 8 | `RUSTUP_TOOLCHAIN=1.99.0 flutter build linux --release` | **0** | `✓ Built build/linux/x64/release/bundle/voicefox_flutter`（07:33:34；`lib/libvoicefox_ffi.so` 24475344B 07:33:16 在位） |

执行批次的命令（报告员未复跑、以产物佐证）：5 次 `flutter build linux --debug`（/tmp/p7_build{,.2,.3,.4,.5}.log 均 `✓ Built …/debug/bundle/voicefox_flutter`，05:41-06:33）；debug bundle 在位（`voicefox_flutter` 06:26:31、`kernel_blob.bin` 06:33:23、`libvoicefox_ffi.so` 05:06:53，报告员 stat 佐证），本轮 uiOnly 重截即运行该 bundle（格式化改动语义零变化，bundle 结论不失效）。

## 测试结果（通过/失败/跳过）

- **Flutter 全量**：375 通过 / 0 失败 / 0 跳过（`flutter test` exit 0）。含 §12.3 全部 12 个必须 widget 测试族（mobile_shell/mobile_home/mobile_library/playlist_detail_isolation/artwork/mobile_now_playing_layout/android_insets/local_music_import/mini_player/desktop_three_column/queue_interaction/search_pagination）与 Phase 1-6 全部回归组（推入式详情页内嵌 Navigator、chrome_theme、repeat_mode、error_toast、search 防抖紧界、四态断言等）。
- **Rust 全量**：826 通过 / 0 失败 / 0 跳过（`cargo test --workspace` exit 0）。
- **静态**：dart format 251 files 0 changed（exit 0）、flutter analyze 0（exit 0）、cargo fmt 0（exit 0）；clippy 门禁命令 exit 101（libmpv2 MPV_SOURCE 环境缺失，基线在案），降级采集 lx-core 28 条既有告警。
- **无跳过项**；无因失败而删除的测试（§15 红线合规）。

## 构建结果（各平台构建状态）

| 平台 | 状态 | 证据 |
|---|---|---|
| **Linux 桌面（x64 release）** | ✅ 构建成功 | `flutter build linux --release` exit 0（本轮报告员实跑，bundle 07:33:34，FFI so 24.4MB 在位） |
| **Linux 桌面（x64 debug）** | ✅ 构建成功 | Phase 7 执行批次 5 次构建 exit 0（/tmp/p7_build*.log）；bundle 06:33 kernel_blob 为本轮 uiOnly 运行/重截载体 |
| **Android（APK）** | ❌ **未构建（全程未构建）** | 环境实测（报告员本轮）：`ANDROID_HOME=/opt/android-sdk` 但**该目录不存在**、`adb` 不存在、无 `~/Android`、无设备/模拟器；JDK 21 在位（OpenJDK 21.0.13）。叠加用户明确搁置指令（**禁止 APK/Gradle 构建与 AVD 创建**，Phase 0 起维持）。`flutter/android` 源码树（AndroidManifest.xml/java/kotlin/res/jniLibs）在位但从未产出 APK |
| Windows / macOS / iOS | 未适用 | 本环境无目标工具链，全程未尝试 |

## 设备和视口

- **真实设备（Android/iOS）**：**零**。无真机、无模拟器、无 AVD，§12.6 真机 13 项（首次启动/导入授权/扫描进度/在线播放/锁屏通知/后台 10 分钟/耳机蓝牙/系统返回/进程回收恢复等）**全程未验证**（P1-06 维持，环境阻断 + 用户搁置）。
- **桌面运行时**：Xvfb 无头环境（本轮报告员 :77；执行批次 :221-:232），debug bundle + `LIBGL_ALWAYS_SOFTWARE=1` + GDK_BACKEND=x11；音频真实输出不可验证（无头 pipewire 限制，Phase 6 口径维持）。非物理真机，如实标注。
- **视口矩阵（§12.4）**：本轮 final/ 交付 13 张 uiOnly 截图 = 桌面 5 档（1024/1280/1440/1920 + 1024 重截）覆盖 home/discover/library/settings；手机 6 张（360×800/390×844×2/430×932×2/360×800 library）；平板 3 张（600×900/840×900/1199×900）。**运行时窗口为 Linux 桌面窗口（isTouchPlatform=false），"phone/tablet" 捕获实为桌面壳 <960 降级布局渲染移动/平板形态页面内容，非 MobileShell/TabletShell 运行时**（MobileShell 平台隔离 mobile_shell.dart:107-119、平板壳运行时不可达 G6 维持；两壳的运行时证据仍只有 widget 层）。
- Search/Playlist Detail/Local Music/Downloads/Now Playing/Queue 六页的最终态截图沿用各阶段真实后端存档（baseline/phase-3/phase-4/phase-5/final 目录），uiOnly 模式下这些页面呈空/错误态，未重复采集。

## 截图路径

`docs/redesign/screenshots/final/`（本轮交付，逐张 `magick identify` 尺寸核验 + Read 目检）：

| 文件 | 实际尺寸 | 状态 |
|---|---|---|
| desktop-home-1024x640-uionly.png | 1024×640 | **报告员本轮替换**：原件为 1280×720 默认窗在 1024×640 屏上的左上裁切（展开侧栏/无 PlayerBar/无 DEBUG 横幅三重矛盾）；真 1024×640 重截 = 折叠 72 rail + PlayerBar 空态 + DEBUG 横幅，与 resolveShellMetrics（responsive_shell.dart:155-172，1024→collapsed）及 Phase 6 QA 实拍一致 |
| desktop-discover-1280x800-uionly.png | 1280×800 | 执行批次原件，目检通过（展开侧栏 + 没有可用的音源 + PlayerBar + DEBUG） |
| desktop-library-1440x900-uionly.png | 1440×900 | 执行批次原件，目检通过（≥1440 三栏档、compact header 断点、空态四态、PlayerBar） |
| desktop-settings-1920x1080-uionly.png | 1920×1080 | 执行批次原件；内容区为「配置加载中…」永久加载态（uiOnly 无后端 config 快照，设置项不可达，如实登记，截图证据价值限于壳层布局） |
| phone-home-360x800-uionly.png | 360×800 | **替换**（原件 560×800）：真 360 重截，Hero CTA Wrap 纵排（vx_hero.dart:127-158 <320 分支），无溢出 |
| phone-home-390x844-uionly.png | 390×844 | **替换**（原件 560×844）：真 390 重截，CTA 横排（≥320 一行容纳），无溢出 |
| phone-home-430x932-uionly.png | 430×932 | **替换**（原件 560×932）：真 430 重截，热门榜单区块开始呈现 |
| phone-discover-390x844-uionly.png | 390×844 | **替换**（原件 560×844）：真 390 重截，没有可用的音源错误态 |
| phone-library-360x800-uionly.png | 360×800 | **替换**（原件 560×800）：真 360 重截；目检发现新缺陷 **P2-15**（「喜欢的歌曲」入口卡标签省略号截断，见缺陷节） |
| phone-settings-430x932-uionly.png | 430×932 | **替换**（原件 560×932）：真 430 重截；同为「配置加载中…」加载态 |
| tablet-discover-840x900-uionly.png | 840×900 | 执行批次原件，目检通过 |
| tablet-home-1199x900-uionly.png | 1199×900 | 执行批次原件，目检通过（960-1199 硬带折叠 72 rail + PlayerBar，G1 口径） |
| tablet-library-600x900-uionly.png | 600×900 | 执行批次原件，目检通过 |

重截方法（报告员实跑）：Xvfb :77（900×1600×24）+ debug bundle + `VOICEFOX_UI_ONLY=1 VOICEFOX_START_PAGE=…` 启动 → `xdotool windowsize` 精确到标注视口 → `xdotool getwindowgeometry` 核实（360×800 等在 uiOnly 下可达，无 560 钳制）→ `import -window <winid>` 逐张捕获 → `magick identify` 尺寸核验 → 逐张 Read 目检。进程清理复核：报告员实例（Xvfb :77 + app）已全部退出（pgrep 实测 0），执行批次遗留的 :105/:141024/:221-:232 Xvfb 实例非本轮产物未触碰。

## 视觉 QA 结果

按 §12.5 清单逐张检查 13 张 final 截图（报告员本轮实看）：

- ✅ 无白屏/黑屏；无 RenderFlex overflow 条纹；无 tofu/字体方框；标题无竖排/异常折行；卡片无边界裁切；深色对比度可读；PlayerBar 空态（未在播放/选择一首歌曲开始播放）在桌面各档常驻（P2-11 口径）；1024 折叠 rail/1199 折叠/1280-1920 展开断点状态全部与 `resolveShellMetrics` 一致。
- ✅ 空态/错误态文案与代码逐字一致：发现页「没有可用的音源/请先在设置中启用至少一个在线音源，再回到发现页。」（discover_page.dart:247）、曲库「还没有收藏/在搜索页点击心形把歌曲收进来」、首页「还没有自建歌单」（§9 四态呈现符合）。
- ❌ → **已修正**：7 张视口标注失实（P1-19，登记即关闭，重截件替换）。
- ❌ → **登记开放**：360×800 曲库入口卡「喜欢的歌曲」标签省略号截断（**P2-15**，新发现；P2-10 回归测试只锁 4 字标签「最近播放」，mobile_library_page_test.dart:148-157，5 字标签漏锁）。
- ⚠️ 证据局限（如实登记）：①设置页两档截图为永久「配置加载中…」态（uiOnly 无后端），设置真实 UI 不可达；②phone/tablet 捕获为桌面壳降级布局渲染，MobileShell 底部 NavigationBar/MiniPlayer、TabletShell NavigationRail 运行时形态不可核（P1-06/G6 维持）；③DEBUG 横幅为 debug 构建固有（非缺陷）；④浅色主题运行时整页截图未采集（chrome_theme_test 5 项 widget 层证据维持）。

## 新增/关闭缺陷

本轮净变化（04 矩阵已同步）：

- **P1-19（登记即关闭）**：final uionly 截图 7 张视口标注失实（desktop-home-1024 实为 1280×720 左上裁切；6 张 phone 标注 360/390/430 实为 560 宽，执行批次 Xvfb 屏 :227-:232 即 560 系）。根因：uiOnly 分支不应用 `VOICEFOX_START_SIZE`/WindowOptions（该代码块位于 main.dart:143-175 真实分支、uiOnly 分支 main.dart:106-116 提前 return；`xdotool getwindowgeometry` 实测 uiOnly 默认窗 1280×720）。关闭证据 = 三重：尺寸实测（identify 前后对照）+ 根因代码定位 + 7 张真实视口重截逐张目检（真 1024×640 渲染折叠 rail + PlayerBar 与 Phase 6 QA 一致，证明应用本体无回归，属证据管线缺陷）。处置遵循 04:11/04:107 先例（证据失实判 P1、重截后登记即关闭）。
- **P2-15（新增，开放）**：360 视口曲库入口卡「喜欢的歌曲」标签省略号截断（真 360 运行时实拍，crop 300% 放大目检）。P2-10 的回归测试仅对「最近播放」（4 字）做 TextPainter 宽度断言，5 字标签在 360 三列等分最窄档（卡内宽 ~70px 级）越界。§12.7 P2 视觉细节级，不影响操作。
- **P3-10（新增，开放）**：uiOnly 分支不支持 `VOICEFOX_START_SIZE`（`_startSizeFromEnv` 逻辑仅存在于真实分支），验收截图管线只能靠 xdotool 后置调窗；未来重建截图管线时应在 uiOnly 分支复用同一 WindowOptions 块（含 minimumSize 语义决策：uiOnly 现无 560 钳制，360-560 宽可达）。
- 无既有缺陷在本轮被修复关闭（本轮无功能性代码修复；P1-19 为证据缺陷关闭）。

### 最终 P0-P3 计数（04 矩阵口径，2026-11-13）

| 级别 | 开放 | 已关闭/已修复 | 开放项 |
|---|---|---|---|
| **P0** | **1** | 1（P0-02） | P0-01 主 isolate 概率性卡死（未复现未定位；ButtonPress 间歇失效同域观察在案） |
| **P1** | **4** | 12 + P1-19（本轮登记即关闭） | P1-05 进程静默退出（1 例观察）/ P1-06 Android 全链环境阻断 / P1-16 导入 bottom sheet 运行时断言红屏 / P1-17 扫描取消后部分入库 |
| **P2** | **8** | 6 关闭 + P2-07 已修复 | P2-02 双 ThemeData 产源（受控）/ P2-04 niri 窗口尺寸契约 / P2-05 MPRIS GUI 未接 / P2-08 xwayland resize GL timeout / P2-09 队列拖拽排序（后端无命令，如实禁用）/ P2-13 重试后损坏文件计「复用」/ P2-14 解析阶段暂停打成失败 / **P2-15（本轮新增）** |
| **P3** | **8** | P3-01 已修复 + P3-03 落地长期记录 | P3-02 readAudioInfo 悬空桥 / P3-04 PlaylistDto 字段缺失 / P3-05 ATK 断言与 OpenGL 告警 / P3-06 文档债 / P3-07 歌词无手动重取 / P3-08 旧 golden 数据种子 / P3-09 下载行 overflow 23px 与大小显示异常 / **P3-10（本轮新增）** |

### §13 Phase 7 退出条件判定（如实）

| 条件 | 判定 |
|---|---|
| P0/P1 为 0 | **未满足**：P0-01 开放（概率性未复现，根因未定位，不构成修复证据）；P1-05/16/17 真实开放；P1-06 环境阻断维持。其中 P1-16（主导入入口运行时红屏）为最高优先可复现缺陷，建议下一修复批次首先收口 |
| 质量门禁全部通过 | **Linux 侧全部通过**（format/analyze/flutter test 375/cargo test 826/cargo fmt 全绿 exit 0）；**两项门禁无法执行**：clippy 原样命令 exit 101（MPV_SOURCE 环境缺失 → libmpv2 build.rs panic，基线在案）、Android 构建类门禁（环境缺失 + 用户搁置） |
| 每个目标平台有构建与运行证据 | **Linux ✅**（release 07:33 + debug 06:33 构建 + Xvfb 运行时截图 13 张真实视口）；**Android ❌**（无构建无运行，全程未验证，**无 Android 真机验证，如实写明**） |
| 未验证项明确披露 | ✅ 见下节 |

## 未解决问题和原因（§16 未验证项汇总）

**真机验证项（全部未验证，无 Android 真机验证）**：
- §12.6 Android 真机 13 项 + MobileShell/TabletShell/MiniPlayer/锁屏通知/后台播放/SAF 导入真机行为：无设备、无模拟器、SDK 目录不存在（P1-06；用户明确搁置：禁止 APK/Gradle 构建与 AVD 创建）。

**仅自动化测试锁定（无运行时证据）**：
- MobileShell 底部 NavigationBar/MiniPlayer、TabletShell 三态 rail/end panel（平台隔离，仅 widget/golden 层，tablet_shell_test 8/8、mobile_shell_test 全绿）；AndroidInsets widget 契约（android_insets_layout_test 7 项）；浅色主题整页运行时（chrome_theme_test 5 项 + VxChrome 双源 token）；封面请求头构造（cover_image_headers_test 12 项，未抓包）；扫描取消契约/暂停语义（local_music_import_test，运行时被 P1-16/P1-17 反证为不可信）。

**运行时已验证但受限**：
- 桌面运行时全部基于 Xvfb 无头环境（非物理真机）；真实音频输出不可验证（无头 pipewire，仅 progress 事件流）；MPRIS 无 GUI 接线（P2-05，busctl 零命中维持）；窗口 resize 期间 GL frame timeout 域（P2-08/P1-05 同域）未定位。

**Phase 7 工作清单未执行项（如实）**：
- 性能 profiling：未执行（无 profiling 会话；Phase 5 已登记 30k 启动 ≈30-40s 未归因，维持）。
- 无障碍专项检查：未执行（无对比度实测/屏幕阅读器/焦点走查会话；仅既有深色对比度目检与语义标签层面）。
- 浅色主题运行时整页走查：未做（Phase 1 起逐阶段顺延，本轮仍未采证）。
- golden harness（G5 裁决点）：未建立（全仓无 matchesGoldenFile 基础设施，Phase 6 登记的裁决点维持开放）。
- §12.4 全页面×全视口矩阵逐格补齐：未逐格补齐（final 目录 13 张 + 各阶段存档覆盖主要页面；uiOnly 下搜索/歌单/下载/全屏播放页呈空/错误态未重复采集）。

**环境注记**：本轮报告员运行的 Xvfb :77 与 app 进程已全部清理；/tmp 下 p7_* 日志与截图中间件留存备查。

## 下一阶段进入条件

Phase 7 为最终收敛阶段，无下一阶段。**收口判定（如实）**：
- **Linux 桌面目标**：门禁全绿 + 构建/运行证据齐 + 视觉 QA 通过 → **可收口**。
- **Android 目标**：退出条件不成立（无构建、无真机验证），在用户补齐 SDK/设备且解除搁置前维持「未验证」终态（P1-06）。
- **遗留修复批次建议**（不阻塞本报告交付）：P1-16（导入入口红屏）→ P1-17（取消入库）→ P0-01/P1-05 定位 → P2-13/14/15 → P3 尾项；MPRIS（P2-05）与队列拖拽排序（P2-09）需后端/独立批次。

---

## §16 许可证合规结论（引用 docs/redesign/02-license-and-reuse-audit.md）

依据 `docs/redesign/02-license-and-reuse-audit.md`（2026-11-11 修订轮）：

- **结论：当前不存在许可证或第三方代码合规阻塞项。** Voicefox 根许可证 **MIT**（02:5，`head -2 LICENSE` 实测 "MIT License"）。
- **最高风险项已隔离**：参考项目 **harmonoid = PolyForm Strict 1.0.0**（02 §0，两次独立证实：研究记录 LICENSE 全文 104 行实读 + 汇总轮首行复核），**禁止任何代码/资产复制**（禁衍生/禁再分发；旧快照 GPL-3.0 时代同样禁止，不存在 MIT 时代）。feishin（GPL-3.0）与 nuclear（AGPL-3.0-only）同样零复制、仅交互参考。全部 UI 为本仓自有实现或合规 vendored。
- **已履行的移植义务**：myune_music vendored（Apache-2.0）110/110 文件头保留 `Vendored from … @5188867b` + seam 标记恰 2 处（lyrics_handler.dart:70-80、playlist_content_notifier.dart:735-798）+ lyricGeter（MIT）全文注册于 license_service.dart:9-45；本轮 Phase 0-7 全部 UI 实现未新增第三方代码拷贝（Rust 零改动、Flutter 改动均为自有页面/壳层）。
- **合规待办（非阻塞，02:233-234 登记）**：①建议新建仓库内 NOTICE 文件替代 vendored 文件头中已失效的外部路径引用（`/home/emo/code/myune_music-reference/LICENSE` 不存在，02:195-197 实测），满足 Apache-2.0 §4 分发义务；②`app_model_audio_backend.dart:14-15` 过时的 setVolume no-op 注释待更正。将来解除 hotkey_manager/system_fonts 本地 stub 或引入 finamp MPL-2.0 文件时须按 02 §2.2/§2.3 履行对应义务。

---

## 清尾 L1（2026-11-14，Phase 7 后开放缺陷清理批次，报告员验证轮）

> 本小节为 Phase 7 报告的追加批次记录：Phase 7 收口后遗留的开放缺陷（P1-16/P1-17/P2-13/P2-14/P2-15/P3-10 + P2-02 护栏化）在本轮实施与验证，缺陷状态以 `docs/redesign/04-defect-matrix.md` 为准。

### 范围

Phase 7 收口后开放缺陷清理（清尾 L1）：**七项关闭**（P1-16 导入流重入红屏、P1-17 扫描取消部分入库、P2-02 双 ThemeData 产源护栏化、P2-13 重试后损坏文件计复用、P2-14 解析阶段暂停契约锁定、P2-15 360 视口标签截断、P3-10 uiOnly START_SIZE）+ **P1-05/P2-08 崩溃取证面补齐**（crash.log panic/Flutter 异常面，两项维持开放）。性能 profiling、无障碍专项、Android 全链、浅色主题运行时走查、golden harness 维持 Phase 7 口径未执行（本轮不新增）。

### 修改文件（实施轮改动，报告员逐文件 diff 核读）

| 文件 | 改动 | 归属 |
|---|---|---|
| `flutter/lib/src/pages/local_music_page.dart` | +25：模块级导入流重入门禁 `_importFlowActive`（:613，try/finally 保证释放，:630-637）+ `debugResetImportFlowGate`（:617） | P1-16 |
| `source/src/local/mod.rs` | +89：提交段前最终取消检查点（:458-468，取消即丢弃本轮报告、快照保持原样）+ scan() 失败清单非空强制重扫（:253-262）+ 2 条 Rust 测试 | P1-17 / P2-13 |
| `download/src/manager.rs` | +91：确定性回归测试 `pause_during_resolving_keeps_paused_against_late_results`（生产代码零改动；生产行为经 git show 实核自 Phase 5 收口提交 57db10b 在树） | P2-14 |
| `flutter/lib/src/pages/library_page.dart` | +9/-1：compact 两行卡标签改 `FittedBox(fit: BoxFit.scaleDown)`（:219-224，省略号路径结构性不可能触发） | P2-15 |
| `flutter/lib/main.dart` | +124/-33：`_startSizeFromEnv`/`_startPosFromEnv` 提取共享 helper（:105-124）+ uiOnly 分支应用 START_SIZE/POS（:180-199，minimumSize 有意不设，注释登记裁决）+ `installCrashLogHandlers`（定义 :154、main() 调用 :172，FlutterError/未处理异常落盘 crash.log） | P3-10 / P1-05·P2-08 |
| `ffi/src/crash_log.rs`（新建） | +105：`crash_log_path`/`append_crash_entry`/`install_gui_panic_hook` + 2 测试；诚实边界注释：引擎级 SIGABRT/GL abort 无 unwind 不经 hook | P1-05·P2-08 |
| `ffi/src/lib.rs` | +7：`new_desktop` 接线 `install_gui_panic_hook`（:1158） | P1-05·P2-08 |
| `flutter/lib/src/theme/voicefox_theme.dart`、`flutter/lib/src/design_system/voicefox_theme.dart` | 头注改「非运行时真源」收口（预览语义限定：设置页逐卡预览 / Gallery 预览页） | P2-02 |
| `flutter/test/crash_log_test.dart`（新建） | P1-05/P2-08 Dart 侧回归 1 项 | 同上 |
| `flutter/test/theme_source_guard_test.dart`（新建） | P2-02 护栏 2 项（运行时 5 文件零引用 + settings_page 预览例外在位） | P2-02 |
| `flutter/test/local_music_import_test.dart` | +1：P1-16 门禁用例（选择器挂起复现运行时间隙 → 二次触发不叠开 → 门禁释放后可用） | P1-16 |
| `flutter/test/mobile_library_page_test.dart` | +1：P2-15 结构性断言（FittedBox 在树 + RenderParagraph 按理想宽度布局，旧 ellipsis 形态该断言即失败） | P2-15 |
| `docs/redesign/screenshots/final/phone-library-360x800-uionly-recheck.png` | 新增（报告员运行时证据：360×800 曲库「喜欢的歌曲」标签完整） | P2-15 / P3-10 |
| `docs/redesign/04-defect-matrix.md`、`docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` §17 | 七项关闭 + 两项取证注记 + 追踪表行 | 报告员 |

### 执行命令与退出码（报告员本轮实跑，全部在 `/home/emo/code/voicefox-gui`）

| # | 命令 | 退出码 | 结果 |
|---|---|---|---|
| 1 | `/home/emo/flutter/bin/dart analyze --fatal-infos` | **0** | `No issues found!` |
| 2 | `/home/emo/flutter/bin/dart format --output=none --set-exit-if-changed lib test` | **0** | `Formatted 253 files (0 changed)` |
| 3 | `/home/emo/flutter/bin/flutter test`（全量） | **0** | `00:42 +380: All tests passed!`（基线 375 + 本轮新增 5） |
| 4 | `cargo test -p voicefox-ffi crash_log` | **0** | 2 passed / 0 failed |
| 5 | `cargo test -p lx-source --lib local::` | **0** | 30 passed / 0 failed / 1 ignored（含 P1-17 `cancelled_before_commit_segment_does_not_commit`、P2-13 `manual_rescan_reparses_failed_files_instead_of_counting_reuse` 均 ok） |
| 6 | `cargo test -p voicefox-download pause_during_resolving` | **0** | 1 passed（P2-14 契约锁定用例） |
| 7 | `cargo fmt --all -- --check` | **0** | 零格式偏差 |
| 8 | `RUSTUP_TOOLCHAIN=1.99.0 flutter build linux --debug --dart-define=VOICEFOX_UI_ONLY=true` | **0** | `✓ Built build/linux/x64/debug/bundle/voicefox_flutter`（bundle/kernel_blob/so 2026-11-14 00:35:21-28；libvoicefox_ffi.so 286350280B，含本轮 ffi crash_log 重建） |

clippy 原样门禁（§12.1）本轮未复跑（Phase 7 基线 exit 101 = libmpv2 MPV_SOURCE 环境缺失在案，本轮 Rust 改动不触及该依赖链，如实登记未复跑）；全量 cargo test 未复跑（定向 3 crate 全绿；Phase 7 基线 826 全绿在案）。

### 运行时验证（Xvfb :117 1600x1200x24，无 WM，报告员实跑）

- **P3-10 几何实核**：uiOnly bundle + `VOICEFOX_START_SIZE=360x800` 启动 → `xdotool getwindowgeometry` = **360×800 精确生效**（Position 0,0；无 uiOnly 旧 1280×720 默认、无 560 钳制），P1-19 根因链在 uiOnly 分支闭合。
- **P2-15 运行时目检**：同实例 `VOICEFOX_START_PAGE=library` 360×800 曲库页截图逐项目检：「喜欢的歌曲」标签**完整渲染无省略号**（同排「最近播放/本地音乐」完整），两行卡形态、分类 chips、来源分段、空态、PlayerBar 空态均正常；截图 `docs/redesign/screenshots/final/phone-library-360x800-uionly-recheck.png`（360×800 50884B，`magick identify` 核验）。
- **P1-16 运行时复走未达成（如实登记）**：uiOnly <960 降级壳内曲库入口卡 tap 未推入 LocalMusicPage（VM service widget 树 dump 确认树中无 LocalMusicPage；同页来源分段 tap 响应正常，排除隐形 modal 屏障；widget 层推入链路由 phase5_library_test.dart:219-222 锁定且在全量 380 项内绿；本轮 library_page.dart 仅改标签渲染，不归因本轮 diff，登记为 uiOnly <960 降级壳运行时观察，未定缺陷等级）。另实测首页空库 Hero「导入本地」当前接线为 home_page.dart:118 `navRequest.value = 5`（导航曲库）而非导入流，Phase 2 偏差 D6「与本地音乐页同一实现」口径已过期（既有接线、非本轮改动）。P1-16 关闭依据 = 门禁机制结构性消除复现窗 + 确定性 widget 复现 + 实施轮运行时实证（代码注释在案）；原红屏现象本身报告员未复现复核。
- **排查注记（环境）**：运行时排查初期旧 app 实例未退出造成多窗口堆叠干扰点击定位（`pkill -x` 对 >15 字符进程名无效、`pkill -f` 需括号技巧避免匹配承载 shell 自身）；清场后单实例重跑，上述结论均出自干净实例。会话结束进程清理复核：app 与 Xvfb :117 均 0 残留（ps 实测）。

### 测试结果（通过/失败/跳过）

- **Flutter 全量**：380 通过 / 0 失败 / 0 跳过（exit 0）。新增 5 项：crash_log_test 1、theme_source_guard_test 2、local_music_import_test +1（8 项）、mobile_library_page_test +1。
- **Rust 定向**：voicefox-ffi crash_log 2、lx-source local:: 30（1 ignored）、voicefox-download pause 1，全绿 exit 0。
- **无跳过项、无因失败删除的测试**（§15 红线合规）；本轮无 Rust 生产代码删除性改动（manager.rs 仅增测试）。

### 新增/关闭缺陷（本轮净变化）

- **关闭 7 项**：P1-16（导入流重入门禁）、P1-17（提交段前取消检查点）、P2-02（单一真源护栏）、P2-13（失败清单非空强制重扫）、P2-14（确定性测试锁定；生产行为 57db10b 已在树）、P2-15（FittedBox scaleDown + 运行时目检）、P3-10（uiOnly START_SIZE/POS + 运行时几何实核）。
- **取证面补齐、维持开放 2 项**：P1-05/P2-08（crash.log 覆盖 panic/Flutter 异常面；引擎级 SIGABRT/GL abort 无 unwind 仍无取证，静默退出根因未定位）。
- **最终开放计数（04 矩阵口径）**：**P0×1 / P1×2 / P2×4 / P3×7**（此前 P0×1 / P1×4 / P2×8 / P3×8）。

### 未解决问题和原因（本轮如实）

- P0-01 主 isolate 概率性卡死：未定位未复现，维持（profiler 仍缺位）。
- P1-05/P2-08 静默退出：取证面部分补齐（panic/Flutter 异常面），引擎级路径需外部 watchdog，根因未定位。
- P1-06 Android 全链：环境阻断 + 用户搁置维持（本轮未触碰）。
- P1-16：原红屏运行时复现报告员未独立复核（复现窗被门禁结构性消除；实施轮运行时实证以代码注释为证）；uiOnly <960 降级壳入口卡 tap 未推入现象登记为观察，未定缺陷等级。
- P2-14：「解析失败先于暂停落地」微竞态无法排除（若失败先到，显示失败为语义正确）；运行时重走未做。
- P3-10：真实桌面分支运行时未重测（代码 diff 为 helper 复用重构，默认 1150x720 与 minimumSize 链路零变化）。
- clippy 原样门禁、全量 cargo test 本轮未复跑（基线在案）。

### 收口判定

Linux 桌面目标维持 Phase 7 收口结论；本轮为 Phase 7 后清理批次，P1 开放项由 4 收敛至 2（均环境/根因类：P1-05 静默退出、P1-06 Android 环境阻断），后续批次建议：P0-01/P1-05 定位（profiler/watchdog）→ P2-05 MPRIS（后端批次）→ P3 尾项。

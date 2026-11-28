# 会话交接：第三轮工程演进（Batch C 全部收口 + Batch D 已实施，待门禁终验与提交）

> **【已失效 → 请读 `SESSION-HANDOFF-2026-11-17.md`】** 本文的工具链陷阱已并入新交接 §二；Batch D-F-G 均已提交推送（HEAD `846bbfe`）。本文仅作历史存档。
>
> 状态：生效中 · 交接日期：2026-11-16 · 交接 HEAD：`566ed42`（feat/ui-redesign，已推送 GitHub，本地在其上另有 **Batch D 未提交改动**，见 §二） · 接收方：任意端执行 AI · 上游计划书：`docs/redesign/second-round/PLAN-rust-ffi-and-ui-evolution.md`（仓内副本）
> 前序交接：`docs/SESSION-HANDOFF-2026-11-14.md`（其中「环境与命令」「Git 纪律」「开放项」各节继续有效，本文只写增量）

## 一、给执行 AI 的开工指令（直接复制执行）

```
继续执行《Flutterfox 跨平台工程演进计划书》（docs/redesign/second-round/PLAN-rust-ffi-and-ui-evolution.md）。
当前状态：Batch C 全部收口（C-A~C-D 四批已提交推送，SR-03 手机复用桌面收敛 8/8）；
Batch D（桌面体验完善）已在本会话实施完毕但尚未提交——工作区有未提交改动，
先按本文 §二 核对工作区与门禁状态，跑完 §五 终验门禁后按仓库长消息风格提交
（commit message 草稿见 §二 末尾），推送走 HTTPS（网络抖动重试即过）。
随后按计划书顺序推进 Batch E（下载可靠性 §8）→ F（队列排序协议 §9.1 + Linux MPRIS §9.2）
→ G（既有缺陷运行时闭环 §10）→ H（稳定性诊断 §11）→ I（质量工程 §12）。
纪律：每批先审计后修改（§13 固定流程）；门禁全绿才提交；逐批单独 commit；
推送走 HTTPS；Android 无用户明确授权不构建 APK/Gradle/AVD；
Linux 专属验证项（桌面 bundle 实跑/Xvfb 截图/niri/MPRIS 运行时）如实标「未验证」；
不删不弱化既有断言；提交/推送前与用户确认授权口径（§0.4.9）。
```

## 二、当前状态（实测，Windows 端）

| 项 | 值 |
| --- | --- |
| 分支/HEAD | feat/ui-redesign @ `566ed42`（已推 GitHub），**工作区有 Batch D 未提交改动**（约 +450/-60，13 文件改 + 2 新增，清单见 §三） |
| 已推送提交 | `4843d27` = Batch C-C（C-04 歌单详情手机页 + C-08 曲库核验 + C-07 帮助页手机形态）；`566ed42` = Batch C-D（Settings 手机分组 + padding 单源化 + 矩阵扩充） |
| 测试基线 | flutter test 逐文件全绿 **501 passed / 0 failed（61 文件，Batch D sweep 实跑）**；cargo test --workspace **835 + 4 平台环境限制**（838 Linux 基线 = 835 + 3，见 04 矩阵 2026-11-15 行） |
| 工具链（本机实测可用） | Flutter 3.47.9（`C:\Users\emo\flutter\bin`，不在 PATH，需全路径调用）· rustc/cargo 1.100.0 **gnu 宿主**（`~/.cargo/bin`）· VS Build Tools 2022 MSVC 14.44 + SDK 26100（用户手装，flutter test 的 native assets 必需）· w64devkit（`C:\Users\emo\.zcode\workspace\toolchain-setup\w64devkit-extract\w64devkit\bin`，PATH 前置提供 gcc/dlltool）· MPV_SOURCE=`C:\Users\emo\.zcode\workspace\toolchain-setup\mpv\mpv-source`（预编译 libmpv-audio v0.41.0-1，sha256 已验）· rustup 镜像 TUNA（RUSTUP_DIST_SERVER/UPDATE_ROOT） |
| 网络现状 | DNS 被污染（github.com → 假 IP）：git 走 `http.curloptResolve`（仓配置已存，轮值真 IP 20.27.177.113/20.200.245.247/140.82.121.9/140.82.113.9）；推送偶发全 IP reset——**重试循环等窗口即过**（C-D 第 9 次成功）；codeload/raw/api 用 `--resolve` 同 IP 直连；rustup/crates.io 用 TUNA 镜像 |

### ⚠️ 关键环境陷阱（Windows 端必读）

1. **`flutter test` 单命令全仓模式在本机会挂**：flutter-tester 进程级瞬时挂起（"did not complete"，挂起文件集合逐轮漂移、单文件复跑全绿）。**等效全量口径 = 逐文件顺序实跑 + 退出码判定**（`for f in test/*_test.dart; do flutter test $f; done`），挂起文件重试 1-3 次即绿。Linux CI 单命令不受影响。
2. **Git Bash 的 `/usr/bin/link.exe`（GNU coreutils）会遮蔽 MSVC 链接器**：rustc msvc 宿主在无 VS 时静默用到它报错；**已整体切 gnu 宿主工具链规避**（`rustup default stable-x86_64-pc-windows-gnu`），cargo 命令需 `PATH=w64devkit/bin:$HOME/.cargo/bin:$PATH` + `MPV_SOURCE` + `--features lx-player/build_libmpv`。
3. **cargo test 必带 `--features lx-player/build_libmpv`**：默认 feature 的 libmpv2 build.rs 不注入 MPV_SOURCE 搜索路径（CI Linux 用系统 libmpv-dev 无此问题）。
4. **Perl 多行替换在 CRLF 文件上不可靠**（\n 不匹配 \r\n，本会话两次损坏后手工修复）；跨行编辑一律用 Read+Edit 工具，行级替换可用单行 sed/perl。
5. **flutter_rust_bridge_codegen 未在本机验证**（Batch A-F 若需再生成，先 `cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked`，未执行过）。
   → **2026-11-17 Batch F 增量**：已装机并打**本地路径补丁**（FRB 2.13 在 Windows 把 workspace 路径混入 `\\?\` 前缀 + 混合分隔符，`strip_prefix` 失配读不到 lib.rs；补丁只修路径计算，输出与 Linux CI 一致）。再生成已实跑过一次（Batch F FfiCommand +2）。
6. **（Batch F 增量）测试 exe 需要 libmpv-2.dll 在 PATH**：`--features lx-player/build_libmpv` 构建的测试二进制运行时报 `STATUS_DLL_NOT_FOUND`（0xc0000135）——把 `toolchain-setup/mpv/libmpv-extract/libmpv-audio-x86_64-*/` 加入 PATH（此前口径只登记了构建期 MPV_SOURCE，本条补全运行时半边）。
7. **（Batch F 增量）单包 cargo 命令同样必带 `--features lx-player/build_libmpv`**：`cargo test -p <pkg>` 不带该 flag 时 feature 指纹与 workspace 不同，重链时 libmpv2 build.rs 不注入 `-L` → `cannot find -lmpv`（链接期才暴露，易误判为环境抖动）。

## 三、Batch D 已实施内容（工作区未提交，勿重做）

| 项 | 文件 | 内容 |
| --- | --- | --- |
| SR-10 | 新 `design_system/components/desktop_content_constraint.dart` + 6 页包裹 | DesktopContentConstraint（Align topCenter + maxWidth 1320，与 now_playing 既有先例同源；窄窗零变化）；home/discover/search/library/downloads/settings 桌面根级包裹 |
| SR-11 残余 | `vx_hover.dart`（+onSecondaryTapUp）→ `vx_card_shell.dart` → `vx_playlist_card.dart` 参数链 + `custom_playlists_page.dart` 新顶层 `showCustomPlaylistCardMenu`（打开详情/重命名/删除，复用同一对话框命令链）+ 首页卡/自建歌单行接线 | 卡面右键 = 同一动作集菜单；**顺带修复真缺陷：VxCardShell 此前仅封面区挂手势，标题/副标题是死区**（外层 GestureDetector opaque 整卡承接）；专辑/歌手/远端歌单卡无域动作如实不加（§7.2.7） |
| SR-13 | `app_shell.dart` | 侧栏/中央内容/右栏内嵌 + PlayerBar 各包 FocusTraversalGroup（Tab 顺序 = 侧栏→内容→右栏→PlayerBar，组内阅读序） |
| SR-14 | `nav_bus.dart`（+searchKeyword ValueNotifier）+ `search_page.dart`（权威写入+流监听回流+防抖派发）+ `app_header.dart`（controller+onChanged 写流）+ `app_shell.dart`（_headerSearchController + 监听同步 + dispose） | Header↔搜索页双向同步单一状态流；两端「文本相同跳过」防循环；Header 提交语义不变 |
| SR-15 | `home_page.dart` | 首页「我的歌单」卡点按 → `CustomPlaylistDetailPage`（不再全跳曲库）； onViewAll 仍指曲库 |
| 测试 | 新 `test/desktop_batch_d_test.dart`（7 用例：SR-10×2/SR-13/SR-14×2/SR-15/SR-11 右键含二级断言） | 全绿实跑 |

**Batch D commit message 草稿**（工作区根提交时用，`toolchain-setup` 会话目录若已清理则按 04 矩阵 2026-11-16 行重写）：
`feat(desktop): Batch D 桌面限宽+卡面右键+焦点漫游组+搜索双向同步+首页歌单入口（SR-10/11/13/14/15）`——要点与实测数据见 `docs/reports/WORK_REPORT_2026-11-15_batch-c-d.md` 同目录 **`WORK_REPORT_2026-11-15_batch-d.md`**（本会话已写就，随工作区一并提交）。

## 四、已完成内容（本会话累计，勿重做）

| 批次 | commit | 内容 |
| --- | --- | --- |
| Batch C-C | 4843d27 | C-04 歌单详情手机页（playlist_detail_shared 提炼 + MobilePlaylistDetailPage §5.6 全规格 + 4 处 push 接线）+ C-08 曲库核验收口（+4 用例；**修复真缺陷：library_page `_artistListRow` leading 无约束，手机档与桌面列表档必挂布局断言**）+ C-07 帮助页手机形态（showDesktopShortcuts 过滤 + 触屏操作段） |
| Batch C-D | 566ed42 | C-06 Settings 手机分组（SettingsSectionContent 提炼 + MobileSettingsPage 列表 + MobileSettingsSectionPage 二级页 + 种子 auto-push）+ padding 单源化（android_insets `mobileListBottomPadding` + 8 页替换）+ viewport_matrix 390/430 扩充 |

## 五、接手后第一件事（Batch D 终验 + 提交清单）

1. `git status --short`（应见 §三 清单 ± format 微调）；
2. `flutter analyze --fatal-infos` = 0；`dart format --output=none --set-exit-if-changed lib test` = 0 changed；
3. `flutter test` 逐文件 sweep（§五命令见 04 矩阵 2026-11-16 行；本会话已实跑 **501 passed / 0 failed，61 文件全绿**，接手后复跑一次确认即可）；
4. cargo 门禁沿用（Rust 零改动，git diff Rust 目录空）；
5. 按 §二 commit 草稿提交（与用户确认授权）→ 推送（重试循环）；
6. 观察 draft PR #12 CI：本会话已推 4843d27/566ed42 两轮，CI 9 job 结果尚未逐 job 核对（会话网络受限），接手后先看最新两个 run。

## 六、开放项与已知陷阱（增量，前交接 §六 继续有效）

1. **flutter test 逐文件口径**：全仓单命令挂起为本机环境抖动（登记在案），Linux CI 单命令为准；两侧结论一致（逐文件全绿 = 等效全量）。
2. **cargo 4 例平台限制**（lx-source 3 例临时目录 `::` + app visualizer 1 例时序 flaky 单独复跑过）：夹具不改不削弱，Linux CI 为准（04 矩阵 2026-11-15 行）。
3. **SR-14 流为全局单例**：测试间必须复位（desktop_batch_d_test 用 addTearDown 示范）；多壳实例同帧写流的理论竞态未登记缺陷（单壳生产路径无此形态）。
4. **SR-11 菜单动作集 = 自建歌单域既有动作**；专辑/歌手/远端歌单卡面右键如实未加（无域动作）；触屏长按未接（卡面长按语义留后续，song_tile 已有先例可循）。
5. **clippy 1.100 版本漂移已修**（notification.rs collapsible_if 折叠）：CI runner 若仍 1.99，该修复为前向兼容零风险。
6. **CI codegen-check**：本会话未动 FFI 面，生成文件无变化；若 Batch E/F 触及 API，先跑 codegen（见陷阱 5）。
7. **工作报告**：C-C/C-D 已入树（docs/reports/WORK_REPORT_2026-11-15_batch-c-{c,d}.md）；Batch D 报告已写待随批提交。

## 七、Git 纪律（继续有效）

只动 feat/* 分支；不 push main、不 force、不打 tag、不 merge、不发 release；提交逐批（类型(范围): 摘要 + 实测门禁数据 + 如实登记未做项）；push 走 HTTPS 容忍抖动重试；**提交/推送需用户当前授权（§0.4.9；本会话 C-C/C-D 两批均经用户明示「提交并推送」）**。

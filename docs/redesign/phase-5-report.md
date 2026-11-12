# Phase 5 Report（本地音乐、下载和离线体验）

- 收口轮日期：2026-11-13。证据来源分层标注：**报告员实跑**（本会话执行并取得输出）/ **ask 已知事实**（实施/QA/门禁会话实跑，报告员未复跑，如实转述）。
- 偏差 E1-E6 与缺陷 D1-D5 均登记于 `docs/redesign/04-defect-matrix.md`（Phase 5 偏差登记节 + P1-16/P1-17/P2-13/P2-14/P3-09）。

## 范围

- §5.10 本地音乐导入全链：导入方式双选项入口（选择文件夹/选择文件）、系统 picker seam、PlatformException 回退手输对话框、目录管理（追加/移除确认）、扫描进度与取消、统计条五字段（新增/复用/无法读取/无音频文件/移除）、失败重试（重扫语义）。
- §5.11 下载管理：三态分组（进行中/已完成/失败）与计数、空组区分文案、暂停/取消（解析与下载两阶段）、删除二次确认（记录+本地文件同删）、失败组重试重新入队、wire 状态词汇表根因修复（E5）。
- 数据地基：文件指纹缓存增量扫描、曲库快照持久化（含 `first_seen`）、扫描快照整体替换语义。
- 本地大库性能：10k/20k/30k 真实文件导入与滚动。
- 不在本轮范围：Android 真机全链（P1-06 环境阻断维持）、浅色主题（归 Phase 7）、全量 flutter test / cargo test 与 cargo release 构建（外部门禁统一执行，按 ask 范围未跑）。

## 修改文件

未提交工作区改动（`git diff --stat HEAD` 报告员实测；Rust/应用 17 文件 +1899/-167，测试 3 文件 +186/-20；随收口提交入树，本轮报告员不执行 git 提交）：

| 层 | 文件 | 变更 | 内容 |
|---|---|---|---|
| Rust·扫描 | source/src/local/mod.rs | +366 | 扫描编排/统计字段（新增/复用/无法读取/无音频文件/移除）/快照提交 |
| Rust·扫描 | source/src/local/scanner.rs | ±197 | 协作式取消标志逐文件检查（:150-165、:286-307「遍历到取消点即停」） |
| Rust·新增 | source/src/local/cache.rs | 新增 | 曲库缓存：分组歌曲+文件指纹+解析失败清单+`first_seen`（:3-34），重启加载与存在性校验 |
| Rust·下载 | download/src/engine.rs | +349 | 下载状态机（queued/resolving/downloading/tagging 到 done/skipped/cancelled/paused/failed） |
| Rust·下载 | download/src/manager.rs | +288 | 暂停/取消/删除任务与 `.part` 语义（E2） |
| Rust·下载 | download/src/records.rs | +73 | 已完成记录持久化 downloads.json（:109） |
| Rust·下载 | download/src/test_support.rs | ±9 | 测试支撑同步 |
| Rust·应用 | application/src/service.rs / event.rs / ports.rs | +56/+31/+14 | 扫描统计与下载命令/事件面 |
| Rust·运行时 | runtime/src/lib.rs | ±18 | `task.state.code()` 英文机读键下发（:386，E5） |
| Rust·FFI | ffi/src/lib.rs | +52 | 新命令/DTO 桥接 |
| Rust·TUI | app/src/pages/downloads.rs + context.rs | +8/±2 | TUI 状态文案同步（继续用 `label()`） |
| Dart | flutter/lib/src/pages/local_music_page.dart | +269 | 导入双选项 bottom sheet（:573-594）、picker seam 与 PlatformException 手输回退（:608-627、:647-653）、SAF content:// seam（:555-568） |
| Dart | flutter/lib/src/pages/downloads_page.dart | +245 | 三态分组 chips/表格/操作列/删除二次确认 |
| Dart | flutter/lib/src/app_model.dart | +55 | 下载任务状态映射 `downloadStateLabel` |
| Dart·生成 | bridge/frb_generated ×3 + lib + freezed | 代码生成 | flutter_rust_bridge_codegen 2.13.0 + build_runner（freezed），随本轮提交 |
| 测试 | flutter/test/local_music_import_test.dart | 新增 7 项 | 导入双选项 seam/PlatformException 回退手输/统计条五字段/取消横幅 |
| 测试 | flutter/test/phase5_downloads_test.dart | 18 项（+141） | 三态分组/删除二次确认/清除已完成禁用/空组文案 |
| 测试 | flutter/test/phase5_local_music_test.dart | 6 项（+48） | 目录管理/移除确认/扫描取消横幅/单曲菜单 |
| 测试 | flutter/test/mobile_home_page_test.dart | +17 | 首页入口回归 |
| 截图 | docs/redesign/screenshots/final/*.png | 新增 4 张 | 见「截图路径」 |
| 文档 | 04-defect-matrix.md / 本报告 / 指南 §17 | 登记 | 偏差 E1-E6、缺陷 D1-D5、验收证据 |

## 关键设计决策

1. **指纹缓存增量扫描**（cache.rs）：整库快照（分组歌曲+文件指纹+解析失败清单+`first_seen`）落盘，加载时对指纹做存在性校验（源文件消失即剔除）；重复扫描按指纹复用，不重复入库。`first_seen`（来源文件到 Unix 秒）为 §5.2「最近添加」预留地基（E6，列表本体计划明确不做）。
2. **扫描快照整体替换 + 协作式取消**：取消为协作式标志，目录遍历与解析循环逐文件检查（scanner.rs:150-165、:286-307）；代码内契约「取消：结果未提交+已取消横幅」（local_music_import_test「取消扫描：统计条不展示旧值，显示已取消横幅」锁定）。运行时 D2 观察与此契约相悖，登记缺陷（见下）。
3. **wire 状态词汇表统一（E5，根因修复）**：`DownloadTaskDto.state` 由中文 `label()` 改为英文机读 `code()`（runtime/src/lib.rs:386）。历史 Dart 侧匹配英文键在生产全为死代码（Rust 发中文）；中文文案由 Dart `downloadStateLabel` 映射，TUI 继续 `label()`。FFI 为进程内接口，无外部契约受影响。
4. **SAF seam 诚实降级（E1）**：`localImportResolver` 可注入 seam，生产缺省对 `content://` 抛 `UnsupportedError`（local_music_page.dart:564-568），UI 显示「暂不支持该文件来源（content://）」，不伪造导入成功；实装与实机验证待 Android 环境。
5. **失败重试 = 重扫语义（E3）**：统计条失败项>0 提供「重试」（重扫必然重新解析无指纹记录的失败文件；部分失败不回滚已提交结果）。运行时 D3 观察到损坏文件被计「复用」与该语义相悖，登记缺陷。
6. **下载任务生命周期（E2/E4）**：暂停保留 staged 前缀、取消/删除清理本任务 `.part`；跨会话恢复不做（计划明确不做），已完成记录持久化 downloads.json；重启后历史 `.part` 不清扫（裁决点在案）。
7. **导入方式双选项 + 手输回退**：添加目录先弹双选项 bottom sheet（§5.10 流程 1-2），系统 picker 不可用（PlatformException，无 portal 沙盒环境）时回退手输绝对路径对话框；手输非唯一方法，是 seam 契约的一部分（local_music_import_test 锁定）。

## 数据流/交互变化

- **导入链**：添加目录 → 双选项（文件夹/文件）→ 系统 picker seam（不可用则手输对话框）→ 路径追加 config `[local_music] paths` + 下发扫描命令 → 进度事件（N/M）→ 统计条五字段 → 快照提交入库 → 重启持久。
- **下载链**：搜索结果入队 → queued/resolving/downloading/tagging → done/failed/skipped；三态分组 chips 实时计数；进行中行提供 暂停/取消，已完成行提供 打开/定位/删除，失败行提供 重试；删除走二次确认对话框，确认后记录与本地文件同删。
- **状态词汇**：wire 层英文 code（机读）→ Dart 层中文 label（显示）；E5 修复后 Dart 侧匹配从死代码变为活代码（有行为变更，已在矩阵登记）。

## 执行命令与退出码

**报告员本轮实跑（2026-11-13，/home/emo/flutter/bin/flutter，flutter/ 目录）**：

| 命令 | 结果 | 退出码 |
|---|---|---|
| `flutter test test/local_music_import_test.dart test/phase5_downloads_test.dart test/phase5_local_music_test.dart --reporter compact` | `00:04 +31: All tests passed!` | 0 |
| `ls build/linux/x64/debug/bundle/lib/` | `libvoicefox_ffi.so` 287203584B（mtime 11-13 00:37）在位 | 0 |
| `stat build/linux/x64/debug/bundle` | mtime 2026-11-13 00:37:47 | 0 |
| `cat ~/.config/voicefox/config.toml` | `[local_music] paths` 仅 `/home/emo/Music/voicefox-phase1`（测试后已还原 phase1 单路径，环境注记核实） | 0 |
| `ls /tmp/p5music-10k` 计数 / `p5music-20k` 计数 / `p5music-real` | 10000 / 20000 / P5测试曲1-6.mp3 在位 | 0 |
| 4 张 final/ 截图 Read 逐张目检 | 见「视觉 QA 结果」 | - |

**ask 已知事实（实施/QA/门禁会话实跑，报告员未复跑）**：

- 门禁全绿；`flutter build linux --debug` exit 0（bundle 含 cargo `libvoicefox_ffi.so`，报告员 ls 佐证在位）。
- Xvfb :105 + `GDK_BACKEND=x11` + `VOICEFOX_START_SIZE=390x844` / `START_PAGE=library` 真实启动；xdotool 驱动真实 UI、`import` 截图 + magick 裁切；数据全部真实（在线搜索 kw/酷我/酷狗/汽水/咪咕 共 200+ 结果、真实下载 5.5MB m4a / 2.6MB mp3+lrc 落盘 `~/voicefox/` 并经 ffprobe 验证 342s、本地扫描真实文件）。
- 导入实跑：picker 走 PlatformException 回退手输（Xvfb 无 xdg-desktop-portal），入库 6 首+元数据/时长正确，损坏文件计「无法读取 1」；统计条五字段全真实值；增量扫描指纹缓存复用 10006/4894/20006 多轮；失败重试不整体回滚（重试后 30012 首不变，见 D3）；目录+曲目持久跨 3 次重启（10012→14900→30012）。
- 性能实跑：10000 文件解析+入库 ≈2.5s、15112 新增 ≈12s 内、30k 曲库拖拽滚动流畅（懒加载逐行渲染）、30k 启动 ≈30-40s。
- 下载实跑：三态分组/计数/空组区分文案；暂停按钮实点 3 次（解析阶段）→ 均变「失败」而非已暂停（D4）；取消作废任务；删除二次确认+确认后记录与本地文件均移除；失败组重试真实重新入队。
- cargo 定向套件（上轮实施批次，04 矩阵验证记录在案）：download 70 / lx-source local:: 28（含 10k 复用契约）/ application 72 / runtime 40 / ffi 6 / app 333 全通过；clippy 六 crate 新增告警 0（lx-core 基线 30 条维持）。
- `unshare -n` → `Operation not permitted`（沙箱禁用户命名空间，离线隔离验证环境阻断）。

## 测试结果（通过/失败/跳过）

- 定向 3 文件 **31 项：通过 31 / 失败 0 / 跳过 0**（报告员本轮实跑 `00:04 +31: All tests passed!` exit 0）。构成（grep 计数与总数吻合）：local_music_import 7 + phase5_downloads 18 + phase5_local_music 6。
- 锁定要点（本轮运行输出逐名在册）：导入双选项 seam、PlatformException 回退手输（非唯一方法）、统计条五字段、取消后已取消横幅且统计条不展示旧值、目录移除确认、删除二次确认走删除命令、无已完成任务时清除已完成禁用、筛选空组与全空列表区分文案。
- 上轮实施批次（04 矩阵验证记录）：定向 flutter 4 文件 39 项全绿 + cargo 定向 6 套件全通过（数字见「执行命令与退出码」）。
- 全量 flutter test / cargo test 由外部门禁统一执行（已知事实「门禁全绿」），报告员未复跑全量，如实登记。

## 构建结果

- **debug**：`flutter build linux --debug` exit 0（ask 已知事实）；`flutter/build/linux/x64/debug/bundle` mtime **2026-11-13 00:37:47**、`lib/libvoicefox_ffi.so` 287203584B mtime 00:37（报告员 ls/stat 实测在位）。本轮全部运行验证基于该含修复产物。
- **release**：本阶段未重建（上轮 Phase 3 03:52:19 release bundle 不含本轮改动，如实登记；release 重建随收口提交后批次执行）。

## 设备和视口

- Linux 桌面（CachyOS）+ Xvfb :105 私有显示 + `GDK_BACKEND=x11`；`VOICEFOX_START_SIZE=390x844` 请求被 `main.dart:163` `minimumSize(560,480)` 钳到 **560×844**（非 390 宽，如实登记）；本地音乐/下载页在 560 宽下按窄布局真实渲染（4 张截图目检确认）。
- 精确移动视口（390×844）布局由 widget 测试层覆盖（31 项内）。
- Android 真机/模拟器：无（无 JDK/模拟器，P1-06 环境阻断维持）。

## 截图路径

| 文件 | 尺寸 | 大小 / mtime（实测） | 目检要点（报告员逐张 Read） |
|---|---|---|---|
| docs/redesign/screenshots/final/desktop-localmusic-560x844-importing.png | 560x844 | 84794B / 11-13 00:54 | 本地音乐页「正在扫描本地歌曲…」+取消按钮；目录 /tmp/p5music-real + /tmp/p5music-10k 带移除按钮；「共 12 首」真实条目（P5测试曲1-6·P5艺术家·00:01、Phase1 曲目真实时长 00:12/00:20/00:42）；DEBUG 横幅为 debug 构建固有 |
| docs/redesign/screenshots/final/desktop-downloads-560x844-active.png | 560x844 | 42711B / 11-13 01:22 | 三态 chips 全部 6/进行中 1/已完成 2/失败 3；进行中行 LOVE·3B LAB.☆·High320·「解析地址」进度条 + 暂停/取消按钮（解析阶段暂停钮在位，D4 场景）；清除已完成入口；全局播放栏「未在播放」空态 |
| docs/redesign/screenshots/final/desktop-downloads-560x844-completed.png | 560x844 | 62070B / 11-13 01:23 | 已完成 3 行真实封面（Love!/Arnd 3.3MB/3.3MB、L.O.V.E./Ashlee Simpson 2.3MB/2.3MB、LOVE/3B LAB.☆ 5.3MB/5.3MB）+ 打开/定位/删除操作列 |
| docs/redesign/screenshots/final/desktop-downloads-560x844-failed.png | 560x844 | 70842B / 11-13 01:24 | 失败 5 行「失败 · 音频…」截断文案 + 重试按钮；**1.4 MB / 475.7 KB 已收大于声明总量在图内可见（D5 证据之一）**；全部 7/进行中 0/已完成 2/失败 5 计数一致 |

## 视觉 QA 结果

- **独立 QA（ask 已知事实，QA 会话）**：Phase 5 独立 QA **P0=0、P1=0、minor=3**；§13 四条退出条件全部有实跑测试支撑；无阻塞，可收口。
- **报告员逐张目检（本轮实跑）**：4 张截图均为真实数据渲染（无白屏/无 mock 数据/无 tofu）；本地音乐页导入中态、下载页三态分组与计数、已完成真实封面与体积、失败态截断文案与重试列全部与 §5.10/§5.11 及代码内契约一致；D5 的「1.4MB/475.7KB」异常显示与「失败 · 音频…」截断在 failed.png 内直接可见（缺陷与证据同图，如实呈现）。

## 新增/关闭缺陷

**新增登记（全部开放；D 编号为 Phase 5 运行时验证发现序号，矩阵 ID 为全局编号）**：

| D | 矩阵 ID | 级别 | 问题 |
|---|---|---|---|
| D1 | **P1-16** | P1 | 导入方式选择 bottom sheet 流程触发 Flutter debug 断言 `_dependents.isEmpty`（framework.dart:6281）红屏 UI 死亡，3 个会话复现；widget 测试全绿但运行时主导入入口坏（入口触发点 local_music_page.dart:578 `showModalBottomSheet<_ImportChoice>`） |
| D2 | **P1-17** | P1 | 扫描取消后部分结果入库：点击取消后扫描停在 4888/20000 且 14900 首被提交+统计条显示部分值，违反代码内契约「取消：结果未提交+已取消横幅」（scanner.rs:150 协作式取消；widget 测试通过但运行时不符；不能排除点击与扫描结束竞态） |
| D3 | **P2-13** | P2 | 重试后损坏文件计「复用」而非重新解析失败（无法读取 1→0），与 E3「失败文件没有指纹记录、重扫必然重新解析」的登记语义相悖 |
| D4 | **P2-14** | P2 | 暂停在解析阶段打成失败：暂停按钮实点 3 次（解析阶段）→ 均变「失败」而非已暂停 |
| D5 | **P3-09** | P3 | 进行中下载行 560 宽 debug overflow 23px + 进度「1.4MB/475.7KB」已收大于声明总量的显示异常（音源大小不一致，failed.png 在图可见） |

- **关闭**：本阶段无既有矩阵缺陷项被修复关闭（无对应证据，如实登记）；Phase 1 退出条件表「本地音乐真实导入并播放」行更新为 Phase 5 桌面已验证（非缺陷项）；偏差 E1-E6 随登记维持。
- 环境注记：10k/20k 目录因 D1 崩溃无法经 UI 加入，改为关 app 后外部编辑 config.toml 加路径（已在报告如实声明；**测试后 config 已还原为 phase1 单路径**，报告员 cat 实测核实）；测试文件留在 /tmp/p5music-*（报告员实测 10000/20000 文件在位）；扫描入库的 30012 首留在本地曲库 DB。

## 未解决问题和原因

**未验证（如实披露，不因测试全绿改判）**：

1. **Android 真机项全部**：SAF `content://` URI 翻译 seam 实装、SAF 持久授权、系统 picker 真机行为、后台服务：无模拟器/JDK（P1-06 环境阻断），仅有 widget/seam 层测试证据（E1）。
2. **桌面 Xvfb 下系统 picker 本身不可用**（xdg-desktop-portal 缺失）：实跑的是 PlatformException 回退手输路径，系统 picker 真实对话框行为未验证。
3. **精确 390×844 视口截图**：窗口被 `main.dart:163` minimumSize 钳到 560 宽，实际交付 560×844；390 布局由 widget/golden 测试覆盖。
4. **离线播放严格验证**：`unshare -n` → Operation not permitted（沙箱禁用户命名空间），无法断网隔离；已验证下载文件磁盘有效（ffprobe m4a 342s / mp3+lrc）+ 删除对话框契约文案，**未验证播放器离线优先本地文件**。
5. **暂停→已暂停→继续运行时链路**：暂停点击 3 次均致任务失败（D4），下载阶段 <1.5s 无暂停窗口；「已暂停」态与继续按钮运行时未验证。
6. **下载失败原因完整文案**：UI 截断显示「失败 · 音频…」，未在 UI 内展开完整原因；磁盘侧观察到已收字节（1.4MB）大于声明总量（475.7KB）的音源大小不一致（D5 关联）。
7. **D1/D2 根因未定位**：D1 三个会话复现但未定位到具体 widget 树依赖（framework 断言点在框架层）；D2 不能排除点击与扫描结束竞态，复现步骤与影响面登记在矩阵。
8. **全量 flutter test / cargo test、cargo release 构建、浅色主题、手操清理**：按 ask 范围未跑（外部门禁统一执行/归 Phase 7）。
9. **30k 曲库启动 ≈30-40s** 为实测观察值，未做 profiling 归因（归 Phase 7 性能项）。

## 下一阶段进入条件

- §13 Phase 5 退出条件核对：
  - **导入结果持久化** ✅ 实跑（目录+曲目跨 3 次重启 10012→14900→30012）。
  - **重复扫描不重复入库** ✅ 实跑（指纹缓存复用 10006/4894/20006 多轮 + 失败重试后 30012 首不变）。
  - **失败可重试** ✅ 实跑（重试按钮真实重新入队，重扫语义 E3；D3 损坏文件复用缺陷登记在案）。
  - **重启后可播放**：持久化已实跑验证；QA 判定四条退出条件全部有实跑测试支撑（ask 已知事实转述）；本地曲目点击播放的运行时动作未在报告员侧独立复跑，如实披露。
- **Phase 6（DesktopShell 三栏重构）可进入**（QA 无阻塞判定）；但 **P1-16（D1 主导入入口运行时红屏崩溃）与 P1-17（D2 取消后部分结果入库）开放**，建议随 Phase 6/7 修复批次收口，Phase 6 期间复现 D1 时优先定位根因。
- Android 真机项 P1-06 维持（跨阶段披露）；浅色主题归 Phase 7；全量门禁与 release 重建随收口提交批次执行（本轮报告员不执行 git 提交）。

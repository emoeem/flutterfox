# SESSION-HANDOFF 2026-11-17 —— 第三轮 Batch G 后跨机器/跨会话交接

> **本文档取代 `SESSION-HANDOFF-2026-11-16.md` 成为唯一开工入口**（后者 §二 工具链陷阱仍有效并已并入本文 §二）。
> 交接时点：Batch G 已提交推送（`846bbfe`），工作区干净，下一批 = **Batch H（稳定性与崩溃诊断 §11）**。

## 一、开工指令（新会话第一个动作）

1. **仓库不在你的会话 workspace 里**。先定位（历史会话的 workspace 与仓库分离是常态）：
   ```bash
   ls /c/Users/emo/.zcode/workspace/draft-*/flutterfox
   # 当前真实位置：/c/Users/emo/.zcode/workspace/draft-449e2e92-5e43-4654-b96f-7f51130a0b14/flutterfox
   ```
   所有后续命令 `cd` 到该目录。若 draft-449e2e92 已被清理，用 `git log --oneline -1` 确认各候选目录 HEAD 是否为 `846bbfe`。
2. 确认基线：`git log --oneline -3` 应见 `846bbfe`（Batch G）→ `c065e6e`（Batch F）→ `293be01`（Batch E）；分支 `feat/ui-redesign`；draft PR #12。
3. 读本文 §二（工具链陷阱，**逐条照抄命令**）→ §四（Batch H 开工清单）→ 开工。
4. 每批纪律不变：**门禁全绿才提交；逐批单独 commit；推送走 HTTPS**；批次收尾写 `docs/reports/WORK_REPORT_<日期>_batch-<X>.md` + 04 矩阵更新行 + 更新本文。

## 二、关键环境陷阱（Windows 端必读，Batch G 后共 8 条）

1. **`flutter test` 单命令全仓模式本机挂起**（flutter-tester 进程级瞬时挂起，挂起集合逐轮漂移）。等效全量口径 = 逐文件顺序实跑 + 退出码判定 + 挂起文件重试 1-3 次（sweep 脚本模式见 Batch F/G 报告）；Linux CI 不受影响。
2. **Rust 用 gnu 宿主工具链**（`rustup default stable-x86_64-pc-windows-gnu`，规避 Git Bash `/usr/bin/link.exe` 遮蔽 MSVC 链接器）。cargo 命令前置：
   ```bash
   export PATH="/c/Users/emo/.zcode/workspace/toolchain-setup/mpv/libmpv-extract/libmpv-audio-x86_64-v0.41.0-1:/c/Users/emo/.zcode/workspace/toolchain-setup/w64devkit-extract/w64devkit/bin:/c/Users/emo/.cargo/bin:$PATH"
   export MPV_SOURCE="C:\\Users\\emo\\.zcode\\workspace\\toolchain-setup\\mpv\\mpv-source"
   ```
   （w64devkit 供 windres/MinGW 工具；libmpv-extract 供测试 exe 运行期 DLL，见条 6）
3. **cargo test/clippy 必带 `--features lx-player/build_libmpv`**——**单包 `-p <pkg>` 命令同样必带**（不带则 feature 指纹失效重链时报 `cannot find -lmpv`，易误判环境抖动）。
4. **Perl/sed 多行替换在 CRLF 文件不可靠**（本会话曾两次损坏）；跨行编辑一律 Read+Edit 工具。
5. **FRB codegen 已装机并打本地路径补丁**（2.13.0 Windows `\\?\` 前缀 bug，只修路径计算输出与 Linux CI 一致）。再生成：`flutter_rust_bridge_codegen generate`（ffi 与 flutter 两侧 frb_generated 均会更新，属预期）。
6. **测试 exe 需 libmpv-2.dll 在 PATH**（否则 `STATUS_DLL_NOT_FOUND` 0xc0000135）——条 2 的 PATH 已含；跑单测仍报缺就把 `libmpv-extract/libmpv-audio-x86_64-*/` 目录加 PATH。
7. **Windows GUI 真机运行链（Batch G 打通）**：
   - `flutter build windows --debug`（约 156s）→ `flutter/build/windows/x64/runner/Debug/voicefox_flutter.exe`；
   - **Rust FFI DLL 不随构建产出**：`cargo build -p voicefox-ffi --features voicefox-runtime/build-libmpv` 后把 `target/debug/voicefox_ffi.dll` **手工拷入 exe 目录**（运行时手工加载，非 native assets；改过 Rust 后忘记这步 = 启动报 `Failed to load dynamic library 'voicefox_ffi.dll'`）；
   - `libmpv-2.dll` 同样拷入 exe 目录（或 PATH）；
   - 启动：`./voicefox_flutter.exe > /tmp/voicefox_app.log 2>&1 &`（debug 版 print/debugPrint 全落日志）。
8. **CUA（界面自动化）驱动注意**（Batch G 实测）：Flutter a11y 树需**连续两次观察才激活**（激活后 38 元素含逐行内容与可编辑搜索框）；synthesized 点击对部分 widget **间歇失效**（搜索行双击可靠；PlayerBar 封面/顶栏图标可能无响应，重试或换行内 ▶ 路径）；**UIA 按标题栏按钮曾触发一次进程静默消失**（P1-05 素材，见 §五）——自动化会话里避免对标题栏按钮做 AXPress。

## 三、已完成内容（累计，勿重做）

| 批次 | commit | 内容 | 状态 |
| --- | --- | --- | --- |
| C-C | `4843d27` | C-04 歌单详情手机页 + C-08 曲库核验 + C-07 帮助页（SR-03 7/8） | ✅ |
| C-D | `566ed42` | C-06 Settings 手机分组 + padding 单源化（SR-03 8/8 收敛） | ✅ |
| D | `d3a0420` | SR-10/11/13/14/15 桌面五项 + 卡面死区真缺陷修复 + 交接文档入库 | ✅ |
| E | `293be01` | P3-09 下载状态行五处收口（§8.3） | ✅ |
| F | `c065e6e` | 队列协议三面收口（P2-09 关闭）+ media-session crate 提取 + GUI MPRIS 桥（cfg linux） | ✅ |
| **G** | **`846bbfe`** | **运行时闭环：P1-20/P2-16/P2-17/P2-18 四项关闭 + 换曲旧词污染实锤修复（state.lyrics 换曲清空 + 回归单测）+ P2-19/P2-20 新登记** | ✅ |

- 测试基线：cargo test 等效全绿 **859**（858 + lx-source Windows 夹具 3 例按登记口径单跑复归；lx-source `::` 临时目录夹具 3 例 + app visualizer 时序 flaky 为永久登记项，Linux CI 为准）；flutter test 逐文件 sweep **61 文件 508 全绿**（Batch F 口径）。
- 报告索引：`docs/reports/WORK_REPORT_2026-11-15_batch-c-c.md`（至 batch-d）、`WORK_REPORT_2026-11-16_batch-e.md`、`WORK_REPORT_2026-11-17_batch-f.md`、`WORK_REPORT_2026-11-17_batch-g.md`；运行时证据 `docs/redesign/screenshots/batch-g-winrt/`（28 帧）。

## 四、下一批：Batch H（稳定性与崩溃诊断，计划书 §11）

计划书要求（§11.1-11.3）：P0-01 主 isolate 概率性卡死、P1-05/P2-08 OpenGL timeout 后进程消失、故障恢复策略。**核心实验矩阵需 Linux niri/Wayland**（事件速率、30 分钟+长会话、休眠唤醒、GPU 路径核验）。

**Windows 会话可先行项（建议顺序）**：
1. **P2-19 修复**（小型，独立可收口）：搜索骨架态 713 高窗口底部溢出 143px——`search_page`/discover 共用骨架容器加视口高度约束；100% 复现路径 = 1136×713 窗口触发搜索；修复后补 widget 断言 + 关矩阵行。
2. **崩溃证据链（Batch H 纪律：禁止只加 try/catch 宣布解决）**：
   - 复现 Batch G 登记的静默退出单例（UIA AXPress 标题栏按钮 → 进程消失，无 panic 无 crash.log）——P1-05 类「引擎级无 unwind 不经 hook」路径；
   - 采集：Windows 事件查看器 Application 日志、WER 报告、`voicefox/crash.log`（%APPDATA%/voicefox/）有无、stdout 终态；
   - 区分：Rust panic（可 unwind→crash.log）vs SIGABRT/GL abort（不可 unwind→需外部 watchdog，crash_log.rs 模块注释已登记边界）。
3. **故障恢复审计（§11.3）**：音频引擎失效不得假 Playing / runtime 未启动不得假 Loading——读码核验 + widget 断言补强（`播放器拒绝播放请求` 已有错误链）。
4. **Linux 会话任务清单（若切 Linux 环境）**：§11.1 实验矩阵（空/1k/10k/30k 曲库 × 空闲/播放/切歌/搜索/下载组合 × 30min+ 长会话）、P2-04 窗口几何（niri/XWayland/XWayland Satellite）、**MPRIS 运行时验收**（Batch F 遗留：媒体键/Waybar/playerctl 全链）、lx-source 3 例夹具复归确认。

## 五、开放项与已知陷阱（增量，前交接 §五/§六 继续有效）

| 项 | 状态 | 备注 |
| --- | --- | --- |
| P0-01 主 isolate 卡死 | 开放 | Batch H 主战场，Linux 实验矩阵 |
| P1-05/P2-08 静默退出 | 开放 | 2026-11-17 新增 Windows 单例素材（UIA 触发，无 panic 无 crash.log）；crash_log.rs 覆盖边界已登记 |
| P1-06 Android 全链 | 开放 | 环境阻断（用户已搁置 Android 构建） |
| P2-04 窗口几何 | 开放 | niri/Wayland 专属，Linux 会话 |
| **P2-19 搜索骨架溢出** | **开放（新）** | Batch G 登记，Windows 可先行修复 |
| **P2-20 soda 发现面** | **开放（新）** | 服务端契约变更（P3 观察）；候选出路 = playlist 详情链路做曲目发现（需评估）；与 P2-16 封面链无关 |
| MPRIS 运行时验收 | 开放 | Batch F cfg-linux 代码待 Linux CI/会话首次编译+运行验证 |
| GUI SMTC / Now Playing | 开放 | media-session crate 已就绪，GUI Windows/macOS 接入为后续批次 |
| 结构化 FfiError | 开放 | FFI-R10 口径，全接口签名变更成本/收益独立评估 |
| lx-source 3 例 + visualizer flaky | 永久登记 | Windows 夹具限制，Linux CI 为准，夹具不改不削弱 |

## 六、Git 纪律（不变）

- 逐批单独 commit；message 用仓库根 `toolchain-setup/commit-message-*.txt` 同款长消息风格（要点 + 实测数据 + 如实登记段落）。
- 推送 HTTPS（`git push origin feat/ui-redesign`）；draft PR #12 上每批一个 CI run，红 job 把日志贴回会话。
- **提交前门禁**（照抄）：cargo fmt --check 0 / clippy `-D warnings` exit 0 / cargo test --workspace --no-fail-fast（lx-source 3+网络抖动口径）/ dart analyze 0 / dart format lib test 0 / flutter test 逐文件 sweep。
- 文档随批入库：工作报告 + 04 矩阵更新行 + 本交接文档更新。

## 七、快速恢复现场（新会话 5 分钟热身）

```bash
REPO=/c/Users/emo/.zcode/workspace/draft-449e2e92-5e43-4654-b96f-7f51130a0b14/flutterfox
cd $REPO && git log --oneline -3 && git status --short   # 应干净，HEAD=846bbfe
export PATH="/c/Users/emo/.zcode/workspace/toolchain-setup/mpv/libmpv-extract/libmpv-audio-x86_64-v0.41.0-1:/c/Users/emo/.zcode/workspace/toolchain-setup/w64devkit-extract/w64devkit/bin:/c/Users/emo/.cargo/bin:$PATH"
export MPV_SOURCE="C:\\Users\\emo\\.zcode\\workspace\\toolchain-setup\\mpv\\mpv-source"
cargo test -p voicefox-application --lib lyrics --features lx-player/build_libmpv   # 3 passed = 现场恢复
# GUI 真机（可选）：
cargo build -p voicefox-ffi --features voicefox-runtime/build-libmpv && cp target/debug/voicefox_ffi.dll flutter/build/windows/x64/runner/Debug/
cd flutter && flutter build windows --debug && cd ../  # exe 目录补 libmpv-2.dll（已存在则跳过）
```

## 八、2026-11-18 自主执行会话增量（CI 修复批次，覆盖 §一 开工路径）

- **工作区已迁移**：本轮在 `/c/Users/emo/.zcode/workspace/draft-979e508e-b821-4fe4-a04a-14e8efb1f4c7/flutterfox`
  重新检出（feat/ui-redesign @ `1e0ea54` 起）。draft-449e2e92 旧检出核实干净、与 origin 同步后**保持只读**；
  新会话应以 `git log --oneline -1` 对照各 draft-* 目录取最新检出，不再假设 449e2e92 有效。
- **§二.5 FRB codegen 机制修正**：FRB 2.13 把 `cargo expand` 当**硬依赖**——cargo-expand 存在但 expand
  失败时 generate 直接 `Error: cargo expand returned empty output` 退出（binary 完全缺失才是 WARN 降级）。
  expand 需要 `-Zunpretty`（nightly-only），官方 stable 逃逸 = **`RUSTC_BOOTSTRAP=1`**（本机实测 exit 0）。
  再生成完整口径：`export RUSTC_BOOTSTRAP=1 flutter_rust_bridge_codegen generate && cargo fmt --all`。
  CI codegen job 已同步此路径（cargo-expand 1.0.127 + 环境变量，不装 nightly）。本轮曾装
  nightly 1.102.0 仅作排查，未用于任何门禁。
- **CI 两根因已修**（详见 `docs/reports/WORK_REPORT_2026-11-18_batch-ci-fix.md`）：
  media-session Cargo.toml 补 `anyhow.workspace = true`（cfg(linux) 遮蔽问题，Windows 本机门禁看不到它）；
  codegen job 装 cargo-expand + RUSTC_BOOTSTRAP=1 + 删重复一致性检查步骤。
- **新增 `docs/flutterfox/`**：OWNERSHIP_AND_BOUNDARIES / AUTONOMOUS_EXECUTION_STATUS / KNOWN_LIMITATIONS
  （自主执行合同 §12 交付物，F0 基线冻结产物）。

## 九、2026-11-18 轮次收口（唯一开工入口更新）

- **本轮交付链（全部已推送，CI 全绿）**：`829c3d1`→`1429c74`→`8f59048`→`c31c275`→`147f15d`→`74abcb7`→`d8a6c44`→`42ac321`。
- **开工入口改为 `docs/flutterfox/FINAL_ACCEPTANCE_REPORT.md`**（§8 移交清单 = 下一会话任务清单）：
  RT-02 余项/RT-07/RT-12 UI 计数/RT-14/RT-20 交互式 soak/SMTC 媒体键注入待补（原因 = 本会话 CUA
  被执行者 stop() 误终止 + engine a11y/输入管线环境性退化，见报告 §6）；P0-W1 engine 根因调查。
- **新增开放缺陷 P0-W1**（Windows 冷启动首帧白屏）：规避已入库（main.dart 1px 尺寸往返），
  engine 层根因未定位；素材链见 04 矩阵 2026-11-18 行 + FINAL_ACCEPTANCE_REPORT §3。
- **P2-19 已关闭**（tracksFitted + 真机实证）；**GUI Windows SMTC 已接入**（媒体键运行时验证留待
  新 CUA 会话）；**FRB 再生成口径 = `RUSTC_BOOTSTRAP=1 flutter_rust_bridge_codegen generate && cargo fmt --all`**。
- 测试 profile 恢复：%APPDATA%/voicefox/config/config.toml 已还原至本轮前备份
  （`$TEMP/config.toml.bak-h1`）；library10k 注入路径已移除；合成媒体留在
  `%TEMP%/flutterfox-test-media/`（TEMP 生命周期，可重生成：脚本思路见报告 §8/§4）。


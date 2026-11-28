# WORK REPORT — Batch H1:CI 门禁恢复收尾 + P2-19 + GUI SMTC 接入(2026-11-18)

> 上游:执行合同 §4(F1 收尾)/§6(F3)/§9(F6 前置)· 交接文档 §四(Batch H Windows 先行项)
> 基线:feat/ui-redesign @ `1e0ea54` → 本批至 `c31c275` + TUI shim 修复提交。
> 执行者:ZCode 自主执行会话(合同 §15 直接执行模式)。

## 1. 批次内容与提交

| 提交 | 内容 |
| --- | --- |
| `829c3d1` fix(ci) | media-session 补 anyhow(cfg linux 遮蔽)、codegen job 装 cargo-expand 1.0.127 + RUSTC_BOOTSTRAP=1、删重复检查步骤;F0 基线文档入库(详见 WORK_REPORT_2026-11-18_batch-ci-fix.md) |
| `1429c74` fix(mpris) | media_bridge(时名 mpris_bridge)补 ApplicationService 的 cfg(linux) 导入(Linux CI E0425 ×5) |
| `8f59048` fix(ui) | **P2-19 关闭(widget 层)**:VxLoadingSkeleton.tracksFitted 视口自适应 + search_page 接入 + 5 回归用例 |
| `c31c275` feat(media) | **GUI Windows SMTC 接入**:media-session 新增 smtc.rs(TUI 原样移植)、media_bridge 跨平台泛化(git mv + cfg any)、media_session_enabled 开关、ffi new_desktop 接线 |
| TUI shim 修复 | app: translate_event/channel 平台门控 + `::media_session::mpris::start()` 直连 + 删除无用 mpris shim(Linux 首次编译暴露的 4 错,E0432/E0425/unused ×2) |

## 2. CI 逐轮根因链(全部实证修复,非猜改)

| 轮次 | run | 结果 | 新暴露根因 → 修复 |
| --- | --- | --- | --- |
| 0(接手时) | 43934529292 | 3 job 失败 | anyhow E0433(Linux only)+ cargo-expand 缺失 + 步骤重复 |
| 1 | 44124069630 | 同 3 job 失败 | **第一层洋葱**:application mpris_bridge Linux 段缺 ApplicationService 导入(E0425 ×5)→ cfg 门控导入 |
| 2 | 44128343103 | codegen ✓ analyze/test ✓ app 编译到达 | **第二层**:application 编译通过后 clippy 首见 run_command_loop single_match → let-chain 收拢(随 SMTC 批推送) |
| 3 | 44131584156 | codegen ✓ Windows ✓ Android ✓ **app 编译到达** | **第三层**:voicefox-app(TUI)Linux shim 从未被编译——shim 无条件 re-export cfg(windows,macos) 的 translate_event/channel(E0432 configured-out)级联毒化 crate::media_session 与 mpris shim(E0425 + unused ×2)→ 平台门控 + 直连 + 删 shim |
| 4 | (本轮) | 待观察 | 预期:Lint/Build Linux 收绿;TUI Linux 面其余为 Batch E 已验证面 |

**关键中间胜利**:FRB codegen consistency 自 Batch F 起首次转绿(44128343103 起)——
cargo-expand + RUSTC_BOOTSTRAP=1 与本地补丁版 FRB 2.13 同路径,生成物与提交版零 diff,
「生成物与手写 API 同步」门禁恢复有效。

## 3. P2-19(搜索骨架溢出,合同 §1.2 / 交接 §四.1)

- 根因:`VxLoadingSkeleton.tracks(rows: 8)` 固定 520px Column 在 Expanded 视口内不裁切不收缩
  (1136×713 下 Expanded ≈450px → 143px 溢出,100% 复现)。
- 修复:组件级 `tracksFitted` 变体(行数按约束高度拟合,度量单源在组件;无界退化固定行数),
  search_page 加载分支接入。既有 `tracks` 形态零变化。
- 测试(本会话实跑):`test/vx_loading_skeleton_test.dart` 5/5(A/B 对照锁定:紧视口下旧行为
  必须仍溢出 + 新行为干净;拟合数契约 443→6/713→8/120→1;无界退化 5 行)。
- 回归:骨架消费面 7 测试文件 75 passed 0 failed;dart analyze 0;dart format 0 changed。
- **如实登记**:1136×713 真机复测归 F4 五尺寸走查(widget 层证据先行,不冒充实机)。

## 4. GUI Windows SMTC 接入(合同 §5.1 系统媒体集成;交接开放项「GUI SMTC」)

- media-session crate 补齐 Windows 后端:smtc.rs 自 TUI app/src/smtc.rs 原样移植
  (souvlaki + 隐藏顶层窗口 + 50ms 消息泵;快照差异比对分离 metadata/playback)。
- media_bridge(mpris_bridge.rs → media_bridge.rs)运行时接线泛化 any(linux, windows):
  spawn_media_session_bridge / start_backend(平台分派 mpris::start() async 与
  smtc::start() 同步);纯逻辑段与 19 单测零变化。
- 开关:service.rs `media_session_enabled()`——Linux 读 integration.mpris、
  Windows 读 integration.smtc(与 TUI start_media_controls 同源);ffi new_desktop
  cfg(any(linux, windows)) 接线。
- 实测(Windows 本会话实跑):clippy 三 crate exit 0;cargo test 103 passed 0 failed
  (media-session 2 + application 101 含 bridge 19);cargo fmt 0。
- **如实登记**:SMTC 运行时行为(媒体键/系统浮层)归 F7 实机以媒体键注入验证;
  macOS GUI Now Playing 未接入(无可验证平台,不冒充);TUI 侧 SMTC 原有实现零改动。

## 5. 工具链新陷阱(交接文档 §二 增量,已在 SESSION-HANDOFF §八登记)

- **FRB generate 把 cargo expand 当硬依赖**(binary 缺失才 WARN 降级;存在但失败即
  exit 1)。expand 需 nightly `-Zunpretty`;stable 逃逸 = `RUSTC_BOOTSTRAP=1`
  (cargo-expand 官方口径,本机实测 exit 0)。再生成完整口径:
  `export RUSTC_BOOTSTRAP=1 flutter_rust_bridge_codegen generate && cargo fmt --all`。
- **cfg(linux) 面的三层洋葱**:Batch F/G 的 Linux-only 代码(anyhow 声明、bridge 导入、
  TUI shim)全部只在 Windows 门禁下开发,CI 首次编译逐层暴露;修复口径 =
  与 application crate 已验证路径同构 + 平台门控与 crate 侧一致。
- 本机排查时装 nightly 1.102.0(未用于任何门禁/产物)。

## 6. 门禁实录(本批收口时点)

| 门禁 | 结果 |
| --- | --- |
| cargo fmt --all -- --check | exit 0 |
| cargo clippy(workspace CI 同款参数,Windows + build_libmpv) | exit 0(含新 smtc/bridge 面) |
| cargo test -p media-session -p voicefox-application --lib | 103 passed 0 failed |
| cargo clippy -p voicefox-app --all-targets(TUI shim 修复后) | exit 0 |
| flutter analyze --fatal-infos / dart format lib test | 0 / 0 changed |
| flutter test 定向(vx_loading_skeleton + 消费面 7 文件) | 5/5 + 75/75 |
| GitHub Actions | 待 run 44131584156 系列结论(见状态文件增量) |

未复跑项(沿用同代码基线,如实登记):cargo test --workspace 全量(858 基线;
Linux 侧由 CI 实跑验证)、flutter test 全量逐文件 sweep(本批 Dart 改动面已定向覆盖,
全量 sweep 归 F7 收口批)。

## 7. 移交与下一批

- F4/F7 实机测试环境:GUI debug 构建 + voicefox_ffi.dll 装配(本批构建)、
  合成媒体(%TEMP%\flutterfox-test-media:few 4 文件 + CUE + library10k 10k 文件)。
- 下一步:五尺寸实机走查(F4)→ RT-01…RT-20(F7)→ 稳定性取证(F5)。

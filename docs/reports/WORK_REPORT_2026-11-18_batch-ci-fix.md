# WORK REPORT — Batch CI-Fix(2026-11-18)

> 上游:执行合同 §4(F1 CI/构建链路修复)· 交接文档 SESSION-HANDOFF-2026-11-17(§五:CI 门禁失败)
> 本批性质:**纯构建链路修复,零业务代码变更**。执行者:ZCode 自主执行会话(合同 §15 直接执行模式)。

## 1. 基线与执行环境

- 工作区:`C:/Users/emo/.zcode/workspace/draft-979e508e-b821-4fe4-a04a-14e8efb1f4c7/flutterfox`
  (新检出:本地克隆自上一会话 draft-449e2e92 检出 @ `1e0ea54`,origin 指回 GitHub;旧检出核实为干净且与 origin 同步,保持只读)。
- 分支 `feat/ui-redesign`,基线 HEAD `1e0ea54`(Batch G `846bbfe` + 交接文档提交),工作区干净。
- PR #12 OPEN/Draft;最近两次 CI run(43934529292 @1e0ea54、43933600436 @846bbfe)失败,43907256341(@293be01)成功。
- 工具链:Flutter 3.47.9 / Dart 3.13.7 / rustc 1.100.0 stable-gnu(默认)/ FRB codegen 2.13.0(本地路径补丁)/ cargo-expand 1.0.127;
  本轮新装 nightly 1.102.0-nightly(2026-11-16,最终未采用,见 §3)。

## 2. CI 失败根因(逐条实证,非沿用历史结论)

| # | 失败 job | 根因 | 证据 |
| --- | --- | --- | --- |
| 1 | Build Linux x86_64(Build)、Lint(Clippy (zero warnings)) | `media-session/src/mpris.rs:17` 使用 `anyhow::Result`,但 `media-session/Cargo.toml` 未声明 anyhow → `error[E0433]: cannot find module or crate anyhow`;workspace 级 clippy/build 在 Linux 必然编译该 crate | run 43934529292 失败日志 + 源码核实:`lib.rs` 中 `pub mod mpris` 为 `#[cfg(target_os = "linux")]`——Windows 本机门禁不编译该模块,构成本机绿/CI 红的结构性遮蔽 |
| 2 | FRB codegen consistency(Regenerate bindings) | job 内 FRB generate 内部调用 `cargo expand`,CI 未安装 cargo-expand(`no such command: expand`);随后 ffi 依赖 media-session 编译同样命中根因 1 的 E0433 | run 43934529292 失败日志;本机复现:`cargo expand` 在无 nightly 的 stable 上必败(`error: the option Z is only accepted on the nightly compiler`) |
| 3 | FRB codegen consistency | `ci.yml` codegen job 中「Check generated files are up to date」步骤**重复定义两次**(原 L74-92) | 源码核实 |

## 3. 修复内容与本机验证

### 3.1 media-session 补 anyhow 声明

- `media-session/Cargo.toml`:`[target.'cfg(target_os = "linux")'.dependencies]` 增加 `anyhow.workspace = true`(workspace 根已有 `anyhow = "1"` 统一版本;依赖与消费方同在 cfg(linux) 面,不引入 Windows/macOS 侧多余依赖边)。
- `Cargo.lock` 同步(media-session dependencies 增加 `"anyhow"`,diff 1 行)。

### 3.2 codegen job:cargo-expand + RUSTC_BOOTSTRAP=1(与本地同路径)

- 关键实证:**FRB 2.13 的 `generate` 把 `cargo expand` 当硬依赖**(cargo-expand 存在但 expand 失败 → `Error: cargo expand returned empty output`,generate exit 1;binary 完全缺失时才降级为 WARN 并继续)。
- cargo-expand 需要 nightly 才能跑 `-Zunpretty=expanded`;其官方记载的 stable 逃逸 = `RUSTC_BOOTSTRAP=1`。本机实测:`RUSTC_BOOTSTRAP=1 cargo expand --lib` exit 0(395KB 展开输出,47.7s);**不装 nightly**,避免 CI 与本地工具链漂移。
- ci.yml:codegen job 增加 `Install cargo-expand`(固定 1.0.127 --locked)+ `Regenerate bindings` 步骤加 `RUSTC_BOOTSTRAP: "1"` 环境变量;删除重复的一致性检查步骤(保留一份)。
- 环境增量登记:本机曾装 nightly 1.102.0(排查过程中安装,未用于任何门禁/产物;cargo-expand 走 stable+bootstrap 路径)。

### 3.3 codegen 零 diff 验证(本地全路径)

`flutter_rust_bridge_codegen generate`(RUSTC_BOOTSTRAP=1)→ exit 0 → `cargo fmt --all` → `git diff` 全部生成物
(ffi/src/frb_generated.rs + flutter/lib/src/bridge/*.dart)**与提交版零内容差异**。提交版绑定与
「补丁版 FRB 2.13.0 + stable-gnu 1.100 + RUSTC_BOOTSTRAP 展开 + cargo fmt」路径一致;CI Linux 侧
稳定工具链展开在 Batch E 曾达成零 diff(同管道),本批生成面无手写 API 变更,预期 CI 同绿。

### 3.4 本机门禁(Windows,交接文档 §二 口径)

| 门禁 | 结果 |
| --- | --- |
| `cargo fmt --all -- --check` | exit 0 |
| `cargo clippy --workspace --all-targets --features lx-player/build_libmpv -- -D warnings -A clippy::double_must_use` | exit 0(voicefox-application manifest 级 unused-deps 1 条预存警告,Batch F 已登记) |
| `flutter analyze --fatal-infos`(3.47.9) | exit 0(No issues found) |
| `dart format --output=none --set-exit-if-changed lib test` | 274 files 0 changed,exit 0 |
| 现场恢复热身 `cargo test -p voicefox-application --lib lyrics --features lx-player/build_libmpv` | 3 passed |

未在本机复跑项(如实登记):`cargo test --workspace` 全量(本批 Rust 零代码变更,基线 858 passed 沿用
Batch G 同代码实跑结果;Linux 侧 anyhow 编译由 CI 直接验证——这正是本根因只有 Linux 能暴露的部分)、
flutter test 逐文件 sweep(本批 Dart 零变更)。

## 4. 提交与 CI 观察

- 提交:`fix(ci): media-session 补 anyhow 声明 + codegen job 装 cargo-expand(RUSTC_BOOTSTRAP=1)+ 删重复检查步骤`
- 推送后 run URL:**(推送后由 AUTONOMOUS_EXECUTION_STATUS.md 增量登记)**
- 预期:8/8 job 全绿(Build Linux/Windows/macOS×2/Android、Lint、Flutter analyze/test、FRB codegen)。

## 5. 剩余风险与移交

- `docs/flutterfox/`(OWNERSHIP_AND_BOUNDARIES / AUTONOMOUS_EXECUTION_STATUS / KNOWN_LIMITATIONS)随本批入库,F0 基线冻结完成。
- 下一批 = 合同 F2(功能盘点)→ Batch H 主线(P2-19 修复为 Windows 先行项)。

# FlutterFox 所有权与边界表(OWNERSHIP_AND_BOUNDARIES)

> 建立依据:合同 §3.3。现场归属判定基于:仓库文件树(feat/ui-redesign @ `1e0ea54`)、
> `docs/SESSION-HANDOFF-2026-11-17.md` 各批次改动记录、`.github/workflows/ci.yml` 构建目标、
> 以及各 crate `Cargo.toml` 的依赖与用途。判定原则:**能证明被此前 FlutterFox 批次直接修改过的层
> 按既定模式处理;无法证明归属的默认只读。**

## 分层判定

| 目录/crate | 内容 | 归属判定 | 本轮处理 |
| --- | --- | --- | --- |
| `flutter/` | FlutterFox GUI(lib 213 文件 + test 61 文件,windows/android/macos/linux 壳) | FlutterFox 自有 UI 层 | **可修改**(主战场) |
| `flutter/lib/src/bridge` | FRB 生成物 | 生成物,禁止手工编辑 | 只能经 `flutter_rust_bridge_codegen generate` 再生成 |
| `ffi/` | FFI 桥(voicefox_ffi cdylib、crash_log、`#[cfg(linux)]` 装配) | FlutterFox 与后端的接口边界层;Batch F/G 均直接修改过 | **可修改**,API 变更必须同批 FRB 再生成 |
| `media-session/` | Batch F 提取的媒体会话 crate(纯数据层 + `#[cfg(linux)]` mpris + souvlaki) | FlutterFox GUI 的媒体集成层(Batch F 为 GUI 新建) | **可修改**(当前 CI 根因之一在此 manifest) |
| `application/` | 应用服务层(service.rs 搜索/播放/歌词/队列编排、mpris_bridge) | GUI 命令执行层;Batch D/E/F/G 均按 GUI 需求最小修改 | **谨慎可修改**:跟随既有批次模式,只做 GUI 所需最小变更,不动 TUI 专属业务 |
| `core/` `source/` `lyric/` `download/` `runtime/` `player/` | VoiceFox 后端 crates(音源聚合、歌词、下载、播放引擎) | VoiceFox 业务后端 | **默认只读**;仅构建门禁类修复(依赖声明)允许 |
| `app/` | VoiceFox TUI(ratatui) | VoiceFox TUI,其他开发者维护 | **只读**;仅 lint 级最小修复(先例:Batch C-C notification.rs let-chain) |
| `test/` | workspace 测试 crate | 共享测试设施 | 只读 |
| `docs/` | 设计/交接/缺陷矩阵/报告 | 文档 | 可新增 `docs/flutterfox/*`、`docs/reports/*`;改既有文档需同步口径 |
| `site/` `packaging/` `icons/` `scripts/` `.github/` | 官网/打包/图标/脚本/CI | 辅助设施 | CI 修复(`.github/workflows/ci.yml`)属合同 F1 范围,可修改;其余只读 |
| `Cargo.toml`(workspace 根) | workspace 成员与统一依赖 | 构建基础设施 | 可修改(仅依赖声明类) |

## 硬边界(合同 §0.1 落地)

1. **不接管 VoiceFox TUI(`app/`)与后端 crates 的功能开发**;只通过 `ffi/` 接口消费。
2. **musid-dli 是音源聚合库,不是音频解码/播放引擎**;播放引擎边界在 `player/`/`libmpv2`,本轮不替换。
3. GUI 对媒体会话(Windows SMTC/macOS Now Playing/Linux MPRIS)的消费统一走 `media-session` crate,
   GUI 侧接入是后续批次范围(media-session 已就绪,接入未完成,登记开放)。
4. FRB 生成文件(`ffi/src/frb_generated.rs`、`flutter/lib/src/bridge`)手工编辑禁止;
   手写 API 变更必须同批再生成并提交(CI codegen-check 门禁)。
5. VoiceFox 独立仓库(`emoeem/voicefox` 等)不在本轮范围,不做任何操作。

## 与旧交接工作区的关系

`/c/Users/emo/.zcode/workspace/draft-449e2e92-5e43-4654-b96f-7f51130a0b14/flutterfox` 为上一会话的
检出(HEAD `1e0ea54`,干净、与 origin 同步,已核实无未推送工作)。本轮在
`/c/Users/emo/.zcode/workspace/draft-979e508e-b821-4fe4-a04a-14e8efb1f4c7/flutterfox` 建立新检出
(本地克隆自旧检出 + origin 指回 GitHub),旧工作区**保持只读不动**。

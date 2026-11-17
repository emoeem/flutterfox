# 工作报告：Batch E（下载可靠性 §8：P3-09 收口 + §8.3 桌面下载状态行字节口径与失败详情）

> 日期：2026-11-17 · 执行环境：Windows 10（Git Bash）· 分支 feat/ui-redesign · 基线 HEAD `d3a0420`（Batch D 提交）
> 上游：计划书 §8 + 04 矩阵 P3-09（Phase 5 运行时登记 D5）· UI 唯一规格 §5.11/§8.3

## 基线

- 分支/HEAD：feat/ui-redesign @ `d3a0420`，工作区干净（仅本批改动）。
- Flutter 3.47.9 / Dart 3.13.7 / rustc 1.100.0（gnu）/ FRB 2.13.0。
- Rust 面：**零改动**（§8.2 审计结论：既有机制已覆盖计划书要求，见下）。

## 审计结论（Step 1-2，§8.2 Rust 引擎逐项）

| §8.2 要求 | 审计判定 | 证据 |
|---|---|---|
| 总量来源（Content-Length/Range/元数据/文件系统） | **已实现且口径正确**：探测 HEAD 失败回退 `Range: bytes=0-0` 从 Content-Range 取总量+分片能力；`probe.total.or(req.expected_size)` 服务器声明优先于元数据 | engine.rs:476-521/369-383 |
| downloaded/expected/verified 区分 | **已区分**：`ProgressSnapshot{downloaded,total}` + `ratio()` clamp 0..1（Rust 侧不会产生 >100% 比率）；完成经临时文件原子改名（Phase 5 ffprobe 实证） | engine.rs:138-151/311-322 |
| 错误 Content-Length/压缩/分片 | 分片（`download_chunked`）与单流按探测能力选择；超限守卫（limit）在位 | engine.rs:369-383 |
| 状态机/终态约束 | pause 接受四活跃态 + Paused 短路迟到结果（P2-14 已修+测试）；取消不提交（P1-17 已修+测试）；失败重扫（P2-13 已修+测试） | manager.rs + 04 矩阵 2026-11-14 行 |
| 迟到进度事件 | Paused 短路 + 任务代次隔离（E5 wire 词汇表已修） | download/src/manager.rs:642-659（04 矩阵 P2-14 行） |
| 结构化错误 | task.error 字符串直传（**维持开放**：结构化 FfiError 全接口签名变更，Batch A 已登记成本/收益待评估，FFI-R10 同口径） | ffi/src/lib.rs |
| 跨会话恢复 | 计划既定不做（E4 登记维持） | 04 矩阵 Phase 5 偏差节 |

结论：**Rust 零改动**——P3-09 的三处现象全部为 Dart 呈现层缺口（见下）。

## P3-09 病灶定位（Dart 呈现层）

| 现象 | 病灶 | 证据（HEAD d3a0420） |
|---|---|---|
| 百分比可超 100% | `downloads_page.dart` `'${downloaded * 100 ~/ total}%'` 未夹取（Rust ratio 已夹取但 Dart 直除原始字节） | downloads_page.dart:472 |
| `1.4MB/475.7KB` 显示异常 | 字节如实直出本身符合 §8.3「不篡改」，但缺「服务器总量信息不一致」说明，用户无法理解异常 | downloads_page.dart:446-448 |
| 总量未知不显已下载 | `hasProgress = total > 0`，total==0 时体积行整行隐藏（§8.3 要求显示已下载） | 同上 |
| 560 窄窗 overflow 23px | 状态行 Row 内百分比/速度 Text 非 Flexible | downloads_page.dart:469-486（旧行号） |
| 失败原因截断「失败 · 音频…」 | 行内 Flexible+ellipsis 截断，完整原因（task.error）无展开出口 | downloads_page.dart:455-468 |

## 修改清单

| 文件 | 修改 | 根因 / 必要性 |
|---|---|---|
| `flutter/lib/src/pages/downloads_page.dart` | ① 百分比 `((downloaded*100)~/total).clamp(0,100)`；② `totalMismatch = downloaded > total` 时体积行附「（服务器总量信息不一致）」错误色说明（原始字节如实不动）；③ 总量未知显示「已下载 X」（无虚假总量/百分比）；④ 失败行点按 → `_showFailureDetails` 对话框（完整原因 SelectableText + 复制按钮，§8.3「可展开/复制」）；⑤ 状态行百分比/速度 Flexible 化（560 overflow 收口）；⑥ +services import（Clipboard） | §8.3 桌面呈现收口；移动页（C-B）已同口径（字节 clamp+原样+原因折叠）无需改 |
| `flutter/test/phase5_downloads_test.dart` | +5 用例：百分比封顶 100（>100% 回归）/ 总量不一致说明+原始字节如实 / 总量未知显已下载无虚假量 / 失败详情对话框（完整文本不截断+复制+关闭）/ 560 窄窗无溢出回归 | §8.4 测试矩阵 |

## 契约 / 行为变化

- Rust API / DTO / Command / Event：无。
- Dart：下载页状态行呈现逻辑（clamp/说明/未知总量/失败详情对话框）；无 API 变化。
- 平台行为：桌面下载页窄窗（560）不再溢出；失败原因可达（点按→详情+复制）。
- 兼容策略：纯呈现层，无接口变化。

## 验证

| 命令 / 操作 | 平台与环境 | 退出码 | 通过 / 失败 | 备注 |
|---|---|---:|---|---|
| `flutter analyze --fatal-infos` | Windows / Flutter 3.47.9 | 0 | No issues found | 全仓 |
| `dart format --output=none --set-exit-if-changed lib test` | 同上 | 0 | 274 files 0 changed | |
| `flutter test test/phase5_downloads_test.dart` | 同上 | 0 | **23/23**（基线 18 + 本批 5） | 含 P3-09 五项回归 |
| `flutter test` 逐文件 sweep（退出码判定） | 同上 | 0 | **506 passed / 0 failed（62 文件全绿）** | 基线 501（Batch D）+ phase5_downloads 5（基线 18→23 含既有用例计数随断言微调浮动） |
| cargo fmt / clippy / test | Windows / rustc 1.100.0 gnu | 0 / 0 / — | 沿用 Batch C 实跑（本批 Rust 零改动） | |

**如实登记**：
- §8.4「真实下载运行证据」维持 Phase 5 登记（真实联网下载 + ffprobe 已实证；本批为呈现层，无需重跑）。
- 560 窄窗 widget 层无溢出 ≠ 桌面运行时截图（Linux 运行时项维持口径）。
- 结构化 FfiError 维持开放（FFI-R10 同口径，全接口签名变更成本/收益留独立评估）。
- `flutter test` 单命令全仓模式本机抖动口径维持（逐文件实跑为等效全量）。

## 缺陷矩阵更新

- **P3-09 关闭**（五处现象全收口：>100% 百分比 / 字节倒挂说明 / 总量未知已下载 / 560 overflow / 失败原因展开+复制；Phase 5 登记的运行时证据 + 本批 widget 层回归双覆盖）。
- 其余矩阵项无状态变化（P2-13/P2-14/E1-E5 维持既有登记）。

## Git 状态

- 修改：2 个文件（downloads_page.dart + phase5_downloads_test.dart）。
- 是否提交：**待用户授权**（§0.4.9）。是否推送：**待用户授权**。

## 下一批次建议

- Batch F（§9）：队列排序协议（QueueMove/QueueInsertNext/QueuePlayAt 业务命令——**首次跨 Rust/FFI/Dart 面改动**，需 FRB codegen 本机就绪）+ Linux MPRIS（Rust 实装，Windows 只能实现与单测、运行时留 Linux）——建议在 Linux 会话或用户明确授权后推进。
- 工具链备注：FRB codegen 本机未安装（HANDOFF-2026-11-16 §二陷阱 5）。

# docs 索引

> 本目录文档遵循 /home/emo/code/telegram-bot/docs/DOC-STANDARD.md 的写作与维护标准（数字实测、讲为什么、坏消息单列）。

## 目录归属

| 目录 | 内容 | 什么时候看 |
| --- | --- | --- |
| `reports/` | 一轮工作的实测报告（WORK_REPORT_YYYY-MM-DD_主题.md） | 想知道某一轮干了什么、门禁数字、遗留问题 |
| `redesign/` | 全平台 UI/UX 重构执行产物：`VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md`（唯一契约，§17 追踪表随跑更新）、`00…04-*.md`（基线/研究/许可证/复用映射/缺陷矩阵）、`phase-N-report.md`（阶段报告）、`screenshots/`（视口矩阵截图）、`second-round/`（第二轮盘点与报告） | 想知道重构进展、规格依据、缺陷状态 |
| `architecture/` | 跨语言架构契约文档：`ffi-contract-inventory.md`（FFI 接口/DTO/流清单+测试矩阵）、`ffi-reliability-design.md`（R01-R12 风险判定与加固设计） | 想知道 Rust/Dart 边界契约、FFI 风险状态 |
| 根级历史文档 | `SESSION-HANDOFF.md`（跨会话交接）、`flutter_ui_spec.md`（旧 UI 规格 v3，部分已被重构指南取代）、`PHASE*-REPORT.md`（上一轮桌面重构的阶段报告）、`USER_GUIDE.md` / `CONFIGURATION.md` / `SYNC.md`（产品手册） | 交接与产品功能 |

## 文档清单

- [SESSION-HANDOFF-2026-11-14.md](SESSION-HANDOFF-2026-11-14.md): 跨机器交接（Windows 端继续第三轮工程演进：当前状态/任务队列/环境命令/开工指令）
- [redesign/second-round/PLAN-rust-ffi-and-ui-evolution.md](redesign/second-round/PLAN-rust-ffi-and-ui-evolution.md): 第三轮《跨平台工程演进计划书》仓内副本（Batch A-I 全量任务书）

- [reports/WORK_REPORT_2026-11-14_second-round-baseline-review.md](reports/WORK_REPORT_2026-11-14_second-round-baseline-review.md): 第三轮工程演进 Phase 0 基线复核 + Batch A 只读审计报告（SR-11 裁决 + FFI-R 登记入口）
- [architecture/ffi-contract-inventory.md](architecture/ffi-contract-inventory.md): FFI 契约与调用链清单（24 API/24 DTO/60 命令变体/双流/测试矩阵）
- [architecture/ffi-reliability-design.md](architecture/ffi-reliability-design.md): FFI 可靠性风险判定与加固设计（R01-R12 判定+18 项最小修复候选+三批实施建议）
- [reports/WORK_REPORT_2026-11-14_second-round-phase0.md](reports/WORK_REPORT_2026-11-14_second-round-phase0.md): 第二轮 UI/UX 重构 Phase 0 只读审计实测报告（CI 根因+HEAD 测试红面+WIP 批次核验）
- [redesign/second-round/01-implementation-audit.md](redesign/second-round/01-implementation-audit.md): 第二轮实现盘点与差距审计（逐页矩阵 + SR-01..18 新差距登记）
- [redesign/second-round/baseline/BASELINE-MANIFEST.md](redesign/second-round/baseline/BASELINE-MANIFEST.md): 第二轮基线截图证据集清单
- [reports/WORK_REPORT_2026-11-11_redesign-phase0-1.md](reports/WORK_REPORT_2026-11-11_redesign-phase0-1.md): 重构 Phase 0-1 完成 + Phase 2 阻塞的实测报告
- [redesign/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md](redesign/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md): 重构执行契约（Phase 0-7，含 §17 追踪表）
- [redesign/phase-1-report.md](redesign/phase-1-report.md): Phase 1 数据链路修复阶段报告

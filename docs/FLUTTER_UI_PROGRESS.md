# Flutterfox UI 重构进度（FLUTTER_UI_PROGRESS）

计划依据：`flutterfox-ui-redesign-plan.md` v1.0。本文件按计划 §9.8 在每批完成后更新：
改了什么、为什么、文件列表、测试结果、截图路径、剩余问题。

---

## Phase 0：现状重审与基线冻结（进行中，2026-11-06）

### 本批范围

只检查，不做视觉重写；不修改 Rust 业务代码。

### 已完成

1. **基线确认**：`main @ 32b1f37` 即计划书检查基线；工作区除审计文档外无源码改动。
2. **构建实跑**：`flutter build linux --release` 通过（Flutter 3.47.9）；实机运行确认
   首页/曲库真实数据加载、单一窗口标题栏、图标轨侧栏、系统无 MPRIS。
3. **旧审计逐条复核**：`UI_AUDIT_2026-11-04` 的 P0×9 / P1×13 / U×19 全部标注状态
   （已修复 / 仍存在 / 被架构替代 / 待实机确认），证据回源码，见 `docs/UI_AUDIT_DESKTOP.md` §2。
4. **现状问题清单**：新 P0×1（readAudioInfo 悬空桥）、P1×8、P2×7，见 `UI_AUDIT_DESKTOP.md` §3。
5. **重复实现对照表（P0-C）**：播放栏×3（2 现役）、队列×2（均现役）、标题栏×2（均现役）、
   主题管线×2（1 运行时），处置建议见 `UI_AUDIT_DESKTOP.md` §4。
6. **结构设计确认稿（P0-B）**：确认五主入口 / 窗口结构 / 断点 / 播放器结构 / 真源约束，
   见 `UI_AUDIT_DESKTOP.md` §5。

### 文件清单

| 文件 | 变更 |
|---|---|
| `docs/UI_AUDIT_DESKTOP.md` | 新增（Phase 0 主交付物） |
| `docs/FLUTTER_UI_PROGRESS.md` | 新增（本文件） |
| `docs/shots/20261106/20261106-m1-home-1440-dark.png` | 新增（自动化截图样张） |

### 测试结果

- `flutter build linux --release`：通过。
- 构建未触碰源码；`flutter analyze` / `flutter test` 维持 2026-11-05 审计结论
  （0 issues / 53 tests 全绿），本批未改动代码故未重跑。

### 截图路径

`docs/shots/20261106/`（用户手动截图归档中；归档后回填 `UI_AUDIT_DESKTOP.md` §1 索引）。

### 剩余问题

1. ~~等待用户手动截图~~ 已归档 8 张（`docs/shots/20261106/`），并据图定稿：新增 P0-A2
   （播放中总时长恒 0）、U-16 确认 44 套主题、U-19 帮助文案陈旧、P2-V8/V9。
2. 未覆盖页面（搜索/榜单/本地/下载/歌单详情/全屏播放页/队列/浅色）相关结论保持「待实机确认」。
3. Phase 0 验收达成，进入 Phase 1-5 执行（动态工作流流水线，见本文件后续批次记录）。

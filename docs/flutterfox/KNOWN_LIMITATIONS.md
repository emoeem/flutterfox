# FlutterFox 已知限制与责任边界(KNOWN_LIMITATIONS)

> 建立依据:合同 §3.4。状态沿用 `docs/redesign/04-defect-matrix.md`(2026-11-17 Batch G 后)
> 与 `docs/SESSION-HANDOFF-2026-11-17.md` §五,本轮执行中动态更新。

## 平台不可验证项(Windows 环境硬边界)

| 项 | 状态 | 说明 |
| --- | --- | --- |
| P1-06 Android 全链 | BLOCKED(用户搁置) | 不创建模拟器、不构建 APK;Android 壳层仅有 widget 测试覆盖 |
| P2-04 niri/Wayland 窗口几何 | 开放(Linux 专属) | Windows 结论不可替代;以 Linux 会话/CI 为准 |
| MPRIS 运行时验收 | 开放(Linux 专属) | Batch F cfg-linux 代码待 Linux CI 编译 + 运行时验证 |
| lx-source 3 例夹具失败 | 永久登记 | Windows 临时目录命名限制;Linux CI 为准,夹具不改不削弱 |
| app visualizer 时序 flaky | 永久登记 | Windows 调度抖动;Linux CI 为准 |

## 开放缺陷(接手时点快照,处理进度见 AUTONOMOUS_EXECUTION_STATUS)

| 编号 | 摘要 | 本轮处理方向 |
| --- | --- | --- |
| P0-01 | 主 isolate 概率性卡死(搜索结果/播放后 UI 全死) | F5 主战场:事件泵热路径取证;「未复现」不构成关闭证据 |
| P1-05 / P2-08 | 进程静默退出(GL timeout / UIA 标题栏 AXPress 单例,无 panic 无 crash.log) | F5:Windows 事件/WER/退出码证据链;不可 unwind 路径需外部 watchdog(独立设计) |
| P2-19 | 搜索骨架态 1136×713 底部溢出 143px(100% 复现) | F3/F4 优先修复(Windows 可先行,交接文档建议) |
| P2-20 | soda 发现面服务端空响应(上游契约变更) | 只保证空态诚实、无崩溃/假数据;不伪造内容、不盲目换接口 |
| GUI SMTC / Now Playing | media-session crate 就绪,GUI Windows/macOS 接入未完成 | F6 边界评估;接入属后续批次范围 |
| 结构化 FfiError(FFI-R10) | 全接口签名变更,成本/收益待独立评估 | 本轮不动签名,仅登记 |

## 上游/环境事实

- soda 曲目发现端 200 空 body = 服务端契约变更,FlutterFox 侧无法修复内容本身(P2-16 封面链与其无关)。
- 网络抖动:wy::url 等 2 例测试依赖真实音源网络,失败按交接口径单跑复归,不判代码缺陷。
- Flutter stable 已漂移(material.dart 整体弃用);SDK 固定 3.47.9 为仓库既定决策,本轮不升级 SDK。
- CI 的 Windows job 只构建 TUI(voicefox-app,MinGW);Flutter GUI Windows 构建仅本机验证(CI 无对应 job)——
  GUI 运行证据依赖 F7 实机批次。

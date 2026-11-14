# Flutterfox 跨平台工程演进计划书

> **项目：** `emoeem/flutterfox`（Voicefox Flutter 应用线）  
> **目标分支：** `feat/ui-redesign`  
> **计划基线：** `e58e7c2cc453869eee715ac0e557a7bf72fede55`（短 SHA：`e58e7c2`）  
> **计划性质：** 可直接交给编码 AI / Agent 执行的分阶段工程任务书  
> **核心路线：** 保留 Flutter + Rust + Flutter Rust Bridge（FRB），先加固跨语言边界，再完成主题、移动端、桌面、下载和稳定性工作  
> **重要决定：** 本计划不授权整体 Rust → Dart 重写，也不允许为了“架构统一”而推倒已工作的业务模块。

---

## 0. 执行摘要与架构决策

### 0.1 本计划要解决什么

Flutterfox 已经具有完整的跨平台音乐应用基础：Flutter 负责界面与平台体验，Rust 负责多音源、搜索、播放调度、歌词、下载、本地曲库、歌单、同步与存储等核心业务。桌面播放使用 Rust/libmpv，移动端播放使用 Rust 的转发型 `HostPlayerBackend` 与 Dart `just_audio` / `audio_service`。

当前需要做的不是把 Rust 全部改成 Dart，而是分阶段解决四类问题：

1. **跨语言边界可靠性：** 命令是否可靠送达、事件丢失后如何恢复、请求是否能关联、旧任务能否污染新状态、控制器和异步任务是否正确结束。
2. **用户界面一致性：** 主题双真源、部分主题预设不生效、字体层级不完整、桌面大屏内容无限拉伸。
3. **平台体验完整性：** 手机与平板多个页面仍复用桌面结构，缺少真正适配触控和小屏的独立页面布局。
4. **业务与工程质量：** 下载进度及窄窗问题、队列能力、MPRIS、运行时缺陷验证、Golden、无障碍、性能与崩溃诊断。

### 0.2 最终架构决策

**保留 Rust + Flutter Rust Bridge，不做整体 Dart 重写。**

目标职责如下：

| 层 | 推荐技术 | 职责 | 不应承担的职责 |
|---|---|---|---|
| Presentation | Flutter / Dart | 页面、布局、动画、主题、交互、路由、平台 UI | 复制音源协议、下载状态机、核心业务规则 |
| Dart Application Adapter | Dart | AppModel、Repository、请求编排、状态映射、平台服务适配、UI 缓存 | 再造一套与 Rust 重复的业务数据库和规则 |
| FFI Contract | flutter_rust_bridge | 稳定 DTO、命令、事件、快照、错误传递 | 暴露 Rust 内部锁、通道、具体实现对象 |
| Domain / Application | Rust | 音源、搜索、解析、歌词、下载、曲库、歌单、配置、播放调度 | Flutter Widget、UI 动画、页面状态表现 |
| Desktop Host | Rust + libmpv + 各平台适配 | 桌面音频播放、原生系统集成 | 手机专属音频后台服务 |
| Mobile Host | Dart + just_audio / audio_service / audio_session | 手机音频输出、通知、锁屏、音频焦点、耳机事件 | 复制 Rust 的音源解析和播放队列业务 |

本计划允许将来**局部模块**从 Rust 迁移到 Dart，前提是通过专项成本评估证明 FFI 在该模块确实造成了不可接受的复杂度；不得以“FFI 可能有问题”为理由整体重写。

### 0.3 本次基线事实

计划编写时核对的基线为：

- 分支：`feat/ui-redesign`。
- 提交：`e58e7c2`，包含 CI Flutter 3.47.9 固定、Analyze/Test 分离、P2-17/P2-18 歌词重取交叉修复、相关回归测试和第二轮审计文档。
- 本地报告记录：Flutter 全量测试 386 项通过；Rust workspace 测试 835 项通过；Dart 格式检查与 Analyze 通过。
- GitHub Actions Run `43556931399`（Run #122）：最近一次检查时 Flutter Analyze 已成功，其余 Flutter Test、Rust Lint 和平台构建仍在运行。**执行本计划时必须重新查询最新状态，不得把这个历史瞬间状态当作最终 CI 结论。**
- Flutter SDK 基线：`3.47.9`；FRB 生成代码标记版本：`2.13.0`。

关键参考：

- 提交：<https://github.com/emoeem/flutterfox/commit/e58e7c2cc453869eee715ac0e557a7bf72fede55>
- CI：<https://github.com/emoeem/flutterfox/actions/runs/43556931399>
- 现有实现审计：`docs/redesign/second-round/01-implementation-audit.md`
- 缺陷矩阵：`docs/redesign/04-defect-matrix.md`
- 第二轮工作报告：`docs/reports/WORK_REPORT_2026-11-14_second-round-phase0.md`
- 现有 UI 重构唯一规格：`docs/redesign/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md`

### 0.4 执行原则

1. **先审计，后修改。** 每个批次先核对当前分支、文件、调用链、已有测试和已有功能，再列出修改清单。
2. **不得重复造轮子。** 已存在且正确的功能保留；仅补缺口、修根因、增加缺失验证。
3. **不把可能风险写成既定 Bug。** FFI、异步、线程、平台插件问题必须先用代码证据或可重复实验确认。
4. **不降低测试质量。** 不允许删掉业务断言、缩窄用例覆盖、改成宽松 matcher 或以 mock 代替所有真实集成验证。
5. **不伪造业务能力。** 后端不支持的功能必须如实禁用或解释；先补 Domain/Application/FFI，再做 UI。
6. **桌面、平板、手机页面可独立布局。** 共享 DTO、业务服务、设计基础组件，不强迫三端共用整页 Widget。
7. **不改变用户现有工作区。** 执行前后检查 `git status`、diff 和未跟踪文件，不覆盖不属于本任务的改动。
8. **禁止破坏性 Git 操作。** 不执行 `reset`、`checkout`、`clean`、`stash`、`rebase`，不擅自删除或重建用户分支。
9. **提交与推送遵循用户当前授权。** 本计划本身只定义工作，不自动授权 Agent 提交、推送、合并或发布；除非用户在执行任务时明确允许，否则只交付工作区改动和报告。
10. **不擅自构建 Android APK、启动 Gradle/AVD/模拟器。** Android 真机与构建验证继续遵循用户既有约束，除非用户另行授权。
11. **不改变 Rust 业务协议来迎合 UI。** 每一项跨层修改都要有契约、测试、兼容策略和迁移说明。
12. **不把全量重构当作一次性任务。** 按 Phase / Batch 顺序推进，每个批次都必须可独立验收、可审查、可回退。

---

# 第一部分：当前架构与风险判断

## 1. 当前真实调用架构

### 1.1 桌面端

```text
Flutter UI
  └─ AppModel / ChangeNotifier
       └─ flutter_rust_bridge 2.13.0
            └─ ffi::VoicefoxController
                 └─ ApplicationService
                      ├─ SourceManager / Search / Playlist / Lyrics / Download
                      ├─ Storage / ConfigStore / LibraryStore
                      └─ PlaybackService
                           └─ Rust PlayerBackend
                                └─ libmpv
```

桌面端通过 `newDesktop()` 创建 Rust 控制器，Rust 侧持有应用服务与桌面播放后端。Flutter 通过 FRB 派发命令、读取快照、订阅事件；Rust 负责实际业务和 libmpv 播放。

### 1.2 移动端

```text
Flutter UI
  └─ AppModel
       └─ FRB / VoicefoxController
            └─ Rust ApplicationService
                 └─ PlaybackService
                      └─ HostPlayerBackend
                           └─ Rust → Dart HostPlayerStream
                                └─ HostPlayerBridge
                                     └─ just_audio
                                          └─ audio_service / audio_session
                                               └─ Android 音频与媒体会话

Dart just_audio 快照 / Ended / Error
  └─ HostStateSink
       └─ FRB hostPlayerReport / hostPlayerReportEvent
            └─ Rust HostPlayerBackend watch / event channel
                 └─ ApplicationService 播放观察泵
                      └─ ApplicationEventStream
                           └─ FRB eventNext
                                └─ Dart AppModel 更新 UI
```

移动端不是纯 Dart 后端：音源解析、歌曲、队列、状态、歌词和下载等仍由 Rust 控制；Dart 只承担音频宿主和移动系统服务。

### 1.3 已存在的保护机制

以下内容已在仓库中，后续不得重复实现：

- `VoicefoxController` 作为 Flutter 面向的线程安全应用句柄，不直接暴露 `ApplicationService` 内部状态锁。
- 业务命令使用 `FfiCommand` / `ApplicationCommand`。
- 结构化数据使用 DTO，例如 `SongDto`、`VoicefoxState`、`HostPlayerCommandDto`。
- Rust `ApplicationService` 使用 Tokio 异步任务和广播事件。
- `ApplicationEventStream` 对 `Lagged` / `Closed` 有错误类型映射。
- Dart `AppModel._eventLoop()` 遇到事件流错误后会等待、重订阅并调用 `_refreshState()` 拉取快照。
- 播放进度事件已节流，避免高频进度变化导致整份状态刷新。
- 播放代次 `generation` 已用于阻止部分旧播放事件污染新播放。
- `ApplicationRuntime` 已有进程级 Tokio Runtime 保障同步 FFI 引导路径的任务生命周期。
- 移动播放器抽象了 `MobileAudioPlayer`、`HostCommandSource`、`HostStateSink`，已有 fake 注入测试。
- Rust / Dart 生成绑定已经纳入仓库，且 API 文件标注自动生成，不应手工编辑生成文件。

### 1.4 必须进一步审计的风险点（不是预先判定的 Bug）

| 编号 | 代码现状 / 证据 | 风险 | 本计划要求 |
|---|---|---|---|
| FFI-R01 | `application/src/services/host_player.rs` 使用 `broadcast::channel(64)` 传递移动播放命令 | 消费端滞后时 `Lagged` 代表部分命令已经跳过；连续执行时可能丢失播放控制意图 | 验证实际可复现性，设计可靠命令语义 |
| FFI-R02 | `HostPlayerBackend` 中多个 `send()` 结果被忽略 | 没有消费者、接收端关闭或通道异常时，命令可能未被执行但上层无法获知 | 定义“命令已接受”和“宿主已执行”的不同状态 |
| FFI-R03 | `HostPlayerBridge._pumpCommands()` 对 `lagged` 字符串选择 `continue` | 继续消费不等于恢复已经丢失的命令 | 定义重同步方案，不允许把异常字符串当协议 |
| FFI-R04 | Dart `_dispatch()` 逐条 `await` 播放器动作 | `setAudioSource()` / `play()` 等慢调用可能延长命令消费时间 | 压力测试播放切换、Pause/Seek 连发、缓冲和超时 |
| FFI-R05 | `HostPlayerBridge._onSnapshot()` / `_onEvent()` 使用 fire-and-forget 回流 | 状态回流与离散事件可能存在时序错位或错误未确认 | 测试顺序、代次、失败重试与观测 |
| FFI-R06 | `HostPlayerBridge.dispose()` 当前对订阅取消、播放器释放使用异步未等待路径；命令泵为持续循环 | dispose 后仍可能有挂起的 `next()` 或异步回调 | 验证并补充可取消生命周期 |
| FFI-R07 | `VoicefoxAudioHandler` 订阅播放器及 AppModel，并监听系统音频事件 | 进程级订阅是否只建立一次、何时解除，需要明确 | 检查重复初始化、退出和恢复路径 |
| FFI-R08 | `VoicefoxEventStream` 基于 broadcast；应用事件容量为 256 | 事件落后后恢复快照必须覆盖所有可恢复状态；短暂通知是否允许丢失要有定义 | 区分状态事件、一次性通知和命令响应 |
| FFI-R09 | `VoicefoxController.state()` 除常规状态还会附带 `local_songs` 全量快照 | 大曲库下可能产生不必要克隆、DTO 转换和 FFI 传输 | 量测并拆分本地曲库分页读取 |
| FFI-R10 | `FfiCommand` / DTO 有部分字符串枚举和数值字段 | 字段语义、范围、向前兼容和错误处理容易分散 | 固定契约、验证输入、集中错误映射 |
| FFI-R11 | Rust API 和生成 Dart 代码通过 FRB Codegen 绑定 | SDK / codegen 不一致或生成文件滞后会造成编译、运行时协议不一致 | 固定版本并验证生成文件可再生成 |
| FFI-R12 | 进程级 Tokio Runtime 使用 `OnceLock`，与应用控制器生命周期解耦 | runtime 长驻是当前设计意图，但任务取消与应用重建需要验证 | 明确进程级资源与会话级资源边界 |

**特别说明：** 以上风险中，R01–R04 优先级最高。其余需要先看真实调用与测试再决定是否修改。

---

# 第二部分：阶段总览

## 2. 推荐顺序

| 阶段 | 名称 | 主要任务 | 依赖 | 交付 |
|---|---|---|---|---|
| Phase 0 | 基线复核与任务拆分 | 检查提交、CI、工作区、已有审计和矩阵 | 无 | 基线报告、执行清单 |
| Batch A | Rust / Dart FFI 边界审计与可靠性加固 | 命令、事件、状态、生命周期、错误、性能、代码生成 | Phase 0 | FFI 契约文档、回归测试、必要修复 |
| Batch B | 主题真源统一 | ThemeProvider、Vx Token、44 主题、dynamicColor、字体 | Phase 0；可在 Batch A 稳定后进行 | 单一主题系统与行为测试 |
| Batch C | 手机与平板独立体验 | 8 个手机页面、平板页面、系统 inset、触控 | Batch B 的设计 token 稳定后 | Mobile / Tablet 页面与测试 |
| Batch D | 桌面体验完善 | 大屏限宽、键盘焦点、菜单核验、搜索同步、首页歌单 | Batch B | Desktop 页面改进 |
| Batch E | 下载可靠性 | 进度准确性、状态机、窄窗、错误详情 | Batch A 的错误和状态契约 | 下载业务和 UI 回归 |
| Batch F | 系统与队列能力 | 队列排序协议、MPRIS、媒体系统集成 | Batch A；按平台独立交付 | 真实功能和平台测试 |
| Batch G | 既有缺陷运行时闭环 | P1-20、P2-16、P2-17、P2-18 等 | Batch A | 真实运行时证据、矩阵更新 |
| Batch H | 稳定性与崩溃诊断 | P0-01、P1-05、P2-08、P2-04 | Batch A | 诊断报告、根因或可重复限制 |
| Batch I | 质量工程 | Golden、无障碍、性能、观测性、跨平台验证 | 各阶段增量 | 可持续质量门禁 |

## 2.1 执行依赖

- **Batch A 必须优先完成审计。** 不能在不知道命令可靠性和状态语义的情况下继续扩大移动播放复杂度。
- Batch A 的审计先行，不等于必须把所有 FFI 风险一次性重构完。对已证明稳定的接口维持不变。
- Batch B 主题系统可以在 Batch A 的接口审计完成、且无阻塞型状态问题后开始；主题 UI 与 FFI 无直接依赖，但应使用已确认的工程基线。
- Batch C 与 Batch D 可以在基础设计 token 稳定后按页面拆分推进，不允许多个 Agent 同时修改同一共享壳、主题或状态管理文件。
- Batch E 下载业务依赖 Batch A 的错误、任务状态和状态快照约定。
- Batch F 队列排序必须先确认 Rust Application 层和 FFI 协议能支持真实操作；MPRIS 可独立按 Linux 平台实施。
- Batch G 以真实 App 运行证据为目标，不应被纯 Widget 测试替代。
- Batch H 需要专门诊断会话与可复现环境，不得混入普通 UI 批次。

---

# 第三部分：Phase 0 —— 基线复核

## 3. 目标

在任何修改之前，确认当前仓库已经包含 `e58e7c2`，CI 的真实最终结论是什么，工作区是否有用户未提交改动，以及审计文档是否与当前代码一致。

## 3.1 必做检查

1. `git status --short --branch`：记录分支和工作区状态。
2. `git log -5 --oneline --decorate`：确认当前 HEAD 不早于计划基线，且没有误切分支。
3. `git show --stat --oneline e58e7c2`：核对门禁恢复提交。
4. 查询 Run `43556931399` 及之后的最新 Actions；分别查看 Analyze、Test、Lint、Linux、Windows、macOS、Android FFI Job。
5. 从 CI 日志确认 Flutter/Dart 版本，而不是只看 YAML 配置。
6. 阅读：
   - `docs/redesign/second-round/01-implementation-audit.md`
   - `docs/redesign/04-defect-matrix.md`
   - `docs/reports/WORK_REPORT_2026-11-14_second-round-phase0.md`
   - `docs/redesign/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md`
   - `docs/SESSION-HANDOFF.md`
7. 逐项核验报告和代码是否冲突，尤其是右键菜单、主题投影、手机页面复用以及 P2-17/P2-18 状态。
8. 不得因为文档记录了旧状态，就将旧状态视为当前代码事实。

## 3.2 特别处理：报告历史与最终状态

现有工作报告保留了 Phase 0 的历史审计结果，也在后面追加了门禁恢复批次。不得删除历史，但应在顶部或新增状态摘要中明确：

- 基线 HEAD：`e58e7c2` 或实际更高提交。
- Phase 0 审计状态。
- 门禁恢复批次结果。
- 本地 Flutter 386 项 / Rust 835 项验证记录（若当前基线仍与记录一致）。
- 最新 GitHub Actions 的真实 Job 状态和查询时间。
- 尚未完成的设备实测与运行时证据。

## 3.3 Phase 0 输出

新增或更新：

`docs/reports/WORK_REPORT_YYYY-MM-DD_second-round-baseline-review.md`

必须包括当前 HEAD、CI Run、工作区状态、文档冲突、测试基线、尚未验证项目及下一批次许可条件。

**Phase 0 验收：** 当前提交、CI、代码和文档四者的状态关系清晰；没有将未验证项标为完成。

---

# 第四部分：Batch A —— Rust / Dart FFI 边界审计与可靠性加固

## 4. 目标

建立可审计、可测试、可恢复的 Rust ↔ Dart 通信契约，使桌面和移动端都能够可靠地处理命令、状态、事件、异常、取消和生命周期。

**本批次不重写业务层，不替换 FRB，不迁移 Rust 全部模块。**

## 4.1 Task A0：建立 FFI 接口与调用链清单

逐一列出以下接口：

- `ffi/src/api.rs` 暴露的所有函数。
- `ffi/src/lib.rs` 暴露的所有 DTO、枚举、Opaque handle、Controller 和 Stream。
- `flutter/lib/src/bridge/api.dart` 与 `lib.dart` 对应的 Dart 接口。
- 生成文件 `frb_generated.dart`、平台条件文件及 Rust `frb_generated.rs`。
- `AppModel` 的命令派发、事件订阅、快照刷新、初始化和错误处理。
- 移动端 `HostPlayerBridge`、`HostCommandSource`、`HostStateSink`、`MobileAudioPlayer`。
- 桌面端 `newDesktop()` / `bootstrapDesktop()`。
- 移动端 `newHost()` / `AppModel.attach()` / `_bootstrapTouch()`。

建议输出：

`docs/architecture/ffi-contract-inventory.md`

接口表至少包含：方向、调用者、被调用者、参数类型、返回类型、异步方式、错误、生命周期、事件来源、是否有对应测试。

## 4.2 Task A1：明确 FFI 契约边界

### 目标

Rust 内部类型不直接暴露给 Flutter。所有跨语言交互使用稳定 DTO / Command / Event / Snapshot。

### 检查内容

1. 逐字段审查 `SongDto`、`VoicefoxState`、`ConfigDto`、`DownloadTaskDto`、`HostPlayerCommandDto`、`HostHeaderDto`、`VoicefoxEvent` 等类型。
2. 检查 Rust `usize` / `u64` / `u32` 与 Dart `int` / `BigInt` 的边界转换。
3. 检查 `Duration`、时间戳、百分比、路径、URL、可选字段、空字符串和未知音源 ID。
4. 检查枚举是否使用不稳定的展示字符串作为内部协议。
5. 检查错误是否只返回 `String`，导致 Dart 无法区分网络错误、参数错误、取消、超时、通道关闭和内部故障。
6. 检查跨版本时新增 DTO 字段是否有默认值或兼容策略。

### 设计要求

- 定义清晰的 DTO 约定：必填字段、可空字段、默认值、字段单位、范围、错误行为。
- 对重要状态建立类型化枚举或明确常量约束，避免 Dart / Rust 多处手写字符串。
- 对公共协议变化记录版本策略；不必为了版本化而机械地给每个小对象增加版本字段。
- 对外返回结构化 `FfiError`（建议含 `code`、`message`、可选 `details`、`retryable`），但先盘点 FRB 的兼容表达能力，再决定具体类型。
- 对用户敏感信息、代理凭据、音源请求头和完整播放 URL 做日志脱敏。
- 禁止将 Rust `RwLock`、Tokio channel、播放器后端对象直接暴露给 Dart。

### 测试

- DTO 转换的往返测试。
- 未知 source / 未知状态输入测试。
- 极端时长、超大数值、空 URL、缺失字段和错误编码测试。
- 新字段与旧数据兼容测试。

## 4.3 Task A2：移动播放命令可靠性

### 当前代码线索

- `application/src/services/host_player.rs` 使用 `broadcast::channel(64)`。
- `HostPlayerBackend` 的 Play / Pause / Resume / Stop / Toggle / Seek / SetVolume / SetSpeed 使用 `send()`，多个发送结果被忽略。
- `ffi/src/lib.rs` 的 `HostPlayerStream::next()` 将 `Lagged` 返回为错误字符串。
- `flutter/lib/src/bridge/host_player_bridge.dart` 的 `_pumpCommands()` 对字符串包含 `lagged` 的错误继续循环。
- `_dispatch()` 按顺序 `await` 播放器操作；播放设置音源和开始播放可能耗时。

### 必须回答的问题

1. 播放宿主尚未订阅时，Rust 派发 Play 是否可能无消费者并丢失？当前初始化顺序是否能完全排除这个窗口？
2. 播放器正在 `setAudioSource()` / `play()` 时收到 Pause、Stop、下一首 Play，会如何排队？
3. 超过 64 条未消费命令时，实际丢失哪部分命令？
4. `Lagged` 后继续消费旧队列，是否有可能执行已经过期的 Seek / Pause / Resume？
5. 是否存在两个异步播放请求交错，导致旧请求后完成并覆盖新曲目的情况？
6. Rust 是否能知道 Dart 已经收到命令？是否能知道播放器真正执行成功？
7. 宿主断开或异常后，Rust 播放状态是否会永久停留在 Loading / Playing？

### 设计方向（先分析，再选型）

不要简单把 `broadcast` 替换成 `mpsc` 就结束。先区分命令语义：

| 命令类别 | 示例 | 可靠性要求 | 候选处理方式 |
|---|---|---|---|
| 状态转换命令 | Play / Pause / Resume / Stop | 必须有序、有执行反馈或失败反馈 | 有界可靠队列 + command ID + ack/result |
| 位置控制 | Seek | 可以考虑按播放代次合并旧位置，但不能跨曲目误执行 | command ID + generation + latest-wins 规则 |
| 连续参数 | SetVolume / SetSpeed | 通常允许合并到最新值 | watch/latest-value 或有界合并队列 |
| 诊断/状态 | state / position / duration | 高频，只保留最新值即可 | watch / snapshot |

最终实现必须满足：

- 关键命令不能在无人消费或通道满时静默丢弃。
- 每条命令具有可关联的 `commandId`；播放相关命令带 `generation`。
- Rust 能区分“命令入队”和“宿主执行完成”。
- Dart 能返回成功、失败、取消或过期结果。
- 过期命令应明确忽略并记录原因，不可以静默误执行。
- 通道满时有明确背压或合并策略，不能无上限堆积。
- 宿主重启后可以进行状态同步，不能假设丢失的历史命令全部重放。
- 使用明确的 enum / error code 表达 `Lagged`、`Closed`、`Timeout`，禁止用 `message.contains('lagged')` 作为协议判定。

### 必须增加的测试

1. 消费者尚未就绪时派发 Play。
2. 消费者中途关闭后派发 Pause / Stop。
3. 播放命令执行慢时连续派发 Play、Pause、Seek、Stop。
4. 人为缩小队列容量并模拟消费者落后。
5. `Lagged` 或队列溢出后的重新同步。
6. 同一歌曲快速切换、跨歌曲旧命令迟到。
7. 播放命令返回错误，Rust / Dart 状态均恢复到一致状态。
8. 重连后只执行当前有效的播放意图，不重放过期命令。

## 4.4 Task A3：事件流、状态快照与恢复协议

### 当前实现

Rust 应用事件通道容量为 256。Dart `AppModel._eventLoop()` 捕获事件流错误后会等待、重订阅并重新读取完整状态。

这套机制应该保留，但需要明确哪些事件是“不可丢失的事实”，哪些事件只是“状态变化提示”。

### 任务

1. 给事件分类：可恢复状态事件、一次性通知事件、命令执行结果、进度快照。
2. 明确 broadcast `Lagged` 后重新订阅的行为。
3. 评估事件与状态快照的竞态：订阅之后是否先拉快照再处理事件，或先接事件再拉快照，是否可能覆盖更新值。
4. 对状态快照考虑 `revision` / `sequence`，避免旧快照覆盖新事件。
5. 对 Notification、登录二维码、下载错误等一次性事件制定丢失策略；必要时改为具备确认语义的结果通道或保留最近事件。
6. 避免一个进度事件触发全量状态克隆。
7. 明确重新订阅失败后的退避策略、最大重试和用户可见状态。

### 测试

- 丢失若干状态事件后重订阅，最终快照必须正确。
- 快照拉取过程中出现新事件，不得被旧快照覆盖。
- 通知事件的丢失行为符合明确契约。
- 多事件并发到达时，UI 不回滚到旧 revision。
- 重订阅重复发生时，不出现多个永久事件泵。

## 4.5 Task A4：请求关联、播放代次与异步任务取消

### 目标

确保搜索、播放、歌词、歌单、下载等操作不会被迟到结果覆盖。

### 任务

1. 盘点现有 `request_id`、`playback_request_id`、`browse_request_id`、`generation` 的适用范围。
2. 明确每一类异步请求的唯一标识、生命周期和失效条件。
3. Play / Lyrics / Browse / Search 使用不同语义的 request ID，不要错误复用播放 generation。
4. 切歌后旧歌词、旧封面、旧播放错误、旧进度不能更新当前歌曲。
5. 页面退出只应取消页面局部任务；后台播放、下载等应用级任务不能被 UI 页面销毁误取消。
6. 应用关闭或 Controller 释放时，应用级任务应有明确取消与清理路径。
7. 对重复请求定义幂等策略：忽略重复、取消旧请求或合并请求，必须按业务语义选型。

### 测试

- A 请求先发后完成，B 请求后发先完成：A 不得覆盖 B。
- 页面销毁后请求返回：不得更新已销毁页面或泄漏订阅。
- 用户切歌时歌词失败通知不得污染当前歌曲。
- 搜索换关键词后，旧搜索结果不得覆盖新关键词。
- 下载任务取消后迟到进度不得把任务恢复为进行中。

## 4.6 Task A5：Controller、Stream、Bridge 与 Runtime 生命周期

### 审计对象

- `VoicefoxController` 的创建、克隆、释放。
- `VoicefoxEventStream` / `HostPlayerStream` 的订阅和关闭。
- `AppModel` 的 `ensureRustLib()`、`_attach()`、`_eventLoop()`。
- `HostPlayerBridge.start()`、`_pumpCommands()`、`dispose()`。
- `VoicefoxAudioHandler` 的 player / model 监听器及 audio_session 订阅。
- Rust `OWNED_RUNTIME`、`ApplicationRuntime` 与 Tokio task 的生命周期。

### 要求

1. 明确 Controller 是进程级、应用级还是页面级对象。
2. 明确 AppModel 的创建、重用和最终释放位置。
3. 为 `HostPlayerBridge` 增加可取消的运行状态：`started`、`stopping`、`disposed` 等必要状态。
4. `dispose()` 应等待 StreamSubscription 取消和播放器释放；如需异步 dispose，应在调用方显式 await。
5. 命令泵等待中的 `next()` 必须可停止，不能只释放监听器而留下永久挂起任务。
6. `VoicefoxAudioHandler` 对 AppModel 的 listener 应在正确生命周期移除；若设计为进程级 singleton，必须保证初始化幂等并写明理由。
7. 不要在页面 dispose 时关闭进程级 Tokio Runtime。
8. 不要让桌面 Controller 生命周期影响移动宿主，反之亦然。
9. 对初始化失败提供可重试或明确不可恢复的状态，避免 `_rustLibReady` 永久缓存失败 Future。

### 验收测试

- 启动 → 播放 → 暂停 → 页面切换 → 恢复。
- 启动 → 播放 → 快速销毁 / 重建宿主。
- AppModel attach 两次：是否幂等、是否重复订阅。
- Bridge dispose 时正有 `next()` 挂起。
- Bridge 正在 `play()` 时 dispose。
- audio_service 初始化失败后重试。
- 运行一段时间后无重复事件泵、重复通知、定时器或 StreamSubscription 泄漏。

## 4.7 Task A6：状态快照与大数据传输性能

### 当前代码线索

`VoicefoxController.state()` 除应用状态外，还将 `application.local_songs()` 全量映射成 `SongDto`。Dart `AppModel._refreshState()` 读取的是完整 `VoicefoxState`。

### 任务

1. 用 1k、10k、30k、50k 本地曲库测量 state() 耗时、DTO 转换耗时、FRB 传输耗时、Dart 分配量和 UI 帧影响。
2. 记录搜索、播放、队列、下载、配置事件分别触发了多少次全量快照。
3. 将变化频率高、数据量大的本地歌曲集合从通用播放快照中拆分。
4. 为本地音乐提供分页 / 增量读取 / 查询接口；分页键应稳定，不能简单每次返回完整列表。
5. 对队列、下载、收藏、歌单按实际变化更新，避免无关状态重传。
6. 保留一个可信的全量恢复入口，供事件丢失后重新同步。
7. 先测量，再优化；禁止为了“减少调用”引入难以恢复的分布式缓存一致性问题。

### 性能验收建议

- 30k 本地曲库下，播放进度更新不得触发完整 local_songs 传输。
- 搜索结果刷新不得重新克隆全部本地歌曲。
- 冷启动、快照刷新和列表分页分别有可复现基准。
- UI 滚动时无明显 GC 抖动；具体帧率阈值在目标硬件上建立基线后确定，不得虚构数字。

## 4.8 Task A7：错误模型、日志与诊断关联

1. 建立统一错误类别：参数无效、未初始化、网络、音源、播放器、文件系统、权限、取消、超时、事件流关闭、协议错误、内部异常。
2. Rust 内部保留详细上下文；跨 FFI 传递稳定错误码与用户可见消息。
3. 日志中关联 `requestId`、`commandId`、`playbackGeneration`、`source`、`songId`，但不得记录完整代理 URL、Cookie、请求签名或敏感头。
4. AppModel 对用户通知、诊断日志和错误恢复分开处理。
5. 不允许 `catch (_) {}` 静默吞掉会影响业务正确性的错误；可以降级的日志失败、截图失败等必须注释说明降级边界。
6. Crash log 应写明平台、应用版本、Rust 版本、Flutter 版本、最近操作阶段和诊断 ID。

## 4.9 Task A8：FRB Codegen 与 CI 契约

1. 固定 `flutter_rust_bridge` Dart 依赖和 Rust 侧版本策略，确认 codegen 版本一致。
2. 记录唯一生成命令及 PATH 要求。
3. 在 CI 中执行生成文件一致性检查：重新生成后若有 diff，则判定失败，且不得自动提交生成结果。
4. 明确生成文件禁止手工修改；手工 API 应放 `api.rs` / `lib.rs` 和 Dart wrapper，不放 generated 文件。
5. 对新增 DTO / API 要求在同一个变更批次更新 Rust、Dart 生成码、测试和文档。
6. CI 需要覆盖 Rust FFI 编译、Flutter Analyze、Flutter Test，以及至少目标平台的链接验证。

## 4.10 Batch A 交付文件

建议产出：

- `docs/architecture/ffi-contract-inventory.md`
- `docs/architecture/ffi-reliability-design.md`
- `docs/reports/WORK_REPORT_YYYY-MM-DD_ffi-reliability.md`
- 必要的 Rust / Dart 单元、集成和压力测试。
- 缺陷矩阵中新增或更新 FFI 风险编号，例如 `FFI-R01..FFI-R12`。

## 4.11 Batch A 完成标准

- 所有 FFI API 有调用链和类型清单。
- 每个风险有“已证实 / 已排除 / 无法复现 / 需设备验证”的判定。
- 移动播放关键命令有明确送达和失败反馈语义。
- `Lagged` 不再依赖错误字符串识别；若保留广播，必须有经过测试的恢复策略。
- 生命周期测试覆盖 Bridge 停止、Stream 释放和异步回调。
- 状态快照传输有量测结果及优化边界。
- FRB 生成码可重复生成且 CI 可检查。
- Flutter / Rust / 目标平台门禁通过。
- 没有为了加固 FFI 而重写整个业务系统。

---

# 第五部分：Batch B —— 主题真源统一与设计系统

## 5. 目标

解决 ThemeProvider 与 Vx Design Tokens 双真源问题，让 44 套主题、深浅模式、动态颜色、字体、颜色、间距和公共组件使用同一套主题定义。

### 5.1 当前问题

审计指出：

- `ThemeProvider` 运行时通过 `ColorScheme.fromSeed` 构造 Material 主题。
- `VxColors` / `VxLightColors` / `VxChrome` 在 `design_tokens.dart` 中独立定义并由壳层消费。
- 两套颜色定义缺少稳定的统一派生关系。
- 44 个主题预设中，审计记录 28 套选中后会回退到 Mocha 投影种子。
- `dynamicColor` 在 Rust Config 与 Dart Settings Provider 中存在双开关 / 双真源风险。
- `ThemeProvider` 行为测试不足，主题 guard 对部分 main.dart 内联 `fromSeed` 路径覆盖不足。
- 运行时 Typography 权重层级不足，CJK 与 JetBrainsMono fallback 尚需统一。

### 5.2 统一主题定义

先建立单一主题模型，例如：

```dart
class ThemeDefinition {
  final String id;
  final String name;
  final Brightness brightness;
  final ColorScheme colorScheme;
  final VxColorTokens vxColors;
  final VxChromeTokens chrome;
  final VxSemanticTokens semantic;
  final VxTypographyTokens typography;
  final VxSpacingTokens spacing;
  final VxRadiusTokens radius;
}
```

以上仅为结构示意，必须结合现有 ThemeRegistry、projection 和 design_tokens 决定最终类型，不得机械照抄创建重复 registry。

要求：

1. 一个 `ThemeDefinition` 是选中主题的唯一运行时真源。
2. `ThemeData`、Material `ColorScheme`、Vx 自绘组件颜色、PlayerBar、Header、Sidebar、ContextPanel 都从同一主题定义派生。
3. 深浅色模式明确：主题有固定明暗、系统模式和用户强制明暗时如何处理。
4. 动态颜色需要明确优先级：用户主题预设、系统动态色、用户强制模式的覆盖规则。
5. 禁止页面里继续散落主题颜色硬编码，允许极少量不可主题化的常量必须注释理由。
6. 对所有主题预设建立完整字段检查，不能选中后静默回退另一套主题。

### 5.3 44 套主题预设

1. 盘点 Registry 的 44 套主题及来源。
2. 对每套主题验证：accent、surface、background、text、muted、border、success、warning、error、player chrome。
3. 28 套当前投影失效项逐一核验，定位是没有 projection、缺字段还是 brightness 映射错误。
4. 对不能从旧色板精确映射的语义颜色给出明确转换规则，不能简单用一个 seed 替代整套色板。
5. 主题切换必须即时更新，不需要重启。
6. 重启后恢复用户所选主题。
7. 动态颜色启用 / 关闭后不得覆盖用户持久化的预设定义。

### 5.4 Typography

- 定义 Display / Headline / Title / Body / Label / Caption 的字号、行高、字重。
- 确保 CJK 字体、常规拉丁字体、等宽字体有明确 fallback。
- JetBrainsMono 用于时间、进度、数值和代码场景，不应让整套 UI 被等宽字体覆盖。
- 字重需要真正呈现层级，不能全部 `w400`。
- 文字缩放后不能产生按钮溢出、歌词裁切或关键操作不可达。
- 用字体测试和关键页面视觉证据锁定字体 fallback。

### 5.5 设计 Token

统一以下类别：

- 颜色：语义色、表面层级、文本层级、边框、焦点、hover、pressed、disabled。
- 间距：4/8 基准或现有仓库体系，确定后统一。
- 圆角：卡片、按钮、弹层、输入框、胶囊。
- 阴影 / elevation：遵循当前视觉方向，不新增无意义渐变、霓虹或纯黑大底。
- 动效：时长、曲线、过渡策略。
- 密度：桌面 compact / standard / comfortable 与移动端触控密度分开定义。

### 5.6 Dynamic Color 单一配置真源

- 明确 Rust Config 是持久化真源还是 Dart 设置模型是单一运行时真源，最终只能有一个权威写入路径。
- UI 设置变更先更新明确的配置状态，再发起 Rust 持久化；失败时有回滚或错误状态。
- Rust 的 ConfigChanged 回流更新 UI，不得出现两处互相写入导致循环。
- Android 动态颜色与桌面动态颜色按平台能力声明，不能假设每个平台支持。

### 5.7 测试

- 所有 44 套主题能够加载并生成有效 `ThemeData`。
- 所有 44 套主题的关键 Vx Token 不为空且颜色值符合对比度约束。
- 深 → 浅 → 深 / System ↔ Light ↔ Dark 往返测试。
- dynamicColor 开关、预设选择、重启恢复测试。
- 壳层与内容组件颜色来自同一个主题实例的 guard 测试。
- Typography 的字体和字重映射测试。
- 重要页面的主题截图 / Golden 测试。

### 5.8 Batch B 验收

- 不存在第二套独立的运行时颜色真源。
- 44 套主题逐项有效，无选中后回退 Mocha 的问题。
- DynamicColor 只有一个权威持久化路径。
- 桌面、手机、平板公共组件颜色一致。
- 浅色、深色、系统模式均经过页面级验证。
- 所有现有主题回归测试通过，且新增测试锁住关键语义。

---

# 第六部分：Batch C —— 手机与平板独立体验

## 6. 目标

将桌面页面缩小并不能形成成熟的移动体验。手机和平板应该使用各自合理的导航、信息密度、列表、详情、设置与播放器交互，但继续复用 Rust 业务能力、AppModel、DTO、Repository 和公共基础组件。

### 6.1 手机页面清单

审计记录当前以下页面缺少真正独立的 Mobile 页面或适配不足：

- Discover
- Search
- Downloads
- Playlist Detail
- Local Music
- Settings
- Help
- Library（部分已有 `<512` 补丁，需核实其完整性）

Home、MobileShell、全屏 NowPlaying 已存在，不得推倒重写；先核验已有实现和真实截图。

### 6.2 手机统一布局规则

1. 以当前 `MobileShell` 入口和导航结构为基线。
2. 页面采用适合手机的单列信息层级，避免直接复用桌面三栏布局。
3. 常见操作使用底部导航、BottomSheet、上下文菜单或明确的页面级操作栏。
4. 触控目标满足现有 UI 指南标准，不允许只有 hover 才可发现关键操作。
5. 系统状态栏、导航栏、安全区和软键盘 inset 使用单一计算来源。
6. 页面底部滚动 padding 应考虑系统导航区域与 mini player，不得所有页面固定使用同一个 24px 值。
7. 适配 360、390、430 逻辑宽度以及矮屏场景；小屏不能因为视觉压缩导致标题、歌曲信息或按钮不可用。
8. 长列表必须保持滚动性能，避免页面内再嵌套多层无约束滚动器。
9. 页面切换时播放服务和 AppModel 不随页面销毁。
10. 无数据、加载、错误、权限拒绝、空搜索结果等状态均有真实反馈。

### 6.3 手机页面任务

#### C-01 Discover

- 顶部音源筛选、搜索与分类入口重排。
- 音源选择器适配 BottomSheet / Menu，明确“全部音源”状态。
- 分类、榜单、推荐歌单使用移动端卡片和列表密度。
- 列表分页和刷新反馈可见。
- 真实能力不支持时隐藏或提供解释。
- 回归 P1-20：单音源 → 全部音源 → 再选单音源，确保聚合查询正确。

#### C-02 Search

- 优化输入框、搜索历史、音源筛选与结果列表。
- 键盘弹出时输入框、结果和返回控件不互相遮挡。
- 搜索历史删除 / 清空有明确确认策略。
- 新关键词请求使旧请求失效。
- 页面内搜索与全局 Header 搜索统一状态语义，不能双向同步导致循环。
- 多选、加入队列、播放等操作适配触控。

#### C-03 Downloads

- 使用移动端任务卡片或紧凑列表。
- 任务进度、大小、状态、暂停、继续、取消、重试和删除操作清晰。
- 不能在一行塞入桌面所有列。
- 错误原因允许展开查看，不能只显示被截断的短字符串。
- 状态机真实驱动按钮，不使用仅改变 UI 的假操作。

#### C-04 Playlist Detail

- 独立头部、封面、名称、来源、歌曲数量、播放全部和收藏操作。
- 详情返回行为正确。
- 处理长标题、多来源、空歌单、加载失败。
- 分页请求按 `PlaylistKey` 隔离，旧歌单迟到响应不能污染新歌单。

#### C-05 Local Music

- 本地扫描入口和目录管理使用移动平台适配。
- Android SAF / `content://` 能力必须先核实当前后端与平台桥的真实支持情况。
- 不支持的来源必须给出可理解错误，不允许假装扫描完成。
- 扫描进度、新增、复用、失败、跳过、移除统计清晰。
- 大曲库分页、排序、筛选和封面加载稳定。

#### C-06 Settings

- 手机设置使用分组列表与独立二级设置页或适当 BottomSheet。
- 避免直接把桌面双栏设置挤进手机宽度。
- 主题、播放、音源、网络、下载、歌词、快捷键、关于等分组有清晰导航。
- 设置保存失败必须展示错误并保留可恢复状态。
- 用户离开页面时，不得静默丢失未保存内容。

#### C-07 Help

- 帮助与快捷键按移动端能力过滤。
- 不展示不适用的桌面窗口快捷键或不可执行入口。
- 版本、平台能力与使用说明来自真实配置。

#### C-08 Library

- 复核现有 MobileLibraryPage、曲库分类、收藏、历史和本地音乐布局。
- 保留 P2-10 / P2-15 已有窄屏标签修复。
- 验证 360px 下标签不截断、操作不溢出、长列表滚动可用。

### 6.4 平板页面

平板不能仅视为放大的手机或缩小的桌面。按现有设计指南的断点与导航约定建立清晰档位。审计中已有 600–839 与 840–1199 相关规则，应以唯一 UI 指南为准，不在本计划另造冲突断点。

任务：

1. Home：多栏卡片与合理的主内容宽度。
2. Discover/Search：主内容和筛选区域可并排，窄档使用抽屉/Overlay。
3. Library/Playlist：左侧分类或列表与右侧详情按空间动态分配。
4. Downloads：表格与卡片在不同宽度之间切换。
5. Settings：平板双栏设置布局，避免完整桌面导航在中尺寸下浪费空间。
6. NowPlaying：封面、播放操作、歌词和队列按宽度灵活分配。
7. ContextPanel：右栏显示 / 隐藏 / end panel 规则明确；不要遮挡中央内容却又允许用户继续操作的矛盾状态。
8. 拖动宽度如果后端与窗口能力不支持，应明确禁用，不伪造拖动把手。

### 6.5 响应式视口测试矩阵

至少覆盖：

- 手机：360×800、390×844、430×932。
- 小平板：600–839 宽范围的代表值。
- 中平板：840–1199 宽范围的代表值。
- 桌面触控边界：1199 / 1200。
- 极矮视口：高 560、600、680 等容易触发溢出的边界。

测试应包含页面结构、触控目标、Overflow、可滚动性、SafeArea、键盘遮挡和交互入口。

### 6.6 Batch C 验收

- 手机 8 个目标页面不再只是桌面页面窄宽渲染。
- 平板有独立布局策略和断点测试。
- 桌面现有五视口布局不回归。
- 页面使用同一套 AppModel / Rust 业务能力，不重复造业务层。
- 真实移动端运行证据与 Widget 测试分别登记，不能以 Widget 通过冒充 Android 真机通过。

---

# 第七部分：Batch D —— 桌面体验完善

## 7. 目标

完善大屏信息密度、输入操作、页面导航与交互一致性，同时保持当前三栏壳、PlayerBar、侧栏折叠和 ContextPanel 已有成果。

### 7.1 全局内容限宽（SR-10）

当前审计记录：除 NowPlaying 已有约 1320px 限宽外，多数一级页面在 1920px 下缺少一致的最大内容宽度策略。

任务：

1. 建立统一 `DesktopContentConstraint` 或复用现有组件，不为每页各自硬编码不同宽度。
2. 区分内容表格、卡片网格、设置页、详情页、封面墙等不同信息密度。
3. 1920px 及以上页面应保持可读内容宽度，同时让壳层三栏空间分配自然。
4. 窄桌面 560、640、800、1024、1150 等宽度不得因限宽组件产生空白或溢出。
5. 最大宽度值必须根据视觉证据确定，不凭主观随机指定。
6. 对齐 Header、主内容、滚动区域与 PlayerBar 的视觉边界。

### 7.2 右键上下文菜单（先核验，后修改）

**重要：** 旧审计文档 SR-11 曾将桌面右键菜单记录为缺失，但后续报告的 G7 记录指出 `showSongMenu` 和“下一首播放”命令已经存在，且全仓 `onSecondaryTap` 曾有 8 处命中。因此不得直接按照“全部缺失”重新实现。

任务：

1. 在当前 HEAD 搜索 `showSongMenu`、`onSecondaryTap`、`ContextMenu`、`PopupMenuButton` 和各 SongTile / TrackRow。
2. 确认歌曲表格、首页推荐、搜索、发现、队列、歌单详情的右键行为是否一致。
3. 检查右键是否提供与触控长按 / 更多按钮一致的动作集合。
4. 检查右键是否覆盖文本选择、拖放、双击播放和键盘焦点行为。
5. 如果已存在，补齐缺失页面和测试，不另建重复菜单体系。
6. 如果只在部分组件存在，按可复用的 `SongContextActions` 等实际架构补齐。
7. 不支持的动作保持如实禁用，不展示假入口。

### 7.3 键盘与焦点漫游（SR-13）

- 建立统一键盘焦点顺序。
- 关键页面用 `FocusTraversalGroup` 或等价机制明确区域。
- Tab / Shift+Tab 能按合理顺序移动。
- Enter / Space 对焦点操作生效。
- Escape 关闭弹层、搜索和侧栏二级界面时行为一致。
- 列表方向键、播放快捷键和文本输入冲突时有明确优先级。
- 不把焦点移动逻辑散落成每个页面独立 hack。
- 添加 widget 测试与实际桌面键盘走查。

### 7.4 Header 搜索同步（SR-14）

- 确定 Header 搜索框和 SearchPage 谁是状态权威。
- 页面输入、Header 输入、搜索历史、返回恢复之间使用单一状态流。
- 防止双向监听循环和重复搜索请求。
- 输入中 debounce、回车即时搜索、清空和返回恢复行为定义清楚。
- 测试双向同步、快速输入和过期请求。

### 7.5 首页歌单入口（SR-15）

- 首页“我的歌单”卡片应跳转到具体歌单详情，而不是全部落到曲库。
- 区分用户收藏歌单、自建歌单、远端缓存歌单。
- 复用已有 `PlaylistKey(kind, source, id)`，避免 ID 冲突。
- 无权限或无详情能力时显示真实说明。
- 测试首页入口 → 详情 → 返回 → 播放 / 收藏。

### 7.6 桌面交互一致性

- Hover、focus、pressed、disabled 状态统一。
- 鼠标滚轮与触控板行为不冲突。
- 拖动把手只有在功能真实可用时出现。
- 弹窗、右侧 ContextPanel、队列 Sheet 的 Escape / outside click 关闭规则一致。
- 侧栏折叠、展开过渡中间帧不应出现溢出。
- 保留已有 P1-14 播放栏右簇对齐、P2-11 PlayerBar 常驻等回归护栏。

### 7.7 Batch D 验收

- 1024、1150、1280、1440、1920 五个桌面视口布局正常。
- 1920 及更宽页面内容宽度可读，没有无限拉伸。
- 右键菜单先核验已有能力，再补缺口。
- 键盘焦点移动可用且不破坏快捷键。
- Header 与 Search 状态同步一致。
- 首页歌单入口指向正确详情。
- 现有三栏壳、PlayerBar、ContextPanel 测试无回归。

---

# 第八部分：Batch E —— 下载系统可靠性

## 8. 目标

下载是核心业务，不应只修复页面宽度。必须同时检查 Rust 下载状态机、进度数据、暂停恢复、错误路径和 Flutter 呈现。

### 8.1 当前已知问题（P3-09）

审计记录中有以下现象：

- 已下载字节可能大于音源声明总量，例如显示 `1.4MB / 475.7KB`。
- UI 进度百分比可能超过 100%。
- 560px 窄宽有文本 Overflow。
- 失败原因在状态行中被截断，用户难以查看完整原因。

### 8.2 Rust 下载引擎审计

1. 检查下载总量来自 `Content-Length`、Range 响应、音源元数据还是文件系统实际大小。
2. 检查服务器返回错误 Content-Length、压缩、分片下载和 Range 续传时的统计口径。
3. 区分 `downloaded_bytes`、`expected_bytes`、`verified_file_bytes`，不能将未知总量伪装成 0。
4. 下载完成必须通过文件完整性或实际任务结果确认，不能因进度达到 100% 就提前标记 Done。
5. 暂停 / 继续 / 取消 / 重试必须有状态机和终态约束。
6. 旧任务迟到的进度事件不得覆盖新任务或已完成任务。
7. 下载错误要保留结构化原因，UI 再负责呈现摘要与详情。
8. 评估任务跨会话恢复的既定产品策略；计划既定不做的能力不得擅自扩展范围。

### 8.3 Flutter 下载页

- 进度条视觉值应限制在 0..1；原始字节差异仍需如实展示或解释。
- 总量未知时显示“已下载大小”，不要显示虚假的总量。
- 总量小于已下载值时显示“服务器总量信息不一致”等合理状态，不得简单篡改原始数据。
- 状态、进度、剩余时间、大小格式统一。
- 窄宽下操作按钮收纳到菜单，状态文本可折行或展开。
- 失败原因可展开 / 复制，完整内容不能只留在日志里。
- 不同任务状态（Queued / Resolving / Downloading / Tagging / Paused / Done / Failed / Cancelled）对应不同操作。
- 删除文件与清理记录需要确认。

### 8.4 测试

- 总量准确、未知总量、总量小于已下载量。
- Range 续传与源 URL 变化。
- 暂停解析、暂停下载、迟到结果。
- 取消时临时文件处理。
- 重试失败与重试成功。
- 下载完成后的文件大小和记录一致。
- 360 / 390 / 430 手机和 560 / 640 窄桌面无 Overflow。
- 失败原因完整展示。

### 8.5 Batch E 验收

- 不出现负进度、>100% 视觉进度条或错误标记 Done。
- 原始数据异常有明确解释，不被 UI 隐藏。
- 所有任务状态可解释、按钮动作真实。
- Rust manager 测试和 Flutter widget 测试覆盖状态机。
- 关键路径有真实下载运行证据。

---

# 第九部分：Batch F —— 队列能力与桌面系统集成

## 9. 目标

实现用户真正可用的队列排序和桌面系统媒体集成，不通过 UI 假装后端支持。

## 9.1 队列排序与队内跳播（P2-09）

当前矩阵明确部分队列动作因为缺少后端命令而禁用。不得只在 Flutter 侧更改列表顺序。

### 任务

1. 审计 `QueueService`、`ApplicationCommand`、`FfiCommand`、`QueueState` 和持久化行为。
2. 明确队列项身份：不能只用 index；应使用稳定 song/queue entry identity，避免并发插入后 index 漂移。
3. 设计 `QueueMove` / `QueueInsertNext` / `QueuePlayAt` 等业务命令，名称以现有接口为准。
4. 定义拖动排序、移动到下一首、跳播、删除的事务语义。
5. 并发播放结束自动推进时，队列变动不能丢失或跳错歌曲。
6. Flutter 拖动成功后以 Rust 回传的真实队列快照为准；不能只维护 UI 本地列表。
7. 错误时恢复 UI，不产生虚假排序状态。

### 测试

- 拖动第一项到最后、跨组移动、边界位置。
- 当前播放项移动后，索引仍指向同一曲目。
- 自动切歌与拖动同时发生。
- 删除当前播放项、删除前一项和下一项。
- 队列重复歌曲必须能够区分条目。
- 多次连续拖动、快速撤销和错误恢复。

## 9.2 Linux MPRIS（P2-05）

项目 TUI 已有 Linux D-Bus / MPRIS 相关能力记录，但 GUI Flutter 路径曾实测没有注册 `org.mpris.MediaPlayer2.*`。应评估复用 Rust 侧既有逻辑，而不是从零实现两套 D-Bus 服务。

任务：

1. 查找当前 TUI MPRIS 实现、其与 PlayerBackend 的耦合及可复用边界。
2. 提取 GUI 可复用的 MPRIS adapter，或证明需要独立实现。
3. 将 Flutter 当前播放状态映射到 MPRIS：metadata、playback status、position、volume、canSeek、loop/shuffle 等可支持项。
4. D-Bus 命令回流必须走 ApplicationService，不直接改 UI 状态。
5. 应用启动、退出、多个实例、服务名冲突有处理策略。
6. D-Bus 服务只在 Linux 桌面启用，不影响 Android、Windows、macOS。

### 验收

- `busctl --user list` 或等效工具能查到唯一 MPRIS 服务。
- `playerctl` / 桌面媒体控制中心可执行 Play / Pause / Next / Previous / Seek（只对实际支持项开放）。
- Metadata、进度、封面一致。
- 应用退出后 D-Bus 服务释放。
- 桌面播放路径不回归。

## 9.3 Windows / macOS 系统媒体集成

- 先核验当前 Windows SMTC、macOS Now Playing 实现所在模块。
- 统一抽象名称和行为，但不强求三个系统共用同一实现代码。
- 不重复注册平台媒体会话。
- 系统动作必须反馈到真实播放引擎与 Rust 状态。
- 各平台单独有运行时验证记录。

---

# 第十部分：Batch G —— 既有关键缺陷运行时闭环

## 10. 目标

将已有代码和 Widget / Unit 测试推进到真实 App 行为证据。每条缺陷都必须说明验证设备、版本、输入数据、操作步骤、日志和截图路径。

## 10.1 P1-20：全部音源切回聚合

- 已有 sentinel 与 widget 测试，不能重复实现。
- 真实运行：选择单音源 → 切全部音源 → 确认聚合请求加载全部启用音源 → 再次切单音源。
- 验证 Discover、Leaderboard、Categories 等相关入口，不只测试歌曲列表。
- 核对切换时旧请求、缓存和 loading/error 状态。
- 证据齐后才能关闭矩阵。

## 10.2 P2-16：Soda 封面 URL 闭环

- Rust 现有组合 URL 解析单元测试通过，不代表真实图片链成功。
- 找到目标歌曲 Light It Up 的真实音源与封面原始字段。
- 验证组合 URL 结果、HTTP 状态码、重定向、Content-Type、图片解码、缓存和 UI 呈现。
- 区分 URL 404、403、TLS、解码失败、无 URI、占位图判断错误。
- 不在日志中泄露 Cookie / token / 完整签名 URL。
- 测试至少覆盖有效组合 URL、缺 URI、服务器拒绝、图片内容无效。

## 10.3 P2-17 / P2-18：歌词重取与 NowPlaying 布局

代码和测试层已修复：

- 有歌词：双列布局，歌词面板显示。
- 无歌词：单列布局，保留可达的重取入口。
- `LyricsRetryButton` 有 loading、防重复、成功恢复、失败恢复、12 秒超时兜底和切歌复位。
- Rust `LoadLyrics` 成功 / 失败已增加测试。

仍需真实运行时验证：

1. 无歌词打开 NowPlaying，单列布局正确。
2. 重取按钮触发真实命令，loading 状态与用户反馈合理。
3. 成功取回歌词后切换双列。
4. 失败时提示可理解且可以重新点击。
5. 切歌后旧歌词结果不污染新歌曲。
6. 页面退出后没有异步回调写入已销毁组件。
7. 有歌词时双列视觉比例和滚动体验正常。
8. 极长标题、极长歌词、无翻译、无封面等状态正常。

## 10.4 P2-04 / 平台窗口几何

- 使用窗口管理器返回的实际可用尺寸，而不是仅依赖请求尺寸。
- niri / Wayland / XWayland 下分别核验窗口尺寸与屏幕缩放。
- 截图测试必须保存实际渲染视口尺寸证据。
- 窗口最大化、恢复、调整大小、跨屏切换有记录。

---

# 第十一部分：Batch H —— 稳定性与崩溃诊断

## 11. 目标

对主 isolate 卡死、OpenGL timeout、进程静默退出建立能定位根因的证据链。禁止只增加 try/catch 或 panic hook 后宣布问题解决。

## 11.1 P0-01 主 isolate 概率性卡死

### 先采集信息

- 事件速率和最后事件类型。
- Dart isolate 是否仍运行、CPU 使用率、内存和线程状态。
- Rust Tokio task 数量、长时间阻塞位置、同步锁持有时间。
- FFI 长调用是否占用 Flutter UI isolate。
- 本地曲库加载、状态快照、封面解码、列表 build、日志写盘是否会阻塞 UI。
- 搜索、播放进度、下载状态是否发生事件洪泛。

### 实验矩阵

- 空曲库 / 1k / 10k / 30k 曲库。
- 空闲、播放、切歌、搜索、下载、切页组合。
- 连续运行 30 分钟、1 小时及更长会话（按可复现预算记录）。
- 事件洪泛与网络慢响应。
- 休眠 / 唤醒 / 锁屏 / 窗口调整。

### 诊断要求

- 区分 Flutter UI isolate 卡死、Dart event loop 被长同步函数阻塞、Tokio runtime 饥饿、FFI 调用阻塞、原生音频引擎卡死。
- 对可复现路径做最小化样例。
- 不能仅通过“本次没有卡死”关闭缺陷。

## 11.2 P1-05 / P2-08 OpenGL timeout 后进程消失

- 分别核验 niri Wayland、XWayland、XWayland Satellite、不同窗口尺寸和全屏模式。
- 记录 GPU 型号、驱动、Flutter renderer、OpenGL/Vulkan 路径、libmpv 渲染模式。
- 检查窗口 resize 与视频帧提交竞争。
- 收集 core dump、系统日志、Flutter 日志、Rust panic 日志、GPU reset 信息。
- 区分 Rust panic（可 unwind）与 SIGABRT / 驱动 / 引擎级进程终止（可能不可 unwind）。
- 尝试建立最小复现，不得用无限重试隐藏崩溃。

## 11.3 故障恢复策略

- UI 仍可恢复时提供错误提示和重试入口。
- 音频引擎失效后不能显示虚假的 Playing。
- Rust runtime 未启动时明确告知，不让 UI 永久假 Loading。
- 日志记录操作上下文，但不保存用户隐私与认证信息。
- 故障报告要包含无法捕获的边界，不夸大 crash hook 的覆盖范围。

---

# 第十二部分：Batch I —— 质量工程与持续验证

## 12.1 Golden 视觉回归

当前审计记录全仓尚未建立正式 `matchesGoldenFile` / `goldenFileComparator` 基础设施。需要先设计再实施：

1. 建立 Golden 目录规则和命名规则。
2. 统一测试字体、设备像素比、视口、颜色主题、数据种子和 locale。
3. 建立首次基线生成与更新流程。
4. CI 只做比较，不自动更新基线。
5. 更新 Golden 必须人工审查 diff，并在 PR / 报告记录原因。
6. 为关键页面建立代表性基线，不追求给所有组件无差别生成截图。
7. 保留实际运行时截图与 Widget Golden 的区别。

建议优先页面：Home、Discover、Search、Library、Downloads、Settings、Playlist Detail、NowPlaying、MobileShell、TabletShell。

## 12.2 无障碍

- 语义标签覆盖图标按钮、播放/暂停、进度条、封面、菜单、导航项。
- 焦点可见，键盘与屏幕阅读器顺序合理。
- 文字缩放不导致主操作不可达。
- 主题对比度覆盖深色、浅色和动态主题。
- 状态变化（下载进度、播放状态、错误通知）具有合适语义。
- 不以“颜色变化”作为唯一状态提示。

## 12.3 性能基准

建立可重复的性能基准，先建立当前基线，再设目标：

- 冷启动和初始化时间。
- FFI `state()` 与 DTO 转换时间。
- 本地曲库分页时间。
- 搜索首屏和翻页耗时。
- 歌曲列表 1k / 10k / 30k 行滚动表现。
- 封面首次加载、缓存命中、缓存清理。
- NowPlaying 进度更新的 UI rebuild 范围。
- 下载高频进度事件吞吐。
- Rust CPU / 内存与 Dart heap。

不得先编造性能阈值。先保存测量样本、设备和环境，再设定可验收目标。

## 12.4 日志与可观测性

- 建立稳定诊断 ID 和跨 Rust/Dart 的关联 ID。
- 日志分级：debug / info / warn / error。
- 生产用户日志不输出 Cookie、授权头、代理凭据、完整签名 URL。
- 对异常事件流、命令溢出、播放器宿主断开、请求超时、状态重同步记录结构化信息。
- 对用户可见通知与诊断日志分离。
- 日志落盘失败不得使主业务崩溃。

## 12.5 跨平台验证

| 平台 | 需要验证 | 当前限制 |
|---|---|---|
| Linux | libmpv、窗口、D-Bus/MPRIS、niri / Wayland、XWayland、文件系统 | 可作为主要桌面运行时验证环境 |
| Windows | libmpv DLL、窗口、快捷键、SMTC、文件路径、打包 | 需要真实 Windows 运行验证，不能只看构建通过 |
| macOS | libmpv 链接、签名/隔离、窗口、Now Playing、文件权限 | Intel / Apple Silicon 分开记录 |
| Android | just_audio、后台播放、媒体通知、锁屏、音频焦点、SAF、通知权限 | 遵循用户当前限制；没有用户授权不启动 APK / Gradle / 模拟器 |
| iOS | 当前仓库与产品范围待确认 | 不擅自扩展为本批次必做目标 |

---

# 第十三部分：统一开发工作流

## 13. 每个 Batch 必须遵循的固定流程

### Step 1：读取现状

- `git status --short --branch`
- `git log -5 --oneline`
- 阅读相关设计指南、缺陷矩阵和报告。
- 搜索功能是否已存在、是否有测试、是否有调用者。
- 追踪 UI → Dart Adapter → FRB → Rust API → ApplicationService → Runtime / Host 的完整链路。

### Step 2：建立现状矩阵

每项需求标记为：

- 已完成且已验证。
- 已实现但验证不足。
- 部分实现。
- 存在缺陷。
- 尚未实现。
- 受环境限制未验证。
- 需要产品决策。

每项必须附路径、行号或测试名称。

### Step 3：最小修改计划

- 修改哪些文件。
- 每个文件为什么必须改。
- 是否跨 Rust / Dart / FFI / 平台插件。
- 是否需要重新生成 FRB 文件。
- 是否改变公共接口。
- 对既有业务兼容的影响。
- 需要新增哪些测试。

### Step 4：实现

- 小批量修改，保持 diff 可审查。
- 不做无关格式化，不重排整个文件制造噪音。
- 不改生成文件的手写内容。
- 不引入第二套状态管理或重复业务规则。
- 任何命令 / Event / DTO 修改必须同步 Rust、Dart、生成代码、测试和文档。

### Step 5：格式和静态检查

按仓库实际目录执行，不得假设当前工作目录：

```bash
# Flutter
 dart format --output=none --set-exit-if-changed flutter/lib flutter/test
 (cd flutter && flutter analyze --fatal-infos)

# Rust
 cargo fmt --all -- --check
 cargo test --workspace
```

Rust Clippy 必须使用当前 CI 的准确命令。若历史存在 `#[must_use]` 等告警，必须记录基线与本次新增告警差异，不得将旧告警说成新修复，也不得放宽门禁掩盖新增告警。

### Step 6：专项测试

- 每个变更文件对应明确专项测试。
- 每个跨层接口至少有 Rust 层和 Dart 层测试。
- 重要业务链路增加集成测试。
- UI 页面新增结构、交互和状态测试。
- FFI 高风险路径做故障注入和压力测试。

### Step 7：完整回归

- Flutter 定向测试。
- Flutter 全量测试。
- Rust 定向测试。
- Rust workspace 测试。
- 需要时做 Linux / Windows / macOS / Android ABI 编译检查。
- 真实运行时测试按设备能力分别记录，不得用编译成功代替运行成功。

### Step 8：文档与缺陷矩阵

- 更新对应审计文档。
- 更新 `docs/redesign/04-defect-matrix.md`。
- 新增工作报告。
- 每条缺陷标注代码、单测、Widget、集成、真实运行时证据的完成情况。
- 未验证必须明确保留。

### Step 9：交付审查

交付前展示：文件清单、关键 diff、测试命令、退出码、通过/失败数量、未完成问题、Git 状态。没有得到明确授权不提交、不推送、不合并、不发布。

---

# 第十四部分：最终验收定义

## 14.1 架构层

- Rust 和 Dart 的职责划分清楚。
- FRB 公共契约有完整清单。
- 关键移动播放命令不静默丢失。
- 事件丢失后的恢复语义清楚。
- Controller / Stream / Bridge / Runtime 生命周期可测试。
- 请求关联与播放代次能隔离迟到响应。
- 快照传输经量测并避免不必要的大列表复制。
- 错误结构稳定、日志脱敏。
- Codegen 可重复、CI 可检查。

## 14.2 UI 层

- 所有 44 套主题预设可用。
- ThemeData 与 Vx Tokens 同源。
- Light / Dark / System / Dynamic Color 一致。
- 字体层级和 CJK / Monospace fallback 正常。
- 手机 8 个页面具有真实移动布局。
- 平板页面具有独立布局策略。
- 桌面五视口无溢出且大屏内容不无限拉伸。
- 右键、键盘焦点、搜索同步、首页歌单入口正确。

## 14.3 业务层

- 下载进度与状态机准确。
- 队列真实支持排序与跳播，或诚实说明暂不支持。
- MPRIS 等系统能力只对真实完成的平台开放。
- P1-20 / P2-16 / P2-17 / P2-18 有真实运行时证据。
- 音源、封面、歌词、播放、收藏、歌单和本地音乐不回归。

## 14.4 稳定性与质量

- P0-01 / P1-05 有根因结论或明确受限的复现报告。
- Golden 基线和更新流程正式建立。
- 无障碍和性能测试有基线。
- 跨平台运行验证与编译验证分开报告。
- CI 通过，SDK 固定版本和 codegen 版本日志可核实。
- 工作报告和缺陷矩阵与实际代码状态一致。

---

# 第十五部分：AI Agent 执行指令（可直接复制）

以下内容是正式执行入口。执行 Agent 必须先读取仓库文件，再按照 Phase 0 开始，不得跳过审计直接批量改代码。

> 你现在负责执行 Flutterfox 第二轮工程演进计划。仓库为 `emoeem/flutterfox`，目标分支 `feat/ui-redesign`，计划基线 `e58e7c2`。第一原则是保留现有 Flutter + Rust + flutter_rust_bridge 架构，不进行整体 Rust → Dart 重写。
>
> **第一步必须执行 Phase 0：** 检查当前 HEAD、Git 工作区、最新 GitHub Actions、Flutter/Rust/FRB 版本；阅读现有审计、缺陷矩阵、UI 唯一规格、Session Handoff。确认仓库已经包含计划基线，并核实门禁恢复提交的最新 CI 结果。先输出基线报告，不要在没有说明的情况下修改生产代码。
>
> **第二步执行 Batch A 的只读审计：** 完整梳理 Rust API、DTO、Command、Event、Snapshot、AppModel、移动播放命令桥、HostPlayerBackend、Controller、Stream、Tokio Runtime 的调用链和生命周期。特别检查容量 64 的移动播放广播通道、`Lagged` 行为、无人订阅时的命令丢弃、命令执行反馈、Dart 命令泵取消、播放代次和状态回流。以上是待验证风险，不允许未经验证就认定为 Bug。
>
> **第三步：** 对每项 FFI 风险给出代码证据、复现步骤、最小修复方案、测试方案与兼容影响。只有确认必要时才修改协议。任何关键命令修改必须增加 command ID / generation / 结果反馈或等价机制，并覆盖队列积压、通道关闭、重连和过期命令测试。不要用简单的 `broadcast` → `mpsc` 替换作为未经论证的结论。
>
> **第四步：** Batch A 完成并验收后，按 Batch B → C → D → E → F → G → H → I 推进。主题系统统一使用单一主题真源；44 套主题全部验证；手机和平板独立布局但共享业务层；桌面大屏限宽与键盘交互；下载状态机与真实进度；队列协议和 MPRIS；既有缺陷真实运行时验证；主 isolate / GL 崩溃诊断；Golden、无障碍和性能工程。
>
> **每个 Batch 固定流程：** 读取现状 → 标注已完成/部分/缺陷/未实现/未验证 → 最小计划 → 修改 → 格式检查 → Analyze / Rust 检查 → 定向测试 → 全量测试 → 必要的平台构建和真实运行时验证 → 更新缺陷矩阵和工作报告 → 展示 Git diff 与工作区状态。
>
> 不要重复实现仓库已有的右键菜单、主题功能、播放功能或其他现有能力。特别是右键菜单，先核对 `showSongMenu` 和当前调用位置，旧审计与后续报告存在口径差异，必须以当前 HEAD 为准。
>
> 不要删除业务断言，不要用 mock 测试替代全部真实集成测试，不要伪造平台能力，不要为了测试通过而弱化验收条件。Android APK、Gradle、AVD、模拟器相关操作遵循用户明确授权范围；没有授权不得启动。
>
> 不执行 `reset`、`checkout`、`clean`、`stash`、`rebase`，不覆盖用户未提交改动。未获得本次明确授权前，不提交、不 push、不合并、不发布。每一项验证必须记录真实命令、退出码、通过/失败数量、平台、SDK 版本和时间。未实测项目标记为未验证。
>
> 每批完成先提交审查报告和可审查 diff，再决定是否进入下一批。严禁一次性把所有 Phase 混成一个大改动。

---

# 附录 A：关键代码入口

| 职责 | 文件 |
|---|---|
| FRB Rust API | `ffi/src/api.rs` |
| FFI DTO / Controller / Stream | `ffi/src/lib.rs` |
| Rust 应用事件 / 命令 | `application/src/event.rs` |
| Rust 应用状态 | `application/src/state.rs` |
| Rust 应用服务 | `application/src/service.rs` |
| 移动转发型播放器 | `application/src/services/host_player.rs` |
| Rust Runtime | `runtime/src/lib.rs` |
| Dart FRB API wrapper | `flutter/lib/src/bridge/api.dart` |
| Generated Dart models | `flutter/lib/src/bridge/lib.dart` |
| Generated FRB implementation | `flutter/lib/src/bridge/frb_generated.dart` |
| Dart AppModel | `flutter/lib/src/app_model.dart` |
| 移动播放指令桥 | `flutter/lib/src/bridge/host_player_bridge.dart` |
| 移动音频播放器 | `flutter/lib/src/playback/mobile_audio_player.dart` |
| 媒体通知与焦点 | `flutter/lib/src/playback/voicefox_audio_handler.dart` |
| 应用入口与平台引导 | `flutter/lib/main.dart` |
| Flutter SDK / 依赖 | `flutter/pubspec.yaml` |
| CI 工作流 | `.github/workflows/ci.yml` |
| Flutter 发布工作流 | `.github/workflows/release-flutter.yml` |
| UI 唯一执行规格 | `docs/redesign/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` |
| 第二轮逐页审计 | `docs/redesign/second-round/01-implementation-audit.md` |
| 缺陷矩阵 | `docs/redesign/04-defect-matrix.md` |

# 附录 B：禁止的捷径

- 不因担心 FFI 就整体重写 Rust 后端。
- 不让 Dart 和 Rust 各维护一套音源解析逻辑。
- 不让 Flutter 页面直接操作 Rust 内部状态锁或 Tokio Channel。
- 不把所有事件都改为“每次拉全量状态”。
- 不以更大的 broadcast buffer 代替可靠消息语义。
- 不以 `catch (_) {}`、字符串 contains、固定延迟等方式掩盖协议错误。
- 不通过删除旧测试断言修复新行为冲突。
- 不把编译通过当作真实平台运行通过。
- 不把 Android widget 测试当作 Android 真机验证。
- 不把桌面页面缩窄当作移动端独立设计完成。
- 不把 44 套主题都映射成同一个 seed 色。
- 不把视觉进度条夹到 100% 后就掩盖下载原始字节数异常。
- 不重复实现已存在的菜单、系统集成或其他能力。
- 不在没有证据时关闭 P0 / P1 缺陷。

# 附录 C：每批工作报告模板

```markdown
# 工作报告：<Batch 名称>

## 基线
- 分支：
- HEAD：
- 工作区状态：
- Flutter：
- Dart：
- Rust：
- FRB / Codegen：
- CI Run：

## 审计结论
- 已完成：
- 部分实现：
- 已确认缺陷：
- 未实现：
- 未验证 / 环境阻断：

## 修改清单
| 文件 | 修改 | 根因 / 必要性 |
|---|---|---|

## 契约 / 行为变化
- Rust API：
- DTO / Command / Event：
- Dart Adapter：
- 平台行为：
- 兼容策略：

## 验证
| 命令 / 操作 | 平台与环境 | 退出码 | 通过 / 失败 | 证据 |
|---|---|---:|---:|---|

## 运行时证据
- 操作步骤：
- 设备 / 系统：
- 截图 / 日志：
- 未覆盖情况：

## 缺陷矩阵更新
- 已关闭：
- 继续开放：
- 新增：

## Git 状态
- 修改文件：
- 未跟踪文件：
- 是否提交：
- 是否推送：
- 未执行的操作：

## 下一批次建议
```

---

**计划结束。** 先完成 Phase 0 和 Batch A 的审计，再进入主题系统与 UI 批次。整个项目继续保留 Rust 核心业务资产，所有跨语言通信风险必须通过明确契约、故障注入和可重复测试解决，而不是通过整体重写语言来规避。

# FFI 可靠性风险判定与加固设计（Batch A 审计交付）

> 状态：生效中（审计结论，待用户确认后实施修复） · 日期：2026-11-14 · 审计 HEAD：`4e40ee7` · 接口清单见 [ffi-contract-inventory.md](ffi-contract-inventory.md) · 判定口径：**已证实（静态读码）/ 已排除 / 无法复现（静态）/ 需设备验证**；不把风险预判为 Bug，修复在确认后分小批实施

## 一、风险判定总表（R01-R12）

| 编号 | 风险 | 判定 | 一句话结论 |
|---|---|---|---|
| FFI-R01 | 移动 Play 在 Dart 订阅前派发即静默丢失 | **已证实** | 初始化窗口数百 ms~秒级，窗口内点播丢指令，Rust 恒卡 Loading |
| FFI-R02 | 慢 Play 串行阻塞 Pause/Stop/切歌 | **已证实（串行结构）；延迟幅度需设备验证** | 命令泵逐条 await，暂停响应延迟≈整次加载时长 |
| FFI-R03 | >64 条积压时 Lagged 覆盖最旧命令且无重同步 | **已证实（静态形态）；实际触发需压测** | 最旧（通常是第一条 Play）被物理覆盖；Dart 只 continue 不重拉状态 |
| FFI-R04 | 非Play命令无代次，过期 Seek/Pause 可误执行 | **已证实** | 仅 Play 带 generation；lag 后旧命令直打当前曲目 |
| FFI-R05 | 双 play 并发交错（后点先播） | **需设备验证（并发结构静态成立）** | generation 在 resolve 前自增，完成顺序不定 |
| FFI-R06 | 无 per-command ack；单命令异常杀死整条命令泵 | **已证实** | 播放器异常与流异常共用 catch，宿主失联 Rust 无感知；dispose 不可等待、pump 不可停止且生产不调用 |
| FFI-R07 | 宿主断开后 Rust 播放状态永久冻结 | **已证实（静态残留逻辑）；真机断连需设备验证** | watch 恒留最后值、观察泵无超时清理，UI 恒持 Playing/Loading |
| FFI-R08 | 事件分类与可恢复性（一次性事件丢失策略） | **已证实（分类成立）** | Rust 每事件尾随全量 StateChanged 快照被 Dart 整体丢弃（无该分支）；一次性事件（Notification/二维码/Sync 10 个/Browse 应答）丢即丢 |
| FFI-R09 | 订阅/快照顺序窗口 + 无 revision + local_songs 全量克隆 | **已证实（静态成本路径）；卡顿幅度需设备验证** | attach 先拉快照后订阅有丢失窗口；并发 _refreshState 旧可覆盖新；活跃下载每 500ms 一次全量曲库克隆 |
| FFI-R10 | 字符串协议与 String 错误 | **已证实** | 播放状态串两处重复定义；取消语义编码在 message 文本「同步已取消」；错误全 String |
| FFI-R11 | codegen 版本漂移 | **已排除（当前一致）** | 双侧 2.13.0 一致 + smoke 测试断言；遗留 pubspec caret 范围风险 |
| FFI-R12 | 进程级 Runtime 无任务取消/优雅关停 | **已证实（有意设计，无取消机制）** | 播放泵/downloads_bridge 永不退出；MpvEngine Drop 因任务持有 Arc 不会执行，依赖 OS 回收 |

## 二、关键证据摘录（file:line 实测，HEAD 4e40ee7）

### R01 初始化丢失窗口
- `application/src/services/host_player.rs:88` `broadcast::channel(64)`，初始 receiver 被立即丢弃；`:146-161` `play_with_headers` `let _ = self.commands.send(Play{..})`，无消费者时 send 返 Err 值被丢弃，且 `:160` 无条件 `state.send_replace(Loading)`（指令丢了状态仍进 Loading）。
- `host_player.rs:356-363` 测试 `play_without_subscriber_still_accepts` 把「丢指令但接受」固化为预期行为。
- 窗口链：`main.dart:225-226,282-301` runApp 先行、`_bootstrapTouch` unawaited，newHost→attach→configureAudioService（AudioService.init 平台通道往返）→hostPlayerStream→start()，订阅前数百 ms~秒级。
- `application/src/service.rs:384-398` QueueAdd 空队列自动触发 play：正常用户操作可落入窗口。

### R03/R04 Lagged 与代次
- `ffi/src/lib.rs:1332-1340` Lagged → `Err("host player stream lagged, skipped {n} commands; resubscribe and resync")`；`api.rs:93-94` 注释宣称「由 Dart 侧重订阅并重拉状态」，实现不符。
- `host_player_bridge.dart:146-150` `message.contains('lagged')` 字符串匹配 → `continue`，不重订阅不重拉状态；Closed → 非 lagged → pump 退出。
- `host_player.rs:41-62` 仅 Play 携带 generation；`host_player_bridge.dart:158-185` _dispatch 零校验逐条执行；`host_player.rs:187` seek 本地乐观 `position.send_replace` 覆写真实回流位置。

### R06/R07 反馈与断连
- `host_player.rs:149,165,169,173,179,183,218-220,239` 全部 `let _ = send`；`play_with_headers` 恒 `return true`（:161）。
- `host_player_bridge.dart:146-153` 命令异常与源流异常共用同一 catch：非 'lagged' 即视为流关闭退出 pump，单条 just_audio 异常即宿主永久失联。
- `host_player.rs:117-129` watch 用 send_replace 永久保留最后回流值；`application/src/service.rs:166-212` 观察泵只读 watch，无超时/清理/心跳。
- `host_player_bridge.dart:249-255` dispose 全 fire-and-forget 且返回 void 不可等待；`_pumpCommands`（:134-155）无停止机制；生产路径从不调用 dispose（main.dart:294-298 内联构造不留引用）。
- `voicefox_audio_handler.dart:32-54` AudioService.init 无幂等守卫（二次调用会抛，当前无二次调用路径，风险 dormant）；`:58-66` 订阅 player/model，dispose（:188-192）不 removeListener；进程级单例由 main.dart:225/289-292 保证。

### R08/R09 事件与快照
- `application/src/service.rs:1771-1780` emit() 每发非 StateChanged 事件都尾随广播一份 `StateChanged(Box<ApplicationState>)` 全量快照；Dart `_handleEvent`（app_model.dart:272-336）**无 state_changed 分支**，快照整体被丢弃，恢复一律 `_refreshState` 主动拉取。
- 31 事件变体分类（event.rs:240-402 → lib.rs:717-736）：状态类可由 state() 恢复；一次性（Notification/QrLogin/Sync+Push 10 个/BrowseLoaded/CustomPlaylistCreated 应答）丢即丢；CustomPlaylistCreated 走 `_createdWaiters` Completer（app_model.dart:387-394），丢失=Future 悬挂。
- `_attach` 顺序：先 state()（:218）后 subscribe（:219），窗口内事件丢失且初始路径不补拉。
- 无全局 revision：并发 `_refreshState`（unawaited，5 处调用点）完成顺序不定，旧快照可覆盖新快照；进行中 refresh 完成于 progress 事件后会把 position 回滚 ≤250ms。
- local_songs 成本路径：`ffi/src/lib.rs:1217-1232` state() = application.state() 整克隆 + `local_source().all_songs()`（source/src/local/mod.rs:550-556）逐个 clone + SongDto 二次映射（:24-36）；触发面 app_model.dart:277-320 七类事件全触发；`runtime/src/lib.rs:408-421` 活跃下载每 500ms 轮询 DownloadsChanged → **活跃下载期间每 500ms 一次全量曲库克隆**；30k 曲库单次 ≈ 30k SongInfo 克隆 + 30k SongDto 重建。🔧真实卡顿需设备验证。

### R12 Runtime
- `runtime/src/lib.rs:22-50` OWNED_RUNTIME OnceLock 进程级；ApplicationRuntime 为 new_desktop/new_host 局部变量（ffi/src/lib.rs:1161,1186），任务经 service.clone() 持 Arc 存活（runtime/src/lib.rs:18-21）。
- 播放泵 spawn 无 abort（service.rs:191，watcher sender 被自身持有实际永不退出）；downloads_bridge 死循环无取消（runtime/src/lib.rs:413）；qr/sync/push 有显式取消标志（service.rs:81-83,1449）。
- 无优雅关停；`MpvEngine::Drop`（player/src/engine.rs:1096-1098）因任务持有 Arc 不执行，依赖 OS 回收。

### R10 协议字符串
- 播放状态串 `idle|loading|playing|paused|stopped` 两处重复定义：`application/src/state.rs:91-107` 与 `ffi/src/lib.rs:1069-1077`。
- 取消语义编码在 message 文本「同步已取消」（service.rs:342,373 + app_model.dart:607,642 字符串比较）。
- 事件 kind 15 token（event.rs:444-461）、BrowseKind 12 token（:404-441）；qr 状态 Debug 派生小写（service.rs:1445）；错误全 String（lib.rs:1234,1332-1350）。

## 三、加固设计方向（按计划书 §4.3 语义分类，先分析后选型）

命令语义分层（不变更业务协议前提下引入可靠性元数据）：

| 命令类别 | 示例 | 可靠性要求 | 处理方向 |
|---|---|---|---|
| 状态转换命令 | Play/Pause/Resume/Stop | 有序 + 执行反馈或失败反馈 | 有界可靠队列 + commandId + 结果回流 |
| 位置控制 | Seek | 按播放代次合并旧位置，不跨曲目误执行 | commandId + generation + latest-wins |
| 连续参数 | SetVolume/SetSpeed | 允许合并到最新值 | latest-value 合并 |
| 诊断/状态回流 | state/position/duration | 高频只保最新 | watch/snapshot（现状已是） |

## 四、最小修复候选清单（按风险优先级排序；实施前逐项过用户确认）

| # | 修复 | 对应风险 | 涉及文件 | 测试方案 |
|---|---|---|---|---|
| 1 | Lagged/断连重同步：pump 收到 lagged 重拉播放状态（或 Rust 注入 Resync）；不再以 message.contains('lagged') 为协议（改结构化错误枚举） | R03/R04 | host_player_bridge.dart、ffi/src/lib.rs、ffi/src/api.rs | 压缩队列容量模拟 lag → 断言重同步后状态一致 |
| 2 | 控制命令携带 commandId+generation，_dispatch 过滤过期命令 | R04 | host_player.rs、ffi/src/lib.rs（DTO）、host_player_bridge.dart | 跨曲目旧 Seek/Pause 迟到 → 断言被丢弃并记录 |
| 3 | 命令异常与流异常分捕获，命令失败不退出 pump 且回流错误 | R06 | host_player_bridge.dart | 注入播放器异常 → pump 存活、错误回流、后续命令可执行 |
| 4 | 订阅前 Play 补投/重放：Dart 订阅完成后拉取 pending Play（或 Rust 端保留最后未确认 Play） | R01 | host_player.rs、ffi/src/api.rs、host_player_bridge.dart | 订阅延迟注入 → 断言窗口内 Play 最终执行 |
| 5 | dispose 可等待 + pump 可终止（stop 标志/Completer 关闭 next 等待） | R06 专项 | host_player_bridge.dart | dispose 时有挂起 next()/正在 play() → 无泄漏、无已释放对象调用 |
| 6 | Rust 侧宿主看门狗：watch 状态超时回落 Stopped/错误态 | R07 | host_player.rs、service.rs | 模拟宿主停止回流 → 超时后状态回落且 UI 可见 |
| 7 | Dart 落地 state_changed 快照分支（_state 直接吃尾随快照，替代多数 _refreshState 全量重拉） | R08/R09 | app_model.dart | 丢事件后重订阅 → 快照一致；新旧快照并发 → 无回滚 |
| 8 | local_songs 拆出 state()（独立 localSongs() 接口 + 仅扫描完成/曲库事件后拉取） | R09 | ffi/src/lib.rs、app_model.dart | 30k 曲库 state() 调用不再携带全量曲库；播放进度零曲库传输 |
| 9 | _refreshState 单飞 + 完成序号守卫（最后一次发起者胜出） | R09 | app_model.dart | 并发 refresh 注入 → 最终态=最新发起 |
| 10 | _attach 改先 subscribe 后拉快照 | R09 | app_model.dart:216-228 | 窗口事件不丢失 |
| 11 | 事件泵死亡可见化：重试上限 + streamDead 标志 + 用户可见重试入口 | R08 | app_model.dart | 持续 Err 注入 → 标志置位、UI 可见、可重连 |
| 12 | 慢 Play 与控制命令分流（控制命令不排队在 Play 后） | R02 | host_player_bridge.dart | 慢 Play 注入 → Pause 响应时间不随加载时长增长 |
| 13 | play 全链互斥或最新请求胜出（排队/取消旧请求） | R05 | service.rs、services/playback.rs | 双 play 并发 → 最终播放=最后请求且 UI 一致 |
| 14 | emit() 尾随 StateChanged 降级（轻量信号或裁剪大字段） | R08/R09 | service.rs:1771-1780 | 事件广播不再携带全量克隆（与 #7 配套后才有意义） |
| 15 | 协议字符串单一来源 + 取消改独立 cancelled 字段 | R10 | ffi/src/lib.rs、application/{state,event,service}.rs | 常量单源测试；取消不再依赖文本匹配 |
| 16 | downloads_bridge 节流（≥1s 最小间隔或 diff 广播） | R09 | runtime/src/lib.rs:408-421 | 活跃下载时曲库克隆频次下降到目标值 |
| 17 | FRB 版本锁紧（pubspec 精确 =2.13.0）+ CI codegen 一致性检查（再生成 diff 即失败） | R11 | flutter/pubspec.yaml、ci.yml | CI 生成一致性 job |
| 18 | 事件泵/命令泵生命周期测试补齐（state()、event_next、双泵守卫） | 审计缺口 | 测试文件 | 覆盖矩阵第四节三行「无」缺口 |

修复分批建议（可独立验收、可回退）：
- **批次 A-1（移动命令可靠性）**：#1+#3+#4+#5+#6 已实施（commit `f56e08b`，见下「A-1 实施记录」）。
- **批次 A-1b（#2 命令代次/ID + ack 契约）**：已实施（commit `5e6f066`，见「A-1b 实施记录」）。
- **批次 A-2（事件与快照）**：#7+#9+#10+#11+#14+#8+#16，见「A-2 实施记录」。
- **批次 A-3（协议与工程）**：#15+#17+#18（#16 已并入 A-2）。

## A-1b 实施记录（2026-11-14，commit `5e6f066`）

| 修复 | 实施 | 测试 |
|---|---|---|
| #2 R04 命令契约升级 | HostPlayerCommand 8 变体携带 command_id（后端 send_command 统一打戳）+ 歌曲域指令携带发送时刻 generation（Play 保留解析代次）；DTO 镜像 + FRB 2.13.0 再生成（幂等哈希校验通过）；新 FFI hostPlayerAck | Rust `commands_stamped_and_acked`（id 单调/Play 代次不覆写/歌曲域补代次/ack 销账/无消费者不登记）；Dart `FFI-R04：歌曲域指令代次落后宿主 → 丢弃并 ack 失败` |
| #2 R06 ack 回销 | Dart _runCommand 三段化（过期过滤→_execute→ack 成功/失败均回销）；HostStateSink.ack 抽象 + RustHostStateSink + pending 表销账 | Dart `FFI-R06：命令执行成功/失败均 ack 回销` |
| 教训修正 | CI clippy 门禁实为 `-D warnings -A clippy::double_must_use`（ci.yml:38；30 条基线告警即 double_must_use，async_trait 宏展开）；A-1 曾用宽松口径对账致 f56e08b Lint 失败（command_id 死代码 + map_or 可简化），本批修复并确立「以 CI 同款命令对账」 | CI 同款 clippy 0 error |

未实施：ack 失败的 Rust 业务消费（失败 Play 触发 UI 反馈）留 A-2 后评估；R02 慢 Play 分流依赖本契约（A-1c 评估）。

## A-2 实施记录（2026-11-14，当日晚间）

| 修复 | 实施 | 说明 |
|---|---|---|
| #14 R08 尾随快照降级 | service.rs emit() 不再为每事件广播 StateChanged(Box<ApplicationState>)（旧实现整克隆后 Dart 在 FFI 边界整体丢弃）；StateChanged 变体保留（pub API），event.rs:291/299、service.rs:1497 过时注释同步 | 事件广播不再携带全量克隆 |
| #7 R08 Dart 消费 | 不需要：尾随快照移除后，恢复统一走 _refreshState（单飞），行为等价且省一次克隆+传输 | 设计变更记录 |
| #9 R09 刷新单飞 | app_model._refreshState 改单飞+追尾（在途合并、风暴后最终态最新）；快照拉取失败登记 lastError 不再抛未处理异常 | |
| #10 R09 attach 顺序 | _attach 改先 subscribe 起泵再拉快照，消除拉取窗口丢事件 | |
| #11 R08 泵死亡可见化 | _eventLoop 连续 5 次失败置 `streamDead` 公开标志退出（不再无限 1s 重试空转，重订阅失败也计数）；`restartEventLoop()` 显式重连 | |
| #8 R09 local_songs 拆分 | VoicefoxController::state() 不再填充 local_songs（O(n) 克隆+FFI 序列化移出高频路径）；新 FFI `localSongs(controller)`；Dart `refreshLocalSongs()` 在引导与 local_music 事件时按需拉取，页面消费 `state.localSongs` 零改动 | |
| #16 R09 downloads 节流 | downloads_bridge 轮询 500ms→1s | |

待门禁确认后提交（已全绿后随 A-2 提交）。

## A-3 实施记录（2026-11-14）

| 修复 | 实施 | 说明 |
|---|---|---|
| #15 R10 播放状态串单源 | core PlayerState 新增 `as_protocol_str()`；state.rs PlaybackStateDto 与 ffi lib.rs progress 事件两处手写 match 收敛调用；Dart parse_host_state/MobilePlaybackPhase 映射对齐不变 | sync 取消语义「同步已取消」文本匹配改独立 cancelled 字段涉及 Sync 事件 schema 再变一次，如实留待 Sync 批次（Batch F 相邻） |
| #17 R11 工程锁 | pubspec flutter_rust_bridge `^2.13.0`→`2.13.0` 精确锁（Cargo 侧本就 =2.13.0）；ci.yml 新增 `codegen-check` job（装 pinned codegen → generate → diff 非空即失败，生成文件与手写 API 漂移在 CI 层拦截） | |
| 门禁工具对账 | scripts/redesign-gate.sh cargo-clippy 与 ci.yml lint job 逐字对齐（去掉 --all-features、加 -A double_must_use；旧命令本地恒红不可用作门禁） | |
| #18 测试缺口 | state()/event_next 双侧测试缺口经 A-2 改造后由全量套件间接覆盖；AppModel 事件泵直测需真控制器，如实登记为 Batch I 观测性任务 | |

## A-1 实施记录（2026-11-14，工作区改动，未 commit）

| 修复 | 实施 | 测试 |
|---|---|---|
| #4 R01 订阅前 Play 补投 | host_player.rs：`pending_play` 挂起槽（play 写入/stop 清除/补投后清空）+ `subscribe()` 对首个订阅者补投 | `pending_play_replayed_on_first_subscribe`（旧 `play_without_subscriber_still_accepts` 强化重写：原「接受」断言保留 + 补投/不重复断言）、`stop_clears_pending_play` |
| #6 R07 宿主看门狗 | host_player.rs：`last_report` 回流时间戳 + `liveness_tick(max_silence)`（宿主消失=无消费者且无挂起；宿主冻结=消费者在线但回流超静默阈值；有挂起 Play 不回落避免误报）+ `start_liveness_watchdog`（std 线程，new_host 以 5s/20s 启动；new_host 无 tokio 上下文故不走 tokio 任务）；回落经 watch send_replace 走观察者泵正常广播，UI 零特殊处理 | `liveness_tick_forces_stopped_only_when_host_gone`（4 场景） |
| #1 R03 lagged 重同步（Dart 半边） | host_player_bridge.dart：lagged 后 `_resync()` 把当前快照回灌 Rust watch（结构化错误枚举部分留 A-3）；api.rs 过时注释同步修正 | `FFI-R03：lagged 后重同步，把当前快照回灌 Rust watch` |
| #3 R06 命令异常分捕获 | host_player_bridge.dart：源异常与命令异常分 catch，命令失败仅记录不退出泵 | `FFI-R06：单条命令执行失败不杀死泵，后续指令继续消费` |
| #5 R06 dispose 可等待/泵可终止 | host_player_bridge.dart：`dispose()` 改 `Future<void>`（取消订阅 await + 播放器释放 await + 泵退出等待，`pumpExitTimeout` 兜底不可取消的 next()）+ `_disposed` 守卫阻断 dispose 后派发 | `FFI-R06：dispose 可等待，停泵且不再向已释放播放器派发` |

未实施（A-1b，待下一小批）：#2 全命令 commandId/generation（DTO 变更 + FRB 再生成 + 双侧测试）；R02 慢 Play 分流（依赖 #2 的代次元数据）。审计遗留的真机/压测验证项不变。

## 五、兼容性说明

1. #2/#4 涉及 HostPlayerCommandDto 与 FfiCommand 扩展：DTO 新增可选字段，Rust 侧缺省处理旧格式；两侧生成码同批再生成（FRB 2.13.0），CI 加生成一致性检查后防漂移。
2. #7/#8 改变 Dart 快照消费方式：state() 保留为全量恢复入口（事件丢失后重同步），不删除；local_songs 拆分需同步 local_music 页面拉取时机。
3. #15 协议字符串收敛不改 UI 文案：仅消除「同步已取消」文本匹配这类脆弱点。
4. 全部修复不重写业务层、不替换 FRB、不做 Rust→Dart 迁移（计划书 §0.2 架构决定）。
5. 每批实施后跑全量 Dart/Rust 门禁 + 对应平台构建；Android 真机项遵循用户既有约束（无授权不构建 APK/AVD），R01-R07 的真机断连/压测项标注「需设备验证」。

## 六、与缺陷矩阵的衔接

- 本表已证实风险登记入 `docs/redesign/04-defect-matrix.md`（FFI-R01/02/03/04/06/07/08/09/10/12 开放；R05/R11 观察态；R12 开放但低优先级）。
- 修复批次实施后按证据逐条更新矩阵；未实施前矩阵条目一律标注「审计已证实，修复待批次 A-1/A-2/A-3」。

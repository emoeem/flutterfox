# Phase 8 报告：Android 播放链路（Rust 转发型后端 + FRB 反向通道 + just_audio/audio_service），iOS 与蓝牙未覆盖

日期：2026-11-07　执行：工作流自动实施（提交 525f3d2，未推送）

计划书依据：`flutterfox-ui-redesign-plan-v2.md` Phase 8 节（Android 原生媒体能力：audio_service、音频会话、前台媒体服务、通知栏、锁屏、耳机按键、音频焦点；iOS 同节要求；设备路由只显示系统实际报告的设备；不可把桌面 libmpv 直接复制到手机）。前置：Phase 7 桌面/触屏壳已落库（c2c72fa）。

## 实施前勘察（可行性与切入顺序）

- mpv 引擎锁在 desktop-mpv feature（`player/src/lib.rs:7-8`，lib.rs:6 注明移动端由宿主侧原生音频实现 PlayerBackend），移动 ABI 走 --no-default-features。勘察时实跑 `cargo check -p voicefox-ffi --target aarch64-linux-android --no-default-features --locked`（配 NDK 27.2 链接器/cc 环境变量）19.96s 通过；target/aarch64-linux-android/debug/libvoicefox_ffi.so（2026-11-03 产物，无 mpv 符号）证明完整交叉构建此前已通。
- 宿主引导链齐全：`ffi/src/lib.rs:1121` from_application(ApplicationService)、`runtime/src/lib.rs:128` ApplicationRuntime::from_parts(config, path, player) 可注入任意 PlayerBackend、setDataDir 已解决 Android 数据目录（bridge/api.dart:57-64 + lx-core set_data_dir_override，FLUTTER_MIGRATION_PROGRESS.md:360 记录 2026-11-04 完成）。
- 关键接缝在 `application/src/services/playback.rs:95,123`：Rust 侧解析出 url+headers 后调 player.prepare()/play_with_headers()。移动路径应写一个 Rust 侧 PlayerBackend 适配器（参考 application/src/services/test_support.rs:18 NullPlayer 形态），经 flutter_rust_bridge 反向通道把 play(url, generation, headers) 转发给 Dart 的 just_audio，position/state/duration 以流回流。
- 会话层用 audio_service 包 AudioHandler 承担前台媒体服务/通知栏/锁屏/耳机按键/音频焦点；勘察时 pubspec 两者都没有（计划书:576 与迁移文档:94-96,352 已内定 just_audio + audio_service 方向）。
- 切入顺序：①Rust 转发型 PlayerBackend + FRB 反向信号面 → ②gradle/jniLibs 接入 + setDataDir/from_application 引导无音频冒烟 → ③just_audio 接管播放（AudioSource.uri(headers:) 承接自定义头）→ ④audio_service 媒体会话与前台服务 → ⑤耳机键/音频焦点/真实设备路由。iOS 部分仓库无 ios/ 目录与任何 AVAudioSession 先例，无从验证，列为 Phase 8 后段独立批次。

## 已完成任务表（实测）

### 批次一（Rust 侧）

| 项 | 状态 | 说明 |
|---|---|---|
| 任务 1：转发型 PlayerBackend | ✅ | 新增 `application/src/services/host_player.rs`（385 行）HostPlayerBackend，参照 test_support.rs NullPlayer 形态实现 PlayerBackend 全部方法但不做音频解码：prepare() 发代次令牌；play_with_headers() 覆写默认实现原样转发 url+generation+headers（`core/src/traits/player.rs:124` 默认实现会丢弃 headers；playback.rs:95/123 接缝零改动，现有 trait 调用直接落到新后端）；pause/resume/stop/toggle/seek/set_volume/set_speed 经 tokio broadcast(64) 转发给 Dart；回流侧 report_state/position/duration 用 watch send_replace 写回（教训：watch::send 无接收者时返回 SendError 丢值，send_replace 无条件更新共享槽，宿主订阅前 report 不丢，已用最小探针定位）；经 service.rs:175-211 既有观察者泵自动进入 ApplicationEventStream → Flutter 事件流；take_event_receiver 单次交付（engine.rs:856 同模式）承接宿主回流的 Ended/Error 驱动队列推进 |
| 任务 2：移动 ABI 零破坏 | ✅ | 未触碰 player/core/runtime/playback.rs（git diff 证实：ffi/src/lib.rs 纯增量 113 插入 0 删除，全仓 14 行删除均为 import 重排）；mpv 仍锁在 desktop-mpv feature |
| 任务 3：FRB 反向信号面 + 代码生成 | ✅ | `ffi/src/lib.rs` 增控制器 host_player 句柄 + new_host()（load_config + from_parts 注入新后端 + with_config_base，与 new_desktop 同构无 mpv）；因 FRB 对外部 crate 类型一律生成 opaque（Dart 拿不到 url/headers），按仓库「api.rs 只暴露 DTO」架构在 ffi 侧定义 HostPlayerCommandDto/HostHeaderDto 镜像并 From 转换；`ffi/src/api.rs` 增 new_host/host_player_stream/host_player_next（与 event_next 同模式：Dart 持流轮询，Lagged 返回 Err 由 Dart 侧重订阅重拉）/host_player_report(state,positionMs,durationMs)/host_player_report_event(ended/error/buffering/playing)；按仓库现行流程重生成（PATH=$HOME/flutter/bin:$PATH flutter_rust_bridge_codegen generate，避开迁移文档 D9 记录的 /usr/sbin/flutter 卡死）；生成码全部入库：ffi/src/frb_generated.rs + flutter/lib/src/bridge/api.dart/frb_generated*.dart/lib.dart/lib.freezed.dart（纯增量，lib.dart 0 删除），Dart 侧拿到 sealed HostPlayerCommandDto（play{url,generation,headers}/pause/resume/stop/toggle/seek/setVolume/setSpeed） |
| 任务 4：桌面零变化 | ✅ | 桌面 feature 编译通过、new_desktop 未动、813 例工作区测试全过 |

批次一自跑检查（实施时实测）：`cargo check -p voicefox-ffi --no-default-features --locked` 通过（0.11s Finished）；`cargo test --workspace` 21 个测试目标 813 passed 0 failed（日志 /tmp/cargo-test-final.log）。附加：cargo check -p voicefox-ffi（桌面 feature）通过；NDK 27.2 aarch64-linux-android 交叉 check（--no-default-features --locked，与勘察同款环境变量）1.67s 通过；flutter analyze --fatal-infos 零 issue；bridge_smoke_test+mini_player_test 2/2；host_player 单测 5/5（代次单调、headers 透传、控制转发、watch 回流、无订阅者容错、事件单次交付）。Cargo.lock 仅增 ffi 的 tokio 依赖条目（workspace 内部既有版本）。

### 批次二（Android 壳）

| 项 | 状态 | 说明 |
|---|---|---|
| 任务 1：FFI 交叉产物 | ✅ | 新建 `scripts/build-android-ffi.sh` 固化构建：NDK 候选探测（$ANDROID_NDK_HOME → ~/Android/Sdk/ndk/版本 → ~/android-sdk/ndk/版本；ask 所指 ~/Android/Sdk/ndk 在本机不存在，实际在 ~/android-sdk/ndk/，27.2.12479018 与 28.2 并存默认 27.2，VOICEFOX_NDK_VERSION 可覆盖），导出 CC/AR/CXX/RANLIB/CARGO_TARGET 链接器环境（aarch64-linux-android24-clang，与 minSdk 24 对齐）+ RUSTFLAGS=-C strip=debuginfo（保留 FRB opaque 引用计数所需导出符号，仅去调试信息）；实跑 `cargo build -p voicefox-ffi --target aarch64-linux-android --release --no-default-features --locked` 56.87s 完成，产物 flutter/android/app/src/main/jniLibs/arm64-v8a/libvoicefox_ffi.so 23,995,320 字节（file 实证：ELF 64-bit ARM aarch64，for Android 24，built by NDK r27c；对比 debug 251MB 大幅缩小）；产物不入库：flutter/.gitignore 增 /android/app/src/main/jniLibs/ 并用 git check-ignore 实证生效 |
| 任务 2：gradle/manifest 核对 | ✅ | minSdk = flutter.minSdkVersion，Flutter 模板默认 24（flutter_tools FlutterExtension.kt:26）与脚本 android24 clang 一致；AGP 默认打包 src/main/jniLibs/abi → APK lib/abi，实证 flutter build apk --debug 后 unzip -l 见 lib/arm64-v8a/libvoicefox_ffi.so（15.7MB 压缩态）与 libflutter.so/libdartjni.so 同层；风险记录：本批仅产 arm64-v8a，纯 32 位设备无此库；manifest 无权限保持（无音频冒烟不需要 INTERNET；libraryRefresh 本地扫描/configGet 读配置） |
| 任务 3：Dart 引导链 | ✅ | `main.dart` 新增触屏平台分支（纯增量 0 删除，桌面不进）：getApplicationSupportDirectory → bridge.setDataDir(path:)（修正 Android 上 dirs::data_dir() 为 None 的回退问题）→ bridge.newHost()（批次一转发型后端 + config_base）→ model.attach（事件泵+快照+libraryRefresh/configGet）→ HostPlayerBridge.start()；新建 `lib/src/bridge/host_player_bridge.dart` 消费 Rust→Dart 播放指令流（hostPlayerNext 轮询：Err 含 lagged 记录后继续，流关闭退出；无音频实现如实只记录不伪造播放状态、不回流，批次三接 just_audio/audio_service）；引导任一步失败 reportBootstrapError 呈现不静默。冒烟：adb devices 复查仍 0 设备（Linux 宿主无 emulator 二进制，android-emulator 插件 GUI 流程不支持 Linux），按 ask 明示许可降级为 flutter build apk --debug 构建门禁，✓ Built 通过；DynamicLibrary.open 加载与 from_application 引导的运行时表现未经实机验证（无设备），仅有 FRB 加载名匹配（frb_generated.dart stem='voicefox_ffi' → Android 打开 libvoicefox_ffi.so）+ so 入包实证 |
| 任务 4：桌面零变化 | ✅ | flutter build linux --release ✓（bundle libvoicefox_ffi.so 24MB 重产）；main.dart 桌面路径纯增量 0 删除、触屏分支不进桌面；analyze 零 issue |

### 批次三（Dart 侧音频承接）

| 项 | 状态 | 说明 |
|---|---|---|
| 任务 1：依赖接入 | ✅ | pub.dev 直达可用（无需镜像）：just_audio ^0.10.6 + audio_service ^0.18.19（pubspec.yaml:38-39），另加 audio_session ^0.2.4（becomingNoisy/音频焦点，flutter pub add 后成显式依赖，避免 depend_on_referenced_packages 告警）与 dev fake_async ^1.3.3（pubspec.yaml:40,55） |
| 任务 2：just_audio 承接反向信号 | ✅ | 新建 `lib/src/playback/mobile_audio_player.dart`：MobileAudioPlayer 抽象 + JustAudioMobilePlayer 实现，play(url, generation, headers) 用 AudioSource.uri(headers:) 逐请求透传国内音源自定义请求头；FfiCommand 语义对齐（SetVolume 0-100 → 0..1 折算、Seek 毫秒绝对定位、Toggle 由宿主按 playing 二选一、completed → ended 携带当前代次供 Rust service.rs:247 判代）；状态映射 ProcessingState → idle/loading/playing/paused/stopped 与 Rust parse_host_state 字符串一一对应；snapshotStream/eventStream 供回流 |
| 任务 3：audio_service 媒体会话 | ✅ | 新建 `lib/src/playback/voicefox_audio_handler.dart`：BaseAudioHandler+SeekHandler 承担通知栏/锁屏控制/媒体按键（play/pause/stop/seek/setSpeed 映射）、耳机拔出经 audio_session becomingNoisyEventStream 暂停、音频焦点经 AudioSessionConfiguration.music() 配置；configureAudioService（生产装配专用，测试路径完全绕开）初始化 AudioServiceConfig（notificationChannel com.example.voicefox_flutter.playback、ongoing、stopForegroundOnPause）；MediaItem 元数据真源取 AppModel.state.playback.song（无曲目用 app 名兜底，不伪造曲目）；AndroidManifest 增 INTERNET/WAKE_LOCK/FOREGROUND_SERVICE/FOREGROUND_SERVICE_MEDIA_PLAYBACK/POST_NOTIFICATIONS 权限与 AudioService（foregroundServiceType=mediaPlayback）+MediaButtonReceiver 声明（manifest:9,40,49）；MainActivity 改继承 AudioServiceActivity |
| 任务 4：仅触屏启用 | ✅ | HostPlayerBridge 重构为依赖抽象注入（HostCommandSource/RustHostCommandSource 包批次一 opaque 流、HostStateSink/RustHostStateSink 包 hostPlayerReport/Event、MobileAudioPlayer 可注入），装配点仅 main.dart _bootstrapTouch（isTouchPlatform 分支，桌面不进；main.dart 本批 0 删除行，桌面路径纯增量）；回流节流 = 相位/时长变化立即 + 位置 500ms 合并（默认，与桌面 LivePlayback 节奏一致，可注入） |
| 任务 5：fake 测试 | ✅ | `test/host_player_bridge_test.dart` 6 例全过（fake source/player/sink 全链路，零平台通道）：headers 透传、volume 折算 37 → 0.37、seek 42000ms、Toggle 未播放 → resume/播放中 → pause、回流字符串对齐、节流（首快照立即/同相位合并到 500ms 末/相位变化绕过节流，fakeAsync 驱动）、ended/error 携带代次、lagged 继续消费+流关闭退出 |
| 任务 6：蓝牙扩展点（不实现） | ✅（仅扩展点） | MobileAudioPlayer.enumerateRoutes 注释扩展点（audio_service 无设备枚举，计划书:962-963 需 AudioManager.getDevices 单独桥）+ handler customAction 预留宿主动作入口；本轮不实现不显示设备，路由功能整体列为未覆盖待办 |

## 实施中记录与风险（门禁与工程笔记）

- 门禁记录（实施时实测，按轮次原样登记）：analyze 第 1 轮 exitCode 0「No issues found! (ran in 2.9s)」；test 第 1 轮 exitCode 0「00:14 +183: All tests passed!」；android cargo check 第 1 轮 exitCode 101「warning: build failed, waiting for other jobs to finish...」，第 2 轮 exitCode 0「Finished dev profile [unoptimized + debuginfo] target(s) in 7.23s」；rust workspace test 第 2 轮 exitCode 0（尾行「Doc-tests voicefox_runtime」）；P8 analyze 第 1 轮 exitCode 0「No issues found! (ran in 1.1s)」；P8 flutter test 第 1 轮 exitCode 0「00:14 +183: All tests passed!」；flutter build apk --debug exitCode 0（输出含 Flutter 官方插件 Kotlin 迁移提示，非阻断）；P8-3 analyze 第 1 轮 exitCode 0「No issues found! (ran in 1.2s)」；P8-3 flutter test 第 1 轮 exitCode 0「00:15 +189: All tests passed!」（189 = 183 + 批次三 6 例）。
- FRB 对外部 crate 类型生成 opaque 的限制以 ffi 侧 DTO 镜像化解，与仓库「api.rs 只暴露 DTO」架构一致。
- watch::send 无接收者丢值教训已在 host_player.rs 以 send_replace 具体化。
- 代码生成必须以 PATH=$HOME/flutter/bin:$PATH 前缀运行，避开 /usr/sbin/flutter 卡死（迁移文档 D9）。
- RUSTFLAGS=-C strip=debuginfo 仅为保留 FRB opaque 引用计数所需导出符号，非全量 strip。

## 验收状态

- 报告撰写时复核（2026-11-07，HEAD 525f3d2，工作区干净），以下均为本次实跑结果：
  - `flutter analyze --fatal-infos`（flutter/ 目录）：No issues found! (ran in 1.3s)
  - `flutter test`（flutter/ 目录，全量）：00:14 +189: All tests passed!
  - `cargo check -p voicefox-ffi --no-default-features --locked`：Finished dev profile [unoptimized + debuginfo] target(s) in 0.38s（exit 0）
  - `cargo test --workspace`：21 个测试目标合计 813 passed / 0 failed（逐目标 test result 行汇总）
  - 产物在位：flutter/android/app/src/main/jniLibs/arm64-v8a/libvoicefox_ffi.so 实测 23,995,320 字节（与批次二构建记录一致；不入库，gitignore 管辖）
  - pubspec.yaml:38-40,55 与 AndroidManifest 权限/组件声明逐行核对一致
- 构建门禁（实施时）：flutter build apk --debug ✓（just_audio/audio_service 35 项入包、libvoicefox_ffi.so 保持）；flutter build linux --release ✓（桌面零变化）
- 提交：525f3d2（feat: Phase 8(UI/FFI) Android 播放链路，工作流自动实施，未推送；28 文件 +3973/-17，一并落库 docs/PHASE7-REPORT.md 与 .cargo/config.toml）

## 待补项（未完成，不得视为已完成）

- iOS：整体未覆盖。仓库无 ios/ 目录、无任何 AVAudioSession 先例、无工具链可验证；AVAudioSession、MPNowPlayingInfoCenter、MPRemoteCommandCenter、后台音频与 AirPlay 路由均未实施，列为 Phase 8 后段独立批次。
- 蓝牙/设备路由：未覆盖待办。计划书:962-963 要求「原生设备路由只显示系统实际报告的设备，蓝牙图标根据真实连接状态变化」，需 AudioManager.getDevices 单独桥接；本轮仅留 enumerateRoutes 注释扩展点与 handler customAction 预留，不实现、不显示任何设备。
- 实机运行时验证：adb devices 持续 0 设备（Linux 宿主无 emulator 二进制，插件 GUI 模拟器流程不支持 Linux）。DynamicLibrary.open 加载、from_application 引导、just_audio 实际发声、通知栏、锁屏控制、耳机按键、音频焦点、AudioSource.uri(headers:) 的真机请求头透传表现均未经真机验证，仅有构建入包实证 + FRB 加载名匹配 + widget/fake 测试佐证。
- 切入顺序②的「setDataDir/from_application 引导跑通无音频冒烟」实机部分未完成（按 ask 明示许可降级为构建门禁）。
- 切入顺序⑤（真实设备路由）未开始。
- ABI 覆盖：仅 arm64-v8a，纯 32 位设备无此库，切序③后按需扩 ABI。
- applicationId/签名整改：留上线批。

## 剩余问题与已知发现（未修）

1. android cargo check 第 1 轮 exitCode 101（并行构建失败等待），第 2 轮 7.23s 通过：按门禁记录原样留档，未深究首败原因。
2. so 产物 23,995,320 字节（release，strip=debuginfo）不入库；换机构建需重跑 scripts/build-android-ffi.sh，NDK 探测路径与 VOICEFOX_NDK_VERSION 覆盖逻辑见脚本。
3. Dart 指令流为轮询模式（hostPlayerNext），Lagged 时由 Dart 侧重订阅重拉，与 event_next 同模式；流关闭即退出循环，长时运行下的重连语义未经实机长测。
4. 无音频实现阶段，HostPlayerBridge 收到播放指令仅记录不回流、不伪造播放状态；在批次三装配后由 JustAudioMobilePlayer 承接，但其真机行为未验证（见待补项）。

## 与计划书 Phase 8 要求对照

| 计划书要求 | 状态 |
|---|---|
| Android：audio_service、音频会话、前台媒体服务、通知栏、锁屏、耳机按键、音频焦点 | ✅ 代码与装配完成（fake 测试 6 例 + 插件 35 项入包 + manifest/MainActivity 就位）；实机行为待真机验证（见待补项） |
| iOS：AVAudioSession、MPNowPlayingInfoCenter、MPRemoteCommandCenter、后台音频和 AirPlay 路由 | ❌ 未覆盖待办（无 ios/ 目录与工具链，列 Phase 8 后段独立批次） |
| 原生设备路由只显示系统实际报告的设备，蓝牙图标根据真实连接状态变化 | ❌ 未覆盖待办（本轮仅注释扩展点 + customAction 预留，不实现不显示） |
| 移动端 PlayerBackend 和媒体会话协调；不可把桌面 libmpv 直接复制到手机 | ✅（HostPlayerBackend 转发型后端注入 from_parts；mpv 仍锁 desktop-mpv feature，未复制到移动 ABI） |

## 附录：证据清单

- Rust 侧：`application/src/services/host_player.rs`（新增 385 行）、`application/src/services/mod.rs`、`application/src/lib.rs`、`ffi/src/lib.rs`（+113，0 删除）、`ffi/src/api.rs`、`ffi/Cargo.toml`、`ffi/src/frb_generated.rs`、`Cargo.lock`（仅增 ffi 的 tokio 条目）、`.cargo/config.toml`
- Android 壳：`scripts/build-android-ffi.sh`（新增）、`flutter/.gitignore`（jniLibs 忽略）、`flutter/lib/main.dart`（触屏引导分支）、`flutter/lib/src/bridge/host_player_bridge.dart`（新增）
- Dart 音频承接：`flutter/pubspec.yaml`、`flutter/pubspec.lock`、`flutter/lib/src/playback/mobile_audio_player.dart`（新增）、`flutter/lib/src/playback/voicefox_audio_handler.dart`（新增）、`flutter/android/app/src/main/AndroidManifest.xml`、`flutter/android/app/src/main/kotlin/com/example/voicefox_flutter/MainActivity.kt`
- FRB 生成码（全部入库）：`flutter/lib/src/bridge/api.dart`、`frb_generated.dart`、`frb_generated.io.dart`、`frb_generated.web.dart`、`lib.dart`、`lib.freezed.dart`
- 测试：`flutter/test/host_player_bridge_test.dart`（新增 6 例，全量 189 例含）；Rust 侧 host_player 单测 5/5
- 报告撰写时复核命令（本次实跑）：`flutter analyze --fatal-infos`、`flutter test`（均于 flutter/ 目录）；`cargo check -p voicefox-ffi --no-default-features --locked`、`cargo test --workspace`（均于仓库根）；结果见验收状态节
- 提交：525f3d2（基线 c2c72fa，即 Phase 7 落库点；未推送）

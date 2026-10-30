# Flutter GUI 迁移进度存档（断点续跑）

> 本文档是无人值守迁移的唯一状态来源。每完成一个可验证单元立即更新。
> 断点续跑：从「当前状态 / 下一步」一节继续，不要重读全部代码重新推导。

- 依据规划：会话内已审阅批准的《voicefox 跨平台 GUI 迁移规划（Flutter + flutter_rust_bridge）》（Phase 0-4）
- 铁律：改动必须实际验证；TUI 是回归基准（cargo test 全绿）；不静默删功能；iOS/频谱/kitty 封面不做
- **工作区**：/home/emo/code/voicefox-gui（自 /home/emo/code/voicefox @ dd116b1 克隆，原仓库保持不动）

## 当前状态 / 下一步（断点续跑入口）

- **Phase 0 ✅（99f75b9）Phase 1 ✅（9d569b4）Phase 2 ✅（01b589a）
  UI 设计 ✅（docs/flutter_ui_spec.md）Phase 3 ffi ✅（e914da7）Phase 3 UI 首批页面 ✅（acca624，桌面实跑通过）**
- **下一步精确入口（Phase 3 UI 剩余页 → Phase 4）**：
  1. 剩余页面（对照 app/src/pages/）：leaderboard、playlists（远程网格+自定义歌单 CRUD）、
     details（歌手/专辑）、sync overlay、local_music（扫描+列表）、help、歌词全屏页。
     页面骨架参考 lib/src/pages/ 已有 6 页的模式（AppModel + bridge 命令直调）。
  2. 歌词页：state.lyrics（LyricsDto.lines + currentLine）滚动渲染；
     mini player 点击展开全屏播放页（spec §9 容器变换转场）。
  3. Phase 4 Android（入口清单）：
     a. flutter/lib/src/app_model.dart 已预留 attach(controller)——Android 侧需要
        宿主先构造 ApplicationService：Android 端直接跑 cdylib（cargo-ndk 产物）+
        Dart 音频后端（just_audio + audio_service 实现 core 的 PlayerBackend 语义：
        Rust 只解析 URL/歌词，播放由 Dart 侧执行）。
        ⚠ ffi 的 from_application 路径 config_base=None → ConfigUpdate 会报
        "配置存储不可用"，Android 引导时需另想（扩 with_config_base 或 ConfigDto 走
        runtime 直读）。
     b. js-sources feature-gate：source/src/js/engine.rs 的 node 子进程加 feature
        `js-sources`（默认开），ffi--no-default-features 构建时关闭；
        download crate 无 node 依赖（已确认）。
     c. 路径核对：lx_core::fsutil::default_data_dir 在 Android 返回
        dirs::data_dir()=null → fallback "."；需要 Android 上传 app 私有目录
        （PathProvider 传参或 cargo 端 cfg(target_os="android")）。
     d. gradle 集成：cargo-ndk 产 libvoicefox_ffi.so 放
        flutter/android/app/src/main/jniLibs/<abi>/；RustLib.init 自动加载。
        桌面 linux bundle 需手动 cp .so 到 bundle/lib/（已验证可行）。
     e. 模拟器实测：后台播放（audio_service foreground service）、锁屏控制、
        下载通知。
- **已知 flaky**：source::cover_cache::sweep_evicts_down_to_the_limit_by_oldest_access
  在满负载并行时偶发（单独跑稳定），mtime 已修到毫秒档仍可复现，待后续用
  注入时钟的方式根治。
- **待确认决策（延续记录）**：
  · 状态管理 v1 = ChangeNotifier（未引 riverpod/bloc），理由：单控制器事件流
    已够用，避免提前固化架构；引入时机 = 出现跨页共享的派生状态时。
  · dynamic_color 固定 1.7.0：0.13.0 引入第三方 material_ui，其 ColorScheme
    与 Flutter SDK 类型不兼容。
  · ConfigDto 为子集镜像（v1 设置面），完整镜像成本高且 FFI 层膨胀；
    扩设置项 = 扩 ConfigDto 字段 + apply_to 一行。
  · 二维码渲染 v1 未接 qr_flutter（显示内容串兜底），pub.dev 有成熟包
    qr_flutter（周下载量高、近一年维护），接入点 = qr_login_page.dart _QrView。
  · 旧 flutter scaffold（app.dart/shell.dart 459 行占位）被新架构替代，git 历史可查。

## Phase 2 交付明细（新增命令/事件清单）

- 命令：LibraryRefresh / FavoritesAdd·Remove / FavoritePlaylistAdd·Remove / HistoryRemove·HistoryClear / CustomPlaylistCreate·Rename·Delete·AddSongs·RemoveSong / ConfigGet·ConfigUpdate / DownloadEnqueue·DownloadCancel·DownloadClearFinished / QrLoginStart·QrLoginCancel / LocalScan
- 事件：LibraryChanged / DownloadsChanged / ConfigChanged / QrLoginCreated / QrLoginPolled(status 字符串: waiting/scanned/success/expired/failed/network_error/risk_control/server_error/invalid_session) / LocalScanCompleted
- 端口：application/src/ports.rs（LibraryStore/ConfigStore/DownloadsEngine + DownloadTaskInfo DTO）
- 适配器：runtime（Storage→LibraryStore；RuntimeConfigStore；RuntimeDownloads 包装 DownloadManager + 500ms 变更桥）
- 关键决策：无 tokio 上下文时下载端口优雅留空（Handle::try_current）；QR 轮询 2s/次、取消用 AtomicBool；scan 走 spawn_blocking


## 已完成清单（文件级）

- [x] 审阅与规划（会话内，规划文档已批准）
- [x] 环境搭建：Flutter 3.47.9 装于 ~/flutter（tarball 1.58GB 断点续传下载）；~/android-sdk 补装 platforms;android-36 与 cmdline-tools 软链；flutter doctor Android/Linux 均绿
- [x] 新工作区建立：git clone → voicefox-gui @ dd116b1，原仓库保持干净
- [x] 根 Cargo.toml：reqwest → default-features=false + rustls-tls + charset + http2
- [x] ffi/Cargo.toml：voicefox-runtime 依赖加 default-features = false（否则 runtime 默认特性仍拉 mpv）
- [x] runtime/Cargo.toml：lx-player 依赖加 default-features = false（同上）
- [x] player/src/lib.rs：engine 模块加 #[cfg(feature = "desktop-mpv")]
- [x] ffi/src/api.rs：new_desktop 改为始终存在、体内 cfg 分支（FRB 生成代码无条件引用它，不能在签名上 cfg 门控）
- [x] .github/workflows/ci.yml：新增 build-android（cargo-ndk 三 ABI，--no-default-features）与 flutter（analyze --fatal-infos）两个 job，YAML 校验通过
- [x] flutter/：flutter create 四平台 runner（android/linux/macos/windows）+ .gitignore/.metadata/analysis_options/main.dart/widget_test；pubspec 补 flutter_lints ^6、SDK 约束升 >=3.10.0；修 6 处 lint（app.dart/shell.dart 花括号与插值、mini_player_test 未用 import）
- [x] FRB codegen 跑通：ffi/src/frb_generated.rs 与 flutter/lib/src/bridge/api.dart 重生成（feat: new_desktop 包装函数变化）

## 遇到的坑与已做决策

| 时间 | 坑/决策 | 说明 |
|---|---|---|
| D0 | 用户要求新项目文件夹 | 全部迁移工作在 /home/emo/code/voicefox-gui 进行，原 /home/emo/code/voicefox 不再修改（已还原本会话对其的改动） |
| D0 | 环境缺 flutter | 解法：下载官方 stable 3.47.9 tarball（第一次下载 586MB 后连接重置 exit 56，断点续传重试中），解压到 ~/flutter，不改系统 |
| D0 | reqwest 切 rustls 不能只加 feature | 必须同时 `default-features = false`，否则 native-tls 仍被拉入（Android 拖 OpenSSL）；需手动补 `charset`（GBK 解码，国内音源需要）与 `http2` |
| D0 | 原仓库 Cargo.lock 有非本会话的本地改动 | git status 显示 M Cargo.lock（chacha20/cpufeatures 重排，疑似用户本地另跑过 cargo），**未动它**，仅记录 |
| D0 | 状态管理待定 | shell.dart 现状极简（无状态管理库），Phase 3 引入时 riverpod/bloc 二选一，理由写入待确认决策 |

## 验证状态

| 命令 | 状态 | 时间 |
|---|---|---|
| `cargo check --workspace`（reqwest 切换后） | ✅ 绿 | D0 |
| `cargo test --release`（Phase 0 基线） | ✅ 792 passed / 0 failed（日志 /tmp/baseline_test.log） | D0 |
| `cargo check -p voicefox-ffi --no-default-features` | ✅ 绿（无 mpv ABI） | D0 |
| `cargo tree -p voicefox-ffi --no-default-features -i libmpv2` | ✅ libmpv2 不在依赖树 | D0 |
| `cargo ndk -t arm64-v8a build -p voicefox-ffi --no-default-features` | ✅ 产出 /tmp/voicefox-ndk-test/arm64-v8a/libvoicefox_ffi.so (10.5MB) | D0 |
| `flutter analyze` | 未跑（flutter 下载中） | - |
| `flutter_rust_bridge_codegen generate` | 未跑 | - |

## Phase 完成度对照

- [ ] Phase 0 基础设施
- [ ] Phase 1 抽取（download crate / 歌单迁移 / 配置统一）
- [ ] Phase 2 边界扩宽
- [ ] Phase 3 ffi + Flutter UI
- [ ] Phase 4 Android 落地

（各 Phase 内部细项见下方分节，完成一项勾一项）

## Phase 0 细项

- [x] reqwest → rustls-tls（根 Cargo.toml）
- [ ] cargo check/test 回归通过
- [ ] flutter create 平台 runner（android/windows/linux/macos）
- [ ] FRB codegen 跑通（ffi/src/frb_generated.rs 重生成）
- [ ] CI 加 Android target（cargo-ndk: aarch64/armv7/x86_64-linux-android）+ Flutter analyze/build job

## Phase 1 细项

- [ ] 新 crate `download/`（voicefox-download）：迁移 app/src/download/*（manager/engine/records/tags/naming/webdav）
- [ ] 歌单管理 app/src/playlist/{manager,shuffle,mode}.rs → application 或 runtime
- [ ] 配置统一：app/src/config/loader.rs 并入 runtime/src/lib.rs load_config
- [ ] app（TUI）改消费新库；cargo test 全绿 + TUI 手动无回归

## Phase 2 细项

- [ ] application/src/event.rs：ApplicationCommand/ApplicationEvent 扩 favorites/history/downloads/settings/QR 登录/跨源同步/local/封面

## Phase 3 细项

- [ ] ffi/src/api.rs DTO/FfiCommand/事件流扩宽
- [ ] Flutter 页面对齐 app/src/pages/ 全部
- [ ] 16 主题色板 → M3 ColorScheme（seed 共用，不分叉）
- [ ] 桌面 platform/ crate（MPRIS/SMTC/通知从 app 抽出接回）
- [ ] docs/flutter_ui_spec.md（FlClash 调研 + 具体设计值）

## Phase 4 细项

- [ ] just_audio + audio_service（Android 音频后台）
- [ ] js-sources feature-gate（source/src/js/engine.rs node 子进程）
- [ ] 路径核对（dirs 在 Android 的落位）
- [ ] cargo-ndk + gradle 集成
- [ ] 模拟器实测：后台播放/锁屏控制/下载通知

# Flutter GUI 迁移进度存档（断点续跑）

> 本文档是无人值守迁移的唯一状态来源。每完成一个可验证单元立即更新。
> 断点续跑：从「当前状态 / 下一步」一节继续，不要重读全部代码重新推导。

- 依据规划：会话内已审阅批准的《voicefox 跨平台 GUI 迁移规划（Flutter + flutter_rust_bridge）》（Phase 0-4）
- 铁律：改动必须实际验证；TUI 是回归基准（cargo test 全绿）；不静默删功能；iOS/频谱/kitty 封面不做
- **工作区**：/home/emo/code/voicefox-gui（自 /home/emo/code/voicefox @ dd116b1 克隆，原仓库保持不动）

## 当前状态 / 下一步（断点续跑入口）

- **Phase 0 ✅（commit 99f75b9）Phase 1 ✅（commit 9d569b4）**
- **下一步精确入口（Phase 2）**：
  1. 读 `application/src/event.rs`（ApplicationCommand/ApplicationEvent 现状）与 `application/src/services/`（现有 PlaybackService/SearchService/QueueService/LyricsService/PlaylistService 结构）
  2. 读 `app/src/context.rs` + `app/src/pages/{favorites,history,downloads,qr_login,local_music,settings}.rs` 与 `app/src/sync.rs`，梳理各功能的命令/事件需求面
  3. 扩宽 ApplicationCommand/ApplicationEvent：favorites / history / downloads（转 broadcast 事件）/ settings / QR 登录 / 跨源同步 diff / local 扫描 / 封面字节
  4. 验证：cargo test 全绿 + clippy 0 警告，TUI 仍跑旧路径不动
- **注意**：Phase 2 只扩 application 边界，不改 ffi（ffi 扩宽在 Phase 3）

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

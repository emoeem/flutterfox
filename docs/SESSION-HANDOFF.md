# SESSION HANDOFF：Flutterfox/Voicefox 跨会话交接

更新：2026-11-07　用途：新会话接续本项目的唯一状态源。配合记忆索引使用。

## 一、授权口径（用户历次授权，已生效）

1. AI 自主研发工作流全权执行：调研/比较/实施/测试/CI/推送/验收/持续优化，无需逐步请示。
2. **验收通过即可推送 GitHub 并触发构建、发布多平台 Release**（2026-11-07 明确）。
3. 后端任务选型：按实际情况用 Rust 或非 Rust，不强制非 Rust（2026-11-07 澄清）。
4. 本仓库远程：`flutterfox` = github.com/emoeem/flutterfox（MIT）。SSH 通道偶发失效时用 `git push https://github.com/emoeem/flutterfox.git main`。

## 二、当前状态（main @ 3ea4ab7 + ad1e30f）

- **计划书**：/home/emo/Downloads/flutterfox-ui-redesign-plan-v2.md（§13 为最终完成定义）。
- **桌面重构 Phase 0-8 全部完成**：Phase 7（c2c72fa）MobileShell/平板三态/手势全屏播放，桌面冻结基线逐像素 RMSE=0 零回归；Phase 8（525f3d2）Rust 转发型 PlayerBackend + FRB 反向通道 + jniLibs + just_audio/audio_service。批级报告：docs/PHASE0-FINDINGS.md 至 docs/PHASE8-REPORT.md。
- **测试基线**：Dart 189 用例 + Rust workspace 813 用例全过；flutter analyze --fatal-infos 零 issue；clippy 存量约 30 条机械警告（double_must_use 类，CI 现有豁免）待清理。
- **CI**（.github/workflows/ci.yml）：fmt + clippy 零警告（-A double_must_use）+ TUI 三平台构建 + cargo-ndk Android FFI + flutter analyze/test，main 全绿。
- **Release v0.9.0**（2026-11-07）：Flutter 四平台（Linux/Android CI 全链路，Windows/macOS CI 实跑通过）+ TUI 五平台资产，同一 Release；发布管线 .github/workflows/release-flutter.yml（tag 触发 + workflow_dispatch 试跑，gh get-or-create 与 TUI 发布共存）。
- **真机两连修**（用户实测驱动，已入 3ea4ab7 / ad1e30f 并替换 Release APK）：
  1. Bad state：触屏引导在 RustLib.init 之前调桥函数 → 新增幂等 AppModel.ensureRustLib() 并前移到引导首步；
  2. EROFS：default_config_path 在 Android 上 ProjectDirs/dirs 全 None 回退 "." 写只读根 → config 路径优先吃 fsutil 的 set_data_dir_override。
  修复后 APK 用户验证中（2026-11-07 晚）。

## 三、待办队列（按优先级）

1. **真机验证收尾**：用户重装 APK 后的引导结果；通知栏/锁屏/耳机键/音频焦点实机行为；蓝牙设备路由（MobileAudioPlayer.enumerateRoutes 扩展点已留，需平台桥）。
2. **P4-01 MCP 类比项不适用本项目；这里是 PHASE6-REPORT 登记的后端任务**（Rust 侧，授权已放开）：队列 reorder/jump（FfiCommand 扩展）、MPRIS/SMTC/Now Playing 媒体键、歌词 YRC 逐字与翻译结构（LyricsDto 扩展）、duration=0 音源时长补齐、音频输出枚举与 EQ DSP。
3. clippy 30 条机械警告清理 → CI 升级 -D warnings（豁免可去掉）。
4. Windows/macOS Flutter 产物从尝试矩阵转正（移除 continue-on-error）；Android 正式签名与应用 id 整改（现 debug 签名）；armv7/x86_64 ABI 按需扩。
5. iOS 批次（仓库无 ios/ 目录，无工具链，需单独立项）。
6. 已知小缺陷：极矮视口（高 <560 桌面页）纵向 43px 溢出；浅色主题下壳 chrome 仍为 VxColors 暗面常量（冻结前既有状态，重构时一并处理）。
7. Flutter 升级（3.47.9 → 更新）时注意：--no-codesign 已被移除（用 CODE_SIGNING_ALLOWED=NO）。

## 四、工程事实与环境

- Flutter 3.47.9（CI 同版本钉死）；Rust stable + MSRV 1.90.0；NDK 27.2（scripts/build-android-ffi.sh 自适应探测，VOICEFOX_NDK_VERSION 可覆盖）。
- FRB 生成码入库；再生成命令：`PATH=$HOME/flutter/bin:$PATH flutter_rust_bridge_codegen generate`（避开 /usr/sbin/flutter 卡死）。
- .cargo/config.toml 不得硬编码本机 NDK 路径（曾致 CI 必炸）；本机个人配置放 ~/.cargo/config.toml。
- CI runner 的镜像环境变量（ANDROID_NDK_LATEST_HOME 等）不进 GA 的 env 上下文，须在 shell 层 export。
- minSdk 24 与脚本 android24 clang 对齐；FFI 产物 jniLibs/ 不入库（重建 = scripts/build-android-ffi.sh + flutter build apk）。

## 五、新会话开场动作

1. 读本文件 + 记忆索引（pensting 项目记忆含 Voicefox 段）。
2. `git -C /home/emo/code/voicefox-gui status` + `gh run list --repo emoeem/flutterfox --limit 3` 确认基线未漂移。
3. 按第三节队列推进；每批完成 = 验证 + commit + push（发布按授权触发 release-flutter）。

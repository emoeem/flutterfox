# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!-- 项目当前版本 0.9.0（Cargo.toml）。首个条目由维护者按既有 release 历史回填；
     此后每次 release 将 Unreleased 重命名为日期版本并另起新的空 Unreleased。 -->

## [Unreleased]

### Added

## [0.9.0] - 2026-11-07

### Added

- Phase 7：移动端 MobileShell（底部导航 + 迷你播放栏）、平板三态断点（Rail/双栏/三栏）、手势式全屏播放页（封面/歌词/队列分层）；移动/平板形态仅触屏平台生效，桌面全宽零回归（冻结基线逐像素对照 RMSE=0）
- Phase 8：Android 播放链路：Rust 转发型 PlayerBackend（headers 不丢失）+ flutter_rust_bridge 反向通道、NDK 交叉 FFI 入包（scripts/build-android-ffi.sh）、just_audio + audio_service 承接播放与通知栏/锁屏/耳机键（实机验证待真机）
- CI：flutter 全量测试门禁；release-flutter 发布管线（Linux/Android 全链路 + Windows/macOS 尝试矩阵）

### Fixed

- 修复 app 包测试编译断裂（Phase 4 遗漏的 DownloadTaskView.song 字段）

### Changed

### Deprecated

### Removed

### Fixed

### Security

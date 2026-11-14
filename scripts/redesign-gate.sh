#!/usr/bin/env bash
# Voicefox UI 重构门禁脚本（依据 docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md §12.1）。
#
# 设计给 ZCode 工作流的 world.run 以固定 cwd（仓库根）直接调用：world.run 没有shell、
# 不能 cd，因此所有子命令的环境修复与目录切换都封装在这里。
#
# 用法: scripts/redesign-gate.sh <subcommand>
# 子命令:
#   dart-format      dart format --set-exit-if-changed lib test（flutter/）
#   flutter-analyze  flutter analyze --fatal-infos（flutter/）
#   flutter-test     flutter test（flutter/）
#   cargo-fmt        cargo fmt --all -- --check
#   cargo-clippy     cargo clippy --workspace --all-targets -- -D warnings -A clippy::double_must_use
#                    （与 ci.yml lint job 逐字一致：double_must_use 30 条基线为
#                     async_trait 宏展开固有，CI 既有豁免；2026-11-14 A-3 对齐前
#                     旧命令带 --all-features 且缺豁免，本地恒红不可用作门禁）
#   cargo-test       cargo test --workspace
#   all              硬门禁全套：dart-format + flutter-analyze + flutter-test + cargo-fmt + cargo-test
#   env              打印本脚本解析出的环境（诊断用）
set -u

# —— 环境修复：真实工具链位置（会话 shell 的 HOME 指向 distrobox home，PATH 缺 flutter/cargo）——
export HOME=/home/emo
export PATH="/home/emo/flutter/bin:/home/emo/.cargo/bin:$PATH"
export RUSTUP_HOME=/home/emo/.rustup
export CARGO_HOME=/home/emo/.cargo
export ANDROID_HOME=/home/emo/android-sdk
export ANDROID_SDK_ROOT=/home/emo/android-sdk

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "${1:-}" in
  env)
    echo "REPO_ROOT=$REPO_ROOT"
    echo "HOME=$HOME"
    flutter --version 2>&1 | head -1
    dart --version 2>&1
    cargo --version 2>&1
    ;;
  dart-format)
    cd "$REPO_ROOT/flutter" || exit 1
    exec dart format --output=none --set-exit-if-changed lib test
    ;;
  flutter-analyze)
    cd "$REPO_ROOT/flutter" || exit 1
    flutter pub get || exit 1
    exec flutter analyze --fatal-infos
    ;;
  flutter-test)
    cd "$REPO_ROOT/flutter" || exit 1
    flutter pub get || exit 1
    exec flutter test
    ;;
  cargo-fmt)
    cd "$REPO_ROOT" || exit 1
    exec cargo fmt --all -- --check
    ;;
  cargo-clippy)
    cd "$REPO_ROOT" || exit 1
    exec cargo clippy --workspace --all-targets -- -D warnings -A clippy::double_must_use
    ;;
  cargo-test)
    cd "$REPO_ROOT" || exit 1
    exec cargo test --workspace
    ;;
  all)
    rc=0
    for sub in dart-format flutter-analyze flutter-test cargo-fmt cargo-test; do
      echo "=== gate: $sub ==="
      "$0" "$sub" || rc=1
    done
    exit $rc
    ;;
  *)
    echo "unknown subcommand: ${1:-<empty>}（可用: env dart-format flutter-analyze flutter-test cargo-fmt cargo-clippy cargo-test all）" >&2
    exit 64
    ;;
esac

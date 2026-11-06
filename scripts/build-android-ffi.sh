#!/usr/bin/env bash
# Phase 8 批次二：Android arm64 FFI 动态库交叉构建。
#
# 产物：flutter/android/app/src/main/jniLibs/arm64-v8a/libvoicefox_ffi.so
# （不入库，见 flutter/.gitignore；gradle 自动打包进 APK lib/arm64-v8a/）。
#
# 要点：
# - --no-default-features：mpv 锁在 desktop-mpv feature，移动 ABI 不带 mpv
#   （player/src/lib.rs:6-7）；链接FRB 生成的 Dart 加载名固定为
#   libvoicefox_ffi.so（frb_generated.dart kDefaultExternalLibraryLoaderConfig
#   stem='voicefox_ffi'，Android 上 DynamicLibrary.open 同名）。
# - NDK 定位顺序：$ANDROID_NDK_HOME → ~/Android/Sdk/ndk/<版本> →
#   ~/android-sdk/ndk/<版本>（本机实际在后者；27.2.12479018 与 28.2 并存，
#   默认取 27.2，可用 VOICEFOX_NDK_VERSION 覆盖）。API 级别 24 与 Flutter
#   模板 minSdk 24 一致（FlutterExtension.kt minSdkVersion 默认 24）。
# - RUSTFLAGS 剥离调试信息：debug 产物曾达 251MB，release+strip 显著缩小。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="aarch64-linux-android"
API="${VOICEFOX_ANDROID_API:-24}"
NDK_VERSION="${VOICEFOX_NDK_VERSION:-27.2.12479018}"
NDK_CANDIDATES=(
  "${ANDROID_NDK_HOME:-}"
  "$HOME/Android/Sdk/ndk/$NDK_VERSION"
  "$HOME/android-sdk/ndk/$NDK_VERSION"
)
NDK=""
for candidate in "${NDK_CANDIDATES[@]}"; do
  if [ -n "$candidate" ] && [ -x "$candidate/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android${API}-clang" ]; then
    NDK="$candidate"
    break
  fi
done
if [ -z "$NDK" ]; then
  echo "error: NDK $NDK_VERSION not found (tried: ${NDK_CANDIDATES[*]})" >&2
  exit 1
fi
echo "==> NDK: $NDK"
OUT_DIR="$REPO_ROOT/flutter/android/app/src/main/jniLibs/arm64-v8a"

TC="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
LINKER="$TC/aarch64-linux-android${API}-clang"

export AR_aarch64_linux_android="$TC/llvm-ar"
export CC_aarch64_linux_android="$LINKER"
export CXX_aarch64_linux_android="$TC/aarch64-linux-android${API}-clang++"
export RANLIB="$TC/llvm-ranlib"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$LINKER"
export RUSTFLAGS="-C strip=debuginfo"

echo "==> cargo build -p voicefox-ffi --target $TARGET --release --no-default-features --locked"
cd "$REPO_ROOT"
cargo build -p voicefox-ffi --target "$TARGET" --release --no-default-features --locked

SO="target/$TARGET/release/libvoicefox_ffi.so"
mkdir -p "$OUT_DIR"
cp "$SO" "$OUT_DIR/libvoicefox_ffi.so"

echo "==> 产物"
ls -la "$OUT_DIR/libvoicefox_ffi.so"
file "$OUT_DIR/libvoicefox_ffi.so"

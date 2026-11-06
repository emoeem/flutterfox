# Contributing to voicefox

Thanks for putting in the work to improve this project. This document covers what a contributor needs before opening a pull request.

## Development setup

voicefox 是 Rust workspace（player/source/lyric/download/application/runtime/ffi）+ Flutter GUI（`flutter/`）的双栈桌面应用，经 flutter_rust_bridge 连接。

```bash
git clone https://github.com/emoeem/flutterfox
cd flutterfox
cargo fetch
cd flutter && flutter pub get
```

FFI 绑定由 `flutter_rust_bridge.yaml` 生成（`rust_input: crate::api`，Dart 产物落在 `flutter/lib/src/bridge`）；改动 ffi crate 后需重新 codegen。

## Branching and commits

- Branch off `main` for every change. Name branches `feat/add-search-filter` 风格（type/short-description）。
- Write commit messages in [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) format: `<type>[optional scope]: <description>`. Common types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`.
- Mark breaking changes with `!` before the colon (`feat!: ...`) or a `BREAKING CHANGE:` footer.
- Keep commits focused. If a commit conforms to more than one type, split it.

## Before opening a pull request

Run the full local gate:

```bash
cargo clippy --workspace --all-targets
cargo check --workspace
cargo test --workspace
cd flutter && flutter analyze && flutter test
```

All must pass（当前基线：analyze 0 问题、53/53 测试通过）。The pull request template will ask you to confirm this.

## Pull requests

- Fill out every section of the [pull request template](.github/PULL_REQUEST_TEMPLATE.md).
- Keep pull requests small and single-purpose. A PR that does three unrelated things is three PRs.
- Link the issue it closes, if any.

## Reporting bugs and requesting features

Use the [issue templates](.github/ISSUE_TEMPLATE). Do not report security vulnerabilities as public issues: see [SECURITY.md](SECURITY.md).

## Release process

Releases 由 tag 触发 `.github/workflows/release.yml` 构建；版本号以根 `Cargo.toml` 为准，CHANGELOG.md 的 Unreleased 段在 release 时重命名为日期版本。

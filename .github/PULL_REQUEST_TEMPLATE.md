## Summary
<!-- 一段话说清这个 PR 做什么、为什么。 -->

## Changes
<!-- 改动清单；跨 Rust/Flutter 的改动分别列出。 -->

## Checklist
- [ ] `cargo clippy --workspace --all-targets` 通过
- [ ] `cargo check --workspace` 通过
- [ ] `cargo test --workspace` 通过
- [ ] `cd flutter && flutter analyze` 0 问题
- [ ] `flutter test` 全绿
- [ ] 涉及 ffi 改动时已重新 codegen 并提交生成物
- [ ] CHANGELOG.md 的 Unreleased 段已补充（面向用户的改动）

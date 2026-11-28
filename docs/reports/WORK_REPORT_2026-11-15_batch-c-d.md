# 工作报告：Batch C-D（Settings 手机分组 + 滚动底部 padding 单源化 + 360/390/430 矩阵验收）

> 日期：2026-11-15 · 执行环境：Windows 10（Git Bash）· 分支 feat/ui-redesign · 基线 HEAD `4843d27`（Batch C-C 提交）
> 上游：第三轮计划书 §6.3 C-06 + 交接 §四.2（C-D 任务队列）· UI 唯一规格 §6.3/§6.2.6

## 基线

- 分支/HEAD：feat/ui-redesign @ `4843d27`，工作区干净（仅本批改动）。
- Flutter 3.47.9 / Dart 3.13.7 / rustc 1.100.0（gnu）/ FRB 2.13.0——与 C-C 批次一致。
- Rust 面：**零改动**（git diff application/core/source/runtime/ffi/download/lyric/player/app 为空），cargo fmt/clippy/test 门禁沿用 C-C 批次同代码实跑结果（fmt 0 / clippy 0 / 835+4 平台环境限制）。

## 审计结论（Step 1-2）

| 项 | 状态 | 证据（HEAD 4843d27 实测） |
|---|---|---|
| C-06 Settings 手机分组 | 未实现（<640 为横向胶囊行 + 桌面内容直排） | settings_page.dart:141-205 窄窗降级（audit SR-17「胶囊行不记忆滚动位置」） |
| 设置内容实现 | 桌面 `_SettingsBodyState` 私有方法（_groups + 9 类行构建） | settings_page.dart:220-776（单一实现，可提炼） |
| 底部滚动 padding | 各页散落（24 字面量 / VxSpacing.xl 混用） | mobile_home:51、mobile_discover:91、mobile_downloads:106、mobile_search:338、mobile_local:296、mobile_playlist_detail 尾部、library_page ×5 |
| padding 遮挡语义 | 无遮挡缺陷（分层契约已保证） | android_insets.dart：MiniPlayer+NavigationBar 由壳层 bottomNavigationBar 消费、系统 inset 由 SafeArea 消费；滚动内容不被遮挡 |
| 360/390/430 矩阵 | viewport_matrix_test 仅 360 手机档抽样 | viewport_matrix_test.dart（Phase 7 批次口径） |
| 手机壳设置槽种子 | IndexedStack KeyedSubtree('mobile-settings:seed') + SettingsPage 直排 | mobile_shell.dart:578-590 |

## 修改清单

| 文件 | 修改 | 根因 / 必要性 |
|---|---|---|
| `flutter/lib/src/pages/settings_page.dart` | **提炼 `SettingsSectionContent`（StatefulWidget）**：`_groups` 分组 switch + 全部行构建（_row/_group/_switchRow/_sliderRow/_playModeRow/_defaultSourceRow/_qualityRow/_themeModeRow/_shortcutRow/_openQrLogin）自 `_SettingsBodyState` 迁入单一公开实现；桌面 `_content` 改为消费它；State 化仅为沿用 State.context（本类无内部状态，设置项全部即时下发 updateConfig） | 内容/业务单一出处（照 playlist_detail_shared / discover_shared 模式）；手机二级页与桌面双栏右侧不允许第二份 |
| `flutter/lib/src/pages/mobile_settings_page.dart`（新增） | **C-06 手机设置两页**：`MobileSettingsPage`（壳 body 分组列表：9 组入口行 icon+label+chevron，触控 ≥48dp，列表不依赖 config 快照；`initialSection` 种子首帧后自动推入对应二级页一次）+ `MobileSettingsSectionPage`（推入路由自带 Scaffold+AppBar，config 未达如实「配置加载中…」，到达后渲染 SettingsSectionContent） | §6.3 C-06「分组列表与独立二级设置页，避免桌面双栏挤进手机宽度」 |
| `flutter/lib/src/shell/app_shell.dart` | settings 槽 form 分叉（mobile → MobileSettingsPage；desktop/平板 → SettingsPage 不变） | 接线唯一出处 |
| `flutter/lib/src/shell/android_insets.dart` | 新增 `mobileListBottomPadding()` 单源 helper（=VxSpacing.xl）+ 契约注释 | C-D padding 单源化唯一改动点；「联动」语义=分层契约已保证不遮挡（见审计），呼吸空间统一取值 |
| 7 个页面 padding 替换 | mobile_home/discover/downloads `fromLTRB(…,24)`、mobile_search/local `bottom: VxSpacing.xl`、mobile_playlist_detail 尾部 SizedBox、settings 两页、library_page ×5 → `mobileListBottomPadding()` | 消灭散落字面量；桌面/平板共用页面（library）数值不变（helper 同值 24） |
| `flutter/test/mobile_settings_page_test.dart`（新增） | 5 用例：9 组齐备+三视口无溢出+触控 ≥48dp / 点组推入二级页+config 未达加载态 / config 到达渲染真实设置项 / 音源管理种子自动推入 / buildShellPage 桌面槽守卫 | C-06 四态与接线 |
| `flutter/test/mobile_shell_test.dart` | 3 处断言按新行为重写（不削弱）：navRequest→设置断言分组列表行（原「配置加载中…」）；抽屉「设置」断言分组列表；音源管理种子断言改为 MobileSettingsSectionPage 在树 + 设置槽 KeyedSubtree（skipOffstage:false——auto-push 的不透明路由使其下设置槽被 Overlay 标记 below-opaque） | §0.1.14 允许：行为断言语义保留、视觉断言按新行为更新 |
| `flutter/test/viewport_matrix_test.dart` | +2 用例（390/430 全目的地矩阵：五主入口逐个切换 + 抽屉设置/帮助，逐目的地无溢出断言） | §6.5 矩阵扩充 |

## 契约 / 行为变化

- Rust API / DTO / Command / Event：无（本批 Dart-only）。
- Dart Adapter：`buildShellPage` settings 槽新增 mobile 分叉；`SettingsSectionContent` 新公开组件。
- 平台行为：手机壳设置目的地 = 分组列表（原桌面内容直排）；抽屉「音源管理」种子 = 直达 sources 二级页；全部设置项行为/命令/即时下发语义不变；桌面/平板零变化。
- 兼容策略：mobile_shell IndexedStack 的 KeyedSubtree 种子键保留（测试护栏 continue 有效）；SettingsPage（桌面）构造签名不变。

## 验证

| 命令 / 操作 | 平台与环境 | 退出码 | 通过 / 失败 | 备注 |
|---|---|---:|---|---|
| `flutter analyze --fatal-infos` | Windows / Flutter 3.47.9 | 0 | No issues found | 全仓 |
| `dart format --output=none --set-exit-if-changed lib test` | 同上 | 0 | 272 files 0 changed | |
| `flutter test`（逐文件顺序实跑，退出码判定） | 同上 | 0 | **494 passed / 0 failed**（60 文件全绿） | 基线 483（C-C）+ 本批新增 mobile_settings 5 + viewport_matrix 2 + 计数口径修正（now_playing 全量 18）= 494 |
| cargo fmt / clippy / test | Windows / rustc 1.100.0 gnu | 0 / 0 / — | 沿用 C-C 实跑（本批 Rust 零改动） | |

**如实登记**：
- 底部 padding「联动 MiniPlayer+NavigationBar+bottom inset」的实现裁决：android_insets.dart 分层契约（MiniPlayer+NavigationBar 由壳层 Scaffold bottomNavigationBar 消费、系统 inset 由 SafeArea/NavigationBar 消费）已结构性保证滚动内容不被遮挡——故不存在「补偿型」padding 需求；C-D 落地为单一出处常量 + 契约注释（未来若引入 overlay 型底栏，唯一改动点=该 helper）+ 360/390/430 矩阵无溢出断言。全仓 grep 无 overlay 型底栏。
- 手机壳设置槽种子 auto-push 后，其下设置槽被 Overlay 标记 below-opaque（Visibility false）——mobile_shell_test 的种子断言以 skipOffstage:false 保持护栏有效（KeyedSubtree 键保留在树）。
- 交互式手操（设置项改动在真机的回流/失败 toast）维持未验证口径（P1-06 / 运行时证据分离）。

## 缺陷矩阵更新

- SR-03 手机复用桌面收敛 **8/8**（Settings 手机分组落地为最后一块；8 页 = 首页/发现/搜索/下载/歌单详情/本地音乐/设置/帮助 + 曲库 <512 补丁核验收口）。
- SR-17 内「settings 配置失败无错误态」维持（config==null 仅文字加载态——本批二级页同口径如实登记，错误态归后续批次）。
- 其余矩阵项无状态变化。

## Git 状态

- 修改：10 个文件（settings_page/library_page/app_shell/android_insets + 5 mobile 页 + 2 test）。
- 新增：2 个文件（mobile_settings_page.dart + mobile_settings_page_test.dart）。
- 是否提交：**待用户授权**（§0.4.9）。是否推送：**待用户授权**。

## 下一批次建议

- Batch D（桌面体验完善）：DesktopContentConstraint 限宽（SR-10）、右键菜单缺口精查（SR-11 残余=网格卡面）、FocusTraversalGroup（SR-13）、Header 搜索双向同步（SR-14）、首页歌单入口进详情（SR-15）。
- 工具链备注（Windows 会话交接）：flutter test 需 VS Build Tools（已装）；`flutter test` 单命令全仓模式在本机有 flutter-tester 进程瞬时挂起抖动，以逐文件顺序实跑为等效全量口径；Rust 用 gnu 宿主工具链 + w64devkit（PATH 提供 gcc/dlltool/libgcc_eh）+ MPV_SOURCE 指向 libmpv-audio 预编译件 + `--features lx-player/build_libmpv`。

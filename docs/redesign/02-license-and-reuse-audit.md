# 许可证与复用审计（02-license-and-reuse-audit，2026-11-10）

- 依据：`docs/VOICEFOX_UI_REDESIGN_EXECUTION_GUIDE.md` §2.2/§2.3；输入为 6 份研究记录 + 基线 `00-baseline.md`。
- Voicefox 根许可证：**MIT**（`LICENSE:1-2`，Copyright (c) 2026 emoeem，汇总人本次实读）。兼容性基准即 MIT。
- 核验方式：各记录对根 LICENSE 全文或首部实读、依赖逐一实查（pub.dev API score tag / raw.githubusercontent /
  pub-cache 归档解包 / clone 内 LICENSE 实读）；汇总人 2026-11-10 以 `head /tmp/voicefox-ref/<repo>/LICENSE`
  对 6 个仍在场的克隆复核根许可证，全部与记录一致。

---

## ⚠️ 0. 最高法律风险：harmonoid = PolyForm Strict 1.0.0【已证实，最高优先级标注】

> **结论已被两次独立证实，必须全员知晓：**
>
> 1. 研究记录实读根 LICENSE 全部 104 行：Copyright License 节（LICENSE:11-17）授予的版权许可
>    *"for any permitted purpose, **other than distributing the software or making changes or new works based on
>    the software**"*——即**禁止再分发、禁止制作衍生作品**；仅允许非商业/个人用途（LICENSE:25-35）。
> 2. 汇总人 2026-11-10 执行 `head /tmp/voicefox-ref/harmonoid/LICENSE`，首行即
>    `# PolyForm Strict License 1.0.0`（<https://polyformproject.org/licenses/strict/1.0.0>），证实记录结论。
>
> **因此：禁止把 harmonoid 的任何代码、assets/ 内矢量与图标资产复制进 Voicefox——复制即违反「不得制作衍生
> 作品」条款，即使不发布、只进仓库也已在「制作新作品」。唯一合法姿势是设计级参考：读源码理解交互/布局思路，
> 之后在 Voicefox 中自行实现。**
>
> **许可证历史陷阱**（git log --follow LICENSE 实测）：≤2022-02-15 的旧快照（commit 1197a8be 及更早）是
> **GPL-3.0**；2022-02~2024-02 期间是专有 EULA；2024-02-22（commit 96b6df96）起才是 PolyForm Strict。
> **不存在任何「MIT 时代」——从旧 tag 摘代码会让 Voicefox 整体陷入 GPL-3.0 传染，同样禁止。**
>
> **附带事实**：公开树不可构建——`.gitmodules` 10 个子模块中 9 个实测 `Repository not found`（private/smtc-win32/
> tag_reader/adaptive_layouts/media_library/identity/taglib/discord_social_sdk/lastfm 等），闭源依赖覆盖 lib/ 266 个
> dart 文件中的 73+68+28+4+4 个；`media_player.dart:14` 直接 import 闭源 CrossfadePlayer。属 source-available
> 仅供阅读，不存在「挑文件搬走」的可能。另 syncfusion_flutter_sliders（社区许可：年收入<$1M 且开发者<5 人，
> 否则商业授权）非 OSI，若参考其滑杆用法需注意边界。

---

## 1. 总矩阵：谁允许代码移植、谁只允许交互参考

| 项目 | 根许可证 | 传染性 | 代码移植判定 | 交互参考 | 一句话边界 |
|---|---|---|---|---|---|
| **myune_music（仓库内 vendored）** | Apache-2.0 | 弱（文件级保留声明） | ✅ **允许，且为 §2.3 优先级 1**——冻结树已落地 | ✅ | 保留文件头来源标注 + 修改声明；上游不再回写不跟进 |
| **aethertune** | 0BSD | 无 | ✅ **允许直接复制**（最宽松）；但按 §2.3 已 vendored 的 myune 优先，只做零耦合组件级移植 | ✅ | 0BSD 不要求署名，按 §2.2 仍保留来源声明（仓库+SHA） |
| **finamp** | MPL-2.0 | 中（**文件级** copyleft，不传染其余项目） | ⚠️ **允许「小幅改造」个别 UI 文件**，成本大于仅借鉴；服务层不采用 | ✅ | 每个拷贝文件保留 MPL-2.0 头并对该文件修改开源；Voicefox 整体 MIT 不受传染 |
| **feishin** | GPL-3.0 | **强**（整体 copyleft） | ❌ **禁止**（含 CSS module；逐文件翻译即重写） | ✅（『读设计不读着抄』） | 任何复制 = Voicefox 整体必须 GPL → 违约 |
| **nuclear** | AGPL-3.0-only | **最强**（+网络服务条款） | ❌ **禁止**（含「改写式移植」） | ✅（思想吸收，实现全重写） | 同上，且网络服务器运行也须开源（Preamble 40-48 行） |
| **harmonoid** | PolyForm Strict 1.0.0 | 特殊（禁衍生/禁再分发） | ❌ **禁止**（代码+资产均禁） | ✅ 仅设计级 | 见 §0 显眼标注 |

**结论**：允许代码级复用的只有 **myune（已 vendored，优先）**、**aethertune（零耦合纯 Dart 组件）**、
**finamp（个别 UI 文件，须履行 MPL-2.0 文件级义务）**。feishin / nuclear / harmonoid 只允许交互/设计参考。

## 2. 逐项目审计

### 2.1 myune_music（vendored，Apache-2.0）——已履行的义务

- 上游根 LICENSE = Apache-2.0（pinned SHA `5188867b2f986e79260d8191c0c659bc1d2216ad` 实读 LICENSE:1-39）：
  §2 版权许可、§3 专利许可（专利诉讼即终止）、**§4 再分发须随附许可证副本/声明修改/保留版权与 NOTICE**。
- **已履行**：110 个 vendored .dart 文件头统一标注
  `// Vendored from https://github.com/xiaobaimc/myune_music @ 5188867b2f986e79260d8191c0c659bc1d2216ad`
  （汇总人本次实读 lyrics_widget.dart:1-3、license_service.dart:1-3 确认）；seam 注入以
  `// === voicefox seam: begin/end ===` 显式标记（仅 2 处：lyrics_handler.dart:70-80、
  playlist_content_notifier.dart:739/771 附近，注释明言「只做只读投影，不触发任何播放入口；上游逻辑一行未改」）。
- **三级依赖署名**：lyricGeter（WisteriaZy/lyricGeter，KRC/QRC/YRC 解析参考实现）= **MIT**（Copyright (c) 2026
  大触紫衣），全文内嵌注册于 `flutter/lib/src/myune/services/license_service.dart:8-40`（本次实读确认，
  LicenseRegistry + LicenseEntryWithLineBreaks，关于页署名义务已履行）。
- **依赖边界**（记录逐一实读）：mpv_audio_kit（git pin e8768813）= BSD-3（clone HEAD 实读；**pin 精确版本未读**，
  fetch 两次网络失败；风险低——voicefox 不发行该包，shim 本地新写）；vendored UI 依赖面 pub-cache 实读
  provider/rxdart/mesh_gradient/silky_scroll/window_manager/file_picker/cached_network_image/markdown_widget/uuid = MIT
  或 Apache-2.0，scrollable_positioned_list/colorgram = BSD-3，pinyin = BSD-2，pointycastle = Bouncy Castle BSD-3 风格，
  http/crypto/path/shared_preferences/path_provider/url_launcher = Dart/Flutter authors BSD-3。
  hotkey_manager 0.2.3 与 system_fonts 1.0.1 被 voicefox 以**本地 clean-room stub** 覆盖（flutter/packages/ 文件头
  自述为 voicefox 编写），未发行上游代码——**上游两包许可证未验证**，将来解除 stub 换真包需补核对。
- **待办（本次新发现，登记）**：vendored 文件头引用的
  `/home/emo/code/myune_music-reference/LICENSE` 路径在本机已不存在（记录实测 git rev-parse exit 128）——
  **建议把该引用改为仓库内 NOTICE 文件**（含上游 URL/pin SHA/Apache-2.0 全文或指引/修改声明/lyricGeter MIT 指引），
  满足二进制分发时 Apache-2.0 §4 的「随附许可证副本 + 声明修改」要求。整改不在本次 ask 范围，此处仅登记。
- **冻结策略**：上游已领先 3 个 commit（bedd052/cba771b/c7614d0，后者 2026-11-09 "feat: 新增流派页面"，本次实测
  origin/master 可达）；冻结策略下不回写不跟进，若将来同步上游需重跑逐文件 diff 冻结验证。

### 2.2 aethertune（0BSD）——允许移植，义务最轻

- 根 LICENSE 实读为 BSD Zero Clause（Copyright (C) 2026 AetherTune Contributors）：允许任意使用/修改/分发且
  **不要求署名**。汇总人复核首行一致。
- **移植履行方式**：0BSD 无强制义务；按指南 §2.2 仍在移植文件头保留来源声明（`// Ported from
  https://github.com/Yunushan/aethertune @ ccde7234…`）以便溯源。**注意引用必须固定 Yunushan/aethertune**——
  GitHub 同名仓 nevermore23274/AetherTune（Rust 终端电台播放器，131 stars）是外部初步核查命中的另一个项目。
- **其 vendored 包若被一并拷贝**：rhttp（MIT，Tien Do Nam，基于 Tienisto/rhttp @9871f1c，改动记录于
  AETHERTUNE_PATCHES.md）与 audio_service_mpris（MIT，Boris Drazhzhov）——须保留其 LICENSE 文本与署名；
  flutter_secure_storage（BSD-3-Clause）全文内嵌于其 NOTICE。当前 Voicefox 未拷贝这些包，仅登记边界。
- **LRCLIB 边界**：其 lrclib_lyrics_provider 仅限运行时公共 API 调用，NOTICE 明确不捆绑歌词内容——移植适配时
  须保留该边界与出处标注。
- 依赖（pub.dev API score tags 核查）：just_audio Apache-2.0/MIT、media_kit MIT、provider MIT、audio_service MIT、
  audio_session MIT、just_audio_media_kit Unlicense、dynamic_color Apache-2.0、window_manager/sqlite3/file_picker/
  tray_manager/hotkey_manager/smtc_windows MIT、flutter_secure_storage/share_plus/material_ui BSD-3、
  app_links Apache-2.0——无 copyleft 污染。

### 2.3 finamp（MPL-2.0）——文件级 copyleft 的正确履行

- 根 LICENSE 实读全文 374 行 = **MPL-2.0**（不是早期备注猜测的 Apache 系）。关键条款：
  - **§3.1 文件级 copyleft**：修改 Covered Software 源文件须仍以 MPL-2.0 发布；
  - **§3.3 Larger Work**：可用自有条款组合——MPL 文件进 MIT 项目**合法**，被拷贝文件及其修改保持 MPL-2.0 即可，
    **不传染项目其余部分**；
  - **§3.4**：禁止移除版权/许可证声明；
  - §2.1(b) 专利授权 + §2.3 限制；§5.2 专利诉讼终止。
- **允许的移植形态**：仅个别 UI 文件「小幅改造」（候选清单见 03 报告：lyrics_screen 交互、PlayerHideableController、
  progress_slider 模式等）。**服务层不采用**（Jellyfin 深耦合 + 14 个 git-fork 依赖）。
- **移植履行方式（对每个拷贝文件）**：
  1. 保留原文件 MPL-2.0 头与版权声明（§3.4 禁止移除）；
  2. 追加来源标注：`// Portions Copyright (c) finamp contributors, MPL-2.0; source: github.com/finamp-app/finamp @
     337a2fd8…; modified by voicefox`；
  3. 该文件的修改版以 MPL-2.0 提供（在文件头注明「This Source Code Form is subject to the terms of the Mozilla
     Public License, v. 2.0」）；Voicefox 其余文件保持 MIT 不变；
  4. 在 NOTICE/THIRD-PARTY 清单登记 finamp + MPL-2.0。
- **依赖边界**：19+5 个直依赖经 pub.dev API license tag 实查（2026-11-10）全为宽松许可（Apache-2.0/BSD-3/MIT），
  与 MIT 兼容——**但仅当真正引入某依赖时才需要履行其义务，仅参考 UI 不引入依赖则无义务**。
  风险：pubspec.lock 实数 14 个 git-fork 依赖，fork 端 LICENSE 未逐一核验——**禁止照搬其 pubspec**。

### 2.4 feishin（GPL-3.0）——只允许交互参考

- 根 LICENSE 逐行读完 675 行 = FSF 标准原文 GPL-3.0，无附加条款；package.json:23 同。关键条款：§5c 衍生作品
  整体须继续 GPL；§6 传导须附源码；§11 专利授权；§15/16 无担保。
- **禁止**任何 feishin 源码（src/**，**含 CSS module**）复制进 Voicefox；仓库内 vendored myune（Apache-2.0）可并入
  GPL 项目（单向兼容），**反向**把 feishin GPL 代码搬进非 GPL 的 Voicefox 代码树构成违约。
- **纪律**：『读设计不读着抄』——记录设计来源页（如 queue 操作语义 types.ts:122-130）供实现者理解行为，
  实现保持无代码级相似性；版本固定 SHA `e60dcc80…` 以免设计漂移（仓库活跃，近月 PR #2689 等）。
- 依赖：zustand/@tanstack/react-query/@mantine/core/react-window/motion/music-metadata/@radix-ui
  react-context-menu/fast-average-color = MIT、wavesurfer.js = BSD-3（raw.githubusercontent 实读）——宽松，
  但 feishin 自有源码整体按 GPL 处理，边界不变。**未核验**：node-mpv（jeffvli 私有 fork，package.json git 引用）、
  butterchurn 系、react-split-pane、react-player、mpris-service、@xhayper/discord-rpc、electron 系列——
  不采用这些能力即绕开；若未来任何人想参考 node-mpv fork 须先确认其 LICENSE。

### 2.5 nuclear（AGPL-3.0-only）——只允许交互参考

- 根 LICENSE 实读 = 完整 GNU AFFERO GENERAL PUBLIC LICENSE v3 文本；package.json:49 `"license": "AGPL-3.0-only"`；
  player/src-tauri/Cargo.toml 同。强 copyleft：衍生作品须整体 AGPL 开源；**§Agentic 条款（Preamble 40-48 行）**
  网络服务器运行也须向用户提供源码。
- **禁止**复制任何 nuclear 源码文本/代码结构到 Voicefox（**包括「改写式移植」**）；交互与信息架构思想可参考，
  实现须全部重写为本仓库自有代码。参考输入固定 SHA `46d1d938…`（master 处于 Electron→Tauri 大迁移中段，
  legacy/electron 分支冻结但同为 AGPL-3.0）。
- 依赖：JS 侧（zustand/immer/TanStack 全家桶/tailwind4/motion/lucide/dnd-kit/radix/headlessui/react-hotkeys-hook/
  esbuild-wasm）与 Rust 侧（tauri 2.7/reqwest/sqlx/axum/rmcp）均为常见宽松许可生态，但逐一包/crate 许可证文件
  未打开验证（lock 文件不含 license 字段）——**即使依赖宽松，nuclear 本体代码是 AGPL，边界不变**。

### 2.6 harmonoid（PolyForm Strict 1.0.0）——见 §0 显眼标注

- 只允许设计级参考；许可证演变史（实测 git log --follow LICENSE）：GPL-3.0（2020-12-17，1197a8be）→ 专有
  EULA.txt（2022-02-15，723c11cf，禁止再分发/反编译）→ PolyForm Strict（2024-02-22，96b6df96，与当前一致）。
- **旧快照摘代码 = GPL-3.0 传染**，EULA 快照 = 专有侵权，两个方向都禁止。
- 依赖边界（记录逐一实读）：media_kit 1.2.6 = MIT（上游 LICENSE 实读）；go_router 16.3.0 = BSD-3（Flutter Authors）；
  drift 2.31.0 = MIT；provider 6.1.5+1 = MIT（pub.dev 归档解包）；audio_service 0.18.18 = MIT（归档解包）；
  **syncfusion_flutter_sliders 24.2.7 = Syncfusion License 非 OSI**（社区许可条件：年收入<$1M 且开发者<5 人）；
  git ref 固定 fork（flutter_local_notifications@54c397a、mpris_service、windows_taskbar、dart_lrc、
  m3_expressive_shapes@e023ce8）**许可证未逐一验证**。这些仅影响「阅读理解」，无复制即无义务。

## 3. 移植需要保留的版权声明 / NOTICE 清单（操作级）

| 来源 | 移植动作 | 必须保留/登记 |
|---|---|---|
| myune vendored（Apache-2.0） | 已落地，继续复用 | ① 文件头 `Vendored from … @5188867b` 保留；② seam 注入保持 `=== voicefox seam: begin/end ===` 标记；③ lyricGeter MIT 全文保持在 license_service.dart 注册；④ **建议新建仓库内 NOTICE**（上游 URL + pin SHA + Apache-2.0 指引 + 修改声明 + lyricGeter 指引），替代已失效的文件头外部路径引用 |
| aethertune（0BSD） | 零耦合组件移植 | 文件头 `// Ported from https://github.com/Yunushan/aethertune @ ccde7234…`（溯源用，非法律强制）；若拷贝其 vendored rhttp/audio_service_mpris 则保留 MIT LICENSE 文本 |
| finamp（MPL-2.0） | 个别 UI 文件小幅改造 | ① 原文件 MPL-2.0 头与版权声明完整保留；② 追加来源 + SHA + modified 标注；③ 该文件以 MPL-2.0 提供修改版；④ NOTICE/THIRD-PARTY 登记 finamp/MPL-2.0 |
| lyricGeter（MIT，经 myune 间接引入） | 已引入 | license_service.dart:8-40 全文注册保持不动（Copyright (c) 2026 大触紫衣） |
| feishin / nuclear / harmonoid | **无移植** | 无文件可保留——保持零复制状态即为合规；设计参考记录只需注明「思想来源 + SHA」，不得携带代码 |

**Voicefox 根 MIT + NOTICE 建议结构**（供 Phase 后续执行）：`NOTICE` 列出 myune_music（Apache-2.0，pin 5188867b）、
lyricGeter（MIT，经 license_service 注册）、任何未来引入的 finamp MPL-2.0 文件、aethertune 0BSD 移植件；
并声明各来源文件许可证不变、修改已声明。

## 4. 与 Voicefox 根 MIT 的兼容性结论

| 许可证 | 可并入 MIT 项目？ | 条件 |
|---|---|---|
| MIT / BSD-2 / BSD-3 / 0BSD / Unlicense | ✅ | 保留版权与许可声明（0BSD 无强制，按 §2.2 保留来源声明） |
| Apache-2.0 | ✅ | §4：随附许可证副本、声明修改、保留 NOTICE；专利授权随文件 |
| MPL-2.0 | ✅（文件级） | 被拷贝文件及其修改保持 MPL-2.0；不传染其余文件（§3.3 Larger Work） |
| **GPL-3.0** | ❌ | 整体传染——Voicefox 必须整体 GPL，违约 |
| **AGPL-3.0-only** | ❌ | 同上且更严（网络服务条款） |
| **PolyForm Strict 1.0.0** | ❌ | 连衍生权都未授予——比 GPL 更硬，复制即侵权 |

## 5. 环境限制与本次核验范围声明

- 汇总人 2026-11-10 实跑的核验：`git rev-parse HEAD` × 6 仓库（全部与记录 SHA 一致）、`head LICENSE` × 6 +
  voicefox 根 LICENSE、vendored 文件头与 license_service.dart、projection.dart/adoptExternal 接缝、
  design_system 组件清单（详见 01 报告卷首）。
- **未由汇总人重跑、依赖记录背书的内容**：各记录内对依赖的逐一许可实查（pub.dev API/raw.githubusercontent/
  pub-cache 解包，执行日 2026-11-06~11-10）；harmonoid LICENSE 104 行全文与 git log --follow 演变史；
  finamp LICENSE 374 行全文；feishin LICENSE 675 行全文；myune 与上游 5188867b 的 110 文件 diff。
  记录明确标注了各自的执行命令与失败项（如 api.github.com 在研究环境不可达、TLS 中断等），本报告按记录引用。

## 6. 诚实清单（未验证项汇总，来自各记录）

1. **参考项目运行证据**：6 个项目均未构建/运行（见 01 报告 §0）——§2.2「页面截图或运行证据」条目未满足，以源码级核验代替并如实登记。
2. finamp：14 个 git-fork 依赖的 fork 仓库 LICENSE 未逐一打开；未做全量传递依赖审计；media_kit_libs_windows_audio
   用的 Komodo5197 fork mpv-winbuild 二进制分发条款未核验；iOS/CarPlay 分支未验证。
3. nuclear：npm/crate 逐一许可证文件未打开（lock 文件无 license 字段）；legacy/electron 分支仅抽查头 3 commit；
   esbuild-wasm 插件沙箱细节未深入；移动端 targets 未发现。
4. feishin：node-mpv 私有 fork、butterchurn 系、react-split-pane、react-player、mpris-service、@xhayper/discord-rpc、
   electron 系列许可证未核验；队列拖拽逐行实现、src/main 主进程（MPRIS/DLNA/scrobble）未深读。
5. harmonoid：lib/private 内容不可访问（CrossfadePlayer 实现无法验证）；应用未构建未运行（公开树缺 9/10 子模块）；
   git ref 固定 fork 依赖许可证未逐一抓取；identity 套件 LyricsView 实现不可读。
6. myune：mpv_audio_kit **pin e8768813 精确版本**的 LICENSE 未读（clone HEAD 验证为 BSD-3）；hotkey_manager 0.2.3 与
   system_fonts 1.0.1 上游许可证未验证（voicefox 用本地 stub）；上游 3 个新 commit 差异未评估；运行时证据未产出
   （vendored 冻结树按 §7.3 不作为构建入口）。
7. aethertune：commit 总数 847 来自 GitHub API 累加（本地 unshallow 因 TLS 失败）；pub.dev score tag 未逐一打开上游
   LICENSE 文件（vendored 包除外）；services/server 未逐行审计；本地化 RTL 实际效果未验证。

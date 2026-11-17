# Phase 4 Report（播放器和移动端系统媒体体验）

- 收口轮日期：2026-11-12（缺陷修复验证 + 重建 + 真实运行重截 + QA 复查；报告员独立实跑复核）。
- Phase 4 主体（Mini Player、Now Playing 全屏页、歌词/队列、手势、audio_session 生命周期）跨批次落地：Mini Player 于 Phase 2 收口（§17）；全屏播放页封面 280-340dp 自适应带（P2-12）、封面横滑切歌（P2-06）、队列底部 sheet、歌词点击门槛、audio_session 中断处理于 2026-11-12 封面带追加批次落地（见 phase-2-report.md 追加批次节与 04 矩阵）；本报告覆盖 Phase 4 收口轮全部证据与 §13 退出条件核对。

## 范围

- 本轮（收口轮）：全屏播放页大封面 403 灰占位缺陷根因修复（网易系封面 CDN 封杀 Dart 默认 UA）+ debug 重建 + Xvfb 真实在线播放（kw/wy 源）重截受影响视口 + QA 复查（P0 无、P1 封面异常关闭）+ §13 Phase 4 退出条件复核。
- 不在本轮范围：Android 后台服务/通知/锁屏/耳机蓝牙真机验证（环境阻断，P1-06 维持，见「未解决问题和原因」）；浅色主题（归 Phase 7）；release 重建（本轮为 debug 构建，见「构建结果」）。

## 修改文件

未提交工作区改动（`git status` 实测：M ×4 + 未跟踪 ×2 + 截图目录；随收口提交入树）：

| 文件 | 变更 | 内容 |
|---|---|---|
| flutter/lib/src/widgets/cover_image.dart | +35 | 修复主体：`coverUserAgent = 'voicefox'`（:17）+ `coverReferer(url)` 按音源映射（:21-33）+ `coverImageHttpHeaders(url)`（:36-41）+ `CachedNetworkImage(httpHeaders: …)` 下发（:87） |
| flutter/lib/src/playback/voicefox_audio_handler.dart | +29/-5 | Phase 4 pause 守卫：`_pausingForInterruption` 区分「让焦自动暂停」与「用户手动暂停」，`pause()` 非自动发起时清空恢复守卫，`onInterruptionEvent` begin 置位绕过清空（end 才能恢复） |
| flutter/test/cover_image_headers_test.dart | 新增（12 项） | Referer 按音源映射 5 项（镜像 Rust `cover_referer`）+ 请求头构造 4 项 + `CachedNetworkImage.httpHeaders` 下发 widget 3 项 |
| flutter/test/voicefox_audio_handler_test.dart | 新增（8 项） | 焦点中断 4 态（begin 记录并暂停 / end 且抢占前在播恢复 / 抢占期手动暂停 end 不覆盖 / 抢占前未在播不恢复）+ 元数据映射 2 项 + playbackState 映射 2 项 |
| flutter/test/mobile_now_playing_test.dart | +84 | 新增 group「LiveSeekRow 拖动 seek 契约（§5.1）」2 项（有 duration 派发真实 seekMs / 无 duration 手势禁用如实显 --:--） |
| flutter/test/mobile_shell_test.dart | +31 | 新增「系统返回（PopScope）：全屏打开时返回先退全屏而非退壳」1 项 |
| docs/redesign/screenshots/phase-3-player/*.png | 重截 3 张 + 保留 1 张 | 见「截图路径」 |

## 关键设计决策

1. **UA 换族而非伪装浏览器**：`coverUserAgent = 'voicefox'`，对齐 Rust 侧封面下载的 UA 家族（`runtime/src/cover_src/source.rs` 的 `voicefox/<版本>`）；不透传 dart:io 默认 UA `Dart/<ver> (dart:io)`。Phase4-QA1 实锤网易系 CDN（p2.music.126.net 等）封杀含 `Dart/` 的 UA 一律 403 text/html（注释登记于 cover_image.dart:9-15）。
2. **Referer 映射与 Rust 单点镜像**：`coverReferer` 逐条镜像 Rust `cover_referer`（source.rs:166-174，顺序一致）：kuwo.cn→www.kuwo.cn、kugou.com→www.kugou.com、qq.com→y.qq.com、music.163.com/126.net→music.163.com、其余 null；Flutter 直拉与 Rust 下载对部分防盗链 CDN 保持同一行为。
3. **httpHeaders 整体覆写语义**：UA 经 flutter_cache_manager 的 HttpFileService（package:http IOClient 以 `headers.set` 落到 dart:io 请求，io_client.dart:119-120）整体覆写默认 UA 而非叠加，大封面与队列行共用同一映射即可（cover_image.dart:36-41 注释）。
4. **音频焦点 pause 守卫**：`onInterruptionEvent` begin 时快照在播态并置 `_pausingForInterruption=true` 后暂停；用户经通知栏/锁屏/耳机的手动 `pause()` 清空 `_playingBeforeInterruption`，end 事件不得覆盖用户意图；应用内 dispatch 暂停不经 handler（host_player_bridge 直达 MobileAudioPlayer），其快照回声与本自动暂停回声不可区分，登记为 Phase 4 已知限制（代码注释如实载明）。

## 数据流/交互变化

- 封面链：`CoverImage` 全部网络请求携带 `User-Agent: voicefox` + 按音源 `Referer`，网易系 CDN 403 解除，全屏播放页大封面恢复真实渲染；首页卡片/迷你栏/队列行同组件受益。
- 音频焦点链：begin（抢占）记录在播快照并自动暂停；end 仅在「抢占前确实在播且非用户手动暂停」时恢复播放。
- 全屏页返回链：系统返回（PopScope）在全屏打开时先退全屏而非退壳（回归测试锁定）。

## 执行命令与退出码

报告员本轮实跑（2026-11-12，/home/emo/flutter/bin/flutter 3.47.9，flutter/ 目录）：

| 命令 | 结果 | 退出码 |
|---|---|---|
| `flutter test test/cover_image_headers_test.dart test/voicefox_audio_handler_test.dart test/mobile_now_playing_test.dart test/mobile_shell_test.dart test/now_playing_test.dart --reporter compact` | `00:08 +56: All tests passed!` | 0 |
| `flutter test test/cover_image_headers_test.dart test/mobile_now_playing_test.dart --reporter compact` | `00:04 +26: All tests passed!` | 0 |
| 根因对照：`curl -A "Dart/3.9 (dart:io)" http://p2.music.126.net/DrNrcSu1YLan6Oya57x60A==/109951173908998514.jpg` | **403 text/html 146B** | 无 |
| 根因对照：`curl -A "voicefox" <同 URL>` | **200 image/jpg 602586B**（magick identify：JPEG 3000x3000） | 无 |

- 封面 URL 取自本轮 QA 运行日志 /tmp/p4/verify_run3.log:76（`playback.cover=http://p2.music.126.net/…/109951173908998514.jpg`，song=Love state=playing）；curl 双向对照为报告员独立复跑，与 Phase4-QA1 实跑结论一致（QA 记录：Dart UA 403 text/html、voicefox UA 200 image/jpg）。
- 本轮运行记录（实施/QA 会话，ask 已知事实，报告员未复跑）：`flutter build linux --debug`（含 cargo libvoicefox_ffi.so）exit 0，输出 `✓ Built build/linux/x64/debug/bundle/voicefox_flutter`；Xvfb :101 600x900 私有显示（:99 被并行 actor 1200x1600 实例占用，报告员 pgrep 复测 `Xvfb :99 -screen 0 1200x1600x24` 在位 pid 686423）+ `GDK_BACKEND=x11` + `VOICEFOX_START_SIZE` 验收钩子启动重建后的真实 app，kw/wy 源真实在线播放 Love CNBLUE（wy 网易系，即原缺陷触发源），xdotool 驱动、`import` 截取 + ImageMagick 裁切。

## 测试结果（通过/失败/跳过）

- 定向 5 文件 **56 项：通过 56 / 失败 0 / 跳过 0**（报告员实跑，逐文件数与 grep 声明数吻合）：cover_image_headers 12 + voicefox_audio_handler 8 + mobile_now_playing 14 + mobile_shell 9 + now_playing 13。
- 修复验证 2 文件 **26 项：通过 26 / 失败 0 / 跳过 0**（cover_image_headers 12 + mobile_now_playing 14；其中新增头逻辑断言：coverReferer 按音源映射 5 项镜像 Rust `cover_referer`、UA 构造为 voicefox 家族不含 Dart、126.net 域附 music.163.com Referer、`CachedNetworkImage.httpHeaders` 下发三层锁定）。
- 上轮结论维持（随本轮套件复跑全绿）：audio_handler 焦点中断 4 态 + Phase 4 pause 守卫（voicefox_audio_handler_test 8 项）；后台播放/切歌/进度/歌词同步/页面切换不重置五项退出条件的 widget/单测层证据在位（now_playing_test 13 项含全屏进出不重置、移出队列真实命令等）。
- 全量 flutter test / cargo test 由外部门禁统一执行（本轮已知事实「门禁全绿」），报告员未复跑全量，如实登记。

## 构建结果

- 本轮运行记录：`flutter build linux --debug` exit 0（含 cargo libvoicefox_ffi.so）；`build/linux/x64/debug/bundle/voicefox_flutter` mtime 11-12 06:22 在位（报告员 `ls` 佐证，早于 06:24-06:25 重截，运行时验证基于含修复的重建产物）。
- **release bundle 未随本修复轮重建**（上轮 03:52:19 的 release bundle 不含本修复）；release 重建随收口提交后批次执行，如实登记。

## 设备和视口

- Linux 桌面（CachyOS）+ Xvfb :101 600x900 私有显示（:99 被并行 actor 的 1200x1600 实例占用）；`VOICEFOX_START_SIZE` 验收钩子请求 560x844 / 560x800，实截 PNG 尺寸经 magick identify 实测 560x844 ×3 + 560x800 ×1。
- 精确移动视口（390×844/360×800）桌面窗口被 `main.dart:163` minimumSize(560,480) 钳到 560 宽（上轮 app 日志 `Timed out waiting for OpenGL frame of size 560x844` 实证；本轮未复测）；移动视口布局由 widget/golden 层断言覆盖。
- kw/wy 源真实在线播放（Love CNBLUE，wy 网易系为原缺陷触发源），非 mock 数据。
- Android 真机/模拟器：无（无 JDK，P1-06 环境阻断维持）。

## 截图路径

| 文件 | 尺寸 | mtime（实测） | 状态 |
|---|---|---|---|
| docs/redesign/screenshots/phase-3-player/linux-nowplaying-560x844-playing.png | 560x844 | 06:24:35 | 重截（137458B） |
| docs/redesign/screenshots/phase-3-player/linux-nowplaying-560x844-lyrics-unavailable.png | 560x844 | 06:24:51 | 重截（137366B） |
| docs/redesign/screenshots/phase-3-player/linux-nowplaying-560x800-playing.png | 560x800 | 06:25:28 | 重截（136827B） |
| docs/redesign/screenshots/phase-3-player/linux-nowplaying-560x844-queue-open.png | 560x844 | 05:18 | 保留原截（80397B，未受影响项；QA 记 minor） |

- 非受影响项无重截：queue-open 的队列行封面为酷我源本就正常（coverReferer 注释与 Phase4-QA1 实锤一致）。

## 视觉 QA 结果

QA 复查通过：**P0 无，P1 封面异常已关闭**。报告员本轮对 4 张截图逐张独立 Read 目检：

1. **linux-nowplaying-560x844-playing.png**（重截）：全屏播放页大封面渲染真实 CNBLUE《BLUE LOVE》专辑图（修复前为灰占位），与元数据 CNBLUE·Bluelove 一致；进度 00:25/03:47 与滑块位置一致；音量 80；深色对比度正常；DEBUG 横幅压 more 按钮为 debug 构建固有；无白黑屏/溢出/遮挡。
2. **linux-nowplaying-560x844-lyrics-unavailable.png**（重截）：大封面真实渲染；00:41/03:47 走带；「暂无歌词」诚实空态文案完整（§9 符合）。
3. **linux-nowplaying-560x800-playing.png**（重截）：大封面真实渲染；00:10/03:47；800 高度无溢出。
4. **linux-nowplaying-560x844-queue-open.png**（旧图 05:18，未重拍，QA 记 minor）：队列证据要素完好（共 22 首、当前行高亮、队列行真实迷你封面）；**但该旧图大封面区为灰占位（修复前缺陷形态）**，与运行记录所述「其封面为酷我源本就正常」存在出入，如实登记；大封面证据由 3 张重拍承担，不由本图承担。

- 首页卡片/迷你栏封面同步恢复（QA 记录，ask 已知事实）。
- 3 张重拍体积 53KB→137KB（QA 记录），与真实位图内容替代灰占位一致。

## 新增/关闭缺陷

- **P1-15 登记并关闭**（详见 04-defect-matrix.md P1 节）：网易系封面 CDN 封杀 Dart 默认 UA（`Dart/<ver>`），全屏播放页大封面 403 灰占位。修复 = cover_image.dart +35（voicefox UA + 按音源 Referer + httpHeaders 下发）；三层回归（映射镜像 Rust / UA 构造 / 下发）12 项全绿；根因 curl 双向实锤（QA 实跑 + 报告员独立复跑同结果：Dart UA 403 text/html、voicefox UA 200 image/jpg 3000x3000 JPEG）；修复后真实运行重截 3 张逐张目检通过。
- 本轮无新增开放缺陷；残留 minor：①queue-open 旧图未重拍（见上）；②403 修复仅目检验证（封面真实渲染），未抓包核对实际请求头，请求头正确性由 cover_image_headers_test.dart 单测锁定（其中 UA/Referer 头逻辑断言 10 项）。

## 未解决问题和原因

**未验证（如实披露，不因测试全绿改判）**：

1. **390×844 / 360×800 真机视口截图**：桌面窗口被 main.dart:163 minimumSize(560,480) 钳到 560 宽，仅以 560×844/560×800 呈现；精确移动视口由 widget 测试断言覆盖。
2. **MobileShell 移动端全屏播放页运行时呈现**（280-340dp 封面带、横滑切歌、上滑歌词层、下滑关闭）：桌面运行时 isTouchPlatform=false 恒走 desktop 壳（responsive_shell.dart:87-95），仅 widget 测试可达。
3. **歌词行点击跳转 seek**：运行时曲目仍为真实「暂无歌词」错误态（无时间戳可点），无法实证；widget 测试覆盖有/无时间戳两种门槛行为（本轮 26 项内）。
4. **移动端队列底部 sheet**：桌面运行时队列为侧板，sheet 行为仅 widget 测试。
5. **audio_service 通知/锁屏/耳机蓝牙/音频焦点/后台播放生命周期**：无 Android 真机或模拟器（无 JDK，P1-06 维持；voicefox_audio_handler_test.dart:17-22 如实声明），真机后台行为与浅色主题维持既有「未验证」披露。
6. **网易系封面 403 修复未抓包核对请求头**：仅目检验证（封面真实渲染）+ curl 双向对照；请求头构造正确性由单测锁定（见「新增/关闭缺陷」）。
7. **队列面板本轮未重开复核**：保留上一轮截图与结论（移出队列 22→21 实证、跳播/排序按设计禁用 queue_panel.dart:265-270）。
8. **release bundle 未随本修复轮重建**（本轮仅 debug 构建）；全量门禁由外部门禁统一执行（已知事实「门禁全绿」），报告员未复跑全量。

## 下一阶段进入条件

- §13 Phase 4 退出条件核对：**后台播放、切歌、进度、歌词同步、页面切换不重置播放**，随本轮定向套件复跑全绿（widget/单测层，含 audio_handler 焦点中断 4 态与 pause 守卫）；**锁屏媒体控制**真机侧未验证（无 Android 环境，P1-06 维持），以 audio_service 元数据/playbackState 映射单测 + 桌面运行时为证据并如实披露。
- Phase 5（本地音乐、下载和离线体验）可进入；Android 真机项作为跨阶段披露维持（P1-06），不阻塞以桌面 + widget 层为证据面的后续阶段。
- 修复代码与新增测试为未提交工作区改动，随收口提交入树（本轮报告员不执行 git 提交）。

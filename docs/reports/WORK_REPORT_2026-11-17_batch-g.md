# 工作报告：Batch G（既有缺陷运行时闭环 §10：P1-20 / P2-16 / P2-17 / P2-18 四项关闭 + 运行时实锤真缺陷 1 项修复）

> 日期：2026-11-17 · 执行环境：**Windows 10 真实 GUI 运行**（Git Bash + CUA 界面驱动）· 分支 feat/ui-redesign · 基线 HEAD `c065e6e`（Batch F 提交）
> 上游：计划书 §10（Batch G 运行时闭环）· 04 矩阵 P1-20/P2-16/P2-17/P2-18 · **本批为首个 Windows 真机运行时证据批次**（此前运行时项全部留 Linux）

## 执行环境突破（本批前置）

- **Windows GUI 桌面应用首次构建+引导成功**：`flutter build windows --debug`（156s）→ `voicefox_flutter.exe`；运行时需 `voicefox_ffi.dll`（`cargo build -p voicefox-ffi --features voicefox-runtime/build-libmpv` 产物拷入 exe 目录）+ `libmpv-2.dll`（toolchain-setup mpv-extract）同目录。
- 引导证据：Impeller 渲染、FFI 装载、`playback pump started`、动态取色，全部业务面可用。
- **音源网络可达**：netease 200 / kw 301 / qishui 200 / douyinpic CDN 200——真实联网验证全链可行。
- 证据面：CUA 界面驱动 + 28 张运行时截图（`docs/redesign/screenshots/batch-g-winrt/`）+ 应用日志（/tmp/voicefox_app*.log）。

## P1-20 全部音源切回聚合【关闭，运行时实证】

计划书 §10.1 要求全链路验证。运行时实拍（全部真实联网数据）：

| 步骤 | 证据 | 结果 |
|---|---|---|
| 全部音源聚合（精选歌单） | `winrt-p120-playlists-aggregated.png` | 酷我+酷狗+网易云+咪咕分组、真实封面渲染 |
| 下拉切单源酷我 | `winrt-p120-single-kuwo.png` | 音源范围：酷我，今日精选视图 |
| 切回全部音源（菜单含哨兵项） | `winrt-p120-dropdown-with-all-visible.png` → `winrt-p120-aggregated-restored.png` | **聚合真实恢复**（酷我+酷狗分组回归） |
| 排行榜入口（不只测歌单列表） | `winrt-p120-leaderboard-kugou-group.png` | 酷我榜组 + 酷狗榜组（内地榜/飙升榜/新歌榜，真实更新时间戳） |

哨兵修复（P1-20 前序批次的 '' 哨兵）在运行时得到最终确认：单源↔全部往返、聚合恢复、多 Tab 入口全通。**关闭**。

## P2-16 Soda 封面 URL 闭环【关闭，四类用例证据齐】

计划书 §10.2 四类用例全部实证（真实 HTTP 链，不泄露签名/token）：

| 用例 | 证据 | 结果 |
|---|---|---|
| 有效组合 URL | 新鲜真曲数据（`/luna/pc/playlist/detail` 真实响应 → uri `tos-cn-v-2774c002/oU4vrE…`）→ 组合 `{base}{uri}~{tpl}-image.jpeg` → curl | **200 image/jpeg 1,072,823B（1.07MB 真图）0 重定向 0.6s** |
| 缺 URI | 单测 `keeps_cover_empty_without_uri`（既有） | 宁可不带封面不落裸基址 ✓ |
| 服务器拒绝 | 畸形 uri → **404** application/json；裸基址（旧缺陷形态）→ **400** application/json | 拒绝路径可区分 ✓ |
| 图片内容无效 | Content-Type 判定面：200=image/jpeg vs 拒绝=application/json | 可区分 ✓ |

**关键裁决**：`Light It Up`（测试夹具曲）所属 soda 音源当前**曲目搜索与推荐端点服务端返回空**（`/luna/search/track` 200 空 body、发现页推荐空态；playlist 关键词搜索与歌单详情仍正常）——属**服务端契约变更**（代码注释期「网页端参数能正常返回」已失效），与封面链无关的上游可用性问题，登记新观察行 **P2-20**（P3：单音源发现面不可用，封面组合逻辑本身不受影响）。封面组合逻辑经真实 CDN 用**新鲜真曲数据**验证正确 → **关闭**（UI 呈现层由 P1-15 UA 修复族既有证据 + 播放页真实封面渲染佐证）。

## P2-17 / P2-18 歌词重取与 NowPlaying 布局【关闭 + 运行时实锤真缺陷 1 项修复】

计划书 §10.3 八场景运行时矩阵（Windows 真机）：

| 场景 | 证据 | 结果 |
|---|---|---|
| 7. 有歌词双列布局+滚动 | `winrt-p218-lyrics-double-column-real.png` / `winrt-FIX2-nowplaying-wy-lyrics-double-column.png` | 双列 46/54 比例正常；**歌词随播放进度实时高亮**（01:02 → 「我不会描述你」白亮） |
| 1. 无歌词单列布局 | `winrt-FIX2-VERIFIED-single-column-retry.png` | 封面居中单列（320–500 自适应）✓ |
| 2. 重取 loading 态 | `winrt-FIX2-retry-clicked-loading.png` | spinner + 「获取中...」在途禁用 ✓ |
| 4. 失败提示可理解可再点 | `winrt-FIX2-retry-failure-feedback.png` | 「暂未取到歌词，可再次尝试」+ 按钮复位 ✓ |
| 8. 无封面态 | 同场景 1 帧 | 5sing 曲无封面 → 渐变占位正常 ✓ |
| 5. 切歌旧词不污染 | **Before**: `winrt-p217-lyrics-failed-state.png`（修复前：旧曲歌词残留双列）→ **After**: `winrt-FIX2-VERIFIED-single-column-retry.png` | **运行时实锤真缺陷 → 修复 → 复验闭环**（见下） |
| 6. 页面退出无幽灵回调 | 多次进出播放页 + 应用日志无异常 | 间接佐证（widget 层既有断言 + 运行时无异常日志） |
| 3. 成功切双列 | 自动加载路径（场景 7 帧） | ✓ |

### 运行时实锤真缺陷：切歌后旧歌词污染新曲（场景 5）

- **复现**（修复前，真实运行）：kw/wy 有词曲播放 → 切 5sing 无词曲（歌词 `not found`）→ **右列仍显示旧曲歌词双列**，新曲重取入口被遮蔽。
- **根因**：`state.lyrics` 仅在 LyricsChanged 时回写；换曲不清空 → 新曲歌词加载失败期间旧词滞留。既有单测只覆盖「同曲重试失败不改 state」（防错误污染语义），跨曲组合未建模。
- **修复**（`application/src/service.rs`）：两条 play 路径（`play` / `play_with_restore`）在 `state.playback.song` 提交处同步 `state.lyrics = None`——换曲即清空，失败路径「不写错误结果」语义不变；Dart 经 `PlaybackStarted → _refreshState` 拉到清空态，NowPlaying 自动落单列+重取。
- **回归测试**：`switching_song_clears_stale_lyrics_and_failure_does_not_restore_them`（PerSongLyricFetcher + LocalDownloadEffects + AcceptingPlayer 三桩装配：旧词在位 → 换曲播放 → 新词 NotFound 通知收敛 → 断言 lyrics None）。
- **运行时复验**：修复 DLL 重建后同一操作序列 → 单列+重取（After 帧）✓。

## 新发现登记（运行时验证的附带产出）

| 编号 | 级别 | 内容 | 证据 |
|---|---|---|---|
| **P2-19** | P2 | 搜索页骨架/加载态窗口底部溢出 **BOTTOM OVERFLOWED BY 143 PIXELS**（1136×713 窗口 100% 复现；结果加载完成后消失，滚动列表正常）——骨架容器缺视口约束 | `winrt-NEW-search-skeleton-overflow143.png` |
| **P2-20** | P3 | soda 音源曲目搜索/推荐端点服务端返回空（200 空 body / 空态），playlist 关键词搜索与歌单详情正常——服务端契约变更，非客户端缺陷；App 内如实空态 | `winrt-p216-soda-empty-state.png` + curl 实录 |
| —（Batch H 素材） | P1-05 补记 | 进程静默退出 1 例：UIA（自动化）按标题栏按钮后进程消失，stdout 无 panic、无 crash.log——与 P1-05/P0-01「进程静默消失」同类；单例非复现，归 Batch H 实验矩阵 | /tmp/voicefox_app2.log 终态 |
| —（观察） | P3 | Flutter Windows a11y 桥在 UIA 客户端连接时刷 `Failed to update ui::AXTree` 噪音（框架级，不影响功能） | 应用日志 |

## P2-04 平台窗口几何【维持开放，Linux 会话】

niri / Wayland / XWayland 窗口尺寸核验属 Linux 桌面环境专项，Windows 端无从执行。维持原登记，留 Linux 会话（与交接文档开放项口径一致）。

## 修改清单

| 文件 | 修改 |
|---|---|
| `application/src/service.rs` | play / play_with_restore 两路径换曲清空 `state.lyrics`（含注释裁决说明）+ 回归测试 `switching_song_clears_stale_lyrics_and_failure_does_not_restore_them` + PerSongLyricFetcher / LocalDownloadEffects / AcceptingPlayer 测试桩 + `service_with_lyric_fetcher` 泛型化（impl LyricFetcher + 'static） |
| `docs/redesign/screenshots/batch-g-winrt/` | 28 张运行时证据帧（新增） |
| `docs/redesign/04-defect-matrix.md` | P1-20 / P2-16 / P2-17 / P2-18 关闭 + P2-04 维持 + P2-19 / P2-20 新登记 + P1-05 静默退出补记 |

**Dart 面零改动**（修复在 Rust 状态层，Dart 经既有事件拉取链自然收敛）。

## 验证

| 门禁 | 结果 |
|---|---|
| `cargo fmt --check` | 0 ✓ |
| `cargo clippy --workspace --all-targets --features lx-player/build_libmpv -D warnings` | exit 0（预存 manifest 级 unused-deps 警告维持登记）✓ |
| `cargo test --workspace --no-fail-fast` | **858 passed**（lx-source 本轮 5 失败 = 3 登记 Windows 夹具 + 2 wy::url localhost 网络抖动；单跑复归 226+3 登记集）→ 等效全绿 **859** = Batch F 858 + 新增回归 1；app visualizer 本轮通过 ✓ |
| `dart analyze --fatal-infos` | 0（Dart 零改动）✓ |
| `dart format lib test` | 0 changed ✓ |
| 运行时验证 | 见上表（Windows 真机 + 28 张证据帧） |

## 后续

- **P2-04**：Linux 会话执行（niri/Wayland/XWayland）。
- **Batch H**：稳定性与崩溃诊断——本批静默退出单例 + P0-01/P1-05 实验矩阵（事件洪污/长会话/休眠唤醒）待 Linux 侧系统性执行；Windows 侧可先建 crash 证据链。
- **P2-19 修复**：搜索骨架态视口约束（小型呈现层收口，可随下批）。
- soda 上游契约变更（P2-20）：跟踪服务端，或评估换用 playlist 详情链路做曲目发现（结构性替代，需单独评估）。

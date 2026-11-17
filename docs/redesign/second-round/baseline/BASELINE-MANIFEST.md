# 第二轮基线截图证据集（BASELINE-MANIFEST）

> 状态：生效中 · 日期 2026-11-14 · 适用 HEAD `eb1afc3`（feat/ui-redesign，工作区干净）

## 结论（为什么是清单而不是新截图集）

第二轮 Phase 0 尚未修改任何生产代码，工作树与 HEAD `eb1afc3` 完全一致；因此**仓库内现存全部 239 张截图天然就是"改动前基线"**，且已随各自提交进入 git 历史永久可溯。为避免将大量 PNG 复制一份造成仓库体积翻倍，本目录以清单方式登记基线证据，不改动原文件。

- 最新一轮全量矩阵证据：`docs/redesign/screenshots/final/`（19 张，2026-11-13 清尾 L2，commit `5ec550a`，UI-only harness + VOICEFOX_START_SIZE 真实视口）
- 历史阶段证据：`docs/redesign/screenshots/{baseline,phase-1-mobile,phase-2-library,...}/` 与 `gallery.html`（203 张画廊索引）

## 计划书 §2.4 最低基线集 → 现存文件映射

| 平台 | 页面 | 现存证据（docs/redesign/screenshots/ 下） |
|---|---|---|
| 桌面 | Home | final/desktop-home-1024x640-uionly.png |
| 桌面 | Discover | final/desktop-discover-1280x800-uionly.png |
| 桌面 | Search | desktop-search-*.png（10 张，多视口） |
| 桌面 | Library | final/desktop-library-1440x900-uionly.png |
| 桌面 | Downloads | final/desktop-downloads-560x844-{active,completed,failed}.png |
| 桌面 | Settings | final/desktop-settings-1920x1080-uionly.png |
| 桌面 | Now Playing | desktop-nowplaying-*.png（5 张） |
| 手机 | Home | phone-home-*.png（6 张） |
| 手机 | Discover | phone-discover-*.png（4 张） |
| 手机 | Search | phone-search-*.png（7 张） |
| 手机 | Library | phone-library-*.png（5 张） |
| 手机 | Downloads | tablet/phone downloads 见 phase 矩阵 |
| 手机 | Now Playing | mobile 播放页见 phase-3/6 矩阵 |
| 平板 | Home / Library / Discover / Now Playing | tablet-{home,library,discover,nowplaying}-*.png（6/6/6/5 张） |

## 已知偏差（坏消息单列）

1. **eb1afc3 WIP 改动页的截图是旧代码状态**：`discover_page.dart`、`now_playing_page.dart`、`lyrics_panel.dart` 在 `eb1afc3` 有在途改动（P1-20/P2-16/P2-17/P2-18），现存截图摄于 `5ec550a`。这三个页面的基线将在 WIP 批次运行时验证轮用当前代码重截（该验证本来就是 P2-16/17/18 关闭的必要证据），届时补入本目录。
2. **UI-only 局限**：final/ 矩阵为 harness 截图，只能证明壳层与视觉骨架；真实音源/播放/下载链路的运行时证据按计划书 §2.4 不得由其替代，未验证项在审计报告如实标注。
3. 命名沿用历史格式（`{platform}-{page}-{size}-{state}.png`），未按计划书 `{platform}-{page}-{width}x{height}-{theme}-{state}-baseline.png` 重命名。理由：重命名会让 8 份阶段报告与 gallery.html 的既有引用全部失效，收益为零。

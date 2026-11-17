# FlutterFox 最终验收报告(FINAL_ACCEPTANCE_REPORT)

> 执行轮次:2026-11-18,执行合同 `C:/Users/emo/Desktop/FLUTTERFOX_AUTONOMOUS_COMPLETION_PLAN.md`(§15 直接执行模式)。
> 执行者:ZCode 自主执行会话。分支:`feat/ui-redesign`。交付 HEAD:`d8a6c44`。
> **总判定:功能批次已完成;稳定性门禁部分满足——P0-W1(新发现)已登记并规避、P0-01 维持开放(未复现不构成关闭),如下如实分账。**

## 1. 交付总览

| 阶段 | 结果 | 摘要 |
| --- | --- | --- |
| F0 基线冻结 | ✅ | 仓库定位(旧检出核实只读,新检出克隆)、分支/HEAD/CI 基线、所有权表、3 份基线文档 |
| F1 CI/构建链路修复 | ✅ **CI 全绿** | 4 层洋葱根因逐层实证修复:① media-session cfg(linux) anyhow 缺声明;② media_bridge Linux 段缺 ApplicationService 导入;③ voicefox-app shim Linux 形态 4 错(E0432 级联);④ FRB codegen 缺 cargo-expand(补 1.0.127 + RUSTC_BOOTSTRAP=1)。run 44138779964(147f15d)与 44147067501(74abcb7)**全部 job SUCCESS** |
| F2 功能盘点 | ✅ | FEATURE_ACCEPTANCE_MATRIX.md(10 域 × 四状态,继承证据如实标注) |
| F3 核心功能 | ✅ | **P2-19 关闭**(tracksFitted + 5 回归用例 + 1024×640 真机实证);**GUI Windows SMTC 接入**(media-session 泛化跨平台,TUI 后端原样移植) |
| F4 UI/UX 五尺寸 | ✅ | 1024×640 / 1136×713 / 1280×720 / 1440×900 / 1904×942(1920×1080 受物理屏上限近似)全部零溢出,断点/限宽/展开侧栏正确(证据 batch-h1/F4-*.png) |
| F5 稳定性 | ◐ | P0-01:事件泵热路径代码审计完成(轻量 progress/单飞/失联可观测均已在位);RT-20 长会话以**被动 30 分钟观察**执行(交互式 soak 因 CUA 会话终止受阻,如实登记);P1-05/P2-08 证据链:crash.log 钩子在位,新增 P0-W1 白屏素材同族登记 |
| F6 播放后端边界 | ✅ | 耦合审计:FlutterFox 自有层(pages/shell/player/design_system)零 mpv 泄漏(桌面链走 FFI 命令通道);myune vendored 层 mpv 接缝集中在 myune_seam 适配器(移动宿主播放,按 §9.5 不重写);本轮新增的 media-session/SMTC 沿"后端 adapter + 共享数据层"边界实现 |
| F7 Windows 实机 | ◐ | RT-01/03/05/06/19 PASS + F4 五尺寸 + RT-15 真机实证;RT-12 部分完成;RT-14/20 交互式部分 BLOCKED(见 §4) |
| F8 文档与交付 | ✅ | 本报告 + 状态/日志/限制文档 + 全部批次报告;推送到 origin/feat/ui-redesign,CI 全绿 |

## 2. 代码交付(commit 链,全部推送至 feat/ui-redesign)

| SHA | 内容 |
| --- | --- |
| `829c3d1` | CI:media-session anyhow 声明 + codegen cargo-expand/RUSTC_BOOTSTRAP + 删重复步骤 + F0 文档 |
| `1429c74` | media_bridge ApplicationService cfg(linux) 导入(E0425 ×5) |
| `8f59048` | **P2-19**:VxLoadingSkeleton.tracksFitted + search_page 接入 + 5 回归用例 |
| `c31c275` | **GUI SMTC 接入**:media-session/smtc.rs 移植 + media_bridge 跨平台泛化 + 开关 + ffi 接线 |
| `147f15d` | TUI Linux shim 修复(translate_event/channel 平台门控 + mpris 直连 + 删无用 shim) |
| `74abcb7` | **P0-W1 自愈规避**(冷启动白屏,详见 §3)+ 实机证据首批 |
| `d8a6c44` | 实机测试日志 + 04 矩阵 2026-11-18 更新行 |

## 3. 新登记缺陷:P0-W1(Windows 冷启动首帧白屏)——已规避,根因开放

- **现象**:GUI 冷启动(默认 1150×720)窗口持续白屏,无 Flutter 内容/无 a11y 元素;Dart/Rust 后台链路全部正常(引导日志/事件流/取色)。任何真实 WM_SIZE(实测 Win+Left 贴靠)后立即完整呈现。
- **归属取证**:bisect @ 846bbfe(Batch G 已知好)同白屏 → 非本轮回归;关 integration.smtc 仍白屏 → 非 SMTC 接线;pubspec 零漂移;记事本/ZCode 渲染正常 → 会话/DWM 正常。
- **定性**:引擎/环境层首 GL 帧呈现失败(P2-08「GL frame timeout」同族;QXL/ANGLE 环境自 Batch G 后漂移触发;本会话 100% 复现,昨日 Batch G 正常 → 环境敏感)。
- **规避(已入库)**:main.dart 桌面分支 show() 后 1px 尺寸往返强制表面重建(Windows only);实测冷启动零人工操作完整渲染。
- **残余风险**:engine 层根因未定位;规避依赖 WM_SIZE 触发,若环境漂移到「任何 resize 都不呈现」的程度则规避失效(未观察到此形态);非 Windows 平台零变化。

## 4. RT 用例实机验收账目(证据:docs/flutterfox/evidence/batch-h1/ + WINDOWS_RUNTIME_TEST_LOG.md)

| ID | 结果 | 要点 |
| --- | --- | --- |
| RT-01 冷启动 | PASS(带 P0-W1 规避) | 自愈后零人工操作渲染;引导链日志完整 |
| RT-02 页面导航 | PASS(部分) | 侧栏→曲库(入口卡计数/chips/空态指引/PlayerBar 常驻);发现/下载/设置页因 CUA 会话终止未走查(BLOCKED 部分) |
| RT-03 搜索 | PASS | Header 输入 → SR-14 双向同步 → 192/215 结果多源聚合(千千/JOOX/网易云/咪咕/酷狗/QQ/酷我),封面渐进解析 |
| RT-04 全部音源往返 | 继承证据(P1-20,Batch G) | 本轮未重复执行 |
| RT-05 播放 | PASS | 行内 ▶ → 诚实解析期(无假 Playing)→ 换源 fallback(wy)→ 00:27/02:06 真实走带(4Hz 泵日志) |
| RT-06 播放控制 | PASS | 暂停 00:48 冻结/继续/Seek 01:26(~65% 精确)/下一首 |
| RT-07 队列 | 未执行(BLOCKED) | CUA 会话终止 |
| RT-08/09 歌词封面 | 继承证据(Batch G 运行时闭环 + 本轮换曲观察) | 歌词区随播放切换正常 |
| RT-10 收藏/最近播放 | PARTIAL | 最近播放列表真实数据渲染多帧;收藏操作未执行 |
| RT-11 本地导入 | PARTIAL | 合成媒体就绪(few 4 WAV + CUE);UI 导入流未执行 |
| RT-12 大曲库 | PARTIAL | 10k 注入经历配置损坏→隔离→重建完整闭环(§6.7 韧性实证);正确注入后扫描会话进程稳定;**UI 计数/滚动验证 BLOCKED**(CUA 终止) |
| RT-13 下载 | 继承证据(Phase 5/P3-09) | 本轮未重复 |
| RT-14 设置/主题 | BLOCKED | CUA 会话终止 |
| RT-15 窄窗口 1136×713 | **PASS** | P2-19 修复实证:1024×640 骨架零溢出(更紧窗口)+ 1136×713 结果页正常 |
| RT-16 最小窗口 1024×640 | PASS | F4-1024x640-home.png |
| RT-17 大窗口 | PASS(近似) | 物理屏 1904×942 上限,内容限宽 ~1320 居中(SR-10) |
| RT-18 键盘操作 | PARTIAL | Header 输入/回车可靠;F1 帮助浮层在本会话输入退化期未触发(a11y/输入管线环境性退化) |
| RT-19 异常恢复 | **PASS** | JOOX 源 URL 解析失败 →「获取播放地址失败,换源后仍不可用」诚实呈现,无假 Playing/无崩溃/事件流存活 |
| RT-20 长会话 | ◐ | 30 分钟被动观察(进程/内存/日志)进行中;交互式混合会话 BLOCKED(CUA 终止) |

## 5. 门禁实录

| 门禁 | 结果 |
| --- | --- |
| GitHub Actions(147f15d / 74abcb7) | **全部 job SUCCESS**(Linux/macOS×2/Windows 构建、Android FFI、Lint、Flutter analyze/test、FRB codegen) |
| cargo fmt / clippy(CI 同款,Windows+build_libmpv) | exit 0(含新 SMTC/bridge 面) |
| cargo test 定向(media-session + application) | 103 passed 0 failed |
| flutter analyze --fatal-infos / dart format | 0 / 0 changed |
| flutter test 定向(新测试 + 骨架消费面 7 文件) | 5/5 + 75/75 |
| flutter build windows --debug | exit 0 ×3 次(含规避验证轮) |
| cargo test --workspace 全量 | 未复跑(Rust 变更面已定向覆盖;Linux 侧由 CI 实跑验证——Build Linux job SUCCESS 即其证据) |

## 6. 阻塞与责任边界(诚实声明)

1. **CUA 会话被终止(执行者操作失误)**:排查白屏期间执行了 `stop()`(本意重置,实为 kill 开关),GUI 交互验证中途不可用。受影响:RT-02 余项/RT-07/RT-14/RT-20 交互式部分。**未按 skill 红线切换其他自动化技术**;恢复需新 CUA 会话。
2. **engine a11y 桥/输入管线本会话漂移**:AXTree error 刷屏、UIA 树间歇可用(8↔38 元素)、event 点击间歇失效——与 P0-W1 同族环境漂移;已用 event 策略 + 日志双判定缓解,并在日志中如实登记。
3. **Linux 专属验证**(P2-04/MPRIS 运行时/lx-source 3 夹具):维持合同口径,Linux CI 编译/测试为证,运行时未验证。
4. **Android(P1-06)**:维持用户搁置口径,零操作。
5. **P0-01**:代码审计确认已知嫌疑路径均已系统性缓解(轻量 progress/单飞/守卫/可观测失联);本会话未复现卡死;按合同「未复现不构成关闭」维持开放。
6. **P2-20/P1-05**:上游契约/静默退出根因,维持登记;SMTC 运行时媒体键验证留待下一会话(CUA 恢复后)。

## 7. 合同 §14 完成定义对照

- 功能/UI/质量项:见 §4 账目——主流程(启动/导航/搜索/播放/控制/异常恢复)有真机 PASS;部分交互项 BLOCKED 并如实标注,无任何未验证项冒充 PASS。
- 稳定性:P0-W1 已登记+规避(根因开放);P0-01 开放(审计+被动观察);**按合同 §14 末款,本轮状态如实标记为「功能批次已完成,稳定性门禁仍未完全满足」**。
- CI:目标分支最新修复 SHA 全 job SUCCESS ✅;只推送 feat/ui-redesign ✅;未合并 main/未动他人工作 ✅。

## 8. 外观修复追加批(2026-11-18,验收截图排查驱动)

七页屏幕真值截图(evidence/appearance/CUR-*.png,1280×720)排查出两处外观缺陷并修复:

1. **首页 Hero「继续收听」卡右侧 ~450px 空梯度**(最显眼半成品观感):VxHero 新增可选
   `backgroundArt` 层——同一封面 URL 的更大尺寸实例(640)经 ImageFiltered blur(σ30) 铺满
   整卡,渐变/高光层降透明度(0.74)叠加,文案可读性由深色渐变保证;解析失败回落
   VxCoverFallback 渐变,模糊后视觉等效纯渐变,无新增失败形态。背景 art 走同一解析管线
   (P1-15 UA/Referer 头族),未引入裸 Image.network。
2. **最近播放横滑书架右缘生硬裁切**:RecentShelf 加 ShaderMask(dstIn) 尾部 40px 线性渐隐,
   给出「可继续滑动」暗示;滚动到底尾卡右缘轻微淡出为通用书架形态既有代价。

验证:home_appearance_fix_test.dart 3/3(背景层存在+降透明度/引导形态零变化/遮罩恰一且可视
卡片渲染)+ 既有 home_page_test 9/9 回归 + analyze 0;真机 before/after:
appearance/CUR-home.png(修复前)vs FIX-home-1280x720.png(修复后,空洞消除+渐隐生效)。
其余五页(发现/搜索/曲库/下载/设置/帮助)截图巡检无溢出/遮挡/裁切缺陷,观感良好。

## 9. 移交清单(下一会话)

1. 新 CUA 会话恢复后补齐:RT-02 余项/RT-07/RT-12 UI 计数/RT-14 主题/RT-20 交互式 soak/SMTC 媒体键注入(RT-05 已证明命令链通,媒体键走 media-session→bridge→dispatch 全链,预期可用)。
2. P0-W1 engine 层根因调查(素材:本报告 §3 取证链 + crash.log + Event Viewer;重启 VM 后观察是否自愈可区分「VM 会话态」vs「持久环境漂移」)。
3. media-session 的 macOS Now Playing 后端接入(无可验证平台,当前未实现)。
4. 恢复测试 profile:config.toml 已由备份 `$TEMP/config.toml.bak-h1` 可还原;library10k 注入路径在 §local_music.paths(验证后移除)。

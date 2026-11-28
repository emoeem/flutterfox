# Windows 实机运行测试日志(WINDOWS_RUNTIME_TEST_LOG)

> 执行者:ZCode 自主执行会话(合同 §10)。构建:debug @ `74abcb7`(含 P2-19 修复、SMTC 接入、白屏自愈)。
> 证据目录:`docs/flutterfox/evidence/batch-h1/`。交互方式:CUA(event 策略强制原始输入——
> 本会话 engine a11y 桥损坏(AXTree error 刷屏,与白屏同族的环境漂移),a11y 策略点击静默失效)。
> 测试 profile:本机 %APPDATA%/voicefox(Batch G 会话的测试 profile,含真实音源网络;破坏性操作前备份)。

## 环境与启动链(2026-11-18)

| 项 | 值 |
| --- | --- |
| 构建 | flutter build windows --debug exit 0(145.9s)+ cargo build voicefox-ffi exit 0(57.5s)+ DLL 手工装配(libmpv-2.dll/voicefox_ffi.dll 入 exe 目录,交接 §二.7) |
| 合成媒体 | %TEMP%/flutterfox-test-media/:few 4 WAV + CUE + library10k 10000 文件(175MB,54s 生成) |
| 显示环境 | QXL 1904×942,DPI 96(100%),单屏 |

## 已执行用例(随批更新)

| ID | 结果 | 证据/要点 |
| --- | --- | --- |
| RT-01 冷启动 | **PASS(带 P0-W1 规避)** | 初始白屏缺陷实锤(846bbfe 同现,见 P0-W1 登记)→ main.dart show() 后 1px 尺寸往返自愈 → 零人工操作完整渲染;证据 RT01-coldstart-selfheal-no-manual-resize.png;引导日志链完整(Impeller/FFI 装载/pump/动态取色) |
| RT-01-ALT | 白屏对照 | bisect worktree @ 846bbfe 同白屏;关闭 smtc 仍白屏;pubspec 零漂移;记事本/ZCode 渲染正常 —— P0-W1 定性证据链 |
| F4@1024×640 首页 | PASS | F4-1024x640-home.png:Rail/Header/Hero/最近播放/PlayerBar 全部正常,无溢出 |
| RT-03 搜索@1024×640 | PASS | Header 输入「晴天」→ SR-14 双向同步(header 与页面框一致)→ 骨架态(无溢出!)→ 192 结果(千千音乐/JOOX/网易云/咪咕聚合,封面渐进解析,时长/行号/来源徽章正确);证据 RT03-search-results-1024x633.png |
| RT-15 P2-19 骨架溢出@1024×640 | **PASS(真机实证)** | 搜索加载骨架在 633px 高窗口内被正确约束,零溢出(历史缺陷 100% 复现场景的更紧窗口);证据 F4-1024x640-search-empty.png(骨架形态) |
| RT-05 播放 | PASS | 行内 ▶(event 策略)→ 解析期 PlayerBar 诚实「未在播放」(无假 Playing)→ 换源 fallback(wy)成功 → 晴天/a兴·wy 00:27/02:06 走带;证据 RT05-playback-state-check.png;日志 17/5s last=progress(4Hz 泵) |
| RT-06 暂停/继续/Seek | PASS | 暂停:00:48 冻结+图标翻转(RT06-paused.png);继续+Seek:01:26/02:06(~65% 精确落点,RT06-seeked.png) |
| RT-06 下一首 | PASS(含 RT-19) | ⏭ → 下一首(JOOX 源)URL 解析失败 → 诚实错误「获取播放地址失败,换源后仍不可用: parse error」→ 无假 Playing、无崩溃、事件流存活(14/5s)——RT-19 异常恢复同场实证 |
| RT-02 导航 | PASS | 侧栏 event 点击 → 曲库页:三入口卡计数(最近播放 9/本地 0/喜欢 0)+ 类型 chips + 来源 chips + 空态「还没有收藏」带下一步指引;PlayerBar 常驻;证据 RT02-library-1024x633.png |
| a11y 树 | **BLOCKED(环境)** | engine「Failed to update ui::AXTree」错误刷屏(CUA 观察触发),UIA 仅见 8 个 chrome 元素,Batch G 曾正常(38 元素)——与白屏同族的环境漂移;交互全部走 event 策略坐标 + 键盘替代 |

## 待执行(后续批次)

RT-02 余下目的地(发现/下载/设置)、RT-04 全部音源往返、RT-07 队列面板、RT-08/09 歌词封面、
RT-10 收藏、RT-11 本地导入(few 目录)、RT-12 10k 曲库(config 注入 + 重启,Phase 5 口径)、
RT-13 下载、RT-14 设置/主题、F4 其余四尺寸(1136×713/1280×720/1440×900/1920×1080)、
RT-17 大屏、RT-18 键盘、RT-20 30 分钟长会话。

## 交互注意事项(本会话实测)

1. CUA 点击必须 `strategy: "event"`(a11y 桥损坏时 auto 策略静默失效;hover/tooltip 仍可见)。
2. 合成双击不可靠;行播放走 hover 行内 ▶ 按钮。
3. Header 搜索框点击/输入/回车全可靠(SR-14 链路)。
4. 每次交互后以日志(过滤 AXTree 行)+ 截图双重判定,不以单次截图断言。

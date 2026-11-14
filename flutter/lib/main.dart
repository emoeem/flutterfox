// ignore_for_file: deprecated_member_use // window_manager 0.6 把 0.5.x API 移入 legacy.dart 桥接层(changelog 指定迁移路径), 后续大版本切 native API
/// voicefox Flutter 前端入口。
///
/// 桌面：Rust 侧 newDesktop()（mpv 播放）引导；移动端（Phase 4）由宿主注入
/// ApplicationService 后走 AppModel.attach。
/// UI 壳：Phase 2 起为 `src/shell/VoicefoxShell`（Header+Sidebar+内容区+
/// ContextPanel+PlayerBar 唯一外壳）。Rust 引导完成后 `MyuneHost` 挂起
/// app 级 Provider 图（存活全程），`MyuneProjection` 把 AppModel 快照常驻
/// 投影进 vendored 组件。旧壳 myune_shell/app_shell.dart 已退役。
library;

import 'dart:async';
import 'dart:io' show File, FileMode, Platform;

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kDebugMode, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/legacy.dart';

import 'src/app_model.dart';
import 'src/bridge/api.dart' as bridge;
import 'src/bridge/host_player_bridge.dart';
import 'src/playback/mobile_audio_player.dart';
import 'src/playback/voicefox_audio_handler.dart';
import 'src/myune/page/playlist/playlist_content_notifier.dart';
import 'src/myune/page/setting/settings_provider.dart';
import 'src/myune/services/notification_service.dart';
import 'src/myune/theme/theme_provider.dart';
import 'src/myune_seam/app_model_audio_backend.dart'
    show attachVoicefoxAudioBackend;
import 'src/myune_shell/projection.dart' show MyuneHost;
import 'src/shell/app_shell.dart' show ShellDetailSeed, VoicefoxShell;
import 'src/shell/app_sidebar.dart' show ShellDestination;
import 'src/shell/mobile_shell.dart' show TouchShell;
import 'src/shell/responsive_shell.dart' show isTouchPlatform;
import 'src/theme/app_theme.dart';

/// 桌面窗口平台（非触屏）：window_manager / 窗控 / DragToMoveArea 只在
/// 这些平台进树。判定用 dart:io Platform（isTouchPlatform），禁止
/// defaultTargetPlatform（FLUTTER_TEST 强制 android，会翻掉桌面基线）。
bool get _isDesktopWindowPlatform => !isTouchPlatform;

/// 无 Rust UI-only 引导（Phase 7）：`--dart-define=VOICEFOX_UI_ONLY=1` 且
/// debug 构建（kDebugMode）才生效。bool.fromEnvironment 是编译期常量，
/// release 下 kDebugMode 恒 false，整个分支被树摇剔除，不会静默吞掉
/// 真实引导。用途：Android 模拟器（工程暂无 jniLibs；进程由 Zygote 派生
/// 无法注入环境变量，故不能用 Platform.environment 门控）与桌面同一
/// 用法的 UI 预览：`flutter run --dart-define=VOICEFOX_UI_ONLY=1`。
/// 该分支只渲染壳与各页真实空/错误态（无 Rust 时 dispatch 安全返回
/// 错误串，app_model.dart `_sendCommand`），不引入任何原生媒体能力
/// （计划书 §11.4 边界）。
const bool kUiOnly = bool.fromEnvironment('VOICEFOX_UI_ONLY') && kDebugMode;

/// 验收截图起始页（与 VOICEFOX_START_SIZE 同一约定）：VOICEFOX_START_PAGE=
/// home|discover|search|library|downloads|settings|help，缺省 home，
/// 运行时行为一致。
ShellDestination? _startDestinationFromEnv() {
  final raw = Platform.environment['VOICEFOX_START_PAGE']?.trim();
  if (raw == null || raw.isEmpty) return null;
  return switch (raw) {
    'home' => ShellDestination.home,
    'discover' => ShellDestination.discover,
    'search' => ShellDestination.search,
    'library' => ShellDestination.library,
    'downloads' => ShellDestination.downloads,
    'settings' => ShellDestination.settings,
    'help' => ShellDestination.help,
    _ => null,
  };
}

/// 我的音乐初始二级类别：VOICEFOX_START_TAB=songs|albums|artists|playlists。
String? _startLibraryTabFromEnv() {
  final raw = Platform.environment['VOICEFOX_START_TAB']?.trim();
  return (raw == null || raw.isEmpty) ? null : raw;
}

/// 设置页初始分组：VOICEFOX_START_SECTION=appearance 等（验收截图用）。
String? _startSettingsSectionFromEnv() {
  final raw = Platform.environment['VOICEFOX_START_SECTION']?.trim();
  return (raw == null || raw.isEmpty) ? null : raw;
}

/// 详情页下钻种子：VOICEFOX_START_DETAIL=album|artist|playlist|local，
/// 配 VOICEFOX_START_KEYWORD（album/artist 的搜索词）与
/// VOICEFOX_START_SOURCE（playlist 的音源，默认 kw）。
ShellDetailSeed? _startDetailSeedFromEnv() {
  final raw = Platform.environment['VOICEFOX_START_DETAIL']?.trim();
  if (raw == null || raw.isEmpty) return null;
  final keyword = Platform.environment['VOICEFOX_START_KEYWORD']?.trim() ?? '';
  final source = Platform.environment['VOICEFOX_START_SOURCE']?.trim() ?? 'kw';
  return ShellDetailSeed(kind: raw, keyword: keyword, source: source);
}

/// 验收截图搜索种子：VOICEFOX_START_SEARCH=关键词，配 search 起始页使用。
String _startSearchSeedFromEnv() =>
    Platform.environment['VOICEFOX_START_SEARCH']?.trim() ?? '';

/// 初始窗口尺寸：VOICEFOX_START_SIZE=1440x900（WxH）。缺省或格式非法
/// 返回 null，由调用方决定各自缺省尺寸（真实桌面分支 1150x720；uiOnly
/// 分支不改窗口大小）。
Size? _startSizeFromEnv() {
  final raw = Platform.environment['VOICEFOX_START_SIZE']?.trim();
  if (raw == null || raw.isEmpty) return null;
  final match = RegExp(r'^(\d+)x(\d+)$').firstMatch(raw);
  if (match == null) return null;
  return Size(double.parse(match.group(1)!), double.parse(match.group(2)!));
}

/// 可选起始位置：VOICEFOX_START_POS=x,y（X11 后端 + 验收截图用；Wayland
/// 合成器可能忽略，运行时行为不受影响）。缺省或格式非法返回 null。
Offset? _startPosFromEnv() {
  final raw = Platform.environment['VOICEFOX_START_POS']?.trim();
  if (raw == null || raw.isEmpty) return null;
  final match = RegExp(r'^(-?\d+),(-?\d+)$').firstMatch(raw);
  if (match == null) return null;
  return Offset(double.parse(match.group(1)!), double.parse(match.group(2)!));
}

/// 崩溃取证落盘路径（P1-05/P2-08）：`VOICEFOX_CRASH_LOG` 覆盖，缺省
/// `<config>/crash.log`（与 Rust 侧 panic hook、TUI voicefox.log 同目录）。
/// 非 dart:io 平台（web 测试环境）返回 null。
String? crashLogFilePath() {
  final override = Platform.environment['VOICEFOX_CRASH_LOG']?.trim();
  if (override != null && override.isNotEmpty) return override;
  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) return null;
  final xdgConfig = Platform.environment['XDG_CONFIG_HOME']?.trim();
  final configDir = (xdgConfig != null && xdgConfig.isNotEmpty)
      ? xdgConfig
      : '$home/.config';
  return '$configDir/voicefox/crash.log';
}

/// 追加一条崩溃取证记录（unix 秒时间戳，与 ffi crash_log 同格式）。写盘
/// 失败静默降级——取证不应反噬正常运行。
void appendCrashLogEntry(String path, String kind, String body) {
  try {
    final file = File(path);
    final parent = file.parent;
    if (!parent.existsSync()) parent.createSync(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    file.writeAsStringSync('[$stamp] $kind: $body\n', mode: FileMode.append);
  } catch (_) {
    // 取证失败不上抛。
  }
}

/// 安装 Flutter/未处理异常崩溃取证（P1-05：静默退出无崩溃日志）。main()
/// 启动时调用；测试可传临时路径验证。
void installCrashLogHandlers({String? path}) {
  final target = path ?? crashLogFilePath();
  if (target == null) return;
  FlutterError.onError = (details) {
    appendCrashLogEntry(target, 'flutter-error', details.exceptionAsString());
    // 保留既有 stderr/红屏行为。
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    appendCrashLogEntry(target, 'unhandled', '$error\n$stack');
    return true;
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // P1-05/P2-08：panic（Rust 侧 ffi/crash_log.rs）与 Flutter/未处理异常
  // （本函数）统一落盘 crash.log，消除静默退出的取证盲区。
  installCrashLogHandlers();
  // Phase 7 无 Rust UI-only 分支：渲染壳 + 各页空/错误态，见 [kUiOnly]。
  // window_manager 0.5.2 仅声明 linux/macos/windows 平台实现，触屏平台
  // 必须跳过（Android 引导屏不再抛 MissingPluginException）；桌面预览
  // 保留窗口初始化（窗控/拖动区可用）。
  if (kUiOnly) {
    if (_isDesktopWindowPlatform) {
      await windowManager.ensureInitialized();
      // P3-10：uiOnly 验收分支同样应用 VOICEFOX_START_SIZE/POS，final
      // 截图矩阵视口标注与实际渲染一致（P1-19 根因收口）。minimumSize
      // 有意不设：uiOnly 现无 560 钳制，360-560 宽可达，对截图管线有利
      // （04 矩阵 P3-10 裁决点）；标题栏形态不变。两个 env 均缺省时不走
      // waitUntilReadyToShow，既有启动路径零变化。
      final startSize = _startSizeFromEnv();
      final startPos = _startPosFromEnv();
      if (startSize != null || startPos != null) {
        unawaited(
          windowManager.waitUntilReadyToShow(
            WindowOptions(size: startSize),
            () async {
              if (startPos != null) await windowManager.setPosition(startPos);
              await windowManager.show();
            },
          ),
        );
      }
    }
    runApp(
      VoicefoxApp(
        model: AppModel(),
        uiOnly: true,
        initialDestination: _startDestinationFromEnv(),
        searchSeed: _startSearchSeedFromEnv(),
        libraryTab: _startLibraryTabFromEnv(),
        settingsSection: _startSettingsSectionFromEnv(),
      ),
    );
    return;
  }
  // Phase 8 批次二：触屏平台真实引导链（无音频）。数据目录覆盖 →
  // newHost（转发型后端，无 mpv）→ AppModel.attach → 宿主指令流消费。
  // 桌面路径不进此分支（零变化）；真实音频输出由批次三 just_audio 承接，
  // 当前指令仅记录（HostPlayerBridge，不伪造播放状态）。
  if (isTouchPlatform) {
    final model = AppModel();
    final app = VoicefoxApp(
      model: model,
      initialDestination: _startDestinationFromEnv(),
      searchSeed: _startSearchSeedFromEnv(),
      libraryTab: _startLibraryTabFromEnv(),
      detailSeed: _startDetailSeedFromEnv(),
      settingsSection: _startSettingsSectionFromEnv(),
    );
    unawaited(_bootstrapTouch(model));
    runApp(app);
    return;
  }
  // 自绘标题栏（AppHeader）依赖隐藏系统标题栏；Android 进程无该插件实现。
  if (_isDesktopWindowPlatform) await windowManager.ensureInitialized();
  // 初始窗口尺寸/位置与隐藏标题栏：仅桌面窗口平台（触屏无 window_manager
  // 插件实现，跳过整段；VOICEFOX_START_* 桌面验收钩子语义不变）。
  if (_isDesktopWindowPlatform) {
    // 初始窗口尺寸：默认 1150x720；VOICEFOX_START_SIZE=1440x900 可覆盖
    // （用于断点验收截图，运行时行为与默认完全一致；解析见
    // _startSizeFromEnv/_startPosFromEnv，uiOnly 分支复用同一钩子）。
    final startSize = _startSizeFromEnv() ?? const Size(1150, 720);
    final startPos = _startPosFromEnv();
    final windowOptions = WindowOptions(
      title: 'voicefox',
      size: startSize,
      minimumSize: const Size(560, 480),
      titleBarStyle: TitleBarStyle.hidden,
    );
    unawaited(
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        if (startPos != null) await windowManager.setPosition(startPos);
        await windowManager.show();
      }),
    );
  }

  final model = AppModel();
  // myune 壳的播放接缝：vendored UI 全部通过 shim 走 AppModel。
  attachVoicefoxAudioBackend(model);
  final app = VoicefoxApp(
    model: model,
    initialDestination: _startDestinationFromEnv(),
    searchSeed: _startSearchSeedFromEnv(),
    libraryTab: _startLibraryTabFromEnv(),
    detailSeed: _startDetailSeedFromEnv(),
    settingsSection: _startSettingsSectionFromEnv(),
  );
  // Rust 引导放后台：窗口先起，骨架屏等待；就绪后 VoicefoxApp 挂 Provider 图。
  unawaited(model.bootstrapDesktop().catchError(model.reportBootstrapError));
  runApp(app);
}

/// 触屏平台引导链（Phase 8 批次二骨架 + 批次三音频承接）。
///
/// 顺序：
/// 1. 数据目录覆盖（Android 上 dirs::data_dir() 为 None，宿主必须把
///    PathProvider 的 App 私有目录传给 setDataDir，迁移文档:360）；
/// 2. newHost：转发型播放后端 + 常规 runtime（无 mpv，config_base 就绪）；
/// 3. AppModel.attach：事件泵 + 初始快照 + libraryRefresh/configGet；
/// 4. audio_service 前台媒体服务（通知栏/锁屏/耳机键/音频焦点，
///    VoicefoxAudioHandler + JustAudioMobilePlayer）；
/// 5. HostPlayerBridge：消费 Rust→Dart 播放指令驱动 just_audio，
///    真实 state/position/duration 回流（hostPlayerReport）。
///
/// 任一步失败经 reportBootstrapError 呈现引导错误（不静默吞掉）。
Future<void> _bootstrapTouch(AppModel model) async {
  try {
    await model.ensureRustLib();
    final dir = await getApplicationSupportDirectory();
    bridge.setDataDir(path: dir.path);
    final controller = await bridge.newHost();
    await model.attach(controller);
    final player = JustAudioMobilePlayer();
    await configureAudioService(
      handler: VoicefoxAudioHandler(player: player, model: model),
    );
    final stream = await bridge.hostPlayerStream(controller: controller);
    HostPlayerBridge(
      source: RustHostCommandSource(stream),
      controller: controller,
      player: player,
    ).start();
  } on Object catch (error) {
    model.reportBootstrapError(error);
  }
}

class VoicefoxApp extends StatefulWidget {
  final AppModel model;

  /// 初始目的地（VOICEFOX_START_PAGE，验收截图用）；null 从首页开始。
  final ShellDestination? initialDestination;

  /// 搜索页种子关键词（VOICEFOX_START_SEARCH，验收截图用）。
  final String searchSeed;

  /// 我的音乐初始二级类别（VOICEFOX_START_TAB，验收截图用）。
  final String? libraryTab;

  /// 设置页初始分组（VOICEFOX_START_SECTION，验收截图用）。
  final String? settingsSection;

  /// 详情页下钻种子（VOICEFOX_START_DETAIL，验收截图用）。
  final ShellDetailSeed? detailSeed;

  /// 无 Rust UI-only 引导（kUiOnly 分支传入）：不起 myune Host，直接以
  /// 测试同款最小 Provider 集渲染壳（桌面 VoicefoxShell / 触屏
  /// TouchShell），页面呈现真实空/错误态。
  final bool uiOnly;

  const VoicefoxApp({
    super.key,
    required this.model,
    this.initialDestination,
    this.searchSeed = '',
    this.libraryTab,
    this.detailSeed,
    this.settingsSection,
    this.uiOnly = false,
  });

  @override
  State<VoicefoxApp> createState() => _VoicefoxAppState();
}

class _VoicefoxAppState extends State<VoicefoxApp> {
  MyuneHost? _host;

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_onModelChanged);
    _maybeAttachHost();
  }

  @override
  void didUpdateWidget(covariant VoicefoxApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      oldWidget.model.removeListener(_onModelChanged);
      widget.model.addListener(_onModelChanged);
      _maybeAttachHost();
    }
  }

  void _onModelChanged() => _maybeAttachHost();

  /// Rust 控制器就绪后才挂 myune Provider 图：引导期不跑 myune 的
  /// 文件系统初始化（日志/歌单 JSON/热键），失败时骨架屏保持轻量。
  void _maybeAttachHost() {
    if (_host == null && widget.model.ready) {
      setState(() => _host = MyuneHost.attach(widget.model));
    }
  }

  @override
  void dispose() {
    widget.model.removeListener(_onModelChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uiOnly) {
      // 无 Rust UI-only：壳直接渲染，不等 Rust 就绪（model.ready 永假也
      // 不回退骨架屏）。Provider 集对齐 shell_test.dart 桌面 harness；
      // 主题走 buildAppTheme 统一构建器（B2）：registry 默认 key 定深色
      // （真主题链路在 Phase 8 接 Rust 配置）。
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AppModel>.value(value: widget.model),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: SettingsProvider(),
          ),
          ChangeNotifierProvider<NotificationService>.value(
            value: NotificationService(),
          ),
        ],
        child: MaterialApp(
          title: 'voicefox',
          theme: buildAppTheme(
            'catppuccin-mocha',
            Brightness.dark,
            platform: defaultTargetPlatform,
          ),
          home: isTouchPlatform
              ? TouchShell(model: widget.model)
              : VoicefoxShell(
                  model: widget.model,
                  initialDestination: widget.initialDestination,
                  searchSeed: widget.searchSeed,
                  libraryTab: widget.libraryTab,
                  detailSeed: widget.detailSeed,
                  settingsSection: widget.settingsSection,
                ),
        ),
      );
    }
    final host = _host;
    if (host == null) {
      // 引导期：无 Provider 图，骨架屏 + 轻量标题栏（可关闭窗口）。
      return AnimatedBuilder(
        animation: widget.model,
        builder: (context, _) {
          final brightness = MediaQuery.platformBrightnessOf(context);
          return MaterialApp(
            title: 'voicefox',
            // 引导骨架屏同走统一构建器（B2）：按平台亮度取 registry 默认 key。
            theme: buildAppTheme(
              'catppuccin-mocha',
              brightness,
              platform: defaultTargetPlatform,
            ),
            home: _BootstrapScreen(model: widget.model),
          );
        },
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppModel>.value(value: widget.model),
        ChangeNotifierProvider<SettingsProvider>.value(value: host.settings),
        ChangeNotifierProvider<ThemeProvider>.value(value: host.theme),
        ChangeNotifierProvider<NotificationService>.value(
          value: host.notifications,
        ),
        ChangeNotifierProvider<PlaylistContentNotifier>.value(
          value: host.playlist,
        ),
      ],
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.model, host.theme]),
        builder: (context, _) {
          return DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              // 动态取色：系统调色板作为 seed 桥进 ThemeProvider（内部有
              // 变更守卫，重复 build 不落盘）。关闭时由 MyuneProjection
              // 应用 TUI 同源 seed。
              if (widget.model.useDynamicColor && lightDynamic != null) {
                host.theme.setSeedColor(lightDynamic.primary);
              }
              return MaterialApp(
                title: 'voicefox',
                theme: host.theme.lightThemeData,
                darkTheme: host.theme.darkThemeData,
                themeMode: host.theme.themeMode,
                // 桌面平台恒走 VoicefoxShell（四档断点零变化）；触屏平台
                // 按宽度进移动/平板形态（responsive_shell.dart 设备形态）。
                home: isTouchPlatform
                    ? TouchShell(model: widget.model)
                    : VoicefoxShell(
                        model: widget.model,
                        initialDestination: widget.initialDestination,
                        searchSeed: widget.searchSeed,
                        libraryTab: widget.libraryTab,
                        detailSeed: widget.detailSeed,
                        settingsSection: widget.settingsSection,
                      ),
              );
            },
          );
        },
      ),
    );
  }
}

/// 引导骨架屏：等待 Rust 控制器；自绘窗口按钮（此时没有 Provider 图，
/// 复用不了 VoicefoxWindowTitleBar）。
class _BootstrapScreen extends StatelessWidget {
  final AppModel model;

  const _BootstrapScreen({required this.model});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 拖动区/关闭按钮只在桌面窗口平台进树（window_manager 无移动端实现）。
    final desktopWindow = _isDesktopWindowPlatform;
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: 31,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(Icons.graphic_eq, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'voicefox',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                Expanded(
                  child: desktopWindow
                      ? DragToMoveArea(child: const SizedBox.expand())
                      : const SizedBox.expand(),
                ),
                if (desktopWindow)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: windowManager.close,
                      child: const SizedBox(
                        width: 40,
                        height: 31,
                        child: Icon(Icons.close, size: 16),
                      ),
                    ),
                  ),
                const SizedBox(width: 2),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: model,
                builder: (context, _) {
                  final error = model.lastNotification;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (error == null)
                        const CircularProgressIndicator()
                      else
                        Icon(
                          Icons.error_outline,
                          size: 40,
                          color: scheme.error,
                        ),
                      const SizedBox(height: 16),
                      Text(
                        error ?? '正在启动 voicefox…',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

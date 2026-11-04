/// voicefox Flutter 前端入口。
///
/// 桌面：Rust 侧 newDesktop()（mpv 播放）引导；移动端（Phase 4）由宿主注入
/// ApplicationService 后走 AppModel.attach。
/// UI 壳为 myune 基底：Rust 引导完成后 `MyuneHost` 挂起 app 级 Provider 图
/// （存活全程），`MyuneProjection` 把 AppModel 快照常驻投影进 vendored 组件。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app_model.dart';
import 'src/myune/page/playlist/playlist_content_notifier.dart';
import 'src/myune/page/setting/settings_provider.dart';
import 'src/myune/services/notification_service.dart';
import 'src/myune/theme/theme_provider.dart';
import 'src/myune_seam/app_model_audio_backend.dart'
    show attachVoicefoxAudioBackend;
import 'src/myune_shell/app_shell.dart';
import 'src/myune_shell/projection.dart' show MyuneHost;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 自绘标题栏（VoicefoxWindowTitleBar）依赖隐藏系统标题栏。
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    title: 'voicefox',
    size: Size(1150, 720),
    minimumSize: Size(560, 480),
    titleBarStyle: TitleBarStyle.hidden,
  );
  unawaited(
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
    }),
  );

  final model = AppModel();
  // myune 壳的播放接缝：vendored UI 全部通过 shim 走 AppModel。
  attachVoicefoxAudioBackend(model);
  final app = VoicefoxApp(model: model);
  // Rust 引导放后台：窗口先起，骨架屏等待；就绪后 VoicefoxApp 挂 Provider 图。
  unawaited(
    model.bootstrapDesktop().catchError(model.reportBootstrapError),
  );
  runApp(app);
}

class VoicefoxApp extends StatefulWidget {
  final AppModel model;

  const VoicefoxApp({super.key, required this.model});

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
    final host = _host;
    if (host == null) {
      // 引导期：无 Provider 图，骨架屏 + 轻量标题栏（可关闭窗口）。
      return AnimatedBuilder(
        animation: widget.model,
        builder: (context, _) {
          final brightness = MediaQuery.platformBrightnessOf(context);
          return MaterialApp(
            title: 'voicefox',
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF89B4FA),
                brightness: brightness,
              ),
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
                home: VoicefoxAppShell(model: widget.model),
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
                  child: DragToMoveArea(child: const SizedBox.expand()),
                ),
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

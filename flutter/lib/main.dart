/// voicefox Flutter 前端入口。
///
/// 桌面：Rust 侧 newDesktop()（mpv 播放）引导；移动端（Phase 4）由宿主注入
/// ApplicationService 后走 AppModel.attach。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'src/app_model.dart';
import 'src/shell.dart';
import 'src/theme/voicefox_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final model = AppModel();
  final app = VoicefoxApp(model: model);
  // Rust 引导放后台：窗口先起，骨架屏等待
  unawaited(
    model.bootstrapDesktop().catchError(model.reportBootstrapError),
  );
  runApp(app);
}

class VoicefoxApp extends StatelessWidget {
  final AppModel model;

  const VoicefoxApp({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            final useDynamic = model.useDynamicColor;
            final light = buildVoicefoxTheme(
              model.themeKey,
              Brightness.light,
              dynamicScheme: useDynamic ? lightDynamic : null,
            );
            final dark = buildVoicefoxTheme(
              model.themeKey,
              Brightness.dark,
              dynamicScheme: useDynamic ? darkDynamic : null,
            );
            return MaterialApp(
              title: 'voicefox',
              theme: light,
              darkTheme: dark,
              themeMode: ThemeMode.system,
              home: model.ready
                  ? VoicefoxShell(model)
                  : _BootstrapScreen(model: model),
            );
          },
        );
      },
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  final AppModel model;

  const _BootstrapScreen({required this.model});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              model.lastNotification ?? '正在启动 voicefox…',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

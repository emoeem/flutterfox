/// Phase 7 无 Rust UI-only 引导分支测试（kUiOnly，main.dart）。
///
/// kUiOnly = bool.fromEnvironment('VOICEFOX_UI_ONLY') && kDebugMode 只在
/// main() 生效（编译期常量，release 树摇剔除）；widget 测试直接传
/// uiOnly: true 验证同一分支的渲染路径：
/// - uiOnly：不等 Rust 就绪，直接渲染桌面壳（测试环境 isTouchPlatform
///   为 false），无骨架屏 CircularProgressIndicator；
/// - 非 uiOnly：保持既有引导骨架屏（mini_player_test.dart 既有断言）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/main.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/player/player_bar.dart';
import 'package:voicefox_flutter/src/shell/app_shell.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('uiOnly=true：跳过骨架屏直接渲染桌面壳（各页真实空态）', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final model = AppModel();
    await tester.pumpWidget(VoicefoxApp(model: model, uiOnly: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 桌面壳直接在树里（PlayerBar 常驻），而不是引导骨架屏。
    expect(find.byType(VoicefoxShell), findsOneWidget);
    expect(find.byType(PlayerBar), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // 无 Rust：播放栏为真实空态。
    expect(find.text('选择一首歌曲开始播放'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uiOnly=false（默认）：保持既有引导骨架屏路径', (tester) async {
    final model = AppModel();
    await tester.pumpWidget(VoicefoxApp(model: model));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(VoicefoxShell), findsNothing);
  });
}

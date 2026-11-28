/// MobileSettingsPage 测试（Batch C-C→C-D C-06 / R6）。
///
/// 覆盖：九组卡片渲染、点分组推入全屏二级页（桌面 SettingsPage 窄宽形态
/// 复用）、initialSection 种子（抽屉「音源管理」）帧后直接定位二级页。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/pages/mobile_settings_page.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/settings_page.dart';

Future<void> _pump(
  WidgetTester tester,
  AppModel model, {
  SettingsSection? initialSection,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MobileSettingsPage(model: model, initialSection: initialSection),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('九组分组卡片全部渲染（SettingsSection.values）', (tester) async {
    await _pump(tester, AppModel());
    expect(find.byType(MobileSettingsPage), findsOneWidget);
    for (final section in SettingsSection.values) {
      expect(find.text(section.label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('点分组推入全屏二级页（SettingsPage 在树）', (tester) async {
    final model = AppModel()
      ..debugSetConfig(
        bridge.ConfigDto(
          theme: 'catppuccin-mocha',
          dynamicColor: false,
          themeMode: 'system',
          volume: 60,
          playbackSpeed: 1.0,
          playMode: 'list-loop',
          historyLimit: 100,
          defaultSource: 'kw',
          enabledSources: ['kw', 'wy'],
          jsSourcesFirst: false,
          downloadDir: '/tmp/music',
          downloadQuality: '320k',
          downloadConcurrency: 3,
          showTranslation: true,
          showYrc: false,
          lyricOffsetMs: 0,
          proxyUrl: '',
          networkTimeoutSecs: BigInt.from(30),
          localMusicEnabled: true,
          localMusicPaths: [],
          localMusicMaxDepth: 0,
        ),
      );
    await _pump(tester, model);
    await tester.tap(find.text(SettingsSection.playback.label));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(
      find.byType(MobileSettingsPage, skipOffstage: false),
      findsOneWidget,
      reason: '入口页在路由栈下层（offstage）保持',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('initialSection 种子：帧后直接定位二级页（音源管理）', (tester) async {
    final model = AppModel()
      ..debugSetConfig(
        bridge.ConfigDto(
          theme: 'catppuccin-mocha',
          dynamicColor: false,
          themeMode: 'system',
          volume: 60,
          playbackSpeed: 1.0,
          playMode: 'list-loop',
          historyLimit: 100,
          defaultSource: 'kw',
          enabledSources: ['kw', 'wy'],
          jsSourcesFirst: false,
          downloadDir: '/tmp/music',
          downloadQuality: '320k',
          downloadConcurrency: 3,
          showTranslation: true,
          showYrc: false,
          lyricOffsetMs: 0,
          proxyUrl: '',
          networkTimeoutSecs: BigInt.from(30),
          localMusicEnabled: true,
          localMusicPaths: [],
          localMusicMaxDepth: 0,
        ),
      );
    await _pump(tester, model, initialSection: SettingsSection.sources);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    // 入口卡片「音源」与二级页 AppBar「音源」同现；种子语义以二级页
    // SettingsPage 在树为准。
    expect(find.text(SettingsSection.sources.label), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

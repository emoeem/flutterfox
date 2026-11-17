/// 手机设置页测试（计划书 C-06，指南 §6.3「分组列表与独立二级设置页」；
/// 360 视口为主）：
/// - 分组列表 9 组渲染（icon + label + chevron，触控目标 ≥48dp），
///   360/390/430 无横向溢出（列表不依赖 config 快照）；
/// - 点组推入二级页（AppBar = 分组名）；config 未达时二级页如实显示
///   加载态（不伪造设置项）；config 到达后渲染与桌面双栏右侧同一实现
///   （SettingsSectionContent 单一出处）；
/// - 音源管理种子（initialSection: sources）首帧后自动推入对应二级页；
/// - 桌面槽守卫：buildShellPage settings 槽 desktop/平板维持桌面双栏页。
///
/// 平台口径：页面级 pump（同 mobile_search_page_test 口径；壳内接线由
/// mobile_shell_test 覆盖）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/mobile_settings_page.dart';
import 'package:voicefox_flutter/src/pages/settings_page.dart';
import 'package:voicefox_flutter/src/shell/app_sidebar.dart'
    show ShellDestination;
import 'package:voicefox_flutter/src/shell/app_shell.dart'
    show ShellFormFactor, buildShellPage;

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpList(
  WidgetTester tester,
  AppModel model, {
  Size size = const Size(360, 800),
  SettingsSection? initialSection,
}) async {
  _setSize(tester, size);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MobileSettingsPage(model, initialSection: initialSection),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('分组列表 9 组齐备、360/390/430 无横向溢出', (tester) async {
    for (final size in const [
      Size(430, 932),
      Size(390, 844),
      Size(360, 800), // 最窄手机档。
    ]) {
      final model = AppModel();
      await _pumpList(tester, model, size: size);
      expect(tester.takeException(), isNull, reason: '${size.width} 视口无溢出');
      for (final label in [
        '播放与音效',
        '音源',
        '下载',
        '歌词',
        '外观',
        '网络',
        '账号与集成',
        '快捷键',
        '关于',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '分组行：$label');
      }
      // 行触控目标 ≥48dp（§5.9）。
      final row = find
          .ancestor(of: find.text('播放与音效'), matching: find.byType(InkWell))
          .first;
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('点组推入二级页；config 未达如实显示加载态（不伪造设置项）', (tester) async {
    final model = AppModel();
    await _pumpList(tester, model);
    await tester.tap(find.text('播放与音效'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(MobileSettingsSectionPage), findsOneWidget);
    expect(find.text('播放与音效'), findsNWidgets(2), reason: '列表行 + 二级页 AppBar');
    // 无控制器时 config 未加载：二级页如实加载态（四态之载入态）。
    expect(find.text('配置加载中…'), findsOneWidget);
    expect(find.text('音量'), findsNothing, reason: '不伪造设置项');
  });

  testWidgets('config 到达后二级页渲染真实设置项（与桌面同一实现）', (tester) async {
    final model = AppModel();
    model.debugSetConfig(
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
    await _pumpList(tester, model);
    await tester.tap(find.text('外观'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('明暗模式'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('音源管理种子：首帧后自动推入 sources 二级页', (tester) async {
    final model = AppModel();
    await _pumpList(tester, model, initialSection: SettingsSection.sources);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(MobileSettingsSectionPage), findsOneWidget);
    // sources 二级页 AppBar 标题。
    expect(find.text('音源'), findsWidgets);
    // config 未达：内容加载态（种子直达仍不伪造设置项）。
    expect(find.text('配置加载中…'), findsOneWidget);
  });

  testWidgets('buildShellPage settings 槽：mobile 分组列表、desktop/平板桌面双栏守卫', (
    tester,
  ) async {
    final model = AppModel();
    _setSize(tester, const Size(360, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildShellPage(
            model,
            ShellDestination.settings,
            form: ShellFormFactor.mobile,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(MobileSettingsPage), findsOneWidget);
    expect(find.text('播放与音效'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: buildShellPage(model, ShellDestination.settings)),
      ),
    );
    await tester.pump();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(MobileSettingsPage), findsNothing);
  });
}

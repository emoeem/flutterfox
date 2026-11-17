/// 循环模式分档视觉与循环顺序测试（指南 §8.3 播放模式可见性）。
///
/// 背景（QA 2026-11-11 repeat-mode-2 证据失实）：两档循环此前共用
/// Icons.repeat 且同为 primary 色——repeat-mode-1（蓝）无法证明是 list-loop
/// 还是 single-loop，repeat-mode-2（灰）无法区分「第 2 档未激活」与
/// 「点击打到了 none」。修复后：list-loop = Icons.repeat + primary +
/// tooltip「列表循环」，single-loop = Icons.repeat_one + primary +
/// tooltip「单曲循环」，none = 中性灰 + tooltip「循环播放」，每一档都有
/// 可验证的独立视觉态；实机复拍（Xvfb + config.toml 地面真值）见
/// phase-1-report 补记。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/design_system/components/vx_player_controls.dart';
import 'package:voicefox_flutter/src/player/player_bar.dart';

/// updateConfig 本地落盘（不起 Rust 控制器）：循环点击后的 config 即时可见。
class _LocalConfigModel extends AppModel {
  @override
  Future<void> updateConfig(
    bridge.ConfigDto Function(bridge.ConfigDto) patch,
  ) async {
    final current = config;
    if (current == null) throw StateError('config not seeded');
    debugSetConfig(patch(current));
  }
}

bridge.ConfigDto _configWithMode(String mode) => bridge.ConfigDto(
  theme: 'catppuccin-mocha',
  dynamicColor: false,
  themeMode: 'system',
  volume: 60,
  playbackSpeed: 1.0,
  playMode: mode,
  historyLimit: 100,
  defaultSource: 'kw',
  enabledSources: ['kw'],
  jsSourcesFirst: false,
  downloadDir: '/tmp/music',
  downloadQuality: null,
  downloadConcurrency: 2,
  showTranslation: true,
  showYrc: false,
  lyricOffsetMs: 0,
  proxyUrl: '',
  networkTimeoutSecs: BigInt.from(30),
  localMusicEnabled: false,
  localMusicPaths: const [],
  localMusicMaxDepth: 0,
);

/// 直接渲染 VxPlayerControls 的最小宿主（组件三档视觉）。
Widget _controlsHost({required bool repeatOn, required bool repeatSingle}) =>
    MaterialApp(
      theme: _testTheme,
      home: Scaffold(
        body: Center(
          child: VxPlayerControls(
            shuffleOn: false,
            repeatOn: repeatOn,
            repeatSingle: repeatSingle,
            onRepeat: () {},
          ),
        ),
      ),
    );

final ThemeData _testTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
);

/// PlayerBar 真实宿主（循环点击走 _cycleRepeat → updateConfig 本地落盘）。
Widget _barHost(AppModel model) => MaterialApp(
  theme: _testTheme,
  home: Scaffold(
    body: Column(
      children: [
        const Spacer(),
        PlayerBar(model: model),
      ],
    ),
  ),
);

Icon? _repeatIcon(WidgetTester tester) {
  for (final type in const [Icons.repeat, Icons.repeat_one]) {
    final matches = find.byIcon(type).evaluate().toList();
    if (matches.isNotEmpty) return matches.first.widget as Icon;
  }
  return null;
}

void main() {
  group('VxPlayerControls 三档视觉（§8.3 播放模式可见性）', () {
    testWidgets('none 档：repeat 图标、中性灰、tooltip「循环播放」', (tester) async {
      await tester.pumpWidget(
        _controlsHost(repeatOn: false, repeatSingle: false),
      );
      await tester.pump();
      expect(find.byIcon(Icons.repeat), findsOneWidget);
      expect(find.byIcon(Icons.repeat_one), findsNothing);
      final icon = _repeatIcon(tester)!;
      expect(
        icon.color,
        _testTheme.colorScheme.onSurfaceVariant,
        reason: 'none = 未激活（中性灰，QA repeat-mode-2 实测色的代码出处）',
      );
      expect(find.byTooltip('循环播放'), findsOneWidget);
    });

    testWidgets('list-loop 档：repeat 图标、primary 色、tooltip「列表循环」', (
      tester,
    ) async {
      await tester.pumpWidget(
        _controlsHost(repeatOn: true, repeatSingle: false),
      );
      await tester.pump();
      expect(find.byIcon(Icons.repeat), findsOneWidget);
      expect(find.byIcon(Icons.repeat_one), findsNothing);
      final icon = _repeatIcon(tester)!;
      expect(
        icon.color,
        _testTheme.colorScheme.primary,
        reason: '第 1 档激活态 = 主色（对照 vx_player_controls active 分支）',
      );
      expect(find.byTooltip('列表循环'), findsOneWidget);
    });

    testWidgets('single-loop 档：repeat_one 图标、primary 色、tooltip「单曲循环」', (
      tester,
    ) async {
      await tester.pumpWidget(
        _controlsHost(repeatOn: true, repeatSingle: true),
      );
      await tester.pump();
      expect(
        find.byIcon(Icons.repeat_one),
        findsOneWidget,
        reason: '第 2 档必须有独立图标（QA repeat-mode-2 缺口的代码修复）',
      );
      expect(find.byIcon(Icons.repeat), findsNothing);
      final icon = _repeatIcon(tester)!;
      expect(icon.color, _testTheme.colorScheme.primary);
      expect(find.byTooltip('单曲循环'), findsOneWidget);
    });
  });

  group('PlayerBar 循环点击顺序（_cycleRepeat → updateConfig）', () {
    testWidgets('list-loop → single-loop → none → list-loop；tooltip/图标随档切换', (
      tester,
    ) async {
      final model = _LocalConfigModel();
      model.debugSetConfig(_configWithMode('list-loop'));
      model.debugSetPlaybackSong(
        id: 's1',
        source: 'kw',
        name: '测试曲',
        singer: '歌手',
      );
      await tester.pumpWidget(_barHost(model));
      await tester.pump();

      // 第 1 档（list-loop）：tooltip「列表循环」。
      expect(find.byTooltip('列表循环'), findsOneWidget);
      await tester.tap(find.byTooltip('列表循环'));
      await tester.pump();

      // 第 2 档（single-loop）：tooltip「单曲循环」+ repeat_one 图标。
      expect(
        model.config!.playMode,
        'single-loop',
        reason: '第 2 档循环必须可到达（§8.3）',
      );
      expect(find.byTooltip('单曲循环'), findsOneWidget);
      expect(find.byIcon(Icons.repeat_one), findsOneWidget);

      await tester.tap(find.byTooltip('单曲循环'));
      await tester.pump();
      expect(model.config!.playMode, 'none');
      expect(find.byTooltip('循环播放'), findsOneWidget);
      expect(
        find.byIcon(Icons.repeat_one),
        findsNothing,
        reason: 'none 档不得残留 repeat_one',
      );

      await tester.tap(find.byTooltip('循环播放'));
      await tester.pump();
      expect(model.config!.playMode, 'list-loop', reason: '循环闭合回第 1 档');
    });
  });
}

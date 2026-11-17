/// Phase 5 设置页：分类导航、主题卡密度、slider 约束、行密度、QR 对话框。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/settings_page.dart';
import 'package:voicefox_flutter/src/theme/registry.dart';

bridge.ConfigDto _config() => bridge.ConfigDto(
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
);

bridge.SourceCapabilitiesDto _cap(String id) => bridge.SourceCapabilitiesDto(
  id: id,
  name: id.toUpperCase(),
  playlists: true,
  playlistCategories: false,
  playlistSearch: true,
  album: true,
  artist: true,
  leaderboard: true,
  login: true,
  qrLogin: true,
);

Future<void> _pump(WidgetTester tester) async {
  final model = AppModel();
  model.debugSetConfig(_config());
  model.debugSetSources([_cap('kw'), _cap('wy')]);
  // 与 Shell 内一致：页面在 Scaffold（Material）之上渲染。
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: SettingsPage(model))),
  );
  await tester.pump();
}

void main() {
  testWidgets('左侧分类导航包含九个分类，点击切换内容', (tester) async {
    await _pump(tester);

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
      expect(find.text(label), findsOneWidget, reason: '缺少分类：$label');
    }

    // 默认在播放组：音量可见；切到歌词组后音量不可见、翻译开关可见。
    expect(find.text('音量'), findsOneWidget);
    await tester.tap(find.text('歌词'));
    await tester.pump();
    expect(find.text('显示翻译'), findsOneWidget);
    expect(find.text('音量'), findsNothing);
  });

  testWidgets('44 个主题以小预览卡收进外观组（密度统一）', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('外观'));
    await tester.pump();

    // 16 同源 + 1 FlClash + 27 内置 = 44。
    final total = kSyncedThemes.length + 1 + kBuiltinThemes.length;
    expect(total, 44, reason: '主题注册表应维持 44 套');

    // 同步主题组在首屏完整渲染：16 张卡逐一可见。
    for (final entry in kSyncedThemes) {
      expect(
        find.textContaining(entry.label),
        findsWidgets,
        reason: '主题卡缺少：${entry.label}',
      );
    }

    // 压缩后的卡片宽度（96 - 内边距 4*2 = 88），不再是 116 大卡。
    final firstCard = find.textContaining(kSyncedThemes.first.label);
    expect(tester.getSize(firstCard).width, lessThan(100));

    // 内置扩展组在下方：把内容 ListView 拖到底部后 28 张卡可见。
    await tester.drag(find.byType(ListView).last, const Offset(0, -1400));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1400));
    await tester.pumpAndSettle();
    for (final entry in [kFlClashTheme, ...kBuiltinThemes]) {
      expect(
        find.textContaining(entry.label),
        findsWidgets,
        reason: '主题卡缺少：${entry.label}',
      );
    }
  });

  testWidgets('滑杆限宽 320px（Phase 0 S2 修复）', (tester) async {
    await _pump(tester);
    final sliders = find.byType(Slider);
    expect(sliders, findsWidgets);
    for (final slider in sliders.evaluate()) {
      final width = tester.getSize(find.byWidget(slider.widget)).width;
      expect(width, lessThanOrEqualTo(320.0), reason: '滑杆不得超过 320px');
    }
  });

  testWidgets('设置行最小高 52px，开关与 label 同行就近排列', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('歌词'));
    await tester.pump();

    final row = find.ancestor(
      of: find.text('显示翻译'),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.minHeight == 52,
      ),
    );
    expect(row, findsOneWidget);
    expect(tester.getSize(row).height, greaterThanOrEqualTo(52));
    // 开关与文字在同一行（同一 Row 内，不是上下堆叠）。
    final textRect = tester.getRect(find.text('显示翻译'));
    final switchRect = tester.getRect(find.byType(Switch).first);
    expect(
      (textRect.top - switchRect.top).abs() < 40,
      isTrue,
      reason: '开关应与 label 垂直就近',
    );
  });

  testWidgets('QR 登录走独立对话框，不再整页跳转', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('账号与集成'));
    await tester.pump();
    await tester.tap(find.text('扫码登录'));
    await tester.pump();
    await tester.pump();

    // 对话框内容出现：四个音源入口 + 状态提示。
    expect(find.text('酷狗'), findsOneWidget);
    expect(find.text('QQ 音乐'), findsOneWidget);
    expect(find.text('网易云'), findsOneWidget);
    expect(find.text('哔哩哔哩'), findsOneWidget);
    expect(find.text('选择音源生成登录二维码'), findsOneWidget);
    // 对话框内有关闭按钮（独立 Dialog，非压栈整页）。
    expect(find.byTooltip('关闭'), findsOneWidget);
  });

  testWidgets('快捷键分组列出播放/导航键位', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('快捷键'));
    await tester.pump();
    expect(find.text('播放 / 暂停'), findsOneWidget);
    expect(find.text('快退 / 快进 5 秒'), findsOneWidget);
    expect(find.textContaining('Ctrl / ⌘ + K'), findsOneWidget);
  });

  testWidgets('关于分组展示版本并提供帮助页入口', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('关于'));
    await tester.pump();
    expect(find.textContaining('0.8.1'), findsWidgets);
    expect(find.text('帮助与关于'), findsOneWidget);
  });
}

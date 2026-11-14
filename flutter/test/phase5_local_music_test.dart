/// Phase 5 本地音乐：目录管理、扫描进度与警告、歌曲列表。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/local_music_page.dart';

bridge.ConfigDto _config({List<String> paths = const []}) => bridge.ConfigDto(
  theme: 'catppuccin-mocha',
  dynamicColor: false,
  themeMode: 'system',
  volume: 100,
  playbackSpeed: 1.0,
  playMode: 'none',
  historyLimit: 100,
  defaultSource: 'kw',
  enabledSources: const ['kw'],
  jsSourcesFirst: false,
  downloadDir: '/tmp',
  downloadQuality: null,
  downloadConcurrency: 2,
  showTranslation: true,
  showYrc: false,
  lyricOffsetMs: 0,
  proxyUrl: '',
  networkTimeoutSecs: BigInt.from(30),
  localMusicEnabled: true,
  localMusicPaths: paths,
  localMusicMaxDepth: 0,
);

bridge.SongDto _song(String id, String name) => bridge.SongDto(
  id: id,
  source: 'local',
  name: name,
  singer: '本地歌手',
  albumName: '本地专辑',
  durationMs: BigInt.from(180000),
  coverUrl: null,
);

Future<void> _pump(
  WidgetTester tester, {
  required List<String> paths,
  List<bridge.SongDto> songs = const [],
}) async {
  final model = AppModel();
  model.debugSetConfig(_config(paths: paths));
  model.debugSetLocalSongs(songs);
  await tester.pumpWidget(MaterialApp(home: LocalMusicPage(model)));
  // 进入页面按 TUI 规则自动补一次扫描；用测试钩子结束它，
  // 使「已配置目录但无歌曲」的空态（含目录管理卡）可达。
  await tester.pump();
  model.debugCompleteLocalScan(songs: songs);
  await tester.pump();
}

void main() {
  group('目录管理', () {
    test('localMusicPathsAfterRemove 仅移除目标且保持顺序', () {
      final next = localMusicPathsAfterRemove(['/a', '/b', '/c'], '/b');
      expect(next, ['/a', '/c']);
      // 目标不存在时原样返回。
      expect(localMusicPathsAfterRemove(['/a'], '/x'), ['/a']);
      // 移除最后一个目录 → 空列表（触发空态引导）。
      expect(localMusicPathsAfterRemove(['/a'], '/a'), isEmpty);
    });

    testWidgets('目录逐个列出并带移除按钮', (tester) async {
      await _pump(tester, paths: ['/music-a', '/music-b']);
      expect(find.text('音乐目录'), findsOneWidget);
      expect(find.text('/music-a'), findsOneWidget);
      expect(find.text('/music-b'), findsOneWidget);
      expect(find.byTooltip('移除目录 /music-a'), findsOneWidget);
      expect(find.byTooltip('移除目录 /music-b'), findsOneWidget);
    });

    testWidgets('移除目录弹出确认对话框并显示路径', (tester) async {
      await _pump(tester, paths: ['/music-a']);
      await tester.tap(find.byTooltip('移除目录 /music-a'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('移除本地音乐目录'), findsOneWidget);
      expect(find.textContaining('/music-a'), findsWidgets);
      expect(find.text('移除'), findsOneWidget);

      // 确认后对话框关闭（无控制器环境下配置不回写，仅验证流程收口）。
      await tester.tap(find.widgetWithText(FilledButton, '移除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('移除本地音乐目录'), findsNothing);
    });
  });

  group('扫描状态与列表', () {
    testWidgets('有歌曲时列表展示并可进入单曲菜单', (tester) async {
      await _pump(
        tester,
        paths: ['/music'],
        songs: [_song('s1', '本地一'), _song('s2', '本地二')],
      );
      expect(find.text('共 2 首'), findsOneWidget);
      expect(find.text('本地一'), findsOneWidget);
      expect(find.text('本地二'), findsOneWidget);
      // 播放全部在顶栏可用。
      final play = tester.widget<FilledButton>(
        find
            .ancestor(
              of: find.text('播放全部'),
              matching: find.byType(FilledButton),
            )
            .first,
      );
      expect(play.onPressed, isNotNull);
    });

    testWidgets('空态区分未配置目录 / 扫描失败两种情形', (tester) async {
      await _pump(tester, paths: const []);
      expect(find.text('尚未配置本地音乐目录'), findsOneWidget);

      final model = AppModel();
      model.debugSetConfig(_config(paths: const ['/missing']));
      model.debugSetLocalSongs(const []);
      model.debugCompleteLocalScan(warnings: const ['目录不存在: /missing']);
      await tester.pumpWidget(MaterialApp(home: LocalMusicPage(model)));
      await tester.pump();
      expect(find.text('扫描失败'), findsOneWidget);
      expect(find.textContaining('目录不存在: /missing'), findsOneWidget);
    });

    testWidgets('扫描中横幅提供取消；取消后统计条不展示旧值（§5.10 流程 4）', (tester) async {
      final model = AppModel();
      model.debugSetConfig(_config(paths: const ['/music']));
      final dispatched = <bridge.FfiCommand>[];
      model.debugSetDispatcherForTest((command) async {
        dispatched.add(command);
      });
      await tester.pumpWidget(MaterialApp(home: LocalMusicPage(model)));
      await tester.pump();
      model.debugCompleteLocalScan(
        songs: [_song('s1', '本地一')],
        stats: bridge.ScanStatsDto(
          discovered: 1,
          reused: 0,
          parsed: 1,
          failed: 0,
          removed: 0,
          skipped: 0,
        ),
      );
      await tester.pump();

      // 再次扫描：横幅出现「取消」，点击下发 LocalScanCancel。
      model.scanLocal();
      await tester.pump();
      expect(find.text('正在扫描本地歌曲…'), findsOneWidget);
      final cancel = tester.widget<TextButton>(
        find
            .ancestor(of: find.text('取消'), matching: find.byType(TextButton))
            .first,
      );
      expect(cancel.onPressed, isNotNull);
      await tester.tap(find.text('取消'));
      await tester.pump();
      expect(
        dispatched.whereType<bridge.FfiCommand_LocalScanCancel>().length,
        1,
      );

      // 取消事件：scanning=false、stats 清空（旧值不上屏）、列表不变。
      model.debugCompleteLocalScan(cancelled: true);
      await tester.pump();
      expect(model.scanningLocal, isFalse);
      expect(model.scanStats, isNull);
      expect(model.state.localSongs.length, 1, reason: '已提交结果保持不变');
      expect(find.textContaining('扫描已取消'), findsOneWidget);
    });
  });
}

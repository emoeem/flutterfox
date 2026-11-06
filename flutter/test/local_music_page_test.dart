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

void main() {
  testWidgets('扫描中展示加载态', (tester) async {
    final model = AppModel();
    model.debugSetConfig(_config(paths: const ['/music']));
    model.debugSetLocalSongs(const []);

    await tester.pumpWidget(MaterialApp(home: LocalMusicPage(model)));
    // 进入页面按 TUI 规则自动补一次扫描。
    await tester.pump();

    expect(find.text('正在扫描本地歌曲…'), findsOneWidget);
  });

  testWidgets('未配置目录时给出空态引导', (tester) async {
    final model = AppModel();
    model.debugSetConfig(_config());
    model.debugSetLocalSongs(const []);

    await tester.pumpWidget(MaterialApp(home: LocalMusicPage(model)));
    await tester.pump();

    expect(find.text('尚未配置本地音乐目录'), findsOneWidget);
    // 顶栏与空态各有一个「添加目录」入口。
    expect(find.text('添加目录'), findsWidgets);
  });

  testWidgets('扫描警告展示错误态与重试', (tester) async {
    final model = AppModel();
    model.debugSetConfig(_config(paths: const ['/missing']));
    model.debugSetLocalSongs(const []);

    await tester.pumpWidget(MaterialApp(home: LocalMusicPage(model)));
    await tester.pump();
    expect(find.text('正在扫描本地歌曲…'), findsOneWidget);

    model.debugCompleteLocalScan(warnings: const ['目录不存在: /missing']);
    await tester.pump();

    expect(find.text('扫描失败'), findsOneWidget);
    expect(find.text('目录不存在: /missing'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('已扫描到歌曲时展示列表与播放全部', (tester) async {
    final model = AppModel();
    model.debugSetConfig(_config(paths: const ['/music']));
    model.debugSetLocalSongs([_song('s1', '本地一'), _song('s2', '本地二')]);

    await tester.pumpWidget(MaterialApp(home: LocalMusicPage(model)));
    await tester.pump();

    expect(find.text('共 2 首'), findsOneWidget);
    expect(find.text('播放全部'), findsOneWidget);
    // 目录管理卡逐个列出目录（可移除）。
    expect(find.text('/music'), findsOneWidget);
    // VxSongTable：序号独立列，行文本不带 'N. ' 前缀。
    expect(find.text('本地一'), findsOneWidget);
    expect(find.text('本地二'), findsOneWidget);

    // 单曲行提供播放（双击语义由行内承接）与右键菜单（更多按钮）；
    // 菜单路由有进场动画，需要两次 pump 才可见。
    await tester.tap(find.byIcon(Icons.more_vert).first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('加入队列'), findsOneWidget);
    expect(find.text('立即播放'), findsOneWidget);
  });
}

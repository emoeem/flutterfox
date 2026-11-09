/// Phase 5 我的音乐：二级切换、计数徽章、搜索/排序、聚合视图与三入口。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/design_system/components/vx_album_card.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_cover_fallback.dart';
import 'package:voicefox_flutter/src/pages/library_page.dart';
import 'package:voicefox_flutter/src/pages/local_music_page.dart';

bridge.SourceCapabilitiesDto _caps() => const bridge.SourceCapabilitiesDto(
  id: 'kw',
  name: 'KW',
  playlists: true,
  playlistCategories: false,
  playlistSearch: true,
  album: true,
  artist: true,
  leaderboard: true,
  login: false,
  qrLogin: false,
);

bridge.ConfigDto _config() => bridge.ConfigDto(
  theme: 'catppuccin-mocha',
  dynamicColor: false,
  themeMode: 'system',
  volume: 60,
  playbackSpeed: 1.0,
  playMode: 'none',
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
  localMusicEnabled: true,
  localMusicPaths: ['/music'],
  localMusicMaxDepth: 0,
);

bridge.SongDto _song(
  String id,
  String name, {
  String singer = '歌手甲',
  String album = '专辑壹',
  String source = 'kw',
}) => bridge.SongDto(
  id: id,
  source: source,
  name: name,
  singer: singer,
  albumName: album,
  durationMs: BigInt.from(180000),
  coverUrl: null,
);

Future<AppModel> _pump(
  WidgetTester tester, {
  List<bridge.SongDto> favorites = const [],
  bool withOthers = true,
}) async {
  final model = AppModel();
  model.debugSetSources([_caps()]);
  model.debugSetConfig(_config());
  model.debugSetFavorites(favorites);
  if (withOthers) {
    model.debugSetCustomPlaylists(const [
      bridge.CustomPlaylistSummaryDto(
        id: 'c1',
        name: '通勤',
        coverUrl: null,
        songCount: 2,
      ),
    ]);
    model.debugSetLocalSongs([_song('l1', '本地一', source: 'local')]);
    model.debugSetHistory([_song('h1', '历史一', album: '专辑贰', singer: '歌手乙')]);
  }
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: LibraryPage(model))),
  );
  await tester.pump();
  return model;
}

void main() {
  testWidgets('二级切换渲染四类视图，计数徽章 0 值也可见', (tester) async {
    await _pump(tester);

    for (final label in ['歌曲', '专辑', '歌手', '歌单']) {
      expect(find.text(label), findsOneWidget, reason: '缺少二级类别：$label');
    }
    // 专辑/歌手聚合有计数（历史+本地）；歌曲收藏为空 → 0 值徽章
    // 弱化显示但不可隐藏（Phase 0 S4：0 值 tab 用计数徽章，不平铺）。
    expect(find.text('2'), findsWidgets);
    expect(find.text('0'), findsOneWidget, reason: '歌曲 tab 的 0 值徽章仍可见');
  });

  testWidgets('歌曲视图 TrackTable 展示收藏并可搜索过滤', (tester) async {
    await _pump(
      tester,
      favorites: [
        _song('f1', '夜航'),
        _song('f2', '白昼', singer: '歌手乙'),
      ],
      withOthers: false,
    );

    expect(find.text('夜航'), findsOneWidget);
    expect(find.text('白昼'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '夜航');
    await tester.pump();
    // find.text 同时命中 EditableText 与行标题，用 findsWidgets。
    expect(find.text('夜航'), findsWidgets);
    expect(find.text('白昼'), findsNothing);
    expect(find.text('没有匹配的歌曲'), findsNothing);

    await tester.enterText(find.byType(TextField), '不存在的歌');
    await tester.pump();
    expect(find.text('没有匹配的歌曲'), findsOneWidget);
  });

  testWidgets('排序：按标题后行序改变', (tester) async {
    // 用 ASCII 标题避免中文字典序歧义（码点序 ≠ 拼音序）。
    await _pump(
      tester,
      favorites: [_song('f1', 'delta'), _song('f2', 'alpha')],
      withOthers: false,
    );

    // 默认序：delta 在前。
    expect(
      tester.getRect(find.text('delta')).top <
          tester.getRect(find.text('alpha')).top,
      isTrue,
    );

    await tester.tap(find.byTooltip('排序'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('按标题'));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('alpha')).top <
          tester.getRect(find.text('delta')).top,
      isTrue,
    );
  });

  testWidgets('专辑聚合视图：历史+本地的专辑成卡，本地专辑进预设详情', (tester) async {
    final model = await _pump(tester);
    await tester.tap(find.text('专辑'));
    await tester.pump();

    // 专辑壹（本地）与 专辑贰（kw 历史）各成一张卡。
    expect(find.byType(VxAlbumCard), findsNWidgets(2));

    // 本地音源不支持专辑详情命令 → 打开预设曲目页（不发生网络请求）。
    // VxCardShell 热区在封面（VxCoverFallback 占位），点「专辑壹」卡封面。
    final localCard = find.ancestor(
      of: find.text('专辑壹'),
      matching: find.byType(VxAlbumCard),
    );
    await tester.tap(
      find.descendant(of: localCard, matching: find.byType(VxCoverFallback)),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('曲目列表'), findsOneWidget);
    expect(find.text('本地一'), findsOneWidget);
    // 预设模式不建 browse 槽位（没有对无控制器的网络请求）。
    expect(model.browse('album_songs', 'local', '专辑壹'), isNull);
  });

  testWidgets('歌手聚合视图：收藏/历史歌手成卡并显示计数', (tester) async {
    final model = AppModel();
    model.debugSetSources([_caps()]);
    model.debugSetFavorites([_song('f1', '收藏一', singer: '歌手甲')]);
    model.debugSetHistory([_song('h1', '历史一', singer: '歌手乙')]);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LibraryPage(model))),
    );
    await tester.pump();

    await tester.tap(find.text('歌手'));
    await tester.pump();
    expect(find.text('歌手甲'), findsOneWidget);
    expect(find.text('歌手乙'), findsOneWidget);
  });

  testWidgets('三入口语义独立：最近播放独立页，本地音乐独立页', (tester) async {
    await _pump(tester);

    // 最近播放入口 → 独立页（含清空历史）。
    await tester.tap(find.text('最近播放'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('历史一'), findsOneWidget);
    expect(find.text('清空历史'), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    // 本地音乐入口 → 目录管理页。
    await tester.tap(find.text('本地音乐'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LocalMusicPage), findsOneWidget);
    expect(find.text('音乐目录'), findsOneWidget);
  });

  testWidgets('喜欢的歌曲入口切换到歌曲类别（与本地音乐语义分离）', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('喜欢的歌曲'));
    await tester.pump();

    // 歌曲视图是收藏表：本地歌曲不出现在里面（语义不混用）。
    expect(find.text('本地一'), findsNothing);
  });

  testWidgets('歌单类别聚合自建歌单与收藏歌单区块', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('歌单'));
    await tester.pumpAndSettle();

    expect(find.text('通勤'), findsOneWidget);
    expect(find.text('2 首 · 本地'), findsOneWidget);
    expect(find.textContaining('收藏歌单'), findsWidgets);
  });
}

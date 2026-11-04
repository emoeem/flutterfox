import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/custom_playlists_page.dart';
import 'package:voicefox_flutter/src/pages/library_page.dart';

const _summary = bridge.CustomPlaylistSummaryDto(
  id: 'c1',
  name: '通勤',
  coverUrl: null,
  songCount: 2,
);

bridge.SongDto _song(String id, String name) => bridge.SongDto(
  id: id,
  source: 'kw',
  name: name,
  singer: '歌手',
  albumName: '专辑',
  durationMs: BigInt.from(180000),
  coverUrl: null,
);

Future<void> _openSongMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('无自建歌单时展示空态与新建入口', (tester) async {
    final model = AppModel();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: CustomPlaylistsSection(model))),
    );

    expect(find.text('还没有自建歌单'), findsOneWidget);
    expect(find.text('新建歌单'), findsOneWidget);
  });

  testWidgets('列表展示歌单名称与曲目数', (tester) async {
    final model = AppModel();
    model.debugSetCustomPlaylists(const [_summary]);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: CustomPlaylistsSection(model))),
    );

    expect(find.text('通勤'), findsOneWidget);
    expect(find.text('2 首 · 本地'), findsOneWidget);
    expect(find.text('共 1 个歌单'), findsOneWidget);
  });

  testWidgets('歌单菜单提供重命名/删除', (tester) async {
    final model = AppModel();
    model.debugSetCustomPlaylists(const [_summary]);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: CustomPlaylistsSection(model))),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('详情页展示曲目、播放全部与移除入口', (tester) async {
    final model = AppModel();
    model.debugSetCustomPlaylists(const [_summary]);
    await tester.pumpWidget(
      MaterialApp(home: CustomPlaylistDetailPage(model, _summary)),
    );
    await tester.pump();

    expect(find.text('歌单加载中…'), findsOneWidget);

    model.debugBrowseLoaded(
      kind: 'custom_playlist',
      source: 'local',
      id: 'c1',
      songs: [_song('s1', '第一首'), _song('s2', '第二首')],
    );
    await tester.pump();

    expect(find.text('播放全部'), findsOneWidget);
    expect(find.text('1. 第一首'), findsOneWidget);
    expect(find.text('2. 第二首'), findsOneWidget);

    await _openSongMenu(tester);
    expect(find.text('从歌单移除'), findsOneWidget);
  });

  testWidgets('空歌单详情展示空态', (tester) async {
    final model = AppModel();
    model.debugSetCustomPlaylists(const [_summary]);
    await tester.pumpWidget(
      MaterialApp(home: CustomPlaylistDetailPage(model, _summary)),
    );
    model.debugBrowseLoaded(kind: 'custom_playlist', source: 'local', id: 'c1');
    await tester.pump();

    expect(find.text('歌单还没有歌曲'), findsOneWidget);
    expect(find.text('暂无可播放曲目'), findsOneWidget);
  });

  testWidgets('详情读取失败展示错误与重试', (tester) async {
    final model = AppModel();
    model.debugSetCustomPlaylists(const [_summary]);
    await tester.pumpWidget(
      MaterialApp(home: CustomPlaylistDetailPage(model, _summary)),
    );
    model.debugBrowseLoaded(
      kind: 'custom_playlist',
      source: 'local',
      id: 'c1',
      message: '自建歌单不存在或已被删除',
      failed: true,
    );
    await tester.pump();

    expect(find.text('歌单读取失败'), findsOneWidget);
    expect(find.text('自建歌单不存在或已被删除'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('曲库页提供自建歌单 tab 并可进入列表', (tester) async {
    final model = AppModel();
    model.debugSetCustomPlaylists(const [_summary]);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LibraryPage(model))),
    );

    expect(find.text('自建歌单 1'), findsOneWidget);
    await tester.tap(find.text('自建歌单 1'));
    await tester.pumpAndSettle();

    expect(find.text('通勤'), findsOneWidget);
    expect(find.text('2 首 · 本地'), findsOneWidget);
  });
}

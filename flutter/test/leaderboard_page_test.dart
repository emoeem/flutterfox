import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/leaderboard_page.dart';

bridge.SourceCapabilitiesDto _caps({
  String id = 'kw',
  bool leaderboard = true,
}) =>
    bridge.SourceCapabilitiesDto(
      id: id,
      name: id.toUpperCase(),
      playlists: true,
      playlistCategories: true,
      playlistSearch: true,
      album: true,
      artist: true,
      leaderboard: leaderboard,
      login: false,
      qrLogin: false,
    );

const _board = bridge.LeaderboardDto(
  id: 'b1',
  name: '飙升榜',
  source: 'kw',
  update: '每日更新',
);

bridge.SongDto _song(String name) => bridge.SongDto(
      id: 's1',
      source: 'kw',
      name: name,
      singer: '歌手',
      albumName: '专辑',
      durationMs: BigInt.from(180000),
      coverUrl: null,
    );

void main() {
  testWidgets('无支持音源时展示空态', (tester) async {
    final model = AppModel();
    model.debugSetSources([_caps(id: 'soda', leaderboard: false)]);
    await tester.pumpWidget(MaterialApp(home: LeaderboardPage(model)));
    await tester.pump();

    expect(find.text('没有支持排行榜的音源'), findsOneWidget);
  });

  testWidgets('榜单目录加载并进入榜内歌曲', (tester) async {
    final model = AppModel();
    model.debugSetSources([_caps()]);
    await tester.pumpWidget(MaterialApp(home: LeaderboardPage(model)));
    await tester.pump();

    expect(find.text('榜单加载中…'), findsOneWidget);

    model.debugBrowseLoaded(
      kind: 'leaderboard_boards',
      source: 'kw',
      id: '',
      boards: const [_board],
    );
    await tester.pump();
    expect(find.text('飙升榜'), findsOneWidget);

    await tester.tap(find.text('飙升榜'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    model.debugBrowseLoaded(
      kind: 'leaderboard_songs',
      source: 'kw',
      id: 'b1',
      songs: [_song('榜内歌曲')],
    );
    await tester.pump();
    expect(find.text('1. 榜内歌曲'), findsOneWidget);
    expect(find.text('播放全部'), findsOneWidget);
  });

  testWidgets('榜内歌曲覆盖加载/空/错误/不支持', (tester) async {
    final model = AppModel();
    await tester.pumpWidget(
      MaterialApp(home: LeaderboardSongsPage(model, 'kw', _board)),
    );
    await tester.pump();
    expect(find.text('加载中…'), findsOneWidget);

    model.debugBrowseLoaded(
      kind: 'leaderboard_songs',
      source: 'kw',
      id: 'b1',
    );
    await tester.pump();
    expect(find.text('榜单暂无歌曲'), findsOneWidget);

    model.debugBrowseLoaded(
      kind: 'leaderboard_songs',
      source: 'kw',
      id: 'b1',
      failed: true,
      message: '榜单不存在',
    );
    await tester.pump();
    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('榜单不存在'), findsOneWidget);

    model.debugBrowseLoaded(
      kind: 'leaderboard_songs',
      source: 'kw',
      id: 'b1',
      message: '该音源不支持排行榜',
    );
    await tester.pump();
    expect(find.text('该音源不支持排行榜'), findsOneWidget);
  });
}

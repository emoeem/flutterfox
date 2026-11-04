import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/playlist_browse_page.dart';

bridge.SourceCapabilitiesDto _caps(String id) => bridge.SourceCapabilitiesDto(
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

const _accountPlaylist = bridge.PlaylistDto(
  id: 'remote-1',
  name: '我喜欢的歌单',
  source: 'wy',
  coverUrl: null,
  songCount: 2,
  description: null,
);

bridge.SongDto _song() => bridge.SongDto(
  id: 's1',
  source: 'wy',
  name: '歌名',
  singer: '歌手',
  albumName: '专辑',
  durationMs: BigInt.from(180000),
  coverUrl: null,
);

void main() {
  testWidgets('镜像平台可切到「我的歌单」并展示同步入口', (tester) async {
    final model = AppModel();
    model.debugSetSources([_caps('wy')]);
    await tester.pumpWidget(MaterialApp(home: PlaylistBrowsePage(model)));
    await tester.pump();

    expect(find.text('我的歌单'), findsOneWidget);
    await tester.tap(find.text('我的歌单'));
    await tester.pump();

    expect(find.textContaining('镜像缓存'), findsOneWidget);
    expect(find.text('同步'), findsOneWidget);

    // 无控制器时加载事件不会到达：注入一次空结果验证空态文案。
    model.debugBrowseLoaded(kind: 'account_playlists', source: 'wy', id: '');
    await tester.pump();
    expect(find.text('还没有账号歌单'), findsOneWidget);
  });

  testWidgets('账号歌单列表可进入详情并读取缓存曲目', (tester) async {
    final model = AppModel();
    model.debugSetSources([_caps('wy')]);
    await tester.pumpWidget(MaterialApp(home: PlaylistBrowsePage(model)));
    await tester.pump();
    await tester.tap(find.text('我的歌单'));
    await tester.pump();

    model.debugBrowseLoaded(
      kind: 'account_playlists',
      source: 'wy',
      id: '',
      playlists: const [_accountPlaylist],
    );
    await tester.pump();

    expect(find.text('我喜欢的歌单'), findsOneWidget);
    await tester.tap(find.text('我喜欢的歌单'));
    await tester.pump();
    await tester.pump();

    // 详情页头部的账号镜像标记（证明走的是缓存详情命令）。
    expect(find.text('账号镜像'), findsOneWidget);

    model.debugBrowseLoaded(
      kind: 'account_playlist_detail',
      source: 'wy',
      id: 'remote-1',
      songs: [_song()],
    );
    await tester.pump();

    expect(find.text('1. 歌名'), findsOneWidget);
  });

  testWidgets('非镜像平台禁用「我的歌单」并说明原因', (tester) async {
    final model = AppModel();
    model.debugSetSources([_caps('kw')]);
    await tester.pumpWidget(MaterialApp(home: PlaylistBrowsePage(model)));
    await tester.pump();

    expect(find.text('账号歌单仅支持网易云 / QQ 音乐'), findsOneWidget);
  });
}

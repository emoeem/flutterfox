import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/design_system/components/vx_album_card.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_cover_fallback.dart';
import 'package:voicefox_flutter/src/pages/album_songs_page.dart';
import 'package:voicefox_flutter/src/pages/artist_detail_page.dart';

bridge.SourceCapabilitiesDto _caps({bool artist = true, bool album = true}) =>
    bridge.SourceCapabilitiesDto(
      id: 'kw',
      name: 'KW',
      playlists: true,
      playlistCategories: true,
      playlistSearch: true,
      album: album,
      artist: artist,
      leaderboard: true,
      login: false,
      qrLogin: false,
    );

const _artist = bridge.ArtistDto(
  id: '歌手',
  name: '歌手',
  source: 'kw',
  coverUrl: null,
);

const _album = bridge.AlbumDto(
  id: '专辑',
  name: '专辑',
  source: 'kw',
  coverUrl: null,
  artist: '歌手',
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
  testWidgets('歌手页热门歌曲串到专辑详情', (tester) async {
    final model = AppModel();
    model.debugSetSources([_caps()]);
    await tester.pumpWidget(
      MaterialApp(home: ArtistDetailPage(model, _artist)),
    );
    await tester.pump();

    model.debugBrowseLoaded(
      kind: 'artist_songs',
      source: 'kw',
      id: '歌手',
      songs: [_song('歌手歌曲')],
    );
    model.debugBrowseLoaded(
      kind: 'artist_albums',
      source: 'kw',
      id: '歌手',
      albums: const [_album],
    );
    await tester.pump();

    // 热门歌曲表 + 专辑网格（Phase 5：Banner + 热门歌曲 + 专辑）。
    expect(find.text('歌手歌曲'), findsOneWidget);
    expect(find.text('热门歌曲'), findsOneWidget);
    expect(find.text('专辑'), findsWidgets);

    // 专辑网格在热门歌曲下方，先滚到可见再点（VxCardShell 热区在封面）。
    await tester.scrollUntilVisible(
      find.byType(VxAlbumCard),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(VxAlbumCard),
        matching: find.byType(VxCoverFallback),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    model.debugBrowseLoaded(
      kind: 'album_songs',
      source: 'kw',
      id: '专辑',
      songs: [_song('专辑曲目')],
    );
    await tester.pump();
    expect(find.text('专辑曲目'), findsOneWidget);
    expect(find.text('播放全部'), findsOneWidget);
  });

  testWidgets('歌手页不支持时展示能力提示', (tester) async {
    final model = AppModel();
    model.debugSetSources([_caps(artist: false, album: false)]);
    await tester.pumpWidget(
      MaterialApp(home: ArtistDetailPage(model, _artist)),
    );
    await tester.pump();

    model.debugBrowseLoaded(
      kind: 'artist_songs',
      source: 'kw',
      id: '歌手',
      message: '该音源不支持歌手详情',
    );
    await tester.pump();
    expect(find.text('该音源不支持歌手详情'), findsOneWidget);
  });

  testWidgets('专辑页加载/空态', (tester) async {
    final model = AppModel();
    await tester.pumpWidget(MaterialApp(home: AlbumSongsPage(model, _album)));
    await tester.pump();
    expect(find.text('加载中…'), findsOneWidget);

    model.debugBrowseLoaded(kind: 'album_songs', source: 'kw', id: '专辑');
    await tester.pump();
    expect(find.text('专辑暂无曲目'), findsOneWidget);
    expect(find.text('暂无可播放曲目'), findsOneWidget);
  });

  testWidgets('专辑页加载失败展示错误态与重试', (tester) async {
    final model = AppModel();
    await tester.pumpWidget(MaterialApp(home: AlbumSongsPage(model, _album)));
    await tester.pump();
    expect(find.text('加载中…'), findsOneWidget);

    model.debugBrowseLoaded(
      kind: 'album_songs',
      source: 'kw',
      id: '专辑',
      message: '网络不可用',
      failed: true,
    );
    await tester.pump();

    // song_table_view.dart:165-177：错误 EmptyState + 重试按钮。
    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('网络不可用'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    // 重试 → _reload → loadAlbumSongs → 槽 loading：回到「加载中…」。
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(find.text('加载中…'), findsOneWidget);
    expect(find.text('加载失败'), findsNothing);
  });
}

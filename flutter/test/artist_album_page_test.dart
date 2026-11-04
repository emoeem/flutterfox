import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
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
  testWidgets('歌手页歌曲/专辑串到专辑曲目', (tester) async {
    final model = AppModel();
    model.debugSetSources([_caps()]);
    await tester.pumpWidget(MaterialApp(home: ArtistDetailPage(model, _artist)));
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

    expect(find.text('1. 歌手歌曲'), findsOneWidget);

    await tester.tap(find.text('专辑'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('专辑'), findsWidgets);

    await tester.tap(find.widgetWithText(ListTile, '专辑'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    model.debugBrowseLoaded(
      kind: 'album_songs',
      source: 'kw',
      id: '专辑',
      songs: [_song('专辑曲目')],
    );
    await tester.pump();
    expect(find.text('1. 专辑曲目'), findsOneWidget);
    expect(find.text('播放全部'), findsOneWidget);
  });

  testWidgets('歌手页不支持时展示能力提示', (tester) async {
    final model = AppModel();
    model.debugSetSources([_caps(artist: false, album: false)]);
    await tester.pumpWidget(MaterialApp(home: ArtistDetailPage(model, _artist)));
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

    model.debugBrowseLoaded(
      kind: 'album_songs',
      source: 'kw',
      id: '专辑',
    );
    await tester.pump();
    expect(find.text('专辑暂无曲目'), findsOneWidget);
    expect(find.text('暂无可播放曲目'), findsOneWidget);
  });
}

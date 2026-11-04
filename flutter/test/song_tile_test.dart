import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/song_tile.dart';

bridge.SourceCapabilitiesDto _caps() => const bridge.SourceCapabilitiesDto(
  id: 'kw',
  name: 'KW',
  playlists: true,
  playlistCategories: true,
  playlistSearch: true,
  album: true,
  artist: true,
  leaderboard: true,
  login: false,
  qrLogin: false,
);

bridge.SongDto _song({String? artistId, String? albumId}) => bridge.SongDto(
  id: 's1',
  source: 'kw',
  name: '歌曲',
  singer: '歌手',
  artistId: artistId,
  albumName: '专辑',
  albumId: albumId,
  durationMs: BigInt.from(180000),
  coverUrl: null,
);

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('查看歌手优先使用稳定 artistId', (tester) async {
    final model = AppModel();
    model.debugSetSources([_caps()]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SongTile(model, _song(artistId: 'artist-123'))),
      ),
    );

    await _openMenu(tester);
    await tester.tap(find.text('查看歌手'));
    await tester.pump();
    await tester.pump();

    expect(model.browse('artist_songs', 'kw', 'artist-123'), isNotNull);
  });

  testWidgets('artistId 缺失时回退到展示名', (tester) async {
    final model = AppModel();
    model.debugSetSources([_caps()]);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SongTile(model, _song()))),
    );

    await _openMenu(tester);
    await tester.tap(find.text('查看歌手'));
    await tester.pump();
    await tester.pump();

    expect(model.browse('artist_songs', 'kw', '歌手'), isNotNull);
    expect(model.browse('artist_songs', 'kw', 'artist-123'), isNull);
  });

  testWidgets('查看专辑优先使用稳定 albumId', (tester) async {
    final model = AppModel();
    model.debugSetSources([_caps()]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SongTile(model, _song(albumId: 'album-9'))),
      ),
    );

    await _openMenu(tester);
    await tester.tap(find.text('查看专辑'));
    await tester.pump();
    await tester.pump();

    expect(model.browse('album_songs', 'kw', 'album-9'), isNotNull);
  });

  testWidgets('albumId 缺失时回退到展示名', (tester) async {
    final model = AppModel();
    model.debugSetSources([_caps()]);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SongTile(model, _song()))),
    );

    await _openMenu(tester);
    await tester.tap(find.text('查看专辑'));
    await tester.pump();
    await tester.pump();

    expect(model.browse('album_songs', 'kw', '专辑'), isNotNull);
  });

  testWidgets('菜单「加入歌单」弹出选择器并列出已有歌单', (tester) async {
    final model = AppModel();
    model.debugSetCustomPlaylists(const [
      bridge.CustomPlaylistSummaryDto(
        id: 'c1',
        name: '通勤',
        coverUrl: null,
        songCount: 2,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SongTile(model, _song()))),
    );

    await _openMenu(tester);
    await tester.tap(find.text('加入歌单'));
    await tester.pumpAndSettle();

    expect(find.text('新建歌单…'), findsOneWidget);
    expect(find.text('通勤'), findsOneWidget);
    expect(find.text('2 首'), findsOneWidget);
  });
}

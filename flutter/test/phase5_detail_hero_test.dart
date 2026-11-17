/// Phase 5 详情页 Hero：专辑/歌手/歌单顶部信息区、长文本、缺封面、禁用项。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/design_system/components/vx_artist_banner.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_cover_fallback.dart';
import 'package:voicefox_flutter/src/pages/album_songs_page.dart';
import 'package:voicefox_flutter/src/pages/artist_detail_page.dart';
import 'package:voicefox_flutter/src/pages/playlist_detail_page.dart';

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

bridge.SongDto _song(String id, String name, {String album = '专辑'}) =>
    bridge.SongDto(
      id: id,
      source: 'kw',
      name: name,
      singer: '歌手',
      albumName: album,
      durationMs: BigInt.from(181000),
      coverUrl: null,
    );

void main() {
  group('专辑详情', () {
    testWidgets('DetailHero：标题/歌手/曲目数/总时长/音源徽章/主按钮', (tester) async {
      final model = AppModel();
      model.debugSetSources([_caps()]);
      const album = bridge.AlbumDto(
        id: 'a1',
        name: '夜航专辑',
        source: 'kw',
        coverUrl: null,
        artist: '歌手甲',
      );
      await tester.pumpWidget(MaterialApp(home: AlbumSongsPage(model, album)));
      await tester.pump();

      model.debugBrowseLoaded(
        kind: 'album_songs',
        source: 'kw',
        id: 'a1',
        songs: [_song('s1', '第一首'), _song('s2', '第二首')],
      );
      await tester.pump();

      // 返回栏 + Hero 各渲染一次标题。
      expect(find.text('夜航专辑'), findsNWidgets(2));
      expect(find.textContaining('歌手甲'), findsOneWidget);
      expect(find.textContaining('2 首'), findsOneWidget);
      // 2 × 3:01 ≈ 6 分钟。
      expect(find.textContaining('总时长 6 分钟'), findsOneWidget);
      expect(find.text('KW'), findsWidgets, reason: '音源徽章 + 行内音源列');
      final play = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('播放全部'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(play.onPressed, isNotNull);
    });

    testWidgets('缺封面用渐变首字母占位，不放灰色图标块', (tester) async {
      final model = AppModel();
      const album = bridge.AlbumDto(
        id: 'a1',
        name: '无封专辑',
        source: 'kw',
        coverUrl: null,
        artist: '歌手甲',
      );
      await tester.pumpWidget(MaterialApp(home: AlbumSongsPage(model, album)));
      await tester.pump();
      expect(find.byType(VxCoverFallback), findsWidgets);
      expect(find.byIcon(Icons.album_outlined), findsNothing);
    });

    testWidgets('长专辑名两行省略，不撑破布局', (tester) async {
      final model = AppModel();
      const longName = '一个非常非常非常非常非常非常非常非常非常非常非常非常非常长的专辑名称会在此处被省略';
      final album = bridge.AlbumDto(
        id: 'a1',
        name: longName,
        source: 'kw',
        coverUrl: null,
        artist: '歌手甲',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 640, child: AlbumSongsPage(model, album)),
          ),
        ),
      );
      await tester.pump();
      // Hero 标题（28px）文本 maxLines 2；返回栏标题为 1 行。
      final heroTitle = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.data == longName && w.maxLines == 2,
        ),
      );
      expect(heroTitle.overflow, TextOverflow.ellipsis);
    });
  });

  group('歌手详情', () {
    testWidgets('Banner：无照片用渐变背景，不显示破图；收藏歌手禁用并说明', (tester) async {
      final model = AppModel();
      model.debugSetSources([_caps()]);
      const artist = bridge.ArtistDto(
        id: '歌手甲',
        name: '歌手甲',
        source: 'kw',
        coverUrl: null,
      );
      await tester.pumpWidget(
        MaterialApp(home: ArtistDetailPage(model, artist)),
      );
      await tester.pump();

      model.debugBrowseLoaded(
        kind: 'artist_songs',
        source: 'kw',
        id: '歌手甲',
        songs: [_song('s1', '热门一')],
      );
      await tester.pump();

      expect(find.byType(VxArtistBanner), findsOneWidget);
      expect(find.byIcon(Icons.person), findsNothing, reason: '不用破图/灰人形占位');
      // Banner 上的歌手名。
      expect(find.text('歌手甲'), findsWidgets);

      // 收藏歌手禁用（后端无命令）。
      final favButton = tester.widget<OutlinedButton>(
        find
            .ancestor(
              of: find.text('收藏歌手'),
              matching: find.byType(OutlinedButton),
            )
            .first,
      );
      expect(favButton.onPressed, isNull);
    });

    testWidgets('热门歌曲与专辑网格分区呈现', (tester) async {
      final model = AppModel();
      model.debugSetSources([_caps()]);
      const artist = bridge.ArtistDto(
        id: '歌手甲',
        name: '歌手甲',
        source: 'kw',
        coverUrl: null,
      );
      await tester.pumpWidget(
        MaterialApp(home: ArtistDetailPage(model, artist)),
      );
      await tester.pump();
      model.debugBrowseLoaded(
        kind: 'artist_songs',
        source: 'kw',
        id: '歌手甲',
        songs: [_song('s1', '热门一')],
      );
      model.debugBrowseLoaded(
        kind: 'artist_albums',
        source: 'kw',
        id: '歌手甲',
        albums: const [
          bridge.AlbumDto(
            id: 'a1',
            name: '歌手专辑',
            source: 'kw',
            coverUrl: null,
            artist: '歌手甲',
          ),
        ],
      );
      await tester.pump();

      expect(find.text('热门歌曲'), findsOneWidget);
      expect(find.text('热门一'), findsOneWidget);
      expect(find.text('歌手专辑'), findsOneWidget);
    });
  });

  group('歌单详情', () {
    const playlist = bridge.PlaylistDto(
      id: 'p1',
      name: '测试歌单',
      source: 'kw',
      coverUrl: null,
      songCount: 12,
      description: '用于验收的描述',
    );

    testWidgets('账号歌单徽章与同步入口，公开歌单不显示同步', (tester) async {
      final model = AppModel();
      await tester.pumpWidget(
        MaterialApp(home: PlaylistDetailPage(model, playlist, account: true)),
      );
      model.debugBrowseLoaded(
        kind: 'account_playlist_detail',
        source: 'kw',
        id: 'p1',
        songs: [_song('s1', '歌一')],
      );
      await tester.pump();

      expect(find.text('账号歌单'), findsOneWidget, reason: 'eyebrow 区分账号/公开');
      expect(find.text('账号镜像'), findsOneWidget, reason: '徽章明确平台来源');
      expect(find.text('同步'), findsOneWidget);
      expect(find.textContaining('12 首'), findsOneWidget);
      expect(find.textContaining('已载入 1'), findsOneWidget);
    });

    testWidgets('公开歌单：eyebrow 为歌单、无同步入口、描述可见', (tester) async {
      final model = AppModel();
      await tester.pumpWidget(
        MaterialApp(home: PlaylistDetailPage(model, playlist)),
      );
      model.debugBrowseLoaded(
        kind: 'playlist_detail',
        source: 'kw',
        id: 'p1',
        songs: [_song('s1', '歌一')],
      );
      await tester.pump();

      expect(find.text('歌单'), findsOneWidget);
      expect(find.text('账号镜像'), findsNothing);
      expect(find.text('同步'), findsNothing);
      expect(find.text('用于验收的描述'), findsOneWidget);
      // 收藏按钮（命令存在）可用。
      final fav = tester.widget<OutlinedButton>(
        find
            .ancestor(
              of: find.text('收藏'),
              matching: find.byType(OutlinedButton),
            )
            .first,
      );
      expect(fav.onPressed, isNotNull);
    });
  });
}

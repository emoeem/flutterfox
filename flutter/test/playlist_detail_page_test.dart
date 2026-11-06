import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/playlist_detail_page.dart';

const _playlist = bridge.PlaylistDto(
  id: 'p1',
  name: '测试歌单',
  source: 'kw',
  coverUrl: null,
  songCount: 2,
  description: '用于 widget test',
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

void main() {
  testWidgets('加载中 → 加载完成显示曲目与播放全部', (tester) async {
    final model = AppModel();
    await tester.pumpWidget(
      MaterialApp(home: PlaylistDetailPage(model, _playlist)),
    );
    await tester.pump();

    expect(find.text('加载中…'), findsOneWidget);

    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', '第一首'), _song('s2', '第二首')],
      hasMore: false,
    );
    await tester.pump();

    expect(find.text('播放全部'), findsOneWidget);
    // VxSongTable：序号独立列，行文本不再带 'N. ' 前缀。
    expect(find.text('第一首'), findsOneWidget);
    expect(find.text('第二首'), findsOneWidget);
    // Hero 元信息：曲目数与总时长（2×3:00 = 6 分钟）。
    expect(find.text('2 首 · 总时长 6 分钟'), findsOneWidget);
  });

  testWidgets('空歌单展示空态', (tester) async {
    final model = AppModel();
    await tester.pumpWidget(
      MaterialApp(home: PlaylistDetailPage(model, _playlist)),
    );
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
    );
    await tester.pump();

    expect(find.text('歌单暂无曲目'), findsOneWidget);
    expect(find.text('暂无可播放曲目'), findsOneWidget);
  });

  testWidgets('音源不支持时展示能力提示而非错误', (tester) async {
    final model = AppModel();
    await tester.pumpWidget(
      MaterialApp(home: PlaylistDetailPage(model, _playlist)),
    );
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      message: '该音源不支持歌单详情',
    );
    await tester.pump();

    expect(find.text('该音源不支持歌单详情'), findsOneWidget);
  });

  testWidgets('请求失败展示错误态与重试', (tester) async {
    final model = AppModel();
    await tester.pumpWidget(
      MaterialApp(home: PlaylistDetailPage(model, _playlist)),
    );
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      message: '网络不可用',
      failed: true,
    );
    await tester.pump();

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('网络不可用'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}

/// 歌单详情数据隔离测试（指南 §8.1 / §12.3 PlaylistDetailIsolationTest）。
///
/// 覆盖 §8.1 测试序列的 widget 层映射：
/// - 不同歌单（A/B）槽位隔离，B 不显示 A 的曲目；
/// - 相同 ID 不同 source 隔离；
/// - 公开歌单 vs 账号歌单（同 ID）隔离；
/// - 迟到的 append 响应不得混入重载后的列表（过期响应丢弃）；
/// - 重复/乱序分页响应不重复合并；顺序分页正常追加；
/// - 错误归属正确歌单槽，不串槽；
/// - 返回已打开过的歌单：首帧显示加载态，不闪现旧曲目。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/playlist_detail_page.dart';

bridge.PlaylistDto _playlist(String id, String source) => bridge.PlaylistDto(
  id: id,
  name: '歌单$source$id',
  source: source,
  coverUrl: null,
  songCount: 2,
);

bridge.SongDto _song(String id, String name, String source) => bridge.SongDto(
  id: id,
  source: source,
  name: name,
  singer: '歌手',
  albumName: '专辑',
  durationMs: BigInt.from(180000),
  coverUrl: null,
);

Future<void> _pumpDetail(
  WidgetTester tester,
  AppModel model,
  bridge.PlaylistDto playlist, {
  bool account = false,
}) async {
  tester.view.physicalSize = const Size(1280, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: PlaylistDetailPage(model, playlist, account: account)),
  );
  await tester.pump();
}

void main() {
  testWidgets('A/B 歌单槽位隔离：B 不显示 A 的曲目，A 响应不覆盖 B', (tester) async {
    final model = AppModel();
    final playlistA = _playlist('p1', 'kw');
    final playlistB = _playlist('p2', 'kw');

    await _pumpDetail(tester, model, playlistA);
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', 'A的第一首', 'kw')],
    );
    await tester.pump();
    expect(find.text('A的第一首'), findsOneWidget);

    // 打开歌单 B（新页面实例，独立槽位）：B 不显示 A 的曲目。
    await _pumpDetail(tester, model, playlistB);
    // B 未加载数据前是加载态（不闪现 A 的歌曲）。
    expect(find.text('A的第一首'), findsNothing);
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p2',
      songs: [_song('s2', 'B的第一首', 'kw')],
    );
    await tester.pump();
    expect(find.text('B的第一首'), findsOneWidget);
    expect(find.text('A的第一首'), findsNothing);

    // A 的槽位数据独立存活（模拟返回 A）。
    expect(
      model.browse('playlist_detail', 'kw', 'p1')!.songs.first.name,
      'A的第一首',
    );
    expect(
      model.browse('playlist_detail', 'kw', 'p2')!.songs.first.name,
      'B的第一首',
    );
  });

  testWidgets('相同 ID 不同 source：缓存隔离互不污染', (tester) async {
    final model = AppModel();
    // kw 槽先装载数据（随后 pump wy 页面只重载 wy 槽，kw 槽不受影响）。
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: '123',
      songs: [_song('s1', '酷我123', 'kw')],
    );
    await _pumpDetail(tester, model, _playlist('123', 'wy'));
    expect(find.text('酷我123'), findsNothing, reason: 'wy 页面不读 kw 槽');
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'wy',
      id: '123',
      songs: [_song('s2', '网易云123', 'wy')],
    );
    await tester.pump();
    expect(find.text('网易云123'), findsOneWidget);
    expect(
      model.browse('playlist_detail', 'kw', '123')!.songs.first.name,
      '酷我123',
    );
    expect(
      model.browse('playlist_detail', 'wy', '123')!.songs.first.name,
      '网易云123',
    );
  });

  testWidgets('公开歌单与账号歌单同 ID：kind 命名空间隔离', (tester) async {
    final model = AppModel();
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'wy',
      id: '900',
      songs: [_song('s1', '公开歌单曲目', 'wy')],
    );
    await _pumpDetail(tester, model, _playlist('900', 'wy'), account: true);
    // 账号页读 account_playlist_detail 槽，不读公开歌单槽。
    expect(find.text('公开歌单曲目'), findsNothing);
    model.debugBrowseLoaded(
      kind: 'account_playlist_detail',
      source: 'wy',
      id: '900',
      songs: [_song('s2', '账号镜像曲目', 'wy')],
    );
    await tester.pump();
    expect(find.text('账号镜像曲目'), findsOneWidget);
    expect(
      model.browse('playlist_detail', 'wy', '900')!.songs.first.name,
      '公开歌单曲目',
    );
  });

  testWidgets('过期 append 响应丢弃：页 2 在途时刷新，旧页 2 不得混入新列表', (tester) async {
    final model = AppModel();
    // 首次加载 page1（arm 分页）。
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', '第一页', 'kw')],
    );
    expect(model.browse('playlist_detail', 'kw', 'p1')!.page, 1);

    // 用户点刷新：清空列表并撤销 arm。
    model.debugBeginBrowse(kind: 'playlist_detail', source: 'kw', id: 'p1');
    final slot = model.browse('playlist_detail', 'kw', 'p1')!;
    expect(slot.songs, isEmpty, reason: '刷新后先清空旧曲目');
    expect(slot.appendArmed, isFalse, reason: '新代次未收到 page1 响应前不 arm');

    // 迟到的旧页 2 响应：必须被丢弃。
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s2', '旧页2迟到曲', 'kw')],
      page: 2,
      hasMore: true,
    );
    expect(
      slot.songs.where((s) => s.name == '旧页2迟到曲'),
      isEmpty,
      reason: '§8.1 过期响应不能覆盖当前页面',
    );
    expect(slot.loading, isTrue, reason: '刷新仍在途');

    // 本代次 page1 响应到达（重新 arm）→ 正常追加新页 2。
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s3', '新第一页', 'kw')],
    );
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s4', '新第二页', 'kw')],
      page: 2,
      hasMore: false,
    );
    expect(slot.songs.map((s) => s.name), ['新第一页', '新第二页']);
  });

  testWidgets('重复页响应丢弃 + 顺序分页正常追加', (tester) async {
    final model = AppModel();
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', '页1', 'kw')],
    );
    final slot = model.browse('playlist_detail', 'kw', 'p1')!;

    // 正常顺序分页：2 → 3。
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s2', '页2', 'kw')],
      page: 2,
    );
    expect(slot.songs.length, 2);

    // 同页重复响应：丢弃（不重复合并）。
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s2-dup', '页2重复', 'kw')],
      page: 2,
    );
    expect(slot.songs.length, 2, reason: '重复的页 2 响应不得二次合并');

    // 乱序（跳页 4）：丢弃，不产生空洞。
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s4', '页4', 'kw')],
      page: 4,
    );
    expect(slot.songs.length, 2);

    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s3', '页3', 'kw')],
      page: 3,
    );
    expect(slot.songs.map((s) => s.name).toList(), ['页1', '页2', '页3']);
  });

  testWidgets('错误归属正确歌单槽：B 失败不影响 A 的数据展示', (tester) async {
    final model = AppModel();
    await _pumpDetail(tester, model, _playlist('p1', 'kw'));
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', 'A曲', 'kw')],
    );
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p2',
      songs: [],
      failed: true,
      message: '歌单不存在',
    );
    await tester.pump();
    expect(find.text('A曲'), findsOneWidget, reason: 'A 槽不受 B 失败影响');
    expect(model.browse('playlist_detail', 'kw', 'p2')!.error, '歌单不存在');
    expect(model.browse('playlist_detail', 'kw', 'p1')!.error, isNull);
  });

  testWidgets('返回已打开过的歌单：首帧加载态，不闪现旧曲目', (tester) async {
    final model = AppModel();
    // 预置上一次访问遗留的槽数据。
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', '上次访问的曲目', 'kw')],
    );
    // 重新进入同一歌单（新页面实例）。
    await _pumpDetail(tester, model, _playlist('p1', 'kw'));
    // initState 已同步 _reload → 清槽 + loading；首帧不得渲染旧曲目。
    expect(find.text('上次访问的曲目'), findsNothing);
    expect(find.text('加载中…'), findsOneWidget);
  });
}

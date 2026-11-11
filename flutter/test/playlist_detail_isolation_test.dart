/// 歌单详情数据隔离测试（指南 §8.1 / §12.3 PlaylistDetailIsolationTest）。
///
/// 覆盖 §8.1 测试序列的 widget 层映射：
/// - 不同歌单（A/B）槽位隔离，B 不显示 A 的曲目；
/// - 相同 ID 不同 source 隔离；
/// - 公开歌单 vs 账号歌单（同 ID）隔离；
/// - 迟到的 append 响应不得混入重载后的列表（过期响应丢弃）；
/// - A 触底分页在途时切到 B：迟到页 2 只落 A 槽（§8.1 序列 7）；
/// - 重复/乱序分页响应不重复合并；顺序分页正常追加；
/// - 错误归属正确歌单槽，不串槽；
/// - 返回已打开过的歌单：首帧显示加载态，不闪现旧曲目。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/playlist_detail_page.dart';

/// 记录派发命令的测试模型（不起 Rust 控制器）。Phase 3 起页面收藏与
/// 下拉刷新走 dispatchWithError（公开的错误返回变体），故覆写它而非
/// dispatch；[errorToReturn] 模拟命令级失败。
class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];
  String? errorToReturn;

  @override
  Future<String?> dispatchWithError(bridge.FfiCommand command) async {
    commands.add(command);
    return errorToReturn;
  }
}

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

/// 分步下拉手势：`tester.drag` 单步大位移不会生成足够的手势事件序列，
/// RefreshIndicator 不会 arm（实测诊断）；分步 move + up 稳定触发。
/// 总拖距 600px：arm 阈值 = 0.25 × 列表视口高（~1200px 测试视口）。
/// up 后再泵 ≥400ms：onRefresh 在 snap 动画（~150ms）结束后才被调用。
Future<void> _pullToRefresh(WidgetTester tester, Finder target) async {
  final center = tester.getCenter(target);
  final gesture = await tester.startGesture(center);
  await gesture.moveBy(const Offset(0, 150));
  await tester.pump();
  await gesture.moveBy(const Offset(0, 450));
  await tester.pump();
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 400));
}

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
    // Key：模拟真实导航「每次打开新开一个页面实例」——同类型页面重泵走
    // element update 会复用 State 跳过 initState（prepareBrowseLoad 不跑），
    // 与 §8.1「切到另一个歌单先显示 loading」的语义不符。
    MaterialApp(
      home: PlaylistDetailPage(
        model,
        playlist,
        account: account,
        key: ValueKey('${playlist.source}/${playlist.id}/$account'),
      ),
    ),
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

  testWidgets('A 触底分页在途时切到 B：A 的迟到页 2 只落 A 槽，不污染 B', (tester) async {
    // §8.1 测试序列 7：对 A 触底加载下一页，再快速切到 B，分页不串数据。
    final model = AppModel();
    final playlistA = _playlist('p1', 'kw');
    final playlistB = _playlist('p2', 'kw');

    await _pumpDetail(tester, model, playlistA);
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', 'A页1', 'kw')],
    );
    await tester.pump();
    expect(find.text('A页1'), findsOneWidget);

    // A 触底：派发页 2 append 请求（响应未到，槽标记加载中）。
    model.debugBeginBrowse(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      append: true,
    );
    expect(model.browse('playlist_detail', 'kw', 'p1')!.loading, isTrue);

    // 快速切到 B：B 页面 initState 同步预清自己的槽。
    await _pumpDetail(tester, model, playlistB);
    expect(find.text('A页1'), findsNothing, reason: 'B 页面不读 A 槽');

    // A 的迟到页 2 响应此时才到达：只允许落 A 槽。
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s2', 'A页2', 'kw')],
      page: 2,
      hasMore: false,
    );
    expect(
      model.browse('playlist_detail', 'kw', 'p1')!.songs.map((s) => s.name),
      ['A页1', 'A页2'],
      reason: 'A 槽分页正常追加',
    );
    final slotB = model.browse('playlist_detail', 'kw', 'p2')!;
    expect(
      slotB.songs.where((s) => s.name == 'A页2'),
      isEmpty,
      reason: 'B 槽不受 A 的迟到分页影响',
    );
    expect(slotB.loading, isTrue, reason: 'B 自己的首屏请求仍在途');
    expect(slotB.error, isNull);
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

  testWidgets('P1-11 回归：浏览错误/notice 消息源头净化，原始 URL 不落槽不直出', (tester) async {
    // §9/P1-11（QA 2026-11-11 第 2 轮）：_applyBrowseEvent 把 event.message
    // 原样写入 result.error/notice，被发现页/歌单页错误框直出。修复后错误
    // 与 notice 均在源头过 sanitizeUserFacingMessage（错误另写 stderr）。
    final model = AppModel();
    const rawMessage =
        'network error: error sending request for url '
        '(http://wapi.kuwo.cn/api/pc/classify/playlist/getRomPlayList?loginUid=0&fmt=json)';

    await _pumpDetail(tester, model, _playlist('p1', 'kw'));
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      failed: true,
      message: rawMessage,
    );
    await tester.pump();

    final slot = model.browse('playlist_detail', 'kw', 'p1')!;
    expect(slot.error, isNotNull);
    expect(slot.error, contains('[URL]'), reason: 'URL 打码后落槽');
    expect(slot.error, isNot(contains('http')), reason: '原始 URL 不得落入用户可见槽');
    expect(
      find.textContaining('wapi.kuwo.cn'),
      findsNothing,
      reason: '页面错误框（VxErrorState detail）不得直出原始 URL',
    );

    // 成功响应携带的 notice 同口径净化（空态标题直出）。
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p2',
      message: '服务端提示: see http://wapi.kuwo.cn/help?uid=1',
    );
    expect(
      model.browse('playlist_detail', 'kw', 'p2')!.notice,
      contains('[URL]'),
      reason: 'notice 与 error 同一净化口径',
    );
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

  testWidgets('下拉刷新：清槽重置 page1、迟到旧页 2 被弃、page1 落槽后 spinner 收起', (tester) async {
    final model = _RecordingModel();
    await _pumpDetail(tester, model, _playlist('p1', 'kw'));
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', '第一页', 'kw')],
    );
    await tester.pump();
    expect(find.text('第一页'), findsOneWidget);

    // 下拉手势触发 RefreshIndicator.onRefresh：load* 内部 _beginBrowse
    // 清槽 + 撤 arm（与 debugBeginBrowse 序列同语义）。
    await _pullToRefresh(tester, find.text('第一页'));
    final slot = model.browse('playlist_detail', 'kw', 'p1')!;
    expect(slot.songs, isEmpty, reason: '下拉刷新先清空旧曲目');
    expect(slot.appendArmed, isFalse, reason: '新代次未收到 page1 前不 arm');
    expect(
      model.commands.whereType<bridge.FfiCommand_PlaylistDetail>().last.page,
      1,
      reason: '下拉刷新重置为 page1',
    );

    // 迟到的旧页 2：必须被丢弃（§8.1 过期响应不得混入）。
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s2', '旧页2迟到曲', 'kw')],
      page: 2,
      hasMore: true,
    );
    expect(slot.songs.where((s) => s.name == '旧页2迟到曲'), isEmpty);
    expect(slot.loading, isTrue, reason: '刷新仍在途');

    // 本代次 page1 响应落槽 → 完成等待者送达 → spinner 收起（§9 不允许
    // 假刷新或永久 spinner）、新数据渲染。
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s3', '刷新后第一页', 'kw')],
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('刷新后第一页'), findsOneWidget);
    expect(slot.page, 1);
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: '刷新完成 Future 送达后 RefreshIndicator 指示器收起',
    );
  });

  testWidgets('收藏 pending：双击在途忽略第二次；成功确认走真实 favoritePlaylists 快照', (
    tester,
  ) async {
    // 成功确认链（核对后修正）：FavoritePlaylistAdd → Rust publish_library
    // → FFI kind="library" → _refreshState 刷新 favoritePlaylists；页面以
    // 真实快照与乐观值一致为确认判据，不监听不存在的 'playlist' 事件。
    final model = _RecordingModel();
    await _pumpDetail(tester, model, _playlist('p1', 'kw'));
    final favButton = find.byTooltip('收藏到本地歌单收藏夹（不写入远端账号）');
    expect(find.text('收藏'), findsOneWidget);

    // 第一次点击：pending + 乐观翻转（图标变实心）。
    await tester.tap(favButton);
    await tester.pump();
    expect(find.text('收藏处理中…'), findsOneWidget);
    expect(
      model.commands.whereType<bridge.FfiCommand_FavoritePlaylistAdd>(),
      hasLength(1),
    );
    expect(find.byIcon(Icons.favorite), findsOneWidget, reason: '乐观翻转图标');

    // pending 在途：第二次点击忽略——不派发反向 remove（双击竞态，
    // 否则 add 在途紧跟 remove，确认后状态与用户意图相反）。
    await tester.tap(favButton);
    await tester.pump();
    expect(
      model.commands.whereType<bridge.FfiCommand_FavoritePlaylistRemove>(),
      isEmpty,
      reason: 'pending 在途忽略再次点击',
    );

    // 模拟 'library' 事件后的快照刷新：与乐观值一致 → pending 清除、
    // 图标保持实心、标签「取消收藏」。无超时假成功。不用 pumpAndSettle：
    // 页面首屏 loading 态的 spinner 永转（本测试无 browse 响应）。
    model.debugSetFavoritePlaylists([_playlist('p1', 'kw')]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('收藏处理中…'), findsNothing);
    expect(find.text('取消收藏'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('收藏失败回滚：乐观图标还原、pending 清除、可再次点击', (tester) async {
    final model = _RecordingModel();
    model.errorToReturn = '收藏失败';
    await _pumpDetail(tester, model, _playlist('p1', 'kw'));
    final favButton = find.byTooltip('收藏到本地歌单收藏夹（不写入远端账号）');

    await tester.tap(favButton);
    await tester.pump();
    expect(
      model.commands.whereType<bridge.FfiCommand_FavoritePlaylistAdd>(),
      hasLength(1),
    );

    // 命令失败返回（§9 操作失败必须回滚乐观 UI）：pending 清除、图标
    // 还原空心（错误路径在微任务即返回，pending 瞬态不可见；在途可见性
    // 由「收藏 pending」用例的成功确认路径覆盖）。错误文案只经命令层
    // lastError → 全局 toast 一处呈现，页面不渲染第二份（P1-07 同口径）。
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('收藏处理中…'), findsNothing);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    // 回滚后 pending 已清：可再次发起。
    model.errorToReturn = null;
    await tester.tap(favButton);
    await tester.pump();
    expect(
      model.commands.whereType<bridge.FfiCommand_FavoritePlaylistAdd>(),
      hasLength(2),
    );
  });

  testWidgets('账号歌单触底不分页（无分页语义回归）', (tester) async {
    final model = _RecordingModel();
    await _pumpDetail(tester, model, _playlist('900', 'wy'), account: true);
    model.debugBrowseLoaded(
      kind: 'account_playlist_detail',
      source: 'wy',
      id: '900',
      songs: [for (var i = 1; i <= 60; i++) _song('$i', '账号曲$i', 'wy')],
    );
    await tester.pump();
    expect(find.text('账号曲1'), findsOneWidget);

    await tester.drag(find.text('账号曲1'), const Offset(0, -4000));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      model.commands.whereType<bridge.FfiCommand_AccountPlaylistDetail>(),
      hasLength(1),
      reason: '账号歌单镜像无分页：触底不派发第二次详情命令',
    );
  });
}

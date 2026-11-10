/// 搜索分页正确性测试（指南 §12.3 SearchPaginationTest / §5.4 / §8.1 语义）。
///
/// 覆盖：loadMore 请求携带当前筛选 source（P1-04 回归）、多选聚合时
/// loadMore 为聚合、in-flight 锁下触底不重复派发、过期（旧 requestId）
/// 响应不覆盖新查询、页 2 响应只追加不重建列表。
///
/// 与 search_page_test.dart 的分工：那边覆盖防抖/选择/三态 UI；本文件
/// 聚焦「分页请求上下文一致性 + 过期响应丢弃」的数据正确性。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/search_page.dart';

/// 记录派发命令的测试模型（不起 Rust 控制器）。
class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];

  @override
  Future<void> dispatch(bridge.FfiCommand command) async {
    commands.add(command);
  }
}

bridge.SongDto _song(String id, String name, String source) => bridge.SongDto(
  id: id,
  source: source,
  name: name,
  singer: '歌手',
  albumName: '专辑',
  durationMs: BigInt.from(180000),
  coverUrl: null,
);

bridge.SearchDto _searchState({
  required String keyword,
  List<bridge.SongDto> items = const [],
  int page = 0,
  bool hasMore = false,
  required BigInt requestId,
  bool loading = false,
  String? error,
}) => bridge.SearchDto(
  keyword: keyword,
  page: page,
  hasMore: hasMore,
  items: items,
  requestId: requestId,
  loading: loading,
  error: error,
);

bridge.SourceCapabilitiesDto _caps(String id, String name) =>
    bridge.SourceCapabilitiesDto(
      id: id,
      name: name,
      playlists: false,
      playlistCategories: false,
      playlistSearch: false,
      album: false,
      artist: false,
      leaderboard: false,
      login: false,
      qrLogin: false,
    );

Future<void> _pumpSearch(
  WidgetTester tester,
  AppModel model, {
  String seedKeyword = 'love',
}) async {
  tester.view.physicalSize = const Size(1280, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SearchPage(model, seedKeyword: seedKeyword)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 30));
}

/// 打开音源筛选弹层并勾选 [sourceId]（onSelected 后页面会重搜）。
Future<void> _selectSource(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('按音源筛选结果'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pump(const Duration(milliseconds: 30));
}

void main() {
  testWidgets('loadMore 携带当前单选筛选 source（P1-04：第 2 页起不回落聚合）', (tester) async {
    final model = _RecordingModel();
    model.debugSetSources([_caps('kw', '酷狗'), _caps('wy', '网易云')]);
    await _pumpSearch(tester, model);

    // 选择酷狗 → 页面重搜（Search 带 source）。
    await _selectSource(tester, '酷狗');
    // seed 搜索（initState）+ 选源重搜两次 Search；断言最近一次带 source。
    expect(
      model.commands.whereType<bridge.FfiCommand_Search>().last.source,
      'kw',
      reason: '首页请求携带音源过滤',
    );

    // 构造首页响应（hasMore）→ 触底分页。
    model.debugSetSearch(
      _searchState(
        keyword: 'love',
        page: 1,
        hasMore: true,
        requestId: BigInt.one,
        items: [for (var i = 1; i <= 60; i++) _song('$i', '歌$i', 'kw')],
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pump(const Duration(milliseconds: 100));

    final mores = model.commands.whereType<bridge.FfiCommand_SearchMore>();
    expect(mores, hasLength(1));
    expect(mores.single.source, 'kw', reason: '分页请求必须与首页同一查询上下文（P1-04 修复）');
  });

  testWidgets('多选聚合时 loadMore 为聚合（source=null），不回落旧筛选', (tester) async {
    final model = _RecordingModel();
    model.debugSetSources([_caps('kw', '酷狗'), _caps('wy', '网易云')]);
    await _pumpSearch(tester, model);

    // 选两个源 → 聚合搜索（source=null）。
    await _selectSource(tester, '酷狗');
    await _selectSource(tester, '网易云');
    final searches = model.commands.whereType<bridge.FfiCommand_Search>();
    expect(searches.last.source, isNull, reason: '多选 = 聚合搜索');

    model.debugSetSearch(
      _searchState(
        keyword: 'love',
        page: 1,
        hasMore: true,
        requestId: BigInt.from(9),
        items: [
          for (var i = 1; i <= 60; i++)
            _song('$i', '歌$i', i.isEven ? 'kw' : 'wy'),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pump(const Duration(milliseconds: 100));

    final mores = model.commands.whereType<bridge.FfiCommand_SearchMore>();
    expect(mores, hasLength(1));
    expect(mores.single.source, isNull, reason: '聚合分页保持聚合');
  });

  testWidgets('in-flight 锁：触底多次只派发一次；响应到达后允许下一页', (tester) async {
    final model = _RecordingModel();
    model.debugSetSources([_caps('kw', '酷狗')]);
    await _pumpSearch(tester, model);

    model.debugSetSearch(
      _searchState(
        keyword: 'love',
        page: 1,
        hasMore: true,
        requestId: BigInt.one,
        items: [for (var i = 1; i <= 60; i++) _song('$i', '歌$i', 'kw')],
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      model.commands.whereType<bridge.FfiCommand_SearchMore>(),
      hasLength(1),
      reason: '触底不重复发请求（§5.4 分页 in-flight 锁）',
    );
  });

  testWidgets('新查询（requestId 变化）释放分页锁并重置上下文', (tester) async {
    final model = _RecordingModel();
    model.debugSetSources([_caps('kw', '酷狗')]);
    await _pumpSearch(tester, model);

    model.debugSetSearch(
      _searchState(
        keyword: 'love',
        page: 1,
        hasMore: true,
        requestId: BigInt.one,
        items: [for (var i = 1; i <= 60; i++) _song('$i', '歌$i', 'kw')],
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      model.commands.whereType<bridge.FfiCommand_SearchMore>(),
      hasLength(1),
    );

    // 第 2 页响应到达（requestId 2）→ 锁释放，允许请求 page 3。
    model.debugSetSearch(
      _searchState(
        keyword: 'love',
        page: 2,
        hasMore: true,
        requestId: BigInt.two,
        items: [for (var i = 1; i <= 120; i++) _song('$i', '歌$i', 'kw')],
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    final mores = model.commands.whereType<bridge.FfiCommand_SearchMore>();
    expect(mores.last.page, 3, reason: '响应到达后锁释放续载下一页');
    expect(mores.last.keyword, 'love', reason: '分页请求延续同一关键词');
  });

  testWidgets('新查询后旧查询的过期快照（requestId 回退）不覆盖当前结果', (tester) async {
    // §8.1「过期响应不能覆盖当前页面」的页面级串联：loadMore 在途时用户
    // 发起新查询，旧查询的迟到快照（requestId 回退）不得把旧结果刷回树。
    // 正常链路由 Rust 按序广播 + start_search append 守卫拦截；本用例锁定
    // Dart 层兜底守卫（search_page._onModelChanged 的 requestId 回退检查）。
    final model = _RecordingModel();
    model.debugSetSources([_caps('kw', '酷狗')]);
    await _pumpSearch(tester, model);

    // 旧查询 'love' 首屏。
    model.debugSetSearch(
      _searchState(
        keyword: 'love',
        page: 1,
        hasMore: true,
        requestId: BigInt.one,
        items: [_song('s1', '旧查询一', 'kw')],
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));
    expect(find.text('旧查询一'), findsOneWidget);

    // 新查询 'rock' 响应到达（requestId 2）→ 页面切到新结果。
    model.debugSetSearch(
      _searchState(
        keyword: 'rock',
        page: 1,
        hasMore: false,
        requestId: BigInt.two,
        items: [_song('r1', '新查询一', 'kw')],
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));
    expect(find.text('新查询一'), findsOneWidget);

    // 迟到的旧查询快照（requestId 回退到 1，携带旧查询 page2 数据）：
    // 必须被忽略，不把旧结果刷回树。
    model.debugSetSearch(
      _searchState(
        keyword: 'love',
        page: 2,
        hasMore: true,
        requestId: BigInt.one,
        items: [_song('s1', '旧查询一', 'kw'), _song('s2', '旧查询迟到曲', 'kw')],
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));
    expect(
      find.text('旧查询迟到曲'),
      findsNothing,
      reason: '§8.1 过期响应（requestId 回退）不得覆盖当前页面',
    );
    expect(find.text('新查询一'), findsOneWidget, reason: '新查询结果保持展示');
  });
}

/// Phase 4 搜索页测试：
/// - 300ms 防抖（输入后立即无派发、300ms 后一次派发）；
/// - seedKeyword 构造即搜索（Shell Ctrl+K 通道）；
/// - 行交互：单击选中、Ctrl 切换多选、Shift 范围多选、Enter 播放选中项、
///   双击播放；
/// - 分页 in-flight 锁 + 加载中 / 没有更多 / 失败重试三态；
/// - 音源多选筛选（单源走后端过滤、多选聚合）；
/// - 专辑 / 歌手 Tab 真实聚合、歌单 Tab 如实解释。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/design_system/components/vx_artwork.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_cover_fallback.dart';
import 'package:voicefox_flutter/src/pages/search_page.dart';

/// 记录派发命令的测试模型（不起 Rust 控制器）。
class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];

  @override
  Future<void> dispatch(bridge.FfiCommand command) async {
    commands.add(command);
  }
}

bridge.SongDto _song(
  String id,
  String name, {
  String singer = '歌手A',
  String album = '专辑A',
  String source = 'wy',
  String? artistId,
  String? albumId,
  int durationMs = 180000,
}) => bridge.SongDto(
  id: id,
  source: source,
  name: name,
  singer: singer,
  artistId: artistId,
  albumName: album,
  albumId: albumId,
  durationMs: BigInt.from(durationMs),
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

Future<void> _pumpSearch(
  WidgetTester tester,
  AppModel model, {
  String seedKeyword = '',
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

void main() {
  testWidgets('防抖 300ms：输入后立即不派发，300ms 后恰好一次', (tester) async {
    final model = _RecordingModel();
    await _pumpSearch(tester, model);

    await tester.enterText(find.byType(TextField), '夜航');
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      model.commands.whereType<bridge.FfiCommand_Search>(),
      isEmpty,
      reason: '300ms 内不应派发搜索',
    );

    await tester.pump(const Duration(milliseconds: 300));
    final searches = model.commands
        .whereType<bridge.FfiCommand_Search>()
        .toList();
    expect(searches, hasLength(1));
    expect(searches.single.keyword, '夜航');
    expect(searches.single.source, isNull, reason: '默认聚合搜索');
  });

  testWidgets('seedKeyword：构造即触发一次搜索（Ctrl+K 通道）', (tester) async {
    final model = _RecordingModel();
    await _pumpSearch(tester, model, seedKeyword: 'Blue Hour');

    final searches = model.commands
        .whereType<bridge.FfiCommand_Search>()
        .toList();
    expect(searches, hasLength(1));
    expect(searches.single.keyword, 'Blue Hour');
  });

  testWidgets('单击选中、再单击另一行切换单选', (tester) async {
    final model = _RecordingModel();
    model.debugSetSearch(
      _searchState(
        keyword: 'kw',
        requestId: BigInt.one,
        items: [
          _song('1', '歌一', singer: '歌手一'),
          _song('2', '歌二', singer: '歌手二'),
        ],
      ),
    );
    await _pumpSearch(tester, model, seedKeyword: 'kw');

    await tester.tap(find.text('歌一'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('歌二'));
    await tester.pump(const Duration(milliseconds: 400));

    // 单击只选中，不播放。
    expect(model.commands.whereType<bridge.FfiCommand_PlaySongs>(), isEmpty);
    // 选中态：新选行的序号列被清空（换为勾选底色），旧选行恢复序号 1。
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNothing, reason: '第二行选中后序号列变空');
  });

  testWidgets('Ctrl 多选两行 + Enter 播放选中项（按行序入队）', (tester) async {
    final model = _RecordingModel();
    model.debugSetSearch(
      _searchState(
        keyword: 'kw',
        requestId: BigInt.one,
        items: [_song('1', '歌一'), _song('2', '歌二'), _song('3', '歌三')],
      ),
    );
    await _pumpSearch(tester, model, seedKeyword: 'kw');

    // 双击窗口（300ms）内单击不会落地：每次 tap 后 pump 400ms 让选中生效。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(find.text('歌一'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('歌三'));
    await tester.pump(const Duration(milliseconds: 400));
    // Ctrl 再点第三行：把「歌三」切换掉，只剩「歌一」。
    await tester.tap(find.text('歌三'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 50));

    final plays = model.commands
        .whereType<bridge.FfiCommand_PlaySongs>()
        .toList();
    expect(plays, hasLength(1));
    expect(plays.single.songs.map((s) => s.id), ['1']);
    expect(plays.single.index, 0);
  });

  testWidgets('Shift 范围多选：锚点到当前行全部选中', (tester) async {
    final model = _RecordingModel();
    model.debugSetSearch(
      _searchState(
        keyword: 'kw',
        requestId: BigInt.one,
        items: [for (var i = 1; i <= 5; i++) _song('$i', '歌$i')],
      ),
    );
    await _pumpSearch(tester, model, seedKeyword: 'kw');

    await tester.tap(find.text('歌1'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.text('歌4'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 50));

    final plays = model.commands
        .whereType<bridge.FfiCommand_PlaySongs>()
        .toList();
    expect(plays, hasLength(1));
    expect(plays.single.songs.map((s) => s.id), ['1', '2', '3', '4']);
  });

  testWidgets('双击行播放整表（双击不触发单击选中）', (tester) async {
    final model = _RecordingModel();
    model.debugSetSearch(
      _searchState(
        keyword: 'kw',
        requestId: BigInt.one,
        items: [_song('1', '歌一'), _song('2', '歌二')],
      ),
    );
    await _pumpSearch(tester, model, seedKeyword: 'kw');

    await tester.tap(find.text('歌二'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('歌二'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    final plays = model.commands
        .whereType<bridge.FfiCommand_PlaySongs>()
        .toList();
    expect(plays, hasLength(1), reason: '双击应只派发一次播放');
    expect(plays.single.songs.map((s) => s.id), ['1', '2']);
    expect(plays.single.index, 1);
  });

  testWidgets('分页 in-flight 锁：触底后只派发一次，响应到达后才允许下一页', (tester) async {
    final model = _RecordingModel();
    model.debugSetSearch(
      _searchState(
        keyword: 'kw',
        page: 1,
        hasMore: true,
        requestId: BigInt.one,
        items: [for (var i = 1; i <= 60; i++) _song('$i', '歌$i')],
      ),
    );
    await _pumpSearch(tester, model, seedKeyword: 'kw');

    Future<void> dragBottom() async {
      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pump(const Duration(milliseconds: 100));
    }

    await dragBottom();
    await dragBottom();
    await dragBottom();
    expect(
      model.commands.whereType<bridge.FfiCommand_SearchMore>(),
      hasLength(1),
      reason: 'in-flight 锁：响应未到达前重复触底不得重复分页',
    );
    expect(
      model.commands.whereType<bridge.FfiCommand_SearchMore>().single.page,
      2,
    );

    // 新响应到达（requestId 变化）：锁释放，仍在底部时自动续载下一页。
    model.debugSetSearch(
      _searchState(
        keyword: 'kw',
        page: 2,
        hasMore: true,
        requestId: BigInt.two,
        items: [for (var i = 1; i <= 120; i++) _song('$i', '歌$i')],
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    final mores = model.commands
        .whereType<bridge.FfiCommand_SearchMore>()
        .toList();
    expect(mores, hasLength(2), reason: '响应到达后锁释放，允许请求 page 3');
    expect(mores.last.page, 3);
  });

  testWidgets('分页三态：加载中 / 没有更多 / 失败重试', (tester) async {
    final model = _RecordingModel();
    // 没有更多。
    model.debugSetSearch(
      _searchState(
        keyword: 'kw',
        requestId: BigInt.one,
        hasMore: false,
        items: [_song('1', '歌一')],
      ),
    );
    await _pumpSearch(tester, model, seedKeyword: 'kw');
    expect(find.text('没有更多结果'), findsOneWidget);

    // 失败：显示重试，点击重新派发 searchMore。
    model.debugSetSearch(
      _searchState(
        keyword: 'kw',
        page: 1,
        hasMore: true,
        requestId: BigInt.two,
        items: [_song('1', '歌一')],
        error: '网络超时',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('加载更多失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      model.commands.whereType<bridge.FfiCommand_SearchMore>(),
      hasLength(1),
    );
    // 派发后进入加载中（in-flight 锁生效）。
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('音源筛选：单选音源走后端过滤，再选一个变聚合', (tester) async {
    final model = _RecordingModel();
    model.debugSetSources([
      bridge.SourceCapabilitiesDto(
        id: 'wy',
        name: '网易云',
        playlists: true,
        playlistCategories: false,
        playlistSearch: true,
        album: false,
        artist: false,
        leaderboard: false,
        login: false,
        qrLogin: false,
      ),
      bridge.SourceCapabilitiesDto(
        id: 'tx',
        name: 'QQ音乐',
        playlists: true,
        playlistCategories: false,
        playlistSearch: true,
        album: false,
        artist: false,
        leaderboard: false,
        login: false,
        qrLogin: false,
      ),
    ]);
    await _pumpSearch(tester, model, seedKeyword: 'kw');
    model.commands.clear();

    // 单选网易云（Phase 3：音源筛选改 chips 行，§5.4 横向滚动）。
    await tester.tap(find.text('网易云'));
    await tester.pumpAndSettle();

    var searches = model.commands
        .whereType<bridge.FfiCommand_Search>()
        .toList();
    expect(searches.last.source, 'wy');

    // 再选 QQ音乐 → 两个音源 = 聚合搜索（null）+ 本地过滤。
    await tester.tap(find.text('QQ音乐'));
    await tester.pumpAndSettle();

    searches = model.commands.whereType<bridge.FfiCommand_Search>().toList();
    expect(searches.last.source, isNull);
  });

  testWidgets('类型 Tab：专辑 / 歌手由结果真实聚合；歌单 Tab 如实解释', (tester) async {
    final model = _RecordingModel();
    model.debugSetSources([
      bridge.SourceCapabilitiesDto(
        id: 'wy',
        name: '网易云',
        playlists: true,
        playlistCategories: false,
        playlistSearch: true,
        album: true,
        artist: true,
        leaderboard: false,
        login: false,
        qrLogin: false,
      ),
    ]);
    model.debugSetSearch(
      _searchState(
        keyword: 'kw',
        requestId: BigInt.one,
        items: [
          _song(
            '1',
            '歌一',
            singer: '歌手甲',
            album: '专辑X',
            artistId: 'a1',
            albumId: 'al1',
          ),
          _song(
            '2',
            '歌二',
            singer: '歌手甲',
            album: '专辑X',
            artistId: 'a1',
            albumId: 'al1',
          ),
          _song(
            '3',
            '歌三',
            singer: '歌手乙',
            album: '专辑Y',
            artistId: 'a2',
            albumId: 'al2',
            source: 'wy',
          ),
        ],
      ),
    );
    await _pumpSearch(tester, model, seedKeyword: 'kw');

    await tester.tap(find.text('专辑'));
    await tester.pumpAndSettle();
    // 去重后只有两张专辑卡，副标题带来源。
    expect(find.text('专辑X'), findsOneWidget);
    expect(find.text('专辑Y'), findsOneWidget);
    expect(find.textContaining('歌手甲 · 网易云'), findsOneWidget);

    await tester.tap(find.text('歌手'));
    await tester.pumpAndSettle();
    expect(find.text('歌手甲'), findsOneWidget);
    expect(find.text('歌手乙'), findsOneWidget);

    await tester.tap(find.text('歌单'));
    await tester.pumpAndSettle();
    expect(find.text('聚合搜索不返回歌单结果'), findsOneWidget);
  });

  testWidgets('清除按钮：清空输入并保留空态', (tester) async {
    final model = _RecordingModel();
    await _pumpSearch(tester, model);

    await tester.enterText(find.byType(TextField), '夜航');
    await tester.pump();
    expect(find.byTooltip('清除'), findsOneWidget);

    await tester.tap(find.byTooltip('清除'));
    await tester.pumpAndSettle();
    expect(find.text('搜索你想听的音乐'), findsOneWidget);
    expect(find.byTooltip('清除'), findsNothing);
  });

  testWidgets('P1-08 回归：结果行封面走 VxArtwork，song.coverUrl 不再被渐变占位吞掉', (
    tester,
  ) async {
    final model = _RecordingModel();
    bridge.SongDto song(String id, String name, String? coverUrl) =>
        bridge.SongDto(
          id: id,
          source: 'wy',
          name: name,
          singer: '歌手',
          albumName: '',
          durationMs: BigInt.from(180000),
          coverUrl: coverUrl,
        );
    model.debugSetSearch(
      _searchState(
        keyword: 'kw',
        requestId: BigInt.one,
        items: [
          song('1', '有封面', 'http://origin/cover.jpg'),
          song('2', '无封面', null),
        ],
      ),
    );
    await _pumpSearch(tester, model, seedKeyword: 'kw');

    final artworks = tester.widgetList<VxArtwork>(find.byType(VxArtwork));
    expect(
      artworks,
      isNotEmpty,
      reason: 'P1-08 修复：歌曲行 cover 参数接入统一封面入口 VxArtwork',
    );
    expect(
      artworks.any((a) => a.url == 'http://origin/cover.jpg'),
      isTrue,
      reason: 'song.coverUrl 必须传入行封面（此前永远渲染 VxCoverFallback）',
    );
    expect(
      find.byType(VxCoverFallback),
      findsNothing,
      reason: '歌曲行不再缺省渲染渐变首字母占位',
    );
  });

  testWidgets('P1-07 同类缺口回归：错误框 detail 净化，原始 URL/异常不直出', (tester) async {
    // QA 2026-11-11（linux-search-1440x900-error-retry.png）：state.search.error
    // 是 Rust 快照字段，不经 lastError/lastNotification 净化链路；渲染前必须
    // 过 AppModel.sanitizeUserFacingMessage（§9）。
    final model = _RecordingModel();
    model.debugSetSearch(
      _searchState(
        keyword: 'kw',
        requestId: BigInt.one,
        items: const [],
        error:
            '所有音源搜索失败: network error: error sending request for url '
            '(https://jadeite.migu.cn/music_search/v3/search/searchAll?isCorre=1)',
      ),
    );
    await _pumpSearch(tester, model, seedKeyword: 'kw');

    expect(
      find.textContaining('https://jadeite.migu.cn'),
      findsNothing,
      reason: '§9 原始 URL 不得直出 UI',
    );
    expect(
      find.textContaining('[URL]'),
      findsWidgets,
      reason: 'URL 已净化为占位符（与 P1-07 toast 同一口径）',
    );
    expect(find.text('搜索失败'), findsOneWidget, reason: '错误态本身保留');
  });
}

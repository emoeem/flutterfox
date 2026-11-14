/// 手机搜索页测试（计划书 C-02，360 视口为主）：
/// - 搜索框（输入/清除/提交/防抖）+ 类型 chips + 音源筛选 chips 单行横滚、
///   触控目标 ≥48dp、360/390 溢出断言；
/// - 音源筛选「全部音源」↔ 单源往返语义（恰选 1 个走后端过滤，取消回聚合）；
/// - 四态区分：Loading 骨架 / Error 重试（detail 净化）/ Empty 无结果 / Success；
/// - 歌曲移动行：标题/歌手/来源渲染、单击即播整列、长按菜单 showSongMenu
///   与桌面同一动作集（接真实命令）；
/// - 专辑/歌手两列网格（聚合去重 + 来源标识）；歌单 Tab 如实解释；
/// - 分页尾三态 + 触底 in-flight 锁；request_id 守卫（过期快照不覆盖）；
/// - 搜索历史：回填即搜置顶、单项删除、清空确认（§9 破坏性操作）；
/// - 键盘 inset：body 随 viewInsets 收缩，输入框不被遮挡（inset 分层契约）。
///
/// 平台口径：360 视口直接 pump MobileSearchPage（页面级，同
/// mobile_library_page_test 口径；壳内接线由 mobile_shell_test 覆盖）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/design_system/components/vx_album_card.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_artist_card.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_loading_skeleton.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_track_row.dart';
import 'package:voicefox_flutter/src/pages/mobile_search_page.dart';

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
}) => bridge.SongDto(
  id: id,
  source: source,
  name: name,
  singer: singer,
  artistId: artistId,
  albumName: album,
  albumId: albumId,
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

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpSearch(
  WidgetTester tester,
  AppModel model, {
  String seedKeyword = '',
  Size size = const Size(360, 800),
  Widget? wrapper,
}) async {
  _setSize(tester, size);
  await tester.pumpWidget(
    wrapper ??
        MaterialApp(
          home: Scaffold(
            body: MobileSearchPage(model, seedKeyword: seedKeyword),
          ),
        ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// 类型 chips 单行横滚：360 视口末位「歌单」在折叠线外未构建，横滑到末尾
/// 再点击（与真实用户操作同路径）。
Future<void> _scrollTypeChips(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('mobile-search-types')),
    const Offset(-200, 0),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('渲染与溢出', () {
    testWidgets('360 视口：搜索框 + 类型 chips + 音源 chips + 计数行无溢出', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([_caps('wy', '网易云'), _caps('kw', '酷狗')]);
      await _pumpSearch(tester, model);

      expect(find.text('输入歌曲、歌手、专辑或歌单名称……'), findsOneWidget);
      expect(find.text('全部音源'), findsOneWidget);
      expect(find.text('全部'), findsOneWidget, reason: '类型 chips 首位');
      expect(find.text('输入关键词开始搜索'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chips 触控目标 ≥48dp（视觉胶囊 32 + 触控余量）', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([_caps('wy', '网易云')]);
      await _pumpSearch(tester, model);

      final typeChip = find.ancestor(
        of: find.text('全部'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(typeChip.first).height, greaterThanOrEqualTo(48));
      final sourceChip = find.ancestor(
        of: find.text('全部音源'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(sourceChip.first).height, greaterThanOrEqualTo(48));
    });

    testWidgets('键盘 inset：body 随 viewInsets 收缩，输入框仍在首部可见', (tester) async {
      final model = _RecordingModel();
      await _pumpSearch(
        tester,
        model,
        wrapper: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: Scaffold(body: MobileSearchPage(model)),
          ),
        ),
      );

      // 输入框位于内容首部（页边距 12），不被 300dp 键盘遮挡。
      final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
      expect(fieldTop, lessThan(60));
      expect(tester.takeException(), isNull);
    });
  });

  group('搜索提交与音源筛选', () {
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

    testWidgets('seedKeyword：构造即触发一次搜索（壳层种子通道）', (tester) async {
      final model = _RecordingModel();
      await _pumpSearch(tester, model, seedKeyword: 'Blue Hour');
      final searches = model.commands
          .whereType<bridge.FfiCommand_Search>()
          .toList();
      expect(searches, hasLength(1));
      expect(searches.single.keyword, 'Blue Hour');
    });

    testWidgets('音源筛选往返：单选走后端过滤，取消/全部音源回聚合（P1-20 同语义）', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([_caps('wy', '网易云'), _caps('kw', '酷狗')]);
      await _pumpSearch(tester, model, seedKeyword: 'kw');
      model.commands.clear();

      // 单选酷狗 → Search 带 source。
      await tester.tap(find.text('酷狗'));
      await tester.pump(const Duration(milliseconds: 30));
      expect(
        model.commands.whereType<bridge.FfiCommand_Search>().last.source,
        'kw',
        reason: '恰选 1 个音源走后端过滤',
      );

      // 再点同 chip（取消选中）→ 无选中 = 聚合搜索。
      await tester.tap(find.text('酷狗'));
      await tester.pump(const Duration(milliseconds: 30));
      expect(
        model.commands.whereType<bridge.FfiCommand_Search>().last.source,
        isNull,
      );

      // 选中后点「全部音源」chip 显式恢复聚合。
      await tester.tap(find.text('酷狗'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('全部音源'));
      await tester.pump(const Duration(milliseconds: 30));
      expect(
        model.commands.whereType<bridge.FfiCommand_Search>().last.source,
        isNull,
        reason: '「全部音源」必须真实回到聚合视图',
      );
    });

    testWidgets('清除按钮：清空输入并回到空态', (tester) async {
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
  });

  group('结果四态与行交互', () {
    testWidgets('四态区分：Loading 骨架 / Error 重试（净化）/ Empty / Success', (
      tester,
    ) async {
      final model = _RecordingModel();
      await _pumpSearch(tester, model, seedKeyword: 'kw');

      model.debugSetSearch(
        _searchState(keyword: 'kw', requestId: BigInt.one, loading: true),
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(
        find.byType(VxLoadingSkeleton),
        findsOneWidget,
        reason: 'Loading 态',
      );

      model.debugSetSearch(
        _searchState(
          keyword: 'kw',
          requestId: BigInt.two,
          error: '所有音源搜索失败: https://jadeite.migu.cn/music_search?token=secret',
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.text('搜索失败'), findsOneWidget, reason: 'Error 态');
      expect(find.text('重试'), findsOneWidget);
      expect(
        find.textContaining('https://'),
        findsNothing,
        reason: '§9 原始 URL 不直出',
      );
      expect(find.textContaining('[URL]'), findsWidgets);

      model.debugSetSearch(
        _searchState(
          keyword: 'kw',
          requestId: BigInt.from(3),
          items: [_song('s1', '结果一')],
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.text('结果一'), findsOneWidget, reason: 'Success 态');

      model.debugSetSearch(
        _searchState(keyword: 'kw', requestId: BigInt.from(4), items: const []),
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.text('没有结果'), findsOneWidget, reason: 'Empty 态');
      expect(tester.takeException(), isNull);
    });

    testWidgets('歌曲移动行：标题/歌手/来源渲染；单击即播整列', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([_caps('wy', '网易云')]);
      model.debugSetSearch(
        _searchState(
          keyword: 'kw',
          requestId: BigInt.one,
          items: [_song('1', '歌一'), _song('2', '歌二')],
        ),
      );
      await _pumpSearch(tester, model, seedKeyword: 'kw');

      expect(find.text('歌一'), findsOneWidget);
      expect(find.textContaining('歌手A'), findsWidgets);
      expect(find.text('网易云'), findsWidgets, reason: '来源小字标识');

      await tester.tap(find.text('歌二'));
      await tester.pump(const Duration(milliseconds: 50));

      final plays = model.commands
          .whereType<bridge.FfiCommand_PlaySongs>()
          .toList();
      expect(plays, hasLength(1), reason: '移动行单击即播（触屏无 hover 操作列）');
      expect(plays.single.songs.map((s) => s.id), ['1', '2']);
      expect(plays.single.index, 1);
      expect(
        tester.getSize(find.byType(VxTrackRow).first).height,
        66,
        reason: 'comfortable 行高 ≥48 触控目标',
      );
    });

    testWidgets('长按行 = 完整歌曲菜单（showSongMenu 与桌面同一动作集，接真实命令）', (tester) async {
      final model = _RecordingModel();
      model.debugSetSearch(
        _searchState(
          keyword: 'kw',
          requestId: BigInt.one,
          items: [_song('1', '歌一')],
        ),
      );
      await _pumpSearch(tester, model, seedKeyword: 'kw');

      await tester.longPress(find.text('歌一'));
      await tester.pumpAndSettle();

      // 菜单项与桌面 showSongMenu 同一动作集（高频在前、危险在后）。
      expect(find.text('立即播放'), findsOneWidget);
      expect(find.text('加入队列'), findsOneWidget);
      expect(find.text('加入歌单'), findsOneWidget);
      expect(find.textContaining('收藏'), findsWidgets);
      expect(find.text('下载'), findsOneWidget);

      await tester.tap(find.text('加入队列'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        model.commands.whereType<bridge.FfiCommand_QueueAdd>(),
        hasLength(1),
        reason: '菜单项接真实命令（与桌面同一命令接线）',
      );
    });

    testWidgets('专辑 / 歌手 Tab：歌曲结果聚合去重，两列网格带来源', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([_caps('wy', '网易云')]);
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
            ),
          ],
        ),
      );
      await _pumpSearch(tester, model, seedKeyword: 'kw');

      await tester.tap(find.text('专辑'));
      await tester.pumpAndSettle();
      // 去重后两张专辑卡；两列网格（360 视口卡宽 = (360-32-12)/2 = 158）。
      expect(find.text('专辑X'), findsOneWidget);
      expect(find.text('专辑Y'), findsOneWidget);
      expect(find.textContaining('歌手甲 · 网易云'), findsOneWidget);
      final card = tester.getSize(find.byType(VxAlbumCard).first);
      expect(card.width, closeTo(158, 1));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('歌手'));
      await tester.pumpAndSettle();
      expect(find.text('歌手甲'), findsOneWidget);
      expect(find.text('歌手乙'), findsOneWidget);
      expect(find.byType(VxArtistCard), findsNWidgets(2));
    });

    testWidgets('歌单 Tab：聚合搜索不返回歌单，如实解释', (tester) async {
      final model = _RecordingModel();
      model.debugSetSearch(
        _searchState(
          keyword: 'kw',
          requestId: BigInt.one,
          items: [_song('1', '歌一')],
        ),
      );
      await _pumpSearch(tester, model, seedKeyword: 'kw');

      await _scrollTypeChips(tester);
      await tester.tap(find.text('歌单'));
      await tester.pumpAndSettle();
      expect(find.text('聚合搜索不返回歌单结果'), findsOneWidget);
    });
  });

  group('分页与过期响应', () {
    testWidgets('分页 in-flight 锁：触底只派发一次；尾三态渲染', (tester) async {
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
        await tester.drag(
          find.byType(VxTrackRow).first,
          const Offset(0, -4000),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 100));
      }

      await dragBottom();
      await dragBottom();
      await dragBottom();
      final mores = model.commands
          .whereType<bridge.FfiCommand_SearchMore>()
          .toList();
      expect(mores, hasLength(1), reason: 'in-flight 锁防重复分页');
      expect(mores.single.page, 2);

      // 等 fling 弹道结算（此处 moreInFlight 恒 true，不能 pumpAndSettle：
      // 尾态 spinner 是无限动画）。
      await tester.pump(const Duration(seconds: 2));

      // 尾态二：失败重试（列表保持 60 行，避免收缩滚动修正触发再加载）。
      model.debugSetSearch(
        _searchState(
          keyword: 'kw',
          page: 1,
          hasMore: true,
          requestId: BigInt.two,
          items: [for (var i = 1; i <= 60; i++) _song('$i', '歌$i')],
          error: '网络超时',
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('加载更多失败'), findsOneWidget);
      model.commands.clear();
      await tester.tap(find.text('重试'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        model.commands.whereType<bridge.FfiCommand_SearchMore>(),
        hasLength(1),
        reason: '失败重试重新派发分页',
      );

      // 尾态三：没有更多（requestId 前进释放 in-flight 锁）。
      model.debugSetSearch(
        _searchState(
          keyword: 'kw',
          page: 2,
          hasMore: false,
          requestId: BigInt.from(3),
          items: [for (var i = 1; i <= 60; i++) _song('$i', '歌$i')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('没有更多结果'), findsOneWidget);
    });

    testWidgets('新查询后旧查询的过期快照（requestId 回退）不覆盖当前结果', (tester) async {
      final model = _RecordingModel();
      await _pumpSearch(tester, model, seedKeyword: 'love');

      model.debugSetSearch(
        _searchState(
          keyword: 'love',
          page: 1,
          requestId: BigInt.one,
          items: [_song('s1', '旧查询一')],
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.text('旧查询一'), findsOneWidget);

      model.debugSetSearch(
        _searchState(
          keyword: 'rock',
          page: 1,
          requestId: BigInt.two,
          items: [_song('r1', '新查询一')],
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(find.text('新查询一'), findsOneWidget);

      model.debugSetSearch(
        _searchState(
          keyword: 'love',
          page: 2,
          requestId: BigInt.one,
          items: [_song('s1', '旧查询一'), _song('s2', '旧查询迟到曲')],
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));
      expect(
        find.text('旧查询迟到曲'),
        findsNothing,
        reason: '§8.1 过期响应（requestId 回退）不得覆盖当前页面',
      );
      expect(find.text('新查询一'), findsOneWidget);
    });
  });

  group('搜索历史（空关键词态）', () {
    testWidgets('回填即搜置顶、单项删除、清空确认（§9）', (tester) async {
      SharedPreferences.setMockInitialValues({
        'voicefox.search_history': ['夜航', 'Blue Hour'],
      });
      final model = _RecordingModel();
      await model.loadSearchHistory();
      await _pumpSearch(tester, model);

      expect(find.text('搜索历史'), findsOneWidget);
      expect(find.text('夜航'), findsOneWidget);
      expect(find.text('Blue Hour'), findsOneWidget);
      expect(find.textContaining('不会上传账号'), findsOneWidget);

      // 点击历史项 = 显式提交：回填即搜并置顶该条。
      await tester.tap(find.text('Blue Hour'));
      await tester.pump(const Duration(milliseconds: 30));
      expect(
        model.commands.whereType<bridge.FfiCommand_Search>().last.keyword,
        'Blue Hour',
      );
      expect(model.searchHistory.first, 'Blue Hour', reason: '点击历史项置顶');

      // 清除输入回到历史面板。
      await tester.tap(find.byTooltip('清除'));
      await tester.pumpAndSettle();
      expect(find.text('搜索历史'), findsOneWidget);

      // 单项删除。
      await tester.tap(find.byTooltip('删除该条历史').first);
      await tester.pump(const Duration(milliseconds: 30));
      expect(model.searchHistory, ['夜航']);

      // 清空需确认：先取消不动数据。
      await tester.tap(find.byTooltip('清空搜索历史'));
      await tester.pumpAndSettle();
      expect(find.text('将删除全部搜索历史，无法恢复。'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(model.searchHistory, ['夜航'], reason: '取消清空不动数据');

      // 确认清空：列表与持久化同步清空。
      await tester.tap(find.byTooltip('清空搜索历史'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清空').last);
      await tester.pumpAndSettle();
      expect(model.searchHistory, isEmpty);
      expect(find.text('搜索你想听的音乐'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('voicefox.search_history') ?? const [],
        isEmpty,
        reason: '清空后持久化同步',
      );
    });
  });
}

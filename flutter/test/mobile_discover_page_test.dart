/// 手机发现页测试（计划书 C-01，360 视口为主）：
/// - 页首标题 + 音源筛选 chips（单行横滚、触控目标 ≥48dp）；
/// - P1-20 哨兵语义回归：单音源 ↔「全部音源」可往返，往返必须真实重载聚合；
/// - 子 Tab 能力禁用（复用桌面 discoverTabEnabled）：禁用 Tab 不可切换；
/// - 组级四态：Loading 骨架 / 错误+重试（重试重发命令）/ 空态 / 成功两列
///   网格（封面 1:1、标题两行、来源·曲目数小字）+ 加载更多分页触发；
/// - 部分成功：单一源失败不隐藏其他源内容；
/// - 排行榜 / 分类 Tab 真实数据渲染与交互；
/// - 360/390 视口溢出断言（tester.takeException isNull）。
///
/// 平台口径：360 视口直接 pump MobileDiscoverPage（对齐 mobile_library_page
/// 页面级口径；壳内接线由 mobile_shell_test 覆盖）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/design_system/components/vx_loading_skeleton.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_playlist_card.dart';
import 'package:voicefox_flutter/src/nav_bus.dart';
import 'package:voicefox_flutter/src/pages/discover_page.dart'
    show DiscoverTab, discoverTabEnabled;
import 'package:voicefox_flutter/src/pages/mobile_discover_page.dart';

/// 记录派发命令的测试模型（不起 Rust 控制器）。
class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];

  @override
  Future<void> dispatch(bridge.FfiCommand command) async {
    commands.add(command);
  }
}

bridge.SourceCapabilitiesDto _source(
  String id,
  String name, {
  bool playlists = false,
  bool playlistCategories = false,
  bool leaderboard = false,
  bool artist = false,
}) => bridge.SourceCapabilitiesDto(
  id: id,
  name: name,
  playlists: playlists,
  playlistCategories: playlistCategories,
  playlistSearch: playlists,
  album: false,
  artist: artist,
  leaderboard: leaderboard,
  login: false,
  qrLogin: false,
);

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 手机发现页内的查找（限定范围）：页面组件可复用同名文本（如音源名同时
/// 是 chips 标签与分组标题），不能全树盲目取 first。
Finder _page(Finder finder) =>
    find.descendant(of: find.byType(MobileDiscoverPage), matching: finder);

Future<void> _pumpDiscover(
  WidgetTester tester,
  AppModel model, {
  Size size = const Size(360, 800),
}) async {
  _setSize(tester, size);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: MobileDiscoverPage(model))),
  );
  // 帧后触发首轮加载；给两帧让状态落地。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Tab chips 是单行横滚（360 视口末位「分类」在折叠线外未构建），横滑到
/// 末尾再断言/点击离屏 chips（与真实用户操作同路径）。
Future<void> _scrollTabChips(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('mobile-discover-tabs')),
    const Offset(-200, 0),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('渲染与溢出', () {
    testWidgets('360 视口：页首「发现」+ 音源 chips + Tab chips 无溢出', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([
        _source('wy', '网易云', playlists: true),
        _source('tx', 'QQ音乐', playlists: true, leaderboard: true),
      ]);
      await _pumpDiscover(tester, model);

      expect(_page(find.text('发现')), findsOneWidget);
      expect(_page(find.text('音源范围：全部音源')), findsOneWidget);
      // chips：全部音源 + 两个音源 + 五个 Tab。
      expect(_page(find.text('全部音源')), findsOneWidget);
      expect(_page(find.text('精选歌单')), findsOneWidget);
      expect(_page(find.text('排行榜')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('无音源：如实空态（不伪造内容）', (tester) async {
      final model = _RecordingModel();
      await _pumpDiscover(tester, model);
      expect(find.text('没有可用的音源'), findsOneWidget);
      expect(_page(find.byType(VxPlaylistCard)), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('390 视口：聚合两源歌单网格渲染无溢出（封面 1:1 两列）', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([
        _source('wy', '网易云', playlists: true),
        _source('tx', 'QQ音乐', playlists: true),
      ]);
      await _pumpDiscover(tester, model, size: const Size(390, 844));
      model.debugBrowseLoaded(
        kind: 'playlists',
        source: 'wy',
        id: '',
        playlists: [
          bridge.PlaylistDto(
            id: 'p1',
            name: '华语经典',
            source: 'wy',
            songCount: 30,
          ),
          bridge.PlaylistDto(
            id: 'p2',
            name: '深夜通勤',
            source: 'wy',
            songCount: 18,
          ),
        ],
      );
      await tester.pumpAndSettle();

      // 分组标题 = 音源名（全部音源聚合语义），卡片带曲数与来源小字。
      expect(_page(find.text('网易云')), findsWidgets);
      expect(_page(find.text('华语经典')), findsOneWidget);
      expect(_page(find.textContaining('30 首歌曲 · 网易云')), findsOneWidget);
      // 两列网格：卡宽 = (390-40-12)/2 = 169（封面 1:1）。
      final card = tester.getSize(_page(find.byType(VxPlaylistCard)).first);
      expect(card.width, closeTo(169, 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('chips 触控目标 ≥48dp（视觉胶囊 32 + 触控余量）', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([_source('wy', '网易云', playlists: true)]);
      await _pumpDiscover(tester, model);

      final chip = find.ancestor(
        of: _page(find.text('全部音源')),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(chip.first).height, greaterThanOrEqualTo(48));
      final tabChip = find.ancestor(
        of: _page(find.text('精选歌单')),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(tabChip.first).height, greaterThanOrEqualTo(48));
    });
  });

  group('音源筛选与 P1-20 哨兵语义', () {
    testWidgets('聚合首发：两个音源都触发歌单加载；单源切换真实重载', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([
        _source('wy', '网易云', playlists: true),
        _source('tx', 'QQ音乐', playlists: true),
      ]);
      await _pumpDiscover(tester, model);
      // 聚合（null）：全部支持歌单的音源补拉。
      expect(
        model.commands.whereType<bridge.FfiCommand_PlaylistList>().map(
          (c) => c.source,
        ),
        containsAll(['wy', 'tx']),
      );

      // 切单源 QQ音乐：清请求键重发该源。
      model.commands.clear();
      await tester.tap(_page(find.text('QQ音乐')).first);
      await tester.pump(const Duration(milliseconds: 50));

      expect(_page(find.text('音源范围：QQ音乐')), findsOneWidget);
      final loads = model.commands
          .whereType<bridge.FfiCommand_PlaylistList>()
          .toList();
      expect(loads, isNotEmpty, reason: '切源必须重载数据（§5.3）');
      expect(loads.map((c) => c.source), ['tx']);
      expect(_page(find.text('今日精选')), findsOneWidget);
    });

    testWidgets('P1-20 回归：单源再选「全部音源」必须回到聚合视图且聚合真实恢复', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([
        _source('wy', '网易云', playlists: true),
        _source('tx', 'QQ音乐', playlists: true),
      ]);
      await _pumpDiscover(tester, model);

      // 先切到单源 tx。
      await tester.tap(_page(find.text('QQ音乐')).first);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_page(find.text('音源范围：QQ音乐')), findsOneWidget);

      // 再选「全部音源」：手机 chips 无 PopupMenu null 吞没问题，但往返语义
      // 与桌面哨兵同一出处（selectSource(null) 清请求键 + 聚合补拉）。
      model.commands.clear();
      await tester.tap(_page(find.text('全部音源')));
      await tester.pump(const Duration(milliseconds: 50));

      expect(_page(find.text('音源范围：全部音源')), findsOneWidget);
      final reloaded = model.commands
          .whereType<bridge.FfiCommand_PlaylistList>()
          .map((c) => c.source)
          .toList();
      expect(reloaded, containsAll(['wy', 'tx']), reason: '回到聚合后所有音源重新加载');
    });

    testWidgets('单源 tx（仅歌单能力）：切源后 Tab 自动回落到精选歌单', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([
        _source(
          'wy',
          '网易云',
          playlists: true,
          leaderboard: true,
          playlistCategories: true,
        ),
        _source('tx', 'QQ音乐', playlists: true),
      ]);
      await _pumpDiscover(tester, model);

      // 全部音源下切到排行榜 Tab（能力并集支持）。
      await tester.tap(_page(find.text('排行榜')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        model.commands.whereType<bridge.FfiCommand_LeaderboardBoards>().map(
          (c) => c.source,
        ),
        contains('wy'),
      );

      // 切到 tx：排行榜不再支持，回落精选歌单。
      await tester.tap(_page(find.text('QQ音乐')).first);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_page(find.text('今日精选')), findsOneWidget);
    });
  });

  group('能力禁用 Tab', () {
    testWidgets('单源 wy 仅歌单能力：其余 Tab 禁用（阻断图标）且点击不切换', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([_source('wy', '网易云', playlists: true)]);
      await _pumpDiscover(tester, model);

      // 禁用判定与桌面同一实现：单源下排行榜/歌手/专辑/分类全部不可用。
      for (final tab in DiscoverTab.values) {
        final enabled = discoverTabEnabled(
          tab,
          model.state.sources,
          source: 'wy',
        );
        expect(
          enabled,
          tab == DiscoverTab.playlists,
          reason: '${tab.name} 能力判定',
        );
      }
      // 四个禁用 Tab 带阻断图标（排行榜/歌手/专辑/分类）；末位「分类」
      // 在 360 视口折叠线外，先横滑 chips 行构建再断言。
      await _scrollTabChips(tester);
      expect(find.byIcon(Icons.block_outlined), findsNWidgets(4));
      await tester.drag(
        find.byKey(const ValueKey('mobile-discover-tabs')),
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();

      await tester.tap(_page(find.text('排行榜')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      // 仍停在精选歌单（聚合分组标题 = 音源名，eyebrow 热门歌单）。
      expect(_page(find.text('热门歌单')), findsOneWidget);
      expect(
        model.commands.whereType<bridge.FfiCommand_LeaderboardBoards>().isEmpty,
        isTrue,
        reason: '禁用 Tab 点击不得派发请求',
      );
    });

    testWidgets('歌手 Tab：如实解释（无浏览接口），「去搜索」切搜索目的地', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([
        // artist 能力位存在（Tab 可切），但后端无「浏览全部歌手」接口。
        _source('wy', '网易云', playlists: true, leaderboard: true, artist: true),
      ]);
      await _pumpDiscover(tester, model);

      await tester.tap(_page(find.text('歌手')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('暂不支持浏览全部歌手'), findsOneWidget);
      expect(find.text('去搜索'), findsOneWidget);

      await tester.tap(find.text('去搜索'));
      await tester.pump();
      expect(navRequest.value, 1, reason: '手机档「去搜索」经 navRequest 切搜索目的地');
      navRequest.value = null;
    });
  });

  group('精选歌单组级四态', () {
    testWidgets('载入态：postFrame 派发后展示骨架屏', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([_source('wy', '网易云', playlists: true)]);
      await _pumpDiscover(tester, model);

      expect(
        model.commands.whereType<bridge.FfiCommand_PlaylistList>().map(
          (c) => c.source,
        ),
        ['wy'],
      );
      expect(find.byType(VxLoadingSkeleton), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('错误态 + 重试：重试重新派发加载（净化 detail，不直出 URL）', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([_source('wy', '网易云', playlists: true)]);
      await _pumpDiscover(tester, model);
      model.debugBrowseLoaded(
        kind: 'playlists',
        source: 'wy',
        id: '',
        message: 'fetch failed: https://api.example.com/x?token=secret',
        failed: true,
      );
      await tester.pump();

      expect(_page(find.text('歌单加载失败')), findsOneWidget);
      expect(_page(find.textContaining('[URL]')), findsOneWidget);
      expect(_page(find.textContaining('https://')), findsNothing);
      expect(_page(find.text('重试')), findsOneWidget);

      model.commands.clear();
      await tester.tap(_page(find.text('重试')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        model.commands.whereType<bridge.FfiCommand_PlaylistList>().map(
          (c) => c.source,
        ),
        ['wy'],
        reason: '重试必须重新派发歌单加载（§7.1 可恢复操作）',
      );
      expect(find.byType(VxLoadingSkeleton), findsWidgets);
    });

    testWidgets('空态：音源 notice 如实直出（不伪造歌单）', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([_source('wy', '网易云', playlists: true)]);
      await _pumpDiscover(tester, model);
      model.debugBrowseLoaded(
        kind: 'playlists',
        source: 'wy',
        id: '',
        playlists: const [],
        message: '维护中，稍后再来',
      );
      await tester.pumpAndSettle();

      expect(_page(find.text('维护中，稍后再来')), findsOneWidget);
      expect(_page(find.byType(VxPlaylistCard)), findsNothing);
    });

    testWidgets('加载更多：hasMore 时按钮触发 page=2 分页（append 语义）', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([_source('wy', '网易云', playlists: true)]);
      await _pumpDiscover(tester, model);
      model.debugBrowseLoaded(
        kind: 'playlists',
        source: 'wy',
        id: '',
        page: 1,
        hasMore: true,
        playlists: [
          bridge.PlaylistDto(
            id: 'p1',
            name: '华语经典',
            source: 'wy',
            songCount: 30,
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(_page(find.text('华语经典')), findsOneWidget);

      model.commands.clear();
      await tester.tap(_page(find.text('加载更多')));
      await tester.pump(const Duration(milliseconds: 50));

      final mores = model.commands
          .whereType<bridge.FfiCommand_PlaylistList>()
          .toList();
      expect(mores, hasLength(1));
      expect(mores.single.page, 2, reason: '加载更多派发下一页（分页上下文一致）');
      expect(mores.single.source, 'wy');
    });

    testWidgets('部分成功：单一源失败不隐藏其他源内容', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([
        _source('wy', '网易云', playlists: true),
        _source('tx', 'QQ音乐', playlists: true),
      ]);
      await _pumpDiscover(tester, model);
      model.debugBrowseLoaded(
        kind: 'playlists',
        source: 'wy',
        id: '',
        message: '网络不可用',
        failed: true,
      );
      model.debugBrowseLoaded(
        kind: 'playlists',
        source: 'tx',
        id: '',
        playlists: [
          bridge.PlaylistDto(
            id: 'p2',
            name: '欧美热榜',
            source: 'tx',
            songCount: 50,
          ),
        ],
      );
      await tester.pumpAndSettle();

      // wy 组错误态与 tx 组成功态同屏（部分成功，不互相隐藏）。
      expect(_page(find.text('歌单加载失败')), findsOneWidget);
      expect(_page(find.text('欧美热榜')), findsOneWidget);
      expect(_page(find.textContaining('50 首歌曲 · QQ音乐')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('排行榜与分类 Tab', () {
    testWidgets('排行榜：真实榜单行卡渲染，打开进入榜单页', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([_source('wy', '网易云', leaderboard: true)]);
      await _pumpDiscover(tester, model);

      await tester.tap(_page(find.text('排行榜')));
      await tester.pump(const Duration(milliseconds: 50));
      model.debugBrowseLoaded(
        kind: 'leaderboard_boards',
        source: 'wy',
        id: '',
        boards: [bridge.LeaderboardDto(id: 'b1', name: '飙升榜', source: 'wy')],
      );
      await tester.pumpAndSettle();

      expect(_page(find.text('飙升榜')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('分类：chips 渲染，点分类切到该源该分类歌单并派发加载', (tester) async {
      final model = _RecordingModel();
      model.debugSetSources([
        _source('wy', '网易云', playlists: true, playlistCategories: true),
      ]);
      await _pumpDiscover(tester, model);

      // 「分类」是 Tab 行末位 chip（360 视口折叠线外），横滑后点击。
      await _scrollTabChips(tester);
      await tester.tap(_page(find.text('分类')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        model.commands.whereType<bridge.FfiCommand_PlaylistCategories>().map(
          (c) => c.source,
        ),
        ['wy'],
      );

      model.debugBrowseLoaded(
        kind: 'playlist_categories',
        source: 'wy',
        id: '',
        categories: [
          bridge.PlaylistCategoryDto(
            id: 'cat1',
            name: '新歌',
            source: 'wy',
            group: '推荐',
            count: 120,
            hot: true,
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(_page(find.text('新歌')), findsOneWidget);

      await tester.tap(_page(find.text('新歌')));
      await tester.pump(const Duration(milliseconds: 50));
      // 点分类：切到单源歌单视图并加载该分类（桌面页同一编排）。
      expect(_page(find.text('今日精选')), findsOneWidget);
      final loads = model.commands
          .whereType<bridge.FfiCommand_PlaylistList>()
          .toList();
      expect(loads.last.source, 'wy');
      expect(loads.last.category, 'cat1');
      expect(_page(find.text('音源范围：网易云')), findsOneWidget);
    });
  });
}

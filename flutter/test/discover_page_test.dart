/// Phase 4 发现页测试：
/// - capabilities 禁用逻辑（纯函数单元测试 + widget 层禁用 Tab 不响应）；
/// - 音源筛选器（全部/单源）切换后 Tab 可用集合变化；
/// - 「全部音源」聚合：多音源分组展示，卡片带来源标识；
/// - 不支持的数据类型显示解释文案（不伪造数据）；
/// - 排行榜 Tab 渲染真实榜单行。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/discover_page.dart';

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
  bool album = false,
  bool artist = false,
  bool leaderboard = false,
}) => bridge.SourceCapabilitiesDto(
  id: id,
  name: name,
  playlists: playlists,
  playlistCategories: playlistCategories,
  playlistSearch: playlists,
  album: album,
  artist: artist,
  leaderboard: leaderboard,
  login: false,
  qrLogin: false,
);

Future<void> _pumpDiscover(WidgetTester tester, AppModel model) async {
  tester.view.physicalSize = const Size(1280, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: DiscoverPage(model))),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('discoverTabEnabled 禁用逻辑（真实 SourceCapabilitiesDto）', () {
    final wy = _source(
      'wy',
      '网易云',
      playlists: true,
      playlistCategories: true,
      leaderboard: true,
      album: true,
      artist: true,
    );
    final tx = _source('tx', 'QQ音乐', playlists: true);
    final sources = [wy, tx];

    test('全部音源：按能力并集判定', () {
      expect(discoverTabEnabled(DiscoverTab.playlists, sources), isTrue);
      expect(discoverTabEnabled(DiscoverTab.leaderboard, sources), isTrue);
      expect(discoverTabEnabled(DiscoverTab.categories, sources), isTrue);
      expect(discoverTabEnabled(DiscoverTab.artists, sources), isTrue);
      expect(discoverTabEnabled(DiscoverTab.albums, sources), isTrue);
    });

    test('单源 tx：只支持歌单，其余 Tab 禁用', () {
      const txId = 'tx';
      expect(
        discoverTabEnabled(DiscoverTab.playlists, sources, source: txId),
        isTrue,
      );
      expect(
        discoverTabEnabled(DiscoverTab.leaderboard, sources, source: txId),
        isFalse,
      );
      expect(
        discoverTabEnabled(DiscoverTab.categories, sources, source: txId),
        isFalse,
      );
      expect(
        discoverTabEnabled(DiscoverTab.artists, sources, source: txId),
        isFalse,
      );
      expect(
        discoverTabEnabled(DiscoverTab.albums, sources, source: txId),
        isFalse,
      );
    });

    test('单源 wy：全 Tab 可用', () {
      const wyId = 'wy';
      for (final tab in DiscoverTab.values) {
        expect(
          discoverTabEnabled(tab, sources, source: wyId),
          isTrue,
          reason: '${tab.name} 应可用',
        );
      }
    });

    test('能力快照为空：全部禁用', () {
      for (final tab in DiscoverTab.values) {
        expect(discoverTabEnabled(tab, const []), isFalse);
      }
    });
  });

  testWidgets('渲染：Tab 栏 + 不支持的 Tab 禁用（tooltip 原因）', (tester) async {
    final model = AppModel();
    model.debugSetSources([_source('wy', '网易云', playlists: true)]);
    await _pumpDiscover(tester, model);

    expect(find.text('发现音乐'), findsOneWidget);
    expect(find.text('音源：全部'), findsOneWidget);
    // 禁用 Tab 带阻断图标（排行榜/歌手/专辑/分类）。
    expect(find.byIcon(Icons.block_outlined), findsNWidgets(4));
    // 长按禁用 Tab 显示原因 tooltip。
    await tester.longPress(find.text('排行榜'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('当前音源不支持排行榜'), findsOneWidget);
    expect(find.text('当前音源不支持歌手浏览'), findsNothing);
  });

  testWidgets('禁用 Tab 点击不切换', (tester) async {
    final model = AppModel();
    model.debugSetSources([_source('wy', '网易云', playlists: true)]);
    await _pumpDiscover(tester, model);

    await tester.tap(find.text('排行榜'), warnIfMissed: false);
    await tester.pump();
    // 当前仍停在精选歌单 Tab（内容区是歌单分组）。
    expect(find.text('热门歌单'), findsWidgets);
  });

  testWidgets('全部音源：聚合多源歌单分组展示并带来源标识', (tester) async {
    final model = _RecordingModel();
    model.debugSetSources([
      _source('wy', '网易云', playlists: true),
      _source('tx', 'QQ音乐', playlists: true),
    ]);
    await _pumpDiscover(tester, model);
    // 两个源都触发了歌单加载。
    final loads = model.commands
        .whereType<bridge.FfiCommand_PlaylistList>()
        .toList();
    expect(loads.map((c) => c.source), containsAll(['wy', 'tx']));

    model.debugBrowseLoaded(
      kind: 'playlists',
      source: 'wy',
      id: '',
      playlists: [
        bridge.PlaylistDto(id: 'p1', name: '华语经典', source: 'wy', songCount: 30),
      ],
    );
    model.debugBrowseLoaded(
      kind: 'playlists',
      source: 'tx',
      id: '',
      playlists: [
        bridge.PlaylistDto(id: 'p2', name: '欧美热榜', source: 'tx', songCount: 50),
      ],
    );
    await tester.pumpAndSettle();

    // 分组标题 = 音源名（全部音源下按源分组）。
    expect(find.text('网易云'), findsWidgets);
    expect(find.text('QQ音乐'), findsWidgets);
    // 歌单卡与曲数。
    expect(find.text('华语经典'), findsOneWidget);
    expect(find.text('欧美热榜'), findsOneWidget);
    // 卡片副标题带曲数与来源标识。
    expect(find.textContaining('30 首歌曲 · 网易云'), findsOneWidget);
    expect(find.textContaining('50 首歌曲 · QQ音乐'), findsOneWidget);
  });

  testWidgets('单源切换后按新源能力回落 Tab 并加载数据', (tester) async {
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

    // 切到排行榜 Tab（全部音源下可用）。
    await tester.tap(find.text('排行榜'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // 请求了支持榜单的音源目录。
    expect(
      model.commands.whereType<bridge.FfiCommand_LeaderboardBoards>().map(
        (c) => c.source,
      ),
      contains('wy'),
    );

    // 切换音源到 tx：排行榜 Tab 不再支持，自动回落到精选歌单。
    await tester.tap(find.text('音源：全部'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QQ音乐'));
    await tester.pumpAndSettle();

    expect(find.text('音源：QQ音乐'), findsOneWidget);
    expect(find.text('今日精选'), findsOneWidget, reason: '排行榜 Tab 不可用时应回落到精选歌单');
    expect(find.byIcon(Icons.block_outlined), findsNWidgets(4));
  });

  testWidgets('歌手 / 专辑 Tab：显示解释文案而非伪造数据', (tester) async {
    final model = AppModel();
    model.debugSetSources([
      _source('wy', '网易云', playlists: true, artist: true, album: true),
    ]);
    await _pumpDiscover(tester, model);

    await tester.tap(find.text('歌手'));
    await tester.pump();
    expect(find.text('暂不支持浏览全部歌手'), findsOneWidget);
    expect(find.text('去搜索'), findsOneWidget);

    await tester.tap(find.text('专辑'));
    await tester.pump();
    expect(find.text('暂不支持浏览全部专辑'), findsOneWidget);
  });

  testWidgets('排行榜 Tab：真实榜单行卡渲染', (tester) async {
    final model = AppModel();
    model.debugSetSources([_source('wy', '网易云', leaderboard: true)]);
    await _pumpDiscover(tester, model);

    await tester.tap(find.text('排行榜'));
    await tester.pump();
    model.debugBrowseLoaded(
      kind: 'leaderboard_boards',
      source: 'wy',
      id: '',
      boards: [bridge.LeaderboardDto(id: 'b1', name: '飙升榜', source: 'wy')],
    );
    await tester.pumpAndSettle();

    expect(find.text('飙升榜'), findsOneWidget);
    expect(find.text('查看榜单'), findsOneWidget);
  });

  testWidgets('切换音源后重新派发 PlaylistList（切源必须重载当前分类数据）', (tester) async {
    final model = _RecordingModel();
    model.debugSetSources([
      _source('wy', '网易云', playlists: true),
      _source('tx', 'QQ音乐', playlists: true),
    ]);
    await _pumpDiscover(tester, model);

    // 全部音源：两个源都触发过加载。
    final initial = model.commands
        .whereType<bridge.FfiCommand_PlaylistList>()
        .map((c) => c.source)
        .toList();
    expect(initial, containsAll(['wy', 'tx']));

    model.commands.clear();
    await tester.tap(find.text('音源：全部'));
    await tester.pumpAndSettle();
    // 多源分组标题也是「QQ音乐」（18px 粗体），弹层菜单项在 overlay 里
    // 树序靠后：用 .last 点菜单项。
    await tester.tap(find.text('QQ音乐').last);
    await tester.pumpAndSettle();

    // 切源后 _requestedPlaylistKeys 清空 → 当前分类重新请求新源数据。
    final reloaded = model.commands
        .whereType<bridge.FfiCommand_PlaylistList>()
        .toList();
    expect(reloaded, isNotEmpty, reason: '切音源必须重新加载数据（§5.3）');
    expect(reloaded.last.source, 'tx');
  });
}

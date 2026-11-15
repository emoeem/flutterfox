/// 手机歌单详情页测试（计划书 C-04，指南 §5.6；360 视口为主）：
/// - 打开先显示加载态不闪现旧歌单（§8.1）；载入成功渲染 Hero（封面位/
///   来源徽章/曲目数/总时长）与移动曲目行；
/// - PlaylistKey 隔离（mobile 版）：A/B 槽位隔离、相同 ID 不同 source
///   隔离、账号歌单 kind 分命名空间（业务与桌面页同一控制器实现）；
/// - 四态：加载骨架 / 错误+重试（detail 净化）/ 空歌单 / 能力提示 notice；
/// - 播放全部/随机播放接真实命令；收藏乐观态失败回滚与成功确认；
/// - 触底分页（FfiCommand_PlaylistDetail page:2）；下拉刷新；
/// - 360/390/430 视口无横向溢出。
///
/// 平台口径：页面级 pump（同 mobile_search_page_test 口径；壳内接线由
/// mobile_shell_test/mobile_home_page_test 覆盖）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/design_system/components/vx_empty_state.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_error_state.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_loading_skeleton.dart';
import 'package:voicefox_flutter/src/pages/mobile_playlist_detail_page.dart';

/// 记录派发命令的测试模型（不起 Rust 控制器）。
class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];
  String? errorToReturn;

  @override
  Future<void> dispatch(bridge.FfiCommand command) async {
    commands.add(command);
  }

  @override
  Future<String?> dispatchWithError(bridge.FfiCommand command) async {
    commands.add(command);
    return errorToReturn;
  }
}

bridge.PlaylistDto _playlist(String id, String source, {String? name}) =>
    bridge.PlaylistDto(
      id: id,
      name: name ?? '歌单$source$id',
      source: source,
      coverUrl: null,
      songCount: 2,
      description: '用于手机页测试的描述',
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

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpPage(
  WidgetTester tester,
  AppModel model,
  bridge.PlaylistDto playlist, {
  bool account = false,
  Size size = const Size(360, 800),
}) async {
  _setSize(tester, size);
  await tester.pumpWidget(
    MaterialApp(
      home: MobilePlaylistDetailPage(
        model,
        playlist,
        account: account,
        key: ValueKey('${playlist.source}/${playlist.id}/$account'),
      ),
    ),
  );
  await tester.pump();
}

/// 分步下拉手势（RefreshIndicator arm 需要足够的手势事件序列，同
/// playlist_detail_isolation_test 口径）。
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

void main() {
  testWidgets('打开先显示加载态；载入成功渲染 Hero 与移动行（§8.1）', (tester) async {
    final model = _RecordingModel();
    model.debugSetSources([
      bridge.SourceCapabilitiesDto(
        id: 'kw',
        name: '酷狗',
        playlists: false,
        playlistCategories: false,
        playlistSearch: false,
        album: false,
        artist: false,
        leaderboard: false,
        login: false,
        qrLogin: false,
      ),
    ]);
    final playlist = _playlist('p1', 'kw', name: '测试歌单');
    // 先给 A 槽装数据，再用同一模型打开 B 页：B 首帧不得闪现 A 曲目——
    // 这里直接以「同页先旧后新」变体锁加载态。
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'old',
      songs: [_song('s0', '旧歌单曲目', 'kw')],
    );
    await _pumpPage(tester, model, playlist);
    // 首帧：槽被 prepareBrowseLoad 清空/未载入 → 加载骨架，无曲目。
    expect(find.byType(VxLoadingSkeleton), findsOneWidget);
    expect(find.text('旧歌单曲目'), findsNothing);

    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', '第一首', 'kw'), _song('s2', '第二首', 'kw')],
      hasMore: false,
    );
    await tester.pump();

    expect(find.byType(VxLoadingSkeleton), findsNothing);
    expect(find.text('第一首'), findsOneWidget);
    expect(find.text('第二首'), findsOneWidget);
    // Hero：名称（AppBar 标题 + Hero 各一份，findsWidgets 即两处都在渲染）。
    expect(find.text('测试歌单'), findsWidgets);
    expect(find.text('酷狗'), findsWidgets, reason: '来源徽章 + 行来源标注');
    expect(find.text('2 首'), findsOneWidget);
    expect(find.text('总时长 6 分钟'), findsOneWidget);
    expect(find.text('用于手机页测试的描述'), findsOneWidget);
    // 主操作启用。
    expect(find.text('播放全部'), findsOneWidget);
    expect(find.text('随机播放'), findsOneWidget);
  });

  testWidgets('A/B 歌单槽位隔离：B 不显示 A 的曲目（mobile 版）', (tester) async {
    final model = _RecordingModel();
    await _pumpPage(tester, model, _playlist('p1', 'kw', name: '歌单A'));
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', 'A的第一首', 'kw')],
    );
    await tester.pump();
    expect(find.text('A的第一首'), findsOneWidget);

    await _pumpPage(tester, model, _playlist('p2', 'kw', name: '歌单B'));
    expect(find.text('A的第一首'), findsNothing, reason: 'B 首帧是加载态');
    expect(find.byType(VxLoadingSkeleton), findsOneWidget);
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p2',
      songs: [_song('s2', 'B的第一首', 'kw')],
    );
    await tester.pump();
    expect(find.text('B的第一首'), findsOneWidget);
    expect(find.text('A的第一首'), findsNothing);
  });

  testWidgets('相同 ID 不同 source：缓存隔离互不污染（mobile 版）', (tester) async {
    final model = _RecordingModel();
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: '123',
      songs: [_song('s1', '酷我123', 'kw')],
    );
    await _pumpPage(tester, model, _playlist('123', 'wy'));
    expect(find.text('酷我123'), findsNothing, reason: 'wy 页面不读 kw 槽');
    expect(find.byType(VxLoadingSkeleton), findsOneWidget);
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'wy',
      id: '123',
      songs: [_song('s2', '网易云123', 'wy')],
    );
    await tester.pump();
    expect(find.text('网易云123'), findsOneWidget);
  });

  testWidgets('账号歌单 kind 分命名空间 + 同步入口', (tester) async {
    final model = _RecordingModel();
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'wy',
      id: '900',
      songs: [_song('s1', '公开歌单曲目', 'wy')],
    );
    await _pumpPage(tester, model, _playlist('900', 'wy'), account: true);
    expect(find.text('公开歌单曲目'), findsNothing, reason: '账号页读 account 槽');
    expect(find.byType(VxLoadingSkeleton), findsOneWidget);
    model.debugBrowseLoaded(
      kind: 'account_playlist_detail',
      source: 'wy',
      id: '900',
      songs: [_song('s2', '账号镜像曲目', 'wy')],
    );
    await tester.pump();
    expect(find.text('账号镜像曲目'), findsOneWidget);
    // 更多菜单含同步（账号歌单特有）；点菜单外屏障关闭后再断言消失。
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pump();
    expect(find.text('同步'), findsOneWidget);
    await tester.tapAt(const Offset(10, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('同步'), findsNothing);
  });

  testWidgets('四态：错误+重试（detail 直出原信息，净化口径与桌面一致）', (tester) async {
    final model = _RecordingModel();
    await _pumpPage(tester, model, _playlist('p1', 'kw'));
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      message: '网络不可用',
      failed: true,
    );
    await tester.pump();
    expect(find.byType(VxErrorState), findsOneWidget);
    expect(find.text('歌单加载失败'), findsOneWidget);
    expect(find.text('网络不可用'), findsOneWidget);
    // 重试派发真实命令（page 1）。
    model.commands.clear();
    await tester.tap(find.text('重试'));
    await tester.pump();
    final retries = model.commands
        .whereType<bridge.FfiCommand_PlaylistDetail>();
    expect(retries, isNotEmpty);
    expect(retries.last.page, 1);
    expect(retries.last.playlistId, 'p1');
  });

  testWidgets('四态：空歌单空态 + 播放全部如实禁用', (tester) async {
    final model = _RecordingModel();
    await _pumpPage(tester, model, _playlist('p1', 'kw'));
    model.debugBrowseLoaded(kind: 'playlist_detail', source: 'kw', id: 'p1');
    await tester.pump();
    expect(find.byType(VxEmptyState), findsOneWidget);
    expect(find.text('歌单暂无曲目'), findsOneWidget);
    expect(find.text('暂无可播放曲目'), findsOneWidget);
    // 禁用按钮不派发播放命令。
    model.commands.clear();
    await tester.tap(find.text('暂无可播放曲目'), warnIfMissed: false);
    await tester.pump();
    expect(model.commands.whereType<bridge.FfiCommand_PlaySongs>(), isEmpty);
  });

  testWidgets('四态：notice 能力提示按标题呈现（非错误态）', (tester) async {
    final model = _RecordingModel();
    await _pumpPage(tester, model, _playlist('p1', 'kw'));
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      message: '该音源不支持歌单详情',
    );
    await tester.pump();
    expect(find.text('该音源不支持歌单详情'), findsOneWidget);
    expect(find.byType(VxErrorState), findsNothing);
  });

  testWidgets('播放全部接真实命令（整列 + index 0）；随机播放 index 在已载入域', (tester) async {
    final model = _RecordingModel();
    await _pumpPage(tester, model, _playlist('p1', 'kw'));
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', '第一首', 'kw'), _song('s2', '第二首', 'kw')],
      hasMore: false,
    );
    await tester.pump();

    await tester.tap(find.text('播放全部'));
    await tester.pump();
    final plays = model.commands
        .whereType<bridge.FfiCommand_PlaySongs>()
        .toList();
    expect(plays, hasLength(1));
    expect(plays.single.songs, hasLength(2));
    expect(plays.single.index, 0);

    model.commands.clear();
    await tester.tap(find.text('随机播放'));
    await tester.pump();
    final shuffles = model.commands
        .whereType<bridge.FfiCommand_PlaySongs>()
        .toList();
    expect(shuffles, hasLength(1));
    expect(shuffles.single.songs, hasLength(2));
    expect(shuffles.single.index, inInclusiveRange(0, 1));
  });

  testWidgets('收藏乐观态：失败回滚（§9）', (tester) async {
    final model = _RecordingModel()..errorToReturn = '写入失败';
    await _pumpPage(tester, model, _playlist('p1', 'kw'));
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', '第一首', 'kw')],
    );
    await tester.pump();

    final favButton = find.byTooltip('收藏到本地歌单收藏夹（不写入远端账号）');
    expect(favButton, findsOneWidget);
    await tester.tap(favButton);
    await tester.pump();
    expect(
      model.commands.whereType<bridge.FfiCommand_FavoritePlaylistAdd>(),
      hasLength(1),
    );
    // 失败回滚：pending 清空，tooltip 回到未收藏态。
    await tester.pump();
    expect(find.byTooltip('收藏到本地歌单收藏夹（不写入远端账号）'), findsOneWidget);
    expect(find.byTooltip('取消收藏'), findsNothing);
  });

  testWidgets('收藏乐观态：成功以真实快照确认清 pending', (tester) async {
    final model = _RecordingModel();
    await _pumpPage(tester, model, _playlist('p1', 'kw'));
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', '第一首', 'kw')],
    );
    await tester.pump();

    final favButton = find.byTooltip('收藏到本地歌单收藏夹（不写入远端账号）');
    await tester.tap(favButton);
    await tester.pump();
    expect(
      model.commands.whereType<bridge.FfiCommand_FavoritePlaylistAdd>(),
      hasLength(1),
    );
    // 命令成功（errorToReturn = null），pending 在途：待确认期不可再击。
    expect(find.byTooltip('收藏处理中…'), findsOneWidget);
    // 'library' 事件真实快照确认：镜像出现该歌单 → pending 清除。
    model.debugSetFavoritePlaylists([
      bridge.PlaylistDto(
        id: 'p1',
        name: '歌单kwp1',
        source: 'kw',
        coverUrl: null,
        songCount: 2,
      ),
    ]);
    await tester.pump();
    expect(find.byTooltip('取消收藏'), findsOneWidget);
    expect(find.byTooltip('收藏处理中…'), findsNothing);
  });

  testWidgets('触底分页：加载更多派发 page 2（在线歌单）', (tester) async {
    final model = _RecordingModel();
    await _pumpPage(tester, model, _playlist('p1', 'kw'));
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', '第一首', 'kw'), _song('s2', '第二首', 'kw')],
      page: 1,
      hasMore: true,
    );
    await tester.pump();

    // 触底：footer「加载更多」可见；点击派发 page 2（触底自动续载与按钮
    // 二选一，此处以按钮为确定性入口）。
    expect(find.text('加载更多'), findsOneWidget);
    model.commands.clear();
    await tester.tap(find.text('加载更多'));
    await tester.pump();
    final mores = model.commands.whereType<bridge.FfiCommand_PlaylistDetail>();
    expect(mores, isNotEmpty);
    expect(mores.last.page, 2);
  });

  testWidgets('下拉刷新派发 page 1 重载（§5.6）', (tester) async {
    final model = _RecordingModel();
    await _pumpPage(tester, model, _playlist('p1', 'kw'));
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', '第一首', 'kw')],
      hasMore: false,
    );
    await tester.pump();

    model.commands.clear();
    await _pullToRefresh(tester, find.byType(CustomScrollView));
    final refreshes = model.commands
        .whereType<bridge.FfiCommand_PlaylistDetail>()
        .toList();
    expect(refreshes, isNotEmpty, reason: '下拉刷新触发真实重载');
    expect(refreshes.last.page, 1);
    // 本代次 page=1 响应落槽后刷新 Future 完成（spinner 收起）。
    model.debugBrowseLoaded(
      kind: 'playlist_detail',
      source: 'kw',
      id: 'p1',
      songs: [_song('s1', '第一首', 'kw')],
      hasMore: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });

  testWidgets('360/390/430 视口无横向溢出（§5.6 手机档）', (tester) async {
    for (final size in const [Size(430, 932), Size(390, 844), Size(360, 800)]) {
      final model = _RecordingModel();
      await _pumpPage(
        tester,
        model,
        _playlist('p1', 'kw', name: '一个相当长的歌单名称用来验证两行折行与溢出边界'),
        size: size,
      );
      model.debugBrowseLoaded(
        kind: 'playlist_detail',
        source: 'kw',
        id: 'p1',
        songs: [_song('s1', '第一首', 'kw'), _song('s2', '第二首', 'kw')],
        page: 1,
        hasMore: true,
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: '${size.width} 视口手机歌单详情页无溢出',
      );
      expect(find.text('第一首'), findsOneWidget);
    }
  });
}

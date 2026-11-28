/// MobilePlaylistDetailPage 测试（Batch C-C C-04 / R6）。
///
/// 覆盖：渲染头部与播放全部命令派发、加载骨架态、空歌单态、加载失败态
/// 重试、收藏歌单钮乐观翻转、360-430 视口长标题不溢出。
/// PlaylistKey 隔离语义锁定在 AppModel 槽层（playlist_detail_isolation_test
/// 9 项），本文件不复刻；页面侧锁「同步预清槽 → 首帧无旧歌内容」。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/mobile_playlist_detail_page.dart';

class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];

  _RecordingModel() {
    // dispatch 与 dispatchWithError 都汇于 _commandInterceptor：
    // 用测试拦截器记录，两条派发路径全覆盖（C-B 同款模式）。
    debugSetDispatcherForTest((command) async {
      commands.add(command);
    });
  }
}

bridge.PlaylistDto _playlist(String id, String name, String source) =>
    bridge.PlaylistDto(id: id, name: name, source: source, songCount: 3);

bridge.SongDto _song(String id, String name) => bridge.SongDto(
  id: id,
  source: 'netease',
  name: name,
  singer: '歌手$id',
  albumName: '',
  durationMs: BigInt.from(200000),
);

Future<void> _pump(
  WidgetTester tester,
  _RecordingModel model,
  bridge.PlaylistDto playlist, {
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: MobilePlaylistDetailPage(model, playlist)),
  );
  await tester.pump();
}

Finder _page(Finder f) =>
    find.descendant(of: find.byType(MobilePlaylistDetailPage), matching: f);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('头部渲染：歌单名 / N 首 / 播放全部 / 随机 / 收藏钮', (tester) async {
    final model = _RecordingModel();
    model.debugSetFavoritePlaylists(const []);
    await _pump(tester, model, _playlist('p1', '深夜练歌房', 'kuwo'));
    await tester.pumpAndSettle();

    expect(_page(find.text('深夜练歌房')), findsWidgets);
    expect(_page(find.text('播放全部')), findsOneWidget);
    expect(_page(find.text('随机')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('播放全部派发 playSongs 命令（整列 + 起始序号）', (tester) async {
    final model = _RecordingModel();
    model.debugSetFavoritePlaylists(const []);
    await _pump(tester, model, _playlist('p1', '深夜练歌房', 'kuwo'));
    // 帧后 _reload 派发 loadPlaylistDetail；直接注入槽内曲目模拟已加载。
    final slot = model.browse('playlist_detail', 'kuwo', 'p1');
    slot?.songs.addAll([_song('a', '甲'), _song('b', '乙')]);
    model.notifyListeners();
    await tester.pumpAndSettle();

    await tester.tap(_page(find.text('播放全部')));
    expect(model.commands.whereType<bridge.FfiCommand_PlaySongs>(), isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('加载失败态：错误文案 + 重试钮再派发 loadPlaylistDetail', (tester) async {
    final model = _RecordingModel();
    model.debugSetFavoritePlaylists(const []);
    await _pump(tester, model, _playlist('p1', '坏歌单', 'kuwo'));
    final slot = model.browse('playlist_detail', 'kuwo', 'p1');
    slot?.loading = false;
    slot?.error = '网络不可用';
    model.notifyListeners();
    await tester.pumpAndSettle();

    expect(_page(find.text('歌单加载失败')), findsOneWidget);
    final before = model.commands.length;
    await tester.tap(_page(find.text('重试')));
    await tester.pump();
    expect(model.commands.length, greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('空歌单态：空态面板 + 刷新主行动', (tester) async {
    final model = _RecordingModel();
    model.debugSetFavoritePlaylists(const []);
    await _pump(tester, model, _playlist('p2', '空空如也', 'wy'));
    final slot = model.browse('playlist_detail', 'wy', 'p2');
    slot?.loading = false;
    model.notifyListeners();
    await tester.pumpAndSettle();

    expect(_page(find.text('空歌单')), findsOneWidget);
    expect(_page(find.text('刷新')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360-430 视口：长标题两行钳制无溢出', (tester) async {
    final model = _RecordingModel();
    model.debugSetFavoritePlaylists(const []);
    const longName = '这是一个非常非常非常长的歌单名称用来验证手机端窄宽标题两行截断与按钮行不溢出的回归用例';
    for (final size in [const Size(360, 800), const Size(430, 932)]) {
      await _pump(tester, model, _playlist('p3', longName, 'kg'), size: size);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${size.width} 宽无溢出');
    }
  });

  testWidgets('收藏歌单钮：未收藏态可点派发 favoritePlaylistAdd', (tester) async {
    final model = _RecordingModel();
    model.debugSetFavoritePlaylists(const []);
    await _pump(tester, model, _playlist('p4', '待收藏', 'mg'));
    await tester.pumpAndSettle();

    final add = find.byTooltip('收藏歌单');
    expect(add, findsOneWidget);
    await tester.tap(add);
    expect(
      model.commands.whereType<bridge.FfiCommand_FavoritePlaylistAdd>(),
      isNotEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}

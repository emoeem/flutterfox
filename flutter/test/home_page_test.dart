/// Phase 4 首页测试：
/// - 渲染：问候 + 日期、Continue Listening Hero（有历史 / 无历史两态）；
/// - 空态引导：无历史时 Hero 切换为「搜索在线音乐 / 导入本地音乐」；
/// - S1 断言：旧版 6 大卡片快捷导航（在线歌单/本地音乐/下载/设置等）不再出现；
/// - 最近播放书架渲染 + 双击播放（只派发一次播放命令）；
/// - 我的歌单（真实 customPlaylists）卡片渲染；
/// - 排行榜精选：无能力音源空态、真实榜单数据渲染。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/home_page.dart';

/// 记录派发命令的测试模型（不起 Rust 控制器）。
class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];

  @override
  Future<void> dispatch(bridge.FfiCommand command) async {
    commands.add(command);
  }
}

bridge.SongDto _song(String id, String name, {String singer = '歌手', String source = 'wy'}) =>
    bridge.SongDto(
      id: id,
      source: source,
      name: name,
      singer: singer,
      albumName: '',
      durationMs: BigInt.from(180000),
      coverUrl: null,
    );

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpHome(WidgetTester tester, AppModel model) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: HomePage(model))),
  );
  await tester.pump();
  // 首页 leaderboard 区块在帧后触发浏览请求；再给一帧让状态落地。
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('无历史空态：引导 Hero（搜索/导入）+ 无 6 大卡片快捷导航',
      (tester) async {
    final model = AppModel();
    _useTallViewport(tester);
    await _pumpHome(tester, model);

    // 引导 Hero（按钮短文案防窄窗溢出，完整引导在说明行）。
    expect(find.text('搜索音乐'), findsOneWidget);
    expect(find.text('导入本地'), findsOneWidget);
    // 最近播放分区在有历史时才出现。
    expect(find.text('最近播放'), findsNothing);
    // 我的歌单 / 排行榜分区标题仍在。
    expect(find.text('我的歌单'), findsOneWidget);
    expect(find.text('热门榜单'), findsOneWidget);
    // 我的歌单空态。
    expect(find.text('还没有自建歌单'), findsOneWidget);

    // S1：旧版快捷导航大卡片必须删除。
    expect(find.text('在线歌单'), findsNothing);
    expect(find.text('设置'), findsNothing);
    expect(find.text('下载'), findsNothing);
    expect(find.text('本地音乐'), findsNothing);
  });

  testWidgets('有历史：Hero 展示最近曲目 + 最近播放书架', (tester) async {
    final model = AppModel();
    model.debugSetHistory([
      _song('s1', '夜航'),
      _song('s2', 'Blue Hour', source: 'tx'),
    ]);
    _useTallViewport(tester);
    await _pumpHome(tester, model);

    expect(find.text('CONTINUE LISTENING'), findsOneWidget);
    // Hero 主标题与最近播放书架卡片各一处。
    expect(find.text('夜航'), findsNWidgets(2));
    expect(find.text('继续播放'), findsOneWidget);
    expect(find.text('最近播放'), findsOneWidget);
    // 书架卡片：第二首也在。
    expect(find.text('Blue Hour'), findsOneWidget);
    // 引导按钮不再出现（已切换为内容 Hero）。
    expect(find.text('搜索音乐'), findsNothing);
  });

  testWidgets('双击最近播放卡片：恰好派发一次 playSongs（单击不重复派发）',
      (tester) async {
    final model = _RecordingModel();
    model.debugSetHistory([
      _song('s1', '夜航'),
      _song('s2', 'Blue Hour'),
    ]);
    _useTallViewport(tester);
    await _pumpHome(tester, model);

    // Hero 与书架卡都有「夜航」，点书架卡（尺寸 13 的文本）。
    final cardTitle = find.text('夜航').last;
    await tester.tap(cardTitle);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(cardTitle);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));

    final plays = model.commands.whereType<bridge.FfiCommand_PlaySongs>().toList();
    expect(plays, hasLength(1), reason: '双击应只派发一次播放命令');
  });

  testWidgets('我的歌单：真实 customPlaylists 渲染卡片', (tester) async {
    final model = AppModel();
    model.debugSetHistory([_song('s1', '夜航')]);
    model.debugSetCustomPlaylists([
      bridge.CustomPlaylistSummaryDto(
        id: 'p1',
        name: '深夜开车',
        songCount: 12,
      ),
    ]);
    _useTallViewport(tester);
    await _pumpHome(tester, model);

    expect(find.text('深夜开车'), findsOneWidget);
    expect(find.text('12 首歌曲'), findsOneWidget);
    expect(find.text('还没有自建歌单'), findsNothing);
  });

  testWidgets('排行榜：没有支持音源时显示空态', (tester) async {
    final model = AppModel();
    _useTallViewport(tester);
    await _pumpHome(tester, model);

    expect(find.text('没有支持排行榜的音源'), findsOneWidget);
  });

  testWidgets('排行榜：真实榜单数据渲染为榜单行卡（非统计卡）', (tester) async {
    final model = _RecordingModel();
    model.debugSetSources([
      bridge.SourceCapabilitiesDto(
        id: 'wy',
        name: '网易云',
        playlists: true,
        playlistCategories: true,
        playlistSearch: true,
        album: false,
        artist: false,
        leaderboard: true,
        login: true,
        qrLogin: true,
      ),
    ]);
    _useTallViewport(tester);
    await _pumpHome(tester, model);
    // 帧后已请求榜单目录。
    expect(
      model.commands
          .whereType<bridge.FfiCommand_LeaderboardBoards>()
          .isNotEmpty,
      isTrue,
    );

    model.debugBrowseLoaded(
      kind: 'leaderboard_boards',
      source: 'wy',
      id: '',
      boards: [
        bridge.LeaderboardDto(id: 'b1', name: '飙升榜', source: 'wy'),
        bridge.LeaderboardDto(id: 'b2', name: '热歌榜', source: 'wy'),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('飙升榜'), findsOneWidget);
    expect(find.text('热歌榜'), findsOneWidget);
    // 卡片带音源标识。
    expect(find.text('网易云'), findsWidgets);
  });
}

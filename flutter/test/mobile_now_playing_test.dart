/// Phase 7 第二批：手机全屏播放页（MobileNowPlayingPage）三态切换与手势测试。
///
/// 覆盖（批次验收）：
/// - 三态分层：封面（缺省）/ 歌词（LyricsPanel compact）/ 队列（QueuePanel）
///   切换；无歌空态如实呈现；
/// - 手势：封面层点击或上滑进歌词层；封面层下滑退出整页（onClose）；
/// - 队列层如实呈现禁用的拖拽排序（后端无命令，queue_panel.dart:8-9 现状，
///   不伪造拖拽）；
/// - 复用件：取色背景/封面 crossfade/LiveSeekRow 与桌面 NowPlayingPage
///   同源（桌面并置布局回归由 now_playing_test.dart 覆盖）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/player/lyrics_panel.dart';
import 'package:voicefox_flutter/src/player/mobile_now_playing_page.dart';
import 'package:voicefox_flutter/src/player/now_playing_page.dart';
import 'package:voicefox_flutter/src/player/queue_panel.dart';

bridge.SongDto _song(String id, String name) => bridge.SongDto(
  id: id,
  source: 'netease',
  name: name,
  singer: '测试歌手',
  albumName: '测试专辑',
  durationMs: BigInt.from(244000),
  coverUrl: null,
);

Widget _harness(AppModel model, {VoidCallback? onClose}) {
  return MaterialApp(
    home: MobileNowPlayingPage(model: model, onClose: onClose ?? () {}),
  );
}

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('渲染封面层：封面/歌名/控制行；无歌呈现真实空态', (tester) async {
    _setSize(tester, const Size(390, 844));
    final model = AppModel();
    model.debugSetPlaybackSong(
      id: 's1',
      source: 'netease',
      name: '夜航',
      singer: '测试歌手',
      state: 'paused',
      positionMs: 42000,
      durationMs: 244000,
    );
    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    expect(find.byType(CrossfadeCover), findsOneWidget);
    expect(find.text('夜航'), findsOneWidget);
    // 歌词层/队列层未激活。
    expect(find.byType(LyricsPanel), findsNothing);
    expect(find.byType(QueuePanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无歌空态：未在播放 + 返回应用（不伪造播放内容）', (tester) async {
    _setSize(tester, const Size(390, 844));
    final model = AppModel();
    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    expect(find.text('未在播放'), findsOneWidget);
    expect(find.text('返回应用'), findsOneWidget);
  });

  testWidgets('点击封面进歌词层；顶栏歌词按钮切回封面', (tester) async {
    _setSize(tester, const Size(390, 844));
    final model = AppModel();
    model.debugSetPlaybackSong(
      id: 's1',
      source: 'netease',
      name: '夜航',
      singer: '测试歌手',
      state: 'paused',
      positionMs: 42000,
      durationMs: 244000,
    );
    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    // 点封面区域（避开控制按钮）。
    await tester.tap(find.byType(CrossfadeCover));
    await tester.pumpAndSettle();
    expect(find.byType(LyricsPanel), findsOneWidget);
    // 无歌词数据：如实空态。
    expect(find.text('暂无歌词'), findsOneWidget);

    // 顶栏歌词按钮（激活态）再点一次 → 回封面层。
    await tester.tap(find.byTooltip('歌词层'));
    await tester.pumpAndSettle();
    expect(find.byType(LyricsPanel), findsNothing);
    expect(find.byType(CrossfadeCover), findsOneWidget);
  });

  testWidgets('上滑进歌词层（fling up）', (tester) async {
    _setSize(tester, const Size(390, 844));
    final model = AppModel();
    model.debugSetPlaybackSong(
      id: 's1',
      source: 'netease',
      name: '夜航',
      singer: '测试歌手',
      state: 'paused',
      positionMs: 42000,
      durationMs: 244000,
    );
    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(CrossfadeCover), const Offset(0, -200), 800);
    await tester.pumpAndSettle();
    expect(find.byType(LyricsPanel), findsOneWidget);
  });

  testWidgets('封面层下滑退出整页（onClose）', (tester) async {
    _setSize(tester, const Size(390, 844));
    final model = AppModel();
    model.debugSetPlaybackSong(
      id: 's1',
      source: 'netease',
      name: '夜航',
      singer: '测试歌手',
      state: 'paused',
      positionMs: 42000,
      durationMs: 244000,
    );
    var closed = false;
    await tester.pumpWidget(_harness(model, onClose: () => closed = true));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(CrossfadeCover), const Offset(0, 200), 800);
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });

  testWidgets('歌词层数据呈现（debugSetLyrics 真实歌词行）', (tester) async {
    _setSize(tester, const Size(390, 844));
    final model = AppModel();
    model.debugSetPlaybackSong(
      id: 's1',
      source: 'netease',
      name: '夜航',
      singer: '测试歌手',
      state: 'paused',
      positionMs: 42000,
      durationMs: 244000,
    );
    model.debugSetLyrics(
      bridge.LyricsDto(
        currentLine: 0,
        positionMs: BigInt.zero,
        isEmpty: false,
        lines: [
          bridge.LyricLineDto(
            timestampMs: BigInt.zero,
            durationMs: BigInt.from(10000),
            text: '第一句歌词',
          ),
          bridge.LyricLineDto(
            timestampMs: BigInt.from(10000),
            durationMs: BigInt.from(10000),
            text: '第二句歌词',
          ),
        ],
      ),
    );
    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('歌词层'));
    await tester.pumpAndSettle();
    expect(find.byType(LyricsPanel), findsOneWidget);
    expect(find.text('第一句歌词'), findsOneWidget);
  });

  testWidgets('队列层：QueuePanel 复用；拖拽排序如实禁用并说明（后端无命令）', (tester) async {
    _setSize(tester, const Size(390, 844));
    final model = AppModel();
    model.debugSetPlaybackSong(
      id: 's1',
      source: 'netease',
      name: '夜航',
      singer: '测试歌手',
      state: 'paused',
      positionMs: 42000,
      durationMs: 244000,
    );
    model.debugSetQueue([_song('q1', '队列曲一'), _song('q2', '队列曲二')]);
    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('队列层'));
    await tester.pumpAndSettle();
    expect(find.byType(QueuePanel), findsOneWidget);
    expect(find.text('队列曲一'), findsOneWidget);
    // 拖柄禁用 + 原因说明（queue_panel.dart:194，不伪造拖拽）。
    expect(find.byTooltip('后端暂无队列排序命令，暂不支持拖动排序'), findsWidgets);
  });

  testWidgets('空队列：队列为空态', (tester) async {
    _setSize(tester, const Size(390, 844));
    final model = AppModel();
    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('队列层'));
    await tester.pumpAndSettle();
    expect(find.text('队列为空'), findsOneWidget);
  });
}

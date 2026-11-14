/// Phase 7 第二批：手机全屏播放页（MobileNowPlayingPage）两层切换与手势测试。
///
/// 覆盖（批次验收）：
/// - 两层分层：封面（缺省）/ 歌词（LyricsPanel compact）切换；无歌空态
///   如实呈现；队列走底部 sheet（契约由 queue_interaction_test.dart 锁定）；
/// - 手势：封面层点击或上滑进歌词层；封面层下滑退出整页（onClose）；
///   封面横滑切歌（P2-06：左滑 next / 右滑 previous / 慢速过滤 /
///   拖动中方向提示可见，Cancel 隐藏）；
/// - 歌词点击门槛（§5.7:461）：无时间戳不派发 seekMs 并如实说明，
///   有时间戳才派发；
/// - 复用件：取色背景/封面 crossfade/LiveSeekRow 与桌面 NowPlayingPage
///   同源（桌面并置布局回归由 now_playing_test.dart 覆盖）。
///
/// 注：LyricsPanel 为桌面 ContextPanel 歌词 Tab 共用组件，seek 门槛改动
/// 同样生效于桌面侧（影响范围声明，桌面歌词 Tab 回归由 context_panel
/// 既有测试覆盖呈现语义，门槛断言在本文件 widget 层锁定）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/player/lyrics_panel.dart';
import 'package:voicefox_flutter/src/player/mobile_now_playing_page.dart';
import 'package:voicefox_flutter/src/player/now_playing_page.dart';
import 'package:voicefox_flutter/src/player/progress_control.dart';
import 'package:voicefox_flutter/src/player/queue_panel.dart';

class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];

  @override
  Future<void> dispatch(bridge.FfiCommand command) async {
    commands.add(command);
  }
}

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

  group('封面横滑切歌（P2-06，§5.7 只绑封面区）', () {
    testWidgets('左滑（速度达标）→ 派发 FfiCommand.next', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = _RecordingModel();
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

      await tester.fling(
        find.byType(CrossfadeCover),
        const Offset(-300, 0),
        800,
      );
      await tester.pumpAndSettle();

      expect(
        model.commands.contains(const bridge.FfiCommand.next()),
        isTrue,
        reason: '左滑必须走真实 FfiCommand.next',
      );
      expect(
        model.commands.contains(const bridge.FfiCommand.previous()),
        isFalse,
      );
    });

    testWidgets('右滑（速度达标）→ 派发 FfiCommand.previous', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = _RecordingModel();
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

      await tester.fling(
        find.byType(CrossfadeCover),
        const Offset(300, 0),
        800,
      );
      await tester.pumpAndSettle();

      expect(
        model.commands.contains(const bridge.FfiCommand.previous()),
        isTrue,
        reason: '右滑必须走真实 FfiCommand.previous',
      );
      expect(model.commands.contains(const bridge.FfiCommand.next()), isFalse);
    });

    testWidgets('慢速横滑（速度阈值以下）不切歌', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = _RecordingModel();
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

      await tester.fling(
        find.byType(CrossfadeCover),
        const Offset(-120, 0),
        300,
      );
      await tester.pumpAndSettle();

      expect(
        model.commands.contains(const bridge.FfiCommand.next()),
        isFalse,
        reason: '速度阈值过滤：慢速拖动不得切歌',
      );
      expect(
        model.commands.contains(const bridge.FfiCommand.previous()),
        isFalse,
      );
    });

    testWidgets('拖动中方向提示可见，反向切换，Cancel 隐藏', (tester) async {
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

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CrossfadeCover)),
      );
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-10, 0));
      await tester.pumpAndSettle();
      expect(find.text('下一首'), findsOneWidget, reason: '左拖显示下一首方向提示');

      await gesture.moveBy(const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(find.text('上一首'), findsOneWidget, reason: '反向拖动提示跟随切换');
      expect(find.text('下一首'), findsNothing);

      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(find.text('上一首'), findsNothing, reason: 'Cancel 必须隐藏方向提示');
      expect(find.text('下一首'), findsNothing);
    });
  });

  group('歌词点击门槛（§5.7:461）', () {
    testWidgets('歌词无时间戳：点击行不派发 seekMs，并如实说明', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = _RecordingModel();
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
          ],
        ),
      );
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('歌词层'));
      await tester.pumpAndSettle();
      expect(find.byType(LyricsPanel), findsOneWidget);

      await tester.tap(find.text('第一句歌词'));
      await tester.pumpAndSettle();

      expect(
        model.commands.where((c) => c == bridge.FfiCommand.seekMs(BigInt.zero)),
        isEmpty,
        reason: '无时间戳歌词不得派发 seekMs',
      );
      expect(find.text('本曲歌词无时间戳，不支持点击跳转'), findsOneWidget);
    });

    testWidgets('歌词有时间戳：点击行派发真实 seekMs', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = _RecordingModel();
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

      await tester.tap(find.text('第二句歌词'));
      await tester.pumpAndSettle();

      expect(
        model.commands.contains(bridge.FfiCommand.seekMs(BigInt.from(10000))),
        isTrue,
        reason: '有时间戳歌词行点击必须走真实 seekMs',
      );
      // 有时间戳时不出现门槛说明。
      expect(find.text('本曲歌词无时间戳，不支持点击跳转'), findsNothing);
    });
  });

  group('LiveSeekRow 拖动 seek 契约（§5.1 点按/拖动真实 seek）', () {
    testWidgets('有 duration：横拖到中点派发真实 seekMs 目标值', (tester) async {
      final model = _RecordingModel();
      model.debugSetPlaybackSong(
        id: 's1',
        source: 'netease',
        name: '夜航',
        singer: '测试歌手',
        state: 'paused',
        positionMs: 0,
        durationMs: 244000,
      );
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      final bar = find
          .descendant(
            of: find.byType(LiveSeekRow),
            matching: find.byType(GestureDetector),
          )
          .last;
      final rect = tester.getRect(bar);
      // fraction 分母是 LiveSeekRow 的行宽（外层 LayoutBuilder，含两侧
      // 时间标签），非拖拽条宽：拖行宽一半即 0.5 相位 → 122000ms。
      final rowWidth = tester
          .getSize(
            find
                .descendant(
                  of: find.byType(LiveSeekRow),
                  matching: find.byType(LayoutBuilder),
                )
                .first,
          )
          .width;
      await tester.dragFrom(
        Offset(rect.left, rect.center.dy),
        Offset(rowWidth / 2, 0),
      );
      await tester.pumpAndSettle();

      expect(
        model.commands.where(
          (c) => c == bridge.FfiCommand.seekMs(BigInt.from(122000)),
        ),
        hasLength(1),
        reason: '拖动到中点必须派发 244000×0.5=122000ms 的真实 seekMs',
      );
    });

    testWidgets('无 duration：手势禁用不派发 seekMs，右标签如实显 --:--', (tester) async {
      final model = _RecordingModel();
      model.debugSetPlaybackSong(
        id: 's1',
        source: 'netease',
        name: '夜航',
        singer: '测试歌手',
        state: 'paused',
        positionMs: 0,
        durationMs: 0,
      );
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      // 时长读不到（durationMs=0）显 --:--（P0-F1），不伪造 00:00。
      expect(find.text('--:--'), findsOneWidget);

      final bar = find
          .descendant(
            of: find.byType(LiveSeekRow),
            matching: find.byType(GestureDetector),
          )
          .last;
      await tester.drag(bar, const Offset(120, 0));
      await tester.pumpAndSettle();

      expect(
        model.commands.where((c) => c == bridge.FfiCommand.seekMs(BigInt.zero)),
        isEmpty,
        reason: '无 duration 手势回调全 null，不得派发 seekMs',
      );
    });
  });
}

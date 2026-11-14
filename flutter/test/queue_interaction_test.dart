/// Phase 4 队列 sheet 交互契约（§5.7:452「底部 sheet」；P2-09 维持）。
///
/// 锁定（自 mobile_now_playing_test.dart 队列层两用例迁入 + sheet 扩展）：
/// - 顶栏队列按钮 → showModalBottomSheet 打开（QueuePanel 在树），打开
///   期间按钮保持激活态（队列不再占页内 layer，MobileNowPlayingLayer 无
///   queue 值）；
/// - 关闭：DragHandle 下滑（唯一主动收起入口——QueuePanel 为
///   Column+Expanded(ListView) 定高依赖，DraggableScrollableSheet 不兼容，
///   列表滚动不收起）/ 点遮罩关闭，回封面层且按钮退出激活态；
/// - 真实命令路径：清空（二次确认对话流）/ 移出队列 / 随机切换
///   （_RecordingModel dispatch 断言）；
/// - 空队列态；拖拽排序如实禁用并说明（后端无命令，queue_panel.dart
///   头注现状，不伪造拖拽）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/config_ext.dart';
import 'package:voicefox_flutter/src/player/mobile_now_playing_page.dart';
import 'package:voicefox_flutter/src/player/now_playing_page.dart';
import 'package:voicefox_flutter/src/player/queue_panel.dart';

class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];

  @override
  Future<void> dispatch(bridge.FfiCommand command) async {
    commands.add(command);
  }
}

bridge.SongDto _song(String id, String name) => bridge.SongDto(
  id: id,
  source: 'netease',
  name: name,
  singer: '测试歌手',
  albumName: '测试专辑',
  durationMs: BigInt.from(244000),
  coverUrl: null,
);

bridge.ConfigDto _config() => bridge.ConfigDto(
  theme: 'catppuccin-mocha',
  dynamicColor: false,
  themeMode: 'system',
  volume: 100,
  playbackSpeed: 1.0,
  playMode: 'none',
  historyLimit: 100,
  defaultSource: 'kw',
  enabledSources: const ['kw'],
  jsSourcesFirst: false,
  downloadDir: '/tmp',
  downloadQuality: null,
  downloadConcurrency: 2,
  showTranslation: true,
  showYrc: false,
  lyricOffsetMs: 0,
  proxyUrl: '',
  networkTimeoutSecs: BigInt.from(30),
  localMusicEnabled: true,
  localMusicPaths: const [],
  localMusicMaxDepth: 0,
);

Widget _harness(AppModel model) {
  return MaterialApp(
    home: MobileNowPlayingPage(model: model, onClose: () {}),
  );
}

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip('播放队列'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('顶栏队列按钮 → 底部 sheet 打开（QueuePanel 在树）且按钮激活', (tester) async {
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

    await _openSheet(tester);
    expect(find.byType(QueuePanel), findsOneWidget);
    expect(find.text('队列曲一'), findsOneWidget);
    expect(find.text('队列曲二'), findsOneWidget);
    // 打开期间顶栏队列按钮保持激活态（不留下永久灰置按钮）。
    final context = tester.element(find.byTooltip('播放队列'));
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byTooltip('播放队列'),
        matching: find.byIcon(Icons.queue_music_outlined),
      ),
    );
    expect(icon.color, Theme.of(context).colorScheme.primary);
  });

  testWidgets('DragHandle 下滑关闭 sheet → 回封面层', (tester) async {
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
    model.debugSetQueue([_song('q1', '队列曲一')]);
    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    await _openSheet(tester);
    expect(find.byType(QueuePanel), findsOneWidget);

    await tester.fling(
      find.byKey(const ValueKey('queue_sheet_drag_handle')),
      const Offset(0, 200),
      600,
    );
    await tester.pumpAndSettle();
    expect(find.byType(QueuePanel), findsNothing);
    expect(find.byType(CrossfadeCover), findsOneWidget, reason: '回封面层');
  });

  testWidgets('点遮罩关闭 sheet → 回封面层', (tester) async {
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
    model.debugSetQueue([_song('q1', '队列曲一')]);
    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    await _openSheet(tester);
    expect(find.byType(QueuePanel), findsOneWidget);

    // sheet 高 0.75×屏高，上方为遮罩区。
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(find.byType(QueuePanel), findsNothing);
    expect(find.byType(CrossfadeCover), findsOneWidget);
  });

  testWidgets('清空队列：二次确认对话流；取消不派发，确认派发 queueClear', (tester) async {
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
    model.debugSetQueue([_song('q1', '队列曲一'), _song('q2', '队列曲二')]);
    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    await _openSheet(tester);
    await tester.tap(find.byTooltip('清空队列'));
    await tester.pumpAndSettle();
    // 确认对话如实说明当前曲继续播放。
    expect(find.text('清空播放队列'), findsOneWidget);
    expect(find.text('将移除队列中的全部待播歌曲；当前歌曲不受影响，继续播放。'), findsOneWidget);

    // 取消：不派发。
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
      model.commands.contains(const bridge.FfiCommand.queueClear()),
      isFalse,
      reason: '取消清空不得派发 queueClear',
    );

    // 确认：派发真实命令。
    await tester.tap(find.byTooltip('清空队列'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    expect(
      model.commands.contains(const bridge.FfiCommand.queueClear()),
      isTrue,
      reason: '清空必须走真实 FfiCommand.queueClear',
    );
  });

  testWidgets('移出队列：行菜单派发 queueRemove(index)', (tester) async {
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
    model.debugSetQueue([_song('q1', '队列曲一'), _song('q2', '队列曲二')]);
    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    await _openSheet(tester);
    // 待播行（队列曲二，index 1）的行菜单。
    await tester.tap(find.byTooltip('更多操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移出队列'));
    await tester.pumpAndSettle();

    expect(
      model.commands.contains(bridge.FfiCommand.queueRemove(index: 1)),
      isTrue,
      reason: '移出队列必须走真实 FfiCommand.queueRemove',
    );
  });

  testWidgets('随机切换：派发 configUpdate（playMode → random）', (tester) async {
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
    model.debugSetConfig(_config());
    model.debugSetQueue([_song('q1', '队列曲一')]);
    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    await _openSheet(tester);
    // 全屏封面层 VxPlayerControls 也有同名随机按钮，限定 sheet 内 QueuePanel。
    await tester.tap(
      find.descendant(
        of: find.byType(QueuePanel),
        matching: find.byTooltip('随机播放'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      model.commands.contains(
        bridge.FfiCommand.configUpdate(
          config: _config().copyWith(playMode: 'random'),
        ),
      ),
      isTrue,
      reason: '随机开关必须走真实 configUpdate（updateConfig → dispatch）',
    );
  });

  testWidgets('空队列：sheet 内队列为空态', (tester) async {
    _setSize(tester, const Size(390, 844));
    final model = AppModel();
    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    await _openSheet(tester);
    expect(find.text('队列为空'), findsOneWidget);
  });

  testWidgets('拖拽排序如实禁用并说明（后端无命令，不伪造拖拽）', (tester) async {
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

    await _openSheet(tester);
    // 拖柄禁用 + 原因说明（queue_panel.dart:194）。
    final handles = find.byTooltip('后端暂无队列排序命令，暂不支持拖动排序');
    expect(handles, findsWidgets);
    final iconButton = tester.widget<IconButton>(
      find.ancestor(of: handles.first, matching: find.byType(IconButton)),
    );
    expect(iconButton.onPressed, isNull);
  });
}

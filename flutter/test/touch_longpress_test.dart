/// Phase 7 触屏长按菜单测试（计划 §9 语义：长按替代右键 / hover 操作）。
///
/// 覆盖（批次验收）：
/// - SongTrackRow 长按弹出完整歌曲菜单，菜单项接真实命令（_RecordingModel
///   断言 FfiCommand）；菜单含 hover 操作的可达替代（立即播放/加入队列/
///   收藏/下载 全部在菜单内）；
/// - SongTile 长按同样弹菜单；
/// - 桌面右键（onSecondaryTapUp）行为回归不变：仍弹同一份菜单。
///
/// 无控制器时命令走 _RecordingModel；真实 AppModel 无控制器时 dispatch
/// 安全返回错误串（app_model.dart `_sendCommand`），空操作如实反馈。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/song_tile.dart';

/// 记录命令的 AppModel：真实命令路径 + 可断言（对齐 now_playing_test）。
class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];

  @override
  Future<void> dispatch(bridge.FfiCommand command) async {
    commands.add(command);
  }
}

bridge.SongDto _song() => bridge.SongDto(
  id: 's1',
  source: 'netease',
  name: '夜航',
  singer: '测试歌手',
  albumName: '测试专辑',
  durationMs: BigInt.from(244000),
  coverUrl: null,
);

Future<void> _longPressRow(WidgetTester tester) async {
  final row = find.text('夜航');
  final center = tester.getCenter(row.first);
  // 长按 600ms（默认 longPressTimeout 500ms）。
  final gesture = await tester.startGesture(center);
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('SongTrackRow 长按弹出菜单，菜单项接真实命令（加入队列）', (tester) async {
    final model = _RecordingModel();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SongTrackRow(model, _song()))),
    );

    await _longPressRow(tester);
    // 菜单本体出现，且聚合 hover 操作的触屏替代项。
    expect(find.text('立即播放'), findsOneWidget);
    expect(find.text('下一首播放'), findsOneWidget);
    expect(find.text('加入队列'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('下载'), findsOneWidget);

    await tester.tap(find.text('加入队列'));
    await tester.pump();
    expect(
      model.commands.any(
        (c) => c == bridge.FfiCommand.queueAdd(song: _song(), next: false),
      ),
      isTrue,
      reason: '长按菜单「加入队列」必须走真实 FfiCommand',
    );
  });

  testWidgets('SongTrackRow 长按菜单「立即播放」接真实播放命令', (tester) async {
    final model = _RecordingModel();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SongTrackRow(model, _song()))),
    );

    await _longPressRow(tester);
    await tester.tap(find.text('立即播放'));
    await tester.pump();
    expect(
      model.commands.contains(bridge.FfiCommand.playSong(song: _song())),
      isTrue,
      reason: '长按菜单「立即播放」必须走真实 FfiCommand.play',
    );
  });

  testWidgets('SongTile 长按弹出菜单并可接真实命令（收藏）', (tester) async {
    final model = _RecordingModel();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SongTile(model, _song()))),
    );

    await _longPressRow(tester);
    expect(find.text('加入队列'), findsOneWidget);
    await tester.tap(find.text('收藏'));
    await tester.pump();
    expect(
      model.commands.contains(bridge.FfiCommand.favoritesAdd(song: _song())),
      isTrue,
      reason: 'SongTile 长按菜单「收藏」必须走真实 FfiCommand（未收藏 → favoritesAdd）',
    );
  });

  testWidgets('桌面右键行为回归不变：onSecondaryTapUp 弹同一份菜单', (tester) async {
    final model = _RecordingModel();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SongTrackRow(model, _song()))),
    );

    final center = tester.getCenter(find.text('夜航').first);
    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('立即播放'), findsOneWidget);
    expect(find.text('下载'), findsOneWidget);
  });
}

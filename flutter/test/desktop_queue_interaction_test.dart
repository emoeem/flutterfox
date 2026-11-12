/// Phase 6 桌面歌单表 / 队列交互核验（§7.6 / §12.3:1013）。
///
/// W2 结论（评审修正后口径）：桌面右键菜单与「下一首播放」真实后端命令
/// **早已实现**——showSongMenu（song_tile.dart）是唯一菜单本体，三个触发
/// 入口（桌面右键 onSecondaryTapUp / 触屏长按 / 行尾「更多」）走同一份
/// 菜单与命令接线；「下一首播放」接的是真实 FfiCommand.queueAdd(next:true)
/// （非禁用项）。本文件核验该既有覆盖，**不新建第二份菜单**。
///
/// 锁定：
/// - 桌面 VxSongTable 行右键 → showSongMenu 菜单 §7.6 清单全覆盖；
/// - 「下一首播放」/「加入队列」/双击 → 真实 FfiCommand（_RecordingModel
///   断言，与 queue_interaction_test.dart 同模式）；
/// - 桌面 ContextPanel 队列 Tab（QueuePanel 桌面挂载形态）：当前曲高亮
///   与 queueIndex 同步、移出队列/清空二次确认真实命令、拖动排序与队内
///   跳播/移动如实禁用并说明（P2-09 口径，不伪造）；
/// - VxTrackRow 密度 50/58/66 与 §7.6「行高 56–64」带的登记冲突
///   （standard 在带内，compact/comfortable 越界）按矩阵偏差口径锁定。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/design_system/components/vx_track_row.dart';
import 'package:voicefox_flutter/src/myune/page/setting/settings_provider.dart';
import 'package:voicefox_flutter/src/myune/services/notification_service.dart';
import 'package:voicefox_flutter/src/player/queue_panel.dart';
import 'package:voicefox_flutter/src/shell/app_shell.dart';
import 'package:voicefox_flutter/src/shell/context_panel.dart';
import 'package:voicefox_flutter/src/widgets/song_table_view.dart';

/// dispatch 只记录不执行（与 queue_interaction_test.dart 同模式）。
class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];

  @override
  Future<void> dispatch(bridge.FfiCommand command) async {
    commands.add(command);
  }
}

bridge.SongDto _song(String id, String name) => bridge.SongDto(
  id: id,
  source: 'kw',
  name: name,
  singer: '测试歌手',
  albumName: '测试专辑',
  durationMs: BigInt.from(244000),
  coverUrl: null,
);

Widget _tableHarness(AppModel model, List<bridge.SongDto> songs) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppModel>.value(value: model),
        ChangeNotifierProvider<SettingsProvider>.value(
          value: SettingsProvider(),
        ),
        ChangeNotifierProvider<NotificationService>.value(
          value: NotificationService(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: VxSongTable(model: model, songs: songs),
        ),
      ),
    );

Widget _shellHarness(AppModel model) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AppModel>.value(value: model),
    ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
    ChangeNotifierProvider<NotificationService>.value(
      value: NotificationService(),
    ),
  ],
  child: MaterialApp(home: VoicefoxShell(model: model)),
);

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('桌面 VxSongTable 右键菜单（既有 showSongMenu 核验，不新建菜单）', () {
    testWidgets('§7.6 清单全覆盖：播放/下一首播放/加入队列/加入歌单/喜欢/下载/详情', (tester) async {
      _setSize(tester, const Size(1440, 900));
      final model = _RecordingModel();
      final songs = [_song('t1', '桌面曲一'), _song('t2', '桌面曲二')];
      await tester.pumpWidget(_tableHarness(model, songs));
      await tester.pumpAndSettle();

      // 行右键（onSecondaryTapUp → showSongMenu，song_tile.dart 既有接线）。
      await tester.tap(find.text('桌面曲一'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('立即播放'), findsOneWidget);
      expect(find.text('下一首播放'), findsOneWidget);
      expect(find.text('加入队列'), findsOneWidget);
      expect(find.text('加入歌单'), findsOneWidget);
      // §8.5：收藏入口注明写本地曲库。
      expect(find.text('收藏（本地曲库）'), findsOneWidget);
      expect(find.text('下载'), findsOneWidget);
      // 详情：无后端能力位时如实标注「该音源不支持」（诚实禁用）。
      expect(find.textContaining('查看歌手'), findsOneWidget);
      expect(find.textContaining('查看专辑'), findsOneWidget);
    });

    testWidgets('右键「下一首播放」→ 真实命令 FfiCommand.queueAdd(next: true)', (
      tester,
    ) async {
      _setSize(tester, const Size(1440, 900));
      final model = _RecordingModel();
      final song = _song('t1', '桌面曲一');
      await tester.pumpWidget(_tableHarness(model, [song]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('桌面曲一'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一首播放'));
      await tester.pumpAndSettle();

      expect(
        model.commands.contains(
          bridge.FfiCommand.queueAdd(song: song, next: true),
        ),
        isTrue,
        reason: '「下一首播放」是已接线的真实后端命令（评审修正：不得按禁用项处理）',
      );
    });

    testWidgets('右键「加入队列」→ FfiCommand.queueAdd(next: false)', (tester) async {
      _setSize(tester, const Size(1440, 900));
      final model = _RecordingModel();
      final song = _song('t1', '桌面曲一');
      await tester.pumpWidget(_tableHarness(model, [song]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('桌面曲一'), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('加入队列'));
      await tester.pumpAndSettle();

      expect(
        model.commands.contains(
          bridge.FfiCommand.queueAdd(song: song, next: false),
        ),
        isTrue,
      );
    });

    testWidgets('双击行 → FfiCommand.playSong', (tester) async {
      _setSize(tester, const Size(1440, 900));
      final model = _RecordingModel();
      final song = _song('t1', '桌面曲一');
      await tester.pumpWidget(_tableHarness(model, [song]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('桌面曲一'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('桌面曲一'));
      await tester.pumpAndSettle();

      expect(
        model.commands.contains(bridge.FfiCommand.playSong(song: song)),
        isTrue,
        reason: '双击播放是桌面歌单表既有交互（外层/行内双击同命令）',
      );
    });
  });

  group('桌面 ContextPanel 队列 Tab（QueuePanel 桌面挂载形态）', () {
    Future<void> openQueuePanel(WidgetTester tester, AppModel model) async {
      _setSize(tester, const Size(1440, 900));
      await tester.pumpWidget(_shellHarness(model));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('队列面板'));
      await tester.pumpAndSettle();
    }

    testWidgets('当前曲高亮与 queueIndex 同步；拖动排序如实禁用并说明', (tester) async {
      final model = _RecordingModel();
      model.debugSetPlaybackSong(
        id: 'q1',
        source: 'kw',
        name: '队列曲一',
        singer: '测试歌手',
        state: 'paused',
        positionMs: 42000,
        durationMs: 244000,
      );
      model.debugSetQueue([
        _song('q1', '队列曲一'),
        _song('q2', '队列曲二'),
        _song('q3', '队列曲三'),
      ], index: 1);
      await openQueuePanel(tester, model);

      expect(find.byType(QueuePanel), findsOneWidget);
      expect(find.byType(ContextPanel), findsOneWidget);
      // 当前曲（queueIndex=1 → 队列曲二）行内均衡器图标恰好 1 处：
      // 高亮跟随 queueIndex，不随播放位漂移。
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
      // 拖动排序：后端无命令，禁用 + 说明（P2-09 口径，不伪造拖拽）。
      // byTooltip 命中的是 Tooltip widget，其祖先才是 IconButton。
      final dragHandle = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byTooltip('后端暂无队列排序命令，暂不支持拖动排序'),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(dragHandle.onPressed, isNull);
    });

    testWidgets('移出队列 → FfiCommand.queueRemove(index)；清空二次确认 → queueClear', (
      tester,
    ) async {
      final model = _RecordingModel();
      model.debugSetPlaybackSong(
        id: 'q1',
        source: 'kw',
        name: '队列曲一',
        singer: '测试歌手',
        state: 'paused',
        positionMs: 42000,
        durationMs: 244000,
      );
      model.debugSetQueue([_song('q1', '队列曲一'), _song('q2', '队列曲二')]);
      await openQueuePanel(tester, model);

      // 首行「更多操作」→ 移出队列（真实命令，索引 0）。
      await tester.tap(find.byTooltip('更多操作').first);
      await tester.pumpAndSettle();
      // 队内跳播/移动类菜单项如实禁用（后端无命令）。
      expect(find.text('后端暂无队列跳播命令'), findsOneWidget);
      expect(find.text('后端暂无队列移动命令'), findsOneWidget);
      await tester.tap(find.text('移出队列'));
      await tester.pumpAndSettle();
      expect(
        model.commands.contains(bridge.FfiCommand.queueRemove(index: 0)),
        isTrue,
      );

      // 清空：二次确认对话流（确认路径；取消路径由 queue_interaction_test 锁定）。
      await tester.tap(find.byTooltip('清空队列'));
      await tester.pumpAndSettle();
      expect(find.text('清空播放队列'), findsOneWidget);
      // 确认按钮是 FilledButton(Text('清空'))，与 queue_interaction_test 同款。
      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();
      expect(model.commands.contains(bridge.FfiCommand.queueClear()), isTrue);
    });
  });

  group('VxTrackRow 密度带登记冲突（§7.6 行高 56–64）', () {
    test('standard 58 在带内；compact 50 / comfortable 66 越界（矩阵偏差口径锁定）', () {
      // §7.6 要求 56–64；实现三档密度 50/58/66（vx_track_row.dart）。
      // 只改 standard 档之外的档位会影响移动端复用组件，按矩阵登记偏差
      // 处理（Phase 6 不动实现），本断言锁登记口径防止漂移。
      expect(VxTrackRowDensity.standard.height, 58);
      expect(VxTrackRowDensity.compact.height, 50);
      expect(VxTrackRowDensity.comfortable.height, 66);
      expect(
        VxTrackRowDensity.standard.height >= 56 &&
            VxTrackRowDensity.standard.height <= 64,
        isTrue,
        reason: '桌面歌单表缺省 standard 档落在 §7.6 56–64 带内',
      );
    });
  });
}

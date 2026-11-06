/// Phase 3 NowPlaying / LyricsPanel / QueuePanel widget 测试（计划书 Phase 3 验收）。
///
/// 覆盖：全屏页渲染与返回、Shell 集成（打开时 PlayerBar 隐藏、Esc 恢复）、
/// 歌词当前行高亮与点击 seek、歌词/队列空态、队列移除/清空确认（真实命令）、
/// 后端缺失能力的禁用项（拖动排序/下一首播放/立即播放）、时长未知 `--:--`。
///
/// 不起 Rust 控制器：_RecordingModel 记录 dispatch 命令做断言（seek/移除/
/// 清空都是真实命令路径，仅控制器替换为记录器）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/myune/page/setting/settings_provider.dart';
import 'package:voicefox_flutter/src/myune/services/notification_service.dart';
import 'package:voicefox_flutter/src/player/now_playing_page.dart';
import 'package:voicefox_flutter/src/player/player_bar.dart';
import 'package:voicefox_flutter/src/player/queue_panel.dart';
import 'package:voicefox_flutter/src/shell/app_shell.dart';

/// 记录命令的 AppModel：真实命令路径 + 可断言。
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

bridge.LyricsDto _lyrics() => bridge.LyricsDto(
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
        bridge.LyricLineDto(
          timestampMs: BigInt.from(20000),
          durationMs: BigInt.from(10000),
          text: '第三句歌词',
        ),
      ],
    );

Widget _pageHarness(AppModel model, {VoidCallback? onClose}) {
  return MaterialApp(
    home: Scaffold(
      body: NowPlayingPage(
        model: model,
        onClose: onClose ?? () {},
      ),
    ),
  );
}

Widget _shellHarness(AppModel model) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppModel>.value(value: model),
      ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
      ChangeNotifierProvider<NotificationService>.value(
        value: NotificationService(),
      ),
    ],
    child: MaterialApp(home: VoicefoxShell(model: model)),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('NowPlayingPage 渲染与返回', () {
    testWidgets('渲染：曲名/歌手/返回区/NOW PLAYING，无 myune 标题栏', (tester) async {
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
      await tester.pumpWidget(_pageHarness(model));
      await tester.pumpAndSettle();

      expect(find.text('夜航'), findsOneWidget);
      // debugSetPlaybackSong 的 albumName 为空 → 元信息回退「歌手 · 音源」。
      expect(find.text('测试歌手 · netease'), findsOneWidget);
      expect(find.text('NOW PLAYING'), findsOneWidget);
      expect(find.byType(NowPlayingPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('无歌曲：空态如实呈现，返回动作可用', (tester) async {
      var closed = false;
      final model = AppModel();
      await tester.pumpWidget(
        _pageHarness(model, onClose: () => closed = true),
      );
      await tester.pumpAndSettle();

      expect(find.text('未在播放'), findsWidgets);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });

    testWidgets('顶部返回按钮触发 onClose', (tester) async {
      var closed = false;
      final model = AppModel();
      model.debugSetPlaybackSong(
        id: 's1',
        source: 'netease',
        name: '夜航',
        singer: '测试歌手',
        state: 'paused',
      );
      await tester.pumpWidget(
        _pageHarness(model, onClose: () => closed = true),
      );
      await tester.pumpAndSettle();

      // 顶部返回区（首个「返回应用」是 TextButton.icon，空态才有 FilledButton）。
      await tester.tap(find.text('返回应用').first);
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });

    testWidgets('时长未知：时间显示 --:--（P0-F1 不伪造 00:00）', (tester) async {
      final model = AppModel();
      model.debugSetPlaybackSong(
        id: 's1',
        source: 'netease',
        name: '夜航',
        singer: '测试歌手',
        state: 'paused',
        positionMs: 0,
        durationMs: 0,
      );
      await tester.pumpWidget(_pageHarness(model));
      await tester.pumpAndSettle();

      expect(find.text('--:--'), findsOneWidget);
    });
  });

  group('Shell 集成：全屏进出与 PlayerBar 隐藏', () {
    testWidgets('点播放栏封面进全屏：PlayerBar 从树中移除；Esc 返回后恢复',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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
      await tester.pumpWidget(_shellHarness(model));
      await tester.pumpAndSettle();

      expect(find.byType(PlayerBar), findsOneWidget);
      expect(find.byType(NowPlayingPage), findsNothing);

      // 点播放栏封面 → 全屏播放页；PlayerBar 不进树（§5.1 防双重控制）。
      await tester.tap(
        find.descendant(
          of: find.byType(PlayerBar),
          matching: find.byType(ClipRRect),
        ).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingPage), findsOneWidget);
      expect(find.byType(PlayerBar), findsNothing);
      expect(find.text('NOW PLAYING'), findsOneWidget);

      // Esc → 返回主界面，PlayerBar 恢复。
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingPage), findsNothing);
      expect(find.byType(PlayerBar), findsOneWidget);
    });
  });

  group('歌词面板', () {
    testWidgets('当前行高亮：26-32px w600（全屏 32px），插值位置驱动', (tester) async {
      final model = AppModel();
      model.debugSetPlaybackSong(
        id: 's1',
        source: 'netease',
        name: '夜航',
        singer: '测试歌手',
        state: 'paused',
        positionMs: 12000,
        durationMs: 244000,
      );
      model.debugSetLyrics(_lyrics());
      await tester.pumpWidget(_pageHarness(model));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('第二句歌词'));
      final style = DefaultTextStyle.of(context).style;
      expect(style.fontSize, 32, reason: '全屏当前行 26-32px 规范取 32');
      expect(style.fontWeight, FontWeight.w600);
      // 相邻行降字号降透明。
      final nearContext = tester.element(find.text('第一句歌词'));
      final nearStyle = DefaultTextStyle.of(nearContext).style;
      expect(nearStyle.fontSize, 20);
      expect(nearStyle.fontWeight, FontWeight.w400);
    });

    testWidgets('点击歌词行 → 真实 seekMs 命令', (tester) async {
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
      model.debugSetLyrics(_lyrics());
      await tester.pumpWidget(_pageHarness(model));
      await tester.pumpAndSettle();

      await tester.tap(find.text('第三句歌词'));
      await tester.pumpAndSettle();

      final seeks = model.commands.whereType<bridge.FfiCommand_SeekMs>().toList();
      expect(seeks, hasLength(1));
      expect(seeks.first.field0, BigInt.from(20000));
    });

    testWidgets('无歌词：空态如实说明（后端无重取命令，不伪造重试按钮）',
        (tester) async {
      final model = AppModel();
      model.debugSetPlaybackSong(
        id: 's1',
        source: 'netease',
        name: '夜航',
        singer: '测试歌手',
        state: 'paused',
      );
      model.debugSetLyrics(
        bridge.LyricsDto(
          currentLine: 0,
          positionMs: BigInt.zero,
          lines: const [],
          isEmpty: true,
        ),
      );
      await tester.pumpWidget(_pageHarness(model));
      await tester.pumpAndSettle();

      expect(find.text('暂无歌词'), findsOneWidget);
      expect(find.text('重试'), findsNothing);
    });
  });

  group('队列面板', () {
    testWidgets('空队列态', (tester) async {
      final model = AppModel();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 320, child: QueuePanel(model: model)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('队列为空'), findsOneWidget);
    });

    testWidgets('当前曲分组 + 待播列表渲染', (tester) async {
      final model = AppModel();
      model.debugSetQueue(
        [_song('a', '第一首'), _song('b', '第二首'), _song('c', '第三首')],
        index: 0,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 320, child: QueuePanel(model: model)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('当前播放'), findsOneWidget);
      expect(find.text('接下来播放 · 2 首'), findsOneWidget);
      expect(find.text('第一首'), findsOneWidget);
      expect(find.text('第三首'), findsOneWidget);
    });

    testWidgets('行菜单「移出队列」→ 真实 queueRemove 命令', (tester) async {
      final model = _RecordingModel();
      model.debugSetQueue(
        [_song('a', '第一首'), _song('b', '第二首'), _song('c', '第三首')],
        index: 0,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 320, child: QueuePanel(model: model)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 打开第一行待播曲（index 1）的行菜单；.at(0) 是当前播放行。
      await tester.tap(find.byTooltip('更多操作').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('移出队列'));
      await tester.pumpAndSettle();

      final removes =
          model.commands.whereType<bridge.FfiCommand_QueueRemove>().toList();
      expect(removes, hasLength(1));
      expect(removes.first.index, 1);
    });

    testWidgets('清空队列：二次确认后下发 queueClear', (tester) async {
      final model = _RecordingModel();
      model.debugSetQueue([_song('a', '第一首'), _song('b', '第二首')], index: 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 320, child: QueuePanel(model: model)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('清空队列'));
      await tester.pumpAndSettle();
      expect(find.text('清空播放队列'), findsOneWidget);
      // 确认文案说明当前曲继续播放（§5.3）。
      expect(find.textContaining('当前歌曲不受影响'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '清空'));
      await tester.pumpAndSettle();
      expect(
        model.commands.whereType<bridge.FfiCommand_QueueClear>(),
        hasLength(1),
      );
    });

    testWidgets('后端缺失能力：拖动排序拖柄禁用；行菜单 立即播放/下一首播放 禁用并说明',
        (tester) async {
      final model = AppModel();
      model.debugSetQueue(
        [_song('a', '第一首'), _song('b', '第二首'), _song('c', '第三首')],
        index: 0,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 320, child: QueuePanel(model: model)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final handle = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.drag_indicator),
          matching: find.byType(IconButton),
        ).first,
      );
      expect(handle.onPressed, isNull);

      await tester.tap(find.byTooltip('更多操作').first);
      await tester.pumpAndSettle();
      final playNow = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, '立即播放'),
      );
      final playNext = tester.widget<PopupMenuItem<String>>(
        find.widgetWithText(PopupMenuItem<String>, '下一首播放'),
      );
      expect(playNow.enabled, isFalse);
      expect(playNext.enabled, isFalse);
      expect(find.text('后端暂无队列跳播命令'), findsOneWidget);
      expect(find.text('后端暂无队列移动命令'), findsOneWidget);
    });
  });
}

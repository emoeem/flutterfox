/// MiniPlayerBar 交互契约（§5.8；Phase 2 自 mobile_shell_test.dart 迁入扩展）。
///
/// 锁定：
/// - 无歌不进树 / 有歌可见（壳条件渲染）；
/// - 点击主体经 nowPlayingRequest 打开全屏播放页；
/// - **点击控制只执行控制不跳转**（§5.8「点击控制只执行控制，不触发
///   页面跳转」）：播放/下一首派发真实 FfiCommand 且壳不切全屏；
/// - 控制命令走 AppModel 真实命令路径（_RecordingModel 断言）。
///
/// 平台口径：直接 pump MobileShell（对齐 shell_test.dart 既有模式）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/myune/page/setting/settings_provider.dart';
import 'package:voicefox_flutter/src/myune/services/notification_service.dart';
import 'package:voicefox_flutter/src/nav_bus.dart';
import 'package:voicefox_flutter/src/player/mini_player_bar.dart';
import 'package:voicefox_flutter/src/player/mobile_now_playing_page.dart';
import 'package:voicefox_flutter/src/shell/mobile_shell.dart';

class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];

  @override
  Future<void> dispatch(bridge.FfiCommand command) async {
    commands.add(command);
  }
}

AppModel _songModel({bool recording = false}) {
  final model = recording ? _RecordingModel() : AppModel();
  model.debugSetPlaybackSong(
    id: 's1',
    source: 'netease',
    name: '夜航',
    singer: '测试歌手',
    state: 'paused',
    positionMs: 42000,
    durationMs: 244000,
  );
  return model;
}

Widget _harness(AppModel model) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppModel>.value(value: model),
      ChangeNotifierProvider<SettingsProvider>.value(value: SettingsProvider()),
      ChangeNotifierProvider<NotificationService>.value(
        value: NotificationService(),
      ),
    ],
    child: MaterialApp(home: MobileShell(model: model)),
  );
}

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('MiniPlayerBar 进树契约', () {
    testWidgets('无歌不进树，有歌可见（§5.8 不保留空白高度）', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();
      expect(find.byType(MiniPlayerBar), findsNothing);

      model.debugSetPlaybackSong(
        id: 's1',
        source: 'netease',
        name: '夜航',
        singer: '测试歌手',
        state: 'paused',
        positionMs: 0,
        durationMs: 244000,
      );
      await tester.pumpAndSettle();
      expect(find.byType(MiniPlayerBar), findsOneWidget);
    });
  });

  group('MiniPlayerBar 点击主体 vs 点击控制', () {
    testWidgets('点击主体经 nowPlayingRequest 打开全屏播放页', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = _songModel();
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      // 点歌名区域（避开行尾控制按钮；限定迷你播放栏内的文本）。
      await tester.tap(
        find.descendant(
          of: find.byType(MiniPlayerBar),
          matching: find.text('夜航'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MobileNowPlayingPage), findsOneWidget);
      expect(nowPlayingRequest.value, isFalse);
    });

    testWidgets('点击控制只执行控制不跳转：播放命令派发且壳不切全屏', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = _songModel(recording: true) as _RecordingModel;
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      // 点播放/暂停控制（IconButton 自带命中隔离，主体 onTap 不触发）。
      await tester.tap(
        find.descendant(
          of: find.byType(MiniPlayerBar),
          matching: find.byIcon(Icons.play_arrow),
        ),
      );
      await tester.pump();

      // §5.8：控制只执行控制——真实命令已派发。
      expect(
        model.commands.contains(const bridge.FfiCommand.toggle()),
        isTrue,
        reason: '播放/暂停必须走真实 FfiCommand.toggle',
      );
      // ……且不触发页面跳转：仍在壳内，未进全屏播放页。
      expect(find.byType(MobileNowPlayingPage), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(MiniPlayerBar), findsOneWidget);
      expect(nowPlayingRequest.value, isFalse);
    });

    testWidgets('点击控制只执行控制不跳转：下一首命令派发且壳不切全屏', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = _songModel(recording: true) as _RecordingModel;
      await tester.pumpWidget(_harness(model));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(MiniPlayerBar),
          matching: find.byIcon(Icons.skip_next),
        ),
      );
      await tester.pump();

      expect(
        model.commands.contains(const bridge.FfiCommand.next()),
        isTrue,
        reason: '下一首必须走真实 FfiCommand.next',
      );
      expect(find.byType(MobileNowPlayingPage), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(nowPlayingRequest.value, isFalse);
    });
  });
}

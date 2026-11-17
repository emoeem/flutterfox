/// 手机本地音乐页测试（计划书 C-05，360 视口为主）：
/// - 扫描状态 banner（可取消）：进入页自动补扫描（TUI 同规则）、取消派发
///   LocalScanCancel；取消不提交语义保持（AppModel debugCompleteLocalScan
///   cancelled 分支——已入库歌曲不变 + 已取消横幅）；
/// - 统计条（新增/复用/无法读取/无音频文件/移除）+ 失败项「重试」重扫；
/// - 警告横幅；目录管理卡（移除走确认对话框 + ConfigUpdate + 残余目录重扫）；
/// - 曲目列表（移动行）：单击播放整列、播放全部；
/// - 空库引导：未配置目录 → 添加目录；已配置无歌 → 重新扫描/添加目录/
///   去在线搜索（pop 回壳 + navRequest=1 切搜索目的地）；
/// - 360 视口溢出断言（tester.takeException isNull）。
///
/// 平台口径：直接 pump MobileLocalMusicPage（推入路由页自带 Scaffold；
/// push 入口接线由 mobile_shell_test / mobile_home_page_test 覆盖）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/design_system/components/vx_track_row.dart';
import 'package:voicefox_flutter/src/nav_bus.dart' as nav_bus;
import 'package:voicefox_flutter/src/pages/mobile_local_music_page.dart';

/// 记录派发命令的测试模型（不起 Rust 控制器）。
class _RecordingModel extends AppModel {
  final List<bridge.FfiCommand> commands = [];

  @override
  Future<void> dispatch(bridge.FfiCommand command) async {
    commands.add(command);
  }
}

bridge.ConfigDto _config({List<String> paths = const []}) => bridge.ConfigDto(
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
  localMusicPaths: paths,
  localMusicMaxDepth: 0,
);

bridge.SongDto _song(String id, String name) => bridge.SongDto(
  id: id,
  source: 'local',
  name: name,
  singer: '本地歌手',
  albumName: '本地专辑',
  durationMs: BigInt.from(180000),
  coverUrl: null,
);

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 页面内的查找（限定范围）：页面组件可复用同名文本，不能全树盲目取 first。
Finder _page(Finder finder) =>
    find.descendant(of: find.byType(MobileLocalMusicPage), matching: finder);

Future<void> _pumpLocal(
  WidgetTester tester,
  AppModel model, {
  Size size = const Size(360, 800),
}) async {
  _setSize(tester, size);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: MobileLocalMusicPage(model))),
  );
  // 进入页面的帧后自动补扫描等状态落地。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    nav_bus.navRequest.value = null;
  });

  tearDown(() {
    nav_bus.navRequest.value = null;
  });

  group('扫描状态与统计', () {
    testWidgets('进入页自动补扫描（启用+有目录+空库）：banner 可取消', (tester) async {
      final model = _RecordingModel();
      model.debugSetConfig(_config(paths: const ['/music']));
      model.debugSetLocalSongs(const []);
      await _pumpLocal(tester, model);

      // TUI 同规则自动补一次扫描（paths 来自配置）。
      final scans = model.commands
          .whereType<bridge.FfiCommand_LocalScan>()
          .toList();
      expect(scans, hasLength(1));
      expect(scans.single.paths, ['/music']);
      expect(_page(find.text('正在扫描本地歌曲…')), findsOneWidget);

      // 可取消。
      await tester.tap(_page(find.text('取消')));
      await tester.pump();
      expect(
        model.commands.whereType<bridge.FfiCommand_LocalScanCancel>(),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('统计条：新增/复用/无法读取/无音频文件/移除；失败项提供重试', (tester) async {
      final model = _RecordingModel();
      model.debugSetConfig(_config(paths: const ['/music']));
      model.debugSetLocalSongs(const []);
      await _pumpLocal(tester, model);

      model.debugCompleteLocalScan(
        songs: [_song('s1', '本地一'), _song('s2', '本地二'), _song('s3', '本地三')],
        stats: const bridge.ScanStatsDto(
          discovered: 7,
          reused: 2,
          parsed: 3,
          failed: 1,
          removed: 0,
          skipped: 1,
        ),
      );
      await tester.pump();

      expect(
        _page(find.text('新增 3 · 复用 2 · 无法读取 1 · 无音频文件 1 · 移除 0')),
        findsOneWidget,
      );
      await tester.tap(_page(find.text('重试')));
      await tester.pump();
      // 重扫即重试：再次派发 LocalScan。
      expect(
        model.commands.whereType<bridge.FfiCommand_LocalScan>(),
        hasLength(2),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('取消不提交语义保持：已入库歌曲不变 + 已取消横幅（无统计条）', (tester) async {
      final model = _RecordingModel();
      model.debugSetConfig(_config(paths: const ['/music']));
      model.debugSetLocalSongs([_song('s1', '本地一'), _song('s2', '本地二')]);
      await _pumpLocal(tester, model);

      model.debugCompleteLocalScan(cancelled: true);
      await tester.pump();

      expect(_page(find.text('扫描已取消；已入库歌曲保持不变')), findsOneWidget);
      // 本次结果未提交：曲库保持 2 首（取消事件不改快照）。
      expect(_page(find.text('共 2 首')), findsOneWidget);
      expect(_page(find.text('本地一')), findsOneWidget);
      expect(_page(find.text('本地二')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('警告横幅如实直出', (tester) async {
      final model = _RecordingModel();
      model.debugSetConfig(_config(paths: const ['/missing']));
      model.debugSetLocalSongs(const []);
      await _pumpLocal(tester, model);

      model.debugCompleteLocalScan(
        warnings: const ['目录不存在: /missing'],
        stats: const bridge.ScanStatsDto(
          discovered: 0,
          reused: 0,
          parsed: 0,
          failed: 0,
          removed: 0,
          skipped: 0,
        ),
      );
      await tester.pump();

      expect(_page(find.text('扫描警告：目录不存在: /missing')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('目录管理', () {
    testWidgets('目录卡逐目录列出；移除需确认：取消不派发，确认后 ConfigUpdate + 残余重扫', (tester) async {
      final model = _RecordingModel();
      model.debugSetConfig(_config(paths: const ['/music', '/lost']));
      model.debugSetLocalSongs([_song('s1', '本地一')]);
      await _pumpLocal(tester, model);

      expect(_page(find.text('/music')), findsOneWidget);
      expect(_page(find.text('/lost')), findsOneWidget);

      // 取消：不派发任何命令。
      await tester.tap(_page(find.byTooltip('移除目录 /lost')));
      await tester.pump();
      expect(find.text('移除本地音乐目录'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pump();
      expect(model.commands, isEmpty);

      // 确认：ConfigUpdate（保留 /music）+ 残余目录重扫。
      await tester.tap(_page(find.byTooltip('移除目录 /lost')));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '移除'));
      await tester.pump();
      final updates = model.commands
          .whereType<bridge.FfiCommand_ConfigUpdate>()
          .toList();
      expect(updates, hasLength(1));
      expect(updates.single.config.localMusicPaths, ['/music']);
      final rescans = model.commands
          .whereType<bridge.FfiCommand_LocalScan>()
          .toList();
      expect(rescans, hasLength(1));
      expect(rescans.single.paths, ['/music']);
    });
  });

  group('曲目列表与播放', () {
    testWidgets('移动行渲染 + 单击播放整列 + 播放全部', (tester) async {
      final model = _RecordingModel();
      model.debugSetConfig(_config(paths: const ['/music']));
      model.debugSetLocalSongs([_song('s1', '本地一'), _song('s2', '本地二')]);
      await _pumpLocal(tester, model);

      expect(_page(find.text('共 2 首')), findsOneWidget);
      expect(_page(find.byType(VxTrackRow)), findsNWidgets(2));
      expect(_page(find.text('本地一')), findsOneWidget);
      expect(_page(find.text('本地二')), findsOneWidget);

      // 单击行 = 播放整列（该行起）。
      await tester.tap(_page(find.text('本地二')));
      await tester.pump();
      final played = model.commands
          .whereType<bridge.FfiCommand_PlaySongs>()
          .toList();
      expect(played, hasLength(1));
      expect(played.single.index, 1);
      expect(played.single.songs.map((s) => s.id), ['s1', 's2']);

      // 顶栏播放全部。
      await tester.tap(_page(find.byTooltip('播放全部')));
      await tester.pump();
      expect(
        model.commands.whereType<bridge.FfiCommand_PlaySongs>(),
        hasLength(2),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('空库引导与 360 溢出', () {
    testWidgets('未配置目录：「尚未配置本地音乐目录」+ 添加目录引导', (tester) async {
      final model = _RecordingModel();
      model.debugSetConfig(_config());
      model.debugSetLocalSongs(const []);
      await _pumpLocal(tester, model);

      expect(_page(find.text('尚未配置本地音乐目录')), findsOneWidget);
      expect(_page(find.text('添加一个音乐文件夹，扫描后即可在这里播放')), findsOneWidget);
      // 空态主 CTA + AppBar 图标钮两个入口都可达。
      expect(find.byTooltip('添加目录'), findsOneWidget);
      expect(_page(find.text('添加目录')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('已配置无歌：重新扫描/添加目录/去在线搜索（pop 回壳 + navRequest=1）', (tester) async {
      final model = _RecordingModel();
      model.debugSetConfig(_config(paths: const ['/music']));
      model.debugSetLocalSongs(const []);
      // 直接挂壳层首页，页以推入路由打开（与生产 push 语义一致）。
      _setSize(tester, const Size(360, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (homeContext) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(homeContext).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MobileLocalMusicPage(model),
                    ),
                  ),
                  child: const Text('壳层'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('壳层'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MobileLocalMusicPage), findsOneWidget);

      // 自动补扫描先落地：结束扫描（无警告无歌曲）进入空库引导。
      model.debugCompleteLocalScan();
      await tester.pump();

      expect(find.text('未扫描到本地歌曲'), findsOneWidget);
      expect(find.text('重新扫描'), findsOneWidget);
      expect(find.text('添加目录'), findsWidgets);
      expect(find.text('去在线搜索'), findsOneWidget);

      // 去在线搜索：pop 回壳 + navRequest=1（切搜索目的地）。
      await tester.tap(find.text('去在线搜索'));
      await tester.pumpAndSettle();
      expect(find.byType(MobileLocalMusicPage), findsNothing);
      expect(nav_bus.navRequest.value, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('360 视口：banner + 统计 + 目录卡 + 列表整页无溢出', (tester) async {
      final model = _RecordingModel();
      model.debugSetConfig(
        _config(paths: const ['/home/user/Music', '/mnt/nas/flac-collection']),
      );
      model.debugSetLocalSongs([
        _song('s1', '超长本地歌曲名称测试超长本地歌曲名称测试超长本地歌曲名称'),
        _song('s2', '本地二'),
      ]);
      await _pumpLocal(tester, model);

      model.debugCompleteLocalScan(
        songs: model.state.localSongs,
        warnings: const ['目录不存在: /mnt/nas/flac-collection'],
        stats: const bridge.ScanStatsDto(
          discovered: 5,
          reused: 1,
          parsed: 1,
          failed: 0,
          removed: 0,
          skipped: 0,
        ),
      );
      await tester.pump();

      expect(find.byType(VxTrackRow), findsNWidgets(2));
      expect(
        _page(find.text('扫描警告：目录不存在: /mnt/nas/flac-collection')),
        findsOneWidget,
      );
      expect(_page(find.text('/home/user/Music')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

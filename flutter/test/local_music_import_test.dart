/// LocalMusicImportTest（Phase 5 §5.10 导入流程补全）：
/// - 统计条（新增/复用/无法读取/无音频文件/移除）与「重试失败项」；
/// - 扫描可取消：取消后列表不变、scanningLocal=false、统计条不展示旧值；
/// - 导入入口双选项（选择文件夹/选择文件）与可注入 file picker seam；
/// - content:// SAF 来源错误文案（seam 抛 UnsupportedError，不伪造成功）；
/// - 手输路径是回退手段而非唯一方法（选择器可用时不弹手输框）。
///
/// 「导入单文件后重扫父目录不重复」的记录去重契约由 Rust 侧单测锁定
///（lx-source local mod：单文件导入 root=父目录 canonical 键）。
library;

import 'package:file_picker/file_picker.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/local_music_page.dart';

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

bridge.ScanStatsDto _stats({
  int discovered = 3,
  int reused = 1,
  int parsed = 2,
  int failed = 0,
  int removed = 0,
  int skipped = 1,
}) => bridge.ScanStatsDto(
  discovered: discovered,
  reused: reused,
  parsed: parsed,
  failed: failed,
  removed: removed,
  skipped: skipped,
);

Future<void> _pump(
  WidgetTester tester,
  AppModel model, {
  List<bridge.SongDto> songs = const [],
}) async {
  await tester.pumpWidget(MaterialApp(home: LocalMusicPage(model)));
  await tester.pump();
  model.debugCompleteLocalScan(songs: songs);
  await tester.pump();
}

void main() {
  setUp(() {
    // 每用例恢复生产 seam。
    localDirectoryPicker = FilePicker.getDirectoryPath;
    localFilePicker = ({dialogTitle}) async =>
        (await FilePicker.pickFile(dialogTitle: dialogTitle))?.path;
    localImportResolver = defaultImportResolver;
    debugResetImportFlowGate();
  });

  group('扫描统计条（§5.10 流程 5）', () {
    testWidgets('完成事件展示新增/复用/无法读取/无音频文件/移除', (tester) async {
      final model = AppModel();
      model.debugSetConfig(_config(paths: ['/music']));
      await _pump(tester, model, songs: [_song('s1', 'a'), _song('s2', 'b')]);
      model.debugCompleteLocalScan(stats: _stats());
      await tester.pump();

      expect(find.textContaining('新增 2'), findsOneWidget);
      expect(find.textContaining('复用 1'), findsOneWidget);
      expect(find.textContaining('无法读取 0'), findsOneWidget);
      expect(find.textContaining('无音频文件 1'), findsOneWidget);
      expect(find.textContaining('移除 0'), findsOneWidget);
      expect(find.text('重试'), findsNothing, reason: '无失败项不提供重试');
    });

    testWidgets('有失败项时提供重试（重扫即重试，不整体回滚）', (tester) async {
      final model = AppModel();
      model.debugSetConfig(_config(paths: ['/music']));
      await _pump(tester, model);
      model.debugCompleteLocalScan(stats: _stats(failed: 2, parsed: 1));
      await tester.pump();
      final retry = tester.widget<TextButton>(
        find
            .ancestor(of: find.text('重试'), matching: find.byType(TextButton))
            .first,
      );
      expect(retry.onPressed, isNotNull);
    });

    testWidgets('取消扫描：统计条不展示旧值，显示已取消横幅', (tester) async {
      final model = AppModel();
      model.debugSetConfig(_config(paths: ['/music']));
      await _pump(tester, model, songs: [_song('s1', 'a')]);
      // 先有一次成功统计，再取消下一次扫描。
      model.debugCompleteLocalScan(songs: [_song('s1', 'a')], stats: _stats());
      await tester.pump();
      model.scanLocal();
      await tester.pump();
      expect(model.scanningLocal, isTrue);
      expect(find.text('取消'), findsOneWidget, reason: '扫描中横幅提供取消');

      // 取消事件：stats=null、cancelled=true、localSongs 不变。
      model.debugCompleteLocalScan(cancelled: true);
      await tester.pump();
      expect(model.scanningLocal, isFalse);
      expect(model.scanCancelled, isTrue);
      expect(model.scanStats, isNull, reason: '取消的扫描不提交，不能展示旧统计');
      expect(model.state.localSongs.length, 1, reason: '已提交结果保持不变');
      expect(find.textContaining('扫描已取消'), findsOneWidget);
    });
  });

  group('导入入口双选项（§5.10 流程 1-2）', () {
    testWidgets('添加目录先弹双选项；选「选择文件夹」走目录选择器', (tester) async {
      final model = AppModel();
      model.debugSetConfig(_config(paths: const []));
      var directoryCalls = 0;
      localDirectoryPicker = ({dialogTitle}) async {
        directoryCalls += 1;
        return null;
      };
      await _pump(tester, model);

      await tester.tap(find.text('添加目录').first);
      await tester.pumpAndSettle();
      expect(find.text('选择文件夹'), findsOneWidget);
      expect(find.text('选择文件'), findsOneWidget);
      expect(directoryCalls, 0, reason: '双选项先于选择器');

      await tester.tap(find.text('选择文件夹'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(directoryCalls, 1);
      // 选择器返回 null（用户取消）→ 回退手输对话框（回退语义）。
      expect(find.text('添加本地音乐目录'), findsOneWidget);
    });

    testWidgets('选「选择文件」走文件选择器 seam 并下发扫描命令', (tester) async {
      final model = AppModel();
      model.debugSetConfig(_config(paths: const []));
      var fileCalls = 0;
      localFilePicker = ({dialogTitle}) async {
        fileCalls += 1;
        return '/music/track.flac';
      };
      final dispatched = <bridge.FfiCommand>[];
      model.debugSetDispatcherForTest((command) async {
        dispatched.add(command);
      });
      await _pump(tester, model);

      await tester.tap(find.text('添加目录').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择文件'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(fileCalls, 1);
      // 文件路径追加进配置路径并触发扫描（LocalScan 命令）。
      expect(dispatched.whereType<bridge.FfiCommand_LocalScan>().length, 1);
      expect(
        dispatched.whereType<bridge.FfiCommand_LocalScan>().first.paths,
        contains('/music/track.flac'),
      );
    });

    testWidgets('content:// 来源经 resolver seam 报错文案，不伪造导入成功', (tester) async {
      final model = AppModel();
      model.debugSetConfig(_config(paths: const []));
      localFilePicker = ({dialogTitle}) async => 'content://media/1';
      final dispatched = <bridge.FfiCommand>[];
      model.debugSetDispatcherForTest((command) async {
        dispatched.add(command);
      });
      await _pump(tester, model);

      await tester.tap(find.text('添加目录').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择文件'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('暂不支持该文件来源'), findsOneWidget);
      expect(dispatched, isEmpty, reason: 'SAF 未实装，不发起扫描');
    });

    testWidgets('选择器不可用（PlatformException）时回退手输对话框（非唯一方法）', (tester) async {
      final model = AppModel();
      model.debugSetConfig(_config(paths: const []));
      localDirectoryPicker = ({dialogTitle}) =>
          throw PlatformException(code: 'picker_unavailable');
      await _pump(tester, model);

      await tester.tap(find.text('添加目录').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('选择文件夹'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('添加本地音乐目录'), findsOneWidget, reason: '手输是回退手段，不是唯一导入方法');
      expect(find.text('目录绝对路径'), findsOneWidget);
    });

    testWidgets('导入流重入门禁（P1-16）：进行中再触发不叠开第二条 modal 流', (tester) async {
      final model = AppModel();
      model.debugSetConfig(_config(paths: const []));
      // 选择器挂起不返回（复现 P1-16 运行时间隙：sheet 已 pop、后续
      // 对话框未出现，用户再次点击的窗口）。
      final pickerHang = Completer<String?>();
      localDirectoryPicker = ({dialogTitle}) => pickerHang.future;
      await _pump(tester, model);
      final pageContext = tester.element(find.byType(LocalMusicPage));

      final first = importLocalMusicDirectory(pageContext, model);
      await tester.pumpAndSettle();
      expect(find.text('选择文件夹'), findsOneWidget, reason: '第一条流的 sheet 在位');

      // 点击选择文件夹：sheet pop、系统选择器挂起不返回（运行时间隙）。
      await tester.tap(find.text('选择文件夹'));
      await tester.pumpAndSettle();
      expect(find.text('选择文件夹'), findsNothing, reason: 'sheet 已 pop，选择器挂起中');

      // 间隙内的第二次触发：立即返回，不叠开第二条 sheet/dialog。
      final second = importLocalMusicDirectory(pageContext, model);
      await tester.pumpAndSettle();
      expect(find.text('添加本地音乐目录'), findsNothing, reason: '门禁期内不叠开第二条流');
      expect(second, completes);

      // 走完第一条流（选择器返回 null → 手输框），门禁释放。
      pickerHang.complete(null);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('添加本地音乐目录'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pump(const Duration(milliseconds: 400));
      await first;

      // 门禁已释放：再次触发能正常开 sheet，且整条流可走完（不残留门禁）。
      localDirectoryPicker = ({dialogTitle}) async => null;
      final third = importLocalMusicDirectory(pageContext, model);
      await tester.pumpAndSettle();
      expect(find.text('选择文件夹'), findsOneWidget, reason: '门禁释放后导入流可用');
      await tester.tap(find.text('选择文件夹'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('取消'));
      await tester.pump(const Duration(milliseconds: 400));
      await third;
    });
  });
}

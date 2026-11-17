/// 手机下载页测试（计划书 C-03，360 视口为主）：
/// - 状态筛选 chips（全部/进行中/已完成/失败，分组判定与桌面同源）；
/// - 任务卡渲染：标题/歌手·音质/状态标签/进度条/字节与速度；
/// - 操作按真实状态派发（暂停/继续/取消/重试/清除已完成，复用 AppModel
///   既有下载命令，经 RecordingModel 捕获）；
/// - 删除二次确认（取消不派发、确认才派发）；
/// - 失败原因可展开查看完整 message（不截断）；
/// - 字节倒挂（已收 > 总量）：进度条钳 0..1、字节如实原样显示；
/// - 空态给去处（去发现音乐/管理下载目录）+ 分组空态；
/// - 360 视口溢出断言（tester.takeException isNull）。
///
/// 平台口径：360 视口直接 pump MobileDownloadsPage（对齐 mobile_discover
/// 页面级口径；壳内接线由 mobile_shell_test 覆盖）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/nav_bus.dart' as nav_bus;
import 'package:voicefox_flutter/src/pages/mobile_downloads_page.dart';

/// 记录派发命令的测试模型（不起 Rust 控制器）。
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
  singer: '歌手',
  albumName: '专辑',
  durationMs: BigInt.from(180000),
  coverUrl: null,
);

bridge.DownloadTaskDto _task(
  BigInt id,
  String name, {
  String state = 'downloading',
  bool active = false,
  int downloaded = 0,
  int? total,
  String? error,
  String singer = '歌手',
  String quality = 'flac',
}) => bridge.DownloadTaskDto(
  id: id,
  name: name,
  singer: singer,
  source: 'kw',
  quality: quality,
  dest: '/tmp/$name.flac',
  song: _song('s$id', name),
  state: state,
  active: active,
  downloaded: BigInt.from(downloaded),
  total: total == null ? null : BigInt.from(total),
  error: error,
  triggerAutoCache: false,
);

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpDownloads(
  WidgetTester tester,
  AppModel model, {
  Size size = const Size(360, 800),
}) async {
  _setSize(tester, size);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: MobileDownloadsPage(model))),
  );
  await tester.pump();
}

/// 页面内的查找（限定范围）：页面组件可复用同名文本，不能全树盲目取 first。
Finder _page(Finder finder) =>
    find.descendant(of: find.byType(MobileDownloadsPage), matching: finder);

/// 筛选 chips 是单行横滚（360 视口末位「失败」在折叠线外未构建/不可点），
/// 横滑到末尾再点击（与真实用户操作同路径，对齐 mobile_discover 测试模式）。
/// 不用 pumpAndSettle：无 total 的任务卡是无限进度条动画，永不静止。
Future<void> _scrollFilters(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('mobile-downloads-filters')),
    const Offset(-200, 0),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    nav_bus.navRequest.value = null;
  });

  tearDown(() {
    nav_bus.navRequest.value = null;
  });

  group('渲染与状态筛选分组', () {
    testWidgets('任务卡渲染：标题/歌手·音质/状态标签/进度条，360 视口无溢出', (tester) async {
      final model = _RecordingModel();
      model.debugSetDownloads([
        _task(
          BigInt.one,
          '夜航',
          state: 'downloading',
          active: true,
          downloaded: 1024 * 1024,
          total: 4 * 1024 * 1024,
        ),
        _task(
          BigInt.two,
          '星尘',
          state: 'done',
          downloaded: 4 * 1024 * 1024,
          total: 4 * 1024 * 1024,
        ),
      ]);
      await _pumpDownloads(tester, model);

      expect(_page(find.text('下载')), findsOneWidget);
      expect(_page(find.text('夜航')), findsOneWidget);
      expect(_page(find.text('星尘')), findsOneWidget);
      // 歌手与音质合并小字；状态标签为中文映射（不抛英文枚举）。
      expect(_page(find.text('歌手 · flac')), findsNWidgets(2));
      expect(_page(find.text('下载中')), findsOneWidget);
      expect(_page(find.text('已完成')), findsOneWidget);
      // 进行中任务有进度条。
      expect(_page(find.byType(LinearProgressIndicator)), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('筛选 chips 带计数；点「失败」只显示失败分组任务', (tester) async {
      final model = _RecordingModel();
      model.debugSetDownloads([
        _task(BigInt.one, '下载甲', state: 'downloading', active: true),
        _task(BigInt.two, '下载乙', state: 'paused', active: true),
        _task(BigInt.from(3), '完成丙', state: 'done'),
        _task(BigInt.from(4), '失败丁', state: 'failed', error: '网络不可用'),
        _task(BigInt.from(5), '取消戊', state: 'cancelled'),
      ]);
      await _pumpDownloads(tester, model);

      // 暂停归入「进行中」分组（可恢复，桌面同语义）；取消归入「失败」。
      expect(_page(find.text('全部 5')), findsOneWidget);
      expect(_page(find.text('进行中 2')), findsOneWidget);
      expect(_page(find.text('已完成 1')), findsOneWidget);
      expect(_page(find.text('失败 2')), findsOneWidget);
      expect(_page(find.text('失败丁')), findsOneWidget);

      // 末位 chips 在 360 视口折叠线外：横滑后点击。
      await _scrollFilters(tester);
      await tester.tap(_page(find.text('失败 2')));
      await tester.pump();
      expect(_page(find.text('失败丁')), findsOneWidget);
      expect(_page(find.text('取消戊')), findsOneWidget);
      expect(_page(find.text('下载甲')), findsNothing);
      expect(_page(find.text('完成丙')), findsNothing);
      expect(tester.takeException(), isNull);

      // 分组空态：切到「已完成」清不掉——这里切一个空组合不可能，改验
      // 空库分支由下方专项用例覆盖；本组切回「全部」恢复全量（首枚 chip
      // 已横滑出折叠线，先拖回）。
      await tester.drag(
        find.byKey(const ValueKey('mobile-downloads-filters')),
        const Offset(200, 0),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(_page(find.text('全部 5')));
      await tester.pump();
      expect(_page(find.text('下载甲')), findsOneWidget);
    });

    testWidgets('筛选后空分组给「该分组下没有任务」', (tester) async {
      final model = _RecordingModel();
      model.debugSetDownloads([
        _task(BigInt.one, '下载甲', state: 'downloading', active: true),
      ]);
      await _pumpDownloads(tester, model);
      await _scrollFilters(tester);
      await tester.tap(_page(find.text('失败 0')));
      await tester.pump();
      expect(_page(find.text('该分组下没有任务')), findsOneWidget);
      expect(_page(find.text('切换筛选查看其他任务')), findsOneWidget);
    });
  });

  group('操作按真实状态派发', () {
    testWidgets('下载中：暂停/取消可用，派发真实命令', (tester) async {
      final model = _RecordingModel();
      model.debugSetDownloads([
        _task(BigInt.one, '夜航', state: 'downloading', active: true),
      ]);
      await _pumpDownloads(tester, model);

      await tester.tap(_page(find.text('暂停')));
      await tester.pump();
      expect(
        model.commands.whereType<bridge.FfiCommand_DownloadPause>().map(
          (c) => c.id,
        ),
        [BigInt.one],
      );

      await tester.tap(_page(find.text('取消')));
      await tester.pump();
      expect(
        model.commands.whereType<bridge.FfiCommand_DownloadCancel>().map(
          (c) => c.id,
        ),
        [BigInt.one],
      );
    });

    testWidgets('已暂停：继续/取消可用（暂停不提供暂停钮）', (tester) async {
      final model = _RecordingModel();
      model.debugSetDownloads([
        _task(BigInt.one, '夜航', state: 'paused', active: true),
      ]);
      await _pumpDownloads(tester, model);

      expect(_page(find.text('已暂停')), findsOneWidget);
      expect(_page(find.text('暂停')), findsNothing);
      await tester.tap(_page(find.text('继续')));
      await tester.pump();
      expect(
        model.commands.whereType<bridge.FfiCommand_DownloadResume>().map(
          (c) => c.id,
        ),
        [BigInt.one],
      );
    });

    testWidgets('失败：重试复用任务内歌曲载荷重新入队', (tester) async {
      final model = _RecordingModel();
      final task = _task(BigInt.one, '夜航', state: 'failed', error: '网络不可用');
      model.debugSetDownloads([task]);
      await _pumpDownloads(tester, model);

      await tester.tap(_page(find.text('重试')));
      await tester.pump();
      final retries = model.commands
          .whereType<bridge.FfiCommand_DownloadEnqueue>()
          .toList();
      expect(retries, hasLength(1));
      expect(retries.single.song.id, 's1', reason: '重试复用任务内歌曲载荷');
    });

    testWidgets('删除二次确认：取消不派发，确认后派发删除命令', (tester) async {
      final model = _RecordingModel();
      model.debugSetDownloads([
        _task(BigInt.one, '完成曲', state: 'done', downloaded: 4096, total: 4096),
      ]);
      await _pumpDownloads(tester, model);

      await tester.tap(_page(find.text('删除')));
      await tester.pump();
      expect(find.text('删除下载文件'), findsOneWidget);
      expect(find.textContaining('「完成曲」'), findsOneWidget);

      // 取消：不派发。
      await tester.tap(find.text('取消'));
      await tester.pump();
      expect(
        model.commands.whereType<bridge.FfiCommand_DownloadDeleteFile>(),
        isEmpty,
      );

      // 确认：派发。
      await tester.tap(_page(find.text('删除')));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pump();
      expect(
        model.commands.whereType<bridge.FfiCommand_DownloadDeleteFile>().map(
          (c) => c.id,
        ),
        [BigInt.one],
      );
    });

    testWidgets('清除已完成：有完结任务时可用并派发；打开/定位禁用占位', (tester) async {
      final model = _RecordingModel();
      model.debugSetDownloads([
        _task(BigInt.one, '完成曲', state: 'done', downloaded: 4096, total: 4096),
      ]);
      await _pumpDownloads(tester, model);

      await tester.tap(_page(find.text('清除已完成')));
      await tester.pump();
      expect(
        model.commands.whereType<bridge.FfiCommand_DownloadClearFinished>(),
        hasLength(1),
      );

      // 打开/定位：后端无命令，禁用占位（点击无动作）。
      await tester.tap(_page(find.text('打开')), warnIfMissed: false);
      await tester.tap(_page(find.text('定位')), warnIfMissed: false);
      await tester.pump();
      expect(model.commands, hasLength(1), reason: '禁用钮不派发命令');
    });
  });

  group('失败原因与字节显示', () {
    testWidgets('失败原因可展开查看完整 message（不截断为「失败 · 音频…」）', (tester) async {
      const message = '音频流不可用（HTTP 403）：已尝试 3 次全部超时，请稍后重试或更换音源';
      final model = _RecordingModel();
      model.debugSetDownloads([
        _task(BigInt.one, '夜航', state: 'failed', error: message),
      ]);
      await _pumpDownloads(tester, model);

      // 折叠态：状态标签只显示「失败」，完整 message 不在树上。
      expect(_page(find.text('失败')), findsOneWidget);
      expect(_page(find.textContaining('HTTP 403')), findsNothing);

      // 展开后完整直出（软换行，不截断）。
      await tester.tap(_page(find.text('失败原因')));
      await tester.pump();
      expect(_page(find.textContaining('HTTP 403')), findsOneWidget);
      expect(_page(find.textContaining('更换音源')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 再点收起。
      await tester.tap(_page(find.text('失败原因')));
      await tester.pump();
      expect(_page(find.textContaining('HTTP 403')), findsNothing);
    });

    testWidgets('字节倒挂（已收 > 总量）：进度条钳 0..1，字节如实原样显示', (tester) async {
      final model = _RecordingModel();
      model.debugSetDownloads([
        _task(
          BigInt.one,
          '倒挂曲',
          state: 'downloading',
          active: true,
          downloaded: 1500,
          total: 1000,
        ),
      ]);
      await _pumpDownloads(tester, model);

      // 字节如实：1.5 KB / 1000 B（不伪造两侧一致）。
      expect(_page(find.text('1.5 KB / 1000 B')), findsOneWidget);
      // 进度条钳 0..1，不越界。
      final bar = tester.widget<LinearProgressIndicator>(
        _page(find.byType(LinearProgressIndicator)).first,
      );
      expect(bar.value, 1.0);
      expect(tester.takeException(), isNull);
    });
  });

  group('空态与 360 溢出', () {
    testWidgets('空库空态给去处：去发现音乐 / 管理下载目录（navRequest 总线）', (tester) async {
      final model = _RecordingModel();
      await _pumpDownloads(tester, model);

      expect(_page(find.text('暂无下载任务')), findsOneWidget);
      await tester.tap(_page(find.text('去发现音乐')));
      await tester.pump();
      expect(nav_bus.navRequest.value, 3);
      nav_bus.navRequest.value = null;

      await tester.tap(_page(find.text('管理下载目录')));
      await tester.pump();
      expect(nav_bus.navRequest.value, 7);
    });

    testWidgets('360 视口：混合状态与长标题/长错误整页无溢出', (tester) async {
      final model = _RecordingModel();
      model.debugSetDownloads([
        _task(
          BigInt.one,
          '超长歌曲名称测试超长歌曲名称测试超长歌曲名称测试超长歌曲名称测试',
          state: 'downloading',
          active: true,
          downloaded: 1024 * 1024,
          total: 4 * 1024 * 1024,
          singer: '超长歌手名称测试超长歌手名称测试',
        ),
        _task(
          BigInt.two,
          '失败长文案曲',
          state: 'failed',
          error:
              '一段非常长的失败原因描述一段非常长的失败原因描述一段非常长的失败原因描述'
              '一段非常长的失败原因描述一段非常长的失败原因描述一段非常长的失败原因描述',
        ),
        _task(
          BigInt.from(3),
          '完成曲',
          state: 'done',
          downloaded: 4096,
          total: 4096,
        ),
      ]);
      await _pumpDownloads(tester, model);

      // 展开失败原因（最长内容形态）后仍无溢出。
      await tester.tap(_page(find.text('失败原因')));
      await tester.pump();
      expect(_page(find.textContaining('一段非常长的失败原因描述')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

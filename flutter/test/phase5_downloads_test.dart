/// Phase 5 下载页：任务列表表格、状态→操作映射、筛选与中文原因；
/// Phase 5 新链路：暂停/继续（真实命令）、删除二次确认、体积与速度、
/// 空态入口（去发现音乐/管理下载目录）。
///
/// wire 词汇表说明：`state` 是 Rust `DownloadState::code()` 的英文机读键
/// （queued/downloading/done/paused/…），中文文案由 Dart 侧映射——
/// 旧版 wire 发中文 label、Dart 匹配英文键全部落空，本轮统一。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/nav_bus.dart' as nav_bus;
import 'package:voicefox_flutter/src/pages/downloads_page.dart';

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
}) => bridge.DownloadTaskDto(
  id: id,
  name: name,
  singer: '歌手',
  source: 'kw',
  quality: 'flac',
  dest: '/tmp/$name.flac',
  song: _song('s$id', name),
  state: state,
  active: active,
  downloaded: BigInt.from(downloaded),
  total: total == null ? null : BigInt.from(total),
  error: error,
  triggerAutoCache: false,
);

Future<void> _pump(
  WidgetTester tester,
  List<bridge.DownloadTaskDto> tasks,
) async {
  final model = AppModel();
  model.debugSetDownloads(tasks);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: DownloadsPage(model))),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    nav_bus.navRequest.value = null;
  });

  group('状态 → 操作映射（纯函数）', () {
    test('下载中：可暂停（真实命令）可取消，重试/打开不可用', () {
      final ops = downloadRowOpsFor(
        _task(BigInt.one, 'a', state: 'downloading', active: true),
      );
      expect(ops.canCancel, isTrue);
      expect(ops.canPause, isTrue, reason: 'Phase 5 起暂停走 DownloadPause');
      expect(ops.canResume, isFalse);
      expect(ops.canRetry, isFalse);
      expect(ops.canOpenFile, isFalse, reason: '后端没有打开文件命令');
    });

    test('排队中：与下载中同组（进行中）', () {
      final ops = downloadRowOpsFor(_task(BigInt.one, 'a', state: 'queued'));
      expect(ops.canCancel, isTrue);
      expect(ops.canRetry, isFalse);
    });

    test('已暂停：可继续可取消，不再提供暂停', () {
      final ops = downloadRowOpsFor(
        _task(BigInt.one, 'a', state: 'paused', active: true),
      );
      expect(ops.canResume, isTrue);
      expect(ops.canCancel, isTrue, reason: '取消暂停任务会作废并清暂存文件');
      expect(ops.canPause, isFalse);
    });

    test('失败/取消：可重试', () {
      expect(
        downloadRowOpsFor(_task(BigInt.one, 'a', state: 'failed')).canRetry,
        isTrue,
      );
      expect(
        downloadRowOpsFor(_task(BigInt.one, 'a', state: 'cancelled')).canRetry,
        isTrue,
      );
    });

    test('已完成/已跳过：可删除本地文件；打开/定位禁用占位', () {
      final ops = downloadRowOpsFor(_task(BigInt.one, 'a', state: 'done'));
      expect(ops.canDelete, isTrue, reason: 'DownloadDeleteFile 删文件+清记录');
      expect(ops.canOpenFile, isFalse);
      expect(ops.canRetry, isFalse);
      expect(ops.canCancel, isFalse);
    });

    test('状态中文映射覆盖全部机读键，不抛英文枚举', () {
      expect(downloadStateLabel('queued'), '排队中');
      expect(downloadStateLabel('resolving'), '解析地址');
      expect(downloadStateLabel('downloading'), '下载中');
      expect(downloadStateLabel('tagging'), '下载中');
      expect(downloadStateLabel('paused'), '已暂停');
      expect(downloadStateLabel('done'), '已完成');
      expect(downloadStateLabel('failed'), '失败');
      expect(downloadStateLabel('cancelled'), '已取消');
      expect(downloadStateLabel('skipped'), '已跳过');
    });

    test('分组：已暂停归入进行中；done/skipped 为已完成', () {
      final paused = _task(BigInt.one, 'a', state: 'paused', active: true);
      expect(downloadTaskActive(paused), isTrue);
      expect(downloadTaskCompleted(paused), isFalse);
      expect(downloadTaskFailed(paused), isFalse);
      final done = _task(BigInt.two, 'b', state: 'done');
      expect(downloadTaskCompleted(done), isTrue);
      final skipped = _task(BigInt.from(3), 'c', state: 'skipped');
      expect(downloadTaskCompleted(skipped), isTrue);
    });

    test('失败原因：后端 message 优先，缺省回退状态名', () {
      final withError = downloadFailureText(
        _task(BigInt.one, 'a', state: 'failed', error: '网络不可用'),
      );
      expect(withError, '网络不可用');
      final withoutError = downloadFailureText(
        _task(BigInt.two, 'b', state: 'failed'),
      );
      expect(withoutError, '失败');
    });

    test('体积格式化：B/KB/MB/GB', () {
      expect(downloadFormatBytes(512), '512 B');
      expect(downloadFormatBytes(2048), '2.0 KB');
      expect(downloadFormatBytes(1536 * 1024), '1.5 MB');
      expect(downloadFormatBytes(3 * 1024 * 1024 * 1024), '3.00 GB');
    });
  });

  group('下载页表格', () {
    testWidgets('进行中任务显示进度/体积与暂停取消按钮', (tester) async {
      await _pump(tester, [
        _task(
          BigInt.one,
          '进行中歌曲',
          state: 'downloading',
          active: true,
          downloaded: 720,
          total: 1000,
        ),
      ]);

      expect(find.text('下载中'), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
      expect(find.text('720 B / 1000 B'), findsOneWidget, reason: '行内体积');
      final pause = tester.widget<TextButton>(
        find
            .ancestor(of: find.text('暂停'), matching: find.byType(TextButton))
            .first,
      );
      expect(pause.onPressed, isNotNull, reason: '暂停已接入 DownloadPause');
      final cancel = tester.widget<TextButton>(
        find
            .ancestor(of: find.text('取消'), matching: find.byType(TextButton))
            .first,
      );
      expect(cancel.onPressed, isNotNull);
    });

    testWidgets('已暂停任务显示「已暂停」与继续入口', (tester) async {
      await _pump(tester, [
        _task(
          BigInt.one,
          '暂停歌曲',
          state: 'paused',
          active: true,
          downloaded: 300,
          total: 1000,
        ),
      ]);
      expect(find.text('已暂停'), findsOneWidget);
      final resume = tester.widget<TextButton>(
        find
            .ancestor(of: find.text('继续'), matching: find.byType(TextButton))
            .first,
      );
      expect(resume.onPressed, isNotNull, reason: '继续接入 DownloadResume');
      // 暂停任务显示在「进行中」分组。
      expect(find.text('进行中 1'), findsOneWidget);
    });

    testWidgets('失败任务显示中文原因与重试入口', (tester) async {
      await _pump(tester, [
        _task(BigInt.one, '失败歌曲', state: 'failed', error: '网络超时'),
      ]);
      expect(find.textContaining('失败 · 网络超时'), findsOneWidget);
      final retry = tester.widget<TextButton>(
        find
            .ancestor(of: find.text('重试'), matching: find.byType(TextButton))
            .first,
      );
      expect(retry.onPressed, isNotNull);
    });

    testWidgets('已完成任务：删除按钮弹二次确认，确认后走删除命令', (tester) async {
      final model = AppModel();
      model.debugSetDownloads([_task(BigInt.one, '完成歌曲', state: 'done')]);
      var dispatched = 0;
      model.debugSetDispatcherForTest((command) async {
        if (command is bridge.FfiCommand_DownloadDeleteFile) dispatched += 1;
      });
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DownloadsPage(model))),
      );
      await tester.pump();

      final delete = tester.widget<TextButton>(
        find
            .ancestor(of: find.text('删除'), matching: find.byType(TextButton))
            .first,
      );
      expect(delete.onPressed, isNotNull);

      // §9：先弹二次确认对话框，确认后才下发删除。
      await tester.tap(find.text('删除'));
      await tester.pump();
      expect(find.text('删除下载文件'), findsOneWidget);
      expect(find.textContaining('将删除「完成歌曲」的本地文件'), findsOneWidget);
      expect(dispatched, 0);
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pump();
      expect(dispatched, 1);
    });

    testWidgets('已完成任务的打开/定位按钮禁用并说明（无后端命令）', (tester) async {
      await _pump(tester, [_task(BigInt.one, '完成歌曲', state: 'done')]);
      final open = tester.widget<TextButton>(
        find
            .ancestor(of: find.text('打开'), matching: find.byType(TextButton))
            .first,
      );
      expect(open.onPressed, isNull, reason: '后端没有打开文件命令，按钮必须禁用');
      final locate = tester.widget<TextButton>(
        find
            .ancestor(of: find.text('定位'), matching: find.byType(TextButton))
            .first,
      );
      expect(locate.onPressed, isNull);
    });

    testWidgets('筛选切换只显示对应分组，计数徽章汇总', (tester) async {
      await _pump(tester, [
        _task(
          BigInt.one,
          '进行中歌曲',
          state: 'downloading',
          active: true,
          downloaded: 10,
          total: 100,
        ),
        _task(BigInt.two, '完成歌曲', state: 'done'),
        _task(BigInt.from(3), '失败歌曲', state: 'failed', error: '网络错误'),
      ]);

      expect(find.text('全部 3'), findsOneWidget);
      expect(find.text('进行中 1'), findsOneWidget);
      expect(find.text('已完成 1'), findsOneWidget);
      expect(find.text('失败 1'), findsOneWidget);

      await tester.tap(find.text('失败 1'));
      await tester.pump();
      expect(find.text('失败歌曲'), findsOneWidget);
      expect(find.text('进行中歌曲'), findsNothing);
      expect(find.text('完成歌曲'), findsNothing);
    });

    testWidgets('无已完成任务时清除已完成禁用；有则启用', (tester) async {
      await _pump(tester, [
        _task(
          BigInt.one,
          '进行中歌曲',
          state: 'downloading',
          active: true,
          downloaded: 10,
          total: 100,
        ),
      ]);
      final clear = tester.widget<TextButton>(
        find
            .ancestor(of: find.text('清除已完成'), matching: find.byType(TextButton))
            .first,
      );
      expect(clear.onPressed, isNull);

      await _pump(tester, [_task(BigInt.two, '完成歌曲', state: 'done')]);
      final clear2 = tester.widget<TextButton>(
        find
            .ancestor(of: find.text('清除已完成'), matching: find.byType(TextButton))
            .first,
      );
      expect(clear2.onPressed, isNotNull);
    });

    testWidgets('空列表给出「去发现音乐/管理下载目录」入口并走导航总线', (tester) async {
      await _pump(tester, const []);
      expect(find.text('暂无下载任务'), findsOneWidget);
      expect(find.text('去发现音乐'), findsOneWidget);
      expect(find.text('管理下载目录'), findsOneWidget);

      await tester.tap(find.text('去发现音乐'));
      await tester.pump();
      expect(nav_bus.navRequest.value, 3, reason: 'mapLegacyNavIndex(3)=发现页');

      await tester.tap(find.text('管理下载目录'));
      await tester.pump();
      expect(nav_bus.navRequest.value, 7, reason: 'mapLegacyNavIndex(7)=设置页');
    });

    testWidgets('筛选空组与全空列表区分文案', (tester) async {
      await _pump(tester, [_task(BigInt.one, '完成歌曲', state: 'done')]);
      await tester.tap(find.text('失败 0'));
      await tester.pump();
      expect(find.text('该分组下没有任务'), findsOneWidget);
      expect(find.text('切换筛选查看其他任务'), findsOneWidget);
    });

    // ── Batch E（§8.3/P3-09）：字节口径与失败详情展开 ──

    testWidgets('百分比封顶 100：已收字节超过声明总量不显示 >100%（P3-09）', (tester) async {
      await _pump(tester, [
        _task(
          BigInt.one,
          '倒挂任务',
          state: 'downloading',
          active: true,
          downloaded: 1500000,
          total: 500,
        ),
      ]);
      // 进度条夹取 + 百分比封顶 100（原始字节如实：体积行原样显示）。
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('150%'), findsNothing);
    });

    testWidgets('总量信息不一致：原始字节如实展示并附说明（不篡改）', (tester) async {
      await _pump(tester, [
        _task(
          BigInt.one,
          '倒挂任务',
          state: 'downloading',
          active: true,
          downloaded: 1500000,
          total: 500,
        ),
      ]);
      expect(find.textContaining('服务器总量信息不一致'), findsOneWidget);
      expect(find.textContaining('1.4 MB'), findsOneWidget);
      expect(find.textContaining('500 B'), findsOneWidget);
    });

    testWidgets('总量未知：显示已下载大小，不显示虚假总量与百分比', (tester) async {
      await _pump(tester, [
        _task(
          BigInt.one,
          '未知总量',
          state: 'downloading',
          active: true,
          downloaded: 2048,
        ),
      ]);
      expect(find.textContaining('已下载 2.0 KB'), findsOneWidget);
      expect(find.text('100%'), findsNothing);
    });

    testWidgets('失败原因行内截断：点按展开完整原因对话框并可复制（P3-09）', (tester) async {
      await _pump(tester, [
        _task(
          BigInt.one,
          '失败任务',
          state: 'failed',
          error: '音频分片校验失败：分片 3/7 的 sha256 与清单不一致（完整原因文本，用于验证不截断）',
        ),
      ]);
      // 行内是截断文案；点按展开对话框含完整原因（不截断）与复制按钮。
      await tester.tap(find.textContaining('失败 · 音频分片校验失败'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('失败详情'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('（完整原因文本，用于验证不截断）'),
        ),
        findsOneWidget,
      );
      expect(find.text('复制'), findsOneWidget);
      // 复制写剪贴板并提示。
      await tester.tap(find.text('复制'));
      await tester.pump();
      expect(find.text('已复制失败原因'), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('失败详情'), findsNothing);
    });

    testWidgets('560 窄窗：进行中任务状态行无横向溢出（P3-09 overflow 回归）', (tester) async {
      await _pump560(tester, [
        _task(
          BigInt.one,
          '一个相当长的歌曲名称用来挤压状态行与速度文本的宽度边界',
          state: 'downloading',
          active: true,
          downloaded: 700000,
          total: 1000000,
          error: null,
        ),
      ]);
      expect(tester.takeException(), isNull, reason: '560 窄窗无溢出（P3-09）');
    });
  });
}

Future<void> _pump560(
  WidgetTester tester,
  List<bridge.DownloadTaskDto> tasks,
) async {
  tester.view.physicalSize = const Size(560, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final model = AppModel();
  model.debugSetDownloads(tasks);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: DownloadsPage(model))),
  );
  await tester.pump();
}

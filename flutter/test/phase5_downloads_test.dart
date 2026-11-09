/// Phase 5 下载页：任务列表表格、状态→操作映射、筛选与中文原因。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
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
  await tester.pumpWidget(MaterialApp(home: DownloadsPage(model)));
  await tester.pump();
}

void main() {
  group('状态 → 操作映射（纯函数）', () {
    test('下载中：可取消，暂停/重试/打开不可用（无对应命令）', () {
      final ops = downloadRowOpsFor(
        _task(BigInt.one, 'a', state: 'downloading', active: true),
      );
      expect(ops.canCancel, isTrue);
      expect(ops.canPause, isFalse, reason: '后端没有暂停命令');
      expect(ops.canRetry, isFalse);
      expect(ops.canOpenFile, isFalse, reason: '后端没有打开文件命令');
    });

    test('排队中：与下载中同组（进行中）', () {
      final ops = downloadRowOpsFor(_task(BigInt.one, 'a', state: 'queued'));
      expect(ops.canCancel, isTrue);
      expect(ops.canRetry, isFalse);
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

    test('已完成/已跳过：无任何可用命令（打开/定位禁用占位）', () {
      final ops = downloadRowOpsFor(_task(BigInt.one, 'a', state: 'completed'));
      expect(ops.canOpenFile, isFalse);
      expect(ops.canRetry, isFalse);
      expect(ops.canCancel, isFalse);
    });

    test('状态中文映射不抛英文枚举', () {
      expect(downloadStateLabel('queued'), '排队中');
      expect(downloadStateLabel('downloading'), '下载中');
      expect(downloadStateLabel('completed'), '已完成');
      expect(downloadStateLabel('failed'), '失败');
      expect(downloadStateLabel('cancelled'), '已取消');
      expect(downloadStateLabel('skipped'), '已跳过');
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
  });

  group('下载页表格', () {
    testWidgets('进行中任务显示进度与取消，完成显示已完成的中文状态', (tester) async {
      await _pump(tester, [
        _task(
          BigInt.one,
          '进行中歌曲',
          state: 'downloading',
          active: true,
          downloaded: 720,
          total: 1000,
        ),
        _task(BigInt.two, '已完成歌曲', state: 'completed'),
      ]);

      expect(find.text('下载中'), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);
      // 取消按钮对进行中任务可用。
      final cancel = tester.widget<TextButton>(
        find
            .ancestor(of: find.text('取消'), matching: find.byType(TextButton))
            .first,
      );
      expect(cancel.onPressed, isNotNull);
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

    testWidgets('已完成任务的打开/定位按钮禁用并说明（无后端命令）', (tester) async {
      await _pump(tester, [_task(BigInt.one, '完成歌曲', state: 'completed')]);
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
        _task(BigInt.two, '完成歌曲', state: 'completed'),
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

      await _pump(tester, [_task(BigInt.two, '完成歌曲', state: 'completed')]);
      final clear2 = tester.widget<TextButton>(
        find
            .ancestor(of: find.text('清除已完成'), matching: find.byType(TextButton))
            .first,
      );
      expect(clear2.onPressed, isNotNull);
    });

    testWidgets('空列表与筛选空组给出区分文案', (tester) async {
      await _pump(tester, const []);
      expect(find.text('暂无下载任务'), findsOneWidget);

      await _pump(tester, [_task(BigInt.one, '完成歌曲', state: 'completed')]);
      await tester.tap(find.text('失败 0'));
      await tester.pump();
      expect(find.text('该分组下没有任务'), findsOneWidget);
      expect(find.text('切换筛选查看其他任务'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/widgets/sync_dialog.dart';

const _preview = bridge.SyncPreviewDto(
  playlists: 2,
  favorites: 1,
  songs: 30,
  added: 1,
  updated: 1,
  removed: 0,
  failures: [],
  rows: [
    bridge.SyncRowDto(
      name: '通勤',
      kind: '歌单',
      cached: 10,
      remote: 12,
      status: '更新',
    ),
    bridge.SyncRowDto(
      name: '新歌单',
      kind: '歌单',
      cached: 0,
      remote: 8,
      status: '新增',
    ),
  ],
);

Future<void> _openDialog(WidgetTester tester, AppModel model) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showSyncDialog(context, model, 'wy'),
              child: const Text('打开同步'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开同步'));
  await tester.pump();
}

void main() {
  testWidgets('预览态展示远端统计与明细，确认后进入执行态', (tester) async {
    final model = AppModel();
    await _openDialog(tester, model);
    expect(find.text('正在读取远端歌单…'), findsOneWidget);

    model.debugSetSync(phase: 'preview', preview: _preview);
    await tester.pump();

    expect(find.textContaining('远端 2 个歌单'), findsOneWidget);
    expect(find.textContaining('预计新增 1'), findsOneWidget);
    expect(find.text('通勤'), findsOneWidget);
    expect(find.text('新增'), findsOneWidget);
    expect(find.text('开始同步'), findsOneWidget);

    await tester.tap(find.text('开始同步'));
    await tester.pump();

    expect(find.text('正在拉取并写入本地镜像…'), findsOneWidget);
    expect(find.text('取消同步'), findsOneWidget);
  });

  testWidgets('执行进度按 done/total 展示', (tester) async {
    final model = AppModel();
    await _openDialog(tester, model);
    model.debugSetSync(phase: 'running', done: 3, total: 12);
    await tester.pump();

    expect(find.text('正在写入本地镜像… 3 / 12'), findsOneWidget);
  });

  testWidgets('完成态展示结果与失败明细', (tester) async {
    final model = AppModel();
    await _openDialog(tester, model);
    model.debugSetSync(
      phase: 'done',
      report: const bridge.SyncReportDto(
        playlists: 2,
        favorites: 1,
        songs: 30,
        added: 1,
        updated: 1,
        removed: 0,
        failures: [bridge.SyncFailureDto(name: '旧歌单', reason: '频控')],
      ),
    );
    await tester.pump();

    expect(find.text('同步完成'), findsOneWidget);
    expect(find.textContaining('歌单 2'), findsOneWidget);
    expect(find.text('· 旧歌单：频控'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
  });

  testWidgets('失败态展示错误与重试', (tester) async {
    final model = AppModel();
    await _openDialog(tester, model);
    model.debugSetSync(phase: 'failed', error: '尚未登录网易云，请先在「设置 → 扫码登录」登录');
    await tester.pump();

    expect(find.text('同步失败'), findsOneWidget);
    expect(find.textContaining('尚未登录网易云'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('取消态展示已取消', (tester) async {
    final model = AppModel();
    await _openDialog(tester, model);
    model.debugSetSync(phase: 'cancelled', error: '同步已取消');
    await tester.pump();

    expect(find.text('同步已取消'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('重试会重新发起预览', (tester) async {
    final model = AppModel();
    await _openDialog(tester, model);
    model.debugSetSync(phase: 'failed', error: '网络错误');
    await tester.pump();

    await tester.tap(find.text('重试'));
    await tester.pump();

    expect(model.syncPhase, 'previewing');
    expect(find.text('正在读取远端歌单…'), findsOneWidget);
  });
}

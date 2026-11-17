/// 错误/通知文案净化 + toast 高度上限回归（指南 §9 / QA 2026-11-10 P1）。
///
/// QA 发现：离线聚合搜索失败时，原始异常（含多音源完整 URL）经
/// `lastError` 原样进入 myune toast（单行 Flexible 无 maxLines），toast
/// 高度无上限，把 VxErrorState 的可读错误、详情框与重试按钮全部遮挡。
/// 修复两层：
/// 1. AppModel 源头净化——URL 打码、空白折叠、截断 140；原始异常写 stderr
///    日志（§9：原始异常写日志，不把 URL/token/隐私路径暴露到 UI）；
/// 2. vendored ToastNotificationWidget 兜底限高（maxLines 4 + maxHeight 160，
///    本地改造已标注 seam 来源）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/myune/services/notification_service.dart';
import 'package:voicefox_flutter/src/myune/widgets/toast_notification_widget.dart';

void main() {
  group('AppModel.sanitizeUserFacingMessage 单元', () {
    test('URL 整体打码：多音源完整 URL 不再出现在用户文案中', () {
      final raw =
          '聚合搜索失败: http://kwwlovew.kuwo.cn/api/search?key=love&token=abc '
          'https://music.163.com/api/search?q=love';
      final out = AppModel.sanitizeUserFacingMessage(raw);
      expect(out.contains('http'), isFalse, reason: '§9：完整 URL 不得直出 UI');
      expect(out.contains('token=abc'), isFalse);
      expect(out.contains('[URL]'), isTrue, reason: 'URL 位置用占位符保留可读性');
      expect(out.contains('聚合搜索失败'), isTrue, reason: '可读的错误前缀保留');
    });

    test('多行原始异常折叠为单行（toast 高度不再被 \\n 撑高）', () {
      final raw = '下载失败\n  at fetchCover()\n  caused by: timeout after 12s';
      final out = AppModel.sanitizeUserFacingMessage(raw);
      expect(out.contains('\n'), isFalse, reason: '换行折叠为空格，toast 单行限高');
      expect(out.contains('  '), isFalse, reason: '连续空白折叠');
      expect(out.contains('timeout after 12s'), isTrue, reason: '可读原因保留');
    });

    test('超长消息截断到 140 字符 + 省略号', () {
      final out = AppModel.sanitizeUserFacingMessage('长' * 500);
      expect(out.length, 141, reason: '140 正文 + 1 省略号');
      expect(out.endsWith('…'), isTrue);
    });

    test('空/纯空白消息落到兜底文案「操作失败」', () {
      expect(AppModel.sanitizeUserFacingMessage(''), '操作失败');
      expect(AppModel.sanitizeUserFacingMessage('   \n  '), '操作失败');
    });

    test('事件驱动 lastError：search/playback 事件消息经净化后进入 UI 状态', () {
      final model = AppModel();
      model.debugHandleEventForTest(
        kind: 'search',
        message:
            'search failed: http://kg.example.com/search?token=secret-token-value',
      );
      expect(model.lastError, isNotNull);
      expect(model.lastError!.contains('http'), isFalse);
      expect(model.lastError!.contains('secret-token-value'), isFalse);
      expect(model.lastError!.contains('[URL]'), isTrue);
    });

    test('原始异常字符串（Exception 前缀）同样净化', () {
      // _sendCommand 的 catch 会把 '$error' 交给 _logAndSanitize；
      // 无控制器路径不易构造含 URL 的异常，此处验证同一净化契约。
      final readable = AppModel.sanitizeUserFacingMessage(
        'Exception: http://x/y?z=1  failed',
      );
      expect(readable, 'Exception: [URL] failed');
    });
  });

  group('ToastNotificationWidget 高度上限（兜底层）', () {
    Widget host(AppNotification notification) => MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              right: 12,
              bottom: 80,
              child: ToastNotificationWidget(
                notification: notification,
                animation: const AlwaysStoppedAnimation(1),
                onDismiss: () {},
                onHoverStart: () {},
                onHoverEnd: () {},
              ),
            ),
          ],
        ),
      ),
    );

    testWidgets('超长单行错误消息：toast 高度有上限，不遮整页', (tester) async {
      tester.view.physicalSize = const Size(948, 1010);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final long = 'a' * 500;
      await tester.pumpWidget(
        host(
          AppNotification(
            id: 't1',
            message: long,
            type: NotificationType.error,
          ),
        ),
      );
      await tester.pump();

      final toastRect = tester.getRect(find.byType(ToastNotificationWidget));
      expect(
        toastRect.height,
        lessThanOrEqualTo(200),
        reason: 'QA P1：toast 高度必须有上限（约 160 + padding），不得遮整页',
      );
      // Toast 文本实际渲染为 RichText（Text 内部），按 RichText 断言行数。
      final richTexts = tester
          .widgetList<RichText>(find.byType(RichText))
          .where((r) => (r.text.toPlainText().contains(long)))
          .toList();
      expect(richTexts, hasLength(1), reason: '超长消息渲染为一个文本');
      expect(richTexts.single.maxLines, 4, reason: '文本限 4 行 + 省略');
      expect(
        richTexts.single.overflow,
        TextOverflow.ellipsis,
        reason: '截断以省略号呈现',
      );
    });

    testWidgets('多行（\\n）错误消息同样被折叠限高', (tester) async {
      tester.view.physicalSize = const Size(948, 1010);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final multiline = List.generate(20, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        host(
          AppNotification(
            id: 't2',
            message: multiline,
            type: NotificationType.error,
          ),
        ),
      );
      await tester.pump();

      final toastRect = tester.getRect(find.byType(ToastNotificationWidget));
      expect(
        toastRect.height,
        lessThanOrEqualTo(200),
        reason: '20 行原始异常不得把 toast 撑到整页高（QA P1 截图 ~520px）',
      );
    });

    testWidgets('常规短消息 toast 不受影响（复制/关闭按钮仍在）', (tester) async {
      tester.view.physicalSize = const Size(948, 1010);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(
          AppNotification(
            id: 't3',
            message: '播放失败，请重试',
            type: NotificationType.error,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
      final toastRect = tester.getRect(find.byType(ToastNotificationWidget));
      expect(toastRect.height, lessThan(100), reason: '短消息保持紧凑');
    });
  });
}

/// P1-05/P2-08 崩溃取证回归（main.dart crash log）：
/// - FlutterError / 未处理异常统一落盘 crash.log（与 ffi/crash_log.rs 同
///   格式：`[unix秒] kind: body`），消除静默退出的取证盲区；
/// - append 语义（多次错误累积，不覆盖前一条）；
/// - 用例内保存/还原 FlutterError.onError 与 PlatformDispatcher.onError，
///   不向同进程后续用例泄漏全局回调。
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/main.dart';

void main() {
  late String path;
  late FlutterExceptionHandler? previousFlutterOnError;
  late bool Function(Object error, StackTrace stackTrace)?
  previousDispatcherOnError;

  setUp(() {
    path =
        '${Directory.systemTemp.path}/voicefox-crash-test-'
        '${DateTime.now().microsecondsSinceEpoch}/crash.log';
    previousFlutterOnError = FlutterError.onError;
    previousDispatcherOnError = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = previousFlutterOnError;
    PlatformDispatcher.instance.onError = previousDispatcherOnError;
    Directory(
      path,
    ).parent.delete(recursive: true).catchError((_) => Directory(path).parent);
  });

  test('FlutterError 与未处理异常落盘同一文件（append 累积）', () {
    installCrashLogHandlers(path: path);

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('boom'),
        library: 'crash_log_test',
      ),
    );
    final handled = PlatformDispatcher.instance.onError!(
      Exception('unhandled'),
      StackTrace.current,
    );

    final lines = File(path).readAsStringSync().trim().split('\n');
    expect(lines.length, greaterThan(2), reason: 'unhandled 记录按设计带多行堆栈');
    expect(lines[0], contains('] flutter-error: Bad state: boom'));
    expect(lines[1], contains('] unhandled: Exception: unhandled'));
    expect(handled, isTrue, reason: '未处理异常被接管（返回 true 表示已处理）');
  });
}

/// B4（dynamicColor 单一权威）：SettingsProvider 旧 prefs key
/// `useDynamicColor` → `useCoverDynamicColor` 迁移回归。
///
/// 锁定：
/// - 旧 key 显式 false → 迁移为 false（语义保持关闭）；
/// - 旧 key true（旧默认）/ 缺失 → 新默认 false（与 Rust config.dynamicColor
///   默认对齐；旧默认 true 无法与用户显式开启区分，一律落新默认）；
/// - 迁移结果落盘新 key，旧 key 只读不回写；
/// - setter 写新 key，不再触碰旧 key；
/// - 已迁移（新 key 存在）时直接读新 key，旧 key 值被忽略。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/myune/page/setting/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 让出事件循环，等待 SettingsProvider 内部 fire-and-forget 的
  /// getInstance/setBool 链在 mock 存储上完成落盘。
  Future<void> flushAsyncWrites() async {
    for (var i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<SharedPreferences> freshPrefs(
    Map<String, Object> initialValues,
  ) async {
    SharedPreferences.setMockInitialValues(initialValues);
    return SharedPreferences.getInstance();
  }

  group('useDynamicColor → useCoverDynamicColor 迁移', () {
    test('旧 key 显式 false → 新 key 落盘 false', () async {
      final prefs = await freshPrefs({'useDynamicColor': false});
      final provider = SettingsProvider();
      await provider.initializationFuture;
      await flushAsyncWrites();
      expect(provider.useCoverDynamicColor, isFalse);
      expect(prefs.getBool('useCoverDynamicColor'), isFalse);
    });

    test('旧 key true（旧默认）→ 迁移为新默认 false', () async {
      final prefs = await freshPrefs({'useDynamicColor': true});
      final provider = SettingsProvider();
      await provider.initializationFuture;
      await flushAsyncWrites();
      expect(provider.useCoverDynamicColor, isFalse);
      expect(prefs.getBool('useCoverDynamicColor'), isFalse);
    });

    test('旧 key 缺失 → 新默认 false 并写入新 key', () async {
      final prefs = await freshPrefs(<String, Object>{});
      final provider = SettingsProvider();
      await provider.initializationFuture;
      await flushAsyncWrites();
      expect(provider.useCoverDynamicColor, isFalse);
      expect(prefs.getBool('useCoverDynamicColor'), isFalse);
    });

    test('已迁移（新 key 存在）→ 直接读新 key，忽略旧 key', () async {
      final prefs = await freshPrefs({
        'useDynamicColor': true,
        'useCoverDynamicColor': true,
      });
      final provider = SettingsProvider();
      await provider.initializationFuture;
      expect(provider.useCoverDynamicColor, isTrue);
      // 新 key 保持用户已落盘的值，不被迁移逻辑覆盖
      expect(prefs.getBool('useCoverDynamicColor'), isTrue);
    });

    test('setter 写新 key useCoverDynamicColor，旧 key 不被写入', () async {
      final prefs = await freshPrefs(<String, Object>{});
      final provider = SettingsProvider();
      await provider.initializationFuture;

      provider.setUseCoverDynamicColor(true);
      await flushAsyncWrites();

      expect(provider.useCoverDynamicColor, isTrue);
      expect(prefs.getBool('useCoverDynamicColor'), isTrue);
      expect(prefs.getBool('useDynamicColor'), isNull);

      provider.setUseCoverDynamicColor(false);
      await flushAsyncWrites();
      expect(provider.useCoverDynamicColor, isFalse);
      expect(prefs.getBool('useCoverDynamicColor'), isFalse);
    });
  });
}

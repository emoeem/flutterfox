import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/theme/registry.dart';
import 'package:voicefox_flutter/src/theme/seed_colors.dart';
import 'package:voicefox_flutter/src/theme/voicefox_theme.dart';

void main() {
  testWidgets('主题注册表：TUI 同源 16 套完整，全量 key 构建 ThemeData 不抛异常', (tester) async {
    expect(kSeedThemes.length, 16);
    // 同源 key 全部在注册表中（铁律：seed_colors.dart 是唯一来源）
    for (final seed in kSeedThemes) {
      expect(themeEntryOf(seed.key).key, seed.key);
    }
    // 全量主题（16 同源 + FlClash 定制 + flex 内置扩展）都能构建
    for (final entry in kAllThemes) {
      final theme = buildVoicefoxTheme(entry.key, Brightness.dark);
      expect(theme.colorScheme.primary, isNot(0));
    }
  });

  test('未知主题 key 回退 Catppuccin Mocha（与 TUI 默认一致）', () {
    expect(themeEntryOf('nonexistent-theme').key, 'catppuccin-mocha');
  });

  test('AppModel 初始状态为空快照', () {
    final model = AppModel();
    expect(model.ready, isFalse);
    expect(model.state.queue, isEmpty);
    // 动态取色默认关：具名主题按色板原样呈现
    expect(model.useDynamicColor, isFalse);
  });
}

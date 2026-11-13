/// P2-02 回归：ThemeData 产源收口护栏。
///
/// 运行时唯一真源 = `myune/theme/theme_provider.dart`（ColorScheme.fromSeed
/// + MiSans，main.dart MaterialApp 消费）。另有两个**预览专用**构建器：
/// - `src/theme/voicefox_theme.dart` buildVoicefoxTheme：设置页主题色卡
///   逐卡预览（每张卡展示该主题自己的配色，设计行为）+ myune_preview；
/// - `src/design_system/voicefox_theme.dart` buildDark/LightTheme：
///   Gallery 预览页 + design_system 测试。
///
/// 本测试锁死运行时入口（main.dart / shell / myune provider）不得引入
/// 任一预览构建器，防止全局主题被预览产源静默接管；并确认设置页的
/// 引用仍限定在逐卡预览语义（import 在位 = 该例外被有意保留）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('运行时入口不引入预览主题构建器（P2-02）', () {
    const runtimeFiles = [
      'lib/main.dart',
      'lib/src/shell/app_shell.dart',
      'lib/src/shell/responsive_shell.dart',
      'lib/src/myune/theme/theme_provider.dart',
      'lib/src/app_model.dart',
    ];
    for (final relative in runtimeFiles) {
      final source = File(relative).readAsStringSync();
      expect(
        source.contains("src/theme/voicefox_theme.dart") ||
            source.contains('design_system/voicefox_theme.dart'),
        isFalse,
        reason: '$relative 运行时不得引入预览主题构建器（P2-02 单一真源）',
      );
    }
  });

  test('设置页主题色卡预览例外仍限定在 settings_page（P2-02）', () {
    final source = File('lib/src/pages/settings_page.dart').readAsStringSync();
    expect(
      source.contains(
        "import '../theme/voicefox_theme.dart' show buildVoicefoxTheme;",
      ),
      isTrue,
      reason: '逐卡预览的设计行为被有意保留（_ThemeCard 展示每张卡自己的配色）',
    );
  });
}

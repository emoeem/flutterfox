/// ThemeData 产源收口护栏（P2-02 立法，B1 修订，B2 追加入口护栏）。
///
/// 运行时唯一真源 = `src/theme/app_theme.dart` buildAppTheme（B1 统一主题
/// 构建器：44 套注册表主题显式色板 + VxTypography 层级 + VxPalette 扩展），
/// 由 `myune/theme/theme_provider.dart` 的 lightThemeData/darkThemeData
/// getters 委托消费；`myune_shell/projection.dart` 推 themeKey。
///
/// 构建器产源分两类：
/// - `src/theme/voicefox_theme.dart`：**运行时产源**（B1 升格）——app_theme
///   复用其 flclash 分层 / FlexThemeData / GappedSliderTrackShape 机制；
///   buildVoicefoxTheme 本体仍服务设置页主题色卡逐卡预览 + myune_preview；
/// - `src/design_system/voicefox_theme.dart`：**预览专用**（Gallery 页 +
///   design_system 测试），运行时入口不得引入（Vx 色板已经 app_theme.dart
///   显式槽位映射下发，预览产源不得静默接管全局主题）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('运行时入口不引入 design_system 预览构建器（P2-02，B1 修订）', () {
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
        source.contains('design_system/voicefox_theme.dart'),
        isFalse,
        reason:
            '$relative 运行时不得引入 design_system 预览构建器'
            '（Vx 色板经 app_theme.dart 显式映射下发，P2-02 单一真源）',
      );
    }
  });

  test('运行时主题链路委托统一构建器 buildAppTheme（B1）', () {
    final source = File(
      'lib/src/myune/theme/theme_provider.dart',
    ).readAsStringSync();
    expect(
      source.contains("import '../../theme/app_theme.dart'"),
      isTrue,
      reason: 'ThemeProvider getters 必须委托 buildAppTheme（B1 单一真源）',
    );
    expect(
      source.contains('buildAppTheme'),
      isTrue,
      reason: 'lightThemeData/darkThemeData 不得再 fromSeed/misansTextTheme',
    );
  });

  test('src/theme/voicefox_theme.dart 升格运行时产源，app_theme 复用其机制（B1）', () {
    final source = File('lib/src/theme/app_theme.dart').readAsStringSync();
    expect(
      source.contains("import 'voicefox_theme.dart'"),
      isTrue,
      reason:
          'app_theme 复用 flclash 分层 / FlexThemeData / GappedSliderTrackShape',
    );
  });

  test('设置页主题色卡逐卡预览仍走 buildVoicefoxTheme（设计行为保留）', () {
    final source = File('lib/src/pages/settings_page.dart').readAsStringSync();
    expect(
      source.contains(
        "import '../theme/voicefox_theme.dart' show buildVoicefoxTheme;",
      ),
      isTrue,
      reason: '逐卡预览展示每张卡自己的配色，属设计行为而非全局主题切换',
    );
  });

  test('main.dart 入口无内联主题产源（B2）', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      source.contains('ColorScheme.fromSeed'),
      isFalse,
      reason:
          'main.dart 不得内联 fromSeed（uiOnly/引导骨架屏统一走 '
          'buildAppTheme，B2 入口收敛）',
    );
    expect(
      source.contains('0xFF89B4FA'),
      isFalse,
      reason:
          'main.dart 不得硬编码 mocha seed 色值'
          '（色值唯一来源 src/theme/seed_colors.dart）',
    );
    expect(
      source.contains('ThemeData('),
      isFalse,
      reason:
          'main.dart 不得裸构 ThemeData（入口主题统一委托 '
          'src/theme/app_theme.dart buildAppTheme，B2）',
    );
  });
}

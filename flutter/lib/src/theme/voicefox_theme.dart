/// voicefox 主题构建：注册表项 → Material 3 ThemeData。
///
/// **非运行时真源**（P2-02 收口）：运行时唯一真源 =
/// `myune/theme/theme_provider.dart`（ColorScheme.fromSeed + MiSans）。
/// 本构建器按注册表 key 构建任意主题，现仅用于设置页主题色卡的**逐卡
/// 预览**（settings_page.dart `_ThemeCard`：每张卡展示该主题自己的真实
/// 配色，属设计行为而非全局主题切换）与 myune_preview.dart / 测试。
/// 运行时入口不得引入本构建器——由 test/theme_source_guard_test.dart
/// 锁定（P2-02）。
///
/// 规则见 docs/flutter_ui_spec.md §2/§5/§6 与 FlClash 源码规范：
/// - seed 类主题（TUI 同源 16 套 + FlClash 定制）：flclash_scheme 的 HCT 中性
///   分层（页面底/卡面/块面三级，accent tone clamp）；
/// - flex 扩展主题：flex_color_scheme 内置方案配色，表面由其自管；
/// - 动态色（Android 12+）由 AppModel 决定是否使用（dynamic_color 包）；
/// - 亮度不匹配的主题强制按自身明暗构建（如 dark 主题配 light 模式时）；
/// - 字体回退链按平台注入（typography.dart）；
/// - 滑块 = FlClash M3 规格（厚 gapped 轨 + 小主色 thumb）。
library;

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'flclash_scheme.dart';
import 'registry.dart';
import 'seed_colors.dart';
import 'typography.dart';

/// 主题 key → 对应 seed（仅 seed 类）；未知 key 回退 CatppuccinMocha。
SeedTheme seedThemeOf(String key) {
  for (final theme in kSeedThemes) {
    if (theme.key == key) return theme;
  }
  return kSeedThemes.firstWhere((t) => t.key == 'catppuccin-mocha');
}

/// 构建明/暗两套 ThemeData。dynamicScheme 非 null 时以其 primary 为种子，
/// 表面仍按命名主题 bg 分层（保持主题个性）。
ThemeData buildVoicefoxTheme(
  String themeKey,
  Brightness brightness, {
  ColorScheme? dynamicScheme,
}) {
  final entry = themeEntryOf(themeKey);
  final ThemeData base;

  if (dynamicScheme != null && entry.bgHex != null) {
    base = ThemeData(
      useMaterial3: true,
      colorScheme: flclashScheme(
        seed: dynamicScheme.primary,
        background: Color(hexOf(entry.bgHex!)),
        brightness: brightness,
      ),
    );
  } else if (entry.flex != null) {
    // flex 主题按自身明暗构建，主题个性优先于当前模式。
    base = entry.dark
        ? FlexThemeData.dark(scheme: entry.flex)
        : FlexThemeData.light(scheme: entry.flex);
  } else {
    // seed / FlClash 定制：HCT 分层配色。
    final ownBrightness = entry.dark ? Brightness.dark : Brightness.light;
    base = ThemeData(
      useMaterial3: true,
      colorScheme: flclashScheme(
        seed: Color(hexOf(entry.accentHex!)),
        background: Color(hexOf(entry.bgHex!)),
        brightness: ownBrightness,
      ),
    );
  }
  return _voicefoxComponents(base);
}

/// voicefox 全套组件规格（叠加在任意 base 之上）。
ThemeData _voicefoxComponents(ThemeData base) {
  final scheme = base.colorScheme;
  final dark = scheme.brightness == Brightness.dark;
  final withFonts = base.copyWith(
    textTheme: applyFontFallback(base.textTheme, base.platform),
  );
  return withFonts.copyWith(
    // spec §2：深色卡片=surfaceContainer、浅色卡片=surface（更浅）；
    // 页面底浅色时用 surfaceContainer。
    scaffoldBackgroundColor: dark ? scheme.surface : scheme.surfaceContainer,
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? scheme.surfaceContainer : scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: const StadiumBorder()),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorShape: const StadiumBorder(),
    ),
    progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
      linearMinHeight: 6,
      borderRadius: BorderRadius.circular(8),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      // FlClash M3 规格：厚 gapped 轨 + 小主色 thumb（lib/ui/theme.dart）
      trackHeight: 14,
      trackShape: const GappedSliderTrackShape(gap: 6),
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.secondaryContainer,
      thumbColor: scheme.primary,
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 9,
        elevation: 0,
      ),
      overlayColor: Colors.transparent,
      valueIndicatorColor: scheme.inverseSurface,
    ),
  );
}

/// FlClash 风格 gapped 滑轨：thumb 两侧各留缺口，激活段主色、未激活段次容器色。
class GappedSliderTrackShape extends RoundedRectSliderTrackShape {
  final double gap;

  const GappedSliderTrackShape({this.gap = 6});

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    required TextDirection textDirection,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final radius = Radius.circular(trackRect.height / 2);
    final activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? const Color(0xFF2196F3);
    final inactivePaint = Paint()
      ..color =
          sliderTheme.inactiveTrackColor ??
          activePaint.color.withValues(alpha: 0.24);

    void drawSegment(double left, double right, Paint paint) {
      if (right - left < radius.x * 2) return; // 太短画不出圆头
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, trackRect.top, right, trackRect.bottom),
          radius,
        ),
        paint,
      );
    }

    // thumb 左侧为激活段（主色），右侧为未激活段。
    drawSegment(trackRect.left, thumbCenter.dx - gap, activePaint);
    drawSegment(thumbCenter.dx + gap, trackRect.right, inactivePaint);
  }
}

/// voicefox 主题构建：命名 seed → Material 3 ColorScheme。
///
/// 规则见 docs/flutter_ui_spec.md §5：
/// - ColorScheme.fromSeed 生成 light/dark 各一套；
/// - surface 三档用主题 bg 覆盖，保住各命名主题的底色个性；
/// - Android 12+ 动态色由 AppModel 决定是否使用（dynamic_color 包）。
library;

import 'package:flutter/material.dart';

import 'seed_colors.dart';

Color _bgOf(SeedTheme theme) => Color(hexOf(theme.bg));

/// 主题 key → 对应 seed；未知 key 回退 CatppuccinMocha（与 TUI 默认一致）。
SeedTheme seedThemeOf(String key) {
  for (final theme in kSeedThemes) {
    if (theme.key == key) return theme;
  }
  return kSeedThemes.firstWhere((t) => t.key == 'catppuccin-mocha');
}

/// 构建明/暗两套 ThemeData。dynamicScheme 非 null 时以其为基础，
/// 仅覆盖 surface 三档为命名主题的 bg（保持主题个性）。
ThemeData buildVoicefoxTheme(String themeKey, Brightness brightness,
    {ColorScheme? dynamicScheme}) {
  final seed = seedThemeOf(themeKey);
  var scheme = dynamicScheme ??
      ColorScheme.fromSeed(
        seedColor: Color(hexOf(seed.accent)),
        brightness: brightness,
      );
  // 亮度不匹配的 seed 强制取色板自身明暗（如 dark 主题配 light 模式时）
  if (dynamicScheme == null && seed.dark != (brightness == Brightness.dark)) {
    scheme = ColorScheme.fromSeed(
      seedColor: Color(hexOf(seed.accent)),
      brightness: seed.dark ? Brightness.dark : Brightness.light,
    );
  }
  final bg = _bgOf(seed);
  scheme = scheme.copyWith(
    surface: bg,
    surfaceContainerHighest: Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.06),
      bg,
    ),
    surfaceContainer: Color.alphaBlend(
      scheme.primary.withValues(alpha: 0.04),
      bg,
    ),
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainer,
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
    navigationRailTheme: NavigationRailThemeData(
      indicatorShape: const StadiumBorder(),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      // 参考 FlClash：gapped track + 反色数值指示
      trackHeight: 4,
    ),
  );
}

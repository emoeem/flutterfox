/// Voicefox 运行时 ThemeData 真源（Phase 1）。
///
/// 由 `design_tokens.dart` 生成深 / 浅两套 ThemeData，目标是收敛
/// `theme/voicefox_theme.dart`（旧预览路径）与 `myune/theme/theme_provider.dart`
/// 的双真源不一致（Phase 0 F4）。接入 Shell 后运行时应只走本构建器。
///
/// 规则：
/// - Token 是唯一颜色来源，页面不得自行硬编码颜色；
/// - TextTheme 保留层级：标题 w600-w700，正文 w400，禁止全 w400；
/// - 时间 / 数值用等宽数字（tabular figures + JetBrainsMono 资产）；
/// - 浅色为独立调校对比度的色板，不是深色反转。
library;

import 'package:flutter/material.dart';

import '../theme/typography.dart' show kMonoFamily;
import 'design_tokens.dart';

/// 深色主题（默认）。
ThemeData buildDarkTheme() => _buildTheme(_darkScheme(), _darkTextTheme());

/// 浅色主题（独立调校对比度）。
ThemeData buildLightTheme() => _buildTheme(_lightScheme(), _lightTextTheme());

/// 等宽数字样式：tabular figures + JetBrainsMono（assets/fonts，OFL）。
TextStyle vxMonoStyle(Color? color, {double? fontSize}) =>
    VxTypography.mono.copyWith(
      fontFamily: kMonoFamily,
      color: color,
      fontSize: fontSize,
    );

ColorScheme _darkScheme() => const ColorScheme.dark(
  primary: VxColors.accent,
  onPrimary: VxColors.onAccent,
  secondary: VxColors.accentDeep,
  onSecondary: VxColors.onAccent,
  error: VxColors.error,
  onError: VxColors.onError,
  surface: VxColors.background,
  onSurface: VxColors.textPrimary,
  onSurfaceVariant: VxColors.textSecondary,
  outline: VxColors.divider,
  outlineVariant: VxColors.divider,
  surfaceContainerLowest: VxColors.scrim,
  surfaceContainerLow: VxColors.surface1,
  surfaceContainer: VxColors.surface2,
  surfaceContainerHigh: VxColors.surface3,
  surfaceContainerHighest: VxColors.hover,
  inverseSurface: VxColors.textPrimary,
  onInverseSurface: VxColors.background,
  inversePrimary: VxColors.accentDeep,
);

ColorScheme _lightScheme() => const ColorScheme.light(
  primary: VxLightColors.accent,
  onPrimary: VxLightColors.onAccent,
  secondary: VxLightColors.accentDeep,
  onSecondary: VxLightColors.onAccent,
  error: VxLightColors.error,
  onError: VxLightColors.onError,
  surface: VxLightColors.background,
  onSurface: VxLightColors.textPrimary,
  onSurfaceVariant: VxLightColors.textSecondary,
  outline: VxLightColors.divider,
  outlineVariant: VxLightColors.divider,
  surfaceContainerLowest: VxLightColors.surface2,
  surfaceContainerLow: VxLightColors.surface1,
  surfaceContainer: VxLightColors.surface3,
  surfaceContainerHigh: VxLightColors.hover,
  surfaceContainerHighest: VxLightColors.surface3,
  inverseSurface: VxLightColors.textPrimary,
  onInverseSurface: VxLightColors.background,
  inversePrimary: VxLightColors.accentDeep,
);

TextTheme _darkTextTheme() => _textTheme(
  primary: VxColors.textPrimary,
  secondary: VxColors.textSecondary,
);

TextTheme _lightTextTheme() => _textTheme(
  primary: VxLightColors.textPrimary,
  secondary: VxLightColors.textSecondary,
);

/// §6.3 字号表 → Material 文本角色映射。
TextTheme _textTheme({required Color primary, required Color secondary}) {
  TextStyle s(TextStyle base, {Color? color, double? size}) =>
      base.copyWith(color: color ?? primary, fontSize: size);
  return TextTheme(
    displayLarge: s(VxTypography.display),
    displayMedium: s(VxTypography.display, size: 30),
    displaySmall: s(VxTypography.display, size: 26),
    headlineLarge: s(VxTypography.h1),
    headlineMedium: s(VxTypography.h1, size: 24),
    headlineSmall: s(VxTypography.h2),
    titleLarge: s(VxTypography.title),
    titleMedium: s(VxTypography.title, size: 14),
    titleSmall: s(VxTypography.titleSm),
    bodyLarge: s(VxTypography.body, size: 15),
    bodyMedium: s(VxTypography.body),
    bodySmall: s(VxTypography.caption),
    labelLarge: s(VxTypography.title, color: secondary, size: 13),
    labelMedium: s(VxTypography.caption, color: secondary),
    labelSmall: s(VxTypography.caption, color: secondary, size: 11),
  );
}

ThemeData _buildTheme(ColorScheme scheme, TextTheme textTheme) {
  final dark = scheme.brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    hoverColor: scheme.onSurface.withValues(alpha: 0.04),
    splashColor: scheme.onSurface.withValues(alpha: 0.06),
    highlightColor: scheme.onSurface.withValues(alpha: 0.04),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: VxTypography.title.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VxRadius.lg),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VxRadius.xl),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outline,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: VxTypography.title.copyWith(fontSize: 13),
        minimumSize: const Size(64, 38),
        padding: const EdgeInsets.symmetric(horizontal: VxSpacing.xl),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        textStyle: VxTypography.title.copyWith(fontSize: 13),
        minimumSize: const Size(64, 38),
        padding: const EdgeInsets.symmetric(horizontal: VxSpacing.xl),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        textStyle: VxTypography.caption.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VxRadius.sm),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.onPrimary
            : scheme.onSurfaceVariant,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : scheme.surfaceContainerHighest,
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: scheme.primary,
      inactiveTrackColor: dark
          ? VxDarkSurface.seekTrack
          : VxLightColors.seekTrack,
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      valueIndicatorColor: scheme.surfaceContainerHigh,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: dark
          ? VxDarkSurface.seekTrack
          : VxLightColors.seekTrack,
      linearMinHeight: 4,
      borderRadius: BorderRadius.circular(VxRadius.sm),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VxRadius.md),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(VxRadius.sm),
      ),
      textStyle: VxTypography.caption.copyWith(color: scheme.onSurface),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: VxTypography.body.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VxRadius.md),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStateProperty.all(
        scheme.onSurfaceVariant.withValues(alpha: 0.35),
      ),
    ),
  );
}

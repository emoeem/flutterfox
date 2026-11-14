/// B1 统一主题构建器：注册表 key → 运行时 ThemeData（唯一真源）。
///
/// Phase 0 审计结论的收口：此前运行时 MaterialApp 主题来自
/// `myune/theme/theme_provider.dart`（ColorScheme.fromSeed + misansTextTheme
/// 全 w400），与 design_system/design_tokens.dart 的 Vx 色板完全脱节；44 套
/// 预设只有 16 套经投影生效。本构建器把三条产源合一：
///
/// - **默认家族**（catppuccin-mocha / catppuccin-latte，含未知 key 回退）：
///   显式槽位映射照抄 design_system/voicefox_theme.dart（bg→surface、
///   accent→primary 等），深浅各自取 VxColors / VxLightColors——设计稿
///   像素即默认主题像素；
/// - **seed / FlClash 定制**：flclash_scheme 的 HCT 中性分层（按主题自身
///   明暗构建，明暗错配时主题个性优先，同 buildVoicefoxTheme 规则）；
/// - **flex 扩展**：FlexThemeData 生成色板，**跟随传入亮度**（registry 对
///   flex 统一记 dark:true 是占位值，FlexScheme 本身无天然明暗）。
///
/// 无 M3 槽位的 token（seekTrack / onPlayIcon / hero 六值 / success /
/// warning / textMuted）经 ThemeExtension `VxPalette` 下发，组件用
/// `VxPalette.of(context)` 读取，替代散落的 `dark ?` 三元。
/// textTheme 按 VxTypography 层级映射（标题 w600-w700、正文 w400），
/// 注入平台字体回退链；misansTextTheme 不再参与。
///
/// 桥接：`myune/theme/theme_provider.dart` 的 lightThemeData/darkThemeData
/// 委托本构建器；`myune_shell/projection.dart` 推 themeKey。设计系统
/// 预览构建器（design_system/voicefox_theme.dart）仍不进运行时——由
/// test/theme_source_guard_test.dart 锁定。
library;

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design_system/design_tokens.dart';
import 'flclash_scheme.dart';
import 'registry.dart';
import 'seed_colors.dart';
import 'typography.dart';
// Flutter SDK 自带同名 GappedSliderTrackShape（material/slider_parts），
// 这里用的是本仓库 FlClash 规格实现，别名消歧。
import 'voicefox_theme.dart' as vx_theme show GappedSliderTrackShape;

/// 默认主题家族：Vx 设计稿色板对应的注册表 key（未知 key 回退 mocha，
/// 因此同样落入本家族）。
const List<String> _kDefaultFamilyKeys = ['catppuccin-mocha', 'catppuccin-latte'];

/// 运行时统一主题：44 套注册表 key × 明暗全部可构建。
///
/// [dynamicSeed] 非 null 时以它为强调色种子（DynamicColorBuilder 注入的
/// 系统调色板 / 封面取色路径），主题 bg 分层个性仅在明暗兼容时保留
/// （暗底主题配浅色请求时退回纯 fromSeed，避免暗底亮字）。
ThemeData buildAppTheme(
  String themeKey,
  Brightness brightness, {
  Color? dynamicSeed,
  String? fontFamily,
  TargetPlatform? platform,
}) {
  final entry = themeEntryOf(themeKey);
  final scheme = _schemeFor(entry, brightness, dynamicSeed);
  final dark = scheme.brightness == Brightness.dark;
  final effectivePlatform = platform ?? defaultTargetPlatform;
  final isDefault =
      dynamicSeed == null && _kDefaultFamilyKeys.contains(entry.key);
  final palette = _paletteFor(entry, scheme, dark, dynamicSeed != null);

  final textTheme = _appTextTheme(scheme).apply(
    fontFamilyFallback: appFontFamilyFallback(effectivePlatform),
    fontFamily: fontFamily,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [palette],
    textTheme: textTheme,
    // Vx 设计稿（默认家族）：页面底 = surface，两种模式一致；
    // 其余主题沿用 buildVoicefoxTheme 规则（§2：浅色页面底用 surfaceContainer）。
    scaffoldBackgroundColor:
        (isDefault || dark) ? scheme.surface : scheme.surfaceContainer,
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
      elevation: 0,
      color: dark ? scheme.surfaceContainer : scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1, space: 1),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: VxSpacing.md,
        vertical: VxSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VxRadius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VxRadius.md),
        borderSide: BorderSide(color: scheme.primary),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VxRadius.md)),
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
    navigationBarTheme: NavigationBarThemeData(
      indicatorShape: const StadiumBorder(),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: palette.seekTrack,
      linearMinHeight: 6,
      borderRadius: BorderRadius.circular(8),
    ),
    sliderTheme: SliderThemeData(
      // FlClash M3 规格：厚 gapped 轨 + 小主色 thumb（lib/ui/theme.dart）。
      trackHeight: 14,
      trackShape: const vx_theme.GappedSliderTrackShape(gap: 6),
      activeTrackColor: scheme.primary,
      inactiveTrackColor: palette.seekTrack,
      thumbColor: scheme.primary,
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 9,
        elevation: 0,
      ),
      overlayColor: Colors.transparent,
      valueIndicatorColor: scheme.inverseSurface,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: VxTypography.body.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStateProperty.all(
        scheme.onSurfaceVariant.withValues(alpha: 0.35),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(VxRadius.sm),
      ),
      textStyle: VxTypography.caption.copyWith(color: scheme.onSurface),
    ),
  );
}

/// 默认家族（Vx 设计稿）深色槽位映射——照抄 design_system/voicefox_theme.dart。
ColorScheme _vxDarkScheme() => const ColorScheme.dark(
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

/// 默认家族（Vx 设计稿）浅色槽位映射——独立调校对比度，非深色反转。
ColorScheme _vxLightScheme() => const ColorScheme.light(
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

/// 按 entry 类别构建显式 ColorScheme。
ColorScheme _schemeFor(ThemeEntry entry, Brightness brightness, Color? dynamicSeed) {
  // 动态种子优先（系统调色板 / 封面取色）；bg 分层个性仅在明暗兼容时保留。
  if (dynamicSeed != null) {
    final bgHex = entry.bgHex;
    final compatible =
        bgHex != null && entry.dark == (brightness == Brightness.dark);
    if (compatible) {
      return flclashScheme(
        seed: dynamicSeed,
        background: Color(hexOf(bgHex)),
        brightness: brightness,
      );
    }
    return ColorScheme.fromSeed(seedColor: dynamicSeed, brightness: brightness);
  }
  // 默认家族：Vx 设计稿显式槽位（像素锚点：mocha 深色 primary == VxColors.accent）。
  if (_kDefaultFamilyKeys.contains(entry.key)) {
    return brightness == Brightness.dark ? _vxDarkScheme() : _vxLightScheme();
  }
  // flex 扩展：包内置方案配色，跟随传入亮度（registry dark:true 是占位）。
  if (entry.flex != null) {
    return brightness == Brightness.dark
        ? FlexThemeData.dark(scheme: entry.flex).colorScheme
        : FlexThemeData.light(scheme: entry.flex).colorScheme;
  }
  // seed / FlClash 定制：HCT 分层，按主题自身明暗构建（个性优先）。
  final own = entry.dark ? Brightness.dark : Brightness.light;
  final bgHex = entry.bgHex;
  final accentHex = entry.accentHex;
  if (bgHex == null || accentHex == null) {
    return ColorScheme.fromSeed(
      seedColor: Color(hexOf(kSeedThemes.first.accent)),
      brightness: own,
    );
  }
  return flclashScheme(
    seed: Color(hexOf(accentHex)),
    background: Color(hexOf(bgHex)),
    brightness: own,
  );
}

/// §6.3 字号表 → Material 文本角色映射（照抄 design_system/voicefox_theme.dart）。
TextTheme _appTextTheme(ColorScheme scheme) {
  TextStyle s(TextStyle base, {Color? color, double? size}) =>
      base.copyWith(color: color ?? scheme.onSurface, fontSize: size);
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
    labelLarge: s(VxTypography.title, color: scheme.onSurfaceVariant, size: 13),
    labelMedium: s(VxTypography.caption, color: scheme.onSurfaceVariant),
    labelSmall: s(VxTypography.caption, color: scheme.onSurfaceVariant, size: 11),
  );
}

/// 无 M3 槽位的 token 下发：默认主题取 design_tokens.dart 常量（像素不变），
/// 其他主题从 ColorScheme 派生（hero 层次同 flclash 中性 tone 阶梯）或用
/// 中性默认（success/warning/textMuted 沿用 Vx 语义色）。
VxPalette _paletteFor(ThemeEntry entry, ColorScheme scheme, bool dark, bool dynamic) {
  final isDefault = !dynamic && _kDefaultFamilyKeys.contains(entry.key);
  if (isDefault) {
    return dark ? VxPalette.darkDefaults : VxPalette.lightDefaults;
  }
  return VxPalette(
    seekTrack: Color.lerp(scheme.surface, scheme.onSurface, dark ? 0.20 : 0.16)!,
    onPlayIcon: scheme.onPrimary,
    heroBorder: scheme.outline,
    heroGradientStart: scheme.surfaceContainerHigh,
    heroGradientMid: scheme.surfaceContainer,
    heroGradientEnd: dark ? scheme.surfaceContainerLow : scheme.surface,
    heroGlow: scheme.primary.withValues(alpha: dark ? 0.53 : 0.33),
    heroAccentGlow: scheme.primary.withValues(alpha: dark ? 0.11 : 0.14),
    success: dark ? VxColors.success : VxLightColors.success,
    warning: dark ? VxColors.warning : VxLightColors.warning,
    textMuted: dark ? VxColors.textMuted : VxLightColors.textMuted,
  );
}

/// Shell/组件层的补充 token（ThemeExtension，M3 机制随主题 lerp）。
///
/// 这些值没有 Material 3 ColorScheme 槽位（进度轨、播放圆钮图标、hero 渐变、
/// 语义色、弱文本），此前散落在 `dark ? VxColors.x : VxLightColors.x` 三元里，
/// 无法跟随 44 套主题。统一经本扩展随 ThemeData 下发，组件侧
/// `VxPalette.of(context)` 读取。
@immutable
class VxPalette extends ThemeExtension<VxPalette> {
  /// 进度条 / 滑块未激活轨底色。
  final Color seekTrack;

  /// 播放圆钮图标色（accent 底之上）。
  final Color onPlayIcon;

  /// Hero 的 1px 边线。
  final Color heroBorder;

  /// Hero 线性渐变起点。
  final Color heroGradientStart;

  /// Hero 线性渐变 55% 处。
  final Color heroGradientMid;

  /// Hero 线性渐变终点。
  final Color heroGradientEnd;

  /// Hero 左上径向高光。
  final Color heroGlow;

  /// Hero 右上模糊光斑。
  final Color heroAccentGlow;

  /// 成功语义。
  final Color success;

  /// 警告语义。
  final Color warning;

  /// 弱文本：辅助标签、禁用文字。
  final Color textMuted;

  const VxPalette({
    required this.seekTrack,
    required this.onPlayIcon,
    required this.heroBorder,
    required this.heroGradientStart,
    required this.heroGradientMid,
    required this.heroGradientEnd,
    required this.heroGlow,
    required this.heroAccentGlow,
    required this.success,
    required this.warning,
    required this.textMuted,
  });

  /// 默认主题（Vx 深色）取值——design_tokens.dart 对应常量，像素不变。
  static const VxPalette darkDefaults = VxPalette(
    seekTrack: VxDarkSurface.seekTrack,
    onPlayIcon: VxColors.onPlayIcon,
    heroBorder: VxDarkHero.border,
    heroGradientStart: VxDarkHero.gradientStart,
    heroGradientMid: VxDarkHero.gradientMid,
    heroGradientEnd: VxDarkHero.gradientEnd,
    heroGlow: VxDarkHero.glow,
    heroAccentGlow: VxDarkHero.accentGlow,
    success: VxColors.success,
    warning: VxColors.warning,
    textMuted: VxColors.textMuted,
  );

  /// 默认主题（Vx 浅色）取值。
  static const VxPalette lightDefaults = VxPalette(
    seekTrack: VxLightColors.seekTrack,
    onPlayIcon: VxLightColors.onPlayIcon,
    heroBorder: VxLightHero.border,
    heroGradientStart: VxLightHero.gradientStart,
    heroGradientMid: VxLightHero.gradientMid,
    heroGradientEnd: VxLightHero.gradientEnd,
    heroGlow: VxLightHero.glow,
    heroAccentGlow: VxLightHero.accentGlow,
    success: VxLightColors.success,
    warning: VxLightColors.warning,
    textMuted: VxLightColors.textMuted,
  );

  /// 便捷读取；主题未注入时（如裸 MaterialApp harness）回退深色默认。
  static VxPalette of(BuildContext context) =>
      Theme.of(context).extension<VxPalette>() ?? darkDefaults;

  @override
  VxPalette copyWith({
    Color? seekTrack,
    Color? onPlayIcon,
    Color? heroBorder,
    Color? heroGradientStart,
    Color? heroGradientMid,
    Color? heroGradientEnd,
    Color? heroGlow,
    Color? heroAccentGlow,
    Color? success,
    Color? warning,
    Color? textMuted,
  }) {
    return VxPalette(
      seekTrack: seekTrack ?? this.seekTrack,
      onPlayIcon: onPlayIcon ?? this.onPlayIcon,
      heroBorder: heroBorder ?? this.heroBorder,
      heroGradientStart: heroGradientStart ?? this.heroGradientStart,
      heroGradientMid: heroGradientMid ?? this.heroGradientMid,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
      heroGlow: heroGlow ?? this.heroGlow,
      heroAccentGlow: heroAccentGlow ?? this.heroAccentGlow,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  VxPalette lerp(VxPalette? other, double t) {
    if (other == null) return this;
    return VxPalette(
      seekTrack: Color.lerp(seekTrack, other.seekTrack, t)!,
      onPlayIcon: Color.lerp(onPlayIcon, other.onPlayIcon, t)!,
      heroBorder: Color.lerp(heroBorder, other.heroBorder, t)!,
      heroGradientStart: Color.lerp(heroGradientStart, other.heroGradientStart, t)!,
      heroGradientMid: Color.lerp(heroGradientMid, other.heroGradientMid, t)!,
      heroGradientEnd: Color.lerp(heroGradientEnd, other.heroGradientEnd, t)!,
      heroGlow: Color.lerp(heroGlow, other.heroGlow, t)!,
      heroAccentGlow: Color.lerp(heroAccentGlow, other.heroAccentGlow, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VxPalette &&
      other.seekTrack == seekTrack &&
      other.onPlayIcon == onPlayIcon &&
      other.heroBorder == heroBorder &&
      other.heroGradientStart == heroGradientStart &&
      other.heroGradientMid == heroGradientMid &&
      other.heroGradientEnd == heroGradientEnd &&
      other.heroGlow == heroGlow &&
      other.heroAccentGlow == heroAccentGlow &&
      other.success == success &&
      other.warning == warning &&
      other.textMuted == textMuted;

  @override
  int get hashCode => Object.hash(
    seekTrack,
    onPlayIcon,
    heroBorder,
    heroGradientStart,
    heroGradientMid,
    heroGradientEnd,
    heroGlow,
    heroAccentGlow,
    success,
    warning,
    textMuted,
  );
}

// 代码来源: https://github.com/flutter/flutter/issues/182466#issuecomment-3932182424
// 旨在修复 Flutter 3.40+ 鼠标点击光标被移除的问题
// 参考 https://github.com/flutter/flutter/issues/182466
// TODO: 请等待 Flutter 修复该问题
// B1：自 theme_provider.dart（vendored 私有扩展）上移为公有 helper，
// 供统一构建器与 vendored ThemeProvider 共用。
extension MouseClickableTheme on ThemeData {
  /// 给全部按钮/菜单组件补回点击光标（Flutter 3.40+ 回归的 workaround）。
  ThemeData makeMouseClickable() {
    final WidgetStateMouseCursor clickable =
        defaultTargetPlatform != TargetPlatform.android
        ? WidgetStateMouseCursor.clickable
        : WidgetStateMouseCursor.adaptiveClickable;
    return copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: (elevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
          mouseCursor: clickable,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: (filledButtonTheme.style ?? const ButtonStyle()).copyWith(
          mouseCursor: clickable,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: (outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
          mouseCursor: clickable,
        ),
      ),
      floatingActionButtonTheme: floatingActionButtonTheme.copyWith(
        mouseCursor: clickable,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: (iconButtonTheme.style ?? const ButtonStyle()).copyWith(
          mouseCursor: clickable,
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: (menuButtonTheme.style ?? const ButtonStyle()).copyWith(
          mouseCursor: clickable,
        ),
      ),
      menuTheme: MenuThemeData(
        submenuIcon: menuTheme.submenuIcon,
        style: (menuTheme.style ?? const MenuStyle()).copyWith(
          mouseCursor: clickable,
        ),
      ),
      checkboxTheme: checkboxTheme.copyWith(mouseCursor: clickable),
      popupMenuTheme: popupMenuTheme.copyWith(mouseCursor: clickable),
      segmentedButtonTheme: segmentedButtonTheme.copyWith(
        style: (segmentedButtonTheme.style ?? const ButtonStyle()).copyWith(
          mouseCursor: clickable,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: (textButtonTheme.style ?? const ButtonStyle()).copyWith(
          mouseCursor: clickable,
        ),
      ),
    );
  }
}

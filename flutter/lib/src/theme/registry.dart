/// 主题注册表：16 套 TUI 同源主题 + flex_color_scheme 内置扩展 + FlClash 定制。
///
/// 同源铁律：seed 主题只引用 `seed_colors.dart`（唯一来源 app/examples/theme_dump.rs），
/// 不在此处改写色值。flex 扩展主题取自 flex_color_scheme 包内置方案，
/// key 以 `flex:` 前缀存储；Rust 侧 config.theme.name 只是字符串，
/// TUI 对未知名字按自身规则回默认皮肤（core ThemeConfig 文档注明）。
library;

import 'package:flex_color_scheme/flex_color_scheme.dart';

import 'seed_colors.dart';

class ThemeEntry {
  final String key;
  final String label;

  /// 主题的天然明暗（预览与构建参考）。
  final bool dark;

  /// seed 类主题：色板底色/强调色（hex，"#RRGGBB"）。
  final String? bgHex;
  final String? accentHex;

  /// flex 类主题：包内置方案标识。
  final FlexScheme? flex;

  const ThemeEntry._(
    this.key,
    this.label,
    this.dark, {
    this.bgHex,
    this.accentHex,
    this.flex,
  });

  factory ThemeEntry.fromSeed(SeedTheme seed) => ThemeEntry._(
    seed.key,
    seed.label,
    seed.dark,
    bgHex: seed.bg,
    accentHex: seed.accent,
  );
}

/// 与 TUI 同源的 16 套（顺序与 seed_colors.dart 一致）。
final List<ThemeEntry> kSyncedThemes = [
  for (final seed in kSeedThemes) ThemeEntry.fromSeed(seed),
];

/// flex_color_scheme 内置扩展：覆盖主要色系的精选方案。
final List<ThemeEntry> kBuiltinThemes = [
  for (final scheme in const [
    (FlexScheme.materialBaseline, 'Material Baseline'),
    (FlexScheme.material, 'Material'),
    (FlexScheme.deepPurple, 'Deep Purple'),
    (FlexScheme.indigo, 'Indigo'),
    (FlexScheme.brandBlue, 'Brand Blue'),
    (FlexScheme.deepBlue, 'Deep Blue'),
    (FlexScheme.aquaBlue, 'Aqua Blue'),
    (FlexScheme.bahamaBlue, 'Bahama Blue'),
    (FlexScheme.bigStone, 'Big Stone'),
    (FlexScheme.ebonyClay, 'Ebony Clay'),
    (FlexScheme.shark, 'Shark'),
    (FlexScheme.mandyRed, 'Mandy Red'),
    (FlexScheme.red, 'Red'),
    (FlexScheme.redWine, 'Red Wine'),
    (FlexScheme.barossa, 'Barossa'),
    (FlexScheme.damask, 'Damask'),
    (FlexScheme.sakura, 'Sakura'),
    (FlexScheme.vesuviusBurn, 'Vesuvius Burn'),
    (FlexScheme.mango, 'Mango'),
    (FlexScheme.gold, 'Gold'),
    (FlexScheme.amber, 'Amber'),
    (FlexScheme.wasabi, 'Wasabi'),
    (FlexScheme.money, 'Money'),
    (FlexScheme.jungle, 'Jungle'),
    (FlexScheme.mallardGreen, 'Mallard Green'),
    (FlexScheme.espresso, 'Espresso'),
    (FlexScheme.flutterDash, 'Flutter Dash'),
  ])
    ThemeEntry._('flex:${scheme.$1.name}', scheme.$2, true, flex: scheme.$1),
];

/// FlClash 定制方案：对齐参考截图的紫红 accent + 近纯黑底。
const ThemeEntry kFlClashTheme = ThemeEntry._(
  'flclash',
  'FlClash 紫',
  true,
  bgHex: '#0D0D0D',
  accentHex: '#D64BF5',
);

/// 全量主题（同步组在前）。
final List<ThemeEntry> kAllThemes = [
  ...kSyncedThemes,
  kFlClashTheme,
  ...kBuiltinThemes,
];

/// key → 注册表项；未知 key 回退 Catppuccin Mocha（与 TUI 默认一致）。
ThemeEntry themeEntryOf(String key) {
  for (final entry in kAllThemes) {
    if (entry.key == key) return entry;
  }
  return kSyncedThemes.firstWhere((t) => t.key == 'catppuccin-mocha');
}

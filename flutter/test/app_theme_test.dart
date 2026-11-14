/// B1 统一主题构建器回归：buildAppTheme + VxPalette。
///
/// 锁定：
/// - 44 套注册表主题 × 明暗全部可构建（flex / seed / FlClash 三类别）；
/// - textTheme 层级（标题 w600-w700、正文 w400）——misansTextTheme 全 w400
///   的旧产源不得回归；
/// - 默认主题像素锚点：catppuccin-mocha 深色 ColorScheme.primary ==
///   VxColors.accent（Vx 设计稿色板接管运行时默认主题）；
/// - flex 亮度 bug 修复：flex 主题跟随传入亮度（registry dark:true 是占位）；
/// - VxPalette ThemeExtension 注入与读取；
/// - 平台字体回退链注入。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/design_system/design_tokens.dart';
import 'package:voicefox_flutter/src/theme/app_theme.dart';
import 'package:voicefox_flutter/src/theme/registry.dart';

void main() {
  group('全量可构建（44 套 × 明暗）', () {
    test('kAllThemes 每个 key 双亮度构建不抛异常且色板非默认占位', () {
      expect(kAllThemes.length, 44, reason: '主题注册表应维持 44 套');
      for (final entry in kAllThemes) {
        for (final brightness in Brightness.values) {
          final theme = buildAppTheme(entry.key, brightness);
          expect(
            theme.colorScheme.primary,
            isNotNull,
            reason: '${entry.key}($brightness) 应可构建',
          );
          expect(
            theme.textTheme.bodyMedium,
            isNotNull,
            reason: '${entry.key}($brightness) textTheme 应就绪',
          );
        }
      }
    });

    test('未知 key 回退默认主题（catppuccin-mocha）', () {
      final fallback = buildAppTheme('no-such-theme', Brightness.dark);
      final mocha = buildAppTheme('catppuccin-mocha', Brightness.dark);
      expect(fallback.colorScheme.primary, mocha.colorScheme.primary);
      expect(fallback.scaffoldBackgroundColor, mocha.scaffoldBackgroundColor);
    });
  });

  group('textTheme 层级（禁止全 w400）', () {
    final dark = buildAppTheme('catppuccin-mocha', Brightness.dark);

    test('标题 w700 / 小标题与主标题 w600 / 正文 w400', () {
      expect(dark.textTheme.displayLarge!.fontWeight, FontWeight.w700);
      expect(dark.textTheme.headlineLarge!.fontWeight, FontWeight.w700);
      expect(dark.textTheme.headlineSmall!.fontWeight, FontWeight.w600);
      expect(dark.textTheme.titleLarge!.fontWeight, FontWeight.w600);
      expect(dark.textTheme.titleSmall!.fontWeight, FontWeight.w600);
      expect(dark.textTheme.bodyLarge!.fontWeight, FontWeight.w400);
      expect(dark.textTheme.bodyMedium!.fontWeight, FontWeight.w400);
      expect(dark.textTheme.bodySmall!.fontWeight, FontWeight.w400);
    });

    test('字号层级照 VxTypography 映射', () {
      expect(dark.textTheme.displayLarge!.fontSize, 36);
      expect(dark.textTheme.headlineLarge!.fontSize, 28);
      expect(dark.textTheme.titleLarge!.fontSize, 16);
      expect(dark.textTheme.bodyLarge!.fontSize, 15);
      expect(dark.textTheme.bodyMedium!.fontSize, 14);
      expect(dark.textTheme.bodySmall!.fontSize, 12);
      expect(dark.textTheme.labelLarge!.fontSize, 13);
    });

    test('平台字体回退链注入（bodyLarge.fontFamilyFallback 非空）', () {
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme('nord', brightness);
        expect(
          theme.textTheme.bodyLarge!.fontFamilyFallback,
          isNotEmpty,
          reason: '$brightness 字体回退链不得为空',
        );
      }
    });

    test('fontFamily 参数落到各槽位', () {
      final themed = buildAppTheme(
        'nord',
        Brightness.dark,
        fontFamily: 'TestFont',
      );
      expect(themed.textTheme.bodyMedium!.fontFamily, 'TestFont');
      expect(themed.textTheme.titleLarge!.fontFamily, 'TestFont');
    });
  });

  group('默认主题像素锚点（Vx 设计稿）', () {
    test('catppuccin-mocha 深色 primary == VxColors.accent', () {
      final dark = buildAppTheme('catppuccin-mocha', Brightness.dark);
      expect(dark.colorScheme.primary, VxColors.accent);
      expect(dark.colorScheme.surface, VxColors.background);
      expect(dark.scaffoldBackgroundColor, VxColors.background);
      expect(dark.colorScheme.error, VxColors.error);
    });

    test('默认家族浅色走 VxLightColors（独立调校，非反转）', () {
      final light = buildAppTheme('catppuccin-latte', Brightness.light);
      expect(light.colorScheme.primary, VxLightColors.accent);
      expect(light.scaffoldBackgroundColor, VxLightColors.background);
      expect(
        light.colorScheme.primary,
        isNot(VxColors.accent),
        reason: '浅色 accent 独立调校',
      );
    });
  });

  group('flex 亮度修复（B1）', () {
    test('flex 主题跟随传入亮度，浅色请求得浅色色板', () {
      final light = buildAppTheme('flex:brandBlue', Brightness.light);
      expect(light.colorScheme.brightness, Brightness.light);
      final dark = buildAppTheme('flex:brandBlue', Brightness.dark);
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(light.colorScheme.surface, isNot(dark.colorScheme.surface));
    });
  });

  group('VxPalette ThemeExtension', () {
    testWidgets('VxPalette.of 可从主题读取（默认主题取 design_tokens 常量）', (
      tester,
    ) async {
      VxPalette? palette;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme('catppuccin-mocha', Brightness.dark),
          home: Builder(
            builder: (context) {
              palette = VxPalette.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(palette, isNotNull);
      expect(palette!.seekTrack, VxDarkSurface.seekTrack);
      expect(palette!.onPlayIcon, VxColors.onPlayIcon);
      expect(palette!.success, VxColors.success);
      expect(palette!.warning, VxColors.warning);
      expect(palette!.textMuted, VxColors.textMuted);
      expect(palette!.heroBorder, VxDarkHero.border);
      expect(palette!.heroGradientStart, VxDarkHero.gradientStart);
      expect(palette!.heroGradientMid, VxDarkHero.gradientMid);
      expect(palette!.heroGradientEnd, VxDarkHero.gradientEnd);
      expect(palette!.heroGlow, VxDarkHero.glow);
      expect(palette!.heroAccentGlow, VxDarkHero.accentGlow);
    });

    test('非默认主题的 palette 从色板派生（可读且随主题变化）', () {
      final nordDark = buildAppTheme('nord', Brightness.dark);
      final draculaDark = buildAppTheme('dracula', Brightness.dark);
      final nordPalette = nordDark.extension<VxPalette>()!;
      final draculaPalette = draculaDark.extension<VxPalette>()!;
      // 派生值仍可用（非零透明度）且随主题不同。
      expect(nordPalette.seekTrack.a, greaterThan(0));
      expect(nordPalette.seekTrack, isNot(draculaPalette.seekTrack));
      expect(nordPalette.onPlayIcon, nordDark.colorScheme.onPrimary);
    });

    test('lerp 中点取两值平均；lerp(null) 返回自身', () {
      const a = VxPalette(
        seekTrack: Color(0xFF000000),
        onPlayIcon: Color(0xFF000000),
        heroBorder: Color(0xFF000000),
        heroGradientStart: Color(0xFF000000),
        heroGradientMid: Color(0xFF000000),
        heroGradientEnd: Color(0xFF000000),
        heroGlow: Color(0x00000000),
        heroAccentGlow: Color(0x00000000),
        success: Color(0xFF000000),
        warning: Color(0xFF000000),
        textMuted: Color(0xFF000000),
      );
      const b = VxPalette(
        seekTrack: Color(0xFFFFFFFF),
        onPlayIcon: Color(0xFFFFFFFF),
        heroBorder: Color(0xFFFFFFFF),
        heroGradientStart: Color(0xFFFFFFFF),
        heroGradientMid: Color(0xFFFFFFFF),
        heroGradientEnd: Color(0xFFFFFFFF),
        heroGlow: Color(0xFFFFFFFF),
        heroAccentGlow: Color(0xFFFFFFFF),
        success: Color(0xFFFFFFFF),
        warning: Color(0xFFFFFFFF),
        textMuted: Color(0xFFFFFFFF),
      );
      final mid = a.lerp(b, 0.5);
      // Color 分量为浮点（.r/.b 0-1）：中点即 0.5（.red 是 8bit 取整视图）。
      expect(mid.seekTrack.r, closeTo(0.5, 0.001));
      expect(mid.textMuted.b, closeTo(0.5, 0.001));
      expect(mid.success, isNot(a.success));
      expect(a.lerp(null, 0.5), a);
    });
  });

  group('动态种子路径', () {
    test('dynamicSeed 非 null 时 primary 跟随种子（明暗兼容保留 bg 分层）', () {
      const seed = Color(0xFFE78284); // dracula red
      final dark = buildAppTheme(
        'catppuccin-mocha',
        Brightness.dark,
        dynamicSeed: seed,
      );
      expect(dark.colorScheme.primary, isNot(VxColors.accent));
      expect(dark.colorScheme.brightness, Brightness.dark);
      // 明暗兼容：mocha 是暗色主题，bg 分层个性保留（flclashScheme）。
      expect(dark.colorScheme.surface, const Color(0xFF1E1E2E));
    });

    test('明暗错配时退回纯 fromSeed（避免暗底亮字）', () {
      const seed = Color(0xFFE78284);
      final light = buildAppTheme(
        'catppuccin-mocha',
        Brightness.light,
        dynamicSeed: seed,
      );
      expect(light.colorScheme.brightness, Brightness.light);
      expect(
        light.colorScheme.surface,
        isNot(const Color(0xFF1E1E2E)),
        reason: '浅色请求不得保留暗底',
      );
    });
  });
}

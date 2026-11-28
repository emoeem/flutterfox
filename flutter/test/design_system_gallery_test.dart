/// design_system Gallery 冒烟测试（Phase 1 验收 2）。
///
/// 覆盖：
/// 1. GalleryPage 渲染全部基础组件（深色）；
/// 2. 深/浅主题切换开关工作且组件在浅色下仍渲染；
/// 3. Token 值与概念稿 CSS 变量一致；
/// 4. 标题层级保留（禁止全 w400）、浅色 accent 独立调校；
/// 5. 时间显示规则：缺失时长显示 `--:--`。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_album_card.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_artist_card.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_empty_state.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_error_state.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_hero.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_loading_skeleton.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_player_controls.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_playlist_card.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_seek_bar.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_section_header.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_track_row.dart';
import 'package:voicefox_flutter/src/design_system/design_tokens.dart';
import 'package:voicefox_flutter/src/design_system/gallery_page.dart';
import 'package:voicefox_flutter/src/design_system/voicefox_theme.dart';

void main() {
  testWidgets('GalleryPage 渲染全部基础组件（深色默认）', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GalleryPage()));
    await tester.pumpAndSettle();

    expect(GalleryPage.routeName, '/dev/gallery');
    expect(find.text('Voicefox UI Gallery'), findsOneWidget);
    expect(find.byType(VxSectionHeader), findsWidgets);
    expect(find.byType(VxTrackRow), findsNWidgets(4));
    expect(find.byType(VxAlbumCard), findsNWidgets(2));
    expect(find.byType(VxPlaylistCard), findsNWidgets(2));
    expect(find.byType(VxArtistCard), findsNWidgets(2));
    expect(find.byType(VxHero), findsOneWidget);
    expect(find.byType(VxEmptyState), findsOneWidget);
    expect(find.byType(VxLoadingSkeleton), findsNWidgets(4)); // 1 行骨架 + 3 书架卡
    expect(find.byType(VxErrorState), findsOneWidget);
    expect(find.byType(VxSeekBar), findsNWidgets(2));
    expect(find.byType(VxPlayerControls), findsNWidgets(3));
    // 时长缺失规则：TrackRow 样例 + 未知时长 seek 行都出现 --:--
    expect(find.text('--:--'), findsWidgets);
  });

  testWidgets('主题切换开关切到浅色后组件仍渲染', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GalleryPage()));
    await tester.pumpAndSettle();

    final appBarSwitch = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(Switch),
    );
    expect(appBarSwitch, findsOneWidget);
    await tester.tap(appBarSwitch);
    await tester.pumpAndSettle();

    expect(find.text('浅色预览'), findsOneWidget);
    expect(find.byType(VxHero), findsOneWidget);
    expect(find.byType(VxTrackRow), findsNWidgets(4));
    expect(find.byType(VxPlayerControls), findsNWidgets(3));
  });

  test('深色 Token 与 V2 冻结 spec v1.0 色板一致（docs/redesign/ui-redesign-v2）', () {
    expect(VxColors.background, const Color(0xFF1E1E2E)); // base（Mocha base）
    expect(VxColors.surface1, const Color(0xFF181825)); // elevated（mantle）
    expect(VxColors.surface2, const Color(0xFF262638)); // card
    expect(VxColors.surface3, const Color(0xFF313244)); // high（surface0）
    expect(VxColors.hover, const Color(0xFF45475A)); // Mocha surface1
    expect(VxColors.divider, const Color(0xFF3A3D54)); // 低对比灰紫
    expect(VxColors.textPrimary, const Color(0xFFCDD6F4)); // text-1
    expect(VxColors.textSecondary, const Color(0xFFA6ADC8)); // text-2
    expect(VxColors.textMuted, const Color(0xFF7F849C)); // text-3
    expect(VxColors.accent, const Color(0xFFCBA6F7)); // accent（Mauve）
    expect(VxColors.accentDeep, const Color(0xFFA98BDD)); // 次强调
    expect(VxColors.success, const Color(0xFFA6D189)); // Mocha green
    expect(VxColors.error, const Color(0xFFE78284)); // Mocha red
    expect(VxDarkHero.gradientStart, const Color(0xFF2B2C40)); // Hero 渐变
    expect(VxDarkHero.gradientMid, const Color(0xFF262638));
    expect(VxDarkHero.gradientEnd, const Color(0xFF1E1E2E));
    expect(VxDarkSurface.seekTrack, const Color(0xFF313244)); // 进度轨
  });

  test('标题层级保留（禁止全 w400）；浅色 accent 独立调校', () {
    final dark = buildDarkTheme();
    expect(dark.textTheme.displayLarge!.fontWeight, FontWeight.w700);
    expect(dark.textTheme.headlineLarge!.fontWeight, FontWeight.w700);
    expect(dark.textTheme.headlineSmall!.fontWeight, FontWeight.w600);
    expect(dark.textTheme.titleLarge!.fontWeight, FontWeight.w600);
    expect(dark.textTheme.titleSmall!.fontWeight, FontWeight.w600);
    expect(dark.textTheme.bodyMedium!.fontWeight, FontWeight.w400);
    expect(dark.colorScheme.primary, VxColors.accent);
    expect(dark.scaffoldBackgroundColor, VxColors.background);

    final light = buildLightTheme();
    // 浅色不是反转：accent 为 Latte Mauve（深紫加深），深色 Mauve 在白底对比不足。
    expect(light.colorScheme.primary, const Color(0xFF8839EF));
    expect(light.colorScheme.primary, isNot(VxColors.accent));
    expect(light.textTheme.displayLarge!.fontWeight, FontWeight.w700);
    expect(light.scaffoldBackgroundColor, VxLightColors.background);
  });

  test('时间显示规则：缺失时长显示 --:--，不伪造 00:00', () {
    expect(vxFormatDuration(null), '--:--');
    expect(vxFormatDuration(const Duration(minutes: 4, seconds: 32)), '04:32');
    expect(
      vxFormatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });
}

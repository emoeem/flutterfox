/// 字体策略（复刻 FlClash lib/ui/font.dart）：
/// 不打包中文字体，按平台给 CJK 后备列表，避免系统 fallback 挑错字形；
/// 数字/等宽场景用 JetBrainsMono（assets/fonts，OFL 许可）。
library;

import 'package:flutter/material.dart';

const _linuxHan = [
  'Noto Sans CJK SC',
  'Noto Sans SC',
  'Source Han Sans SC',
  'WenQuanYi Micro Hei',
];
const _windowsHan = [
  'Microsoft YaHei UI',
  'Microsoft JhengHei UI',
  'Yu Gothic UI',
  'Meiryo UI',
  'Malgun Gothic',
];
const _macHan = [
  'PingFang SC',
  'PingFang TC',
  'Hiragino Sans',
  'Apple SD Gothic Neo',
];

/// 平台 CJK 后备列表（Linux 分支与 FlClash 同序）。
List<String> hanFallback(TargetPlatform platform) => switch (platform) {
      TargetPlatform.windows => _windowsHan,
      TargetPlatform.macOS => _macHan,
      TargetPlatform.android => _linuxHan,
      _ => _linuxHan,
    };

/// 应用级字体回退：Material 2021 基座 + 平台 Han 列表。
List<String> appFontFamilyFallback(TargetPlatform platform) {
  final base = Typography.material2021(platform: platform).black.bodyMedium!;
  return [
    ...?base.fontFamilyFallback,
    ...hanFallback(platform),
  ];
}

/// 等宽数字字体（统计数字、时长标签）。
const String kMonoFamily = 'JetBrainsMono';

/// 给整个 textTheme 注入回退链。
TextTheme applyFontFallback(TextTheme textTheme, TargetPlatform platform) {
  final fallback = appFontFamilyFallback(platform);
  return textTheme.apply(fontFamilyFallback: fallback);
}

/// 等宽数字样式（在现有样式上换字体族，保留字号/字重/颜色）。
TextStyle monoStyle(BuildContext context, TextStyle? base) =>
    (base ?? Theme.of(context).textTheme.titleMedium!).copyWith(
      fontFamily: kMonoFamily,
      fontFamilyFallback: appFontFamilyFallback(Theme.of(context).platform),
    );

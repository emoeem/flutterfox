/// FlClash 式 HCT 分层配色（复刻其 lib/ui/color.dart 精髓）：
/// 表面走中性低色度（chroma ≤ 3）的 tone 层级——页面底之上，卡片亮几档、
/// 块面再多亮几档（dark），light 反向；accent 做 tone clamp 保证可读性。
/// 参考：FlClash dark cardTone 15 / blockTone 21 / insetTone 27、
/// _surfaceChroma 3.0、accent tone light 35-60 / dark 50-75。
library;

import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

const double _surfaceChroma = 3.0;

/// 以 [background]（主题 bg）为页面底，[seed]（主题 accent）为强调色构建。
ColorScheme flclashScheme({
  required Color seed,
  required Color background,
  required Brightness brightness,
}) {
  final dark = brightness == Brightness.dark;
  final bgHct = Hct.fromInt(background.toARGB32());
  final seedHct = Hct.fromInt(seed.toARGB32());

  // accent tone clamp（FlClash 规则）：dark 提亮保证对比，light 压暗避免刺眼。
  final accentTone = dark
      ? seedHct.tone.clamp(50.0, 78.0)
      : seedHct.tone.clamp(35.0, 60.0);
  final accent = _hct(seedHct.hue, seedHct.chroma, accentTone);

  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  );

  // 相对层级：保住各命名主题 bg 个性，同时得到 FlClash 的卡面分离感。
  final double cardTone;
  final double blockTone;
  final double lowTone;
  if (dark) {
    cardTone = bgHct.tone + 8;
    blockTone = bgHct.tone + 14;
    lowTone = bgHct.tone + 5;
  } else {
    cardTone = bgHct.tone - 4;
    blockTone = bgHct.tone - 7;
    lowTone = bgHct.tone - 2;
  }

  return scheme.copyWith(
    surface: background,
    surfaceContainerLow: _neutral(bgHct.hue, lowTone),
    surfaceContainer: _neutral(bgHct.hue, cardTone),
    surfaceContainerHighest: _neutral(bgHct.hue, blockTone),
  );
}

/// 中性表面色：保留底色色相，色度压到 3，tone 指定。
Color _neutral(double hue, double tone) =>
    _hct(hue, _surfaceChroma, tone.clamp(0.0, 100.0));

Color _hct(double hue, double chroma, double tone) =>
    Color(Hct.from(hue, chroma, tone).toInt());

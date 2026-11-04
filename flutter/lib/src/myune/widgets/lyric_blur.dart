// Vendored from https://github.com/xiaobaimc/myune_music @ 5188867b2f986e79260d8191c0c659bc1d2216ad
// License: Apache-2.0 (see /home/emo/code/myune_music-reference/LICENSE)
// Upstream logic kept as-is unless the seam (AudioService/adapters) requires it.
//
import 'package:flutter/painting.dart';

TextStyle buildLyricTextStyle({
  required Color lineColor,
  required double fontSize,
  required FontWeight fontWeight,
  required double blurSigma,
}) {
  final double radius = lyricShadowRadiusForSigma(blurSigma);
  if (radius > 0.0) {
    return TextStyle(
      fontSize: fontSize,
      height: 1.2,
      color: const Color(0x00000000),
      shadows: <Shadow>[Shadow(color: lineColor, blurRadius: radius)],
      fontWeight: fontWeight,
    );
  }
  return TextStyle(
    fontSize: fontSize,
    height: 1.2,
    color: lineColor,
    fontWeight: fontWeight,
  );
}

double lyricShadowRadiusForSigma(double sigma) =>
    sigma <= 0.5 ? 0.0 : (sigma - 0.5) / 0.57735;

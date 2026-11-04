// Vendored from https://github.com/xiaobaimc/myune_music @ 5188867b2f986e79260d8191c0c659bc1d2216ad
// License: Apache-2.0 (see /home/emo/code/myune_music-reference/LICENSE)
// Upstream logic kept as-is unless the seam (AudioService/adapters) requires it.
//
import 'package:flutter/widgets.dart';

// 把一个逻辑长度吸附到物理像素栅格上
double snapToDevicePixel(BuildContext context, double logicalLength) {
  final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  if (devicePixelRatio <= 0) {
    return logicalLength;
  }
  return (logicalLength * devicePixelRatio).roundToDouble() / devicePixelRatio;
}

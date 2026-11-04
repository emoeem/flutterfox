// Vendored from https://github.com/xiaobaimc/myune_music @ 5188867b2f986e79260d8191c0c659bc1d2216ad
// License: Apache-2.0 (see /home/emo/code/myune_music-reference/LICENSE)
// Upstream logic kept as-is unless the seam (AudioService/adapters) requires it.
//
import 'package:flutter/material.dart';

class InfoIcon extends StatelessWidget {
  const InfoIcon(
    this.message, {
    super.key,
    this.size = 20,
    this.icon = Icons.info_outline,
  });

  final String message;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final disabledColor = Theme.of(context).disabledColor;
    return Tooltip(
      message: message,
      child: Icon(icon, size: size, color: disabledColor),
    );
  }
}

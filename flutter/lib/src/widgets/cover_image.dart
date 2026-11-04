/// 封面图组件：网络封面 + 加载/缺省回退到图标占位盒。
///
/// 固定尺寸用 [CoverImage]（size 指定）；网格里自适应用 [CoverImage.expand]。
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CoverImage extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;
  final IconData icon;

  /// true 时撑满父级（网格单元），忽略 size。
  final bool expand;

  const CoverImage({
    super.key,
    required this.url,
    required this.size,
    this.radius = 8,
    this.icon = Icons.music_note_outlined,
  }) : expand = false;

  const CoverImage.expand({
    super.key,
    required this.url,
    this.radius = 12,
    this.icon = Icons.music_note_outlined,
  })  : size = 0,
        expand = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder() => DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Icon(icon,
              size: expand ? 32 : size * 0.4, color: scheme.onSurfaceVariant),
        );
    final source = url;
    final image = source == null || source.isEmpty
        ? placeholder()
        : CachedNetworkImage(
            imageUrl: source,
            fit: BoxFit.cover,
            width: expand ? double.infinity : size,
            height: expand ? double.infinity : size,
            placeholder: (_, _) => placeholder(),
            errorWidget: (_, _, _) => placeholder(),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: expand
          ? SizedBox.expand(child: image)
          : SizedBox(width: size, height: size, child: image),
    );
  }
}

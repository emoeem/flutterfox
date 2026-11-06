/// VxArtistBanner：歌手详情页顶部 Banner（§4.6，高 220-260）。
///
/// 有歌手照片时整幅照片 + 底部暗化 scrim；没有照片（或照片加载失败）时
/// 用封面渐变色板按歌手名稳定取色生成背景 + 大号首字，不显示破图 /
/// 灰色占位块（Phase 0 视觉验收原则）。
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// 歌手 Banner。纯展示：内容全部来自构造器。
class VxArtistBanner extends StatelessWidget {
  const VxArtistBanner({
    super.key,
    required this.name,
    this.photoUrl,
    this.sourceLabel,
    this.subtitle,
    this.height = 240,
  });

  /// 歌手名（Banner 左下角 30/700）。
  final String name;

  /// 歌手照片；null / 空 / 加载失败都回退到渐变背景。
  final String? photoUrl;

  /// 音源标识（如 网易云）。
  final String? sourceLabel;

  /// 副文案（如 专辑数）；null 不渲染。
  final String? subtitle;

  /// Banner 高度（§4.6：220-260）。
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    final hasPhoto = url != null && url.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(VxRadius.xl),
      child: Container(
        height: height,
        constraints: BoxConstraints(
          minHeight: 220,
          maxHeight: 260,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPhoto)
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => _gradientBackground(context),
                errorWidget: (_, _, _) => _gradientBackground(context),
              )
            else
              _gradientBackground(context),
            // 底部暗化 scrim：保证名字在任何背景下可读。
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.35, 1.0],
                  colors: [Color(0x00000000), Color(0xB3000000)],
                ),
              ),
            ),
            if (!hasPhoto) _giantInitial(context),
            Positioned(
              left: VxSpacing.xl,
              right: VxSpacing.xl,
              bottom: VxSpacing.xl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: -0.4,
                      color: Colors.white,
                    ),
                  ),
                  if (sourceLabel != null || subtitle != null) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (sourceLabel != null)
                          Text(
                            sourceLabel!,
                            style: VxTypography.caption.copyWith(
                              color: const Color(0xE6FFFFFF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (subtitle != null && subtitle!.trim().isNotEmpty)
                          Text(
                            subtitle!,
                            style: VxTypography.caption.copyWith(
                              color: const Color(0xB3FFFFFF),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 渐变背景：与缺封面占位同一色板，按歌手名稳定取色。
  Widget _gradientBackground(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: VxCoverGradients.forSeed(name),
      ),
    );
  }

  /// 无照片时右下角的超大首字（低透明度，纯装饰）。
  Widget _giantInitial(BuildContext context) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const SizedBox.expand();
    final first = String.fromCharCode(trimmed.runes.first).toUpperCase();
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0.92, 0.24),
        child: Text(
          first,
          style: TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.w800,
            height: 1.0,
            color: const Color(0x2EFFFFFF),
          ),
        ),
      ),
    );
  }
}

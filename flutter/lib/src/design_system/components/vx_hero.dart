/// VxHero：首页 Continue Listening Hero（§4.1 / 概念稿 `.hero`）。
///
/// 形态：18px 圆角面板 + 1px 边线 + 左上径向高光 + 右上强调色光斑 +
/// 大封面（178px、radius 12、投影）+ 文案区（eyebrow / 主标题 / 说明）+
/// 主次 pill 按钮。
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';
import 'vx_cover_fallback.dart';

/// 首页 Hero 面板。纯展示：内容与回调全部来自构造器。
class VxHero extends StatelessWidget {
  const VxHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.cover,
    this.fallbackSeed,
    this.minHeight = 218,
  });

  /// 小字标（如 CONTINUE LISTENING）。
  final String eyebrow;

  /// 主标题（28/700）。
  final String title;

  /// 说明文字（最多 2 行）。
  final String description;

  /// 主按钮文案（如 继续播放）。
  final String primaryLabel;

  /// 主按钮回调；null 时按钮禁用显示。
  final VoidCallback? onPrimary;

  /// 次按钮文案；null 不渲染次按钮。
  final String? secondaryLabel;

  /// 次按钮回调。
  final VoidCallback? onSecondary;

  /// 大封面；null 用渐变首字母占位。
  final Widget? cover;

  /// 占位渐变取色种子；null 用 [title]。
  final String? fallbackSeed;

  /// 面板最小高度（概念稿 min-height 218）。
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final heroBorder = dark ? VxDarkHero.border : VxLightHero.border;
    final start = dark ? VxDarkHero.gradientStart : VxLightHero.gradientStart;
    final mid = dark ? VxDarkHero.gradientMid : VxLightHero.gradientMid;
    final end = dark ? VxDarkHero.gradientEnd : VxLightHero.gradientEnd;
    final glow = dark ? VxDarkHero.glow : VxLightHero.glow;
    final accentGlow = dark
        ? VxDarkHero.accentGlow
        : VxLightHero.accentGlow;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VxRadius.xl),
        border: Border.all(color: heroBorder),
      ),
      child: Stack(
        children: [
          // 线性渐变底（112deg）
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-0.9, -0.4),
                  end: const Alignment(1.0, 0.6),
                  stops: const [0.0, 0.55, 1.0],
                  colors: [start, mid, end],
                ),
              ),
            ),
          ),
          // 左上径向高光（ellipse at 20% 20%）
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.6),
                  radius: 1.0,
                  stops: const [0.0, 0.48],
                  colors: [glow, Colors.transparent],
                ),
              ),
            ),
          ),
          // 右上强调色光斑（.hero:after，300px 圆 + blur）
          Positioned(
            right: 16,
            top: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [accentGlow, Colors.transparent],
                ),
              ),
            ),
          ),
          // 内容
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _heroArt(),
                const SizedBox(width: 26),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow,
                        style: VxTypography.eyebrow.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        title,
                        style: VxTypography.h1.copyWith(
                          color: scheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        description,
                        style: VxTypography.body.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: VxSpacing.lg),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: onPrimary,
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: Text(primaryLabel),
                          ),
                          if (secondaryLabel != null) ...[
                            const SizedBox(width: VxSpacing.sm),
                            OutlinedButton(
                              onPressed: onSecondary,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: scheme.onSurface.withValues(
                                  alpha: 0.06,
                                ),
                                side: BorderSide(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.14,
                                  ),
                                ),
                              ),
                              child: Text(secondaryLabel!),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroArt() {
    final inner = cover ?? VxCoverFallback(title: fallbackSeed ?? title, radius: VxRadius.lg);
    return Container(
      width: 178,
      height: 178,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VxRadius.lg),
        boxShadow: const [
          BoxShadow(color: Color(0x70000000), blurRadius: 32, offset: Offset(0, 14)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VxRadius.lg),
        child: inner,
      ),
    );
  }
}

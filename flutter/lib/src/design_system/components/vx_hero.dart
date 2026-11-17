/// VxHero：首页 Continue Listening Hero（§4.1 / 概念稿 `.hero`）。
///
/// 形态：18px 圆角面板 + 1px 边线 + 左上径向高光 + 右上强调色光斑 +
/// 大封面（178px、radius 12、投影）+ 文案区（eyebrow / 主标题 / 说明）+
/// 主次 pill 按钮。
///
/// 传入 [backgroundArt] 时（2026-11-18 外观修复：宽卡右侧 ~450px 空梯度
/// 观感），封面经模糊放大铺满整卡作背景层，渐变/高光层降透明度叠加其上，
/// 文案区可读性由渐变本身保证；null 时维持纯渐变形态。
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart' show VxPalette;
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
    this.backgroundArt,
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

  /// 背景模糊封面（铺满整卡，[cover] 的同一 URL 的更大尺寸实例）；
  /// null 维持纯渐变背景。传入后渐变/高光层降透明度叠加其上。
  final Widget? backgroundArt;

  /// 占位渐变取色种子；null 用 [title]。
  final String? fallbackSeed;

  /// 面板最小高度（概念稿 min-height 218）。
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // B3：hero 渐变六值随主题（VxPalette 扩展下发，非亮暗三元）。
    final palette = VxPalette.of(context);
    final heroBorder = palette.heroBorder;
    final start = palette.heroGradientStart;
    final mid = palette.heroGradientMid;
    final end = palette.heroGradientEnd;
    final glow = palette.heroGlow;
    final accentGlow = palette.heroAccentGlow;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VxRadius.xl),
        border: Border.all(color: heroBorder),
      ),
      child: Stack(
        children: [
          // 背景模糊封面（P0 外观修复：宽卡右侧空梯度收口）。置于渐变层
          // 之下；渐变/高光层降透明度后叠加，文案可读性由渐变保证。
          // 静态内容（无动效），Flutter 栅格缓存模糊层，无逐帧开销。
          if (backgroundArt != null)
            Positioned.fill(
              child: ClipRect(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Transform.scale(scale: 1.18, child: backgroundArt),
                ),
              ),
            ),
          // 线性渐变底（112deg）+ 左上径向高光：有背景封面时降透明度
          // 叠加（深色渐变仍保证 onSurface 文案 ≥4.5:1 可读性）。
          Positioned.fill(
            child: Opacity(
              opacity: backgroundArt != null ? 0.74 : 1.0,
              child: Stack(
                children: [
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
                ],
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
          // 内容：宽内容区（桌面全部档位，含 <960 降级档最小 ~480）走
          // 封面+文案并置 Row，视觉与 Phase 6 冻结态一致；窄内容区
          // （<320，手机档）封面与文案纵排堆叠，避免 178px 封面把文字列
          // 压扁导致按钮逐字换行（Phase 7 触屏适配）。
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 320;
                final textColumn = Column(
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
                      style: VxTypography.h1.copyWith(color: scheme.onSurface),
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
                    // Wrap：一行放下时与 Row 视觉一致；窄宽自动换行不溢出。
                    Wrap(
                      spacing: VxSpacing.sm,
                      runSpacing: VxSpacing.sm,
                      children: [
                        FilledButton.icon(
                          onPressed: onPrimary,
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: Text(primaryLabel),
                        ),
                        if (secondaryLabel != null)
                          OutlinedButton(
                            onPressed: onSecondary,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: scheme.onSurface.withValues(
                                alpha: 0.06,
                              ),
                              side: BorderSide(
                                color: scheme.onSurface.withValues(alpha: 0.14),
                              ),
                            ),
                            child: Text(secondaryLabel!),
                          ),
                      ],
                    ),
                  ],
                );
                if (wide) {
                  return Row(
                    children: [
                      _heroArt(),
                      const SizedBox(width: 26),
                      Expanded(child: textColumn),
                    ],
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: _heroArt()),
                    const SizedBox(width: 20),
                    textColumn,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroArt() {
    final inner =
        cover ??
        VxCoverFallback(title: fallbackSeed ?? title, radius: VxRadius.lg);
    return Container(
      width: 178,
      height: 178,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VxRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x70000000),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(VxRadius.lg),
        child: inner,
      ),
    );
  }
}

/// Shelf 卡片基座：1:1 封面 + 标题（1-2 行）+ 副标题（1 行）+ hover 播放钮。
///
/// AlbumCard / PlaylistCard / ArtistCard 共用本基座，保证封面比例、
/// 标题行数、hover 规则全应用一致（Phase 1 任务 5）。
/// 形态取自概念稿 `.album-art`（1:1、radius 12、轻阴影）与 `.track-name` / `.track-meta`。
/// V2 spec §4（`docs/redesign/ui-redesign-v2/design-spec.md`）：计数胶囊 +
/// 播放钮右下浮现；SR-11/15（Batch D）整卡可点 + 卡面右键。
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design_tokens.dart';
import 'vx_cover_fallback.dart';
import 'vx_hover.dart';

/// 1:1 封面内容卡。
class VxCardShell extends StatelessWidget {
  const VxCardShell({
    super.key,
    required this.title,
    this.subtitle,
    this.cover,
    this.fallbackSeed,
    this.width = 156,
    this.circle = false,
    this.centered = false,
    this.badge,
    this.onTap,
    this.onPlay,
    this.onSecondaryTapUp,
  });

  /// 标题，最多 2 行。
  final String title;

  /// 副标题，最多 1 行。
  final String? subtitle;

  /// 自定义封面；null 用渐变首字母占位。
  final Widget? cover;

  /// 占位渐变取色种子；null 用 [title]。
  final String? fallbackSeed;

  /// 卡片固定宽度（封面随宽度 1:1）。
  final double width;

  /// true 时封面为圆形（歌手头像）。
  final bool circle;

  /// true 时文字居中（歌手卡常用）。
  final bool centered;

  /// 封面右下角计数胶囊（如「12.4万」「28 首」）；hover 播放钮出现时隐藏
  /// （V2 spec §4：非 hover 态的信息位与 hover 播放钮同位互斥）。
  final String? badge;

  /// 单击卡片。
  final VoidCallback? onTap;

  /// hover 浮现的播放钮回调；null 则不浮现播放钮。
  final VoidCallback? onPlay;

  /// 右键回调（SR-11 残余收口：卡面右键菜单；null 则不响应右键）。
  final GestureTapUpCallback? onSecondaryTapUp;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = dark
        ? const Color(0x25000000)
        : const Color(0x1A000000);
    final crossAxis = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return SizedBox(
      width: width,
      // SR-11/15（Batch D）：整卡可点——此前仅封面区挂手势，标题/副标题
      // 是死区（用户点标题无响应，widget 测试实锤）。外层 GestureDetector
      // opaque 承接整卡；封面内 VxHoverBuilder 保留 hover 视觉与手型光标，
      // 命中竞态由手势竞技场就近解析（单次触发，不重复回调）。
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onSecondaryTapUp: onSecondaryTapUp,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: crossAxis,
          children: [
            VxHoverBuilder(
              onTap: onTap,
              onSecondaryTapUp: onSecondaryTapUp,
              builder: (context, hovering) => AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _cover(shadowColor),
                    if (badge != null)
                      // 计数胶囊（V2 spec §4）：深色底 + 模糊 + 白字，右下
                      // 角；hover 播放钮出现时隐藏（同位互斥防重叠）。
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: AnimatedOpacity(
                          opacity: hovering && onPlay != null ? 0 : 1,
                          duration: VxMotion.hoverFade,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                color: Colors.black.withValues(alpha: 0.55),
                                child: Text(
                                  badge!,
                                  style: VxTypography.mono.copyWith(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (onPlay != null)
                      AnimatedOpacity(
                        opacity: hovering ? 1 : 0,
                        duration: VxMotion.hoverFade,
                        curve: VxMotion.standard,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00000000), Color(0x73000000)],
                            ),
                          ),
                          child: Align(
                            // V2 spec §4：播放钮右下浮现（非居中）。
                            alignment: Alignment.bottomRight,
                            child: Container(
                              margin: const EdgeInsets.all(9),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                size: 21,
                                color: scheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: VxTypography.titleSm.copyWith(color: scheme.onSurface),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                style: VxTypography.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cover(Color shadowColor) {
    final inner =
        cover ??
        VxCoverFallback(
          title: fallbackSeed ?? title,
          radius: circle ? 0 : VxRadius.lg,
        );
    if (circle) {
      return DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(child: inner),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VxRadius.lg),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: const Offset(0, 6),
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

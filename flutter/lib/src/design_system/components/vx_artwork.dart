/// 唯一封面展示入口（指南 §3.4 `VxArtwork` + §8.2）。
///
/// - 解析经 [ArtworkResolver]：负缓存/退避/TTL/单飞（http 走
///   flutter_cache_manager）全部收口，页面不再散落 fallback 逻辑；
/// - 固定尺寸盒（[size] 或 [expand]），加载失败不造成布局跳动；
/// - 空占位（surfaceContainerHighest + 图标）、失败态（含可选重试）；
/// - 缩略图按展示尺寸限解码（[ArtworkResolver.decodeCacheWidth]）；
/// - 语义标签携带实体名（§11.2）。
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../services/artwork_resolver.dart';

class VxArtwork extends StatefulWidget {
  /// 封面 URL（http(s)/file:// / 本地绝对路径；空/null 显示占位）。
  final String? url;

  /// 来源 id（缓存键组成部分；本地实体传 `local`）。
  final String source;

  /// 实体类型（song/album/artist/playlist…；缓存键组成部分）。
  final String entityType;

  /// 实体 id（缓存键组成部分；缺失时按 URL 缓存）。
  final String entityId;

  /// 语义标签/占位种子（实体名）。
  final String entityName;

  /// 固定逻辑尺寸；[expand] 为 true 时忽略。
  final double size;

  /// true 时撑满父级（网格单元）。
  final bool expand;

  final double radius;
  final IconData icon;

  /// 失败态显示重试按钮（默认开；纯装饰场景可关）。
  final bool allowRetry;

  /// 可注入缓存管理器（测试注入脚本化 FileService；生产缺省走
  /// cached_network_image 的默认 manager）。
  final BaseCacheManager? cacheManager;

  const VxArtwork({
    super.key,
    required this.url,
    required this.source,
    required this.entityType,
    required this.entityId,
    this.entityName = '',
    required this.size,
    this.expand = false,
    this.radius = 8,
    this.icon = Icons.music_note_outlined,
    this.allowRetry = true,
    this.cacheManager,
  });

  @override
  State<VxArtwork> createState() => _VxArtworkState();
}

class _VxArtworkState extends State<VxArtwork> {
  ArtworkRequest get _request => ArtworkRequest(
    source: widget.source,
    entityType: widget.entityType,
    entityId: widget.entityId,
    url: widget.url,
    entityName: widget.entityName,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 语义标签覆盖所有分支（占位/失败/已解析），读屏可读出实体名（§11.2）。
    return Semantics(
      label: widget.entityName.isEmpty ? null : widget.entityName,
      excludeSemantics: widget.entityName.isNotEmpty,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: SizedBox(
          width: widget.expand ? double.infinity : widget.size,
          height: widget.expand ? double.infinity : widget.size,
          child: FutureBuilder<ArtworkResult>(
            future: ArtworkResolver.instance.resolve(_request),
            builder: (context, snapshot) {
              final result = snapshot.data;
              if (result == null) return _placeholder(scheme);
              switch (result.status) {
                case ArtworkStatus.empty:
                  // URL 缺失：纯占位（没有可重试的对象）。
                  return _placeholder(scheme);
                case ArtworkStatus.failed:
                  return _failed(scheme, result.failureReason);
                case ArtworkStatus.resolved:
                  return _resolved(context, result);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _resolved(BuildContext context, ArtworkResult result) {
    final request = _request;
    final provider = ArtworkResolver.instance.providerFor(
      request,
      result,
      logicalSize: widget.expand ? 300 : widget.size,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    if (provider != null) {
      return Image(
        image: provider,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        frameBuilder: _frameBuilder,
        errorBuilder: (_, _, _) {
          ArtworkResolver.instance.markDecodeFailed(request);
          return _placeholder(Theme.of(context).colorScheme);
        },
        semanticLabel: widget.entityName,
        excludeFromSemantics: widget.entityName.isEmpty,
      );
    }
    // http(s)：CachedNetworkImage 承担下载单飞与磁盘/内存缓存；
    // memCacheWidth 限制解码尺寸，避免列表小图解码超大原图。
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: result.resolvedUrl!,
      cacheManager: widget.cacheManager,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: ArtworkResolver.decodeCacheWidth(
        widget.expand ? 300 : widget.size,
        dpr,
      ),
      placeholder: (_, _) => _placeholder(Theme.of(context).colorScheme),
      errorWidget: (_, _, _) {
        ArtworkResolver.instance.markFetchFailed(request);
        return _failed(Theme.of(context).colorScheme, '封面加载失败');
      },
    );
  }

  /// 首帧淡入，避免解码完成瞬间的闪烁；错误帧直接落到占位。
  Widget _frameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded) return child;
    return AnimatedOpacity(
      opacity: frame == null ? 0 : 1,
      duration: const Duration(milliseconds: 150),
      child: child,
    );
  }

  Widget _placeholder(ColorScheme scheme) => DecoratedBox(
    decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
    child: Center(
      child: Icon(
        widget.icon,
        size: widget.expand ? 32 : widget.size * 0.4,
        color: scheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _failed(ColorScheme scheme, String? reason) => DecoratedBox(
    decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
    child: Center(
      child: widget.allowRetry
          ? IconButton(
              tooltip: '封面加载失败，点按重试${reason == null ? '' : '：$reason'}',
              icon: Icon(
                Icons.refresh,
                size: widget.expand ? 26 : widget.size * 0.4,
                color: scheme.onSurfaceVariant,
              ),
              onPressed: () {
                ArtworkResolver.instance.retry(_request);
                setState(() {});
              },
            )
          : Icon(
              widget.icon,
              size: widget.expand ? 32 : widget.size * 0.4,
              color: scheme.onSurfaceVariant,
            ),
    ),
  );
}

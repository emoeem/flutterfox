/// 封面图组件：网络封面 + 加载/缺省回退到图标占位盒。
///
/// 固定尺寸用 [CoverImage]（size 指定）；网格里自适应用 [CoverImage.expand]。
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 封面下载的 User-Agent。
///
/// 不能透传 dart:io 默认 UA（`Dart/<ver> (dart:io)`）：网易系封面 CDN
/// （p2.music.126.net 等）封杀含 `Dart/` 的 UA，一律 403 text/html
/// （Phase4-QA1 实锤：同一 URL curl 200 image/jpg / Dart 默认 UA 403 /
/// 换任意非 Dart UA 200）。表现即全屏播放页大封面持续显示失败灰占位，
/// 而队列行（酷我等不封 Dart UA 的音源）正常渲染。对齐 Rust 侧封面下载
/// 的 UA 家族（runtime/src/cover_src/source.rs 的 `voicefox/<版本>`）。
const String coverUserAgent = 'voicefox';

/// 与 Rust `cover_referer` 相同的按音源 Referer 映射（顺序一致）：
/// 部分音源 CDN 要求防盗链 Referer，Flutter 直拉与 Rust 下载保持同一行为。
String? coverReferer(String url) {
  if (url.contains('kuwo.cn')) return 'https://www.kuwo.cn/';
  if (url.contains('kugou.com')) return 'https://www.kugou.com/';
  if (url.contains('qq.com')) return 'https://y.qq.com/';
  if (url.contains('music.163.com') || url.contains('126.net')) {
    return 'https://music.163.com/';
  }
  return null;
}

/// [CoverImage] 网络请求头。
///
/// User-Agent 交给 flutter_cache_manager 的 HttpFileService（package:http
/// IOClient 以 `headers.set` 落到 dart:io 请求，io_client.dart:119-120），
/// 会整体覆写默认 UA 而非叠加，因此大封面与队列行共用本映射即可。
Map<String, String> coverImageHttpHeaders(String url) {
  final headers = <String, String>{'User-Agent': coverUserAgent};
  final referer = coverReferer(url);
  if (referer != null) headers['Referer'] = referer;
  return headers;
}

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
  }) : size = 0,
       expand = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget placeholder() => DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        size: expand ? 32 : size * 0.4,
        color: scheme.onSurfaceVariant,
      ),
    );
    final source = url;
    final image = source == null || source.isEmpty
        ? placeholder()
        : CachedNetworkImage(
            imageUrl: source,
            httpHeaders: coverImageHttpHeaders(source),
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

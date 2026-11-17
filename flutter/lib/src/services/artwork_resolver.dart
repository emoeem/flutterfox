/// 唯一封面解析与缓存服务（指南 §8.2）。
///
/// 页面不再散落各自的 URL fallback / 失败重试逻辑；封面统一经 [ArtworkResolver]
/// 解析、经 `VxArtwork`（design_system/components/vx_artwork.dart）展示。
///
/// 职责分工（避免同一 URL 双份下载）：
/// - http(s) 封面：本服务只做键管理、TTL 与失败负缓存记账；实际下载走
///   `VxArtwork` 内的 `CachedNetworkImage`（flutter_cache_manager 对同 URL
///   并发去重 + 磁盘/内存缓存，即 §8.2 的 single-flight）。
/// - 本地封面（绝对路径 / file://，含 Rust 扫描侧 embedded artwork 落盘路径）：
///   本服务校验存在性并给出限尺寸解码的 [FileImage]。
///
/// Phase 1 解析优先级落地范围（§8.2 六级中的 1/2/4/6）：
/// 1. DTO 携带的有效封面 URL；2. 同实体已缓存的有效封面；
/// 4. 本地路径 / file://；6. 统一占位（失败/空 URL）。
/// 第 3 级（音源补全接口）与第 5 级（可靠实体匹配补全）依赖后端补全链路，
/// 本阶段裁剪，已在 phase-1-report 登记。
///
/// 规则（§8.2）：
/// - 缓存 key 包含 source + entityType + entityId：不同来源同 ID 不冲突；
///   实体键缺失时退化为按 URL 缓存。
/// - 失败进入负缓存（有限重试 + 退避），不无限重试；`retry` 显式清除。
/// - TTL 到期重新解析；URL 过期场景由重新 resolve 覆盖。
/// - 404/403/超时/离线/非图片统一归为 failed 并带失败原因。
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 封面请求：DTO 字段的直接镜像，不含任何全局单例访问。
@immutable
class ArtworkRequest {
  final String source;
  final String entityType;
  final String entityId;

  /// DTO 上的主封面 URL（http(s)/file:// / 本地绝对路径）。
  final String? url;

  /// 语义标签/占位取色种子（实体名）。
  final String entityName;

  const ArtworkRequest({
    required this.source,
    required this.entityType,
    required this.entityId,
    required this.url,
    this.entityName = '',
  });
}

enum ArtworkStatus { resolved, failed, empty }

@immutable
class ArtworkResult {
  final ArtworkStatus status;

  /// http(s) URL 或本地路径；failed/empty 为 null。
  final String? resolvedUrl;

  /// 失败原因（用户可读；原始异常只进日志）。
  final String? failureReason;

  /// true = 本次结果来自缓存（未重新发起存在性检查/网络决策）。
  final bool fromCache;

  const ArtworkResult._(
    this.status,
    this.resolvedUrl,
    this.failureReason,
    this.fromCache,
  );

  const ArtworkResult.resolved(String url, {required bool cached})
    : this._(ArtworkStatus.resolved, url, null, cached);
  const ArtworkResult.failed(String reason)
    : this._(ArtworkStatus.failed, null, reason, false);
  const ArtworkResult.empty() : this._(ArtworkStatus.empty, null, null, false);
}

class _CacheEntry {
  ArtworkResult result;
  DateTime fetchedAt;
  int failCount;
  DateTime? nextAttemptAt;

  _CacheEntry(
    this.result,
    this.fetchedAt,
    this.failCount, [
    this.nextAttemptAt,
  ]);
}

class ArtworkResolver {
  ArtworkResolver._();

  static final ArtworkResolver instance = ArtworkResolver._();

  /// 内存缓存 TTL：到期后重新解析（URL 过期场景由此覆盖）。
  static const ttl = Duration(minutes: 30);

  /// 失败退避基数：第 n 次失败后 n*n*2 秒内不再尝试，最多 [maxAttempts] 次
  /// 后进入 1 小时长退避。
  static const maxAttempts = 3;

  final LinkedHashMap<String, _CacheEntry> _cache =
      LinkedHashMap<String, _CacheEntry>();
  final Map<String, Future<ArtworkResult>> _inflight = {};
  final int _maxEntries = 256;

  /// 可注入时钟（测试 TTL/退避）；生产为系统时间。
  DateTime Function() now = DateTime.now;

  /// 仅测试用：清空全部缓存与在途请求。
  @visibleForTesting
  void debugReset() {
    _cache.clear();
    _inflight.clear();
  }

  /// 缓存键：优先实体键（source|type|id），实体键缺失退化为 URL。
  @visibleForTesting
  static String cacheKeyOf(ArtworkRequest request) {
    if (request.source.isEmpty || request.entityId.isEmpty) {
      return 'url|${request.url ?? ''}';
    }
    return '${request.source}|${request.entityType}|${request.entityId}';
  }

  /// 解析封面。失败/空 URL 不抛异常：返回结果对象让组件决定占位与重试。
  ///
  /// http(s) URL 不做预探测（探测会让同一 URL 发两次请求）：直接返回
  /// resolved，由组件层 `CachedNetworkImage` 发起真正的单次下载；网络层
  /// 失败（404/403/超时/离线/非图片）由组件回调 [markFetchFailed] /
  /// [markDecodeFailed] 记入负缓存。
  Future<ArtworkResult> resolve(ArtworkRequest request) {
    final url = request.url?.trim() ?? '';
    if (url.isEmpty) return Future.value(const ArtworkResult.empty());

    final key = cacheKeyOf(request);
    final cached = _cache[key];
    final currentTime = now();
    if (cached != null) {
      final isHttp = url.startsWith('http://') || url.startsWith('https://');
      final age = currentTime.difference(cached.fetchedAt);
      if (cached.result.status == ArtworkStatus.resolved) {
        if (isHttp && age < ttl) {
          _cache
            ..remove(key)
            ..[key] = cached; // 触达提升到 LRU 尾部
          return Future.value(
            ArtworkResult.resolved(cached.result.resolvedUrl!, cached: true),
          );
        }
        if (!isHttp) {
          // 本地路径每次重新校验（文件可能被移动/删除），不占用 TTL 记账。
          return _resolveLocal(url, key);
        }
        _cache.remove(key); // TTL 过期：重新解析
      } else if (cached.nextAttemptAt != null &&
          currentTime.isBefore(cached.nextAttemptAt!)) {
        // 负缓存退避期内：直接失败，不发起网络请求（离线场景不无限重试）。
        return Future.value(
          ArtworkResult.failed(cached.result.failureReason ?? '封面不可用'),
        );
      } else {
        _cache.remove(key); // 退避期满：允许重试
      }
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      final result = ArtworkResult.resolved(url, cached: false);
      _cache[key] = _CacheEntry(result, now(), 0);
      _trim();
      return Future.value(result);
    }
    return _resolveLocal(url, key);
  }

  Future<ArtworkResult> _resolveLocal(String url, String key) {
    final pending = _inflight[key];
    if (pending != null) return pending; // single-flight
    final future = Future<void>(() async {
      ArtworkResult result;
      try {
        final path = url.startsWith('file://')
            ? Uri.parse(url).toFilePath()
            : url;
        final file = File(path);
        if (await file.exists()) {
          result = ArtworkResult.resolved(url, cached: false);
        } else {
          result = const ArtworkResult.failed('本地封面文件不存在');
        }
      } on Object catch (error) {
        debugPrint('artwork local resolve failed: $error');
        result = const ArtworkResult.failed('封面加载失败');
      }
      _cache[key] = _CacheEntry(result, now(), 0);
      _trim();
    }).then((_) => _cache[key]!.result);
    _inflight[key] = future;
    return future.whenComplete(() => _inflight.remove(key));
  }

  void _trim() {
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// 显式重试：清除负缓存与退避（组件重试按钮调用）。
  void retry(ArtworkRequest request) {
    _cache.remove(cacheKeyOf(request));
  }

  void _recordFailure(ArtworkRequest request, String reason) {
    final key = cacheKeyOf(request);
    final failCount = (_cache[key]?.failCount ?? 0) + 1;
    final backoff = failCount >= maxAttempts
        ? const Duration(hours: 1)
        : Duration(seconds: failCount * failCount * 2);
    _cache[key] = _CacheEntry(
      ArtworkResult.failed(reason),
      now(),
      failCount,
      now().add(backoff),
    );
  }

  /// 组件层网络失败（404/403/超时/离线）时调用：计入负缓存退避。
  void markFetchFailed(ArtworkRequest request, {String? reason}) {
    _recordFailure(request, reason ?? '封面加载失败');
  }

  /// 组件层解码失败（如服务器返回非图片字节）时调用：计入负缓存退避。
  void markDecodeFailed(ArtworkRequest request) {
    _recordFailure(request, '封面内容无法解码');
  }

  /// 按 [logicalSize]（逻辑像素）计算缩略图解码宽度上限：列表小图不得
  /// 解码超大原图（§8.2/§11.1）。
  static int decodeCacheWidth(double logicalSize, double devicePixelRatio) =>
      (logicalSize * devicePixelRatio).round().clamp(16, 1024);

  /// 已解析本地路径 → 限尺寸解码的 [FileImage]；http(s) 一律返回 null
  /// （组件层走 CachedNetworkImage）。调用方在文件缺失时调用 [retry]。
  ImageProvider? providerFor(
    ArtworkRequest request,
    ArtworkResult result, {
    required double logicalSize,
    required double devicePixelRatio,
  }) {
    final url = result.resolvedUrl;
    if (url == null) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return null;
    }
    final path = url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
    return ResizeImage(
      FileImage(File(path)),
      width: decodeCacheWidth(logicalSize, devicePixelRatio),
      allowUpscaling: false,
    );
  }
}

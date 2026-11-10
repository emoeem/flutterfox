/// 封面加载：voicefox 的 SongDto 只带 coverUrl，myune 的 Song 需要字节。
///
/// 带内存 LRU（32 张）+ in-flight 去重，避免每次打开播放页都重新下载；
/// 失败返回 null，播放页回退到占位图而不是崩溃。
/// 注意：**没有磁盘缓存**（旧注释宣称有，实为内存 LRU——P3-01 已更正）；
/// 新代码请改走 `services/artwork_resolver.dart` + `VxArtwork`（§8.2 唯一
/// 封面入口，含负缓存/TTL/限尺寸解码），本文件仅为 myune 播放页字节供给
/// 的兼容层。
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

const int _maxEntries = 32;
const Duration _timeout = Duration(seconds: 12);

final LinkedHashMap<String, Uint8List> _memory =
    LinkedHashMap<String, Uint8List>();
final Map<String, Future<Uint8List?>> _inflight = {};

/// 读取封面字节；`url` 支持 http(s)、file:// 与本地绝对路径。
Future<Uint8List?> loadCoverBytes(String? url) {
  if (url == null || url.isEmpty) return Future.value(null);
  final cached = _memory.remove(url);
  if (cached != null) {
    _memory[url] = cached; // 触达提升到 LRU 尾部
    return Future.value(cached);
  }
  final pending = _inflight[url];
  if (pending != null) return pending;
  final future = _fetch(url)
      .then((bytes) {
        if (bytes != null) {
          _memory[url] = bytes;
          while (_memory.length > _maxEntries) {
            _memory.remove(_memory.keys.first);
          }
        }
        return bytes;
      })
      .whenComplete(() => _inflight.remove(url));
  _inflight[url] = future;
  return future;
}

Future<Uint8List?> _fetch(String url) async {
  try {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final client = HttpClient()..connectionTimeout = _timeout;
      try {
        final request = await client.getUrl(Uri.parse(url)).timeout(_timeout);
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'Mozilla/5.0 (X11; Linux x86_64) voicefox/0.8',
        );
        final response = await request.close().timeout(_timeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return null;
        }
        final chunks = <int>[];
        await response.timeout(_timeout).forEach(chunks.addAll);
        return chunks.isEmpty ? null : Uint8List.fromList(chunks);
      } finally {
        client.close(force: true);
      }
    }
    final path = url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  } on Object {
    // 封面失败不影响播放：返回 null 让调用方走占位图。
    return null;
  }
}

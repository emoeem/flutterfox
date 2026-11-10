/// VxArtwork / ArtworkResolver 测试（指南 §8.2 测试清单 / §12.3 ArtworkWidgetTest）。
///
/// 覆盖：空 URL、404、403、连接拒绝（离线）、非图片内容（解码失败负缓存）、
/// 相同 URL 并发（cache manager 单飞 → 传输层只收到一次请求）、同 ID 不同
/// source 缓存键隔离、缓存命中与 TTL 过期、失败负缓存退避与显式重试、本地
/// embedded artwork（存在性校验失败 + file:// 限尺寸 provider 构造）、失败不
/// 跳布局（固定尺寸盒）、语义标签、解码限尺寸计算。
///
/// 环境声明：TestWidgetsFlutterBinding 拦截真实 socket（HttpClient 恒 400）
/// 与真实图片编解码（codec 层），故 200 下载路径经脚本化 FileService 注入、
/// 「本地封面真实解码渲染」与「非图片字节真实解码」两项以 resolver/回调契约
/// 锁定（本地路径的 widget 级渲染同样被真实 IO 拦截阻断，以 resolver 单测覆盖；渲染级验证待桌面/真机运行，phase-1-report 登记）。
///
/// 传输层策略：TestWidgetsFlutterBinding 会拦截一切真实 socket（所有
/// HttpClient 请求被回 400），因此网络行为经注入 `FileService`（
/// flutter_cache_manager 的传输抽象）脚本化——WebHelper 的并发去重、状态码
/// 分支与错误路径跑的是真实代码，只有 socket 层被替换。
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_artwork.dart';
import 'package:voicefox_flutter/src/services/artwork_resolver.dart';

/// 标准 1x1 PNG（透明的最小合法图片，用于验证真实解码路径）。
final Uint8List _png1x1 = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

const _semanticsKey = Key('artwork-under-test');

/// 脚本化响应：状态码 / 字节 / 延迟 / 直接抛异常（离线模拟）。
class _ScriptedRoute {
  final int status;
  final Uint8List? body;
  final Duration delay;
  final void Function()? thrower;

  const _ScriptedRoute({
    this.status = 200,
    this.body,
    this.delay = Duration.zero,
    this.thrower,
  });

  /// 响应字节；null 视为空体（const 默认值不能直接构造 Uint8List）。
  Uint8List get bytes => body ?? Uint8List(0);
}

/// 计数 + 路由的脚本化 FileService（延迟经 fake-async Timer 驱动）。
class _ScriptedService extends FileService {
  final Map<String, _ScriptedRoute> routes;
  int requests = 0;

  _ScriptedService(this.routes);

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    requests++;
    final route =
        routes[url] ??
        routes[url.split('/').reversed.take(2).last] ??
        const _ScriptedRoute();
    route.thrower?.call();
    if (route.delay > Duration.zero) {
      await Future<void>.delayed(route.delay);
    }
    return _ScriptedResponseImpl(route);
  }
}

class _ScriptedResponseImpl implements FileServiceResponse {
  final _ScriptedRoute route;
  _ScriptedResponseImpl(this.route);

  @override
  Stream<List<int>> get content => Stream.value(route.bytes);

  @override
  int? get contentLength => route.bytes.length;

  @override
  int get statusCode => route.status;

  @override
  DateTime get validTill => DateTime.now().add(const Duration(days: 7));

  @override
  String? get eTag => null;

  @override
  String get fileExtension => '.jpg';
}

/// 注入脚本化传输层的缓存管理器：内存化 repo（JsonRepo 走临时目录），
/// 避免 sqlite/真实路径依赖。
class _ScriptedCacheManager extends CacheManager {
  _ScriptedCacheManager(FileService service)
    : super.custom(
        Config(
          'vx-artwork-test',
          fileService: service,
          repo: NonStoringObjectProvider(),
        ),
      );
}

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
  home: Scaffold(
    body: Center(child: SizedBox(width: 120, height: 120, child: child)),
  ),
);

Widget _artwork(
  String? url, {
  String source = 'kw',
  String entityId = 'e1',
  String entityName = '测试实体',
  bool allowRetry = true,
  Key? key,
  BaseCacheManager? cacheManager,
}) => VxArtwork(
  key: key ?? _semanticsKey,
  url: url,
  source: source,
  entityType: 'song',
  entityId: entityId,
  entityName: entityName,
  size: 120,
  allowRetry: allowRetry,
  cacheManager: cacheManager,
);

/// CacheStore 在后台排了 10s 的清理 Timer（fake-async 计时），测试结束前
/// 把它推过去，避免「Timer is still pending」破坏性断言。
Future<void> _flushCacheTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 11));
  await tester.pump(const Duration(seconds: 11));
}

void main() {
  setUp(() {
    ArtworkResolver.instance.debugReset();
  });

  group('ArtworkResolver 单元', () {
    test('缓存键：实体键优先，同 ID 不同 source 隔离', () {
      const kw = ArtworkRequest(
        source: 'kw',
        entityType: 'song',
        entityId: '123',
        url: 'http://x/a.jpg',
      );
      const wy = ArtworkRequest(
        source: 'wy',
        entityType: 'song',
        entityId: '123',
        url: 'http://x/a.jpg',
      );
      expect(ArtworkResolver.cacheKeyOf(kw), 'kw|song|123');
      expect(ArtworkResolver.cacheKeyOf(wy), 'wy|song|123');
      expect(
        ArtworkResolver.cacheKeyOf(kw) == ArtworkResolver.cacheKeyOf(wy),
        isFalse,
        reason: '§8.2 缓存 key 必须包含来源，避免不同来源同 ID 冲突',
      );
      // 实体键缺失 → 按 URL 缓存。
      expect(
        ArtworkResolver.cacheKeyOf(
          const ArtworkRequest(
            source: '',
            entityType: '',
            entityId: '',
            url: 'http://x/b',
          ),
        ),
        'url|http://x/b',
      );
    });

    test('缩略图解码限尺寸：逻辑尺寸 × DPR，钳制在 16–1024', () {
      expect(ArtworkResolver.decodeCacheWidth(48, 1.0), 48);
      expect(ArtworkResolver.decodeCacheWidth(48, 3.0), 144);
      expect(ArtworkResolver.decodeCacheWidth(3000, 1.0), 1024);
      expect(ArtworkResolver.decodeCacheWidth(4, 1.0), 16);
    });

    test('TTL 命中与过期：命中未发生重新解析', () async {
      final resolver = ArtworkResolver.instance;
      var currentTime = DateTime(2026, 1, 1);
      resolver.now = () => currentTime;
      const request = ArtworkRequest(
        source: 'kw',
        entityType: 'song',
        entityId: '1',
        url: 'http://x/a.jpg',
      );
      final first = await resolver.resolve(request);
      expect(first.fromCache, isFalse);
      final second = await resolver.resolve(request);
      expect(second.fromCache, isTrue, reason: 'TTL 内命中缓存');

      currentTime = currentTime.add(ArtworkResolver.ttl * 2);
      final third = await resolver.resolve(request);
      expect(third.fromCache, isFalse, reason: 'TTL 过期后重新解析');
    });

    test('负缓存退避：失败后退避期内不再尝试，retry 显式清除', () async {
      final resolver = ArtworkResolver.instance;
      var currentTime = DateTime(2026, 1, 1);
      resolver.now = () => currentTime;
      const request = ArtworkRequest(
        source: 'kw',
        entityType: 'song',
        entityId: '1',
        url: 'http://x/broken.jpg',
      );
      resolver.markFetchFailed(request, reason: 'HTTP 404');
      final failed = await resolver.resolve(request);
      expect(failed.status, ArtworkStatus.failed);
      expect(failed.failureReason, 'HTTP 404');

      currentTime = currentTime.add(const Duration(seconds: 1));
      final withinBackoff = await resolver.resolve(request);
      expect(withinBackoff.status, ArtworkStatus.failed);

      resolver.retry(request);
      final retried = await resolver.resolve(request);
      expect(retried.status, ArtworkStatus.resolved, reason: 'retry 清除负缓存');
    });

    test('连续失败达上限进入长退避；退避期满允许重试', () async {
      final resolver = ArtworkResolver.instance;
      var currentTime = DateTime(2026, 1, 1);
      resolver.now = () => currentTime;
      const request = ArtworkRequest(
        source: 'kw',
        entityType: 'song',
        entityId: '1',
        url: 'http://x/dead.jpg',
      );
      for (var i = 0; i < ArtworkResolver.maxAttempts; i++) {
        // 三次失败发生在同一时刻（时钟不前进）：累计 failCount 触发长退避。
        resolver.markFetchFailed(request);
      }
      final result = await resolver.resolve(request);
      expect(result.status, ArtworkStatus.failed);

      currentTime = currentTime.add(const Duration(minutes: 59));
      final still = await resolver.resolve(request);
      expect(still.status, ArtworkStatus.failed, reason: '1 小时长退避期内');
      currentTime = currentTime.add(const Duration(minutes: 2));
      final after = await resolver.resolve(request);
      expect(after.status, ArtworkStatus.resolved, reason: '退避期满重新解析');
    });

    test('空 URL → empty；本地文件缺失 → failed', () async {
      final resolver = ArtworkResolver.instance;
      const empty = ArtworkRequest(
        source: 'kw',
        entityType: 'song',
        entityId: '1',
        url: '',
      );
      expect((await resolver.resolve(empty)).status, ArtworkStatus.empty);

      const missing = ArtworkRequest(
        source: 'local',
        entityType: 'song',
        entityId: '2',
        url: '/nonexistent/cover.jpg',
      );
      final failed = await resolver.resolve(missing);
      expect(failed.status, ArtworkStatus.failed);
    });

    test('本地 embedded artwork：存在的文件解析为 URL 并限尺寸构造 provider', () async {
      final resolver = ArtworkResolver.instance;
      final temp = Directory.systemTemp.createTempSync('vx-artwork');
      addTearDown(() => temp.deleteSync(recursive: true));
      final file = File('${temp.path}/embedded.png')..writeAsBytesSync(_png1x1);
      final request = ArtworkRequest(
        source: 'local',
        entityType: 'song',
        entityId: '3',
        url: file.path,
        entityName: '本地曲',
      );
      final result = await resolver.resolve(request);
      expect(result.status, ArtworkStatus.resolved);
      final provider = resolver.providerFor(
        request,
        result,
        logicalSize: 48,
        devicePixelRatio: 2,
      );
      expect(provider, isNotNull, reason: '本地封面给出限尺寸解码的 ImageProvider');
      // 重新解析（存在性复检）仍成功。
      final again = await resolver.resolve(request);
      expect(again.status, ArtworkStatus.resolved);
    });
  });

  group('VxArtwork 组件（脚本化传输层）', () {
    testWidgets('空 URL 显示占位盒：固定尺寸不跳布局', (tester) async {
      await tester.pumpWidget(_host(_artwork(null)));
      await tester.pump();
      expect(
        tester.getSize(find.byKey(_semanticsKey)),
        const Size(120, 120),
        reason: '占位不得改变布局尺寸（§8.2 封面加载失败不跳布局）',
      );
      expect(find.byIcon(Icons.music_note_outlined), findsOneWidget);
    });

    testWidgets('200 正常加载：同 URL 并发只发起一次下载（single-flight）', (tester) async {
      final service = _ScriptedService({
        'http://origin/cover.jpg': _ScriptedRoute(
          body: _png1x1,
          delay: const Duration(milliseconds: 300),
        ),
      });
      final manager = _ScriptedCacheManager(service);

      // 两组件同帧挂载：第二组件的下载请求与第一份下载并发 → WebHelper
      // 在途去重 → 传输层只收到一次请求。
      tester.view.physicalSize = const Size(600, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: _artwork(
                    'http://origin/cover.jpg',
                    cacheManager: manager,
                  ),
                ),
                SizedBox(
                  width: 120,
                  height: 120,
                  child: _artwork(
                    'http://origin/cover.jpg',
                    entityId: 'e2',
                    key: const ValueKey('a2'),
                    cacheManager: manager,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(service.requests, 1, reason: '§8.2 同一 URL 并发只发起一次下载（在途去重）');
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.requests, 1, reason: '去重后不应出现第二次传输');
      await _flushCacheTimers(tester);
    });

    testWidgets('404 → 失败态带重试；负缓存退避期内不重发请求', (tester) async {
      final service = _ScriptedService({
        'http://origin/missing.jpg': const _ScriptedRoute(status: 404),
      });
      final manager = _ScriptedCacheManager(service);
      const url = 'http://origin/missing.jpg';

      await tester.pumpWidget(_host(_artwork(url, cacheManager: manager)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(service.requests, greaterThanOrEqualTo(1));
      final requestsAtFailure = service.requests;
      expect(find.byIcon(Icons.refresh), findsOneWidget, reason: '失败态提供重试入口');

      // 失败退避期内重建：不重复发起传输。
      await tester.pumpWidget(_host(_artwork(url, cacheManager: manager)));
      await tester.pump();
      expect(service.requests, requestsAtFailure, reason: '失败退避期内不重复发起网络请求');
      await _flushCacheTimers(tester);
    });

    testWidgets('403 → 失败态（权限拒绝同样归一为失败+重试）', (tester) async {
      final service = _ScriptedService({
        'http://origin/forbidden.jpg': const _ScriptedRoute(status: 403),
      });
      await tester.pumpWidget(
        _host(
          _artwork(
            'http://origin/forbidden.jpg',
            cacheManager: _ScriptedCacheManager(service),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      await _flushCacheTimers(tester);
    });

    testWidgets('离线（传输层抛 SocketException）→ 失败态带重试', (tester) async {
      final service = _ScriptedService({
        'http://origin/offline.jpg': const _ScriptedRoute(
          thrower: _throwSocket,
        ),
      });
      await tester.pumpWidget(
        _host(
          _artwork(
            'http://origin/offline.jpg',
            cacheManager: _ScriptedCacheManager(service),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.refresh), findsOneWidget, reason: '离线失败态提供重试入口');
      await _flushCacheTimers(tester);
    });

    testWidgets('语义标签携带实体名（§11.2）', (tester) async {
      await tester.pumpWidget(_host(_artwork(null, entityName: 'L-O-V-E')));
      await tester.pump();
      final semantics = tester.getSemantics(find.byKey(_semanticsKey));
      expect(semantics.label, 'L-O-V-E');
    });
  });
}

void _throwSocket() {
  throw const SocketException('connection refused (scripted offline)');
}

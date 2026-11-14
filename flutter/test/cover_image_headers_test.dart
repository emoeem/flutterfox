/// CoverImage 网络请求头测试（Phase4-QA1 P1 封面缺陷回归锁定）。
///
/// 缺陷：网易系封面 CDN（p2.music.126.net 等）封杀 dart:io 默认 UA
/// （`Dart/<ver> (dart:io)` → 403），全屏播放页大封面（resolved_song
/// 跨源候选 URL）持续显示失败灰占位，而队列行（酷我等音源 URL）正常。
/// 修复：CoverImage 经 CachedNetworkImage.httpHeaders 下发 voicefox UA +
/// 镜像 Rust cover_referer 的按音源 Referer。
///
/// 真实网络行为验证见运行时证据（真实后端 flutter run：修复前灰占位、
/// 修复后封面渲染）；此处锁定请求头构造与下发链路。
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/widgets/cover_image.dart';

void main() {
  group('coverReferer 按音源映射（镜像 Rust cover_referer）', () {
    test('酷我', () {
      expect(
        coverReferer('https://img3.kuwo.cn/star/albumcover/500/6/48/x.jpg'),
        'https://www.kuwo.cn/',
      );
    });
    test('酷狗', () {
      expect(coverReferer('http://c1.kgimg.com/custom/240/x.jpg'), isNull);
      expect(
        coverReferer('https://imge.kugou.com/stdmusic/x.png'),
        'https://www.kugou.com/',
      );
    });
    test('QQ', () {
      expect(coverReferer('https://qq.com/x.jpg'), 'https://y.qq.com/');
      // Rust cover_referer 只匹配 qq.com 子串；QQ 封面实际图床
      // y.gtimg.cn 不含该子串 → 两端同样不附加（镜像如实）。
      expect(
        coverReferer('https://y.gtimg.cn/music/photo_new/T002R500x500M000.jpg'),
        isNull,
      );
    });
    test('网易（music.163.com 与 126.net 两个域）', () {
      expect(
        coverReferer('https://p1.music.126.net/a/b.jpg'),
        'https://music.163.com/',
        reason: '163 封面走 126.net 图床域，Rust 映射同样命中',
      );
      expect(
        coverReferer('http://p2.music.126.net/DrNrcSu1YLan6Oya57x60A==/x.jpg'),
        'https://music.163.com/',
      );
      expect(
        coverReferer('https://music.163.com/api/x'),
        'https://music.163.com/',
      );
    });
    test('其他音源不附加 Referer', () {
      expect(coverReferer('https://img01.dmhmusic.com/0513/M00/x.jpg'), isNull);
      expect(coverReferer('https://image.joox.com/JOOXcover/0/x/300'), isNull);
    });
  });

  group('coverImageHttpHeaders 构造', () {
    test('User-Agent 为 voicefox 家族（不含 Dart）', () {
      final headers = coverImageHttpHeaders('http://p2.music.126.net/a/b.jpg');
      expect(headers['User-Agent'], startsWith('voicefox'));
      expect(headers['User-Agent'], isNot(contains('Dart')));
    });
    test('网易 126.net 域附带 music.163.com Referer', () {
      final headers = coverImageHttpHeaders(
        'http://p2.music.126.net/DrNrcSu1YLan6Oya57x60A==/109951173908998514.jpg',
      );
      expect(headers['Referer'], 'https://music.163.com/');
    });
    test('酷我域附带酷我 Referer', () {
      final headers = coverImageHttpHeaders(
        'https://img3.kuwo.cn/star/albumcover/500/6/48/1406239650.jpg',
      );
      expect(headers['Referer'], 'https://www.kuwo.cn/');
    });
    test('无防盗链要求的音源只有 UA 一项', () {
      final headers = coverImageHttpHeaders(
        'https://image.joox.com/JOOXcover/0/x/300',
      );
      expect(headers.length, 1);
      expect(headers.containsKey('Referer'), isFalse);
    });
  });

  group('CoverImage 经 CachedNetworkImage.httpHeaders 下发', () {
    Future<void> pumpCover(WidgetTester tester, String url) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: CoverImage(url: url, size: 34)),
          ),
        ),
      );
    }

    testWidgets('网易云封面 URL：httpHeaders 含 voicefox UA + 网易 Referer', (
      tester,
    ) async {
      await pumpCover(
        tester,
        'http://p2.music.126.net/DrNrcSu1YLan6Oya57x60A==/x.jpg',
      );
      final cached = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(cached.httpHeaders, isNotNull);
      expect(cached.httpHeaders!['User-Agent'], startsWith('voicefox'));
      expect(cached.httpHeaders!['Referer'], 'https://music.163.com/');
    });

    testWidgets('非网易 URL：httpHeaders 仅 UA 一项', (tester) async {
      await pumpCover(tester, 'https://image.joox.com/JOOXcover/0/x/300');
      final cached = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(cached.httpHeaders!.length, 1);
      expect(cached.httpHeaders!.containsKey('Referer'), isFalse);
    });

    testWidgets('空 URL 仍走占位盒，不构造网络请求', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: CoverImage(url: '', size: 34)),
          ),
        ),
      );
      expect(find.byType(CachedNetworkImage), findsNothing);
    });
  });
}

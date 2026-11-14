import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/pages/player_page.dart';
import 'package:voicefox_flutter/src/widgets/lyrics_view.dart';

bridge.LyricLineDto _line(int ms, String text) => bridge.LyricLineDto(
  timestampMs: BigInt.from(ms),
  durationMs: BigInt.from(5000),
  text: text,
);

void main() {
  group('lyricIndexAt', () {
    final lines = [_line(0, '一'), _line(5000, '二'), _line(10000, '三')];

    test('空歌词返回 -1', () {
      expect(lyricIndexAt(const [], 1000), -1);
    });

    test('首行之前按 Rust 规则归到第 0 行', () {
      final late = [_line(5000, '二'), _line(10000, '三')];
      expect(lyricIndexAt(late, 1000), 0);
    });

    test('按时间戳精确命中最末一个不大于位置的行', () {
      expect(lyricIndexAt(lines, 0), 0);
      expect(lyricIndexAt(lines, 4999), 0);
      expect(lyricIndexAt(lines, 5000), 1);
      expect(lyricIndexAt(lines, 12000), 2);
    });

    test('歌词偏移参与推导（正负都生效）', () {
      expect(lyricIndexAt(lines, 4000, offsetMs: 1500), 1);
      expect(lyricIndexAt(lines, 5000, offsetMs: -1000), 0);
    });
  });

  testWidgets('歌词视图渲染全部行，点击行回传该行起始毫秒', (tester) async {
    final lines = [_line(0, '第一行'), _line(5000, '第二行'), _line(10000, '第三行')];
    final seeks = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: LyricsView(
              lines: lines,
              currentIndex: 1,
              onSeekMs: seeks.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第一行'), findsOneWidget);
    expect(find.text('第二行'), findsOneWidget);
    expect(find.text('第三行'), findsOneWidget);

    await tester.tap(find.text('第二行'));
    expect(seeks, [5000]);
  });

  testWidgets('空歌词显示「暂无歌词」空态', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: LyricsView(lines: [], currentIndex: -1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无歌词'), findsOneWidget);
  });

  testWidgets('播放页无歌曲时显示空态', (tester) async {
    final model = AppModel();
    await tester.pumpWidget(MaterialApp(home: PlayerPage(model)));
    await tester.pumpAndSettle();

    expect(find.text('正在播放'), findsOneWidget);
    expect(find.text('未在播放'), findsOneWidget);
    expect(find.text('从搜索或收藏开始播放'), findsOneWidget);
  });
}

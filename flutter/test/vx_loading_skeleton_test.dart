/// VxLoadingSkeleton 视口自适应骨架测试(P2-19 回归锁定,§7.4 骨架受视口约束)。
///
/// P2-19:search_page 加载态原用固定 `VxLoadingSkeleton.tracks(rows: 8)`
/// (8×58 + 7×8 = 520px,mainAxisSize.min 的 Column 不裁切不收缩),
/// 1136×713 真机窗口下 Expanded 视口不足 → RenderFlex
/// 「BOTTOM OVERFLOWED BY 143 PIXELS」(Batch G 登记,100% 复现,
/// 证据 docs/redesign/screenshots/batch-g-winrt/winrt-NEW-search-skeleton-overflow143.png)。
///
/// 修复 = 组件新增 `VxLoadingSkeleton.tracksFitted`:行数按约束高度拟合
/// (行高/间距常量单源于组件,上限 maxRows、下限 1),search_page 加载分支
/// 改用之。本文件锁定:
/// - A/B 回归:同一紧视口下,固定 rows:8 溢出(异常在案)而 tracksFitted 干净;
/// - 拟合行数契约:H=443 → 6 行(floor((443+8)/66));H=713 → maxRows 封顶 8;
///   H=30 → 下限 1 行,均无溢出异常;
/// - 无界高度(滚动列表内误用)退化为固定 rows 行,行为与 tracks 一致。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_loading_skeleton.dart';

Widget _harness(double height, Widget child) {
  return MaterialApp(
    theme: ThemeData.light(useMaterial3: true),
    home: Scaffold(
      body: SizedBox(width: 1136, height: height, child: child),
    ),
  );
}

/// 与 search_page 加载分支同构:Expanded + 水平 padding 内挂骨架。
Widget _padded(Widget skeleton) {
  return Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: skeleton,
    ),
  );
}

int _renderedTrackRows(WidgetTester tester) {
  return tester
      .widgetList<SizedBox>(
        find.byWidgetPredicate((w) => w is SizedBox && w.height == 58),
      )
      .length;
}

void main() {
  testWidgets('P2-19 A/B:紧视口下固定 8 行骨架溢出(旧缺陷形态在案)', (tester) async {
    tester.view.physicalSize = const Size(1136, 713);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(
        443,
        Column(children: [_padded(const VxLoadingSkeleton.tracks(rows: 8))]),
      ),
    );
    final exception = tester.takeException();
    expect(
      exception,
      isNotNull,
      reason: 'rows: 8(520px)在 443px 视口内必须仍复现溢出,否则本回归失去对照意义',
    );
    // widget 测试中的溢出错误文本是小写形态(调试横幅的大写 BOTTOM OVERFLOWED
    // 是真机 DEBUG 渲染层的视觉条,不出现在测试异常里)。
    expect(exception.toString(), contains('overflowed'));
  });

  testWidgets('P2-19 修复:tracksFitted 同视口无溢出且按约束高度拟合行数', (tester) async {
    tester.view.physicalSize = const Size(1136, 713);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 443px 视口:floor((443+8)/66)=6 行,无异常。
    await tester.pumpWidget(
      _harness(
        443,
        Column(
          children: [_padded(const VxLoadingSkeleton.tracksFitted(maxRows: 8))],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(_renderedTrackRows(tester), 6);
  });

  testWidgets('P2-19 修复:713 视口拟合数被 maxRows 封顶为 8 行', (tester) async {
    tester.view.physicalSize = const Size(1136, 713);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(
        713,
        Column(
          children: [_padded(const VxLoadingSkeleton.tracksFitted(maxRows: 8))],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(_renderedTrackRows(tester), 8);
  });

  testWidgets('P2-19 修复:极矮视口拟合数收拢为 1 行且不溢出', (tester) async {
    tester.view.physicalSize = const Size(1136, 713);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 120px 视口:floor(128/66)=1 行(组件契约 = 至少渲染 1 行;
    // 现实页面骨架区高度不会低于单行行高,低于 58px 的退化形态不在此契约内)。
    await tester.pumpWidget(
      _harness(
        120,
        Column(
          children: [_padded(const VxLoadingSkeleton.tracksFitted(maxRows: 8))],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(_renderedTrackRows(tester), 1);
  });

  testWidgets('tracksFitted 在无界高度(滚动列表)退化为固定行数,与 tracks 行为一致', (tester) async {
    tester.view.physicalSize = const Size(1136, 713);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(
        713,
        SingleChildScrollView(
          child: const VxLoadingSkeleton.tracksFitted(maxRows: 8),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // 无界约束 → 退化为构造缺省 rows=5,不猜高度。
    expect(_renderedTrackRows(tester), 5);
  });
}

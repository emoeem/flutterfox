/// 曲库页（MobileLibraryPageTest，Phase 3）：
/// - 360/390/430 手机视口直接 pump LibraryPage（桌面窗口隔离使 MobileShell
///   不进桌面树，沿 phase-2 报告决策 5 的页面级口径；壳内导航可达性由
///   mobile_shell_test 覆盖，两口径覆盖面不同）；
/// - 入口卡 + 来源 chips 渲染、chips 计数随数据派生、无横向溢出；
/// - 来源筛选在歌曲/专辑/歌手/歌单四档生效且计数同步（§5.5）；
/// - P2-10 回归：430 视口快捷入口卡标签完整渲染，不触发省略号截断；
/// - 本地收藏 Empty 态：无收藏展示「还没有收藏」引导（四态契约之空态）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/design_system/design_tokens.dart';
import 'package:voicefox_flutter/src/pages/library_page.dart';

bridge.SongDto _song(
  String id,
  String name, {
  required String source,
  required String singer,
  required String album,
}) => bridge.SongDto(
  id: id,
  source: source,
  name: name,
  singer: singer,
  albumName: album,
  durationMs: BigInt.from(180000),
  coverUrl: null,
);

/// 种子数据：favorites（kw+wy）、history（kw）、localSongs（local）→
/// chips 派生域 = [kw, wy, local]（≥2 才显示）；收藏歌单 kw+wy；
/// 自建歌单一条（本地数据，验证来源组合规则）。
AppModel _seededModel() {
  final model = AppModel();
  model.debugSetSources([
    bridge.SourceCapabilitiesDto(
      id: 'kw',
      name: '酷狗',
      playlists: false,
      playlistCategories: false,
      playlistSearch: false,
      album: false,
      artist: false,
      leaderboard: false,
      login: false,
      qrLogin: false,
    ),
    bridge.SourceCapabilitiesDto(
      id: 'wy',
      name: '网易云',
      playlists: false,
      playlistCategories: false,
      playlistSearch: false,
      album: false,
      artist: false,
      leaderboard: false,
      login: false,
      qrLogin: false,
    ),
  ]);
  model.debugSetFavorites([
    _song('s1', '酷狗歌A', source: 'kw', singer: '酷狗歌手', album: '酷狗专辑'),
    _song('s2', '网易云歌B', source: 'wy', singer: '网易云歌手', album: '网易云专辑'),
  ]);
  model.debugSetHistory([
    _song('s3', '酷狗歌C', source: 'kw', singer: '酷狗歌手', album: '酷狗专辑'),
  ]);
  model.debugSetLocalSongs([
    _song('s4', '本地歌D', source: 'local', singer: '本地歌手', album: '本地专辑'),
  ]);
  model.debugSetFavoritePlaylists([
    bridge.PlaylistDto(
      id: 'p1',
      name: '酷狗收藏单',
      source: 'kw',
      coverUrl: null,
      songCount: 5,
    ),
    bridge.PlaylistDto(
      id: 'p2',
      name: '网易云收藏单',
      source: 'wy',
      coverUrl: null,
      songCount: 7,
    ),
  ]);
  model.debugSetCustomPlaylists([
    bridge.CustomPlaylistSummaryDto(id: 'c1', name: '自建一', songCount: 3),
  ]);
  return model;
}

Future<void> _pumpLibrary(
  WidgetTester tester,
  AppModel model,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    KeyedSubtree(
      key: ValueKey(size.toString()),
      child: MaterialApp(home: Scaffold(body: LibraryPage(model))),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('360/390/430 视口：入口卡与来源 chips 渲染、无横向溢出、P2-10 标签不截断', (
    tester,
  ) async {
    for (final size in const [
      Size(430, 932), // 缺陷证据视口（P2-10）。
      Size(390, 844),
      Size(360, 800), // 最窄手机档。
    ]) {
      final model = _seededModel();
      await _pumpLibrary(tester, model, size);

      expect(
        tester.takeException(),
        isNull,
        reason: '${size.width} 视口曲库页无横向溢出（入口卡/chips 行）',
      );
      // 入口卡三张齐备。
      expect(find.text('最近播放'), findsOneWidget);
      expect(
        find.text('本地音乐'),
        findsNWidgets(2),
        reason: '入口卡标签 + 来源 chips 的「本地音乐」（songSourceLabel）',
      );
      expect(find.text('喜欢的歌曲'), findsOneWidget);

      // 来源 chips 从真实数据派生（kw/wy/local），提供「全部来源」；
      // 「酷狗/网易云」文案与歌曲行来源标注重复，只断言存在（≥1）。
      expect(find.text('全部来源'), findsOneWidget);
      expect(find.text('酷狗'), findsWidgets);
      expect(find.text('网易云'), findsWidgets);

      // P2-10 回归：430 等窄视口标签完整渲染——布局宽度 ≥ 文本理想宽度
      //（旧布局标签与计数同排被挤到省略号截断）。
      final labelRect = tester.getSize(find.text('最近播放'));
      final ideal = TextPainter(
        text: TextSpan(text: '最近播放', style: VxTypography.titleSm),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(
        labelRect.width >= ideal.width,
        isTrue,
        reason: '${size.width} 视口「最近播放」标签不被省略号截断（P2-10）',
      );
    }
  });

  testWidgets('P2-15 回归：360 最窄档 5 字标签「喜欢的歌曲」scaleDown 渲染不截断', (tester) async {
    final model = _seededModel();
    await _pumpLibrary(tester, model, const Size(360, 800));

    expect(find.text('喜欢的歌曲'), findsOneWidget);
    // 截断防线：标签经 FittedBox(BoxFit.scaleDown) 渲染——省略号路径在
    // 结构上不可能触发（scaleDown 只缩放不裁切，find.text 对 ellipsized
    // Text 仍命中的旧盲区由此关闭）。
    final fitted = find.ancestor(
      of: find.text('喜欢的歌曲'),
      matching: find.byType(FittedBox),
    );
    expect(fitted, findsOneWidget, reason: '5 字标签走 scaleDown 缩放渲染');

    // 防截断的结构性断言：标签 RenderParagraph 必须按「无约束理想宽度」
    // 布局（FittedBox 子树不受约束、超宽时整体缩放呈现）。旧形态
    // （plain Text + maxLines:1 + ellipsis）在 360 档布局宽度被卡宽压到
    // 理想宽度以下，本断言即失败（find.text 对 ellipsized Text 仍命中的
    // 旧盲区由此关闭）。
    final paragraph = tester.renderObject<RenderParagraph>(find.text('喜欢的歌曲'));
    final intrinsic = paragraph.getMinIntrinsicWidth(double.infinity);
    expect(
      paragraph.size.width,
      closeTo(intrinsic, 0.5),
      reason: '5 字标签按理想宽度布局（无 ellipsis 约束裁切）',
    );
  });

  testWidgets('来源筛选生效：歌曲/专辑/歌手/歌单四档过滤、歌单计数同步', (tester) async {
    final model = _seededModel();
    await _pumpLibrary(tester, model, const Size(430, 932));

    // 全部来源：两首歌都在（songs 档只显示本地收藏）。
    expect(find.text('酷狗歌A'), findsOneWidget);
    expect(find.text('网易云歌B'), findsOneWidget);

    // 选「酷狗」chip（树序在前；同文案还有歌曲行来源标注，用 .first）：
    // 歌曲档过滤生效。
    await tester.tap(find.text('酷狗').first);
    await tester.pump();
    expect(find.text('酷狗歌A'), findsOneWidget);
    expect(find.text('网易云歌B'), findsNothing, reason: '来源过滤 songs 档');

    // 专辑档：聚合组按来源过滤。
    await tester.tap(find.text('专辑'));
    await tester.pump();
    expect(find.text('酷狗专辑'), findsOneWidget);
    expect(find.text('网易云专辑'), findsNothing);

    // 歌手档：同口径。
    await tester.tap(find.text('歌手'));
    await tester.pump();
    expect(find.text('酷狗歌手'), findsOneWidget);
    expect(find.text('网易云歌手'), findsNothing);

    // 歌单档：收藏歌单按 source 过滤（计数同步）；自建歌单（本地数据）
    // 在非本地来源下如实隐藏。
    await tester.tap(find.text('歌单'));
    await tester.pump();
    expect(find.text('收藏歌单（1）'), findsOneWidget);
    expect(find.text('酷狗收藏单'), findsOneWidget);
    expect(find.text('网易云收藏单'), findsNothing);
    expect(find.text('自建一'), findsNothing, reason: '自建歌单是本地数据：所选来源非本地时隐藏');

    // 恢复「全部来源」：收藏歌单两条、自建歌单回来。
    await tester.tap(find.text('全部来源'));
    await tester.pump();
    expect(find.text('收藏歌单（2）'), findsOneWidget);
    expect(find.text('自建一'), findsOneWidget);
  });

  testWidgets('本地收藏 Empty 态：无收藏展示「还没有收藏」引导文案', (tester) async {
    final model = _seededModel();
    model.debugSetFavorites([]);
    await _pumpLibrary(tester, model, const Size(390, 844));

    // 空态标题/副标题与 library_page.dart:568-569 逐字一致
    //（经 song_table_view.dart:180-184 EmptyState 渲染）。
    expect(find.text('还没有收藏'), findsOneWidget);
    expect(find.text('在搜索页点击心形把歌曲收进来'), findsOneWidget);
    // 空态不渲染任何歌曲行。
    expect(find.text('酷狗歌A'), findsNothing);
  });
}

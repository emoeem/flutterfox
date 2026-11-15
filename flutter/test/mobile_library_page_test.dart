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
import 'package:voicefox_flutter/src/pages/mobile_local_music_page.dart';
import 'package:voicefox_flutter/src/pages/mobile_playlist_detail_page.dart';
import 'package:voicefox_flutter/src/pages/playlist_detail_page.dart';

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

  // ── Batch C-08 曲库核验收口：<512 补丁 360/390/430 完整性 ──

  testWidgets('C-08：360/390/430 四 tab 主体渲染无横向溢出（含网格/列表双形态）', (tester) async {
    for (final size in const [
      Size(430, 932),
      Size(390, 844),
      Size(360, 800), // 最窄手机档。
    ]) {
      final model = _seededModel();
      await _pumpLibrary(tester, model, size);

      // 歌曲档（songs 表 + 收藏视图切换）。
      expect(tester.takeException(), isNull, reason: '${size.width} 歌曲档');
      expect(find.text('酷狗歌A'), findsOneWidget);

      // 专辑档：网格（默认）与列表两形态（工具行最宽档：搜索+排序+视图+刷新）。
      await tester.tap(find.text('专辑'));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${size.width} 专辑网格档');
      expect(find.text('酷狗专辑'), findsOneWidget);
      await tester.tap(find.byTooltip('切换为列表'));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${size.width} 专辑列表档');
      expect(find.text('酷狗专辑'), findsOneWidget);

      // 歌手档：网格状态自专辑档持久化（上一步已切列表），初始为列表形态
      //（tooltip 随 _grid 状态取反），再切回网格覆盖另一形态。
      await tester.tap(find.text('歌手'));
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: '${size.width} 歌手列表档（状态持久）',
      );
      expect(find.text('酷狗歌手'), findsOneWidget);
      await tester.tap(find.byTooltip('切换为网格'));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${size.width} 歌手网格档');
      expect(find.text('酷狗歌手'), findsOneWidget);

      // 歌单档：自建歌单区 + 收藏歌单列表。
      await tester.tap(find.text('歌单'));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${size.width} 歌单档');
      expect(find.text('自建一'), findsOneWidget);
      expect(find.text('酷狗收藏单'), findsOneWidget);
    }
  });

  testWidgets('C-08：360 最窄档收藏视图切换（本地/网易云/QQ）渲染无溢出且可回落', (tester) async {
    final model = _seededModel();
    await _pumpLibrary(tester, model, const Size(360, 800));

    // 本地视图：收藏歌曲在列。
    expect(find.text('本地'), findsOneWidget);
    expect(find.text('网易云'), findsWidgets, reason: '镜像分段 + 来源 chips 同名');
    expect(find.text('QQ'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '360 视口三段 SegmentedButton');

    // 切到镜像视图（无账号数据 → 加载态渲染，不崩不溢出）。
    await tester.tap(find.text('QQ'));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'QQ 镜像档加载态');

    // 回落本地：歌曲恢复。
    await tester.tap(find.text('本地'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('酷狗歌A'), findsOneWidget);
  });

  testWidgets('C-04 接线：手机形态歌单行推手机版歌单详情', (tester) async {
    final model = _seededModel();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey('mobile-form-390'),
        child: MaterialApp(
          home: Scaffold(body: LibraryPage(model, mobileForm: true)),
        ),
      ),
    );
    await tester.pump();

    // 歌单档 → 收藏歌单行 → 手机版歌单详情页（C-04）。
    // tap 的手势在下一次 pump 才 flush（onTap→push），路由首帧 build 再需
    // 一次 pump：双 pump 序列后转场 300ms 完成。
    await tester.tap(find.text('歌单'));
    await tester.pump();
    await tester.tap(find.text('酷狗收藏单'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.byType(MobilePlaylistDetailPage),
      findsOneWidget,
      reason: '手机形态推 MobilePlaylistDetailPage（C-04）',
    );
  });

  testWidgets('C-08 接线：手机形态本地音乐入口卡推手机版本地音乐页（C-B 同域收口）', (tester) async {
    final model = _seededModel();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey('mobile-form-390-b'),
        child: MaterialApp(
          home: Scaffold(body: LibraryPage(model, mobileForm: true)),
        ),
      ),
    );
    await tester.pump();

    // 入口卡「本地音乐」→ 手机版本地音乐页（songs 档默认，入口卡直接可达）。
    await tester.tap(find.text('本地音乐').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.byType(MobileLocalMusicPage),
      findsOneWidget,
      reason: '手机形态推 MobileLocalMusicPage（C-08 审计补 C-B 同域）',
    );
  });

  testWidgets('C-04 接线：桌面缺省歌单行仍推桌面歌单详情（零变化铁律）', (tester) async {
    final model = _seededModel();
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      KeyedSubtree(
        key: const ValueKey('desktop-form-1280'),
        child: MaterialApp(home: Scaffold(body: LibraryPage(model))),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('歌单'));
    await tester.pump();
    await tester.tap(find.text('酷狗收藏单'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(PlaylistDetailPage), findsOneWidget);
    expect(find.byType(MobilePlaylistDetailPage), findsNothing);
  });
}

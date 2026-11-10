/// 手机首页测试（指南 §5.2 区块顺序 + §9 四态 + §5.10 导入 CTA 契约）。
///
/// 覆盖：
/// - 区块顺序：问候 → 空库 Hero →（有历史时）最近播放横滑 → 快捷入口 →
///   为你推荐 → 排行榜（§5.2 第 1-7 项；第 8 项偏差登记 04-defect-matrix）；
/// - 空库 Hero 两 CTA：搜索走 navRequest 总线切搜索页；「导入本地音乐」
///   直接触发真实文件/目录选择流程（注入 picker 锁回调触发层——宿主测试
///   环境无系统选择器与媒体文件，导入→播放链路按矩阵归 Phase 5，不伪验）；
/// - 有曲后空库 Hero 消失、最近播放横滑卡封面 72dp ∈ 64-76；
/// - 为你推荐走真实 `loadPlaylists` browse 槽（非 customPlaylists）：
///   无能力音源空态 / 成功态真实数据 / 失败态可读错误（P1-07 净化口径）；
/// - 快捷入口真实落点：本地音乐 → 推入 LocalMusicPage；喜欢的歌曲 →
///   推入 LibraryPage 歌曲档。
///
/// 平台口径：直接 pump MobileShell（对齐 shell_test.dart 既有模式）。
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart' as bridge;
import 'package:voicefox_flutter/src/design_system/components/vx_album_card.dart';
import 'package:voicefox_flutter/src/design_system/components/vx_playlist_card.dart';
import 'package:voicefox_flutter/src/myune/page/setting/settings_provider.dart';
import 'package:voicefox_flutter/src/myune/services/notification_service.dart';
import 'package:voicefox_flutter/src/nav_bus.dart';
import 'package:voicefox_flutter/src/pages/library_page.dart';
import 'package:voicefox_flutter/src/pages/local_music_page.dart';
import 'package:voicefox_flutter/src/pages/mobile_home_page.dart';
import 'package:voicefox_flutter/src/shell/mobile_shell.dart';

bridge.SongDto _song(String id, String name, {String source = 'wy'}) =>
    bridge.SongDto(
      id: id,
      source: source,
      name: name,
      singer: '测试歌手',
      albumName: '',
      durationMs: BigInt.from(180000),
      coverUrl: null,
    );

void _setSize(WidgetTester tester, Size logical) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 手机首页内的查找（限定范围）：壳内 IndexedStack 常驻 LibraryPage 等
/// 页面，同名文本（如「本地音乐」「最近播放」）不能全树查找。
Finder _home(Finder finder) =>
    find.descendant(of: find.byType(MobileHomePage), matching: finder);

Future<void> _pumpShell(WidgetTester tester, AppModel model) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppModel>.value(value: model),
        ChangeNotifierProvider<SettingsProvider>.value(
          value: SettingsProvider(),
        ),
        ChangeNotifierProvider<NotificationService>.value(
          value: NotificationService(),
        ),
      ],
      child: MaterialApp(home: MobileShell(model: model)),
    ),
  );
  // 首页推荐/排行榜区块在帧后触发请求；给两帧让状态落地。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // 每用例恢复生产选择器（个别用例注入替身记录调用）。
    localDirectoryPicker = FilePicker.getDirectoryPath;
  });

  group('§5.2 区块顺序与空态', () {
    testWidgets('空库：问候 → 空库 Hero → 快捷入口 → 为你推荐 → 排行榜（自上而下）', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      await _pumpShell(tester, model);

      // 空库 Hero（song==null && history.isEmpty）。
      expect(find.text('音乐库还是空的'), findsOneWidget);
      expect(find.text('导入本地音乐，或搜索在线音乐开始收听。'), findsOneWidget);
      // 最近播放区块在有历史时才出现（同桌面语义）。
      expect(find.text('最近播放'), findsNothing);

      // 区块自上而下：Hero → 快捷入口 → 为你推荐（同屏可测像素序）；
      // 排行榜在 844 视口折叠线以下，滚动后出现（ListView 子项顺序即
      // 视觉顺序，存在性 + 初始折叠即证其为末位区块）。
      final heroY = tester.getTopLeft(find.text('音乐库还是空的')).dy;
      final quickY = tester.getTopLeft(_home(find.text('本地音乐'))).dy;
      final recommendY = tester.getTopLeft(_home(find.text('为你推荐'))).dy;
      expect(heroY, lessThan(quickY));
      expect(quickY, lessThan(recommendY));
      var scrolls = 0;
      while (_home(find.text('热门榜单')).evaluate().isEmpty && scrolls < 6) {
        await tester.drag(find.byType(MobileHomePage), const Offset(0, -400));
        await tester.pumpAndSettle();
        scrolls++;
      }
      expect(scrolls, greaterThan(0), reason: '排行榜区块位于首屏折叠线以下');
      expect(_home(find.text('热门榜单')), findsOneWidget);

      // 无假数据空态（§5.2：没有真实数据显示合理空状态）。
      expect(_home(find.text('当前没有支持歌单的音源')), findsOneWidget);
      expect(_home(find.byType(VxPlaylistCard)), findsNothing);
      expect(_home(find.text('没有支持排行榜的音源')), findsOneWidget);
    });

    testWidgets('有曲后空库 Hero 消失，最近播放横滑卡封面 72dp ∈ 64-76', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      model.debugSetHistory([
        _song('s1', '夜航'),
        _song('s2', 'Blue Hour', source: 'tx'),
      ]);
      await _pumpShell(tester, model);

      expect(find.text('音乐库还是空的'), findsNothing);
      expect(_home(find.text('最近播放')), findsOneWidget);
      expect(_home(find.text('夜航')), findsWidgets);

      // 横滑卡封面/卡宽 72dp（§5.2 封面 64-76，非桌面 156）。
      final card = tester.getSize(_home(find.byType(VxAlbumCard)).first);
      expect(card.width, 72);
    });
  });

  group('空库 Hero 两 CTA（§5.10 第一落点）', () {
    testWidgets('「搜索音乐」走 navRequest 总线切到搜索目的地', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      await _pumpShell(tester, model);

      await tester.tap(find.text('搜索音乐'));
      await tester.pumpAndSettle();

      // 总线消费并切页（mapLegacyNavIndex(1) = search）。
      expect(navRequest.value, isNull);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 2, reason: '搜索是底部五主入口第 3 项');
    });

    testWidgets('「导入本地音乐」直接触发真实文件/目录选择流程，不做跳转介绍页', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      var pickerCalls = 0;
      localDirectoryPicker = ({dialogTitle}) async {
        pickerCalls += 1;
        return null; // 用户取消（宿主测试环境无真实目录选择器）。
      };
      await _pumpShell(tester, model);

      await tester.tap(find.text('导入本地音乐'));
      await tester.pump();

      // §5.10：CTA 触发的是选择器流程本身（回调触发层锁定；导入→扫描→
      // 播放链路依赖真实文件系统与 Rust 控制器，按矩阵归 Phase 5，不伪验）。
      expect(pickerCalls, 1);
      // 不是跳转介绍页：不发生 navRequest 导航，仍在首页。
      expect(navRequest.value, isNull);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 0);
      expect(find.byType(LocalMusicPage), findsNothing);
    });

    testWidgets('窄视口 390：两 CTA 竖排全宽，按钮文字单行不折行（Phase 2 QA P1 回归）', (
      tester,
    ) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      await _pumpShell(tester, model);

      // 按钮整体近全宽（390-40 页边距-40 Hero 内边距=310）：横排等分回退
      // 时每按钮仅 ~149px，会被检出。
      Size buttonOf(Finder label, Type type) => tester.getSize(
        _home(
          find.ancestor(
            of: label,
            matching: find.byWidgetPredicate((w) => w.runtimeType == type),
          ),
        ),
      );
      final searchBtn = buttonOf(find.text('搜索音乐'), FilledButton);
      final importBtn = buttonOf(find.text('导入本地音乐'), OutlinedButton);
      expect(searchBtn.width, greaterThan(280), reason: '竖排后搜索 CTA 近全宽');
      expect(importBtn.width, greaterThan(280), reason: '竖排后导入 CTA 近全宽');

      // label 文字单行（13px 单行高 ≈15.6；折行成「导入本地音/乐」≥31）。
      expect(tester.getSize(_home(find.text('搜索音乐'))).height, lessThan(30));
      expect(
        tester.getSize(_home(find.text('导入本地音乐'))).height,
        lessThan(30),
        reason: '导入 CTA label 不得词中断行',
      );

      // 竖排结构：搜索在上、导入在下。
      final searchTop = tester.getTopLeft(_home(find.text('搜索音乐'))).dy;
      final importTop = tester.getTopLeft(_home(find.text('导入本地音乐'))).dy;
      expect(importTop, greaterThan(searchTop));
      expect(tester.takeException(), isNull);
    });
  });

  group('快捷入口真实落点', () {
    testWidgets('本地音乐 → 推入真实 LocalMusicPage；喜欢的歌曲 → 推入 LibraryPage 歌曲档', (
      tester,
    ) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      await _pumpShell(tester, model);

      // 本地音乐：LocalMusicPage 只在推入路由时存在（IndexedStack 无此页）。
      await tester.tap(_home(find.text('本地音乐')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(LocalMusicPage), findsOneWidget);
      // §5.10 第三落点：页顶「添加目录」主按钮可达（手机窄视口为带
      // tooltip 的图标按钮，≥600 为带标签按钮）。
      expect(find.byTooltip('添加目录'), findsOneWidget);
      expect(find.byTooltip('播放全部'), findsOneWidget);
      // 无 Rust 控制器时页面如实显示配置加载态（不伪造目录/歌曲）。
      expect(find.text('正在加载配置…'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 回到首页再点「喜欢的歌曲」：推入 LibraryPage 歌曲档（壳内
      // IndexedStack 常驻一份——非激活子树需 skipOffstage:false 才计入，
      // 推入路由激活一份，共两份）。
      await tester.tap(find.byIcon(Icons.arrow_back));
      // LocalMusicPage 弹出转场完成后再点下一入口（否则点击命中被退场
      // 路由拦截）。
      await tester.pumpAndSettle();
      await tester.tap(_home(find.text('喜欢的歌曲')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byType(LibraryPage, skipOffstage: false),
        findsNWidgets(2),
        reason: '喜欢的歌曲 → 真实 LibraryPage（songs = 喜欢的歌曲语义）',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('为你推荐四态（真实 loadPlaylists browse 槽）', () {
    testWidgets('成功态：真实歌单数据渲染为横向卡（非自建歌单冒充）', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      model.debugSetSources([
        bridge.SourceCapabilitiesDto(
          id: 'wy',
          name: '网易云',
          playlists: true,
          playlistCategories: true,
          playlistSearch: true,
          album: false,
          artist: false,
          leaderboard: false,
          login: false,
          qrLogin: false,
        ),
      ]);
      await _pumpShell(tester, model);
      // 帧后已发起真实歌单浏览请求。
      expect(
        model.browse('playlists', 'wy', ''),
        isNotNull,
        reason: '推荐区块按首个支持歌单的音源发起真实 loadPlaylists',
      );

      model.debugBrowseLoaded(
        kind: 'playlists',
        source: 'wy',
        id: '',
        playlists: [
          bridge.PlaylistDto(
            id: 'p1',
            name: '深夜通勤',
            source: 'wy',
            songCount: 30,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('深夜通勤'), findsOneWidget);
      // 音源标识出现在区块头 action 与卡片副标题（≥1 处）。
      expect(_home(find.text('网易云')), findsWidgets);
      expect(_home(find.byType(VxPlaylistCard)), findsOneWidget);
    });

    testWidgets('失败态：可读错误 + 重试（错误消息经净化，不直出原始异常）', (tester) async {
      _setSize(tester, const Size(390, 844));
      final model = AppModel();
      model.debugSetSources([
        bridge.SourceCapabilitiesDto(
          id: 'wy',
          name: '网易云',
          playlists: true,
          playlistCategories: false,
          playlistSearch: false,
          album: false,
          artist: false,
          leaderboard: false,
          login: false,
          qrLogin: false,
        ),
      ]);
      await _pumpShell(tester, model);
      model.debugBrowseLoaded(
        kind: 'playlists',
        source: 'wy',
        id: '',
        failed: true,
        message: 'fetch failed: https://api.example.com/v1/boards?token=secret',
      );
      // 失败事件伴随 toast 浮层（自带消隐计时器），不用 pumpAndSettle。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(_home(find.text('推荐加载失败')), findsOneWidget);
      // P1-07：URL/原始异常不直出 UI（净化为 [URL] 占位）。
      expect(_home(find.textContaining('https://')), findsNothing);
      expect(_home(find.textContaining('[URL]')), findsOneWidget);
      expect(_home(find.text('重试')), findsOneWidget);
    });
  });
}

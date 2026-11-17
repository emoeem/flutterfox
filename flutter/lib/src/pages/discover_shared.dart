/// 发现页共享业务面（桌面 DiscoverPage 与手机 MobileDiscoverPage 同一实现，
/// Batch C-01 自桌面页私有逻辑提炼；页面只做布局与交互，业务不允许第二份）。
///
/// - [DiscoverTab] / [discoverTabLabel] / [discoverTabEnabled] /
///   [discoverTabDisabledReason]：子 Tab 能力判定（原桌面页公开 API，原样迁入）；
/// - [DiscoverController]：音源/Tab/分类选择状态 + browse 请求编排
///   （聚合补拉、请求键去重、切源重载、四态重试），原 `_DiscoverPageState`
///   私有编排逻辑；桌面页与手机页各自只消费本控制器，不复制编排。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_empty_state.dart';

/// 发现页子 Tab。
enum DiscoverTab { playlists, leaderboard, artists, albums, categories }

/// Tab 标题（与计划书 §4.2 子导航一致）。
String discoverTabLabel(DiscoverTab tab) => switch (tab) {
  DiscoverTab.playlists => '精选歌单',
  DiscoverTab.leaderboard => '排行榜',
  DiscoverTab.artists => '歌手',
  DiscoverTab.albums => '专辑',
  DiscoverTab.categories => '分类',
};

/// Tab 是否可用（真实 SourceCapabilitiesDto）。
///
/// [source] 为 null 表示「全部音源」：按已启用音源的能力并集判定。
/// 纯函数，便于单测禁用逻辑。
bool discoverTabEnabled(
  DiscoverTab tab,
  List<bridge.SourceCapabilitiesDto> sources, {
  String? source,
}) {
  final pool = source == null
      ? sources
      : sources.where((item) => item.id == source);
  return switch (tab) {
    DiscoverTab.playlists => pool.any((item) => item.playlists),
    DiscoverTab.leaderboard => pool.any((item) => item.leaderboard),
    DiscoverTab.artists => pool.any((item) => item.artist),
    DiscoverTab.albums => pool.any((item) => item.album),
    DiscoverTab.categories => pool.any((item) => item.playlistCategories),
  };
}

/// Tab 禁用时的解释文案。
String discoverTabDisabledReason(DiscoverTab tab) => switch (tab) {
  DiscoverTab.playlists => '当前音源不支持浏览歌单',
  DiscoverTab.leaderboard => '当前音源不支持排行榜',
  DiscoverTab.artists => '当前音源不支持歌手浏览',
  DiscoverTab.albums => '当前音源不支持专辑浏览',
  DiscoverTab.categories => '当前音源不提供歌单分类',
};

/// 音源展示名（能力位名称优先，未知 id 原样）。
String discoverSourceName(AppModel model, String source) =>
    model.capability(source)?.name ?? source;

/// 歌手 / 专辑 Tab：后端没有「浏览全部歌手/专辑」的接口（只能从搜索结果或
/// 歌单详情进入），如实解释，不伪造入口。桌面与手机共用同一份文案与结构。
class DiscoverUnsupportedBody extends StatelessWidget {
  final DiscoverTab tab;

  /// 「去搜索」落点：桌面推入搜索页路由，手机切搜索目的地（navRequest）。
  final VoidCallback onSearch;

  const DiscoverUnsupportedBody({
    super.key,
    required this.tab,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return VxEmptyState(
      icon: tab == DiscoverTab.artists
          ? Icons.person_search_outlined
          : Icons.album_outlined,
      title: tab == DiscoverTab.artists ? '暂不支持浏览全部歌手' : '暂不支持浏览全部专辑',
      message: tab == DiscoverTab.artists
          ? '在线音源未提供歌手浏览接口：可以在搜索页搜索歌手名，或从歌曲行的「更多」进入歌手页。'
          : '在线音源未提供专辑浏览接口：可以在搜索页搜索专辑名，或从歌曲行进入专辑页面。',
      actionLabel: '去搜索',
      onAction: onSearch,
    );
  }
}

/// 发现页业务控制：单一实现供桌面/手机两页消费。
///
/// 生命周期：[attach] 挂模型监听并触发首轮加载；[detach] 解绑（IndexedStack
/// 常驻页面不 detach，模型交换时先 detach 再重建）。
class DiscoverController extends ChangeNotifier {
  DiscoverController(this.model);

  final AppModel model;

  static const categoriesKind = 'playlist_categories';
  static const playlistsKind = 'playlists';
  static const boardsKind = 'leaderboard_boards';

  /// 「全部音源」的菜单哨兵值。PopupMenuButton 把 pop 出的 null 当作
  /// 「未选择、菜单被取消」（SDK popup_menu.dart showButtonMenu 的 then
  /// 回调里 `newValue == null` 走 onCanceled），value 为 null 的菜单项
  /// 永远不会触发 onSelected——P1-20「选回全部音源不回退」即由此起。
  /// 真实音源 id 不可能为空串，用 '' 作哨兵安全。手机 chips 无该坑，
  /// 但单源↔全部音源可往返、聚合真实恢复的语义同一出处（selectSource）。
  static const allSourcesSentinel = '';

  /// null = 全部音源（内容按音源分组）。
  String? source;
  DiscoverTab tab = DiscoverTab.playlists;
  String category = '';

  final Set<String> _requestedBoards = {};
  final Set<String> _requestedPlaylistKeys = {};
  String? _categoriesRequested;

  bool _active = false;
  bool _loadScheduled = false;

  /// 挂模型监听并触发首轮加载（帧后派发，见 [_maybeLoad]）。
  void attach() {
    if (_active) return;
    _active = true;
    model.addListener(_maybeLoad);
    _maybeLoad();
  }

  /// 解绑模型监听；已调度的帧后加载作废（不向已拆页派发请求）。
  void detach() {
    if (!_active) return;
    _active = false;
    model.removeListener(_maybeLoad);
  }

  /// 模型通知驱动的加载调度：defer 到帧后执行——模型通知可能发生在
  /// build 期，直接派发会让祖先在 build 中被标脏（桌面页原语义）。
  void _maybeLoad() {
    if (_loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (!_active) return;
      _loadNow();
    });
  }

  void _loadNow() {
    if (source == null) {
      _loadAggregated();
      return;
    }
    _loadForSource(source!);
  }

  /// 「全部音源」：给每个支持当前 Tab 数据类型的音源补拉数据。
  void _loadAggregated() {
    final sources = model.state.sources;
    switch (tab) {
      case DiscoverTab.playlists:
        for (final source in sources.where((s) => s.playlists)) {
          ensurePlaylists(source.id, category);
        }
      case DiscoverTab.leaderboard:
        for (final source in sources.where((s) => s.leaderboard)) {
          if (_requestedBoards.add(source.id)) {
            model.loadLeaderboardBoards(source.id);
          }
        }
      case DiscoverTab.categories:
        for (final source in sources.where((s) => s.playlistCategories)) {
          _categoriesRequested ??= '';
          if (!_requestedBoards.contains('cat|${source.id}')) {
            _requestedBoards.add('cat|${source.id}');
            model.loadPlaylistCategories(source.id);
          }
        }
      case DiscoverTab.artists:
      case DiscoverTab.albums:
        break;
    }
  }

  void _loadForSource(String source) {
    switch (tab) {
      case DiscoverTab.playlists:
        ensurePlaylists(source, category);
      case DiscoverTab.leaderboard:
        if (_requestedBoards.add(source)) {
          model.loadLeaderboardBoards(source);
        }
      case DiscoverTab.categories:
        if (_categoriesRequested != source) {
          _categoriesRequested = source;
          model.loadPlaylistCategories(source);
        }
      case DiscoverTab.artists:
      case DiscoverTab.albums:
        break;
    }
  }

  /// 按请求键去重派发歌单加载（`source|category`）。
  void ensurePlaylists(String source, String category) {
    final key = '$source|$category';
    if (_requestedPlaylistKeys.add(key)) {
      model.loadPlaylists(source: source, category: category);
    }
  }

  // ── 交互 ──

  /// 切换音源范围（null = 全部音源）：清请求键强制重载；切源后当前 Tab
  /// 可能不再支持，回落到首个支持的 Tab（§5.3）。
  void selectSource(String? id) {
    if (source == id) return;
    source = id;
    category = '';
    _requestedBoards.clear();
    _requestedPlaylistKeys.clear();
    _categoriesRequested = null;
    if (!discoverTabEnabled(tab, model.state.sources, source: id)) {
      tab = _firstEnabledTab(id);
    }
    notifyListeners();
    _maybeLoad();
  }

  void selectTab(DiscoverTab value) {
    if (value == tab) return;
    tab = value;
    notifyListeners();
    _maybeLoad();
  }

  /// 分类 Tab 点分类：切到单源歌单视图并加载该分类（桌面页原语义）。
  void selectCategory(String sourceId, String categoryId) {
    source = sourceId;
    category = categoryId;
    tab = DiscoverTab.playlists;
    _requestedBoards.clear();
    _requestedPlaylistKeys.clear();
    notifyListeners();
    ensurePlaylists(sourceId, categoryId);
  }

  /// 手动刷新：清全部请求键重新补拉。
  void refresh() {
    _requestedBoards.clear();
    _requestedPlaylistKeys.clear();
    _categoriesRequested = null;
    notifyListeners();
    _maybeLoad();
  }

  DiscoverTab _firstEnabledTab(String? source) {
    for (final tab in DiscoverTab.values) {
      if (discoverTabEnabled(tab, model.state.sources, source: source)) {
        return tab;
      }
    }
    return DiscoverTab.playlists;
  }

  // ── 槽读取与四态重试 ──

  BrowseResult? playlistsResult(String sourceId) =>
      model.browse(playlistsKind, sourceId, category);

  BrowseResult? boardsResult(String sourceId) =>
      model.browse(boardsKind, sourceId, '');

  BrowseResult? categoriesResult(String sourceId) =>
      model.browse(categoriesKind, sourceId, '');

  /// 歌单组重试：清请求键重发（§7.1 可恢复操作）。
  void retryPlaylists(String sourceId) {
    _requestedPlaylistKeys.remove('$sourceId|$category');
    ensurePlaylists(sourceId, category);
  }

  /// 榜单组重试。
  void retryBoards(String sourceId) {
    _requestedBoards.remove(sourceId);
    if (_requestedBoards.add(sourceId)) {
      model.loadLeaderboardBoards(sourceId);
    }
  }

  /// 分类组重试。
  void retryCategories() {
    _categoriesRequested = null;
    _maybeLoad();
  }

  /// 歌单加载更多（append 分页走 AppModel 既有 append 语义）。
  void loadNextPlaylistsPage(String sourceId, BrowseResult result) {
    model.loadPlaylists(
      source: sourceId,
      category: category,
      page: result.page + 1,
    );
  }
}

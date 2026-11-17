/// 搜索页共享业务面（桌面 SearchPage 与手机 MobileSearchPage 同一实现，
/// Batch C-02 自桌面页私有逻辑提炼；页面只做布局与交互，业务不允许第二份）。
///
/// - [SearchType] / [searchTypeLabel]：结果类型（原桌面页枚举迁入）；
/// - [SearchPageController]：防抖提交、request_id 守卫（§8.1 过期响应不得覆盖
///   当前页面）、分页 in-flight 锁、音源多选筛选、歌曲结果聚合专辑/歌手、
///   计数行——原 `_SearchPageState` 私有业务；桌面页与手机页各自只消费
///   本控制器，不复制编排；
/// - [SearchResultFooter]：分页尾三态（加载中 / 失败重试 / 没有更多）同一实现；
/// - [confirmClearSearchHistory]：清空历史确认（§9 破坏性操作必须确认）。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/design_tokens.dart';

/// 搜索结果类型 Tab。
enum SearchType { all, songs, albums, artists, playlists }

/// 类型 Tab 标题。
String searchTypeLabel(SearchType type) => switch (type) {
  SearchType.all => '全部',
  SearchType.songs => '歌曲',
  SearchType.albums => '专辑',
  SearchType.artists => '歌手',
  SearchType.playlists => '歌单',
};

/// 搜索快照签名：响应/加载/错误任一变化都需要重绘结果区。
String searchSnapshotSignature(bridge.SearchDto search) =>
    '${search.requestId}|${search.loading}|${search.error}|${search.page}|'
    '${search.hasMore}|${search.items.length}';

/// 搜索页业务控制：单一实现供桌面/手机两页消费。
class SearchPageController extends ChangeNotifier {
  SearchPageController(this.model);

  final AppModel model;

  /// 输入防抖窗口（§5.4）。
  static const debounceMs = 300;

  Timer? _debounce;

  /// 分页 in-flight 锁：searchMore 已下发但还没看到新响应（requestId 未变）。
  bool _moreInFlight = false;
  BigInt _seenRequestId = BigInt.zero;
  String _seenSignature = '';

  /// 搜索历史签名：历史增删不改变 search 快照签名，但空关键词态的面板
  /// 必须随之重绘（单项删除/清空/置顶），所以通知守卫把历史一并纳入。
  String _seenHistorySignature = '';

  bool _active = false;

  /// 音源多选筛选；空集合 = 全部音源（聚合搜索）。
  /// 恰好选一个音源时下发给该音源过滤；多选时聚合搜索 + 本地过滤展示。
  final Set<String> selectedSources = {};

  SearchType type = SearchType.all;

  bool get moreInFlight => _moreInFlight;

  /// FFI search 只支持单音源过滤；恰好选 1 个音源时走后端过滤，
  /// 否则聚合搜索（null），展示时再按多选过滤。
  String? get dispatchSource =>
      selectedSources.length == 1 ? selectedSources.first : null;

  /// 挂模型监听：对齐桌面页 initState 的守卫基线与历史预取（不阻塞首帧）。
  void attach() {
    if (_active) return;
    _active = true;
    _seenRequestId = model.state.search.requestId;
    _seenSignature = searchSnapshotSignature(model.state.search);
    _seenHistorySignature = model.searchHistory.join('\u0000');
    model.addListener(_onModelChanged);
    // 历史读取容错降级（无插件通道 = 空历史），不阻塞首帧。
    unawaited(model.loadSearchHistory());
  }

  /// 解绑模型监听并取消在途防抖。
  void detach() {
    if (!_active) return;
    _active = false;
    model.removeListener(_onModelChanged);
    _debounce?.cancel();
  }

  /// 模型通知：新响应到达（requestId 变化）或出错时释放分页锁；
  /// 快照有变化时通知页面重绘。
  void _onModelChanged() {
    if (!_active) return;
    final search = model.state.search;
    // §8.1「过期响应不能覆盖当前页面」：requestId 回退的快照是旧查询的
    // 迟到响应——新查询结果已在树时直接忽略（正常链路 Rust 侧按序广播 +
    // start_search append 守卫拦截，此处为 Dart 层兜底）。
    if (search.requestId < _seenRequestId) return;
    final responseArrived =
        search.requestId != _seenRequestId || search.error != null;
    if (responseArrived && _moreInFlight) {
      _moreInFlight = false;
    }
    final signature = searchSnapshotSignature(search);
    final historySignature = model.searchHistory.join('\u0000');
    final historyChanged = historySignature != _seenHistorySignature;
    _seenHistorySignature = historySignature;
    if (!responseArrived && signature == _seenSignature && !historyChanged) {
      return;
    }
    _seenRequestId = search.requestId;
    _seenSignature = signature;
    notifyListeners();
  }

  // ── 数据/命令 ──

  /// [record] = 用户显式提交（回车 / 点击历史项 / Shell 种子）时记史；
  /// 防抖自动搜索与换筛选重搜不记，避免「周杰伦」「周杰伦音」等停顿
  /// 中间态污染历史。
  void runSearch(String keyword, {bool record = false}) {
    _debounce?.cancel();
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    if (record) unawaited(model.rememberSearch(trimmed));
    _moreInFlight = false;
    notifyListeners();
    unawaited(
      model.dispatch(
        bridge.FfiCommand.search(keyword: trimmed, source: dispatchSource),
      ),
    );
  }

  /// 输入防抖：停顿 [debounceMs] 后自动搜索一次（不记史）。
  void onSearchTextChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) return;
    _debounce = Timer(
      const Duration(milliseconds: debounceMs),
      () => runSearch(text),
    );
  }

  /// 触底加载下一页；in-flight 锁防重复分页。
  ///
  /// 分页请求必须携带与首页相同的音源过滤（P1-04）：否则第 2 页起回落
  /// 聚合搜索，混入其他音源结果——违反「分页响应只能合并到同一查询上下文」。
  void loadMoreIfNeeded() {
    final state = model.state.search;
    if (_moreInFlight || state.loading || !state.hasMore) return;
    if (state.keyword.isEmpty) return;
    _moreInFlight = true;
    notifyListeners();
    unawaited(
      model.dispatch(
        bridge.FfiCommand.searchMore(
          keyword: state.keyword,
          page: state.page + 1,
          source: dispatchSource,
        ),
      ),
    );
  }

  // ── 音源筛选 ──

  /// 切换音源选中（chips 多选语义）：点已选 chip 取消，空集合回聚合。
  void toggleSource(String id) {
    if (!selectedSources.add(id)) selectedSources.remove(id);
    notifyListeners();
  }

  /// 显式回「全部音源」。
  void clearSources() {
    selectedSources.clear();
    notifyListeners();
  }

  void selectType(SearchType value) {
    if (value == type) return;
    type = value;
    notifyListeners();
  }

  // ── 派生数据 ──

  /// 按音源多选过滤后的展示列表。
  /// 单选音源时后端已按该源过滤；多选时对聚合结果本地过滤。
  List<bridge.SongDto> items() {
    final items = model.state.search.items;
    if (selectedSources.length <= 1) return List<bridge.SongDto>.of(items);
    return items.where((s) => selectedSources.contains(s.source)).toList();
  }

  /// 从歌曲结果聚合专辑（同专辑+音源去重）。
  List<bridge.SongDto> albumRepresentatives() {
    final seen = <String>{};
    final result = <bridge.SongDto>[];
    for (final song in items()) {
      final name = song.albumName.trim();
      if (name.isEmpty) continue;
      final id = song.albumId?.trim();
      final key = '${(id != null && id.isNotEmpty) ? id : name}|${song.source}';
      if (!seen.add(key)) continue;
      result.add(song);
    }
    return result;
  }

  /// 从歌曲结果聚合歌手（同歌手+音源去重）。
  List<bridge.SongDto> artistRepresentatives() {
    final seen = <String>{};
    final result = <bridge.SongDto>[];
    for (final song in items()) {
      final name = song.singer.trim();
      if (name.isEmpty) continue;
      final id = song.artistId?.trim();
      final key = '${(id != null && id.isNotEmpty) ? id : name}|${song.source}';
      if (!seen.add(key)) continue;
      result.add(song);
    }
    return result;
  }

  /// 结果计数行（类型相关）。
  String countLine() {
    final state = model.state.search;
    switch (type) {
      case SearchType.albums:
        return '聚合出 ${albumRepresentatives().length} 张专辑';
      case SearchType.artists:
        return '聚合出 ${artistRepresentatives().length} 位歌手';
      case SearchType.playlists:
        return '聚合搜索不返回歌单，请到「发现」页浏览';
      case SearchType.all:
      case SearchType.songs:
        if (state.keyword.isEmpty) return '输入关键词开始搜索';
        return '找到 ${items().length} 个结果';
    }
  }

  /// 歌单 Tab 的如实解释（聚合搜索不返回歌单数据）。
  String playlistsExplain() {
    final capable = model.state.sources
        .where((s) => s.playlistSearch)
        .map((s) => s.name)
        .toList();
    return capable.isEmpty
        ? '当前音源的搜索接口只返回歌曲；可以在「发现」页浏览精选歌单。'
        : '聚合搜索只返回歌曲；${capable.join('、')}支持歌单搜索，可到「发现」页浏览。';
  }
}

/// 分页尾三态（加载中 / 失败重试 / 没有更多 / 继续滚动提示）。
/// 桌面与手机搜索页同一实现。
class SearchResultFooter extends StatelessWidget {
  final SearchPageController controller;

  const SearchResultFooter(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final state = controller.model.state.search;
    if (controller.moreInFlight || state.loading) {
      return const Padding(
        padding: EdgeInsets.all(VxSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (state.error != null) {
      return Padding(
        padding: const EdgeInsets.all(VxSpacing.md),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '加载更多失败',
                style: VxTypography.caption.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(width: VxSpacing.md),
              TextButton(
                onPressed: controller.loadMoreIfNeeded,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    if (!state.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(VxSpacing.lg),
        child: Center(
          child: Text(
            '没有更多结果',
            style: VxTypography.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(VxSpacing.md),
      child: Center(
        child: Text(
          '继续滚动加载更多…',
          style: VxTypography.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 清空搜索历史确认（§9 破坏性操作：必须确认，取消不动数据）。
Future<void> confirmClearSearchHistory(
  BuildContext context,
  AppModel model,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('清空搜索历史'),
      content: const Text('将删除全部搜索历史，无法恢复。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('清空'),
        ),
      ],
    ),
  );
  if (confirmed ?? false) unawaited(model.clearSearchHistory());
}

/// VxSongTable：SongDto 列表 → 全局 TrackRow 行表（§7.1 TrackTable）。
///
/// - 行复用 [SongTrackRow]（单击选中 / 双击播放 / 右键菜单，§9）；
/// - Enter 播放选中行；Ctrl/⌘ 点击多选、Shift 范围多选（基础版，Phase 6 扩展）；
/// - 统一收口加载 / 错误 / 空 / 不支持 / 翻页五种状态（§10.2）；
/// - 当前播放行持续高亮（由行内 [SongTrackRow] 判定）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/design_tokens.dart';
import '../pages/song_tile.dart';
import 'empty_state.dart';

/// 曲目行表。数据与回调全部来自构造器；选中态内部持有。
class VxSongTable extends StatefulWidget {
  const VxSongTable({
    super.key,
    required this.model,
    required this.songs,
    this.showIndex = true,
    this.showAlbum = true,
    this.showSource = true,
    this.loading = false,
    this.error,
    this.notice,
    this.emptyTitle = '暂无歌曲',
    this.emptySubtitle,
    this.onRetry,
    this.hasMore = false,
    this.onLoadMore,
    this.onRefresh,
    this.onRemoveSong,
    this.padding = const EdgeInsets.only(top: 4, bottom: VxSpacing.xl),
    this.focusOnEnter = true,
  });

  final AppModel model;
  final List<bridge.SongDto> songs;

  /// 是否显示序号列。
  final bool showIndex;

  /// 是否显示专辑列。
  final bool showAlbum;

  /// 是否显示音源列。
  final bool showSource;

  /// 加载中（列表为空时显示加载态）。
  final bool loading;

  /// 加载失败原因；非空显示错误态 + 重试。
  final String? error;

  /// 空态文案覆盖（如「该音源不支持歌手详情」）。
  final String? notice;

  /// 空态标题。
  final String emptyTitle;

  /// 空态副标题。
  final String? emptySubtitle;

  /// 错误态重试回调。
  final VoidCallback? onRetry;

  /// 是否还有下一页。
  final bool hasMore;

  /// 加载下一页回调。
  final VoidCallback? onLoadMore;

  /// 下拉刷新回调（§5.6 触底分页 + 下拉刷新）。非空时列表包
  /// RefreshIndicator 并放开 AlwaysScrollableScrollPhysics（内容不满一屏
  /// 也可下拉）；完成 Future 由调用方提供（page=1 响应或错误落槽时
  /// complete，见 AppModel.awaitBrowseResponse），本组件不伪造完成时机。
  /// 桌面鼠标无下拉手势：页面保留既有「刷新」菜单项为主入口。
  final Future<void> Function()? onRefresh;

  /// 从歌单移除回调（自建歌单详情用）；逐行透传给右键菜单。
  final void Function(bridge.SongDto song)? onRemoveSong;

  /// 列表内边距。
  final EdgeInsetsGeometry padding;

  /// Enter 键播放选中行（嵌入含输入框的布局时可关）。
  final bool focusOnEnter;

  @override
  State<VxSongTable> createState() => _VxSongTableState();
}

class _VxSongTableState extends State<VxSongTable> {
  final Set<int> _selected = {};
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _select(int index) {
    setState(() {
      if (isCtrlPressed()) {
        // Ctrl/⌘：多选切换。
        _selected.contains(index)
            ? _selected.remove(index)
            : _selected.add(index);
        return;
      }
      if (isShiftPressed() && _selected.isNotEmpty) {
        // Shift：从既有选区到点击处做范围选择。
        final anchor = _selected.reduce((a, b) => a < b ? a : b);
        final start = anchor < index ? anchor : index;
        final end = anchor < index ? index : anchor;
        _selected
          ..clear()
          ..addAll([for (var i = start; i <= end; i++) i]);
        return;
      }
      _selected
        ..clear()
        ..add(index);
    });
  }

  void _playSelected() {
    if (_selected.isEmpty) return;
    final songs = widget.songs;
    final ordered = _selected.toList()..sort();
    final index = ordered.where((i) => i < songs.length).first;
    widget.model.playSongs(songs, index: index);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _playSelected();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final songs = widget.songs;
    if (widget.loading && songs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('加载中…'),
          ],
        ),
      );
    }
    if (widget.error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: '加载失败',
            subtitle: widget.error,
          ),
          if (widget.onRetry != null)
            TextButton(onPressed: widget.onRetry, child: const Text('重试')),
        ],
      );
    }
    if (songs.isEmpty) {
      return EmptyState(
        icon: Icons.music_off_outlined,
        title: widget.notice ?? widget.emptyTitle,
        subtitle: widget.notice == null ? widget.emptySubtitle : null,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final list = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // 触底自动翻页（与翻页按钮二选一均可触发，幂等）。
        if (widget.hasMore &&
            widget.onLoadMore != null &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
          widget.onLoadMore!();
        }
        return false;
      },
      child: Focus(
        focusNode: _focus,
        onKeyEvent: widget.focusOnEnter ? _onKeyEvent : null,
        child: ListView.builder(
          padding: widget.padding,
          // 下拉刷新需在内容不满一屏时也可触发（否则 spinner 永不出现，
          // 手势等于摆设）；无 onRefresh 保持默认物理不扰动桌面滚动。
          physics: widget.onRefresh != null
              ? const AlwaysScrollableScrollPhysics()
              : null,
          itemCount: songs.length + (widget.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= songs.length) return _footer(context);
            final song = songs[index];
            final selected = _selected.contains(index);
            return GestureDetector(
              onDoubleTap: () => fireAndForget(widget.model.playSong(song)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                ),
                child: SongTrackRow(
                  widget.model,
                  song,
                  index: widget.showIndex ? index + 1 : null,
                  showAlbum: widget.showAlbum,
                  showSource: widget.showSource,
                  onTap: () => _select(index),
                  onRemove: widget.onRemoveSong == null
                      ? null
                      : () => widget.onRemoveSong!(song),
                ),
              ),
            );
          },
        ),
      ),
    );
    if (widget.onRefresh == null) return list;
    return RefreshIndicator(onRefresh: widget.onRefresh!, child: list);
  }

  Widget _footer(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: widget.loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: widget.onLoadMore,
                child: const Text('加载更多'),
              ),
      ),
    );
  }
}

/// Shift 按住检测（§9 范围多选）。
bool isShiftPressed() {
  final pressed = HardwareKeyboard.instance.logicalKeysPressed;
  return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
      pressed.contains(LogicalKeyboardKey.shiftRight);
}

/// Phase 2 右侧 ContextPanel（计划书 §3.2 / §5.3，S6 的修复点）。
///
/// - 默认 320px，280–420px 可拖动调整（左缘把手）；
/// - 三个 Tab：正在播放 / 歌词 / 队列，全部读 AppModel 真实状态；
/// - <1440 时由 Shell 以覆盖式浮层承载（responsive_shell 决定）；
/// - Phase 3：歌词 Tab 换用共用 LyricsPanel（§5.2 同步滚动/点击 seek），
///   队列 Tab 换用共用 QueuePanel（§5.3 分组/移除/清空确认/禁用项说明）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../design_system/design_tokens.dart';
import '../player/lyrics_panel.dart';
import '../player/queue_panel.dart';
import '../widgets/cover_image.dart';
import 'responsive_shell.dart';

/// ContextPanel 的三个 Tab。
enum ContextTab { nowPlaying, lyrics, queue }

/// 右侧上下文面板。
class ContextPanel extends StatefulWidget {
  const ContextPanel({
    super.key,
    required this.model,
    required this.tab,
    required this.onTabChanged,
    required this.onClose,
    this.width = ShellBreakpoints.contextDefaultWidth,
    this.onWidthChanged,
  });

  final AppModel model;
  final ContextTab tab;
  final ValueChanged<ContextTab> onTabChanged;
  final VoidCallback onClose;

  /// 当前宽度（Shell 持有状态；280–420）。
  final double width;

  /// 拖动把手改变宽度（null 表示不可调整，如浮层窄窗）。
  final ValueChanged<double>? onWidthChanged;

  @override
  State<ContextPanel> createState() => _ContextPanelState();
}

class _ContextPanelState extends State<ContextPanel> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titles = switch (widget.tab) {
      ContextTab.nowPlaying => '正在播放',
      ContextTab.lyrics => '歌词',
      ContextTab.queue => '队列',
    };
    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: VxColors.surface1,
        border: Border(
          left: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左缘宽度调整把手。
          if (widget.onWidthChanged != null)
            Align(
              alignment: Alignment.centerLeft,
              child: _ResizeHandle(
                width: widget.width,
                onWidthChanged: widget.onWidthChanged!,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titles,
                    style: VxTypography.title.copyWith(color: scheme.onSurface),
                  ),
                ),
                IconButton(
                  tooltip: '关闭面板',
                  iconSize: 18,
                  onPressed: widget.onClose,
                  icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final tab in ContextTab.values) ...[
                  _TabButton(
                    label: switch (tab) {
                      ContextTab.nowPlaying => '正在播放',
                      ContextTab.lyrics => '歌词',
                      ContextTab.queue => '队列',
                    },
                    active: widget.tab == tab,
                    onTap: () => widget.onTabChanged(tab),
                  ),
                  const SizedBox(width: 14),
                ],
              ],
            ),
          ),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          Expanded(
            child: switch (widget.tab) {
              ContextTab.nowPlaying => _NowPlayingTab(model: widget.model),
              ContextTab.lyrics => LyricsPanel(
                key: ValueKey(widget.tab),
                model: widget.model,
                compact: true,
              ),
              ContextTab.queue => QueuePanel(
                key: ValueKey(widget.tab),
                model: widget.model,
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// 左缘拖动把手：280–420px。
class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.width, required this.onWidthChanged});

  final double width;
  final ValueChanged<double> onWidthChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          onWidthChanged(
            (width - details.delta.dx).clamp(
              ShellBreakpoints.contextMinWidth,
              ShellBreakpoints.contextMaxWidth,
            ),
          );
        },
        child: SizedBox(width: 8, height: ShellBreakpoints.headerHeight),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: active ? scheme.primary : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── 正在播放 Tab ────────────────────────────────────────────────────────

class _NowPlayingTab extends StatelessWidget {
  const _NowPlayingTab({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final song = model.state.playback.song;
        if (song == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.music_note_outlined,
                  size: 42,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text('未在播放', style: VxTypography.title),
                const SizedBox(height: 4),
                Text(
                  '从搜索或曲库挑一首开始播放',
                  style: VxTypography.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        final favorite = model.isFavorite(song);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(VxRadius.lg),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CoverImage(url: song.coverUrl, size: 280, radius: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                song.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: VxTypography.h2.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: 3),
              Text(
                '${song.singer} · ${song.source}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VxTypography.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    tooltip: favorite ? '取消收藏' : '收藏',
                    onPressed: () => model.toggleFavorite(song),
                    icon: Icon(
                      favorite ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: favorite
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    favorite ? '已收藏' : '未收藏',
                    style: VxTypography.caption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── 歌词 / 队列 Tab 已由共用 LyricsPanel / QueuePanel 承担（Phase 3）────

/// Phase 3 队列面板（计划书 §5.3；ContextPanel 队列 Tab 与全屏播放页共用）。
///
/// 数据只读 AppModel.state.queue / queueIndex（唯一真源，UI 不自持队列副本），
/// 操作全部走真实命令：
/// - 拖动排序：FfiCommand.queueMove（Batch F §9.1 P2-09 收口，真实后端
///   语义，当前播放条目身份由 Rust move_item 保持）；
/// - 队内跳播：点按待播行 → FfiCommand.queuePlayAt；
/// - 行菜单「下一首播放」：FfiCommand.queueMove(index, current+1)；
/// - 移除：FfiCommand.queueRemove；清空：FfiCommand.queueClear（二次确认，
///   说明当前曲是否继续播放）；
/// - 随机开关：config.playMode 经 updateConfig 下发。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../config_ext.dart';
import '../design_system/components/vx_empty_state.dart';
import '../design_system/components/vx_seek_bar.dart' show vxFormatDuration;
import '../design_system/design_tokens.dart';
import '../widgets/cover_image.dart';

/// 队列 / Up Next 面板。
class QueuePanel extends StatelessWidget {
  const QueuePanel({super.key, required this.model});

  final AppModel model;

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空播放队列'),
        content: const Text('将移除队列中的全部待播歌曲；当前歌曲不受影响，继续播放。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await model.dispatch(const bridge.FfiCommand.queueClear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final state = model.state;
        final queue = state.queue;
        final currentIndex = state.queueIndex;
        if (queue.isEmpty) {
          return const VxEmptyState(
            icon: Icons.queue_music_outlined,
            title: '队列为空',
            message: '播放歌曲后会在这里显示待播列表；从搜索、曲库或歌单挑一首开始播放。',
          );
        }
        final upcoming = queue.length - (currentIndex + 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      upcoming > 0
                          ? '共 ${queue.length} 首 · 接下来 $upcoming 首'
                          : '共 ${queue.length} 首',
                      style: VxTypography.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: model,
                    builder: (context, _) {
                      final mode = model.config?.playMode;
                      final ready = model.config != null;
                      return IconButton(
                        tooltip: '随机播放',
                        iconSize: 18,
                        onPressed: ready
                            ? () => model.updateConfig(
                                (config) => config.copyWith(
                                  playMode: mode == 'random'
                                      ? 'list-loop'
                                      : 'random',
                                ),
                              )
                            : null,
                        icon: Icon(
                          Icons.shuffle,
                          color: mode == 'random'
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: '清空队列',
                    iconSize: 18,
                    onPressed: () => _confirmClear(context),
                    icon: Icon(Icons.clear_all, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              // 拖动排序（Batch F §9.1 P2-09 收口）：整列 ReorderableListView，
              // onReorderItem 直接给出换算后的目标索引（SDK 已抵消移除偏移），
              // 命令语义 = Rust move_item（当前播放条目身份由后端保持）。
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: queue.length,
                onReorderItem: (oldIndex, newIndex) {
                  if (newIndex != oldIndex) {
                    model.queueMove(oldIndex, newIndex);
                  }
                },
                proxyDecorator: (child, index, animation) => AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) => Material(
                    elevation: 6 * animation.value,
                    borderRadius: BorderRadius.circular(VxRadius.sm),
                    color: scheme.surfaceContainerHighest,
                    child: child,
                  ),
                ),
                itemBuilder: (context, index) {
                  final song = queue[index];
                  final isCurrent = index == currentIndex;
                  return _QueueRow(
                    key: ValueKey('q-$index-${song.source}-${song.id}'),
                    model: model,
                    song: song,
                    index: index,
                    currentIndex: currentIndex,
                    current: isCurrent,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 队列单行：拖柄（ReorderableDragStartListener）、封面、信息、时长、行菜单。
class _QueueRow extends StatelessWidget {
  const _QueueRow({
    super.key,
    required this.model,
    required this.song,
    required this.index,
    required this.currentIndex,
    this.current = false,
  });

  final AppModel model;
  final bridge.SongDto song;
  final int index;
  final int currentIndex;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final durationMs = song.durationMs.toInt();
    return Container(
      decoration: BoxDecoration(
        // V2 spec §4：当前行 accent-tint 底 + 描边；非当前行用透明 border
        // 占位，避免 hover 切换时内容 1px 跳动。
        color: current ? scheme.primary.withValues(alpha: 0.16) : null,
        borderRadius: BorderRadius.circular(VxRadius.sm),
        border: Border.all(
          color: current
              ? scheme.primary.withValues(alpha: 0.24)
              : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          // 拖动排序：Batch F P2-09 收口，queueMove 真实后端语义。
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.drag_indicator,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            // 队内跳播（Batch F §9.1）：点按待播行从该索引开始播放；
            // 当前播放行不响应点按（跳到自己无意义）。
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: current ? null : () => model.queuePlayAt(index),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: CoverImage(
                        url: song.coverUrl,
                        size: 34,
                        radius: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (current) ...[
                              Icon(
                                Icons.graphic_eq,
                                size: 13,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                song.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          song.singer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    vxFormatDuration(
                      durationMs > 0
                          ? Duration(milliseconds: durationMs)
                          : null,
                    ),
                    style: VxTypography.mono.copyWith(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '更多操作',
            iconSize: 18,
            padding: EdgeInsets.zero,
            color: scheme.surfaceContainerHigh,
            itemBuilder: (context) => [
              // 立即播放（Batch F）：queuePlayAt 队内跳播；当前曲不响应。
              PopupMenuItem<String>(
                value: 'play',
                enabled: !current,
                child: const Text('立即播放'),
              ),
              // 下一首播放（Batch F）：queueMove 移到当前播放之后。
              PopupMenuItem<String>(
                value: 'next',
                enabled: !current,
                child: const Text('下一首播放'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'remove',
                height: 40,
                child: Text('移出队列'),
              ),
            ],
            onSelected: (value) {
              if (value == 'play') {
                model.queuePlayAt(index);
              }
              if (value == 'next') {
                model.queueMove(index, currentIndex + 1);
              }
              if (value == 'remove') {
                model.queueRemove(index);
              }
            },
            icon: Icon(
              Icons.more_horiz,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

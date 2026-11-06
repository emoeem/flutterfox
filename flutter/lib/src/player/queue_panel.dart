/// Phase 3 队列面板（计划书 §5.3；ContextPanel 队列 Tab 与全屏播放页共用）。
///
/// 数据只读 AppModel.state.queue / queueIndex（唯一真源，UI 不自持队列副本），
/// 操作全部走真实命令：
/// - 移除：FfiCommand.queueRemove；清空：FfiCommand.queueClear（二次确认，
///   说明当前曲是否继续播放）；
/// - 随机开关：config.playMode 经 updateConfig 下发；
/// - 拖动排序 / 队列内跳播、移动：Rust 后端（FfiCommand）当前没有对应命令
///   （Phase 2 limitation 5），拖柄与「立即播放 / 下一首播放」菜单项禁用并
///   说明原因，不伪造。
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
        final current = (currentIndex >= 0 && currentIndex < queue.length)
            ? queue[currentIndex]
            : null;
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
                      '共 ${queue.length} 首',
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
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: [
                  if (current != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      child: Text(
                        '当前播放',
                        style: VxTypography.eyebrow.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    _QueueRow(
                      model: model,
                      song: current,
                      index: currentIndex,
                      current: true,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (upcoming > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      child: Text(
                        '接下来播放 · $upcoming 首',
                        style: VxTypography.eyebrow.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (var i = currentIndex + 1; i < queue.length; i++)
                    _QueueRow(model: model, song: queue[i], index: i),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 队列单行：拖柄（后端无排序命令 → 禁用说明）、封面、信息、时长、行菜单。
class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.model,
    required this.song,
    required this.index,
    this.current = false,
  });

  final AppModel model;
  final bridge.SongDto song;
  final int index;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final durationMs = song.durationMs.toInt();
    return Container(
      decoration: BoxDecoration(
        color: current ? scheme.surfaceContainerHighest : null,
        borderRadius: BorderRadius.circular(VxRadius.sm),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          // 拖动排序：后端暂无队列移动命令，禁用并说明（不伪造拖拽）。
          IconButton(
            tooltip: '后端暂无队列排序命令，暂不支持拖动排序',
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            onPressed: null,
            icon: Icon(
              Icons.drag_indicator,
              color: scheme.onSurface.withValues(alpha: 0.38),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 34,
              height: 34,
              child: CoverImage(url: song.coverUrl, size: 34, radius: 6),
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
              durationMs > 0 ? Duration(milliseconds: durationMs) : null,
            ),
            style: VxTypography.mono.copyWith(
              fontSize: 10.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '更多操作',
            iconSize: 18,
            padding: EdgeInsets.zero,
            color: scheme.surfaceContainerHigh,
            itemBuilder: (context) => [
              // 立即播放 / 下一首播放：FfiCommand 无队列跳播与移动命令，
              // 禁用并说明（queueAdd 只会重复入列，不伪装成移动）。
              const PopupMenuItem<String>(
                enabled: false,
                child: _DisabledMenuItem(
                  label: '立即播放',
                  reason: '后端暂无队列跳播命令',
                ),
              ),
              const PopupMenuItem<String>(
                enabled: false,
                child: _DisabledMenuItem(
                  label: '下一首播放',
                  reason: '后端暂无队列移动命令',
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'remove',
                height: 40,
                child: Text('移出队列'),
              ),
            ],
            onSelected: (value) {
              if (value == 'remove') {
                model.queueRemove(index);
              }
            },
            icon: Icon(Icons.more_horiz, size: 16, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 禁用菜单项：操作名 + 原因说明（§4.8「不支持的操作必须禁用并解释」）。
class _DisabledMenuItem extends StatelessWidget {
  const _DisabledMenuItem({required this.label, required this.reason});

  final String label;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.38),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          reason,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

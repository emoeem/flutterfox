// Voicefox queue drawer: fork 自 vendored myune/widgets/playing_queue_drawer.dart
// （Apache-2.0），数据源改为直接读 AppModel（真源），并补齐队列管理能力：
// 当前曲高亮、单曲移除（滑动/按钮）、清空（带确认）。上游的「保存队列为
// 歌单」依赖 myune 本地文件系统歌单，在 voicefox 外部数据模式下无意义，不搬。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../pages/song_tile.dart';

class VoicefoxQueueDrawer extends StatelessWidget {
  const VoicefoxQueueDrawer({super.key});

  Future<void> _confirmClear(BuildContext context, AppModel model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空播放队列'),
        content: const Text('将移除队列中的全部歌曲，当前播放继续。'),
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
    final model = context.watch<AppModel>();
    final state = model.state;
    final queue = state.queue;
    final currentIndex = state.queueIndex;

    return Drawer(
      width: 400,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '正在播放 (${queue.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.clear_all),
                    onPressed: queue.isEmpty
                        ? null
                        : () => _confirmClear(context, model),
                    tooltip: '清空队列',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (queue.isEmpty)
              const Expanded(
                child: Center(child: Text('当前没有播放任何歌曲')),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final song = queue[index];
                    final isCurrent = index == currentIndex;
                    return Dismissible(
                      key: ValueKey('queue-${song.source}-${song.id}-$index'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                      onDismissed: (_) => model.queueRemove(index),
                      child: SongTile(
                        model,
                        song,
                        selected: isCurrent,
                        onRemove: () => model.queueRemove(index),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

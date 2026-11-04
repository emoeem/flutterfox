/// 下载页：活跃任务卡（进度/取消）+ 清除已完成，桌面双列。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../widgets/empty_state.dart';

class DownloadsPage extends StatelessWidget {
  final AppModel model;

  const DownloadsPage(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = model.state.downloads;
    if (tasks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: pageTitle(context, '下载'),
          ),
          const Expanded(
            child: EmptyState(
              icon: Icons.download_outlined,
              title: '暂无下载任务',
              subtitle: '在歌曲行点下载按钮开始',
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: pageTitle(context, '下载'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextButton(
              onPressed: () => model.dispatch(
                const bridge.FfiCommand.downloadClearFinished(),
              ),
              child: const Text('清除已完成'),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 840 ? 2 : 1;
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 128,
                ),
                itemCount: tasks.length,
                itemBuilder: (context, index) =>
                    _TaskCard(model: model, task: tasks[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final AppModel model;
  final bridge.DownloadTaskDto task;

  const _TaskCard({required this.model, required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          '${task.name} - ${task.singer}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: task.total != null && task.total!.toInt() > 0
                        ? task.downloaded.toInt() / task.total!.toInt()
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  task.total != null && task.total!.toInt() > 0
                      ? '${(task.downloaded.toInt() * 100 ~/ task.total!.toInt())}%'
                      : _stateLabel(task.state),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              task.error ?? '${_stateLabel(task.state)} · ${task.quality}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: task.error != null
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: task.active
            ? IconButton(
                tooltip: '取消',
                icon: const Icon(Icons.close),
                onPressed: () => model.dispatch(
                  bridge.FfiCommand.downloadCancel(id: task.id),
                ),
              )
            : task.state == 'failed' || task.state == 'cancelled'
            ? IconButton(
                tooltip: '重试',
                icon: const Icon(Icons.refresh),
                onPressed: () => model.dispatch(
                  bridge.FfiCommand.downloadEnqueue(song: task.song),
                ),
              )
            : const Icon(Icons.check_circle_outline),
      ),
    );
  }
}

/// 后端任务状态 → 界面文案（不再把英文枚举直接抛给用户）。
String _stateLabel(String state) => switch (state) {
  'queued' => '排队中',
  'downloading' || 'active' => '下载中',
  'completed' => '已完成',
  'failed' => '失败',
  'cancelled' => '已取消',
  'skipped' => '已跳过',
  _ => state,
};

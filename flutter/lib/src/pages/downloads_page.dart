/// 下载页：活跃任务卡（进度/取消）+ 清除已完成。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;

class DownloadsPage extends StatelessWidget {
  final AppModel model;

  const DownloadsPage(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = model.state.downloads;
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          '暂无下载任务\n在歌曲行点下载按钮开始',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => model
                .dispatch(const bridge.FfiCommand.downloadClearFinished()),
            child: const Text('清除已完成'),
          ),
        ),
        for (final task in tasks)
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            : task.state,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.error ?? '${task.state} · ${task.quality}',
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
                      onPressed: () => model
                          .dispatch(bridge.FfiCommand.downloadCancel(id: task.id)),
                    )
                  : const Icon(Icons.check_circle_outline),
            ),
          ),
      ],
    );
  }
}

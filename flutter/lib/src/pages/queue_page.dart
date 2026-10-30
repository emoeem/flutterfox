/// 队列页（首页）：顶部播放控制卡 + 队列列表。
/// 布局规格见 docs/flutter_ui_spec.md §9 queue/main。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import 'song_tile.dart';

class QueuePage extends StatelessWidget {
  final AppModel model;

  const QueuePage(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    final state = model.state;
    final song = state.playback.song;
    final playback = state.playback;
    final positionSec = playback.positionMs.toInt() ~/ 1000;
    final durationSec = playback.durationMs.toInt() ~/ 1000;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  song?.name ?? '未在播放',
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  song == null ? '从搜索或收藏开始' : '${song.singer} · ${song.source}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Slider(
                  max: durationSec > 0 ? durationSec.toDouble() : 1,
                  value: positionSec
                      .clamp(0, durationSec > 0 ? durationSec : 1)
                      .toDouble(),
                  onChanged: (value) =>
                      model.seekMs(BigInt.from((value * 1000).round())),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_format(positionSec)),
                    Text(_format(durationSec)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: '上一首',
                      onPressed: model.previous,
                      icon: const Icon(Icons.skip_previous),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: model.toggle,
                      icon: Icon(
                        playback.state == 'playing'
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      label: Text(
                          playback.state == 'playing' ? '暂停' : '播放'),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: '下一首',
                      onPressed: model.next,
                      icon: const Icon(Icons.skip_next),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(
            '队列 · ${state.queue.length} 首',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          trailing: IconButton(
            tooltip: '清空队列',
            icon: const Icon(Icons.clear_all),
            onPressed: model.state.queue.isEmpty
                ? null
                : () => model.dispatch(const bridge.FfiCommand.queueClear()),
          ),
        ),
        for (var i = 0; i < state.queue.length; i++)
          SongTile(model, state.queue[i], index: i),
      ],
    );
  }

  String _format(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '$minutes:${rest.toString().padLeft(2, '0')}';
  }
}

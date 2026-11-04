// Voicefox host for the vendored myune player page.
// Newly written for voicefox, not vendored.
import 'package:flutter/material.dart';

import '../app_model.dart';
import '../myune/page/song_detail_page.dart';
import '../widgets/empty_state.dart';

/// Set to false to fall back to voicefox's legacy player page.
const bool useMyunePlayer = true;

/// myune's SongDetailPage driven by voicefox's AppModel.
///
/// Provider 图（SettingsProvider / ThemeProvider / NotificationService /
/// PlaylistContentNotifier）由 [MyuneHost] 在 Rust 引导完成后挂到 app 级，
/// AppModel 快照由 `MyuneProjection` 常驻投影进 notifier——本页只消费，
/// 不再临时建图（旧实现每次进页都重跑日志/歌单 JSON/热键初始化）。
class MyunePlayerPage extends StatelessWidget {
  const MyunePlayerPage({super.key, required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        if (model.state.playback.song == null) {
          // 没有正在播放的曲目时，vendored 页会显示「无歌词数据」，
          // 语义错误；这里给一个明确的空态。
          return Scaffold(
            appBar: AppBar(title: const Text('正在播放')),
            body: const EmptyState(
              icon: Icons.music_off,
              title: '暂无播放内容',
              subtitle: '从搜索或收藏里挑一首开始播放',
            ),
          );
        }
        return const SongDetailPage();
      },
    );
  }
}

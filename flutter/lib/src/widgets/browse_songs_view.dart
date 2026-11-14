/// 浏览类页面的曲目列表：统一处理加载 / 空 / 不支持 / 错误 / 翻页。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../widgets/empty_state.dart';
import '../pages/song_tile.dart';

class BrowseSongsView extends StatelessWidget {
  final AppModel model;
  final BrowseResult? result;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final String emptyTitle;
  final String? emptySubtitle;
  final bool showIndex;

  const BrowseSongsView({
    super.key,
    required this.model,
    required this.result,
    required this.onRetry,
    required this.onLoadMore,
    required this.emptyTitle,
    this.emptySubtitle,
    this.showIndex = true,
  });

  @override
  Widget build(BuildContext context) {
    final state = result;
    final songs = state?.songs ?? const <bridge.SongDto>[];
    if (state == null || (state.loading && songs.isEmpty)) {
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
    if (state.error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: '加载失败',
            subtitle: state.error,
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      );
    }
    if (songs.isEmpty) {
      return EmptyState(
        icon: Icons.music_off_outlined,
        title: state.notice ?? emptyTitle,
        subtitle: state.notice == null ? emptySubtitle : null,
      );
    }
    final hasMore = state.hasMore;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      itemCount: songs.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= songs.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: state.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: onLoadMore,
                      child: const Text('加载更多'),
                    ),
            ),
          );
        }
        return SongTile(model, songs[index], index: showIndex ? index : -1);
      },
    );
  }
}

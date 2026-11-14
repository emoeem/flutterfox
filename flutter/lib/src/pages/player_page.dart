/// 全屏播放页：封面 + 进度 + 传输控制 + 播放模式 + 全屏歌词。
///
/// 从 mini player 点击展开（容器变换式转场，规格 docs/flutter_ui_spec.md §9）。
/// 本页是独立路由，必须自行订阅 [AppModel]（根部的 AnimatedBuilder 只重建
/// `home`，不会刷新已 push 的路由）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../config_ext.dart';
import '../widgets/cover_image.dart';
import '../widgets/empty_state.dart';
import '../widgets/live_progress.dart';
import '../widgets/lyrics_view.dart';

class PlayerPage extends StatelessWidget {
  final AppModel model;

  const PlayerPage(this.model, {super.key});

  /// 播放页快捷键（仅本路由生效，避免干扰输入框）：
  /// 空格播放/暂停、←/→ 快退/快进 5 秒、Esc 收起。
  Widget _shortcuts(BuildContext context, Widget child) {
    void seekBy(int deltaMs) {
      final playback = model.state.playback;
      final duration = playback.durationMs.toInt();
      var target = playback.positionMs.toInt() + deltaMs;
      if (target < 0) target = 0;
      if (duration > 0 && target > duration) target = duration;
      model.seekMs(BigInt.from(target));
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): model.toggle,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            seekBy(-5000),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            seekBy(5000),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(autofocus: true, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final playback = model.state.playback;
        final song = playback.song;
        final favorite = song != null && model.isFavorite(song);
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: '收起',
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: const Text('正在播放'),
            actions: [
              if (song != null) ...[
                IconButton(
                  // §8.5：说明写入本地曲库，不假装远端账号红心。
                  tooltip: favorite ? '取消收藏（本地曲库）' : '收藏（本地曲库）',
                  onPressed: () => model.toggleFavorite(song),
                  icon: Icon(
                    favorite ? Icons.favorite : Icons.favorite_border,
                    color: favorite
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                IconButton(
                  tooltip: '下载',
                  onPressed: () => model.download(song),
                  icon: const Icon(Icons.download_outlined),
                ),
              ],
            ],
          ),
          body: _shortcuts(
            context,
            song == null
                ? const EmptyState(
                    icon: Icons.music_note_outlined,
                    title: '未在播放',
                    subtitle: '从搜索或收藏开始播放',
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 840;
                      final lyrics = model.state.lyrics;
                      final offset = model.config?.lyricOffsetMs ?? 0;
                      // 歌词推进订阅 playbackTick：纯进度变化只重建歌词视图。
                      final lyricsPanel = ListenableBuilder(
                        listenable: model.playbackTick,
                        builder: (context, _) {
                          final playback = model.state.playback;
                          return LivePlayback(
                            positionMs: playback.positionMs,
                            durationMs: playback.durationMs,
                            playing: playback.state == 'playing',
                            builder: (context, position, duration) =>
                                LyricsView(
                                  lines: lyrics.lines,
                                  // Rust 快照的 currentLine 不随播放推进，这里用
                                  // 插值位置 + 歌词偏移在前端二分推导，保证滚动
                                  // 与高亮实时。
                                  currentIndex: lyricIndexAt(
                                    lyrics.lines,
                                    position.inMilliseconds,
                                    offsetMs: offset,
                                  ),
                                  translation: lyrics.translation,
                                  snapshotCurrentLine: lyrics.currentLine,
                                  onSeekMs: (ms) =>
                                      model.seekMs(BigInt.from(ms)),
                                ),
                          );
                        },
                      );
                      final transport = _Transport(
                        model: model,
                        song: song,
                        playback: playback,
                        compact: !wide,
                      );
                      if (!wide) {
                        return Column(
                          children: [
                            transport,
                            Expanded(child: lyricsPanel),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          SizedBox(
                            width: 360,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                96,
                              ),
                              child: transport,
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: lyricsPanel),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

/// 传输区：封面 + 曲目信息 + 进度滑条 + 上一首/播放/下一首 + 播放模式。
class _Transport extends StatelessWidget {
  final AppModel model;
  final bridge.SongDto song;
  final bridge.PlaybackDto playback;
  final bool compact;

  const _Transport({
    required this.model,
    required this.song,
    required this.playback,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final playing = playback.state == 'playing';
    final config = model.config;
    final info = Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          song.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: compact
              ? Theme.of(context).textTheme.titleLarge
              : Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          '${song.singer} · ${song.source}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (song.albumName.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            song.albumName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 8 : 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CoverImage(url: song.coverUrl, size: 96, radius: 12),
                const SizedBox(width: 12),
                Expanded(child: info),
              ],
            )
          else ...[
            Center(
              child: CoverImage(url: song.coverUrl, size: 280, radius: 16),
            ),
            const SizedBox(height: 16),
            info,
          ],
          const SizedBox(height: 12),
          // 进度订阅 playbackTick：纯进度变化只重建滑条区。
          ListenableBuilder(
            listenable: model.playbackTick,
            builder: (context, _) {
              final playback = model.state.playback;
              return LivePlayback(
                positionMs: playback.positionMs,
                durationMs: playback.durationMs,
                playing: playing,
                builder: (context, position, duration) => Column(
                  children: [
                    Slider(
                      max: duration.inMilliseconds > 0
                          ? duration.inMilliseconds.toDouble()
                          : 1,
                      value: position.inMilliseconds
                          .clamp(
                            0,
                            duration.inMilliseconds > 0
                                ? duration.inMilliseconds
                                : 1,
                          )
                          .toDouble(),
                      onChanged: duration > Duration.zero
                          ? (value) => model.seekMs(BigInt.from(value.round()))
                          : null,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatDuration(position),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          formatDuration(duration),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: '上一首',
                onPressed: model.previous,
                icon: const Icon(Icons.skip_previous, size: 32),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: compact ? 64 : 72,
                height: compact ? 64 : 72,
                child: FilledButton(
                  onPressed: model.toggle,
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: Icon(
                    playing ? Icons.pause : Icons.play_arrow,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                tooltip: '下一首',
                onPressed: model.next,
                icon: const Icon(Icons.skip_next, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mode in const [
                ('none', '顺序'),
                ('list-loop', '列表'),
                ('single-loop', '单曲'),
                ('random', '随机'),
              ])
                ChoiceChip(
                  label: Text(mode.$2),
                  selected: config?.playMode == mode.$1,
                  onSelected: config == null
                      ? null
                      : (_) => model.updateConfig(
                          (config) => config.copyWith(playMode: mode.$1),
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

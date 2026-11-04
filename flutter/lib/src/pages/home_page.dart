/// 首页：播放器式布局（参考 Spotify / QQ 音乐桌面端）——
/// 「正在播放」hero + 最近在听/热门歌单/排行榜横向书架 + 快捷入口。
/// 此前是 FlClash 式仪表盘（统计数字卡/快捷开关/下载进度卡），工具面板
/// 气质太重，v3 视觉迭代中整体替换。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../myune_shell/myune_player_page.dart';
import '../nav_bus.dart';
import '../theme/typography.dart' show monoStyle;
import '../widgets/cover_image.dart';
import '../widgets/live_progress.dart';
import '../widgets/song_card.dart';
import 'leaderboard_page.dart';
import 'playlist_detail_page.dart';

class HomePage extends StatelessWidget {
  final AppModel model;

  const HomePage(this.model, {super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final playback = model.state.playback;
        final song = playback.song;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text('首页', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _NowPlayingHero(model: model, song: song, greeting: _greeting()),
            const SizedBox(height: 24),
            _Section(
              title: '最近在听',
              actionLabel: model.state.history.isEmpty ? null : '去曲库',
              onAction: () => navRequest.value = 2,
              child: _RecentShelf(model: model),
            ),
            _Section(
              title: '热门歌单',
              actionLabel: '去歌单浏览',
              onAction: () => navRequest.value = 3,
              child: _DiscoverPlaylistsShelf(model: model),
            ),
            _Section(
              title: '排行榜',
              actionLabel: '去排行榜',
              onAction: () => navRequest.value = 4,
              child: _LeaderboardShelf(model: model),
            ),
            const _QuickAccess(),
          ],
        );
      },
    );
  }
}

/// Spotify 式书架分区：标题 + 「查看全部」右对齐。
class _Section extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  const _Section({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// 「正在播放」hero：有大封面+进度+控制；无歌时是问候+快捷搜索。
class _NowPlayingHero extends StatelessWidget {
  final AppModel model;
  final bridge.SongDto? song;
  final String greeting;

  const _NowPlayingHero({
    required this.model,
    required this.song,
    required this.greeting,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final song = this.song;
    if (song == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '搜索一首歌，或从下面书架挑个歌单开始听',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.tonalIcon(
                onPressed: () => navRequest.value = 1,
                icon: const Icon(Icons.search),
                label: const Text('去搜索'),
              ),
            ],
          ),
        ),
      );
    }
    final playing = model.state.playback.state == 'playing';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MyunePlayerPage(model: model),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  CoverImage(url: song.coverUrl, size: 88, radius: 10),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('正在播放',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: scheme.primary)),
                        const SizedBox(height: 4),
                        Text(
                          song.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${song.singer}${song.albumName.isEmpty ? '' : ' · ${song.albumName}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: FilledButton(
                      onPressed: model.toggle,
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      child: Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 24,
                child: LivePlayback(
                  positionMs: model.state.playback.positionMs,
                  durationMs: model.state.playback.durationMs,
                  playing: playing,
                  builder: (context, position, duration) => Row(
                    children: [
                      Text(
                        '${position.inMinutes}:${(position.inSeconds.remainder(60)).toString().padLeft(2, '0')}',
                        style: monoStyle(context,
                            Theme.of(context).textTheme.labelSmall),
                      ),
                      Expanded(
                        child: Slider(
                          max: 1,
                          value: duration.inMilliseconds > 0
                              ? (position.inMilliseconds /
                                      duration.inMilliseconds)
                                  .clamp(0.0, 1.0)
                              : 0.0,
                          onChanged: duration.inMilliseconds > 0
                              ? (v) => model.seekMs(
                                    BigInt.from(
                                        (duration.inMilliseconds * v).round()),
                                  )
                              : null,
                        ),
                      ),
                      Text(
                        '${duration.inMinutes}:${(duration.inSeconds.remainder(60)).toString().padLeft(2, '0')}',
                        style: monoStyle(context,
                            Theme.of(context).textTheme.labelSmall),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 最近在听横向书架：封面 124 卡，点击播放。
class _RecentShelf extends StatelessWidget {
  final AppModel model;

  const _RecentShelf({required this.model});

  @override
  Widget build(BuildContext context) {
    final history = model.state.history;
    if (history.isEmpty) {
      return _ShelfHint(
        icon: Icons.history,
        text: '播放过的歌曲会出现在这里',
      );
    }
    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: history.length.clamp(0, 20),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final song = history[index];
          return SizedBox(
            width: 128,
            child: SongCard(model, song),
          );
        },
      ),
    );
  }
}

/// 热门歌单横向书架（数据加载沿用帧后调度模式）。
class _DiscoverPlaylistsShelf extends StatefulWidget {
  final AppModel model;

  const _DiscoverPlaylistsShelf({required this.model});

  @override
  State<_DiscoverPlaylistsShelf> createState() =>
      _DiscoverPlaylistsShelfState();
}

class _DiscoverPlaylistsShelfState extends State<_DiscoverPlaylistsShelf> {
  String? _requestedSource;

  String? _pickSource() {
    for (final source in widget.model.state.sources) {
      if (source.playlists) return source.id;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // 加载触发挂在模型监听里；调度 defer 到帧后执行——模型通知可能发生在
    // build 期，直接触发会让祖先 AnimatedBuilder 在 build 中被标脏。
    widget.model.addListener(_maybeLoad);
    _maybeLoad();
  }

  @override
  void didUpdateWidget(covariant _DiscoverPlaylistsShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      oldWidget.model.removeListener(_maybeLoad);
      widget.model.addListener(_maybeLoad);
      _maybeLoad();
    }
  }

  @override
  void dispose() {
    widget.model.removeListener(_maybeLoad);
    super.dispose();
  }

  bool _loadScheduled = false;

  void _maybeLoad() {
    if (_loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (!mounted) return;
      _loadNow();
    });
  }

  void _loadNow() {
    final source = _pickSource();
    if (source == null || _requestedSource == source) return;
    _requestedSource = source;
    widget.model.loadPlaylists(source: source);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.model,
      builder: (context, _) {
        final source = _pickSource();
        final result =
            source == null ? null : widget.model.browse('playlists', source, '');
        if (source == null) {
          return const _ShelfHint(
            icon: Icons.queue_music_outlined,
            text: '没有支持歌单的音源',
          );
        }
        if (result == null || (result.loading && result.playlists.isEmpty)) {
          return const _ShelfHint(
            icon: null,
            text: '热门歌单加载中…',
            loading: true,
          );
        }
        if (result.error != null && result.playlists.isEmpty) {
          return _ShelfHint(
            icon: Icons.cloud_off,
            text: '加载失败：${result.error}',
          );
        }
        if (result.playlists.isEmpty) {
          return _ShelfHint(
            icon: Icons.queue_music_outlined,
            text: result.notice ?? '暂无推荐歌单',
          );
        }
        return SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: result.playlists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final playlist = result.playlists[index];
              return SizedBox(
                width: 132,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PlaylistDetailPage(widget.model, playlist),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CoverImage(
                        url: playlist.coverUrl,
                        size: 128,
                        radius: 10,
                        icon: Icons.queue_music,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        playlist.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// 排行榜书架：支持榜单的音源 chip 行，点击直达该音源榜单。
class _LeaderboardShelf extends StatelessWidget {
  final AppModel model;

  const _LeaderboardShelf({required this.model});

  @override
  Widget build(BuildContext context) {
    final capable = model.state.sources
        .where((source) => source.leaderboard)
        .toList();
    if (capable.isEmpty) {
      return const _ShelfHint(
        icon: Icons.leaderboard_outlined,
        text: '没有支持排行榜的音源，可在设置中启用',
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final source in capable)
          ActionChip(
            avatar: const Icon(Icons.leaderboard_outlined, size: 16),
            label: Text(source.name),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('排行榜')),
                  body: LeaderboardPage(model, initialSource: source.id),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 快捷入口行：shell 导航索引见 app_shell 注册表。
class _QuickAccess extends StatelessWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = const [
      (Icons.search, '搜索', 1),
      (Icons.favorite_border, '曲库', 2),
      (Icons.playlist_play_outlined, '在线歌单', 3),
      (Icons.library_music_outlined, '本地音乐', 5),
      (Icons.download_outlined, '下载', 6),
      (Icons.settings_outlined, '设置', 7),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (icon, label, index) in entries)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => navRequest.value = index,
            child: Container(
              width: 108,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(icon, size: 22, color: scheme.primary),
                  const SizedBox(height: 6),
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ShelfHint extends StatelessWidget {
  final IconData? icon;
  final String text;
  final bool loading;

  const _ShelfHint({required this.text, this.icon, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (icon != null)
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

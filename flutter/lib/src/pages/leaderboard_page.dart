/// 排行榜：榜单目录（可切换音源）+ 榜内歌曲列表。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../widgets/browse_songs_view.dart';
import '../widgets/empty_state.dart';

class LeaderboardPage extends StatefulWidget {
  final AppModel model;
  final String? initialSource;

  final bool showChrome;

  /// showChrome=false：嵌入 VoicefoxShell 时隐藏自带 AppBar（Shell Header 已有标题/返回）。
  const LeaderboardPage(
    this.model, {
    super.key,
    this.initialSource,
    this.showChrome = true,
  });

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  String? _source;
  String? _loadedSource;
  String? _boardId;
  String? _loadedBoardKey;

  AppModel get _model => widget.model;

  @override
  void initState() {
    super.initState();
    // 选源与加载挂在模型监听里；调度 defer 到帧后执行——模型通知可能
    // 发生在 build 期，直接触发会让祖先在 build 中被标脏。
    _model.addListener(_maybeLoad);
    _maybeLoad();
  }

  @override
  void didUpdateWidget(covariant LeaderboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      oldWidget.model.removeListener(_maybeLoad);
      widget.model.addListener(_maybeLoad);
      _maybeLoad();
    }
  }

  @override
  void dispose() {
    _model.removeListener(_maybeLoad);
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
    final capable = _model.state.sources
        .where((source) => source.leaderboard)
        .toList();
    if (capable.isEmpty) return;
    if (widget.initialSource != null &&
        capable.any((item) => item.id == widget.initialSource)) {
      _source ??= widget.initialSource;
    }
    _source ??= capable.first.id;
    final source = _source!;
    if (_loadedSource != source) {
      _loadedSource = source;
      _model.loadLeaderboardBoards(source);
    }
    final result = _model.browse('leaderboard_boards', source, '');
    final boards = result?.boards ?? const <bridge.LeaderboardDto>[];
    if (boards.isEmpty) return;
    // 默认选中首个可用榜单并直接加载榜内歌曲，用户无需先手选。
    final selected =
        _boardId != null && boards.any((board) => board.id == _boardId)
        ? _boardId!
        : boards.first.id;
    _boardId = selected;
    final boardKey = '$source|$selected';
    if (_loadedBoardKey != boardKey) {
      _loadedBoardKey = boardKey;
      _model.loadLeaderboardSongs(source, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showChrome ? AppBar(title: const Text('排行榜')) : null,
      body: ListenableBuilder(
        listenable: _model,
        builder: (context, _) {
          final capable = _model.state.sources
              .where((source) => source.leaderboard)
              .toList();
          if (capable.isEmpty) {
            return const EmptyState(
              icon: Icons.leaderboard_outlined,
              title: '没有支持排行榜的音源',
              subtitle: '可在设置中启用支持排行榜的音源',
            );
          }
          final source = _source ?? capable.first.id;
          final result = _model.browse('leaderboard_boards', source, '');
          final boards = result?.boards ?? const <bridge.LeaderboardDto>[];
          // 选中榜只读推导，不在此处写状态（_loadNow 负责把选择持久化并
          // 触发榜内歌曲加载）；_boardId 尚未就位时回落首榜。
          final selectedBoard =
              _boardId != null && boards.any((board) => board.id == _boardId)
              ? _boardId!
              : (boards.isEmpty ? '' : boards.first.id);
          return Column(
            children: [
              _sourceChips(context, capable, source),
              if (boards.isNotEmpty)
                _boardChips(context, boards, selectedBoard),
              Expanded(child: _content(context, source, result, boards)),
            ],
          );
        },
      ),
    );
  }

  Widget _sourceChips(
    BuildContext context,
    List<bridge.SourceCapabilitiesDto> capable,
    String selected,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          for (final source in capable)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(source.name),
                selected: source.id == selected,
                onSelected: (_) => setState(() {
                  _source = source.id;
                  _boardId = null;
                  _loadedBoardKey = null;
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _boardChips(
    BuildContext context,
    List<bridge.LeaderboardDto> boards,
    String selected,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          for (final board in boards)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(board.name),
                selected: board.id == selected,
                onSelected: (_) => setState(() => _boardId = board.id),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context,
    String source,
    BrowseResult? result,
    List<bridge.LeaderboardDto> boards,
  ) {
    if (result == null || (result.loading && boards.isEmpty)) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('榜单加载中…'),
          ],
        ),
      );
    }
    if (result.error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: '榜单加载失败',
            subtitle: result.error,
          ),
          TextButton(
            onPressed: () => _model.loadLeaderboardBoards(source),
            child: const Text('重试'),
          ),
        ],
      );
    }
    if (boards.isEmpty) {
      return EmptyState(
        icon: Icons.leaderboard_outlined,
        title: result.notice ?? '该音源暂无榜单',
        subtitle: result.notice == null ? '换一个音源试试' : null,
      );
    }
    final board = boards.firstWhere(
      (item) => item.id == _boardId,
      orElse: () => boards.first,
    );
    return _songs(context, source, board);
  }

  Widget _songs(
    BuildContext context,
    String source,
    bridge.LeaderboardDto board,
  ) {
    final result = _model.browse('leaderboard_songs', source, board.id);
    final songs = result?.songs ?? const <bridge.SongDto>[];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  [
                    source.toUpperCase(),
                    if (board.update != null) board.update!,
                    if (songs.isNotEmpty) '${songs.length} 首',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              FilledButton.icon(
                onPressed: songs.isEmpty ? null : () => _model.playSongs(songs),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('播放全部'),
              ),
            ],
          ),
        ),
        Expanded(
          child: BrowseSongsView(
            model: _model,
            result: result,
            onRetry: () => _model.loadLeaderboardSongs(source, board.id),
            onLoadMore: () => _model.loadLeaderboardSongs(
              source,
              board.id,
              page: (result?.page ?? 0) + 1,
            ),
            emptyTitle: '榜单暂无歌曲',
            emptySubtitle: '换一个榜单试试',
          ),
        ),
      ],
    );
  }
}

class LeaderboardSongsPage extends StatefulWidget {
  final AppModel model;
  final String source;
  final bridge.LeaderboardDto board;

  const LeaderboardSongsPage(this.model, this.source, this.board, {super.key});

  @override
  State<LeaderboardSongsPage> createState() => _LeaderboardSongsPageState();
}

class _LeaderboardSongsPageState extends State<LeaderboardSongsPage> {
  static const _kind = 'leaderboard_songs';

  AppModel get _model => widget.model;

  @override
  void initState() {
    super.initState();
    // 从祖先 ListenableBuilder 里 push 进来时，initState 内的 notify 会撞上构建期。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _model.loadLeaderboardSongs(widget.source, widget.board.id);
    });
  }

  BrowseResult? get _result =>
      _model.browse(_kind, widget.source, widget.board.id);

  void _reload() => _model.loadLeaderboardSongs(widget.source, widget.board.id);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final result = _result;
        final songs = result?.songs ?? const <bridge.SongDto>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.board.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: '刷新',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          widget.source.toUpperCase(),
                          if (widget.board.update != null) widget.board.update!,
                          if (songs.isNotEmpty) '${songs.length} 首',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: songs.isEmpty
                          ? null
                          : () => _model.playSongs(songs),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('播放全部'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: BrowseSongsView(
                  model: _model,
                  result: result,
                  onRetry: _reload,
                  onLoadMore: () => _model.loadLeaderboardSongs(
                    widget.source,
                    widget.board.id,
                    page: (result?.page ?? 0) + 1,
                  ),
                  emptyTitle: '榜单暂无歌曲',
                  emptySubtitle: '换一个榜单试试',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

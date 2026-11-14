/// 手机本地音乐页（计划书 C-05，指南 §5.10：本地导入与本地曲库的手机档布局）。
///
/// 作为整页路由 push（手机壳抽屉「本地音乐」与手机首页快捷入口落点），
/// 自带 Scaffold + AppBar（推入路由需自己承担系统 inset——与壳 body 页的
/// 「无 Scaffold」约定不同，见 shell/android_insets.dart 分层契约）。
///
/// 布局：AppBar（返回/标题/播放全部/添加目录）→ 扫描状态横幅（可取消）→
/// 统计条/已取消横幅 → 警告横幅 → 目录管理卡（逐目录移除）→ 计数行 →
/// 曲目列表（移动行：单击播放整列、长按桌面右键同款菜单）。
///
/// - 业务与桌面 local_music_page.dart 同一实现：目录增删走既有
///   [importLocalMusicDirectory]（file_picker 链路 + 手输回退 + 重入门禁）
///   与 [localMusicPathsAfterRemove]；扫描走 [AppModel.scanLocal]/[AppModel.cancelScan]
///  （取消不提交语义由 AppModel 既有实现保证：scanCancelled 横幅 +
///   scanStats 置 null，localSongs 不变）；本页只做布局与交互；
/// - 进入页面自动补扫描与桌面同一条 TUI 规则（启用 + 有目录 + 曲库空 +
///   未在扫描，只补一次）；
/// - 空库引导（§5.10）：未配置目录 → 添加目录；已配置无歌 → 重新扫描 /
///   添加目录 / 去在线搜索（pop 回壳后经 navRequest 切搜索目的地）；
/// - 触控目标 ≥48dp。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../config_ext.dart';
import '../design_system/components/vx_artwork.dart';
import '../design_system/components/vx_track_row.dart';
import '../design_system/design_tokens.dart';
import '../nav_bus.dart' as nav_bus;
import 'local_music_page.dart'
    show importLocalMusicDirectory, localMusicPathsAfterRemove;
import 'song_tile.dart' show showSongMenu, songSourceLabel;

class MobileLocalMusicPage extends StatefulWidget {
  final AppModel model;

  const MobileLocalMusicPage(this.model, {super.key});

  @override
  State<MobileLocalMusicPage> createState() => _MobileLocalMusicPageState();
}

class _MobileLocalMusicPageState extends State<MobileLocalMusicPage> {
  /// 进入页面自动补扫描只触发一次（与桌面 local_music_page.dart 同一
  /// TUI 规则：启用 + 已配置目录 + 曲库为空 + 未在扫描）。
  bool _autoScanRequested = false;

  AppModel get _model => widget.model;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        _scheduleAutoScan();
        final songs = _model.state.localSongs;
        final scanning = _model.scanningLocal;
        final config = _model.config;
        return Scaffold(
          appBar: AppBar(
            title: const Text('本地音乐'),
            actions: [
              IconButton(
                tooltip: '播放全部',
                onPressed: scanning || songs.isEmpty
                    ? null
                    : () => _model.playSongs(songs),
                icon: const Icon(Icons.play_arrow),
              ),
              IconButton(
                tooltip: '添加目录',
                onPressed: scanning ? null : _addDirectory,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 扫描中横幅（可取消）与统计条/已取消横幅：空库与有歌两个
                // 分支共用（首次扫描发生在空库态，取消入口必须在）。
                _statusArea(context, scanning),
                if (_model.scanWarnings.isNotEmpty)
                  _warningBanner(context, _model.scanWarnings),
                Expanded(child: _body(context, songs, scanning, config)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 状态区 ──

  /// 扫描中横幅（可取消）+ 统计条/已取消横幅（与桌面 _statusArea 同语义）。
  Widget _statusArea(BuildContext context, bool scanning) {
    final children = <Widget>[
      if (scanning)
        Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: VxSpacing.sm),
            const Expanded(child: Text('正在扫描本地歌曲…')),
            TextButton(
              onPressed: () => _model.cancelScan(),
              child: const Text('取消'),
            ),
          ],
        ),
      if (_model.scanCancelled)
        _cancelledBanner(context)
      else if (_model.scanStats != null)
        _statsBanner(context, _model.scanStats!),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VxSpacing.lg,
        VxSpacing.sm,
        VxSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  /// §5.10 流程 5 统计条：新增/复用/无法读取/无音频文件/移除；有失败项时
  /// 提供「重试」（重扫即重试，与桌面同一语义）。
  Widget _statsBanner(BuildContext context, bridge.ScanStatsDto stats) {
    final scheme = Theme.of(context).colorScheme;
    final parts = <String>[
      '新增 ${stats.parsed}',
      '复用 ${stats.reused}',
      '无法读取 ${stats.failed}',
      '无音频文件 ${stats.skipped}',
      '移除 ${stats.removed}',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              parts.join(' · '),
              softWrap: true,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          if (stats.failed > 0)
            TextButton(
              onPressed: () => _model.scanLocal(),
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }

  /// 扫描被取消的横幅：本次结果未提交，已入库歌曲保持不变。
  Widget _cancelledBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '扫描已取消；已入库歌曲保持不变',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _warningBanner(BuildContext context, List<String> warnings) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VxSpacing.lg,
        VxSpacing.sm,
        VxSpacing.lg,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '扫描警告：${warnings.join('；')}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
        ),
      ),
    );
  }

  // ── 主体分支 ──

  Widget _body(
    BuildContext context,
    List<bridge.SongDto> songs,
    bool scanning,
    bridge.ConfigDto? config,
  ) {
    if (songs.isEmpty && scanning) {
      // 扫描文案与取消入口在状态区，这里只放全屏指示器避免重复文案。
      return const Center(child: CircularProgressIndicator());
    }
    if (songs.isEmpty && config == null) {
      // 无 Rust 控制器/配置未达：如实显示加载态（不伪造目录/歌曲）。
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('正在加载配置…'),
          ],
        ),
      );
    }
    if (songs.isEmpty) {
      return _empty(context, config!, scanning);
    }
    return _library(context, songs);
  }

  Widget _library(BuildContext context, List<bridge.SongDto> songs) {
    final paths = _model.config?.localMusicPaths ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            VxSpacing.lg,
            VxSpacing.sm,
            VxSpacing.lg,
            0,
          ),
          child: _directoryCard(context, paths),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            VxSpacing.lg,
            VxSpacing.sm,
            VxSpacing.lg,
            0,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '共 ${songs.length} 首',
              style: VxTypography.titleSm.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(child: _songList(context, songs)),
      ],
    );
  }

  /// 曲目列表（移动行）：单击播放整列（触屏无 hover），长按 = 桌面右键
  /// 菜单的触屏替代（同一份 showSongMenu 菜单与命令接线，§9）。
  Widget _songList(BuildContext context, List<bridge.SongDto> songs) {
    final current = _model.state.playback.song;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: VxSpacing.xl),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return VxTrackRow(
          title: song.name,
          artist: song.singer,
          source: songSourceLabel(_model, song.source),
          density: VxTrackRowDensity.comfortable,
          showIndex: false,
          showAlbum: false,
          cover: VxArtwork(
            url: song.coverUrl,
            source: song.source,
            entityType: 'song',
            entityId: song.id,
            entityName: song.name,
            size: 44,
            radius: 6,
            allowRetry: false,
          ),
          duration: song.durationMs.toInt() > 0
              ? Duration(milliseconds: song.durationMs.toInt())
              : null,
          isPlaying:
              current != null &&
              current.id == song.id &&
              current.source == song.source,
          isLiked: _model.isFavorite(song),
          onTap: () => _model.playSongs(songs, index: index),
          onLongPressStart: (details) => showSongMenu(
            context,
            _model,
            song,
            position: details.globalPosition,
          ),
          onMore: () {
            final box = context.findRenderObject() as RenderBox?;
            final overlay =
                Overlay.of(context).context.findRenderObject() as RenderBox?;
            Offset? anchor;
            if (box != null && overlay != null) {
              anchor = box.localToGlobal(
                Offset(box.size.width - 40, box.size.height / 2),
              );
            }
            showSongMenu(context, _model, song, position: anchor);
          },
        );
      },
    );
  }

  // ── 空库引导 ──

  Widget _empty(BuildContext context, bridge.ConfigDto config, bool scanning) {
    if (config.localMusicPaths.isEmpty) {
      return _emptyBody(
        context,
        icon: Icons.folder_off_outlined,
        title: '尚未配置本地音乐目录',
        subtitle: '添加一个音乐文件夹，扫描后即可在这里播放',
        action: FilledButton.icon(
          onPressed: _addDirectory,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('添加目录'),
        ),
      );
    }

    if (_model.scanWarnings.isNotEmpty) {
      return _emptyBody(
        context,
        icon: Icons.error_outline,
        title: '扫描失败',
        subtitle: _model.scanWarnings.join('\n'),
        action: FilledButton.icon(
          onPressed: _scan,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
      );
    }

    // 已配置目录但没有歌曲：目录管理卡与空态并排展示，目录增删在空态下
    // 依然可用；「去在线搜索」先 pop 回壳再经 navRequest 切搜索目的地。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            VxSpacing.lg,
            VxSpacing.sm,
            VxSpacing.lg,
            0,
          ),
          child: _directoryCard(context, config.localMusicPaths),
        ),
        Expanded(
          child: _emptyBody(
            context,
            icon: Icons.music_off_outlined,
            title: '未扫描到本地歌曲',
            subtitle: '可重新扫描，或添加其他音乐文件夹',
            action: FilledButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.refresh),
              label: const Text('重新扫描'),
            ),
            secondary: Wrap(
              spacing: VxSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _addDirectory,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                  label: const Text('添加目录'),
                ),
                TextButton.icon(
                  onPressed: _goOnlineSearch,
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('去在线搜索'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyBody(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget action,
    Widget? secondary,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: VxSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _warningText(title: title, subtitle: subtitle, icon: icon),
            const SizedBox(height: 12),
            action,
            ?secondary,
          ],
        ),
      ),
    );
  }

  Widget _warningText({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ── 目录管理卡 ──

  /// 目录管理卡：逐个目录 + 移除按钮（与桌面同一确认与配置链路）。
  Widget _directoryCard(BuildContext context, List<String> paths) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(VxSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(VxRadius.lg),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '音乐目录',
            style: VxTypography.titleSm.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: VxSpacing.sm),
          for (final path in paths)
            Padding(
              padding: const EdgeInsets.only(bottom: VxSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: VxSpacing.sm),
                  Expanded(
                    child: Text(
                      path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VxTypography.body.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '移除目录 $path',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    onPressed: () => _removeDirectory(path),
                  ),
                ],
              ),
            ),
          if (paths.isEmpty)
            Text(
              '尚未配置本地音乐目录',
              style: VxTypography.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  // ── 动作 ──

  /// 与 TUI `should_scan_local_music_on_entry` 一致（桌面
  /// local_music_page.dart 同一规则）：仅在首次进入且「启用 + 有目录 +
  /// 曲库为空 + 未扫描」时自动补一次扫描。
  void _scheduleAutoScan() {
    if (_autoScanRequested) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoScanRequested) return;
      final config = _model.config;
      if (config == null) return; // 等配置事件到达后再判断
      if (!config.localMusicEnabled ||
          config.localMusicPaths.isEmpty ||
          _model.state.localSongs.isNotEmpty ||
          _model.scanningLocal) {
        _autoScanRequested = true;
        return;
      }
      _autoScanRequested = true;
      _model.scanLocal();
    });
  }

  Future<void> _scan() async {
    final paths = _model.config?.localMusicPaths ?? const <String>[];
    if (paths.isEmpty) return _addDirectory();
    await _model.scanLocal();
  }

  Future<void> _addDirectory() => importLocalMusicDirectory(context, _model);

  /// 空库引导「去在线搜索」：pop 回壳后经 navRequest 切搜索目的地
  ///（mapLegacyNavIndex 1 = 搜索；手机壳/桌面壳同消费该总线）。
  void _goOnlineSearch() {
    Navigator.of(context).maybePop();
    nav_bus.navRequest.value = 1;
  }

  Future<void> _removeDirectory(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除本地音乐目录'),
        content: Text('将从扫描范围移除「$path」；已扫描到的歌曲不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final config = _model.config;
    if (config == null) return;
    final paths = localMusicPathsAfterRemove(config.localMusicPaths, path);
    await _model.updateConfig(
      (current) => current.copyWith(localMusicPaths: paths),
    );
    if (paths.isNotEmpty) {
      await _model.scanLocal(paths: paths);
    }
  }
}

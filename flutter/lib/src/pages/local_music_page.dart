/// 本地音乐页：目录管理（增删）+ 扫描进度 + 错误信息 + 歌曲列表（§4.4）。
///
/// 消费 `state.localSongs`；目录列表来自配置 `localMusicPaths`（Rust 侧
/// 只读镜像，删除/添加都走 ConfigUpdate，回环事件刷新）。本地扫描不是
/// 自动发生的（`local_songs()` 只读快照），进入页面时按 TUI 同规则补一次
/// 扫描：已启用 + 已配置目录 + 曲库为空 + 未在扫描。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:file_picker/file_picker.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../config_ext.dart';
import '../design_system/design_tokens.dart';
import '../widgets/song_table_view.dart';

class LocalMusicPage extends StatefulWidget {
  final AppModel model;

  const LocalMusicPage(this.model, {super.key});

  @override
  State<LocalMusicPage> createState() => _LocalMusicPageState();
}

class _LocalMusicPageState extends State<LocalMusicPage> {
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
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(context, scanning, songs),
              Expanded(
                child: songs.isEmpty && scanning
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('正在扫描本地歌曲…'),
                          ],
                        ),
                      )
                    : songs.isEmpty && config == null
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text('正在加载配置…'),
                              ],
                            ),
                          )
                        : songs.isEmpty
                            ? _empty(context, config!)
                            : _library(context, songs, scanning),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar(
    BuildContext context,
    bool scanning,
    List<bridge.SongDto> songs,
  ) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          const SizedBox(width: VxSpacing.md),
          IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, size: 20),
          ),
          const SizedBox(width: VxSpacing.xs),
          Text(
            '本地音乐',
            style: VxTypography.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: VxSpacing.lg),
          if (scanning)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: scanning ? null : _addDirectory,
            icon: const Icon(Icons.create_new_folder_outlined, size: 18),
            label: const Text('添加目录'),
          ),
          const SizedBox(width: VxSpacing.sm),
          FilledButton.icon(
            onPressed: scanning || songs.isEmpty
                ? null
                : () => _model.playSongs(songs),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('播放全部'),
          ),
          const SizedBox(width: VxSpacing.lg),
        ],
      ),
    );
  }

  Widget _library(
    BuildContext context,
    List<bridge.SongDto> songs,
    bool scanning,
  ) {
    final paths = _model.config?.localMusicPaths ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(VxSpacing.xl, 0, VxSpacing.xl, 0),
          child: _directoryCard(context, paths),
        ),
        if (scanning) ...[
          const SizedBox(height: VxSpacing.sm),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: VxSpacing.xl),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: VxSpacing.sm),
                Text('正在扫描本地歌曲…'),
              ],
            ),
          ),
        ],
        if (_model.scanWarnings.isNotEmpty) ...[
          const SizedBox(height: VxSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VxSpacing.xl),
            child: _warningBanner(context, _model.scanWarnings),
          ),
        ],
        const SizedBox(height: VxSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: VxSpacing.xl),
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
        Expanded(
          child: VxSongTable(
            model: _model,
            songs: songs,
            emptyTitle: '未扫描到本地歌曲',
            showSource: false,
          ),
        ),
      ],
    );
  }

  /// 目录管理卡：逐个目录 + 删除按钮 + 添加入口。
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

  Widget _empty(BuildContext context, bridge.ConfigDto config) {
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

    // 已配置目录但没有歌曲：目录管理卡与空态并排展示，
    // 目录增删在空态下依然可用。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(VxSpacing.xl, 0, VxSpacing.xl, 0),
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
            secondary: TextButton.icon(
              onPressed: _addDirectory,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('添加目录'),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _warningText(title: title, subtitle: subtitle, icon: icon),
          const SizedBox(height: 12),
          action,
          ?secondary,
        ],
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
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
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

  Widget _warningBanner(BuildContext context, List<String> warnings) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '扫描警告：${warnings.join('；')}',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: scheme.onErrorContainer),
      ),
    );
  }

  /// 与 TUI `should_scan_local_music_on_entry` 一致：仅在首次进入且
  /// 「启用 + 有目录 + 曲库为空 + 未扫描」时自动补一次扫描。
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

  Future<void> _addDirectory() async {
    // 优先系统目录选择器（file_picker）；选择器不可用（部分 Wayland
    // 沙盒环境）时回退手输绝对路径对话框。
    String? target;
    try {
      target = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择本地音乐目录',
      );
    } on PlatformException {
      target = null;
    }
    target ??= await _manualPathDialog();
    if (!mounted) return;

    final path = (target ?? '').trim();
    if (path.isEmpty) return;
    final config = _model.config;
    if (config == null) return;
    final paths = config.localMusicPaths.contains(path)
        ? config.localMusicPaths
        : [...config.localMusicPaths, path];
    await _model.updateConfig(
      (current) => current.copyWith(localMusicPaths: paths),
    );
    await _model.scanLocal(paths: paths);
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

  Future<String?> _manualPathDialog() async {
    final controller = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加本地音乐目录'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '目录绝对路径',
            hintText: '/home/用户名/Music',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('添加并扫描'),
          ),
        ],
      ),
    );
    controller.dispose();
    return path;
  }
}

/// 目录移除后的列表（纯函数，便于测试）：保持原顺序，仅去掉目标路径。
List<String> localMusicPathsAfterRemove(List<String> paths, String path) =>
    [for (final item in paths) if (item != path) item];

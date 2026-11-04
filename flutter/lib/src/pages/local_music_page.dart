/// 本地音乐页：消费 `state.localSongs`，支持播放全部 / 单曲播放 / 入队。
///
/// 本地扫描不是自动发生的（`local_songs()` 只读快照），因此进入页面时按 TUI
/// 同规则补一次扫描：已启用 + 已配置目录 + 曲库为空 + 未在扫描。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:file_picker/file_picker.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../config_ext.dart';
import '../widgets/empty_state.dart';
import 'song_tile.dart';

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
        return Scaffold(
          appBar: AppBar(
            title: const Text('本地音乐'),
            actions: [
              IconButton(
                tooltip: '添加目录',
                onPressed: _addDirectory,
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
              IconButton(
                tooltip: '重新扫描',
                onPressed: scanning ? null : _scan,
                icon: scanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _body(context, songs, scanning),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    List<bridge.SongDto> songs,
    bool scanning,
  ) {
    if (songs.isEmpty && scanning) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('正在扫描本地歌曲…'),
          ],
        ),
      );
    }
    final config = _model.config;
    if (songs.isEmpty && config == null) {
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
    if (songs.isEmpty) return _empty(context, config!);

    return Column(
      children: [
        _header(context, songs, scanning),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            itemCount: songs.length,
            itemBuilder: (context, index) => SongTile(
              _model,
              songs[index],
              index: index,
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    List<bridge.SongDto> songs,
    bool scanning,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final paths = _model.config?.localMusicPaths ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '共 ${songs.length} 首',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton.icon(
                onPressed: scanning ? null : () => _model.playSongs(songs),
                icon: const Icon(Icons.play_arrow),
                label: const Text('播放全部'),
              ),
            ],
          ),
          if (paths.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '目录：${paths.join('、')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (_model.scanWarnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            _warningBanner(context, _model.scanWarnings),
          ],
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, bridge.ConfigDto config) {
    if (config.localMusicPaths.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const EmptyState(
            icon: Icons.folder_off_outlined,
            title: '尚未配置本地音乐目录',
            subtitle: '添加一个音乐文件夹，扫描后即可在这里播放',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _addDirectory,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('添加目录'),
          ),
        ],
      );
    }

    if (_model.scanWarnings.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EmptyState(
            icon: Icons.error_outline,
            title: '扫描失败',
            subtitle: _model.scanWarnings.join('\n'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        EmptyState(
          icon: Icons.music_off_outlined,
          title: '未扫描到本地歌曲',
          subtitle: '当前目录：${config.localMusicPaths.join('、')}\n'
              '可重新扫描，或添加其他音乐文件夹',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _scan,
          icon: const Icon(Icons.refresh),
          label: const Text('重新扫描'),
        ),
        TextButton.icon(
          onPressed: _addDirectory,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('添加目录'),
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
      target = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择本地音乐目录');
    } on PlatformException {
      target = null;
    }
    target ??= await _manualPathDialog();

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

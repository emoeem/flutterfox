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
              // Phase 5：扫描进度（可取消）与统计条对空库/有歌两种分支都可见。
              _statusArea(context, scanning),
              Expanded(
                child: songs.isEmpty && scanning
                    // 扫描文案与取消入口在共享状态区（_statusArea），
                    // 这里只放全屏指示器避免重复文案。
                    ? const Center(child: CircularProgressIndicator())
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
      // 窄视口（手机 <600，§5.10 顶部主按钮仍可达）压缩为图标按钮；
      // ≥600 保持桌面带标签语义不变。
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          return Row(
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
              if (compact)
                IconButton(
                  tooltip: '添加目录',
                  onPressed: scanning ? null : _addDirectory,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                )
              else
                OutlinedButton.icon(
                  onPressed: scanning ? null : _addDirectory,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('添加目录'),
                ),
              const SizedBox(width: VxSpacing.sm),
              if (compact)
                IconButton(
                  tooltip: '播放全部',
                  onPressed: scanning || songs.isEmpty
                      ? null
                      : () => _model.playSongs(songs),
                  icon: const Icon(Icons.play_arrow, size: 20),
                )
              else
                FilledButton.icon(
                  onPressed: scanning || songs.isEmpty
                      ? null
                      : () => _model.playSongs(songs),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('播放全部'),
                ),
              const SizedBox(width: VxSpacing.lg),
            ],
          );
        },
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
        // 扫描中横幅与统计条在共享状态区（_statusArea），空库分支同样可见。
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

  /// 共享状态区：扫描中横幅（可取消）+ 统计条/取消横幅。
  /// 空库与有歌两个分支共用（首次扫描发生在空库态，取消入口必须在）。
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
      // §5.10 流程 5：完成后的统计条（新增/复用/无法读取/无音频文件/移除），
      // 复用警告横幅位置；取消的扫描 stats 为 null，显示已取消横幅。
      if (_model.scanCancelled)
        _cancelledBanner(context)
      else if (_model.scanStats != null)
        _statsBanner(context, _model.scanStats!),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VxSpacing.xl,
        VxSpacing.sm,
        VxSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
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

  /// §5.10 流程 5 统计条：新增/复用/无法读取/无音频文件/移除；
  /// 有失败项时提供「重试」（重扫即重试：失败文件没有指纹记录，会重新解析；
  /// 部分失败不影响已提交结果）。
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
    return Container(
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

  Future<void> _addDirectory() => importLocalMusicDirectory(context, _model);

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

/// 目录移除后的列表（纯函数，便于测试）：保持原顺序，仅去掉目标路径。
List<String> localMusicPathsAfterRemove(List<String> paths, String path) => [
  for (final item in paths)
    if (item != path) item,
];

/// 系统目录选择器挂钩（§5.10 导入流程真实选择步骤）。
///
/// 生产缺省为 file_picker 的系统目录选择器；测试环境注入替身以锁定
/// 「导入 CTA 直接触发文件/目录选择流程，而非跳转介绍页」这一契约层
/// （选择器本身的系统对话框在宿主测试环境不可用）。
Future<String?> Function({String? dialogTitle}) localDirectoryPicker =
    FilePicker.getDirectoryPath;

/// 系统文件选择器挂钩（§5.10 流程 2「选择文件」）：与目录选择器同构的
/// 可注入 seam，生产缺省 file_picker 的单文件选择（取选中文件路径）。
Future<String?> Function({String? dialogTitle}) localFilePicker =
    ({String? dialogTitle}) async =>
        (await FilePicker.pickFile(dialogTitle: dialogTitle))?.path;

/// 导入目标翻译 seam（§5.10：content:// 等 SAF URI 的落点）。
///
/// 桌面直路径原样返回；Android `content://` 需要持久授权翻译
/// （SAF → 本地可访问路径），本环境无 JDK/模拟器无法实机验证，
/// 缺省实现直接抛 [UnsupportedError]，由调用方转成错误提示——
/// 不伪造导入成功。Android 实装后替换此缺省实现。
Future<String> Function(String target) localImportResolver =
    defaultImportResolver;

/// 生产缺省 resolver：content:// 抛 UnsupportedError，其余原样返回。
/// 公开以便测试复位（见各测试 setUp）。
Future<String> defaultImportResolver(String target) async {
  if (target.startsWith('content://')) {
    throw UnsupportedError('暂不支持该文件来源（content://），请使用文件夹导入或手动输入路径');
  }
  return target;
}

/// 导入方式（§5.10 流程 1-2）。
enum _ImportChoice { directory, file }

/// 导入入口双选项对话框；返回 null 表示用户取消。
Future<_ImportChoice?> _importChoiceDialog(BuildContext context) {
  return showModalBottomSheet<_ImportChoice>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('选择文件夹'),
            subtitle: const Text('扫描整个目录（含子目录）'),
            onTap: () =>
                Navigator.of(sheetContext).pop(_ImportChoice.directory),
          ),
          ListTile(
            leading: const Icon(Icons.audio_file_outlined),
            title: const Text('选择文件'),
            subtitle: const Text('导入单个音频或 CUE 文件'),
            onTap: () => Navigator.of(sheetContext).pop(_ImportChoice.file),
          ),
        ],
      ),
    ),
  );
}

/// 导入流重入门禁（P1-16）：同一时刻只允许一条导入流。
///
/// 运行时实证（2026-11-13 Xvfb 真实后端复走）：无 portal 环境下系统选择器
/// 挂起不返回，sheet 已 pop 而后续对话框未出现——处于该间隙的用户再次点击
/// 「添加目录」会在内嵌 Navigator 上叠开第二条 modal 流，两条流交叉
/// push/pop 撕裂路由 teardown，正是 `_dependents.isEmpty` 断言
/// （framework.dart:6281 InheritedElement.debugDeactivated，Phase 5 三个
/// 会话红屏）的已知触发族（flutter/flutter#39131、SO 60528729 同类）。
/// 门禁使进行中的第二次触发直接返回，消除交织。
bool _importFlowActive = false;

/// 测试复位重入门禁（与选择器/resolver seam 的 setUp 复位同口径：
/// 门禁是模块级状态，用例未走完导入流时会残留到下一用例）。
void debugResetImportFlowGate() => _importFlowActive = false;

/// 直接触发本地音乐导入流程（§5.10：导入入口必须直接触发文件/目录
/// 选择，不得只跳转介绍页）。
///
/// 手机首页空库 Hero「导入本地音乐」CTA 与本页顶部「添加目录」按钮
/// 共用同一实现（单一出处，Phase 2 提取）。流程：双选项（选择文件夹/
/// 选择文件）→ 系统选择器（不可用时回退手输绝对路径对话框——手输是
/// 回退手段，不是唯一方法）→ 追加到配置 `localMusicPaths` → 扫描。
Future<void> importLocalMusicDirectory(
  BuildContext context,
  AppModel model,
) async {
  if (_importFlowActive) return;
  _importFlowActive = true;
  try {
    await _importFlow(context, model);
  } finally {
    _importFlowActive = false;
  }
}

Future<void> _importFlow(BuildContext context, AppModel model) async {
  final choice = await _importChoiceDialog(context);
  if (choice == null || !context.mounted) return;
  if (choice == _ImportChoice.file) {
    await _importSingleFile(context, model);
    return;
  }

  // 优先系统目录选择器（file_picker）；选择器不可用（部分 Wayland
  // 沙盒环境）时回退手输绝对路径对话框。
  String? target;
  try {
    target = await localDirectoryPicker(dialogTitle: '选择本地音乐目录');
  } on PlatformException {
    target = null;
  }
  if (!context.mounted) return;
  target ??= await _manualPathDialog(context);
  if (!context.mounted) return;

  final path = (target ?? '').trim();
  if (path.isEmpty) return;
  final config = model.config;
  if (config == null) return;
  final paths = config.localMusicPaths.contains(path)
      ? config.localMusicPaths
      : [...config.localMusicPaths, path];
  await model.updateConfig(
    (current) => current.copyWith(localMusicPaths: paths),
  );
  await model.scanLocal(paths: paths);
}

/// 「选择文件」分支：单文件导入。文件路径与目录一样追加进
/// `localMusicPaths`（Rust 扫描对文件路径直取），重启后仍在。
Future<void> _importSingleFile(BuildContext context, AppModel model) async {
  String? target;
  try {
    target = await localFilePicker(dialogTitle: '选择本地音乐文件');
  } on PlatformException {
    target = null;
  }
  if (!context.mounted) return;
  target ??= await _manualFileDialog(context);
  if (!context.mounted) return;
  final picked = (target ?? '').trim();
  if (picked.isEmpty) return;

  final String resolved;
  try {
    resolved = await localImportResolver(picked);
  } on UnsupportedError catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.message ?? '暂不支持该文件来源')));
    return;
  }
  if (!context.mounted) return;
  final config = model.config;
  if (config == null) return;
  final paths = config.localMusicPaths.contains(resolved)
      ? config.localMusicPaths
      : [...config.localMusicPaths, resolved];
  await model.updateConfig(
    (current) => current.copyWith(localMusicPaths: paths),
  );
  await model.scanLocal(paths: paths);
}

Future<String?> _manualFileDialog(BuildContext context) async {
  final controller = TextEditingController();
  final path = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('添加本地音乐文件'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '文件绝对路径',
          hintText: '/home/用户名/Music/歌曲.flac',
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
          child: const Text('导入并扫描'),
        ),
      ],
    ),
  );
  controller.dispose();
  return path;
}

Future<String?> _manualPathDialog(BuildContext context) async {
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

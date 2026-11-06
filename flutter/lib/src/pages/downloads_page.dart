/// 下载页：任务列表表格（§4.8）——不做小卡片仪表盘。
///
/// - 表格列：歌曲（封面+标题+歌手）/ 音质 / 状态与进度 / 操作；
/// - 按钮按任务真实状态变化：进行中可取消、失败可重试；「暂停」「打开/
///   定位」后端没有对应命令，按钮禁用并解释原因，不允许点击后无动作；
/// - [全部/进行中/已完成/失败] 筛选 + 清除已完成；
/// - 失败原因用后端返回的中文文案直接展示，缺省回退到状态名。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/design_tokens.dart';
import '../widgets/cover_image.dart';
import '../widgets/empty_state.dart' show EmptyState, pageTitle;

/// 后端任务状态 → 界面文案（不再把英文枚举直接抛给用户）。
String downloadStateLabel(String state) => switch (state) {
  'queued' => '排队中',
  'downloading' || 'active' => '下载中',
  'completed' => '已完成',
  'failed' => '失败',
  'cancelled' => '已取消',
  'skipped' => '已跳过',
  _ => state,
};

/// 任务是否属于「进行中」分组（排队/下载中）。
bool downloadTaskActive(bridge.DownloadTaskDto task) =>
    task.active || task.state == 'queued' || task.state == 'downloading';

/// 任务是否属于「已完成」分组（含已跳过——文件已存在）。
bool downloadTaskCompleted(bridge.DownloadTaskDto task) =>
    task.state == 'completed' || task.state == 'skipped';

/// 任务是否属于「失败」分组（含手动取消——需要重试入口）。
bool downloadTaskFailed(bridge.DownloadTaskDto task) =>
    task.state == 'failed' || task.state == 'cancelled';

/// 一行任务的可用操作（§4.8：按真实状态映射；后端无命令的一律 false）。
class DownloadRowOps {
  /// 暂停下载；后端没有暂停命令，恒为 false。
  final bool canPause;

  /// 取消任务；进行中（排队/下载中）可用。
  final bool canCancel;

  /// 重试；失败/取消可用（复用任务内歌曲载荷重新入队）。
  final bool canRetry;

  /// 打开文件/定位；后端没有文件管理器命令，恒为 false。
  final bool canOpenFile;

  const DownloadRowOps({
    required this.canPause,
    required this.canCancel,
    required this.canRetry,
    required this.canOpenFile,
  });
}

/// 状态 → 操作映射（纯函数，便于测试与后续接入新命令）。
DownloadRowOps downloadRowOpsFor(bridge.DownloadTaskDto task) {
  if (downloadTaskActive(task)) {
    // 暂停无命令：禁用占位并说明。
    return const DownloadRowOps(
      canPause: false,
      canCancel: true,
      canRetry: false,
      canOpenFile: false,
    );
  }
  if (downloadTaskFailed(task)) {
    return const DownloadRowOps(
      canPause: false,
      canCancel: false,
      canRetry: true,
      canOpenFile: false,
    );
  }
  // 已完成/已跳过：打开/定位后端无命令，禁用占位并说明。
  return const DownloadRowOps(
    canPause: false,
    canCancel: false,
    canRetry: false,
    canOpenFile: false,
  );
}

/// 失败原因文案：后端 message 优先（中文），缺省回退到状态名。
String downloadFailureText(bridge.DownloadTaskDto task) {
  final error = task.error?.trim();
  if (error != null && error.isNotEmpty) return error;
  return downloadStateLabel(task.state);
}

enum _Filter { all, active, completed, failed }

class DownloadsPage extends StatefulWidget {
  final AppModel model;

  const DownloadsPage(this.model, {super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  _Filter _filter = _Filter.all;

  AppModel get _model => widget.model;

  List<bridge.DownloadTaskDto> get _tasks => _model.state.downloads;

  List<bridge.DownloadTaskDto> get _filteredTasks {
    final tasks = _tasks;
    return switch (_filter) {
      _Filter.all => tasks,
      _Filter.active => tasks.where(downloadTaskActive).toList(),
      _Filter.completed => tasks.where(downloadTaskCompleted).toList(),
      _Filter.failed => tasks.where(downloadTaskFailed).toList(),
    };
  }

  bool get _hasFinished =>
      _tasks.any((task) => !downloadTaskActive(task));

  int _count(bool Function(bridge.DownloadTaskDto) predicate) =>
      _tasks.where(predicate).length;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final tasks = _tasks;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(child: pageTitle(context, '下载')),
                  Tooltip(
                    message: _hasFinished ? '移除已完成/失败/取消的任务记录' : '暂无可清理的任务',
                    child: TextButton(
                      onPressed: _hasFinished
                          ? () => _model.dispatch(
                                const bridge.FfiCommand.downloadClearFinished(),
                              )
                          : null,
                      child: const Text('清除已完成'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<_Filter>(
                      segments: [
                        ButtonSegment(
                          value: _Filter.all,
                          label: Text('全部 ${tasks.length}'),
                        ),
                        ButtonSegment(
                          value: _Filter.active,
                          label: Text('进行中 ${_count(downloadTaskActive)}'),
                        ),
                        ButtonSegment(
                          value: _Filter.completed,
                          label: Text('已完成 ${_count(downloadTaskCompleted)}'),
                        ),
                        ButtonSegment(
                          value: _Filter.failed,
                          label: Text('失败 ${_count(downloadTaskFailed)}'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (value) =>
                          setState(() => _filter = value.first),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _tableHeader(context),
            const Divider(height: 1),
            Expanded(child: _table(context)),
          ],
        );
      },
    );
  }

  Widget _tableHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VxTypography.caption.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 44),
          Expanded(flex: 4, child: Text('歌曲', style: style)),
          SizedBox(width: 56, child: Text('音质', style: style)),
          Expanded(flex: 3, child: Text('状态 / 进度', style: style)),
          SizedBox(width: _opsWidth, child: Text('操作', style: style)),
        ],
      ),
    );
  }

  static const double _opsWidth = 140;

  Widget _table(BuildContext context) {
    final tasks = _filteredTasks;
    if (tasks.isEmpty) {
      return _empty(context);
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: tasks.length,
      itemBuilder: (context, index) => _TaskRow(
        model: _model,
        task: tasks[index],
        opsWidth: _opsWidth,
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final filtered = _filter != _Filter.all;
    return EmptyState(
      icon: Icons.download_outlined,
      title: filtered ? '该分组下没有任务' : '暂无下载任务',
      subtitle: filtered
          ? '切换筛选查看其他任务'
          : '在歌曲行点下载按钮开始；下载目录与音质在设置页调整',
    );
  }
}

class _TaskRow extends StatelessWidget {
  final AppModel model;
  final bridge.DownloadTaskDto task;
  final double opsWidth;

  const _TaskRow({
    required this.model,
    required this.task,
    required this.opsWidth,
  });

  DownloadRowOps get _ops => downloadRowOpsFor(task);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: CoverImage(url: task.song.coverUrl, size: 40, radius: 6),
          ),
          const SizedBox(width: VxSpacing.sm),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VxTypography.titleSm.copyWith(color: scheme.onSurface),
                ),
                Text(
                  task.singer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VxTypography.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              task.quality,
              style: VxTypography.mono.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: VxSpacing.md),
          Expanded(flex: 3, child: _status(context)),
          const SizedBox(width: VxSpacing.md),
          SizedBox(width: opsWidth, child: _operations(context)),
        ],
      ),
    );
  }

  Widget _status(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final success =
        Theme.of(context).brightness == Brightness.dark
            ? VxColors.success
            : VxLightColors.success;
    final total = task.total?.toInt() ?? 0;
    final downloaded = task.downloaded.toInt();
    final hasProgress = total > 0;
    final failed = downloadTaskFailed(task);
    final completed = downloadTaskCompleted(task);
    final label = failed
        ? '失败 · ${downloadFailureText(task)}'
        : downloadStateLabel(task.state);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: VxTypography.caption.copyWith(
                  color: failed
                      ? scheme.error
                      : completed
                          ? success
                          : scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (hasProgress && !completed && !failed) ...[
              const SizedBox(width: 8),
              Text(
                '${downloaded * 100 ~/ total}%',
                style: VxTypography.mono.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            minHeight: 4,
            value: hasProgress ? (downloaded / total).clamp(0.0, 1.0) : null,
            color: failed
                ? scheme.error
                : completed
                    ? success
                    : scheme.primary,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _operations(BuildContext context) {
    final ops = _ops;
    // §4.8：按钮按任务状态变化——只渲染与当前状态相关的操作；
    // 后端无命令的（暂停/打开/定位）禁用占位并说明。
    final buttons = <Widget>[
      if (downloadTaskActive(task)) ...[
        _opButton(
          context,
          icon: Icons.pause_circle_outline,
          label: '暂停',
          tooltip: '后端暂不支持暂停下载',
          onPressed: ops.canPause ? () {} : null,
        ),
        _opButton(
          context,
          icon: Icons.cancel_outlined,
          label: '取消',
          tooltip: '取消该下载任务',
          onPressed: ops.canCancel
              ? () => model.dispatch(
                    bridge.FfiCommand.downloadCancel(id: task.id),
                  )
              : null,
        ),
      ] else if (downloadTaskFailed(task)) ...[
        _opButton(
          context,
          icon: Icons.refresh,
          label: '重试',
          tooltip: '重新排队下载',
          onPressed: ops.canRetry
              ? () => model.dispatch(
                    bridge.FfiCommand.downloadEnqueue(song: task.song),
                  )
              : null,
        ),
      ] else ...[
        _opButton(
          context,
          icon: Icons.folder_open_outlined,
          label: '打开',
          tooltip: '后端暂不支持从界面打开文件',
          onPressed: ops.canOpenFile ? () {} : null,
        ),
        _opButton(
          context,
          icon: Icons.travel_explore_outlined,
          label: '定位',
          tooltip: '后端暂不支持在文件管理器中定位',
          onPressed: ops.canOpenFile ? () {} : null,
        ),
      ],
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: buttons,
    );
  }

  Widget _opButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(0, 32),
          textStyle: const TextStyle(fontSize: 12),
        ),
        icon: Icon(icon, size: 15),
        label: Text(label),
      ),
    );
  }
}

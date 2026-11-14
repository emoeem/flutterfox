/// 手机下载页（计划书 C-03，指南 §5.5：下载管理的手机档布局）。
///
/// 布局：页首标题「下载」（含「清除已完成」）→ 状态筛选 chips（单行横滚，
/// 全部/进行中/已完成/失败，分组判定与桌面同一出处 downloads_page.dart 的
/// downloadTaskActive/Completed/Failed 纯函数）→ 任务卡片列表。
///
/// - 任务卡（竖排，360 视口无溢出）：封面 + 标题/歌手 + 音质 + 状态标签 →
///   进度条（进行中任务）→ 字节/速度行 → 操作行 → 失败原因可展开区；
/// - 操作走 AppModel 既有下载命令（暂停/继续/取消/重试/删除），状态→操作
///   映射复用桌面 [downloadRowOpsFor]（单一出处，不允许第二份映射）；
///   删除带二次确认（§9 破坏性操作）；「打开/定位」后端无命令，如实禁用；
/// - 失败原因展开显示完整 message（桌面行内 Flexible+ellipsis 会截断为
///   「失败 · 音频…」，手机档展开区不截断——软换行完整直出后端文案）；
/// - 已收字节 > 声明总量（后端数据倒挂）时进度条钳 0..1、字节如实原样
///   显示（不伪造「一致」的数字）；
/// - 无自带 Scaffold：直接作为 MobileShell body（inset 契约见
///   shell/android_insets.dart——状态栏由 AppBar 消费、导航条由
///   bottomNavigationBar 消费，滚动区不加第二份）；
/// - 触控目标 ≥48dp（操作按钮最小高 48、chips 含上下触控余量）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/design_tokens.dart';
import '../nav_bus.dart' as nav_bus;
import '../theme/app_theme.dart' show VxPalette;
import '../widgets/cover_image.dart';
import '../widgets/empty_state.dart' show EmptyState;
import 'downloads_page.dart'
    show
        downloadFailureText,
        downloadFormatBytes,
        downloadRowOpsFor,
        downloadStateLabel,
        downloadTaskActive,
        downloadTaskCompleted,
        downloadTaskFailed;

/// 筛选档（与桌面下载页同语义；分组判定复用同一纯函数）。
enum _MobileDownloadFilter { all, active, completed, failed }

class MobileDownloadsPage extends StatefulWidget {
  final AppModel model;

  const MobileDownloadsPage(this.model, {super.key});

  @override
  State<MobileDownloadsPage> createState() => _MobileDownloadsPageState();
}

class _MobileDownloadsPageState extends State<MobileDownloadsPage> {
  _MobileDownloadFilter _filter = _MobileDownloadFilter.all;

  /// 失败原因展开中的任务 id（§5.5：失败原因完整可查，默认折叠省纵向空间）。
  final Set<BigInt> _expandedErrors = {};

  /// 速度差分样本：任务 id → (上次快照字节数, 采样时刻)。与桌面下载页
  /// 同一算法（快照差分；无差分数据不显示，§5.11「有数据才显示」）。
  final Map<BigInt, (int, DateTime)> _samples = {};

  AppModel get _model => widget.model;

  List<bridge.DownloadTaskDto> get _tasks => _model.state.downloads;

  List<bridge.DownloadTaskDto> get _filteredTasks {
    final tasks = _tasks;
    return switch (_filter) {
      _MobileDownloadFilter.all => tasks,
      _MobileDownloadFilter.active => tasks.where(downloadTaskActive).toList(),
      _MobileDownloadFilter.completed =>
        tasks.where(downloadTaskCompleted).toList(),
      _MobileDownloadFilter.failed => tasks.where(downloadTaskFailed).toList(),
    };
  }

  bool get _hasFinished => _tasks.any((task) => !downloadTaskActive(task));

  int _count(bool Function(bridge.DownloadTaskDto) predicate) =>
      _tasks.where(predicate).length;

  /// 由前后两次快照差分出下载速度；无增长或样本不足时返回 null（桌面同源）。
  String? _speedFor(bridge.DownloadTaskDto task) {
    if (task.state != 'downloading' && task.state != 'resolving') return null;
    final now = DateTime.now();
    final current = task.downloaded.toInt();
    final previous = _samples[task.id];
    _samples[task.id] = (current, now);
    if (previous == null) return null;
    final (previousBytes, previousAt) = previous;
    final milliseconds = now.difference(previousAt).inMilliseconds;
    if (milliseconds <= 0) return null;
    final bytesPerSecond = (current - previousBytes) * 1000 / milliseconds;
    if (bytesPerSecond <= 1) return null;
    return '${downloadFormatBytes(bytesPerSecond)}/s';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final tasks = _filteredTasks;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _head(context),
            const SizedBox(height: VxSpacing.md),
            _filterChips(context),
            const SizedBox(height: VxSpacing.md),
            if (tasks.isEmpty)
              _empty(context)
            else
              for (final task in tasks) ...[
                _TaskCard(
                  model: _model,
                  task: task,
                  speedText: _speedFor(task),
                  errorExpanded: _expandedErrors.contains(task.id),
                  onToggleError: () => setState(() {
                    if (!_expandedErrors.remove(task.id)) {
                      _expandedErrors.add(task.id);
                    }
                  }),
                ),
                const SizedBox(height: VxSpacing.md),
              ],
          ],
        );
      },
    );
  }

  Widget _head(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            '下载',
            style: VxTypography.h2.copyWith(color: scheme.onSurface),
          ),
        ),
        TextButton(
          onPressed: _hasFinished
              ? () => _model.dispatch(
                  const bridge.FfiCommand.downloadClearFinished(),
                )
              : null,
          child: const Text('清除已完成'),
        ),
      ],
    );
  }

  /// 状态筛选 chips：全部/进行中/已完成/失败（带计数），单行横滚；
  /// 判定与桌面下载页同一出处（§5.5 筛选语义不另起一份）。
  Widget _filterChips(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget chip(_MobileDownloadFilter value, String label) {
      final selected = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: VxSpacing.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setState(() => _filter = value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.14)
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? scheme.primary : Colors.transparent,
                ),
              ),
              child: Text(
                label,
                style: VxTypography.caption.copyWith(
                  color: selected ? scheme.primary : scheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      key: const ValueKey('mobile-downloads-filters'),
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip(_MobileDownloadFilter.all, '全部 ${_tasks.length}'),
          chip(
            _MobileDownloadFilter.active,
            '进行中 ${_count(downloadTaskActive)}',
          ),
          chip(
            _MobileDownloadFilter.completed,
            '已完成 ${_count(downloadTaskCompleted)}',
          ),
          chip(
            _MobileDownloadFilter.failed,
            '失败 ${_count(downloadTaskFailed)}',
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    if (_filter != _MobileDownloadFilter.all) {
      return const EmptyState(
        icon: Icons.download_outlined,
        title: '该分组下没有任务',
        subtitle: '切换筛选查看其他任务',
      );
    }
    // §5.11：空态给出去处——发现页找歌下载、设置页管理下载目录
    //（手机壳同样消费 navRequest：3 → 发现、7 → 设置）。
    return EmptyState(
      icon: Icons.download_outlined,
      title: '暂无下载任务',
      subtitle: '在歌曲行点下载按钮开始；下载目录与音质在设置页调整',
      action: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => nav_bus.navRequest.value = 3,
            icon: const Icon(Icons.explore_outlined, size: 16),
            label: const Text('去发现音乐'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => nav_bus.navRequest.value = 7,
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: const Text('管理下载目录'),
          ),
        ],
      ),
    );
  }
}

/// 单张任务卡（竖排布局，360 视口不横溢）。
class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.model,
    required this.task,
    required this.errorExpanded,
    required this.onToggleError,
    this.speedText,
  });

  final AppModel model;
  final bridge.DownloadTaskDto task;

  /// 失败原因是否展开（展开显示完整 message，不截断）。
  final bool errorExpanded;
  final VoidCallback onToggleError;

  /// 下载速度文案（页面态差分；无数据为 null 不显示）。
  final String? speedText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final success = VxPalette.of(context).success;
    final failed = downloadTaskFailed(task);
    final completed = downloadTaskCompleted(task);
    final statusColor = failed
        ? scheme.error
        : completed
        ? success
        : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(VxSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(VxRadius.lg),
        border: Border.all(color: scheme.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverImage(url: task.song.coverUrl, size: 44, radius: 8),
              const SizedBox(width: VxSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VxTypography.titleSm.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (task.singer.isNotEmpty) task.singer,
                        task.quality,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VxTypography.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: VxSpacing.sm),
              _StatusTag(
                label: downloadStateLabel(task.state),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: VxSpacing.md),
          _progress(context, statusColor: statusColor),
          const SizedBox(height: VxSpacing.xs),
          _bytesRow(context),
          const SizedBox(height: VxSpacing.xs),
          _operations(context),
          if (failed && downloadFailureText(task).isNotEmpty)
            _failureDetail(context),
        ],
      ),
    );
  }

  /// 进度条：进行中/暂停显示；value 钳 0..1（后端字节倒挂时不越界，
  /// 字节行仍如实原样显示两侧数字）。
  Widget _progress(BuildContext context, {required Color statusColor}) {
    final scheme = Theme.of(context).colorScheme;
    final total = task.total?.toInt() ?? 0;
    final downloaded = task.downloaded.toInt();
    final hasProgress = total > 0;
    final done = downloadTaskCompleted(task);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        minHeight: 4,
        value: hasProgress ? (downloaded / total).clamp(0.0, 1.0) : null,
        color: done ? statusColor : scheme.primary,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
    );
  }

  /// 字节行（§5.11 有数据才显示）：`downloaded / total` 原样 +
  /// 瞬时速度；Wrap 布局防 360 视口长文案溢出。
  Widget _bytesRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = VxTypography.mono.copyWith(
      fontSize: 11,
      color: scheme.onSurfaceVariant,
    );
    final total = task.total?.toInt() ?? 0;
    final downloaded = task.downloaded.toInt();
    final hasProgress = total > 0;
    final parts = <String>[
      ?speedText,
      if (hasProgress)
        '${downloadFormatBytes(downloaded)} / ${downloadFormatBytes(total)}',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: VxSpacing.sm,
      runSpacing: 2,
      children: [for (final part in parts) Text(part, style: style)],
    );
  }

  /// 操作行：按真实状态映射（downloadRowOpsFor 单一出处）；触控目标
  /// 高 ≥48dp（§5.9）；删除走二次确认；打开/定位后端无命令禁用占位。
  Widget _operations(BuildContext context) {
    final ops = downloadRowOpsFor(task);
    final active = downloadTaskActive(task) && task.state != 'paused';
    final paused = task.state == 'paused';
    final failed = downloadTaskFailed(task);

    final buttons = <Widget>[
      if (active) ...[
        _opButton(
          context,
          icon: Icons.pause_circle_outline,
          label: '暂停',
          tooltip: '暂停下载（保留已下载部分）',
          onPressed: ops.canPause ? () => model.downloadPause(task.id) : null,
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
      ] else if (paused) ...[
        _opButton(
          context,
          icon: Icons.play_circle_outline,
          label: '继续',
          tooltip: '继续下载（同源断点续传）',
          onPressed: ops.canResume ? () => model.downloadResume(task.id) : null,
        ),
        _opButton(
          context,
          icon: Icons.cancel_outlined,
          label: '取消',
          tooltip: '取消并作废该任务（清除暂存文件）',
          onPressed: ops.canCancel
              ? () => model.dispatch(
                  bridge.FfiCommand.downloadCancel(id: task.id),
                )
              : null,
        ),
      ] else if (failed) ...[
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
      ] else if (downloadTaskCompleted(task)) ...[
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
        _opButton(
          context,
          icon: Icons.delete_outline,
          label: '删除',
          tooltip: '删除本地文件并清除下载记录',
          onPressed: ops.canDelete ? () => _confirmDelete(context) : null,
        ),
      ],
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: VxSpacing.xs, children: buttons);
  }

  /// 失败原因可展开区：折叠时是「失败原因」开关行（含展开指示），展开后
  /// 完整直出后端 message（软换行，不截断——桌面行内会截成「失败 · 音频…」，
  /// 手机档给全量）。
  Widget _failureDetail(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = downloadFailureText(task);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(VxRadius.sm),
          onTap: onToggleError,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 14, color: scheme.error),
                const SizedBox(width: VxSpacing.xs),
                Text(
                  '失败原因',
                  style: VxTypography.caption.copyWith(color: scheme.error),
                ),
                Icon(
                  errorExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: scheme.error,
                ),
              ],
            ),
          ),
        ),
        if (errorExpanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(VxSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(VxRadius.sm),
            ),
            child: Text(
              message,
              softWrap: true,
              style: VxTypography.body.copyWith(
                fontSize: 12,
                color: scheme.onErrorContainer,
              ),
            ),
          ),
      ],
    );
  }

  /// 删除二次确认（§9 对话框模式，文案与桌面下载页同语义）：写明删文件 +
  /// 清记录 + 回落在线播放。
  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除下载文件'),
        content: Text(
          '将删除「${task.name}」的本地文件并清除下载记录；'
          '已加入播放列表的歌曲将回落在线播放。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(
                dialogContext,
              ).colorScheme.onErrorContainer,
              backgroundColor: Theme.of(
                dialogContext,
              ).colorScheme.errorContainer,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await model.downloadDeleteFile(task.id);
  }

  /// 操作按钮：紧凑图标+文字，触控目标最小高 48（§5.9）。
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
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}

/// 状态标签（小胶囊，语义色随状态）。
class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: VxTypography.caption.copyWith(color: color, fontSize: 11),
      ),
    );
  }
}

/// 账号歌单同步对话框：只读预览 → 写入本地镜像 → 结果回显。
///
/// 同步方向是「远端 → 本地缓存」，不修改远端账号；失败/取消都在
/// 对话框内收口，不弹额外页面。状态全部来自 [AppModel]（syncPhase 等），
/// 事件由 Rust 侧 `sync` 事件流推进。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';

/// 打开同步对话框；调用方负责确认 source 是镜像平台（wy/tx）。
Future<void> showSyncDialog(
  BuildContext context,
  AppModel model,
  String source,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SyncDialog(model: model, source: source),
  );
}

class _SyncDialog extends StatefulWidget {
  final AppModel model;
  final String source;

  const _SyncDialog({required this.model, required this.source});

  @override
  State<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<_SyncDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.model.startSyncPreview(widget.source);
    });
  }

  AppModel get _model => widget.model;

  void _close() {
    _model.resetSync();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final phase = _model.syncPhase;
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.cloud_sync_outlined, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text('同步账号歌单 · ${widget.source.toUpperCase()}')),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(child: _body(context, phase)),
          ),
          actions: _actions(phase),
        );
      },
    );
  }

  Widget _body(BuildContext context, String phase) {
    switch (phase) {
      case 'idle':
      case 'previewing':
        return const _Busy(label: '正在读取远端歌单…');
      case 'preview':
        final preview = _model.syncPreview;
        if (preview == null) return const _Busy(label: '正在读取远端歌单…');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '远端 ${preview.playlists} 个歌单 · ${preview.favorites} 个红心 · '
              '${preview.songs} 首歌曲',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '预计新增 ${preview.added} · 更新 ${preview.updated} · '
              '移除 ${preview.removed}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (preview.rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              _RowList(
                rows: [
                  for (final row in preview.rows)
                    (
                      name: row.name,
                      detail:
                          '${row.kind} · 缓存 ${row.cached} / 远端 ${row.remote}',
                      status: row.status,
                    ),
                ],
              ),
            ],
            if (preview.failures.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Failures(
                items: [
                  for (final failure in preview.failures)
                    '${failure.name}：${failure.reason}',
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '确认后写入本地镜像缓存，不会修改远端账号。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      case 'running':
        final total = _model.syncTotal;
        final done = _model.syncDone;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: total > 0 ? (done / total).clamp(0, 1) : null,
            ),
            const SizedBox(height: 12),
            Text(total > 0 ? '正在写入本地镜像… $done / $total' : '正在拉取并写入本地镜像…'),
          ],
        );
      case 'done':
        final report = _model.syncReport;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ResultLine(icon: Icons.check_circle_outline, text: '同步完成'),
            const SizedBox(height: 8),
            if (report != null) ...[
              Text(
                '歌单 ${report.playlists} · 红心 ${report.favorites} · '
                '歌曲 ${report.songs}',
              ),
              const SizedBox(height: 4),
              Text(
                '新增 ${report.added} · 更新 ${report.updated} · '
                '移除 ${report.removed}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (report.failures.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Failures(
                  items: [
                    for (final failure in report.failures)
                      '${failure.name}：${failure.reason}',
                  ],
                ),
              ],
            ],
          ],
        );
      case 'cancelled':
        return const _ResultLine(icon: Icons.cancel_outlined, text: '同步已取消');
      case 'failed':
      default:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ResultLine(icon: Icons.error_outline, text: '同步失败'),
            const SizedBox(height: 8),
            Text(_model.syncError ?? '未知错误'),
            const SizedBox(height: 8),
            Text(
              '请确认已在「设置 → 扫码登录」登录对应平台后重试。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
    }
  }

  List<Widget> _actions(String phase) {
    switch (phase) {
      case 'idle':
      case 'previewing':
        return [TextButton(onPressed: _close, child: const Text('关闭'))];
      case 'preview':
        return [
          TextButton(onPressed: _close, child: const Text('取消')),
          FilledButton(
            onPressed: _model.startSyncRun,
            child: const Text('开始同步'),
          ),
        ];
      case 'running':
        return [
          TextButton(onPressed: _model.cancelSync, child: const Text('取消同步')),
        ];
      case 'done':
        return [FilledButton(onPressed: _close, child: const Text('完成'))];
      default:
        return [
          TextButton(onPressed: _close, child: const Text('关闭')),
          FilledButton(
            onPressed: () => _model.startSyncPreview(widget.source),
            child: const Text('重试'),
          ),
        ];
    }
  }
}

class _Busy extends StatelessWidget {
  final String label;

  const _Busy({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

class _ResultLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ResultLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

/// 预览明细：名称 + 缓存/远端数 + 状态；限高滚动。
class _RowList extends StatelessWidget {
  /// (名称, 明细, 状态)
  final List<({String name, String detail, String status})> rows;

  const _RowList({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        row.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  row.status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Failures extends StatelessWidget {
  final List<String> items;

  const _Failures({required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '部分歌单未取到（保留旧缓存）：',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.error),
        ),
        const SizedBox(height: 4),
        for (final item in items.take(6))
          Text(
            '· $item',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (items.length > 6)
          Text(
            '… 其余 ${items.length - 6} 条',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

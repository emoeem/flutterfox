library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;

Future<void> showPushDialog(
  BuildContext context,
  AppModel model, {
  required String localName,
  required List<bridge.SongDto> songs,
  required bool isFavorites,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PushDialog(
      model: model,
      localName: localName,
      songs: songs,
      isFavorites: isFavorites,
    ),
  );
}

class _PushDialog extends StatefulWidget {
  final AppModel model;
  final String localName;
  final List<bridge.SongDto> songs;
  final bool isFavorites;

  const _PushDialog({
    required this.model,
    required this.localName,
    required this.songs,
    required this.isFavorites,
  });

  @override
  State<_PushDialog> createState() => _PushDialogState();
}

class _PushDialogState extends State<_PushDialog> {
  static const _sources = {'wy': '网易云', 'tx': 'QQ 音乐'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.model.startPushTargets('wy');
    });
  }

  AppModel get _model => widget.model;

  void _close() {
    if (_model.pushPhase == 'running') _model.cancelPush();
    _model.resetPush();
    Navigator.of(context).pop();
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建远端歌单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: '歌单名称'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    await _model.createPushTarget(name);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _model,
      builder: (context, _) {
        final source = _model.pushSource ?? 'wy';
        final phase = _model.pushPhase;
        return AlertDialog(
          title: Text(widget.isFavorites ? '推送收藏' : '推送「${widget.localName}」'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: [
                      for (final entry in _sources.entries)
                        ButtonSegment(
                          value: entry.key,
                          label: Text(entry.value),
                        ),
                    ],
                    selected: {source},
                    onSelectionChanged: (value) {
                      _model.startPushTargets(value.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  _body(phase),
                ],
              ),
            ),
          ),
          actions: _actions(phase),
        );
      },
    );
  }

  Widget _body(String phase) {
    switch (phase) {
      case 'idle':
      case 'loading_targets':
      case 'creating_target':
      case 'planning':
        return _Busy(
          label: switch (phase) {
            'creating_target' => '正在创建远端歌单…',
            'planning' => '正在计算追加内容…',
            _ => '正在读取远端目标…',
          },
        );
      case 'targets':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('本地 ${widget.songs.length} 首歌曲，选择推送目标'),
            const SizedBox(height: 8),
            if (_model.pushTargets.isEmpty)
              const Text('没有可用目标，可以先创建远端歌单。')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _model.pushTargets.length,
                  itemBuilder: (context, index) {
                    final target = _model.pushTargets[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        target.kind == 'favorites'
                            ? Icons.favorite_border
                            : Icons.queue_music,
                      ),
                      title: Text(target.name),
                      subtitle: Text(
                        '${target.kind == 'favorites' ? '红心' : '歌单'} · ${target.songCount} 首',
                      ),
                      onTap: widget.songs.isEmpty
                          ? null
                          : () => _model.previewPush(
                              localName: widget.localName,
                              songs: widget.songs,
                              isFavorites: widget.isFavorites,
                              target: target,
                            ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _createPlaylist,
              icon: const Icon(Icons.add),
              label: const Text('新建远端歌单'),
            ),
          ],
        );
      case 'preview':
        final preview = _model.pushPreview;
        if (preview == null) return const _Busy(label: '正在计算追加内容…');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${preview.targetName} · ${preview.targetKind}'),
            const SizedBox(height: 8),
            Text('本地 ${preview.localSongs} 首 · 远端已有 ${preview.remoteSongs} 首'),
            Text('将追加 ${preview.additions} 首 · 已匹配 ${preview.matched} 首'),
            if (preview.unmatched > 0) Text('未匹配 ${preview.unmatched} 首，将跳过'),
            if (preview.samples.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('待追加'),
              for (final sample in preview.samples.take(8))
                Text('· $sample', maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 12),
            Text(
              '只会向远端追加歌曲，不会删除目标中已有内容。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      case 'running':
        final total = _model.pushTotal;
        final done = _model.pushDone;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: total > 0 ? (done / total).clamp(0, 1) : null,
            ),
            const SizedBox(height: 12),
            Text(total > 0 ? '正在推送… $done / $total' : '正在准备推送…'),
          ],
        );
      case 'done':
        final report = _model.pushReport;
        if (report == null) return const Text('推送已完成');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('已推送到「${report.targetName}」'),
            Text(
              '新增 ${report.added} · 已存在 ${report.alreadyPresent} · 未匹配 ${report.unmatched}',
            ),
            if (report.failed.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final failure in report.failed.take(8))
                Text(failure, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        );
      case 'cancelled':
        return const Text('推送已取消');
      case 'failed':
        return Text(_model.pushError ?? '推送失败');
      default:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _actions(String phase) {
    switch (phase) {
      case 'preview':
        return [
          TextButton(onPressed: _close, child: const Text('取消')),
          FilledButton(onPressed: _model.runPush, child: const Text('确认推送')),
        ];
      case 'running':
        return [
          TextButton(onPressed: _model.cancelPush, child: const Text('取消推送')),
        ];
      case 'done':
      case 'cancelled':
        return [FilledButton(onPressed: _close, child: const Text('完成'))];
      case 'failed':
        return [
          TextButton(onPressed: _close, child: const Text('关闭')),
          FilledButton(
            onPressed: () => _model.startPushTargets(_model.pushSource ?? 'wy'),
            child: const Text('重试'),
          ),
        ];
      default:
        return [TextButton(onPressed: _close, child: const Text('关闭'))];
    }
  }
}

class _Busy extends StatelessWidget {
  final String label;

  const _Busy({required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: 10),
      Text(label),
    ],
  );
}

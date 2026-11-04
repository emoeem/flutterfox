/// 自建歌单的通用输入与选择弹层。
///
/// 曲库页、详情页与歌曲行共用：名称输入（新建/重命名）和
/// 「加入歌单」选择器（含就地新建 + 立即加歌）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import 'cover_image.dart';

/// 弹出名称输入框；确认返回去空白后的名称，取消/空串返回 null。
Future<String?> promptCustomPlaylistName(
  BuildContext context, {
  String title = '新建歌单',
  String? initialName,
}) async {
  final controller = TextEditingController(text: initialName ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: '歌单名称', hintText: '例如：通勤'),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  controller.dispose();
  final trimmed = name?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// 选择目标自建歌单；`playlistId == null` 表示「新建歌单」。
class _AddTarget {
  final String? playlistId;
  final String? name;

  const _AddTarget.pick(this.playlistId, this.name);
  const _AddTarget.create() : playlistId = null, name = null;

  bool get create => playlistId == null;
}

/// 「加入歌单」弹层：列出自建歌单 + 新建入口。
///
/// 新建分支会等 `createCustomPlaylist` 拿回 id 后立即把 [songs] 加进去；
/// 任一步失败都用 SnackBar 回显 `model.lastNotification`。
Future<void> showAddToCustomPlaylistSheet(
  BuildContext context,
  AppModel model,
  List<bridge.SongDto> songs,
) async {
  if (songs.isEmpty) return;
  final target = await showModalBottomSheet<_AddTarget>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final playlists = model.state.customPlaylists;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  '加入歌单',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('新建歌单…'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(const _AddTarget.create()),
              ),
              const Divider(height: 1),
              if (playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('还没有自建歌单，先新建一个', textAlign: TextAlign.center),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        leading: CoverImage(
                          url: playlist.coverUrl,
                          size: 40,
                          icon: Icons.queue_music,
                        ),
                        title: Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('${playlist.songCount} 首'),
                        onTap: () => Navigator.of(
                          sheetContext,
                        ).pop(_AddTarget.pick(playlist.id, playlist.name)),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
  if (target == null || !context.mounted) return;

  if (!target.create) {
    final id = target.playlistId!;
    final name = target.name ?? '';
    await model.addToCustomPlaylist(id, songs);
    if (!context.mounted) return;
    _snack(context, '已加入「$name」');
    return;
  }

  final name = await promptCustomPlaylistName(context);
  if (name == null || !context.mounted) return;
  final id = await model.createCustomPlaylist(name);
  if (!context.mounted) return;
  if (id == null) {
    _snack(context, model.lastNotification ?? '新建歌单失败');
    return;
  }
  await model.addToCustomPlaylist(id, songs);
  if (!context.mounted) return;
  _snack(context, '已新建「$name」并加入 ${songs.length} 首');
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));
}

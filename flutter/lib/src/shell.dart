/// 应用外壳：自适应导航（手机底栏 / 桌面 rail）+ 底部 mini player。
/// 布局规格见 docs/flutter_ui_spec.md §1/§9。
library;

import 'package:flutter/material.dart';

import 'app_model.dart';
import 'pages/downloads_page.dart';
import 'pages/library_page.dart';
import 'pages/qr_login_page.dart';
import 'pages/queue_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';

class VoicefoxShell extends StatefulWidget {
  final AppModel model;

  const VoicefoxShell(this.model, {super.key});

  @override
  State<VoicefoxShell> createState() => _VoicefoxShellState();
}

class _VoicefoxShellState extends State<VoicefoxShell> {
  int _index = 0;

  static const _destinations = [
    (Icons.queue_music_outlined, '队列'),
    (Icons.search, '搜索'),
    (Icons.favorite_border, '收藏'),
    (Icons.download_outlined, '下载'),
    (Icons.settings_outlined, '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final wide = MediaQuery.sizeOf(context).width > 840;
    // 手机端第 5 项=更多（收纳扫码登录），桌面第 5 项=设置
    final page = switch ((_index, wide)) {
      (0, _) => QueuePage(model),
      (1, _) => SearchPage(model),
      (2, _) => LibraryPage(model),
      (3, _) => DownloadsPage(model),
      (4, true) => SettingsPage(model),
      (4, false) => const _MoreSheet(),
      (_, _) => QueuePage(model),
    };

    final body = Scaffold(
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) =>
                      setState(() => _index = value),
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Icon(Icons.graphic_eq),
                  ),
                  destinations: [
                    for (final item in _destinations)
                      NavigationRailDestination(
                        icon: Icon(item.$1),
                        label: Text(item.$2),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            )
          : page,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(
                    icon: Icon(item.$1),
                    label: item.$2,
                  ),
              ],
            ),
    );

    return Stack(
      children: [
        body,
        // mini player：规格见 flutter_ui_spec.md §9
        Positioned(
          left: wide ? 80 : 0,
          right: 0,
          bottom: wide ? 0 : 80,
          child: _MiniPlayer(
            model: model,
            onTap: () => setState(() => _index = 0),
          ),
        ),
      ],
    );
  }
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        ListTile(
          leading: const Icon(Icons.qr_code_scanner),
          title: const Text('扫码登录'),
          onTap: () {
            final shell = context.findAncestorStateOfType<_VoicefoxShellState>();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('扫码登录')),
                  body: QrLoginPage(shell!.widget.model),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  final AppModel model;
  final VoidCallback onTap;

  const _MiniPlayer({required this.model, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final song = model.state.playback.song;
    if (song == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: const Icon(Icons.music_note),
          title: Text(
            song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            song.singer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '上一首',
                onPressed: model.previous,
                icon: const Icon(Icons.skip_previous),
              ),
              IconButton(
                tooltip: '播放/暂停',
                onPressed: model.toggle,
                icon: Icon(
                  model.state.playback.state == 'playing'
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
              ),
              IconButton(
                tooltip: '下一首',
                onPressed: model.next,
                icon: const Icon(Icons.skip_next),
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

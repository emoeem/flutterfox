// Voicefox host for the player page (transitional entry).
// Newly written for voicefox, not vendored.
//
// Phase 2（§7.3 过渡入口）：不再把 vendored myune SongDetailPage 渲染为
// Voicefox 全屏播放器——该页自带窗口标题栏/队列 Drawer/播放控制区，与全局
// Header 和 PlayerBar 形成重复职责（计划书 §0.3、§3.3「禁止页面内部再自带
// 窗口控制」）。真正的 Voicefox NowPlayingPage 由 Phase 3 交付；在其落地前
// 本入口只渲染如实的过渡空态，不伪造播放控制。
//
// myune/page/song_detail_page.dart 本体冻结不动（§7.3），仅停止作为顶层
// 播放页引用。
import 'package:flutter/material.dart';

import '../app_model.dart';
import '../design_system/components/vx_empty_state.dart';

/// Set to false to fall back to voicefox's legacy player page.
const bool useMyunePlayer = true;

/// 过渡播放入口：Phase 3 NowPlayingPage 落地前的占位页。
///
/// 由 `pages/home_page.dart` 的正在播放 Hero 进入。播放控制在过渡期
/// 统一使用底部全局 PlayerBar 与右栏 ContextPanel。
class MyunePlayerPage extends StatelessWidget {
  const MyunePlayerPage({super.key, required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final song = model.state.playback.song;
    return Scaffold(
      appBar: AppBar(
        title: Text(song == null ? '正在播放' : '正在播放 · ${song.name}'),
      ),
      body: Center(
        child: VxEmptyState(
          icon: Icons.album_outlined,
          title: '全屏播放页重构中',
          message: song == null
              ? '当前没有正在播放的曲目。从搜索或曲库挑一首开始，播放控制可使用底部播放栏。'
              : '「${song.name}」正在播放。全屏播放页（封面/歌词/队列）将在 Phase 3 交付，当前可使用底部播放栏与右侧面板控制播放。',
        ),
      ),
    );
  }
}

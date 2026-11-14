/// 桌面首页（计划书 §4.1：音乐内容首页，不是统计仪表盘）。
///
/// 结构：问候 + 日期页头 → Continue Listening Hero（真实 `state.history` /
/// 当前播放曲目；无历史时切换「导入本地音乐 / 搜索在线音乐」引导）→
/// 最近播放封面书架（home_shared.dart [RecentShelf]，VxAlbumCard 横向）→
/// 我的歌单（VxPlaylistCard，真实 `state.customPlaylists`）→ 排行榜精选
/// （home_shared.dart [LeaderboardSection]，真实 leaderboard 榜单行卡）。
///
/// Phase 2：问候/日期纯函数、最近播放书架、排行榜精选提取共享
/// （home_shared.dart），手机 MobileHomePage 复用同一实现。
///
/// Phase 0 S1：旧版底部 6 大卡片快捷导航与工具统计卡片已删除；
/// 空态 / 加载态统一走 design_system 三态组件。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_empty_state.dart';
import '../design_system/components/vx_hero.dart';
import '../design_system/components/vx_playlist_card.dart';
import '../design_system/components/vx_section_header.dart';
import '../design_system/design_tokens.dart';
import '../nav_bus.dart';
import '../design_system/components/vx_artwork.dart';
import 'home_shared.dart';

class HomePage extends StatelessWidget {
  final AppModel model;

  const HomePage(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final history = model.state.history;
        final greeting = homeGreeting();
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            VxSpacing.pagePadding,
            VxSpacing.lg,
            VxSpacing.pagePadding,
            VxSpacing.xxl,
          ),
          children: [
            _PageHead(greeting: greeting, dateLabel: homeDateLabel()),
            const SizedBox(height: VxSpacing.lg),
            _ContinueHero(model: model, greeting: greeting),
            const SizedBox(height: VxSpacing.sectionGap),
            if (history.isNotEmpty) ...[
              RecentShelf(model: model, history: history),
              const SizedBox(height: VxSpacing.sectionGap),
            ],
            _MyPlaylistsSection(model: model),
            const SizedBox(height: VxSpacing.sectionGap),
            LeaderboardSection(model: model),
          ],
        );
      },
    );
  }
}

/// 页头：问候语（H1）+ 日期（弱色 caption），右侧不放工具开关（§4.1）。
class _PageHead extends StatelessWidget {
  final String greeting;
  final String dateLabel;

  const _PageHead({required this.greeting, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: VxTypography.h1.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: VxSpacing.xs),
        Text(
          dateLabel,
          style: VxTypography.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Continue Listening Hero：有内容时展示最近曲目，无历史时展示引导（§4.1）。
class _ContinueHero extends StatelessWidget {
  final AppModel model;
  final String greeting;

  const _ContinueHero({required this.model, required this.greeting});

  @override
  Widget build(BuildContext context) {
    final playbackSong = model.state.playback.song;
    final history = model.state.history;
    final bridge.SongDto? song =
        playbackSong ?? (history.isEmpty ? null : history.first);

    if (song == null) {
      return VxHero(
        eyebrow: '开始使用',
        title: greeting,
        description: '曲库还是空的：导入本地音乐，或搜索在线音乐开始收听。',
        // Hero 固定 178px 大封面：窄窗（<960）下文案区只有 ~260px，
        // 按钮用短文案避免溢出；完整引导写在说明行。
        primaryLabel: '搜索音乐',
        onPrimary: () => navRequest.value = 1,
        secondaryLabel: '导入本地',
        onSecondary: () => navRequest.value = 5,
        fallbackSeed: greeting,
      );
    }

    final playing = model.state.playback.state == 'playing';
    final album = song.albumName;
    final description = album.isEmpty ? song.singer : '${song.singer} · $album';
    return VxHero(
      eyebrow: 'CONTINUE LISTENING',
      title: song.name,
      description: description,
      // 正在播 ⇒ 暂停；否则继续播放（恢复当前曲目或播放最近一首）。
      primaryLabel: playing ? '暂停' : '继续播放',
      onPrimary: () => _resume(model, song, playing),
      cover: VxArtwork(
        url: song.coverUrl,
        source: song.source,
        entityType: 'song',
        entityId: song.id,
        entityName: song.name,
        size: 178,
        radius: 0,
        icon: Icons.music_note_outlined,
        allowRetry: false,
      ),
      fallbackSeed: song.name,
    );
  }

  void _resume(AppModel model, bridge.SongDto song, bool playing) {
    if (playing || model.state.playback.song != null) {
      model.toggle();
      return;
    }
    // 无播放上下文：把最近播放（含这首）作为队列起点。
    final queue = List<bridge.SongDto>.of(model.state.history);
    if (queue.isEmpty) {
      model.playSong(song);
      return;
    }
    model.playSongs(queue, index: 0);
  }
}

/// 我的歌单：真实 `state.customPlaylists`（本地自建歌单），点卡片进曲库。
class _MyPlaylistsSection extends StatelessWidget {
  final AppModel model;

  const _MyPlaylistsSection({required this.model});

  @override
  Widget build(BuildContext context) {
    final playlists = model.state.customPlaylists;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VxSectionHeader(title: '我的歌单', onViewAll: () => navRequest.value = 2),
        const SizedBox(height: VxSpacing.md),
        if (playlists.isEmpty)
          SizedBox(
            height: 280,
            child: VxEmptyState(
              icon: Icons.playlist_add,
              title: '还没有自建歌单',
              message: '在曲库页点「新建歌单」，或把喜欢的歌曲加入歌单。',
              actionLabel: '去曲库',
              onAction: () => navRequest.value = 2,
            ),
          )
        else
          SizedBox(
            height: 244,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: playlists.length.clamp(0, 12),
              separatorBuilder: (_, _) => const SizedBox(width: VxSpacing.md),
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return VxPlaylistCard(
                  title: playlist.name,
                  trackCount: playlist.songCount,
                  width: 156,
                  cover: VxArtwork(
                    url: playlist.coverUrl,
                    // 自建歌单是本地实体（CustomPlaylistSummaryDto 无 source
                    // 字段），缓存键固定 local 命名空间。
                    source: 'local',
                    entityType: 'playlist',
                    entityId: playlist.id,
                    entityName: playlist.name,
                    size: 156,
                    radius: 0,
                    icon: Icons.queue_music,
                    allowRetry: false,
                  ),
                  onTap: () => navRequest.value = 2,
                );
              },
            ),
          ),
      ],
    );
  }
}

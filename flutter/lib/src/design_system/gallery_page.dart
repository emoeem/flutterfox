/// UI Gallery：设计系统组件陈列页（Phase 1 任务 3，路由 `/dev/gallery`）。
///
/// 开发基建页：分组陈列 design_system 全部基础组件，支持深 / 浅主题
/// 预览切换。页内所有数据均为 **Gallery 样例**（静态展示），不代表真实
/// 业务数据；组件本身保持无状态，接入方在 Phase 2+ 传入真实数据与回调。
library;

import 'package:flutter/material.dart';

import 'components/vx_album_card.dart';
import 'components/vx_artist_card.dart';
import 'components/vx_empty_state.dart';
import 'components/vx_error_state.dart';
import 'components/vx_hero.dart';
import 'components/vx_loading_skeleton.dart';
import 'components/vx_player_controls.dart';
import 'components/vx_playlist_card.dart';
import 'components/vx_seek_bar.dart';
import 'components/vx_section_header.dart';
import 'components/vx_track_row.dart';
import 'design_tokens.dart';
import 'voicefox_theme.dart';

/// 组件陈列页。
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  /// 开发路由：`/dev/gallery`。
  static const routeName = '/dev/gallery';

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  bool _dark = true;
  bool _playing = true;
  bool _shuffleOn = false;
  bool _repeatOn = true;
  double _seek = 0.31;
  bool _unknownDuration = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _dark ? buildDarkTheme() : buildLightTheme(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Voicefox UI Gallery'),
              actions: [
                Text(_dark ? '深色预览' : '浅色预览', style: VxTypography.caption),
                Switch(
                  value: !_dark,
                  onChanged: (v) => setState(() => _dark = !v),
                ),
                const SizedBox(width: VxSpacing.md),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(VxSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _notice(),
                  const SizedBox(height: VxSpacing.sectionGap),
                  _section('色彩 Token（§6.2 + 概念稿）', _colors()),
                  _section('排版 Token（§6.3）', _typography()),
                  _section('SectionHeader 分区标题', _sectionHeaders()),
                  _section('TrackRow 三密度与状态', _trackRows()),
                  _section('AlbumCard / PlaylistCard / ArtistCard', _cards()),
                  _section(
                    'VxHero 首页 Hero',
                    VxHero(
                      eyebrow: 'CONTINUE LISTENING',
                      title: '让音乐继续',
                      description: '从最近播放的专辑、歌单或歌曲继续你的音乐旅程。',
                      primaryLabel: '继续播放',
                      onPrimary: () {},
                      secondaryLabel: '更多',
                      onSecondary: () {},
                    ),
                  ),
                  _section('空状态 / 加载骨架 / 错误状态', _states()),
                  _section('进度条与播放控制', _player()),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- sections

  Widget _notice() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(VxSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(VxRadius.md),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: scheme.primary),
          const SizedBox(width: VxSpacing.sm),
          Expanded(
            child: Text(
              '本页所有数据均为 Gallery 样例（静态展示），仅用于组件预览与视觉验收，'
              '不代表真实业务数据；真实数据与回调在 Phase 2+ 接入。',
              style: VxTypography.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VxSectionHeader(title: title, actions: const [_GalleryTag()]),
        const SizedBox(height: VxSpacing.lg),
        child,
        const SizedBox(height: VxSpacing.sectionGap),
      ],
    );
  }

  Widget _colors() {
    final scheme = Theme.of(context).colorScheme;
    const darkTokens = <(String, Color)>[
      ('background', VxColors.background),
      ('scrim', VxColors.scrim),
      ('surface1', VxColors.surface1),
      ('surface2', VxColors.surface2),
      ('surface3', VxColors.surface3),
      ('hover', VxColors.hover),
      ('divider', VxColors.divider),
      ('text-primary', VxColors.textPrimary),
      ('text-secondary', VxColors.textSecondary),
      ('text-muted', VxColors.textMuted),
      ('accent', VxColors.accent),
      ('accent2', VxColors.accentDeep),
      ('success', VxColors.success),
      ('warning', VxColors.warning),
      ('error', VxColors.error),
    ];
    const lightTokens = <(String, Color)>[
      ('background', VxLightColors.background),
      ('surface1', VxLightColors.surface1),
      ('surface2', VxLightColors.surface2),
      ('surface3', VxLightColors.surface3),
      ('hover', VxLightColors.hover),
      ('divider', VxLightColors.divider),
      ('text-primary', VxLightColors.textPrimary),
      ('text-secondary', VxLightColors.textSecondary),
      ('text-muted', VxLightColors.textMuted),
      ('accent', VxLightColors.accent),
      ('accent-deep', VxLightColors.accentDeep),
      ('success', VxLightColors.success),
      ('warning', VxLightColors.warning),
      ('error', VxLightColors.error),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('深色（VxColors）', style: VxTypography.title),
        const SizedBox(height: VxSpacing.md),
        Wrap(
          spacing: VxSpacing.md,
          runSpacing: VxSpacing.md,
          children: [
            for (final (name, color) in darkTokens)
              _swatch(scheme, name, color),
          ],
        ),
        const SizedBox(height: VxSpacing.lg),
        Text('浅色（VxLightColors，独立调校对比度）', style: VxTypography.title),
        const SizedBox(height: VxSpacing.md),
        Wrap(
          spacing: VxSpacing.md,
          runSpacing: VxSpacing.md,
          children: [
            for (final (name, color) in lightTokens)
              _swatch(scheme, name, color),
          ],
        ),
      ],
    );
  }

  Widget _swatch(ColorScheme scheme, String name, Color color) {
    final argb = color.toARGB32() & 0xFFFFFF;
    final hex = argb.toRadixString(16).padLeft(6, '0').toUpperCase();
    return Container(
      width: 168,
      padding: const EdgeInsets.all(VxSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(VxRadius.md),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: scheme.outline),
            ),
          ),
          const SizedBox(width: VxSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: VxTypography.caption.copyWith(color: scheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '#$hex',
                  style: vxMonoStyle(scheme.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typography() {
    final scheme = Theme.of(context).colorScheme;
    final samples = <(String, TextStyle)>[
      ('Display 36/700', VxTypography.display),
      ('H1 28/700', VxTypography.h1),
      ('H2 22/600', VxTypography.h2),
      ('SectionTitle 18/700', VxTypography.sectionTitle),
      ('Title 16/600', VxTypography.title),
      ('TitleSm 13/600', VxTypography.titleSm),
      ('Body 14/400', VxTypography.body),
      ('Caption 12/400', VxTypography.caption),
      ('Mono 12/500（tabular figures）', vxMonoStyle(scheme.onSurface)),
      ('Eyebrow 10/700', VxTypography.eyebrow),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, style) in samples) ...[
          Text(
            'Voicefox 让音乐继续 Aa 0123 — $label',
            style: style.copyWith(color: scheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: VxSpacing.md),
        ],
      ],
    );
  }

  Widget _sectionHeaders() {
    return Column(
      children: [
        VxSectionHeader(title: '最近播放', onViewAll: () {}),
        const SizedBox(height: VxSpacing.lg),
        VxSectionHeader(
          title: '为你收藏的歌单',
          eyebrow: 'PLAYLISTS',
          onViewAll: () {},
        ),
        const SizedBox(height: VxSpacing.lg),
        VxSectionHeader(title: '只有标题没有操作'),
      ],
    );
  }

  Widget _trackRows() {
    return Column(
      children: [
        VxTrackRow(
          index: 1,
          title: '夜空中最亮的星',
          artist: '逃跑计划',
          album: '世界',
          duration: const Duration(minutes: 4, seconds: 12),
          density: VxTrackRowDensity.compact,
          onPlay: () {},
          onAddToQueue: () {},
          onLike: () {},
          onMore: () {},
        ),
        VxTrackRow(
          index: 2,
          title: '这是一首特别特别长的中文歌曲标题用来验证播放态下省略号截断策略是否稳定且不破坏行高约束',
          artist: '长标题样例歌手',
          album: '长标题样例专辑',
          duration: const Duration(minutes: 3, seconds: 58),
          isPlaying: true,
          showIndex: false,
          cover: DecoratedBox(
            decoration: BoxDecoration(
              gradient: VxCoverGradients.forSeed('月光循环'),
              borderRadius: BorderRadius.circular(VxRadius.sm),
            ),
          ),
          onPlay: () {},
          onAddToQueue: () {},
          onLike: () {},
          onMore: () {},
        ),
        VxTrackRow(
          index: 3,
          title:
              'A Very Long English Track Title That Should Ellipsize Gracefully '
              'Without Breaking The Row Layout Constraints',
          artist: 'Sample Artist',
          album: 'Long English Album Name Also Ellipsized Gracefully',
          source: '本地音乐',
          duration: null,
          density: VxTrackRowDensity.comfortable,
          onPlay: () {},
          onAddToQueue: () {},
          onLike: () {},
          onMore: () {},
        ),
        VxTrackRow(
          index: 4,
          title: 'Blue Hour',
          artist: 'Aerial',
          album: 'Blue Hour EP',
          source: '网易云',
          duration: const Duration(minutes: 4, seconds: 21),
          isLiked: true,
          onPlay: () {},
          onAddToQueue: () {},
          onLike: () {},
          onMore: () {},
        ),
        const SizedBox(height: VxSpacing.sm),
        Text(
          '密度：50（紧凑）/ 58（标准）/ 66（舒适）；hover 出现行内操作；时长缺失显示 --:--',
          style: VxTypography.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _cards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VxAlbumCard(
            title: 'Afterglow',
            subtitle: 'The Midnight · 2024',
            onPlay: () {},
            onTap: () {},
          ),
          const SizedBox(width: VxSpacing.lg),
          VxAlbumCard(
            title: '这是一张专辑名字特别长的情况用来验证封面卡标题两行省略的显示效果是否稳定',
            subtitle: '样例歌手 · 2024',
            onPlay: () {},
          ),
          const SizedBox(width: VxSpacing.lg),
          VxPlaylistCard(
            title: '月光循环',
            trackCount: 12,
            source: '网易云',
            onPlay: () {},
            onTap: () {},
          ),
          const SizedBox(width: VxSpacing.lg),
          VxPlaylistCard(title: '深度专注', trackCount: 28, onPlay: () {}),
          const SizedBox(width: VxSpacing.lg),
          VxArtistCard(
            title: 'M83',
            subtitle: '32 张专辑',
            onPlay: () {},
            onTap: () {},
          ),
          const SizedBox(width: VxSpacing.lg),
          VxArtistCard(
            title: 'Nora En Pure',
            subtitle: '18 张专辑',
            shape: VxArtistCardShape.square,
            onPlay: () {},
          ),
        ],
      ),
    );
  }

  Widget _states() {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: VxSpacing.xl,
      runSpacing: VxSpacing.xl,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        SizedBox(
          width: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('空状态', style: VxTypography.title),
              const SizedBox(height: VxSpacing.md),
              SizedBox(
                height: 340,
                child: VxEmptyState(
                  title: '这里还没有歌曲',
                  message: '导入本地音乐或搜索在线内容后，歌曲会出现在这里。',
                  actionLabel: '导入本地音乐',
                  onAction: () {},
                  secondaryLabel: '去搜索',
                  onSecondaryAction: () {},
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('加载骨架（歌曲行 / 书架）', style: VxTypography.title),
              const SizedBox(height: VxSpacing.md),
              const VxLoadingSkeleton.tracks(rows: 3),
              const SizedBox(height: VxSpacing.lg),
              SizedBox(
                height: 220,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: VxSpacing.lg),
                        const SizedBox(
                          width: 150,
                          child: VxLoadingSkeleton.shelf(rows: 1),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('错误状态', style: VxTypography.title),
              const SizedBox(height: VxSpacing.md),
              SizedBox(
                height: 340,
                child: VxErrorState(
                  title: '加载失败',
                  message: '网络连接超时，请检查网络后重试。',
                  detail: 'SocketException: Connection timed out（Gallery 样例）',
                  onRetry: () {},
                  secondaryLabel: '检查网络设置',
                  onSecondaryAction: () {},
                ),
              ),
            ],
          ),
        ),
        Text(
          '说明与操作为真实下一步动作的占位文案，颜色语义：错误 ${scheme.error}。',
          style: VxTypography.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _player() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VxSeekRow(
          position: Duration(minutes: 1, seconds: 23),
          duration: Duration(minutes: 4, seconds: 32),
        ),
        const SizedBox(height: VxSpacing.md),
        const VxSeekRow(position: null, duration: null),
        const SizedBox(height: VxSpacing.lg),
        Row(
          children: [
            Text('Gallery 演示控制', style: VxTypography.caption),
            const SizedBox(width: VxSpacing.md),
            Switch(
              value: _unknownDuration,
              onChanged: (v) => setState(() => _unknownDuration = v),
            ),
            Text(
              '时长未知（--:--，不伪造进度）',
              style: VxTypography.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: VxSpacing.lg),
            Expanded(
              child: Slider(
                value: _seek,
                onChanged: (v) => setState(() => _seek = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: VxSpacing.lg),
        Wrap(
          spacing: VxSpacing.xxl,
          runSpacing: VxSpacing.lg,
          children: [
            VxPlayerControls(
              isPlaying: _playing,
              shuffleOn: _shuffleOn,
              repeatOn: _repeatOn,
              onPlayPause: () => setState(() => _playing = !_playing),
              onShuffle: () => setState(() => _shuffleOn = !_shuffleOn),
              onRepeat: () => setState(() => _repeatOn = !_repeatOn),
              onPrevious: () {},
              onNext: () {},
            ),
            const VxPlayerControls(
              isPlaying: false,
              shuffleOn: true,
              repeatOn: true,
              onPlayPause: _noop,
              onShuffle: _noop,
              onRepeat: _noop,
              onPrevious: _noop,
              onNext: _noop,
            ),
            const VxPlayerControls(enabled: false),
          ],
        ),
      ],
    );
  }
}

void _noop() {}

/// "Gallery 样例"小标签。
class _GalleryTag extends StatelessWidget {
  const _GalleryTag();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: VxSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline),
      ),
      child: Text(
        'Gallery 样例',
        style: VxTypography.caption.copyWith(
          fontSize: 10,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

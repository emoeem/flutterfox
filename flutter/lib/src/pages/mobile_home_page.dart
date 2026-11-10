/// 手机首页（指南 §5.2：布局顺序 1-7 + §9 四态）。
///
/// 区块顺序：问候区 → 空库 Hero（仅 song==null && history.isEmpty，两 CTA
/// 中「导入本地音乐」直接触发系统目录选择流程，不跳介绍页）→ 最近播放
/// 横滑（封面 72dp ∈ 64-76，复用 home_shared [RecentShelf]）→ 快捷入口
/// （本地音乐/喜欢的歌曲/下载，全部落真实页面）→ 为你推荐（真实
/// `loadPlaylists` browse 槽，无能力音源给空态，不造假数据）→ 排行榜
/// （home_shared [LeaderboardSection] compact 档）。
///
/// §5.2 第 8 项「最近添加或最近播放列表」：最近播放已由第 4 项横滑书架
/// 承载（同一真实数据源 `state.history`，纵向列表为同数据重复展示）；
/// 「最近添加」需要本地扫描时序元数据（localSongs 无添加时间字段）——
/// 已在 04-defect-matrix Phase 2 偏差登记，不在本页造假数据补位。
///
/// 数据全部消费 AppModel 真实状态；错误消息经
/// [AppModel.sanitizeUserFacingMessage] 净化（P1-07 同口径）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/components/vx_artwork.dart';
import '../design_system/components/vx_empty_state.dart';
import '../design_system/components/vx_error_state.dart';
import '../design_system/components/vx_loading_skeleton.dart';
import '../design_system/components/vx_playlist_card.dart';
import '../design_system/components/vx_section_header.dart';
import '../design_system/design_tokens.dart';
import '../nav_bus.dart';
import 'home_shared.dart';
import 'library_page.dart';
import 'local_music_page.dart';
import 'playlist_detail_page.dart';

class MobileHomePage extends StatelessWidget {
  final AppModel model;

  const MobileHomePage(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final history = model.state.history;
        final song = model.state.playback.song;
        final emptyLibrary = song == null && history.isEmpty;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const _GreetingHead(),
            const SizedBox(height: 16),
            if (emptyLibrary) ...[
              _EmptyLibraryHero(model: model),
              const SizedBox(height: 24),
            ],
            if (history.isNotEmpty) ...[
              RecentShelf(model: model, history: history, coverSize: 72),
              const SizedBox(height: 28),
            ],
            _QuickEntries(model: model),
            const SizedBox(height: 28),
            _RecommendedSection(model: model),
            const SizedBox(height: 28),
            LeaderboardSection(model: model, compact: true),
          ],
        );
      },
    );
  }
}

/// 问候区：动态问候语 + 日期（§5.2 第 2 项，不占过高空间；共享纯函数）。
class _GreetingHead extends StatelessWidget {
  const _GreetingHead();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homeGreeting(),
          style: VxTypography.h2.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: VxSpacing.xs),
        Text(
          homeDateLabel(),
          style: VxTypography.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// 空库 Hero（§5.2 规格：左右边距 20dp、圆角 20-24、标题/说明/两 CTA）。
/// 「导入本地音乐」直接触发系统目录选择流程（§5.10 第一落点）。
class _EmptyLibraryHero extends StatelessWidget {
  const _EmptyLibraryHero({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surfaceContainerLow, scheme.surfaceContainerHigh],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.surfaceContainerHighest),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: VxCoverGradients.forSeed('voicefox-empty-library'),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.music_note_outlined,
              size: 34,
              color: Color(0xCCFFFFFF),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '音乐库还是空的',
            textAlign: TextAlign.center,
            style: VxTypography.h2.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: VxSpacing.sm),
          Text(
            '导入本地音乐，或搜索在线音乐开始收听。',
            textAlign: TextAlign.center,
            style: VxTypography.body.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          // 竖排两 CTA（Phase 2 QA P1）：横排等分在 360/390 视口每按钮仅
          // ~134-149px，按钮 label 13px×6 字 + 图标 + 两侧 24 padding 需
          // ≥152px，「导入本地音乐」必词中断行（「导入本地音/乐」）。
          // 竖排全宽后 280-310px 单行容纳，触控目标也更大（§5.9）。
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => navRequest.value = 1,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('搜索音乐'),
                ),
                const SizedBox(height: VxSpacing.sm),
                OutlinedButton.icon(
                  // 直接触发文件/目录选择流程（§5.10：不得只跳转介绍页）。
                  onPressed: () => importLocalMusicDirectory(context, model),
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('导入本地音乐'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 快捷入口（§5.2 第 5 项）：本地音乐 / 喜欢的歌曲 / 下载。
/// 三个入口全部落真实页面/目的地，不做占位跳转：
/// - 本地音乐 → 真实 [LocalMusicPage]（页顶「添加目录」= §5.10 第三落点）；
/// - 喜欢的歌曲 → 真实 [LibraryPage] 歌曲档（songs = 喜欢的歌曲 + 账号
///   红心镜像，与桌面曲库「喜欢的歌曲」入口卡同一语义）；
/// - 下载 → 壳一级目的地「下载」（navRequest=6 经 mapLegacyNavIndex）。
class _QuickEntries extends StatelessWidget {
  const _QuickEntries({required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return Row(
      // ListView 子项高度无界，不能 stretch（会强制无限高）；统一由
      // _EntryTile 的 minHeight 保证三卡等高观感。
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EntryTile(
          icon: Icons.speaker_outlined,
          label: '本地音乐',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => LocalMusicPage(model)),
          ),
        ),
        const SizedBox(width: VxSpacing.md),
        _EntryTile(
          icon: Icons.favorite_border,
          label: '喜欢的歌曲',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: SafeArea(
                  child: LibraryPage(model, initialTab: LibraryTab.songs),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: VxSpacing.md),
        _EntryTile(
          icon: Icons.download_outlined,
          label: '下载',
          onTap: () => navRequest.value = 6,
        ),
      ],
    );
  }
}

/// 快捷入口卡（触控目标高 ≥64dp，§5.9 触控目标 ≥48dp 口径）。
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VxRadius.lg),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(
          horizontal: VxSpacing.md,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(VxRadius.lg),
          border: Border.all(color: scheme.surfaceContainerHighest),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: scheme.primary),
            const SizedBox(height: VxSpacing.sm),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VxTypography.body.copyWith(color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

/// 为你推荐（§5.2 第 6 项）：真实「支持歌单的音源」`loadPlaylists`
/// browse 槽数据，不是 customPlaylists（用户自建歌单≠推荐）。
/// 无能力音源时显示可操作空态，不造假数据（§5.2）。
class _RecommendedSection extends StatefulWidget {
  const _RecommendedSection({required this.model});

  final AppModel model;

  @override
  State<_RecommendedSection> createState() => _RecommendedSectionState();
}

class _RecommendedSectionState extends State<_RecommendedSection> {
  String? _requestedSource;

  AppModel get _model => widget.model;

  @override
  void initState() {
    super.initState();
    // 与共享排行榜同一去重模式：模型监听 + 帧后调度（模型通知可能发生在
    // build 期，直接派发会让祖先 AnimatedBuilder 在 build 中被标脏）。
    _model.addListener(_maybeLoad);
    _maybeLoad();
  }

  @override
  void didUpdateWidget(covariant _RecommendedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) {
      oldWidget.model.removeListener(_maybeLoad);
      widget.model.addListener(_maybeLoad);
      _maybeLoad();
    }
  }

  @override
  void dispose() {
    _model.removeListener(_maybeLoad);
    super.dispose();
  }

  bool _loadScheduled = false;

  void _maybeLoad() {
    if (_loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (!mounted) return;
      _loadNow();
    });
  }

  void _loadNow() {
    final capable = _model.state.sources.where((source) => source.playlists);
    final source = capable.isEmpty ? null : capable.first.id;
    if (source == null || _requestedSource == source) return;
    _requestedSource = source;
    _model.loadPlaylists(source: source, category: '', page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final capable = _model.state.sources
        .where((source) => source.playlists)
        .toList();
    final source = capable.isEmpty ? null : capable.first;
    final result = source == null
        ? null
        : _model.browse('playlists', source.id, '');
    final playlists = result?.playlists ?? const <bridge.PlaylistDto>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VxSectionHeader(
          title: '为你推荐',
          actions: source == null
              ? const <Widget>[]
              : [
                  Padding(
                    padding: const EdgeInsets.only(right: VxSpacing.sm),
                    child: Text(
                      source.name,
                      style: VxTypography.caption.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
          onViewAll: source == null ? null : () => navRequest.value = 3,
        ),
        const SizedBox(height: VxSpacing.md),
        _body(context, source, result, playlists),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    bridge.SourceCapabilitiesDto? source,
    BrowseResult? result,
    List<bridge.PlaylistDto> playlists,
  ) {
    if (source == null) {
      return SizedBox(
        height: 200,
        child: VxEmptyState(
          icon: Icons.explore_outlined,
          title: '当前没有支持歌单的音源',
          message: '可在设置中启用支持歌单的音源，推荐会显示在这里。',
        ),
      );
    }
    if (result == null || (result.loading && playlists.isEmpty)) {
      // 手机档铺满可用宽度（桌面 480 定宽在 360dp 视口放不下）。
      return const SizedBox(
        height: 160,
        width: double.infinity,
        child: VxLoadingSkeleton.tracks(rows: 2),
      );
    }
    if (result.error != null) {
      return Container(
        // 固定高在长错误文案下会 overflow；minHeight 随内容生长。
        constraints: const BoxConstraints(minHeight: 200),
        alignment: Alignment.center,
        child: VxErrorState(
          title: '推荐加载失败',
          message: '无法读取「${source.name}」的歌单目录。',
          // P1-07 同口径：原始异常不直出 UI。
          detail: AppModel.sanitizeUserFacingMessage(result.error!),
          icon: Icons.cloud_off,
          onRetry: () {
            _requestedSource = null;
            _maybeLoad();
          },
        ),
      );
    }
    if (playlists.isEmpty) {
      return SizedBox(
        height: 200,
        child: VxEmptyState(
          icon: Icons.explore_outlined,
          title: result.notice ?? '暂无推荐内容',
          message: '该音源没有返回可用歌单。',
        ),
      );
    }
    return SizedBox(
      height: 204,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: playlists.length.clamp(0, 12),
        separatorBuilder: (_, _) => const SizedBox(width: VxSpacing.md),
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return VxPlaylistCard(
            title: playlist.name,
            source: _model.capability(playlist.source)?.name ?? playlist.source,
            width: 132,
            cover: VxArtwork(
              url: playlist.coverUrl,
              source: playlist.source,
              entityType: 'playlist',
              entityId: playlist.id,
              entityName: playlist.name,
              size: 132,
              radius: 0,
              allowRetry: false,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlaylistDetailPage(_model, playlist),
              ),
            ),
            onPlay: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlaylistDetailPage(_model, playlist),
              ),
            ),
          );
        },
      ),
    );
  }
}

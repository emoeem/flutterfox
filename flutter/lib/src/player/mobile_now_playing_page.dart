/// Phase 7 手机全屏播放页：封面 / 歌词两层 + 队列底部 sheet + 手势切换。
///
/// 分层语义（计划 §9 触屏交互 / §5.7）：
/// - 封面层：点击或上滑进歌词层；下滑退出整页（pull-down dismiss，
///   [onClose] 由壳恢复列表界面）；封面横滑切歌（P2-06，只绑封面区，
///   避开 LiveSeekRow 横向拖动与屏幕左右缘系统返回手势）；
/// - 歌词层：复用 [LyricsPanel]（compact），经顶栏歌词按钮进出；
/// - 队列：底部 sheet（§5.7:452「底部 sheet 或二级页面」，P2-09）复用
///   [QueuePanel]，经顶栏队列按钮开关；DraggableScrollableSheet 与
///   QueuePanel 的 Column+Expanded(ListView) 定高依赖不兼容，故用定高
///   容器 + DragHandle 下滑/点遮罩关闭；拖拽排序/队内跳播如实呈现禁用
///   并说明（后端无对应命令，queue_panel.dart 头注现状，计划 §11.10
///   禁止伪造拖拽）。
///
/// 复用件（自 now_playing_page.dart 提取，桌面并置布局共用同一实现）：
/// [NowPlayingBackdrop]（取色低饱和暗化背景）、[NowPlayingAutoPalette]
/// （封面主色自动重取）、[CrossfadeCover]（封面 crossfade）、
/// [NowPlayingActionRow]（收藏/歌单/下载/更多真实命令）、[LiveSeekRow]
/// （插值 + 真实 seek + `--:--` 规则，progress_control.dart）。
///
/// 手势与滚动的关系：封面层内容按可用高度自适应（封面缩小让位），
/// 不接滚动容器，垂直拖动稳定命中分层手势；极矮视口（横屏）退化为
/// 滚动布局，此时手势让位给滚动（按钮仍可用）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../config_ext.dart';
import '../design_system/components/vx_empty_state.dart';
import '../design_system/components/vx_player_controls.dart';
import '../design_system/design_tokens.dart';
import 'lyrics_panel.dart';
import 'now_playing_page.dart';
import 'progress_control.dart';
import 'queue_panel.dart';

/// 手机全屏播放页的分层（队列不占层：走底部 sheet，见 [_openQueueSheet]）。
enum MobileNowPlayingLayer { cover, lyrics }

/// 手机全屏播放页。
class MobileNowPlayingPage extends StatefulWidget {
  const MobileNowPlayingPage({
    super.key,
    required this.model,
    required this.onClose,
    this.initialLayer = MobileNowPlayingLayer.cover,
  });

  final AppModel model;

  /// 退出整页（壳恢复列表 + 迷你播放栏）。
  final VoidCallback onClose;

  /// 初始分层（跨档穿越保持分层用；缺省封面层）。
  final MobileNowPlayingLayer initialLayer;

  @override
  State<MobileNowPlayingPage> createState() => _MobileNowPlayingPageState();
}

class _MobileNowPlayingPageState extends State<MobileNowPlayingPage> {
  late MobileNowPlayingLayer _layer = widget.initialLayer;

  /// 封面主色（低饱和背景用）；null = 尚未取到 / 取色失败回退主题色。
  Color? _coverColor;

  /// 队列 sheet 是否打开（顶栏队列按钮激活态依据；sheet 无独立 layer）。
  bool _queueSheetOpen = false;

  /// 分层切换的速度阈值（px/s）：过滤轻触抖动。
  static const double _flingVelocity = 120;

  void _setLayer(MobileNowPlayingLayer layer) {
    if (_layer == layer) return;
    setState(() => _layer = layer);
  }

  /// 队列底部 sheet（§5.7:452）：复用 QueuePanel，DragHandle 下滑或点
  /// 遮罩关闭；打开期间顶栏按钮保持激活态（[_queueSheetOpen]）。
  Future<void> _openQueueSheet() async {
    setState(() => _queueSheetOpen = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        // 关闭默认整 sheet 拖拽（与列表滚动争手势、行为不定）：收起入口
        // 收敛为 DragHandle 下滑 + 点遮罩，语义可测。
        enableDrag: false,
        builder: (sheetContext) {
          final scheme = Theme.of(sheetContext).colorScheme;
          return SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.75,
            child: Column(
              children: [
                // DragHandle：唯一主动下滑关闭入口（列表滚动不收起），
                // 下滑速度达标即关闭；点遮罩关闭为兜底。
                GestureDetector(
                  key: const ValueKey('queue_sheet_drag_handle'),
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity > _flingVelocity) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  child: SizedBox(
                    width: double.infinity,
                    height: 24,
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: QueuePanel(model: widget.model)),
              ],
            ),
          );
        },
      );
    } finally {
      // 无论下拉关闭、点遮罩还是路由其它方式退出，都复位激活态。
      if (mounted) {
        setState(() => _queueSheetOpen = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.model,
      builder: (context, _) {
        final model = widget.model;
        final song = model.state.playback.song;
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: NowPlayingBackdrop(coverColor: _coverColor),
              ),
              // 封面取色（失败回退主题色）；歌曲/封面变化时自动重取。
              Positioned(
                left: 0,
                top: 0,
                width: 0,
                height: 0,
                child: NowPlayingAutoPalette(
                  url: song?.coverUrl,
                  onColor: (color) {
                    if (mounted) setState(() => _coverColor = color);
                  },
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      layer: _layer,
                      queueOpen: _queueSheetOpen,
                      onClose: widget.onClose,
                      onToggleLyrics: () => _setLayer(
                        _layer == MobileNowPlayingLayer.lyrics
                            ? MobileNowPlayingLayer.cover
                            : MobileNowPlayingLayer.lyrics,
                      ),
                      onToggleQueue: _openQueueSheet,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : VxMotion.panelExpand,
                        child: KeyedSubtree(
                          key: ValueKey(_layer),
                          child: _buildLayer(context, song),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLayer(BuildContext context, bridge.SongDto? song) {
    switch (_layer) {
      case MobileNowPlayingLayer.lyrics:
        return LyricsPanel(model: widget.model, compact: true);
      case MobileNowPlayingLayer.cover:
        if (song == null) {
          return Center(
            child: VxEmptyState(
              icon: Icons.album_outlined,
              title: '未在播放',
              message: '从搜索、曲库或歌单挑一首开始播放，这里会显示封面与歌词。',
              actionLabel: '返回应用',
              onAction: widget.onClose,
            ),
          );
        }
        return _CoverLayer(
          model: widget.model,
          song: song,
          onTap: () => _setLayer(MobileNowPlayingLayer.lyrics),
          onVerticalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -_flingVelocity) {
              // 上滑：进歌词层。
              _setLayer(MobileNowPlayingLayer.lyrics);
            } else if (velocity > _flingVelocity) {
              // 下滑：退出整页。
              widget.onClose();
            }
          },
        );
    }
  }
}

// ── 顶栏：返回 / 标题 / 歌词 / 队列 ─────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.layer,
    required this.queueOpen,
    required this.onClose,
    required this.onToggleLyrics,
    required this.onToggleQueue,
  });

  final MobileNowPlayingLayer layer;

  /// 队列 sheet 打开态（队列按钮激活依据；队列不再是页内 layer）。
  final bool queueOpen;
  final VoidCallback onClose;
  final VoidCallback onToggleLyrics;
  final VoidCallback onToggleQueue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget toggle(
      IconData icon,
      String tooltip,
      bool active,
      VoidCallback onTap,
    ) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 20,
          color: active ? scheme.primary : scheme.onSurfaceVariant,
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: '返回应用',
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'NOW PLAYING',
              style: VxTypography.eyebrow.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 3,
              ),
            ),
            const Spacer(),
            toggle(
              Icons.lyrics_outlined,
              '歌词层',
              layer == MobileNowPlayingLayer.lyrics,
              onToggleLyrics,
            ),
            toggle(
              Icons.queue_music_outlined,
              '播放队列',
              queueOpen,
              onToggleQueue,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 封面层：自适应不滚动（手势稳定命中） + 极矮视口滚动回退 ─────────────

class _CoverLayer extends StatelessWidget {
  const _CoverLayer({
    required this.model,
    required this.song,
    required this.onTap,
    required this.onVerticalDragEnd,
  });

  final AppModel model;
  final bridge.SongDto song;
  final VoidCallback onTap;
  final ValueChanged<DragEndDetails> onVerticalDragEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        // 内容固定区（歌名/元信息/操作行/进度/控制）约 330；可用高度充足
        // 时封面自适应缩小让位，整层不滚动 → 垂直拖动稳定触发分层手势。
        final scrollFallback = height < 560;
        // 封面 280-340dp 自适应（§5.7:446-447）：高度充足时在 340 上限内
        // 让位歌名/控制行；宽度守卫保留（外层 maxWidth-40 封顶）——极窄
        // 视口下下界取 min(160, 可用宽)，封面绝不宽于可用宽度，防
        // RenderFlex 水平溢出。body 水平 padding 两侧共 40。
        final widthCap = constraints.maxWidth - 40;
        final coverSize = scrollFallback
            ? 240.0
            : math.max(
                math.min(math.min(height - 330, widthCap), 340.0),
                math.min(160.0, widthCap),
              );
        final body = _coverBody(context, coverSize);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onTap,
          onVerticalDragEnd: scrollFallback ? null : onVerticalDragEnd,
          child: scrollFallback
              ? SingleChildScrollView(child: body)
              : Center(child: body),
        );
      },
    );
  }

  Widget _coverBody(BuildContext context, double coverSize) {
    final scheme = Theme.of(context).colorScheme;
    final playback = model.state.playback;
    final playing = playback.state == 'playing';
    final mode = model.config?.playMode ?? 'list-loop';
    final configReady = model.config != null;
    final metaParts = [
      song.singer,
      if (song.albumName.isNotEmpty) song.albumName else song.source,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SwipeableCover(model: model, song: song, size: coverSize),
          const SizedBox(height: 18),
          // 歌名（§5.1 缩到手机档 24px），长标题两行截断。
          Text(
            song.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            metaParts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          NowPlayingActionRow(model: model, song: song),
          const SizedBox(height: 12),
          RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: LiveSeekRow(model: model, playing: playing),
            ),
          ),
          const SizedBox(height: 6),
          VxPlayerControls(
            isPlaying: playing,
            shuffleOn: mode == 'random',
            repeatOn: mode == 'list-loop' || mode == 'single-loop',
            enabled: true,
            gap: 22,
            onShuffle: configReady
                ? () => model.updateConfig(
                    (config) => config.copyWith(
                      playMode: mode == 'random' ? 'list-loop' : 'random',
                    ),
                  )
                : null,
            onPrevious: model.previous,
            onPlayPause: model.toggle,
            onNext: model.next,
            onRepeat: configReady ? () => _cycle(mode) : null,
          ),
        ],
      ),
    );
  }

  void _cycle(String mode) {
    const cycle = ['list-loop', 'single-loop', 'none'];
    final start = cycle.indexOf(mode == 'random' ? 'list-loop' : mode);
    final next = cycle[((start < 0 ? 0 : start) + 1) % cycle.length];
    model.updateConfig((config) => config.copyWith(playMode: next));
  }
}

// ── 封面横滑切歌（P2-06） ─────────────────────────────────────────────────

/// 封面横滑切歌容器：手势只绑封面区（§5.7:459 冲突规避——避开 LiveSeekRow
/// 横向拖动与屏幕左右缘系统返回手势，不绑整层）；拖动中显示半透明方向
/// 提示层（Start/Update 切方向、Cancel/End 隐藏），松手速度达标才切歌：
/// 左滑（负速度）→ 下一首，右滑（正速度）→ 上一首，全部走 AppModel
/// 真实命令（§8.3）。
class _SwipeableCover extends StatefulWidget {
  const _SwipeableCover({
    required this.model,
    required this.song,
    required this.size,
  });

  final AppModel model;
  final bridge.SongDto song;
  final double size;

  @override
  State<_SwipeableCover> createState() => _SwipeableCoverState();
}

class _SwipeableCoverState extends State<_SwipeableCover> {
  /// 切歌速度阈值（px/s）：过滤轻扫误触。
  static const double _swipeVelocity = 500;

  bool _dragging = false;

  /// 拖动方向：-1 = 左滑（下一首）、1 = 右滑（上一首）、0 = 未定。
  int _direction = 0;

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _dragging = true;
      _direction = 0;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx == 0) return;
    setState(() => _direction = details.delta.dx < 0 ? -1 : 1);
  }

  void _onDragEnd(DragEndDetails details) {
    final dx = details.velocity.pixelsPerSecond.dx;
    setState(() {
      _dragging = false;
      _direction = 0;
    });
    if (dx < -_swipeVelocity) {
      widget.model.next();
    } else if (dx > _swipeVelocity) {
      widget.model.previous();
    }
  }

  void _onDragCancel() {
    setState(() {
      _dragging = false;
      _direction = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hintVisible = _dragging && _direction != 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onHorizontalDragCancel: _onDragCancel,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CrossfadeCover(song: widget.song, size: widget.size),
          // 方向提示层：拖动中出现、Cancel/End 消失（子树随隐藏整体移除，
          // 不残留 hit-test 区域）。
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: hintVisible ? 1.0 : 0.0,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              child: hintVisible
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.scrim.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(VxRadius.md),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _direction < 0
                                  ? Icons.fast_forward
                                  : Icons.fast_rewind,
                              size: 20,
                              color: scheme.onSurface,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _direction < 0 ? '下一首' : '上一首',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

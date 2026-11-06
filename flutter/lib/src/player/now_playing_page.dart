/// Phase 3 全屏播放页 NowPlayingPage（计划书 §5.1，产品视觉核心）。
///
/// 布局（1440×900 基准，随窗口自适应）：
/// - 顶部返回区 56px：返回应用 / NOW PLAYING / 队列 / 更多；
/// - 内容主区最大宽 1320 水平居中；左封面列 46% + 右歌词列 54%，间距 48px；
/// - 封面边长按可用高度在 320–500px 自适应；高度不足时左列纵向滚动；
/// - 背景从封面取色做低饱和暗化渐变（取色失败回退主题色暗化），
///   歌词区保持足够对比度；
/// - 歌曲名 28–34px；操作行 收藏/添加到歌单/下载/更多 全部接 AppModel
///   真实命令；音频输出如实显示「由系统管理」（后端无设备枚举，§5.4）；
/// - 进度行共用 LiveSeekRow（插值 + 真实 seek + `--:--` 规则）；
/// - 进入全屏时 Shell 隐藏 PlayerBar，本页提供唯一播放控制，Esc 返回；
/// - 封面切换 crossfade、背景随取色过渡；关闭减少动效时全部直切（§6.5）。
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../config_ext.dart';
import '../design_system/components/vx_empty_state.dart';
import '../design_system/components/vx_player_controls.dart';
import '../design_system/design_tokens.dart';
import '../widgets/cover_image.dart';
import '../widgets/custom_playlist_dialogs.dart';
import 'lyrics_panel.dart';
import 'progress_control.dart';
import 'queue_panel.dart';

/// 全屏播放页。
class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({
    super.key,
    required this.model,
    required this.onClose,
  });

  final AppModel model;

  /// 返回主界面（Shell 恢复 Header/Sidebar/PlayerBar）。
  final VoidCallback onClose;

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  bool _queueOpen = false;

  /// 封面主色（低饱和背景用）；null = 尚未取到 / 取色失败回退主题色。
  Color? _coverColor;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
        },
        child: AnimatedBuilder(
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
                  Column(
                    children: [
                      _TopBar(
                        model: model,
                        queueOpen: _queueOpen,
                        onClose: widget.onClose,
                        onToggleQueue: () =>
                            setState(() => _queueOpen = !_queueOpen),
                      ),
                      Expanded(
                        child: song == null
                            ? Center(
                                child: VxEmptyState(
                                  icon: Icons.album_outlined,
                                  title: '未在播放',
                                  message:
                                      '从搜索、曲库或歌单挑一首开始播放，这里会显示封面与歌词。',
                                  actionLabel: '返回应用',
                                  onAction: widget.onClose,
                                ),
                              )
                            : _NowPlayingBody(
                                model: model,
                                song: song,
                                queueOpen: _queueOpen,
                                onToggleQueue: () =>
                                    setState(() => _queueOpen = !_queueOpen),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── 背景：封面取色低饱和暗化（§5.1） ─────────────────────────────────────

/// 封面取色低饱和暗化背景（Phase 7 提取公开：桌面 NowPlayingPage 与手机
/// MobileNowPlayingPage 共用；浅色亮度 0.85 / 暗色 0.13 保证歌词对比度）。
class NowPlayingBackdrop extends StatelessWidget {
  const NowPlayingBackdrop({super.key, required this.coverColor});

  final Color? coverColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final disable = MediaQuery.disableAnimationsOf(context);
    final base = coverColor ?? scheme.primary;
    final hsl = HSLColor.fromColor(base);
    // 低饱和 + 暗化：saturation 减半封顶 0.45，暗色亮度 0.13（浅色 0.85），
    // 保证歌词文字对比度不被背景渐变干扰。
    final tuned = hsl
        .withSaturation((hsl.saturation * 0.45).clamp(0.0, 0.45))
        .withLightness(dark ? 0.13 : 0.85)
        .toColor();
    return AnimatedContainer(
      duration: disable ? Duration.zero : VxMotion.coverCrossfade,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tuned, scheme.surface],
        ),
      ),
    );
  }
}

/// 封面主色提取：解码 16×16 缩略图取平均色。纯 dart:ui 实现，无新依赖；
/// 失败（无网络/测试环境）返回 null，由背景回退主题色暗化。
class _CoverPalette {
  static final Map<String, Color> _cache = {};

  static Future<Color?> extract(String url) async {
    final cached = _cache[url];
    if (cached != null) return cached;
    try {
      final uri = Uri.parse(url);
      final data = await NetworkAssetBundle(uri).load(uri.toString());
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 16,
        targetHeight: 16,
      );
      final frame = await codec.getNextFrame();
      final bytes = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      frame.image.dispose();
      if (bytes == null) return null;
      final pixels = bytes.buffer.asUint8List();
      var r = 0;
      var g = 0;
      var b = 0;
      var count = 0;
      for (var i = 0; i + 3 < pixels.length; i += 4) {
        if (pixels[i + 3] < 128) continue;
        r += pixels[i];
        g += pixels[i + 1];
        b += pixels[i + 2];
        count++;
      }
      if (count == 0) return null;
      final color = Color.fromARGB(255, r ~/ count, g ~/ count, b ~/ count);
      _cache[url] = color;
      return color;
    } on Object {
      return null;
    }
  }
}

/// 封面 URL 变化时自动重取主色（Phase 7 提取公开；取色实现
/// _CoverPalette 保持私有，失败回退 null 由背景走主题色）。
class NowPlayingAutoPalette extends StatefulWidget {
  const NowPlayingAutoPalette({super.key, required this.url, required this.onColor});

  final String? url;
  final ValueChanged<Color?> onColor;

  @override
  State<NowPlayingAutoPalette> createState() => _AutoPaletteState();
}

class _AutoPaletteState extends State<NowPlayingAutoPalette> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant NowPlayingAutoPalette old) {
    super.didUpdateWidget(old);
    if (widget.url != old.url) _load();
  }

  Future<void> _load() async {
    final url = widget.url;
    if (url == null || url.isEmpty) {
      _report(null);
      return;
    }
    final color = await _CoverPalette.extract(url);
    if (mounted && url == widget.url) {
      _report(color);
    }
  }

  /// onColor 可能触发父级 setState：initState/didUpdateWidget 期间调用会
  /// 「setState during build」，统一延迟到帧末。
  void _report(Color? color) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onColor(color);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ── 顶部返回区（56px） ───────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.model,
    required this.queueOpen,
    required this.onClose,
    required this.onToggleQueue,
  });

  final AppModel model;
  final bool queueOpen;
  final VoidCallback onClose;
  final VoidCallback onToggleQueue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSong = model.state.playback.song != null;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('返回应用'),
            ),
            const SizedBox(width: 14),
            Text(
              'NOW PLAYING',
              style: VxTypography.eyebrow.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 3,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: '队列面板',
              onPressed: onToggleQueue,
              icon: Icon(
                Icons.queue_music_outlined,
                color: queueOpen ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '更多',
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'stop',
                  enabled: hasSong,
                  child: const Text('停止播放'),
                ),
              ],
              onSelected: (value) {
                if (value == 'stop') {
                  model.dispatch(const bridge.FfiCommand.stop());
                }
              },
              icon: Icon(Icons.more_horiz, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 主内容区：左封面列 46% + 右歌词列 54%，间距 48，最大宽 1320 ───────────

class _NowPlayingBody extends StatelessWidget {
  const _NowPlayingBody({
    required this.model,
    required this.song,
    required this.queueOpen,
    required this.onToggleQueue,
  });

  final AppModel model;
  final bridge.SongDto song;
  final bool queueOpen;
  final VoidCallback onToggleQueue;

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bodyH = constraints.maxHeight;
                final leftWidth = (constraints.maxWidth - 48) * 0.46;
                // 封面边长按可用高度自适应（320–500）；高度不足时左列滚动。
                final byHeight = (bodyH - 372).clamp(320.0, 500.0);
                final coverSize = math.min(byHeight, leftWidth - 8);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 46,
                      child: _LeftColumn(
                        model: model,
                        song: song,
                        bodyHeight: bodyH,
                        coverSize: coverSize,
                        narrow: constraints.maxWidth < 1080,
                        onToggleQueue: onToggleQueue,
                      ),
                    ),
                    const SizedBox(width: 48),
                    Expanded(flex: 54, child: LyricsPanel(model: model)),
                  ],
                );
              },
            ),
          ),
        ),
        // 队列侧板（全屏页内唯一的队列入口；ContextPanel 此时被覆盖）。
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: 340,
          child: AnimatedSlide(
            duration: disable ? Duration.zero : VxMotion.panelExpand,
            curve: VxMotion.standard,
            offset: queueOpen ? Offset.zero : const Offset(1, 0),
            child: _QueueSheet(model: model, onClose: onToggleQueue),
          ),
        ),
      ],
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({
    required this.model,
    required this.song,
    required this.bodyHeight,
    required this.coverSize,
    required this.narrow,
    required this.onToggleQueue,
  });

  final AppModel model;
  final bridge.SongDto song;
  final double bodyHeight;
  final double coverSize;
  final bool narrow;
  final VoidCallback onToggleQueue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playback = model.state.playback;
    final playing = playback.state == 'playing';
    final mode = model.config?.playMode ?? 'list-loop';
    final configReady = model.config != null;
    final titleSize = narrow ? 28.0 : 32.0;
    final metaParts = [
      song.singer,
      if (song.albumName.isNotEmpty) song.albumName else song.source,
    ];
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: bodyHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CrossfadeCover(song: song, size: coverSize),
              const SizedBox(height: 24),
              // 歌曲名 28–34px（§5.1），长标题两行截断。
              Text(
                song.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: titleSize.clamp(28.0, 34.0),
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.4,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                metaParts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              NowPlayingActionRow(model: model, song: song),
              const SizedBox(height: 20),
              RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: LiveSeekRow(
                    model: model,
                    positionMs: playback.positionMs,
                    durationMs: playback.durationMs,
                    playing: playing,
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                onRepeat: configReady ? () => _cycle(context, mode) : null,
              ),
              const SizedBox(height: 14),
              _BottomRow(model: model, onToggleQueue: onToggleQueue),
            ],
          ),
        ),
      ),
    );
  }

  void _cycle(BuildContext context, String mode) {
    const cycle = ['list-loop', 'single-loop', 'none'];
    final start = cycle.indexOf(mode == 'random' ? 'list-loop' : mode);
    final next = cycle[((start < 0 ? 0 : start) + 1) % cycle.length];
    model.updateConfig((config) => config.copyWith(playMode: next));
  }
}

// ── 封面（切换 crossfade；无封面走种子渐变占位） ─────────────────────────

/// 封面 crossfade（Phase 7 提取公开：歌曲更换 key 变化 → crossfade，
/// 同曲刷新不重播 §6.5；无封面走种子渐变占位）。
class CrossfadeCover extends StatelessWidget {
  const CrossfadeCover({super.key, required this.song, required this.size});

  final bridge.SongDto song;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disable = MediaQuery.disableAnimationsOf(context);
    final hasCover = song.coverUrl != null && song.coverUrl!.isNotEmpty;
    final content = hasCover
        ? CoverImage.expand(url: song.coverUrl, radius: 16)
        : DecoratedBox(
            decoration: BoxDecoration(
              gradient: VxCoverGradients.forSeed('${song.name}${song.singer}'),
            ),
            child: Icon(
              Icons.music_note_outlined,
              size: size * 0.24,
              color: scheme.onSurfaceVariant,
            ),
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 44,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: disable ? Duration.zero : VxMotion.coverCrossfade,
        child: SizedBox(
          // 歌曲更换时 key 变化 → crossfade；同曲刷新不重播（§6.5）。
          key: ValueKey('${song.id}|${song.coverUrl ?? ''}'),
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: content,
          ),
        ),
      ),
    );
  }
}

// ── 操作行：收藏 / 添加到歌单 / 下载 / 更多（全部真实命令） ─────────────

/// 操作行：收藏 / 添加到歌单 / 下载 / 更多（Phase 7 提取公开；全部真实
/// 命令，窄宽自动换行）。
class NowPlayingActionRow extends StatelessWidget {
  const NowPlayingActionRow({super.key, required this.model, required this.song});

  final AppModel model;
  final bridge.SongDto song;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final favorite = model.isFavorite(song);
        // Wrap：桌面一行放下时与 Row 视觉一致；手机窄宽自动换行不溢出。
        return Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: favorite ? '取消收藏' : '收藏',
              onPressed: () => model.toggleFavorite(song),
              icon: Icon(
                favorite ? Icons.favorite : Icons.favorite_border,
                size: 22,
                color: favorite ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            IconButton(
              tooltip: '添加到歌单',
              onPressed: () => showAddToCustomPlaylistSheet(context, model, [song]),
              icon: Icon(Icons.playlist_add, size: 22, color: scheme.onSurfaceVariant),
            ),
            IconButton(
              tooltip: '下载',
              onPressed: () => model.download(song),
              icon: Icon(Icons.download_outlined, size: 22, color: scheme.onSurfaceVariant),
            ),
            PopupMenuButton<String>(
              tooltip: '更多',
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'stop',
                  enabled: true,
                  child: const Text('停止播放'),
                ),
              ],
              onSelected: (value) {
                if (value == 'stop') {
                  model.dispatch(const bridge.FfiCommand.stop());
                }
              },
              icon: Icon(Icons.more_horiz, size: 22, color: scheme.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}

// ── 底行：音量 / 输出设备 / 队列入口（§5.4 如实呈现） ────────────────────

class _BottomRow extends StatelessWidget {
  const _BottomRow({required this.model, required this.onToggleQueue});

  final AppModel model;
  final VoidCallback onToggleQueue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Wrap：桌面一行放下时与 Row 视觉一致；手机窄宽自动换行不溢出。
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 音量：真实 setVolume 命令（config.volume 为当前值）。
        AnimatedBuilder(
          animation: model,
          builder: (context, _) {
            final volume = model.config?.volume ?? 100;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  switch (volume) {
                    0 => Icons.volume_off,
                    < 50 => Icons.volume_down,
                    _ => Icons.volume_up,
                  },
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                // Flexible：桌面不限宽时滑条恒 110；手机窄宽（Wrap 列
                // 157px）自动收缩，不溢出（Phase 7 触屏适配）。
                Flexible(
                  child: SizedBox(
                    width: 110,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 10),
                      ),
                      child: Slider(
                        value: (volume / 100).clamp(0.0, 1.0),
                        onChanged: model.config != null
                            ? (v) => model.setVolume((v * 100).round())
                            : null,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '$volume',
                    textAlign: TextAlign.center,
                    style: VxTypography.mono.copyWith(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        // 输出设备：后端未提供设备枚举 API，如实显示「由系统管理」（§5.4）。
        PopupMenuButton<void>(
          tooltip: '音频输出',
          itemBuilder: (context) => const [
            PopupMenuItem<void>(
              enabled: false,
              child: Text('由系统管理（后端未提供设备枚举）'),
            ),
          ],
          icon: Icon(Icons.speaker_outlined, size: 20, color: scheme.onSurfaceVariant),
        ),
        IconButton(
          tooltip: '队列面板',
          onPressed: onToggleQueue,
          icon: Icon(Icons.queue_music_outlined, size: 20, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// 全屏页内的队列侧板（复用 QueuePanel，数据同源 AppModel）。
class _QueueSheet extends StatelessWidget {
  const _QueueSheet({required this.model, required this.onClose});

  final AppModel model;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          left: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '队列',
                    style: VxTypography.title.copyWith(color: scheme.onSurface),
                  ),
                ),
                IconButton(
                  tooltip: '关闭队列面板',
                  iconSize: 18,
                  onPressed: onClose,
                  icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Expanded(child: QueuePanel(model: model)),
        ],
      ),
    );
  }
}

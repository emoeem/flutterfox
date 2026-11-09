/// 歌词滚动视图：按播放位置高亮当前行，自动居中滚动，点击行可跳转。
///
/// 当前行由前端按「插值后的播放位置 + 歌词偏移」二分推导：Rust 侧
/// `LyricState.current_line` 只在加载歌词时算一次，GUI 没有逐帧位置事件，
/// 直接消费快照会导致歌词永远停在第 0 行。
library;

import 'package:flutter/material.dart';

import '../bridge/lib.dart' as bridge;
import 'empty_state.dart';

/// 返回 [positionMs] 对应的歌词行下标；空歌词返回 -1。
///
/// 与 Rust `LyricService::update_position` 的分支保持一致：位置早于首行时
/// 也归到第 0 行（而不是“无歌词”），避免开头几秒整片歌词都无高亮。
int lyricIndexAt(
  List<bridge.LyricLineDto> lines,
  int positionMs, {
  int offsetMs = 0,
}) {
  if (lines.isEmpty) return -1;
  final target = positionMs + offsetMs;
  var low = 0;
  var high = lines.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (lines[mid].timestampMs.toInt() <= target) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low == 0 ? 0 : low - 1;
}

class LyricsView extends StatefulWidget {
  final List<bridge.LyricLineDto> lines;

  /// 本地推导出的当前行（[lyricIndexAt] 的结果）。
  final int currentIndex;

  /// Rust 快照里附带的「当前行翻译」；逐行翻译表未过 FFI，只能谨慎使用。
  final String? translation;
  final int snapshotCurrentLine;

  /// 点击歌词行时回调该行起始毫秒，用于 seek。
  final ValueChanged<int>? onSeekMs;

  const LyricsView({
    super.key,
    required this.lines,
    required this.currentIndex,
    this.translation,
    this.snapshotCurrentLine = 0,
    this.onSeekMs,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  List<GlobalKey> _keys = const [];

  @override
  void initState() {
    super.initState();
    _ensureKeys();
    _scheduleScroll();
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureKeys();
    if (oldWidget.currentIndex != widget.currentIndex ||
        oldWidget.lines.length != widget.lines.length) {
      _scheduleScroll();
    }
  }

  void _ensureKeys() {
    if (_keys.length != widget.lines.length) {
      _keys = List.generate(widget.lines.length, (_) => GlobalKey());
    }
  }

  void _scheduleScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = widget.currentIndex;
      if (index < 0 || index >= _keys.length) return;
      final context = _keys[index].currentContext;
      if (context == null) return;
      // 0.35 让当前行略高于垂直中线，符合歌词器常见的“视线预判”位置。
      Scrollable.ensureVisible(
        context,
        alignment: 0.35,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.lines;
    if (lines.isEmpty) {
      return const EmptyState(
        icon: Icons.lyrics_outlined,
        title: '暂无歌词',
        subtitle: '当前音源没有返回歌词，或歌词仍在加载',
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activeStyle = (theme.textTheme.displaySmall ?? const TextStyle())
        .copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
        );
    final idleStyle = (theme.textTheme.titleLarge ?? const TextStyle())
        .copyWith(fontSize: 22, color: scheme.onSurfaceVariant);

    // Rust 只随快照带回「一行」翻译（没有逐行翻译表）；仅当快照行与本地
    // 推导行一致时才展示，避免把第 0 行的翻译挂到别的行上。
    final showTranslation =
        widget.translation != null &&
        widget.currentIndex == widget.snapshotCurrentLine;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 96, 16, 160),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                _LyricLine(
                  key: _keys[i],
                  text: lines[i].text,
                  active: i == widget.currentIndex,
                  activeStyle: activeStyle,
                  idleStyle: idleStyle,
                  onTap: widget.onSeekMs == null
                      ? null
                      : () => widget.onSeekMs!(lines[i].timestampMs.toInt()),
                ),
                if (i == widget.currentIndex && showTranslation)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 8),
                    child: Text(
                      widget.translation!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LyricLine extends StatelessWidget {
  final String text;
  final bool active;
  final TextStyle activeStyle;
  final TextStyle idleStyle;
  final VoidCallback? onTap;

  const _LyricLine({
    super.key,
    required this.text,
    required this.active,
    required this.activeStyle,
    required this.idleStyle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          style: active ? activeStyle : idleStyle,
          textAlign: TextAlign.center,
          child: Text(text),
        ),
      ),
    );
  }
}

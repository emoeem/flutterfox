/// Phase 2 桌面侧栏（计划书 §3.4 三段式）。
///
/// 结构：
/// - 探索组：首页 / 发现 / 搜索（一级导航 3 项）；
/// - 我的音乐组：我的音乐（一级导航第 4 项）；
/// - 我的歌单：真实自建歌单列表（最多 7 项，超出经「查看全部」进曲库）；
/// - 底段：下载（一级导航第 5 项）、设置、帮助。
///
/// 展开态 240px；折叠态 72px 纯图标 + tooltip。当前页高亮使用低饱和容器
/// 与细强调线（§3.4），不用大面积高亮卡片。
///
/// 一级导航收敛为 5 项（§2.1）；排行榜仍由首页榜单书架进入，本地音乐仍由
/// 曲库页入口进入（页面间现有链接保持）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../design_system/design_tokens.dart';
import '../nav_bus.dart';
import '../pages/custom_playlists_page.dart';
import 'responsive_shell.dart';

/// Shell 一级/二级导航目的地。
enum ShellDestination {
  home('首页'),
  discover('发现'),
  search('搜索'),
  library('我的音乐'),
  downloads('下载'),
  settings('设置'),
  help('帮助');

  const ShellDestination(this.label);
  final String label;
}

/// 侧栏。
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.model,
    required this.current,
    required this.onSelect,
    required this.collapsed,
    this.width = ShellBreakpoints.sidebarWidth,
    this.onWidthChanged,
    this.onToggleCollapsed,
  });

  final AppModel model;
  final ShellDestination current;
  final ValueChanged<ShellDestination> onSelect;

  /// true 为 72px 折叠态。
  final bool collapsed;

  /// 展开态宽度（Shell 持有状态；§7.1 240–300 拖调带）。
  final double width;

  /// 右缘拖动把手调整宽度（null 表示不可调整，如降级浮层）。
  final ValueChanged<double>? onWidthChanged;

  /// 折叠/展开开关（null 不显示开关钮）。
  final VoidCallback? onToggleCollapsed;

  static const _primaryOrder = [
    ShellDestination.home,
    ShellDestination.discover,
    ShellDestination.search,
    ShellDestination.library,
  ];

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return _CollapsedSidebar(
        model: model,
        current: current,
        onSelect: onSelect,
        onToggleCollapsed: onToggleCollapsed,
      );
    }
    return _ExpandedSidebar(
      model: model,
      current: current,
      onSelect: onSelect,
      width: width,
      onWidthChanged: onWidthChanged,
      onToggleCollapsed: onToggleCollapsed,
    );
  }
}

// ── 展开态 ──────────────────────────────────────────────────────────────

class _ExpandedSidebar extends StatelessWidget {
  const _ExpandedSidebar({
    required this.model,
    required this.current,
    required this.onSelect,
    required this.width,
    this.onWidthChanged,
    this.onToggleCollapsed,
  });

  final AppModel model;
  final ShellDestination current;
  final ValueChanged<ShellDestination> onSelect;
  final double width;
  final ValueChanged<double>? onWidthChanged;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    // Phase 6 §7.1：右缘拖调把手悬浮在内容之上（侧栏贴窗口左缘，
    // 可拖边缘是右缘，宽度随 dx 正向增长）。折叠↔展开/拖调过渡期容器
    // 宽度在动画中变化：OverflowBox 让内容恒按目标宽度自然布局，由
    // Stack 裁剪过渡帧（_NavRow 固定最小 44px，<68px 中间帧会溢出，
    // 2026-11-13 widget 层实证）。
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: width,
          maxWidth: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 折叠开关头（全新结构，Phase 6）：仅占一行高度，不挤占导航。
              if (onToggleCollapsed != null)
                Align(
                  alignment: Alignment.centerRight,
                  heightFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 8, 0),
                    child: IconButton(
                      tooltip: '折叠侧栏',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      onPressed: onToggleCollapsed,
                      icon: Icon(
                        Icons.keyboard_double_arrow_left,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _GroupLabel('探索'),
                      for (final dest in AppSidebar._primaryOrder.take(3))
                        _NavRow(
                          icon: shellDestinationIcon(dest),
                          label: dest.label,
                          active: current == dest,
                          onTap: () => onSelect(dest),
                        ),
                      const SizedBox(height: VxSpacing.lg),
                      const _GroupLabel('我的音乐'),
                      _NavRow(
                        icon: Icons.library_music_outlined,
                        label: ShellDestination.library.label,
                        active: current == ShellDestination.library,
                        onTap: () => onSelect(ShellDestination.library),
                      ),
                      const SizedBox(height: VxSpacing.lg),
                      _PlaylistSection(model: model, onSelect: onSelect),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // P1-09：分隔线随主题亮暗取 token。
                    Divider(
                      height: 1,
                      color: VxChrome.divider(Theme.of(context).brightness),
                    ),
                    const SizedBox(height: 8),
                    _NavRow(
                      icon: Icons.download_outlined,
                      label: ShellDestination.downloads.label,
                      active: current == ShellDestination.downloads,
                      onTap: () => onSelect(ShellDestination.downloads),
                    ),
                    _NavRow(
                      icon: Icons.settings_outlined,
                      label: ShellDestination.settings.label,
                      active: current == ShellDestination.settings,
                      onTap: () => onSelect(ShellDestination.settings),
                    ),
                    _NavRow(
                      icon: Icons.help_outline,
                      label: ShellDestination.help.label,
                      active: current == ShellDestination.help,
                      onTap: () => onSelect(ShellDestination.help),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 右缘拖动把手（§7.1 240–300）：把手在侧栏右缘 = 与内容区的
        // 内边缘，delta 为 width + dx（与 ContextPanel 左缘镜像相反）。
        if (onWidthChanged != null)
          Align(
            alignment: Alignment.centerRight,
            child: _SidebarResizeHandle(
              key: const ValueKey('sidebar-resize-handle'),
              width: width,
              onWidthChanged: onWidthChanged!,
            ),
          ),
      ],
    );
  }
}

/// 右缘拖动把手：§7.1 240–300px（结构抄 ContextPanel._ResizeHandle，
/// 方向镜像：侧栏贴窗口左缘，向右拖为加宽）。
class _SidebarResizeHandle extends StatelessWidget {
  const _SidebarResizeHandle({
    super.key,
    required this.width,
    required this.onWidthChanged,
  });

  final double width;
  final ValueChanged<double> onWidthChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          onWidthChanged(
            (width + details.delta.dx).clamp(
              ShellBreakpoints.sidebarMinWidth,
              ShellBreakpoints.sidebarMaxWidth,
            ),
          );
        },
        child: SizedBox(width: 8, height: double.infinity),
      ),
    );
  }
}

// ── 折叠态 ──────────────────────────────────────────────────────────────

class _CollapsedSidebar extends StatelessWidget {
  const _CollapsedSidebar({
    required this.model,
    required this.current,
    required this.onSelect,
    this.onToggleCollapsed,
  });

  final AppModel model;
  final ShellDestination current;
  final ValueChanged<ShellDestination> onSelect;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    Widget icon(IconData data, String tooltip, ShellDestination dest) {
      final active = current == dest;
      final scheme = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(VxRadius.sm),
          onTap: () => onSelect(dest),
          child: Tooltip(
            message: tooltip,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: active ? scheme.surfaceContainerHighest : null,
                borderRadius: BorderRadius.circular(VxRadius.sm),
              ),
              child: Icon(
                data,
                size: 20,
                color: active ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: ShellBreakpoints.sidebarCollapsedWidth,
      child: Column(
        children: [
          // Phase 6：折叠态展开钮（与展开态折叠钮成对，§7.2 用户可逆）。
          if (onToggleCollapsed != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: IconButton(
                tooltip: '展开侧栏',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: onToggleCollapsed,
                icon: Icon(
                  Icons.keyboard_double_arrow_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            const SizedBox(height: 14),
          for (final dest in AppSidebar._primaryOrder.take(3))
            icon(shellDestinationIcon(dest), dest.label, dest),
          const SizedBox(height: 10),
          icon(
            Icons.library_music_outlined,
            ShellDestination.library.label,
            ShellDestination.library,
          ),
          const Spacer(),
          icon(
            Icons.download_outlined,
            ShellDestination.downloads.label,
            ShellDestination.downloads,
          ),
          icon(
            Icons.settings_outlined,
            ShellDestination.settings.label,
            ShellDestination.settings,
          ),
          icon(
            Icons.help_outline,
            ShellDestination.help.label,
            ShellDestination.help,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// ShellDestination → 导航图标（桌面侧栏与手机底部导航/Rail 共享，Phase 7 提取公开）。
IconData shellDestinationIcon(ShellDestination dest) => switch (dest) {
  ShellDestination.home => Icons.home_outlined,
  ShellDestination.discover => Icons.explore_outlined,
  ShellDestination.search => Icons.search,
  ShellDestination.library => Icons.library_music_outlined,
  ShellDestination.downloads => Icons.download_outlined,
  ShellDestination.settings => Icons.settings_outlined,
  ShellDestination.help => Icons.help_outline,
};

// ── 公共小件 ────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 7),
      child: Text(
        text.toUpperCase(),
        style: VxTypography.eyebrow.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? scheme.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (active)
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(right: 9),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                else
                  const SizedBox(width: 12),
                Icon(
                  icon,
                  size: 20,
                  color: active ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 我的歌单：真实自建歌单（AppModel.state.customPlaylists），无假数据。
class _PlaylistSection extends StatelessWidget {
  const _PlaylistSection({required this.model, required this.onSelect});

  final AppModel model;
  final ValueChanged<ShellDestination> onSelect;

  /// §3.4：首屏最多 5–7 项，超出进入「查看全部」。
  static const _maxVisible = 7;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final playlists = model.state.customPlaylists;
        final shown = playlists.take(_maxVisible).toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '我的歌单',
                      style: VxTypography.eyebrow.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '${playlists.length}',
                    style: VxTypography.caption.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                child: Text(
                  '暂无自建歌单',
                  style: VxTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final playlist in shown)
                _PlaylistTile(model: model, playlist: playlist),
            if (playlists.length > _maxVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => onSelect(ShellDestination.library),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 30),
                    ),
                    child: const Text('查看全部'),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.model, required this.playlist});

  final AppModel model;
  final bridge.CustomPlaylistSummaryDto playlist;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          // 侧栏是内容区 Navigator 的兄弟子树，`Navigator.of(context)` 会
          // 解析到根路由（整页覆盖壳层，PlayerBar 全没）；经 nav_bus 的
          // contentNavigatorKey 显式落内容区（§7.5 播放器跨页面保持）。
          onTap: () => contentNavigatorKey.currentState?.push(
            MaterialPageRoute<void>(
              builder: (_) => CustomPlaylistDetailPage(model, playlist),
            ),
          ),
          child: Container(
            height: 31,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(
                  Icons.queue_music_outlined,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${playlist.songCount}',
                  style: VxTypography.caption.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

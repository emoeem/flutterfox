// ignore_for_file: deprecated_member_use // window_manager 0.6 把 0.5.x API 移入 legacy.dart 桥接层(changelog 指定迁移路径), 后续大版本切 native API
/// Phase 2 桌面顶部 Header（计划书 §3.3，应用唯一窗口标题/工具栏）。
///
/// 从左至右：品牌字标（宽度与 Sidebar 对齐）/ 后退前进（仅页面导航历史）/
/// 全局搜索框（Ctrl+K 聚焦，提交后进入搜索页）/ 音源入口 / 右栏面板开关
/// （正在播放 · 歌词 · 队列）/ 窗口控制（接 window_manager）。
///
/// 禁止页面内部再出现第二套标题栏或窗口控制（§3.3）。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/legacy.dart';

import '../app_model.dart';
import '../design_system/design_tokens.dart';
import '../myune/page/setting/settings_provider.dart';
import 'context_panel.dart';
import 'responsive_shell.dart';

/// 窗口部件（拖动区/窗控按钮）只在桌面平台进树：window_manager 0.5.2
/// 仅声明 linux/macos/windows 平台实现，触屏平台调用必抛
/// MissingPluginException（Phase 7 平台安全引导）。
bool get _hasDesktopWindow => !isTouchPlatform;

/// 顶部 Header。
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.model,
    required this.sidebarWidth,
    required this.canBack,
    required this.canForward,
    required this.onBack,
    required this.onForward,
    required this.searchFocusNode,
    required this.onSearchSubmit,
    required this.contextOpen,
    required this.contextTab,
    required this.onTogglePanel,
    required this.onOpenSidebar,
  });

  final AppModel model;

  /// 品牌区宽度（与 Sidebar 对齐：240 / 72 / 0 隐藏）。
  final double sidebarWidth;

  final bool canBack;
  final bool canForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  /// Ctrl+K 聚焦目标（Shell 持有，Header 只挂到输入框）。
  final FocusNode searchFocusNode;

  /// 提交搜索关键字（Shell 负责切到搜索页并填充）。
  final ValueChanged<String> onSearchSubmit;

  final bool contextOpen;
  final ContextTab contextTab;

  /// 打开/切换/关闭右栏面板（同 Tab 再次点击为关闭）。
  final ValueChanged<ContextTab> onTogglePanel;

  /// <960 降级布局下打开侧栏浮层。
  final VoidCallback onOpenSidebar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ShellBreakpoints.headerHeight,
      decoration: const BoxDecoration(
        color: VxColors.surface1,
        border: Border(bottom: BorderSide(color: VxColors.divider)),
      ),
      child: Stack(
        children: [
          // 空白处可拖动窗口（自绘标题栏，无系统标题栏；仅桌面平台）。
          if (_hasDesktopWindow)
            Positioned.fill(
              child: DragToMoveArea(child: const SizedBox.expand()),
            ),
          Row(
            children: [
              _brandZone(context),
              const SizedBox(width: 4),
              _navHistoryButtons(context),
              const SizedBox(width: 12),
              Expanded(child: _searchField(context)),
              const SizedBox(width: 12),
              _sourceEntry(context),
              const SizedBox(width: 6),
              _panelToggles(context),
              // 窗控（最小化/最大化/关闭）仅桌面平台进树。
              if (_hasDesktopWindow) ...[
                const SizedBox(width: 6),
                const _WindowControls(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // 品牌区：宽度与 Sidebar 对齐；<960 隐藏侧栏时先给菜单按钮。
  Widget _brandZone(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final menuButton = sidebarWidth == 0
        ? IconButton(
            tooltip: '打开导航',
            onPressed: onOpenSidebar,
            icon: const Icon(Icons.menu),
          )
        : null;
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [VxColors.accent, VxColors.accentDeep],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            'V',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: VxColors.onAccent,
              height: 1,
            ),
          ),
        ),
        if (sidebarWidth >= ShellBreakpoints.sidebarWidth) ...[
          const SizedBox(width: 11),
          Text(
            'VOICEFOX',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: scheme.onSurface,
            ),
          ),
        ],
      ],
    );
    // 侧栏隐藏（<960）时品牌区不再与侧栏对齐，直接跟在菜单按钮后。
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?menuButton,
        if (sidebarWidth == 0)
          Padding(padding: const EdgeInsets.only(left: 6), child: brand)
        else
          SizedBox(width: sidebarWidth, child: brand),
      ],
    );
  }

  Widget _navHistoryButtons(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '后退',
          onPressed: canBack ? onBack : null,
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 17,
            color: canBack ? scheme.onSurfaceVariant : scheme.onSurface.withValues(alpha: 0.25),
          ),
        ),
        const SizedBox(width: 2),
        IconButton(
          tooltip: '前进',
          onPressed: canForward ? onForward : null,
          icon: Icon(
            Icons.arrow_forward_ios,
            size: 17,
            color: canForward ? scheme.onSurfaceVariant : scheme.onSurface.withValues(alpha: 0.25),
          ),
        ),
      ],
    );
  }

  Widget _searchField(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SizedBox(
          height: 36,
          child: TextField(
            focusNode: searchFocusNode,
            textInputAction: TextInputAction.search,
            onSubmitted: onSearchSubmit,
            style: TextStyle(fontSize: 13, color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: '搜索歌曲、专辑、歌手或歌单',
              hintStyle: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
              prefixIcon: Icon(Icons.search, size: 18, color: scheme.onSurfaceVariant),
              prefixIconConstraints: const BoxConstraints(minWidth: 36),
              suffixIcon: _KbdChip(),
              suffixIconConstraints: const BoxConstraints(minWidth: 0),
              isDense: true,
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VxRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 音源状态入口：展示真实音源能力列表（AppModel.state.sources），
  // 选择后进入搜索页（页内筛选，Phase 4 重做发现/搜索时完善交互）。
  Widget _sourceEntry(BuildContext context) {
    final sources = model.state.sources;
    return PopupMenuButton<Object?>(
      tooltip: '音源',
      onSelected: (_) => onSearchSubmit(''),
      itemBuilder: (context) => [
        const PopupMenuItem<Object?>(
          enabled: false,
          height: 34,
          child: Text('聚合搜索 · 全部音源', style: TextStyle(fontSize: 12.5)),
        ),
        if (sources.isEmpty)
          const PopupMenuItem<Object?>(
            enabled: false,
            height: 34,
            child: Text('音源加载中…', style: TextStyle(fontSize: 12.5)),
          )
        else
          for (final source in sources)
            PopupMenuItem<Object?>(
              value: source.id,
              height: 36,
              child: Text(
                source.name,
                style: const TextStyle(fontSize: 12.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
      ],
      icon: const Icon(Icons.radio_button_checked, size: 18),
    );
  }

  Widget _panelToggles(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PanelToggle(
          tooltip: '正在播放面板',
          icon: Icons.album_outlined,
          active: contextOpen && contextTab == ContextTab.nowPlaying,
          onTap: () => onTogglePanel(ContextTab.nowPlaying),
        ),
        _PanelToggle(
          tooltip: '歌词面板',
          icon: Icons.lyrics_outlined,
          active: contextOpen && contextTab == ContextTab.lyrics,
          onTap: () => onTogglePanel(ContextTab.lyrics),
        ),
        _PanelToggle(
          tooltip: '队列面板',
          icon: Icons.queue_music_outlined,
          active: contextOpen && contextTab == ContextTab.queue,
          onTap: () => onTogglePanel(ContextTab.queue),
        ),
      ],
    );
  }
}

/// `Ctrl K` 键位提示小片（概念稿 .search kbd）。
class _KbdChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'Ctrl K',
        style: TextStyle(
          fontSize: 10.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PanelToggle extends StatelessWidget {
  const _PanelToggle({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 19,
        color: active ? scheme.primary : scheme.onSurfaceVariant,
      ),
    );
  }
}

/// 窗口控制：最小化（尊重「最小化到托盘」设置）/ 最大化还原 / 关闭。
class _WindowControls extends StatelessWidget {
  const _WindowControls();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          icon: Icons.remove,
          tooltip: '最小化',
          onPressed: () {
            if (settings.minimizeToTray) {
              windowManager.hide();
            } else {
              windowManager.minimize();
            }
          },
        ),
        const _MaximizeButton(),
        _WindowButton(
          icon: Icons.close,
          tooltip: '关闭',
          onPressed: windowManager.close,
        ),
        const SizedBox(width: 2),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 38,
            height: ShellBreakpoints.headerHeight,
            color: _hovering
                ? scheme.onSurface.withValues(alpha: 0.08)
                : Colors.transparent,
            child: Icon(widget.icon, size: 16, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// 最大化/还原按钮：经 WindowListener 跟随真实窗口状态切换图标。
class _MaximizeButton extends StatefulWidget {
  const _MaximizeButton();

  @override
  State<_MaximizeButton> createState() => _MaximizeButtonState();
}

class _MaximizeButtonState extends State<_MaximizeButton> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    return _WindowButton(
      icon: _maximized ? Icons.filter_none : Icons.crop_square,
      tooltip: _maximized ? '还原' : '最大化',
      onPressed: () async {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
    );
  }
}

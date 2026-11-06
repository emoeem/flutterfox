/// 设置页（§4.9）：左侧分类导航 + 右侧分组设置，不是第二个主工作台。
///
/// - 分类：播放与音效 / 音源 / 下载 / 歌词 / 外观 / 网络 / 账号与集成 /
///   快捷键 / 关于；
/// - 设置项密度统一：单项最小高 52px；开关与 label 就近排列；
/// - 滑杆最大宽 320px（Phase 0 S2：超宽 slider 修复）；
/// - 44 个主题收进外观组的小预览卡网格，密度统一（Phase 0 S3 修复）；
/// - QR 登录走独立对话框，登录状态有明确反馈；
/// - 配置走 ConfigDto 子集；明暗三态写入 theme.mode（Rust ThemeConfig）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../config_ext.dart';
import '../design_system/design_tokens.dart';
import '../theme/registry.dart';
import '../theme/voicefox_theme.dart' show buildVoicefoxTheme;
import 'help_page.dart';
import 'qr_login_page.dart';

/// 设置分类。
enum SettingsSection {
  playback('播放与音效', Icons.graphic_eq_outlined),
  sources('音源', Icons.source_outlined),
  download('下载', Icons.download_outlined),
  lyrics('歌词', Icons.lyrics_outlined),
  appearance('外观', Icons.palette_outlined),
  network('网络', Icons.lan_outlined),
  account('账号与集成', Icons.qr_code_2),
  shortcuts('快捷键', Icons.keyboard_outlined),
  about('关于', Icons.info_outline);

  const SettingsSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class SettingsPage extends StatelessWidget {
  final AppModel model;

  /// 初始分组（VOICEFOX_START_SECTION，验收截图用）；null 从播放开始。
  final SettingsSection? initialSection;

  const SettingsPage(this.model, {super.key, this.initialSection});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        if (model.config == null) {
          // 不用 CircularProgressIndicator：Shell 的 IndexedStack 会常驻
          // 构建本页，无限动画会让 pumpAndSettle 永不收敛。
          return const Center(child: Text('配置加载中…'));
        }
        return _SettingsBody(model: model, initialSection: initialSection);
      },
    );
  }
}

class _SettingsBody extends StatefulWidget {
  final AppModel model;

  /// 初始分组（验收截图用）；null 从播放开始。
  final SettingsSection? initialSection;

  const _SettingsBody({required this.model, this.initialSection});

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  late SettingsSection _section =
      widget.initialSection ?? SettingsSection.playback;

  AppModel get _model => widget.model;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 208, child: _nav(context)),
              const VerticalDivider(width: 1),
              Expanded(child: _content(context)),
            ],
          );
        }
        // 窄窗降级：分类变横向胶囊行。
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: VxSpacing.lg,
                vertical: VxSpacing.sm,
              ),
              child: Row(
                children: [
                  for (final section in SettingsSection.values)
                    _navChip(context, section),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _content(context)),
          ],
        );
      },
    );
  }

  Widget _nav(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        VxSpacing.md,
        VxSpacing.lg,
        VxSpacing.md,
        VxSpacing.xl,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: VxSpacing.sm,
            bottom: VxSpacing.md,
          ),
          child: Text(
            '设置',
            style: VxTypography.h2.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        for (final section in SettingsSection.values)
          _navItem(context, section),
      ],
    );
  }

  Widget _navItem(BuildContext context, SettingsSection section) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _section == section;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(VxRadius.md),
        onTap: () => setState(() => _section = section),
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: VxSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(VxRadius.md),
          ),
          child: Row(
            children: [
              Icon(
                section.icon,
                size: 18,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: VxSpacing.md),
              Expanded(
                child: Text(
                  section.label,
                  style: VxTypography.titleSm.copyWith(
                    color: selected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navChip(BuildContext context, SettingsSection section) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _section == section;
    return Padding(
      padding: const EdgeInsets.only(right: VxSpacing.sm),
      child: ChoiceChip(
        label: Text(section.label),
        selected: selected,
        avatar: Icon(
          section.icon,
          size: 16,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
        onSelected: (_) => setState(() => _section = section),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        VxSpacing.xl,
        VxSpacing.lg,
        VxSpacing.xl,
        VxSpacing.xxl,
      ),
      children: [
        for (final group in _groups(context)) group,
      ],
    );
  }

  List<Widget> _groups(BuildContext context) {
    final config = _model.config;
    if (config == null) return const [];
    return switch (_section) {
      SettingsSection.playback => [
          _group(
            context,
            '播放',
            [
              _VolumeRow(model: _model, volume: config.volume),
              _playModeRow(context, config),
              _sliderRow(
                title: '历史记录条数',
                valueText: '${config.historyLimit} 条',
                slider: Slider(
                  min: 10,
                  max: 500,
                  divisions: 49,
                  label: '${config.historyLimit}',
                  value: config.historyLimit.clamp(10, 500).toDouble(),
                  onChanged: (value) => _model.updateConfig(
                    (config) => config.copyWith(historyLimit: value.round()),
                  ),
                ),
              ),
            ],
          ),
        ],
      SettingsSection.sources => [
          _group(
            context,
            '音源选择',
            [
              _defaultSourceRow(context, config),
              _switchRow(
                title: 'JS 自定义音源优先',
                subtitle: '解析播放地址时先尝试 lx-music 自定义音源',
                value: config.jsSourcesFirst,
                onChanged: (value) => _model.updateConfig(
                  (config) => config.copyWith(jsSourcesFirst: value),
                ),
              ),
            ],
          ),
          _group(
            context,
            '启用的音源',
            [
              for (final source in _model.state.sources)
                _switchRow(
                  title: source.name,
                  value: config.enabledSources.contains(source.id),
                  onChanged: (value) {
                    final enabled = Set<String>.from(config.enabledSources);
                    value ? enabled.add(source.id) : enabled.remove(source.id);
                    // 至少保留一个音源，避免搜索/播放全面失效。
                    if (enabled.isEmpty) return;
                    _model.updateConfig(
                      (config) =>
                          config.copyWith(enabledSources: enabled.toList()),
                    );
                  },
                ),
              if (_model.state.sources.isEmpty)
                _row(title: '音源能力尚未加载', subtitle: '启动后自动刷新'),
            ],
          ),
        ],
      SettingsSection.download => [
          _group(
            context,
            '下载目录与音质',
            [
              _TextFieldRow(
                label: '下载目录',
                hint: '/home/用户名/Music',
                initial: config.downloadDir,
                onSubmit: (value) => _model.updateConfig(
                  (config) => config.copyWith(downloadDir: value.trim()),
                ),
              ),
              _qualityRow(context, config),
            ],
          ),
          _group(
            context,
            '并发',
            [
              _sliderRow(
                title: '同时下载数',
                valueText: '${config.downloadConcurrency} 首',
                slider: Slider(
                  min: 1,
                  max: 8,
                  divisions: 7,
                  label: '${config.downloadConcurrency}',
                  value: config.downloadConcurrency.clamp(1, 8).toDouble(),
                  onChanged: (value) => _model.updateConfig(
                    (config) =>
                        config.copyWith(downloadConcurrency: value.round()),
                  ),
                ),
              ),
            ],
          ),
        ],
      SettingsSection.lyrics => [
          _group(
            context,
            '歌词显示',
            [
              _switchRow(
                title: '显示翻译',
                subtitle: '有翻译歌词时在歌词面板中同时展示',
                value: config.showTranslation,
                onChanged: (value) => _model.updateConfig(
                  (config) => config.copyWith(showTranslation: value),
                ),
              ),
              _switchRow(
                title: '逐字歌词 (YRC)',
                subtitle: '支持逐字 Karaoke 效果的歌词按逐字模式渲染',
                value: config.showYrc,
                onChanged: (value) => _model.updateConfig(
                  (config) => config.copyWith(showYrc: value),
                ),
              ),
            ],
          ),
        ],
      SettingsSection.appearance => [
          _group(
            context,
            '明暗',
            [
              _themeModeRow(context, config),
              _switchRow(
                title: '跟随系统动态取色',
                subtitle: '开启时优先用系统 Material You 调色板',
                value: config.dynamicColor,
                onChanged: (value) => _model.updateConfig(
                  (config) => config.copyWith(dynamicColor: value),
                ),
              ),
            ],
          ),
          _group(
            context,
            '同步主题（与 TUI 同源）',
            [
              Padding(
                padding: const EdgeInsets.all(VxSpacing.md),
                child: Wrap(
                  spacing: VxSpacing.sm,
                  runSpacing: VxSpacing.sm,
                  children: [
                    for (final entry in kSyncedThemes)
                      _ThemeCard(
                        entry: entry,
                        selected: _model.themeKey == entry.key,
                        onTap: () => _model.setTheme(entry.key),
                      ),
                  ],
                ),
              ),
            ],
          ),
          _group(
            context,
            '内置扩展（flex_color_scheme）',
            [
              Padding(
                padding: const EdgeInsets.all(VxSpacing.md),
                child: Wrap(
                  spacing: VxSpacing.sm,
                  runSpacing: VxSpacing.sm,
                  children: [
                    for (final entry in [kFlClashTheme, ...kBuiltinThemes])
                      _ThemeCard(
                        entry: entry,
                        selected: _model.themeKey == entry.key,
                        onTap: () => _model.setTheme(entry.key),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      SettingsSection.network => [
          _group(
            context,
            '代理',
            [
              _TextFieldRow(
                label: '代理地址',
                hint: 'http://127.0.0.1:7890（留空直连）',
                initial: config.proxyUrl,
                onSubmit: (value) => _model.updateConfig(
                  (config) => config.copyWith(proxyUrl: value.trim()),
                ),
              ),
            ],
          ),
          _group(
            context,
            '超时',
            [
              _sliderRow(
                title: '请求超时',
                valueText: '${config.networkTimeoutSecs.toInt()} 秒',
                slider: Slider(
                  min: 5,
                  max: 60,
                  divisions: 11,
                  label: '${config.networkTimeoutSecs.toInt()}',
                  value: config.networkTimeoutSecs
                      .toInt()
                      .clamp(5, 60)
                      .toDouble(),
                  onChanged: (value) => _model.updateConfig(
                    (config) => config.copyWith(
                      networkTimeoutSecs: BigInt.from(value.round()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      SettingsSection.account => [
          _group(
            context,
            '账号登录',
            [
              _row(
                title: '扫码登录',
                subtitle: '网易云 / QQ 音乐 / 酷狗 / 哔哩哔哩；登录状态在对话框内反馈',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openQrLogin(context),
              ),
            ],
          ),
        ],
      SettingsSection.shortcuts => [
          _group(
            context,
            '播放',
            [
              _shortcutRow('空格', '播放 / 暂停'),
              _shortcutRow('← / →', '快退 / 快进 5 秒'),
            ],
          ),
          _group(
            context,
            '导航',
            [
              _shortcutRow('Ctrl / ⌘ + K', '聚焦全局搜索'),
              _shortcutRow('Esc', '关闭浮层 / 返回'),
              _shortcutRow('Enter', '播放选中歌曲（列表内）'),
              _shortcutRow('双击歌曲行', '从该歌曲开始播放'),
            ],
          ),
        ],
      SettingsSection.about => [
          _group(
            context,
            '关于 voicefox',
            [
              _row(title: '版本', subtitle: appVersion),
              _row(title: '前端', subtitle: 'Flutter + flutter_rust_bridge'),
              _row(
                title: '核心',
                subtitle: '与 TUI 版共用同一套 Rust 播放 / 音源 / 存储实现',
              ),
              _row(
                title: '帮助与关于',
                subtitle: '功能地图、自建歌单说明、版本信息',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('帮助与关于')),
                      body: const HelpPage(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
    };
  }

  // ── 行构建 ──

  /// 通用设置行：最小高 52px；开关等控件与 label 同行就近排列。
  Widget _row({
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(
          horizontal: VxSpacing.lg,
          vertical: VxSpacing.sm + 2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: VxTypography.body.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: VxTypography.caption.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
            const SizedBox(width: VxSpacing.xs),
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _row(
      title: title,
      subtitle: subtitle,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  /// 滑杆行：label 在上、滑杆限宽 320px（Phase 0 S2 修复）。
  Widget _sliderRow({
    required String title,
    required String valueText,
    required Widget slider,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(
        horizontal: VxSpacing.lg,
        vertical: VxSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: VxTypography.body.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(width: VxSpacing.sm),
              Text(
                valueText,
                style: VxTypography.mono.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: slider,
          ),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, String title, List<Widget> children) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: VxSpacing.lg),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(VxRadius.lg),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                VxSpacing.lg,
                VxSpacing.md,
                VxSpacing.lg,
                VxSpacing.xs,
              ),
              child: Text(
                title,
                style: VxTypography.titleSm.copyWith(color: scheme.primary),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  // ── 各分类的专用行 ──

  Widget _playModeRow(BuildContext context, bridge.ConfigDto config) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(
        VxSpacing.lg,
        VxSpacing.sm,
        VxSpacing.lg,
        VxSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '播放模式',
            style: VxTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: VxSpacing.sm),
          Wrap(
            spacing: VxSpacing.sm,
            children: [
              for (final mode in const [
                ('none', '顺序'),
                ('list-loop', '列表循环'),
                ('single-loop', '单曲循环'),
                ('random', '随机'),
              ])
                ChoiceChip(
                  label: Text(mode.$2),
                  selected: config.playMode == mode.$1,
                  onSelected: (_) => _model.updateConfig(
                    (config) => config.copyWith(playMode: mode.$1),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _defaultSourceRow(
    BuildContext context,
    bridge.ConfigDto config,
  ) {
    final ids = [for (final source in _model.state.sources) source.id];
    final value = ids.contains(config.defaultSource)
        ? config.defaultSource
        : (ids.isEmpty ? null : ids.first);
    return _row(
      title: '默认音源',
      subtitle: ids.isEmpty ? '音源能力尚未加载' : null,
      trailing: DropdownButton<String>(
        value: value,
        items: [
          for (final source in _model.state.sources)
            DropdownMenuItem(value: source.id, child: Text(source.name)),
        ],
        onChanged: (value) {
          if (value == null) return;
          _model.updateConfig(
            (config) => config.copyWith(defaultSource: value),
          );
        },
      ),
    );
  }

  Widget _qualityRow(BuildContext context, bridge.ConfigDto config) {
    return _row(
      title: '音质偏好',
      subtitle: '下载时优先使用的音质；音源没有该音质时自动降级',
      trailing: DropdownButton<String>(
        value: config.downloadQuality ?? '320k',
        items: const [
          DropdownMenuItem(value: '128k', child: Text('128k')),
          DropdownMenuItem(value: '320k', child: Text('320k')),
          DropdownMenuItem(value: 'flac', child: Text('FLAC')),
          DropdownMenuItem(value: 'flac24bit', child: Text('FLAC 24bit')),
        ],
        onChanged: (value) {
          if (value == null) return;
          _model.updateConfig(
            (config) => config.copyWith(downloadQuality: value),
          );
        },
      ),
    );
  }

  Widget _themeModeRow(BuildContext context, bridge.ConfigDto config) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(
        VxSpacing.lg,
        VxSpacing.sm,
        VxSpacing.lg,
        VxSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '明暗模式',
            style: VxTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: VxSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'system', label: Text('跟随系统')),
                ButtonSegment(value: 'light', label: Text('浅色')),
                ButtonSegment(value: 'dark', label: Text('深色')),
              ],
              selected: {config.themeMode},
              onSelectionChanged: (value) => _model.updateConfig(
                (config) => config.copyWith(themeMode: value.first),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shortcutRow(String keys, String action) {
    final scheme = Theme.of(context).colorScheme;
    return _row(
      title: action,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(VxRadius.sm),
        ),
        child: Text(
          keys,
          style: VxTypography.mono.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }

  /// QR 登录独立对话框（§4.9：登录状态有明确反馈）。
  Future<void> _openQrLogin(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VxRadius.xl),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  VxSpacing.xl,
                  VxSpacing.lg,
                  VxSpacing.md,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '扫码登录',
                        style: VxTypography.title.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: QrLoginPage(_model),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 文本行：未聚焦时跟随配置刷新，提交才下发（避免每键一次 ConfigUpdate）。
class _TextFieldRow extends StatefulWidget {
  final String label;
  final String hint;
  final String initial;
  final ValueChanged<String> onSubmit;

  const _TextFieldRow({
    required this.label,
    required this.hint,
    required this.initial,
    required this.onSubmit,
  });

  @override
  State<_TextFieldRow> createState() => _TextFieldRowState();
}

class _TextFieldRowState extends State<_TextFieldRow> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void didUpdateWidget(covariant _TextFieldRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.initial != _controller.text) {
      _controller.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(
        horizontal: VxSpacing.lg,
        vertical: VxSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: VxTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: VxSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              decoration: InputDecoration(
                hintText: widget.hint,
                isDense: true,
              ),
              onSubmitted: widget.onSubmit,
            ),
          ),
        ],
      ),
    );
  }
}

/// 音量行：拖动过程中只改本地值，松手才下发命令 + 落配置。
///
/// 之前每个 `onChanged` tick 都发一次 ConfigUpdate：一次拖动几十次 TOML
/// 落盘，同时把 ConfigDto 的往返缺陷放大成配置损坏。
class _VolumeRow extends StatefulWidget {
  final AppModel model;
  final int volume;

  const _VolumeRow({required this.model, required this.volume});

  @override
  State<_VolumeRow> createState() => _VolumeRowState();
}

class _VolumeRowState extends State<_VolumeRow> {
  late double _value = widget.volume.toDouble();
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant _VolumeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && widget.volume != oldWidget.volume) {
      _value = widget.volume.toDouble();
    }
  }

  Future<void> _commit(double value) async {
    _dragging = false;
    final volume = value.round();
    await widget.model.setVolume(volume);
    await widget.model.updateConfig(
      (config) => config.copyWith(volume: volume),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(
        horizontal: VxSpacing.lg,
        vertical: VxSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '音量',
                style: VxTypography.body.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(width: VxSpacing.sm),
              Text(
                '${_value.round()}%',
                style: VxTypography.mono.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Slider(
              max: 100,
              divisions: 20,
              value: _value,
              onChangeStart: (_) => _dragging = true,
              onChanged: (value) => setState(() => _value = value),
              onChangeEnd: _commit,
            ),
          ),
        ],
      ),
    );
  }
}

/// 主题色卡（压缩版）：92px 宽迷你预览 + 名称，44 套主题统一密度收进外观组。
class _ThemeCard extends StatelessWidget {
  final ThemeEntry entry;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = buildVoicefoxTheme(
      entry.key,
      entry.dark ? Brightness.dark : Brightness.light,
    ).colorScheme;
    final outer = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(VxRadius.md),
      onTap: onTap,
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(VxRadius.md),
          border: Border.all(
            color: selected
                ? outer.primary
                : outer.outlineVariant.withValues(alpha: 0.6),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 迷你 wireframe 预览：该主题真实配色的微缩界面。
            Container(
              height: 52,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.onSurface.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _WireRow(color: scheme.surfaceContainerHighest),
                  const SizedBox(height: 3),
                  _WireRow(color: scheme.surfaceContainerHighest),
                  const Spacer(),
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VxTypography.mono.copyWith(
                fontSize: 10,
                color: selected ? outer.primary : outer.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WireRow extends StatelessWidget {
  final Color color;

  const _WireRow({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

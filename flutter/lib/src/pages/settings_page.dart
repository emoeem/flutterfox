/// 设置页：规范 7 组（播放器/音源/下载/歌词/主题/网络/账号集成）。
/// 配置走 ConfigDto 子集（docs/FLUTTER_MIGRATION_PROGRESS.md Phase 2 决策）；
/// 明暗三态写入 theme.mode（Rust ThemeConfig）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../config_ext.dart';
import '../theme/registry.dart';
import '../theme/voicefox_theme.dart' show buildVoicefoxTheme;
import '../widgets/empty_state.dart' show pageTitle;
import 'help_page.dart';
import 'qr_login_page.dart';

class SettingsPage extends StatelessWidget {
  final AppModel model;

  const SettingsPage(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    final config = model.config;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        pageTitle(context, '设置'),
        _section(
          context,
          icon: Icons.music_note_outlined,
          title: '播放器',
          children: [
            if (config == null)
              const ListTile(title: Text('配置加载中…'))
            else ...[
              _VolumeRow(model: model, volume: config.volume),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('播放模式', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final mode in const [
                          ('none', '顺序'),
                          ('list-loop', '列表'),
                          ('single-loop', '单曲'),
                          ('random', '随机'),
                        ])
                          ChoiceChip(
                            label: Text(mode.$2),
                            selected: config.playMode == mode.$1,
                            onSelected: (_) => model.updateConfig(
                              (config) => config.copyWith(playMode: mode.$1),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              ListTile(
                title: const Text('历史记录条数'),
                subtitle: Slider(
                  min: 10,
                  max: 500,
                  divisions: 49,
                  label: '${config.historyLimit}',
                  value: config.historyLimit.clamp(10, 500).toDouble(),
                  onChanged: (value) => model.updateConfig(
                    (config) =>
                        config.copyWith(historyLimit: value.round()),
                  ),
                ),
              ),
            ],
          ],
        ),
        _section(
          context,
          icon: Icons.source_outlined,
          title: '音源',
          children: [
            if (config == null)
              const ListTile(title: Text('配置加载中…'))
            else ...[
              ListTile(
                title: const Text('默认音源'),
                trailing: DropdownButton<String>(
                  value: _defaultSourceValue(config),
                  items: [
                    for (final source in model.state.sources)
                      DropdownMenuItem(
                        value: source.id,
                        child: Text(source.name),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    model.updateConfig(
                      (config) => config.copyWith(defaultSource: value),
                    );
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('JS 自定义音源优先'),
                subtitle: const Text('解析播放地址时先尝试 lx-music 自定义音源'),
                value: config.jsSourcesFirst,
                onChanged: (value) => model.updateConfig(
                  (config) => config.copyWith(jsSourcesFirst: value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('启用音源', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    for (final source in model.state.sources)
                      SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(source.name),
                        value: config.enabledSources.contains(source.id),
                        onChanged: (value) {
                          final enabled =
                              Set<String>.from(config.enabledSources);
                          value
                              ? enabled.add(source.id)
                              : enabled.remove(source.id);
                          // 至少保留一个音源，避免搜索/播放全面失效。
                          if (enabled.isEmpty) return;
                          model.updateConfig(
                            (config) =>
                                config.copyWith(enabledSources: enabled.toList()),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        _section(
          context,
          icon: Icons.download_outlined,
          title: '下载',
          children: [
            if (config == null)
              const ListTile(title: Text('配置加载中…'))
            else ...[
              _TextFieldRow(
                label: '下载目录',
                hint: '/home/用户名/Music',
                initial: config.downloadDir,
                onSubmit: (value) => model.updateConfig(
                  (config) => config.copyWith(downloadDir: value.trim()),
                ),
              ),
              ListTile(
                title: const Text('音质偏好'),
                trailing: DropdownButton<String>(
                  value: config.downloadQuality ?? '320k',
                  items: const [
                    DropdownMenuItem(value: '128k', child: Text('128k')),
                    DropdownMenuItem(value: '320k', child: Text('320k')),
                    DropdownMenuItem(value: 'flac', child: Text('FLAC')),
                    DropdownMenuItem(
                        value: 'flac24bit', child: Text('FLAC 24bit')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    model.updateConfig(
                      (config) => config.copyWith(downloadQuality: value),
                    );
                  },
                ),
              ),
              ListTile(
                title: Text('同时下载 ${config.downloadConcurrency} 首'),
                subtitle: Slider(
                  min: 1,
                  max: 8,
                  divisions: 7,
                  value: config.downloadConcurrency.clamp(1, 8).toDouble(),
                  onChanged: (value) => model.updateConfig(
                    (config) =>
                        config.copyWith(downloadConcurrency: value.round()),
                  ),
                ),
              ),
            ],
          ],
        ),
        _section(
          context,
          icon: Icons.lyrics_outlined,
          title: '歌词',
          children: [
            if (config == null)
              const ListTile(title: Text('配置加载中…'))
            else ...[
              SwitchListTile(
                title: const Text('显示翻译'),
                value: config.showTranslation,
                onChanged: (value) => model.updateConfig(
                  (config) => config.copyWith(showTranslation: value),
                ),
              ),
              SwitchListTile(
                title: const Text('逐字歌词 (YRC)'),
                value: config.showYrc,
                onChanged: (value) => model.updateConfig(
                  (config) => config.copyWith(showYrc: value),
                ),
              ),
            ],
          ],
        ),
        _section(
          context,
          icon: Icons.palette_outlined,
          title: '主题',
          children: [
            if (config != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Text('明暗', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(width: 16),
                    // 固定宽度：全宽 SegmentedButton 在桌面上是一整条横杠。
                    SizedBox(
                      width: 360,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'system', label: Text('跟随系统')),
                          ButtonSegment(value: 'light', label: Text('浅色')),
                          ButtonSegment(value: 'dark', label: Text('深色')),
                        ],
                        selected: {config.themeMode},
                        onSelectionChanged: (value) => model.updateConfig(
                          (config) => config.copyWith(themeMode: value.first),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _groupLabel(context, '同步主题（与 TUI 同源）'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in kSyncedThemes)
                        _ThemeCard(
                          entry: entry,
                          selected: model.themeKey == entry.key,
                          onTap: () => model.setTheme(entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _groupLabel(context, '内置扩展（flex_color_scheme）'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in [kFlClashTheme, ...kBuiltinThemes])
                        _ThemeCard(
                          entry: entry,
                          selected: model.themeKey == entry.key,
                          onTap: () => model.setTheme(entry.key),
                        ),
                    ],
                  ),
                  if (config != null) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('跟随系统动态取色'),
                      subtitle: const Text('开启时优先用系统 Material You 调色板'),
                      value: config.dynamicColor,
                      onChanged: (value) => model.updateConfig(
                        (config) => config.copyWith(dynamicColor: value),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        _section(
          context,
          icon: Icons.lan_outlined,
          title: '网络',
          children: [
            if (config == null)
              const ListTile(title: Text('配置加载中…'))
            else ...[
              _TextFieldRow(
                label: '代理地址',
                hint: 'http://127.0.0.1:7890（留空直连）',
                initial: config.proxyUrl,
                onSubmit: (value) => model.updateConfig(
                  (config) => config.copyWith(proxyUrl: value.trim()),
                ),
              ),
              ListTile(
                title: Text('请求超时 ${config.networkTimeoutSecs} 秒'),
                subtitle: Slider(
                  min: 5,
                  max: 60,
                  divisions: 11,
                  label: '${config.networkTimeoutSecs}',
                  value: config.networkTimeoutSecs
                      .toInt()
                      .clamp(5, 60)
                      .toDouble(),
                  onChanged: (value) => model.updateConfig(
                    (config) => config.copyWith(
                      networkTimeoutSecs: BigInt.from(value.round()),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        _section(
          context,
          icon: Icons.qr_code_2,
          title: '账号与集成',
          children: [
            ListTile(
              title: const Text('扫码登录'),
              subtitle: const Text('网易云 / QQ 音乐 / 酷狗 / 哔哩哔哩'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('扫码登录')),
                    body: QrLoginPage(model),
                  ),
                ),
              ),
            ),
            ListTile(
              title: const Text('帮助与关于'),
              subtitle: const Text('快捷键、功能地图、版本信息'),
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
    );
  }

  /// 快照尚未加载或默认音源不在启用列表里时，回落到首个启用音源，
  /// 避免 DropdownButton 的 value 不在 items 里直接抛异常。
  String _defaultSourceValue(bridge.ConfigDto config) {
    final ids = [
      for (final source in model.state.sources) source.id,
    ];
    if (ids.contains(config.defaultSource)) return config.defaultSource;
    return ids.first;
  }

  /// 分区卡：图标 + 标题头部，内容行随其后。显式 surfaceContainer
  /// 底色 + 16 圆角，保证分区与页面底色有明确分离。
  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 0,
        color: scheme.surfaceContainer,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _groupLabel(BuildContext context, String text) => Text(
    text,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
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
    return ListTile(
      title: Text(widget.label),
      subtitle: TextField(
        controller: _controller,
        focusNode: _focus,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: widget.onSubmit,
      ),
    );
  }
}

/// 主题色卡：bg + accent 双色块预览，选中描边。
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 116,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 迷你 wireframe 预览：用该主题真实配色画一个微缩界面
            // （顶栏点+两行列表+底部 accent 条），比色块直观。
            Container(
              height: 66,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(7),
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
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: scheme.onSurface.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _WireRow(color: scheme.surfaceContainerHighest),
                  const SizedBox(height: 4),
                  _WireRow(color: scheme.surfaceContainerHighest),
                  const Spacer(),
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
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
    return ListTile(
      title: Text('音量 ${_value.round()}%'),
      subtitle: Slider(
        max: 100,
        divisions: 20,
        value: _value,
        onChangeStart: (_) => _dragging = true,
        onChanged: (value) => setState(() => _value = value),
        onChangeEnd: _commit,
      ),
    );
  }
}

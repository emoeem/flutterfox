/// 设置页 v1：主题选择（16 seed 色卡）+ 播放器/歌词/下载基础项。
/// 配置走 ConfigDto 子集（docs/FLUTTER_MIGRATION_PROGRESS.md Phase 2 决策）。
library;

import 'package:flutter/material.dart';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import '../theme/seed_colors.dart';
import '../theme/voicefox_theme.dart';

class SettingsPage extends StatelessWidget {
  final AppModel model;

  const SettingsPage(this.model, {super.key});

  @override
  Widget build(BuildContext context) {
    final config = model.config;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        _header(context, '主题'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final seed in kSeedThemes)
                  _ThemeCard(
                    seed: seed,
                    selected: model.themeKey == seed.key,
                    onTap: () {
                      model.themeKey = seed.key;
                      model.updateConfig((config) => bridge.ConfigDto(
                            theme: seed.key,
                            volume: config.volume,
                            playbackSpeed: config.playbackSpeed,
                            playMode: config.playMode,
                            historyLimit: config.historyLimit,
                            defaultSource: config.defaultSource,
                            enabledSources: config.enabledSources,
                            jsSourcesFirst: config.jsSourcesFirst,
                            downloadDir: config.downloadDir,
                            downloadQuality: config.downloadQuality,
                            downloadConcurrency: config.downloadConcurrency,
                            showTranslation: config.showTranslation,
                            showYrc: config.showYrc,
                            lyricOffsetMs: config.lyricOffsetMs,
                            proxyUrl: config.proxyUrl,
                            networkTimeoutSecs: config.networkTimeoutSecs,
                          ));
                    },
                  ),
              ],
            ),
          ),
        ),
        _header(context, '歌词'),
        if (config == null)
          const Card(child: ListTile(title: Text('配置加载中…')))
        else ...[
          SwitchListTile(
            title: const Text('显示翻译'),
            value: config.showTranslation,
            onChanged: (value) => model.updateConfig((config) =>
                _with(config, showTranslation: value)),
          ),
          SwitchListTile(
            title: const Text('逐字歌词 (YRC)'),
            value: config.showYrc,
            onChanged: (value) =>
                model.updateConfig((config) => _with(config, showYrc: value)),
          ),
          _header(context, '播放器'),
          ListTile(
            title: Text('音量 ${config.volume}%'),
            subtitle: Slider(
              max: 100,
              divisions: 20,
              value: config.volume.toDouble(),
              onChanged: (value) => model.updateConfig(
                  (config) => _with(config, volume: value.round())),
            ),
          ),
          ListTile(
            title: const Text('播放模式'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'none', label: Text('顺序')),
                ButtonSegment(value: 'list-loop', label: Text('列表')),
                ButtonSegment(value: 'single-loop', label: Text('单曲')),
                ButtonSegment(value: 'random', label: Text('随机')),
              ],
              selected: {config.playMode},
              onSelectionChanged: (selection) => model.updateConfig(
                  (config) => _with(config, playMode: selection.first)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      );

  bridge.ConfigDto _with(
    bridge.ConfigDto config, {
    int? volume,
    String? playMode,
    bool? showTranslation,
    bool? showYrc,
  }) =>
      bridge.ConfigDto(
        theme: config.theme,
        volume: volume ?? config.volume,
        playbackSpeed: config.playbackSpeed,
        playMode: playMode ?? config.playMode,
        historyLimit: config.historyLimit,
        defaultSource: config.defaultSource,
        enabledSources: config.enabledSources,
        jsSourcesFirst: config.jsSourcesFirst,
        downloadDir: config.downloadDir,
        downloadQuality: config.downloadQuality,
        downloadConcurrency: config.downloadConcurrency,
        showTranslation: showTranslation ?? config.showTranslation,
        showYrc: showYrc ?? config.showYrc,
        lyricOffsetMs: config.lyricOffsetMs,
        proxyUrl: config.proxyUrl,
        networkTimeoutSecs: config.networkTimeoutSecs,
      );
}

class _ThemeCard extends StatelessWidget {
  final SeedTheme seed;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.seed,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = buildVoicefoxTheme(seed.key, Brightness.dark);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(8),
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
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: scheme.colorScheme.surface,
                      borderRadius:
                          const BorderRadius.horizontal(left: Radius.circular(6)),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Color(hexOf(seed.accent)),
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(6)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              seed.label,
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

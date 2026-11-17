/// ConfigDto 复制扩展：FRB 生成类字段为 final，设置面统一走这里重建。
/// 新增 ConfigDto 字段时只需改本文件。
library;

import 'bridge/lib.dart' as bridge;

extension ConfigDtoCopy on bridge.ConfigDto {
  bridge.ConfigDto copyWith({
    String? theme,
    bool? dynamicColor,
    String? themeMode,
    int? volume,
    int? historyLimit,
    String? playMode,
    String? defaultSource,
    List<String>? enabledSources,
    bool? jsSourcesFirst,
    String? downloadDir,
    String? downloadQuality,
    int? downloadConcurrency,
    bool? showTranslation,
    bool? showYrc,
    int? lyricOffsetMs,
    String? proxyUrl,
    BigInt? networkTimeoutSecs,
    List<String>? localMusicPaths,
    int? localMusicMaxDepth,
  }) => bridge.ConfigDto(
    theme: theme ?? this.theme,
    dynamicColor: dynamicColor ?? this.dynamicColor,
    themeMode: themeMode ?? this.themeMode,
    volume: volume ?? this.volume,
    playbackSpeed: playbackSpeed,
    playMode: playMode ?? this.playMode,
    historyLimit: historyLimit ?? this.historyLimit,
    defaultSource: defaultSource ?? this.defaultSource,
    enabledSources: enabledSources ?? this.enabledSources,
    jsSourcesFirst: jsSourcesFirst ?? this.jsSourcesFirst,
    downloadDir: downloadDir ?? this.downloadDir,
    downloadQuality: downloadQuality ?? this.downloadQuality,
    downloadConcurrency: downloadConcurrency ?? this.downloadConcurrency,
    showTranslation: showTranslation ?? this.showTranslation,
    showYrc: showYrc ?? this.showYrc,
    lyricOffsetMs: lyricOffsetMs ?? this.lyricOffsetMs,
    proxyUrl: proxyUrl ?? this.proxyUrl,
    networkTimeoutSecs: networkTimeoutSecs ?? this.networkTimeoutSecs,
    localMusicEnabled: localMusicEnabled,
    localMusicPaths: localMusicPaths ?? this.localMusicPaths,
    localMusicMaxDepth: localMusicMaxDepth ?? this.localMusicMaxDepth,
  );
}

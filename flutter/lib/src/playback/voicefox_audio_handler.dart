/// audio_service 前台媒体服务（Phase 8 批次三，任务 3）。
///
/// 承担：前台媒体服务（AndroidManifest 的 mediaPlayback foregroundService，
/// 见 android/app/src/main/AndroidManifest.xml）、媒体通知栏/锁屏控制
/// （BaseAudioHandler 的 playbackState + mediaItem）、耳机按键与音频焦点
/// （audio_service 0.18 内部经 audio_session 处理焦点；拔出耳机经
/// becomeNoisyEventStream 暂停，避免外放突响）、播控中心动作
/// （play/pause/seek/speed 经 SeekHandler 映射到 [MobileAudioPlayer]）。
///
/// 元数据真源：AppModel.state.playback.song（Rust 快照，批次一 playSong
/// 命令后更新）；通知栏不伪造曲目信息，拿不到时用 app 名兜底。
///
/// 蓝牙设备路由（计划书:962-963 只显示系统实际报告的设备）：audio_service
/// 不提供设备枚举，需单独 AudioManager.getDevices 桥接——本轮不做，扩展点
/// 见 [MobileAudioPlayer.enumerateRoutes] 注释。
library;

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import '../app_model.dart';
import 'mobile_audio_player.dart';

/// 初始化 audio_session + audio_service（引导链只调一次；测试不调用——
/// fake 后端路径完全绕开本文件，任务 5）。
///
/// 音频焦点由 audio_session 配置接管（media 类型，暂停后让出焦点）；
/// 耳机拔出（becoming noisy）暂停避免外放突响。
Future<VoicefoxAudioHandler> configureAudioService({
  required VoicefoxAudioHandler handler,
}) async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  // 耳机拔出（becoming noisy）暂停：订阅生命周期与 session 等长，
  // 无需取消（进程级）。
  session.becomingNoisyEventStream.listen((_) {
    unawaited(handler.pause());
  });
  // 音频焦点中断（§10.2：被抢占→暂停；end 且 shouldResume 且抢占前在播
  // →恢复）：订阅生命周期同上（进程级），恢复守卫在 handler 内。
  session.interruptionEventStream.listen(handler.onInterruptionEvent);
  return AudioService.init(
    builder: () => handler,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.voicefox_flutter.playback',
      androidNotificationChannelName: 'voicefox 播放',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

/// voicefox 前台媒体服务 handler。
class VoicefoxAudioHandler extends BaseAudioHandler with SeekHandler {
  VoicefoxAudioHandler({required this.model, required MobileAudioPlayer player})
    : _player = player {
    _subscriptions
      ..add(player.snapshotStream.listen(_onSnapshot))
      ..add(player.eventStream.listen(_onEvent));
    // 曲目元数据跟随 Rust 快照（真源 AppModel）。
    model.addListener(_syncMediaItem);
    _syncMediaItem();
  }

  final MobileAudioPlayer _player;

  /// 曲目元数据真源（Rust 快照经 AppModel；批次一 playSong 命令后更新）。
  final AppModel model;
  final _subscriptions = <StreamSubscription<void>>[];

  /// media actions（通知栏/锁屏/耳机按键/助手 → 统一映射到播放器）。
  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  void _onSnapshot(MobilePlaybackSnapshot snapshot) {
    // 播控状态 + 位置对齐（锁屏/通知栏进度条数据源）。
    playbackState.add(
      playbackState.value.copyWith(
        processingState: switch (snapshot.phase) {
          MobilePlaybackPhase.idle ||
          MobilePlaybackPhase.stopped => AudioProcessingState.idle,
          MobilePlaybackPhase.loading => AudioProcessingState.loading,
          MobilePlaybackPhase.playing ||
          MobilePlaybackPhase.paused => AudioProcessingState.ready,
        },
        playing: snapshot.phase == MobilePlaybackPhase.playing,
        updatePosition: snapshot.position,
        bufferedPosition: snapshot.position,
        systemActions: const {MediaAction.seek},
      ),
    );
  }

  void _onEvent(MobilePlaybackEvent event) {
    // ended：Rust 侧队列推进后快照换曲，MediaItem 随 model 通知更新；
    // 通知栏无额外动作（不伪造曲目）。
    if (event is MobilePlaybackFailed) {
      debugPrint('voicefox/audio-handler: 播放失败 ${event.message}');
    }
  }

  /// AppModel 快照 → MediaItem（真源曲目元数据，无曲目用 app 名兜底）。
  void _syncMediaItem() {
    final song = model.state.playback.song;
    final durationMs = song?.durationMs.toInt() ?? 0;
    // 封面 artUri：null/空串不进通知（Uri.tryParse('') 返回非 null 空 Uri，
    // 会伪造出无图封面 URL，故照 now_playing_page.dart 的 null||isEmpty
    // 守卫惯例先行拦截）；解析失败同样不伪造。
    final coverUrl = song?.coverUrl;
    final artUri = (coverUrl == null || coverUrl.isEmpty)
        ? null
        : Uri.tryParse(coverUrl);
    mediaItem.add(
      MediaItem(
        id: song?.id ?? 'voicefox-now-playing',
        album: (song?.albumName.isNotEmpty ?? false) ? song!.albumName : null,
        title: song?.name ?? 'voicefox',
        artist: (song?.singer.isNotEmpty ?? false) ? song!.singer : null,
        duration: durationMs > 0 ? Duration(milliseconds: durationMs) : null,
        artUri: artUri,
      ),
    );
  }

  /// 音频焦点被抢占前是否在播（快照镜像）：end 事件只有「抢占前确实在播」
  /// 才恢复——抢占期间用户经通知栏/耳机的手动暂停（playbackState 已翻转为
  /// paused）不能被系统恢复事件覆盖用户意图。
  bool _playingBeforeInterruption = false;

  /// audio_session 中断事件（§10.2 音频焦点）：begin → 记录在播快照并
  /// 暂停让出焦点；end 且抢占前在播 → 恢复。注意：audio_session 0.2.4 的
  /// [AudioInterruptionEvent] 只有 begin/type，无 shouldResume 信号（计划
  /// 文本按新版 API 写就，此处按实际版本如实收敛）；duck 类型本轮不做
  /// 压低音量（无对应命令），统一按暂停处理。
  void onInterruptionEvent(AudioInterruptionEvent event) {
    if (event.begin) {
      _playingBeforeInterruption = playbackState.value.playing;
      unawaited(pause());
    } else {
      final wasPlaying = _playingBeforeInterruption;
      _playingBeforeInterruption = false;
      if (wasPlaying) {
        unawaited(play());
      }
    }
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    // 预留：设备路由/均衡器等宿主动作入口（本轮无实现项）。
    await super.customAction(name, extras);
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
  }
}

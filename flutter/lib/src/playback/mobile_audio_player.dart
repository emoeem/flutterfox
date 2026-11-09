/// 移动端音频播放器抽象 + just_audio 实现（Phase 8 批次三）。
///
/// 抽象层 [MobileAudioPlayer] 让 widget 测试注入 fake（不依赖真实平台
/// 通道，批次任务 5）；生产实现 [JustAudioMobilePlayer] 包裹 just_audio，
/// 承接批次一 Rust→Dart 反向信号（application/src/services/host_player.rs
/// 转发的播放指令）：
/// - `AudioSource.uri(headers:)` 逐请求透传音源自定义请求头（playback.rs
///   play_with_headers 解析产物，国内音源必需）；
/// - 播放/暂停/seek/音量与 FfiCommand 语义对齐（批次一 HostPlayerCommand）：
///   volume 0-100 → just_audio 0..1，Seek 毫秒绝对定位，Toggle 由宿主
///   按当前 playing 状态二选一；
/// - 状态/进度/时长经 [snapshotStream] 回流 Rust（host_player_report），
///   完成/失败经 [eventStream] 回流（host_player_report_event，ended 驱动
///   Rust 队列推进，generation 对齐批次一转发语义）。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// 播放相位（与 Rust PlayerState/桥接字符串 idle/loading/playing/paused/
/// stopped 一一对应，见 host_player_report 的 parse_host_state）。
enum MobilePlaybackPhase { idle, loading, playing, paused, stopped }

/// (相位, 位置, 时长) 聚合快照（回流 Rust 的最小单元）。
@immutable
class MobilePlaybackSnapshot {
  const MobilePlaybackSnapshot({
    required this.phase,
    required this.position,
    required this.duration,
  });

  final MobilePlaybackPhase phase;
  final Duration position;
  final Duration duration;
}

/// 离散播放事件（ended 驱动 Rust 队列推进；error 呈现错误）。
sealed class MobilePlaybackEvent {
  const MobilePlaybackEvent({required this.generation});

  /// 事件所属代次（批次一 Play 指令携带，Rust 侧 service.rs:247 依此
  /// 忽略旧代次竞态）。
  final BigInt generation;
}

class MobilePlaybackEnded extends MobilePlaybackEvent {
  const MobilePlaybackEnded({required super.generation});
}

class MobilePlaybackFailed extends MobilePlaybackEvent {
  const MobilePlaybackFailed({
    required super.generation,
    required this.message,
  });

  final String message;
}

/// 移动端音频播放器抽象（测试注入 fake；生产用 [JustAudioMobilePlayer]）。
abstract class MobileAudioPlayer {
  /// 是否正在播放（Toggle 语义需要：宿主按 playing 二选一）。
  bool get playing;

  /// 当前代次（批次一 Play 指令携带；完成事件对齐）。
  BigInt get generation;

  /// 聚合快照流（状态/进度/时长变化时发出）。
  Stream<MobilePlaybackSnapshot> get snapshotStream;

  /// 离散事件流（completed → ended；播放错误 → failed）。
  Stream<MobilePlaybackEvent> get eventStream;

  /// 播放指定 URL（headers 逐请求透传）。
  Future<void> play(
    String url, {
    required BigInt generation,
    required Map<String, String> headers,
  });

  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);

  /// 音量 0..1（Rust SetVolume 0-100 由桥接层折算）。
  Future<void> setVolume(double volume);
  Future<void> setSpeed(double speed);

  /// 蓝牙/有线输出设备路由（批次六预留扩展点）：audio_service 不提供
  /// 设备枚举，计划书:962-963 要求只显示系统实际报告的设备，需单独
  /// AudioManager.getDevices 桥接；当前不实现、不显示任何设备。
  // Future<List<AudioRouteInfo>> enumerateRoutes();

  Future<void> dispose();
}

/// just_audio 生产实现。
class JustAudioMobilePlayer implements MobileAudioPlayer {
  JustAudioMobilePlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _subscriptions.addAll([
      _player.playerStateStream.listen(_onPlayerState),
      _player.positionStream.listen(_onPosition),
      _player.durationStream.listen(_onDuration),
      _player.playbackEventStream.listen(
        null,
        onError: (Object error) {
          _events.add(
            MobilePlaybackFailed(generation: _generation, message: '$error'),
          );
        },
      ),
    ]);
  }

  final AudioPlayer _player;
  final _subscriptions = <StreamSubscription<void>>[];
  final _snapshots = StreamController<MobilePlaybackSnapshot>.broadcast();
  final _events = StreamController<MobilePlaybackEvent>.broadcast();

  BigInt _generation = BigInt.zero;
  MobilePlaybackPhase _phase = MobilePlaybackPhase.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  /// just_audio 处理状态 → 桥接相位（host_player_report 的状态字符串
  /// 与 Rust parse_host_state 一一对应）。
  static MobilePlaybackPhase _mapPhase(ProcessingState state, bool playing) =>
      switch (state) {
        ProcessingState.idle => MobilePlaybackPhase.idle,
        ProcessingState.loading ||
        ProcessingState.buffering => MobilePlaybackPhase.loading,
        ProcessingState.ready =>
          playing ? MobilePlaybackPhase.playing : MobilePlaybackPhase.paused,
        ProcessingState.completed => MobilePlaybackPhase.stopped,
      };

  void _onPlayerState(PlayerState state) {
    final phase = _mapPhase(state.processingState, state.playing);
    if (state.processingState == ProcessingState.completed) {
      // 完成：先发 ended（Rust 队列推进），相位按 stopped 回流。
      _events.add(MobilePlaybackEnded(generation: _generation));
    }
    _phase = phase;
    _emit();
  }

  void _onPosition(Duration position) {
    _position = position;
    _emit();
  }

  void _onDuration(Duration? duration) {
    _duration = duration ?? Duration.zero;
    _emit();
  }

  void _emit() {
    _snapshots.add(
      MobilePlaybackSnapshot(
        phase: _phase,
        position: _position,
        duration: _duration,
      ),
    );
  }

  @override
  bool get playing => _player.playing;

  @override
  BigInt get generation => _generation;

  @override
  Stream<MobilePlaybackSnapshot> get snapshotStream => _snapshots.stream;

  @override
  Stream<MobilePlaybackEvent> get eventStream => _events.stream;

  @override
  Future<void> play(
    String url, {
    required BigInt generation,
    required Map<String, String> headers,
  }) async {
    _generation = generation;
    // AudioSource.uri(headers:)：国内音源自定义请求头逐请求透传
    // （漏接会大面积播放失败且桌面无此问题）。
    await _player.setAudioSource(
      AudioSource.uri(Uri.parse(url), headers: headers),
    );
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.play();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 1.0));

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _snapshots.close();
    await _events.close();
    await _player.dispose();
  }
}

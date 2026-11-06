/// Rust→Dart 播放指令桥（Phase 8 批次三：just_audio 承接 + 回流）。
///
/// 链路：批次一 Rust 侧 HostPlayerBackend 把播放指令经 broadcast 通道
/// 转发（Rust→Dart），本类消费指令并驱动 [MobileAudioPlayer]（生产
/// just_audio / 测试 fake），再把真实 state/position/duration 与
/// ended/error 事件经 [HostStateSink] 回流 Rust（hostPlayerReport /
/// hostPlayerReportEvent，喂 service.rs 观察者泵 → 既有 Flutter 事件流）。
///
/// FfiCommand 语义对齐（批次一 HostPlayerCommand）：
/// - Play：AudioSource.uri(headers:) 逐请求透传自定义请求头；
/// - SetVolume 0-100 → 播放器 0..1；Seek 毫秒绝对定位；
/// - Toggle：宿主按当前 playing 二选一（Rust toggle 命令不带状态）；
/// - ended 事件携带当前代次，Rust service.rs:247 依代次忽略竞态。
///
/// 回流节流：相位/时长变化立即回流；位置回流按 [positionReportInterval]
/// 合并（默认 500ms，与桌面 LivePlayback 走带节奏一致；测试传 Duration
/// .zero 关节流）。
///
/// 依赖抽象（任务 5）：[HostCommandSource]/[HostStateSink]/
/// [MobileAudioPlayer] 全部可注入 fake，测试不触碰真实平台通道；
/// [VoicefoxAudioHandler]（通知栏/锁屏/焦点）由引导链装配，不在本类内，
/// 测试路径完全不经过它。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../playback/mobile_audio_player.dart';
import 'api.dart' as bridge;
// freezed 子类（HostPlayerCommandDto_*）经 lib.dart 的 part 暴露；
// show 列表会把它们过滤掉，故全量导入。
import 'lib.dart';

/// 播放指令源抽象（生产包批次一 opaque 流；测试自产指令）。
abstract class HostCommandSource {
  Future<HostPlayerCommandDto> next();
}

/// 生产指令源：批次一 HostPlayerStream（Dart 持流轮询）。
class RustHostCommandSource implements HostCommandSource {
  RustHostCommandSource(this._stream);

  final HostPlayerStream _stream;

  @override
  Future<HostPlayerCommandDto> next() => bridge.hostPlayerNext(stream: _stream);
}

/// Rust 回流口抽象（生产 hostPlayerReport/Event；测试 fake 记录调用）。
abstract class HostStateSink {
  Future<void> report({
    required String state,
    required BigInt positionMs,
    required BigInt durationMs,
  });

  Future<void> reportEvent({
    required String kind,
    required BigInt generation,
    String? message,
  });
}

/// 生产回流口。
class RustHostStateSink implements HostStateSink {
  RustHostStateSink(this._controller);

  final VoicefoxController _controller;

  @override
  Future<void> report({
    required String state,
    required BigInt positionMs,
    required BigInt durationMs,
  }) {
    return bridge.hostPlayerReport(
      controller: _controller,
      state: state,
      positionMs: positionMs,
      durationMs: durationMs,
    );
  }

  @override
  Future<void> reportEvent({
    required String kind,
    required BigInt generation,
    String? message,
  }) {
    return bridge.hostPlayerReportEvent(
      controller: _controller,
      kind: kind,
      generation: generation,
      message: message,
    );
  }
}

/// Rust→Dart 播放指令桥。
class HostPlayerBridge {
  HostPlayerBridge({
    required HostCommandSource source,
    VoicefoxController? controller,
    MobileAudioPlayer? player,
    HostStateSink? sink,
    this.positionReportInterval = const Duration(milliseconds: 500),
  }) : assert(
         sink != null || controller != null,
         '需要 sink 或 controller 之一（回流口）',
       ),
       _source = source,
       _player = player ?? JustAudioMobilePlayer(),
       _sink = sink ?? RustHostStateSink(controller!) {
    _subscriptions.addAll([
      _player.snapshotStream.listen(_onSnapshot),
      _player.eventStream.listen(_onEvent),
    ]);
  }

  final HostCommandSource _source;
  final MobileAudioPlayer _player;
  final HostStateSink _sink;
  final _subscriptions = <StreamSubscription<void>>[];

  /// 位置回流合并间隔（Duration.zero = 立即回流，测试用）。
  final Duration positionReportInterval;

  bool _started = false;
  MobilePlaybackSnapshot? _lastSnapshot;
  Timer? _positionDebounce;

  /// 启动消费循环（幂等）。
  void start() {
    if (_started) return;
    _started = true;
    unawaited(_pumpCommands());
  }

  /// 指令消费循环。Lagged（积压丢失但流仍有效）继续；流关闭退出。
  Future<void> _pumpCommands() async {
    while (true) {
      try {
        final command = await _source.next();
        await _dispatch(command);
      } on Object catch (error) {
        final message = '$error';
        if (message.contains('lagged')) {
          continue;
        }
        debugPrint('voicefox/host-player: 指令流关闭（$message）');
        return;
      }
    }
  }

  /// FfiCommand 语义映射（批次一 HostPlayerCommand → 播放器调用）。
  Future<void> _dispatch(HostPlayerCommandDto command) async {
    await switch (command) {
      HostPlayerCommandDto_Play(
        :final url,
        :final generation,
        :final headers,
      ) =>
        _player.play(
          url,
          generation: generation,
          headers: {
            for (final pair in headers) pair.name: pair.value,
          },
        ),
      HostPlayerCommandDto_Pause() => _player.pause(),
      HostPlayerCommandDto_Resume() => _player.resume(),
      HostPlayerCommandDto_Stop() => _player.stop(),
      // Toggle：宿主按当前 playing 二选一（Rust 命令不带状态）。
      HostPlayerCommandDto_Toggle() => _player.playing
          ? _player.pause()
          : _player.resume(),
      HostPlayerCommandDto_Seek(:final positionMs) => _player.seek(
          Duration(milliseconds: positionMs.toInt()),
        ),
      // Rust SetVolume 0-100 → 播放器 0..1。
      HostPlayerCommandDto_SetVolume(:final volume) => _player.setVolume(
          volume / 100,
        ),
      HostPlayerCommandDto_SetSpeed(:final speed) => _player.setSpeed(speed),
    };
  }

  /// 快照回流：相位/时长变化立即，位置按间隔合并。
  void _onSnapshot(MobilePlaybackSnapshot snapshot) {
    final previous = _lastSnapshot;
    _lastSnapshot = snapshot;
    final phaseChanged = previous == null || previous.phase != snapshot.phase;
    final durationChanged =
        previous == null || previous.duration != snapshot.duration;
    if (phaseChanged || durationChanged) {
      _positionDebounce?.cancel();
      _positionDebounce = null;
      unawaited(_report(snapshot));
      return;
    }
    if (positionReportInterval <= Duration.zero) {
      unawaited(_report(snapshot));
      return;
    }
    _positionDebounce ??= Timer(positionReportInterval, () {
      _positionDebounce = null;
      final current = _lastSnapshot;
      if (current != null) unawaited(_report(current));
    });
  }

  /// 相位字符串与 Rust parse_host_state（ffi/src/api.rs）一一对应。
  Future<void> _report(MobilePlaybackSnapshot snapshot) async {
    try {
      await _sink.report(
        state: switch (snapshot.phase) {
          MobilePlaybackPhase.idle => 'idle',
          MobilePlaybackPhase.loading => 'loading',
          MobilePlaybackPhase.playing => 'playing',
          MobilePlaybackPhase.paused => 'paused',
          MobilePlaybackPhase.stopped => 'stopped',
        },
        positionMs: BigInt.from(snapshot.position.inMilliseconds),
        durationMs: BigInt.from(snapshot.duration.inMilliseconds),
      );
    } on Object catch (error) {
      debugPrint('voicefox/host-player: 状态回流失败 $error');
    }
  }

  /// 离散事件回流（ended 驱动 Rust 队列推进；failed 呈现错误）。
  void _onEvent(MobilePlaybackEvent event) {
    final (kind, message) = switch (event) {
      MobilePlaybackEnded() => ('ended', null),
      MobilePlaybackFailed(:final message) => ('error', message),
    };
    unawaited(() async {
      try {
        await _sink.reportEvent(
          kind: kind,
          generation: event.generation,
          message: message,
        );
      } on Object catch (error) {
        debugPrint('voicefox/host-player: 事件回流失败 $error');
      }
    }());
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _positionDebounce?.cancel();
    unawaited(_player.dispose());
  }
}

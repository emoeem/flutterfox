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

/// Rust 回流口抽象（生产 hostPlayerReport/Event/Ack；测试 fake 记录调用）。
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

  /// 命令执行结果回销（FFI-R06 A-1b：区分「已入队」与「宿主已执行」）。
  Future<void> ack({
    required BigInt commandId,
    required bool ok,
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

  @override
  Future<void> ack({
    required BigInt commandId,
    required bool ok,
    String? message,
  }) {
    return bridge.hostPlayerAck(
      controller: _controller,
      commandId: commandId,
      ok: ok,
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
  bool _disposed = false;

  /// 消费循环退出信号（dispose 可等待的依据；start 时创建）。
  Completer<void>? _pumpDone;
  MobilePlaybackSnapshot? _lastSnapshot;
  Timer? _positionDebounce;

  /// 启动消费循环（幂等）。
  void start() {
    if (_started) return;
    _started = true;
    _pumpDone = Completer<void>();
    unawaited(_pumpCommands());
  }

  /// 指令消费循环。
  ///
  /// 异常分三层处理（FFI-R03/R06）：
  /// - 源 Lagged（积压丢失但流仍有效）：回灌当前快照重同步 Rust watch
  ///   （宿主与 Rust 的状态可能因丢指令错位），继续消费缓冲内剩余指令；
  /// - 单条命令执行失败/过期丢弃：在 [_runCommand] 层消化并 ack，不向泵
  ///   传播——泵必须存活以执行后续命令；
  /// - 源关闭/不可恢复错误：退出循环（Rust 侧存活看门狗会把冻结的
  ///   Playing/Loading 回落 Stopped，UI 不会永久卡在最后状态）。
  Future<void> _pumpCommands() async {
    while (!_disposed) {
      HostPlayerCommandDto command;
      try {
        command = await _source.next();
      } on Object catch (error) {
        final message = '$error';
        if (message.contains('lagged')) {
          unawaited(_resync());
          continue;
        }
        debugPrint('voicefox/host-player: 指令流关闭（$message）');
        break;
      }
      if (_disposed) break;
      await _runCommand(command);
    }
    _pumpDone?.complete();
  }

  /// 单条命令：过期过滤（FFI-R04）→ 执行 → ack 回销（FFI-R06）。
  /// 任何失败都在本层消化，不向泵传播。
  Future<void> _runCommand(HostPlayerCommandDto command) async {
    final commandId = _commandId(command);
    final stale = _staleReason(command);
    if (stale != null) {
      debugPrint('voicefox/host-player: 丢弃过期命令 #$commandId（$stale）');
      await _ack(commandId, ok: false, message: stale);
      return;
    }
    try {
      await _execute(command);
      await _ack(commandId, ok: true, message: null);
    } on Object catch (error) {
      // 真实播放器错误另经 eventStream → _onEvent 回流，此处只 ack。
      debugPrint('voicefox/host-player: 指令执行失败（$error）');
      await _ack(commandId, ok: false, message: '$error');
    }
  }

  /// FFI-R04 过期判据：歌曲域指令的代次落后于宿主当前代次即过期。
  /// SetVolume/SetSpeed 是全局连续参数，null = 不过滤。
  String? _staleReason(HostPlayerCommandDto command) {
    final BigInt? generation = switch (command) {
      HostPlayerCommandDto_Play(:final generation) => generation,
      HostPlayerCommandDto_Pause(:final generation) => generation,
      HostPlayerCommandDto_Resume(:final generation) => generation,
      HostPlayerCommandDto_Stop(:final generation) => generation,
      HostPlayerCommandDto_Toggle(:final generation) => generation,
      HostPlayerCommandDto_Seek(:final generation) => generation,
      _ => null,
    };
    if (generation == null) return null;
    final current = _player.generation;
    if (generation < current) {
      return '代次 $generation 落后宿主当前 $current（lag 缓冲旧命令）';
    }
    return null;
  }

  static int _commandId(HostPlayerCommandDto command) {
    final BigInt id = switch (command) {
      HostPlayerCommandDto_Play(:final commandId) => commandId,
      HostPlayerCommandDto_Pause(:final commandId) => commandId,
      HostPlayerCommandDto_Resume(:final commandId) => commandId,
      HostPlayerCommandDto_Stop(:final commandId) => commandId,
      HostPlayerCommandDto_Toggle(:final commandId) => commandId,
      HostPlayerCommandDto_Seek(:final commandId) => commandId,
      HostPlayerCommandDto_SetVolume(:final commandId) => commandId,
      HostPlayerCommandDto_SetSpeed(:final commandId) => commandId,
    };
    return id.toInt();
  }

  Future<void> _ack(int commandId, {required bool ok, String? message}) async {
    try {
      await _sink.ack(
        commandId: BigInt.from(commandId),
        ok: ok,
        message: message,
      );
    } on Object catch (error) {
      debugPrint('voicefox/host-player: ack 回销失败 #$commandId（$error）');
    }
  }

  /// FFI-R03 重同步：把宿主当前快照回灌 Rust watch，对齐因积压丢指令
  /// 可能错位的双侧状态。尚无任何快照（宿主未回流过）时无操作。
  Future<void> _resync() async {
    final snapshot = _lastSnapshot;
    if (snapshot == null) return;
    await _report(snapshot);
  }

  /// FfiCommand 语义映射（批次一 HostPlayerCommand → 播放器调用）。
  Future<void> _execute(HostPlayerCommandDto command) async {
    await switch (command) {
      HostPlayerCommandDto_Play(
        :final url,
        :final generation,
        :final headers,
      ) =>
        _player.play(
          url,
          generation: generation,
          headers: {for (final pair in headers) pair.name: pair.value},
        ),
      HostPlayerCommandDto_Pause() => _player.pause(),
      HostPlayerCommandDto_Resume() => _player.resume(),
      HostPlayerCommandDto_Stop() => _player.stop(),
      // Toggle：宿主按当前 playing 二选一（Rust 命令不带状态）。
      HostPlayerCommandDto_Toggle() =>
        _player.playing ? _player.pause() : _player.resume(),
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

  /// 释放桥（FFI-R06：可等待）。取消快照/事件订阅、释放播放器，并等待
  /// 消费循环退出——挂起的 `next()` 返回后因 [_disposed] 不再派发任何
  /// 指令，不会调用已释放的播放器。
  ///
  /// `pumpExitTimeout` 兜底 FFI `hostPlayerNext` 不可取消的极端情形
  /// （生产为 opaque 流轮询，理论可长时间挂起）；超时后返回，挂起的
  /// next() 结果仍会被 [_disposed] 守卫拦下。测试可注入小值。
  Future<void> dispose({
    Duration pumpExitTimeout = const Duration(seconds: 2),
  }) async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _positionDebounce?.cancel();
    await _player.dispose();
    final done = _pumpDone;
    if (done != null && !done.isCompleted) {
      await done.future.timeout(pumpExitTimeout, onTimeout: () {});
    }
  }
}

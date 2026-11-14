/// Phase 8 批次三：Rust→Dart 播放指令桥测试（fake 全链路，任务 5）。
///
/// 全部依赖抽象注入（FakeCommandSource/FakeMobileAudioPlayer/
/// FakeHostStateSink），不依赖 just_audio/audio_service 真实平台通道，
/// 也不触碰 FRB 控制器。覆盖：
/// - Play 指令：url + generation + headers 逐请求透传（国内音源必需）；
/// - pause/resume/stop/seek/setVolume/setSpeed 与 FfiCommand 语义对齐
///   （volume 0-100 → 0..1、Seek 毫秒、Toggle 按 playing 二选一）；
/// - 回流：相位/时长变化立即（'playing'/'paused'/…，与 Rust
///   parse_host_state 字符串一一对应）、位置节流合并、ended/error 事件；
/// - 源容错：lagged 继续消费、流关闭退出循环。
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/bridge/host_player_bridge.dart';
import 'package:voicefox_flutter/src/bridge/lib.dart';
import 'package:voicefox_flutter/src/playback/mobile_audio_player.dart';

class FakeCommandSource implements HostCommandSource {
  final _waiters = <Completer<HostPlayerCommandDto>>[];
  final _pending = <HostPlayerCommandDto>[];
  final _pendingErrors = <Object>[];

  /// 投递指令：有等待者立即完成，否则挂起待下一次 next()。
  void emit(HostPlayerCommandDto command) {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(command);
    } else {
      _pending.add(command);
    }
  }

  /// 模拟源异常（lagged / closed）。
  void failWith(Object error) {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).completeError(error);
    } else {
      _pendingErrors.add(error);
    }
  }

  @override
  Future<HostPlayerCommandDto> next() {
    if (_pending.isNotEmpty) {
      return Future<HostPlayerCommandDto>.value(_pending.removeAt(0));
    }
    if (_pendingErrors.isNotEmpty) {
      return Future<HostPlayerCommandDto>.error(_pendingErrors.removeAt(0));
    }
    final completer = Completer<HostPlayerCommandDto>();
    _waiters.add(completer);
    return completer.future;
  }
}

class FakeMobileAudioPlayer implements MobileAudioPlayer {
  final calls = <String>[];
  final volumes = <double>[];
  final seeks = <Duration>[];
  final speeds = <double>[];
  final played =
      <({String url, BigInt generation, Map<String, String> headers})>[];

  bool _playing = false;
  BigInt _generation = BigInt.zero;

  /// 下一次 pause() 抛异常（FFI-R06：单条命令失败不得杀死泵）。
  bool throwOnPause = false;
  bool disposed = false;

  final _snapshots = StreamController<MobilePlaybackSnapshot>.broadcast();
  final _events = StreamController<MobilePlaybackEvent>.broadcast();

  void emit(MobilePlaybackSnapshot snapshot) => _snapshots.add(snapshot);
  void emitEnded(BigInt generation) =>
      _events.add(MobilePlaybackEnded(generation: generation));
  void emitFailed(BigInt generation, String message) => _events.add(
    MobilePlaybackFailed(generation: generation, message: message),
  );
  void setPlaying(bool value) {
    _playing = value;
  }

  @override
  bool get playing => _playing;

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
    played.add((url: url, generation: generation, headers: headers));
    calls.add('play');
  }

  @override
  Future<void> pause() async {
    if (throwOnPause) {
      throwOnPause = false;
      throw StateError('注入的 pause 失败');
    }
    calls.add('pause');
  }

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    calls.add('seek');
  }

  @override
  Future<void> setVolume(double volume) async {
    volumes.add(volume);
    calls.add('setVolume');
  }

  @override
  Future<void> setSpeed(double speed) async {
    speeds.add(speed);
    calls.add('setSpeed');
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class FakeHostStateSink implements HostStateSink {
  final reports = <({String state, BigInt positionMs, BigInt durationMs})>[];
  final events = <({String kind, BigInt generation, String? message})>[];

  @override
  Future<void> report({
    required String state,
    required BigInt positionMs,
    required BigInt durationMs,
  }) async {
    reports.add((state: state, positionMs: positionMs, durationMs: durationMs));
  }

  @override
  Future<void> reportEvent({
    required String kind,
    required BigInt generation,
    String? message,
  }) async {
    events.add((kind: kind, generation: generation, message: message));
  }
}

HostPlayerBridge _bridge(
  FakeCommandSource source,
  FakeMobileAudioPlayer player,
  FakeHostStateSink sink, {
  Duration positionReportInterval = Duration.zero,
}) {
  return HostPlayerBridge(
    source: source,
    sink: sink,
    player: player,
    positionReportInterval: positionReportInterval,
  );
}

void main() {
  test('Play 指令：url/generation/headers 逐请求透传', () async {
    final source = FakeCommandSource();
    final player = FakeMobileAudioPlayer();
    final sink = FakeHostStateSink();
    final bridge = _bridge(source, player, sink);

    bridge.start();
    await Future<void>.delayed(Duration.zero);
    source.emit(
      HostPlayerCommandDto_Play(
        url: 'https://example.com/a.mp3',
        generation: BigInt.from(7),
        headers: const [
          HostHeaderDto(name: 'Referer', value: 'https://example.com'),
        ],
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(player.played, hasLength(1));
    expect(player.played.single.url, 'https://example.com/a.mp3');
    expect(player.played.single.generation, BigInt.from(7));
    expect(player.played.single.headers, {
      'Referer': 'https://example.com',
    }, reason: 'headers 必须逐请求透传（国内音源必需）');
  });

  test('控制指令与 FfiCommand 语义对齐：volume 折算/seek 毫秒/Toggle 二选一', () async {
    final source = FakeCommandSource();
    final player = FakeMobileAudioPlayer();
    final sink = FakeHostStateSink();
    final bridge = _bridge(source, player, sink);

    for (var i = 0; i < 6; i++) {}
    bridge.start();
    await Future<void>.delayed(Duration.zero);

    source.emit(HostPlayerCommandDto_Pause());
    source.emit(HostPlayerCommandDto_Resume());
    source.emit(HostPlayerCommandDto_Seek(positionMs: BigInt.from(42000)));
    source.emit(HostPlayerCommandDto_SetVolume(volume: 37));
    source.emit(HostPlayerCommandDto_SetSpeed(speed: 1.5));
    // Toggle：未播放 → resume。
    source.emit(HostPlayerCommandDto_Toggle());
    await Future<void>.delayed(Duration.zero);

    expect(player.calls, [
      'pause',
      'resume',
      'seek',
      'setVolume',
      'setSpeed',
      'resume',
    ]);
    expect(player.seeks.single, const Duration(milliseconds: 42000));
    expect(player.volumes.single, closeTo(0.37, 1e-9), reason: '0-100 → 0..1');
    expect(player.speeds.single, 1.5);

    // Toggle：播放中 → pause。
    player.setPlaying(true);
    await Future<void>.delayed(Duration.zero);
    source.emit(HostPlayerCommandDto_Toggle());
    await Future<void>.delayed(Duration.zero);
    expect(player.calls.last, 'pause');
  });

  test('回流：相位/时长变化立即上报（字符串与 Rust parse_host_state 对齐）', () async {
    final source = FakeCommandSource();
    final player = FakeMobileAudioPlayer();
    final sink = FakeHostStateSink();
    _bridge(source, player, sink);

    player.emit(
      const MobilePlaybackSnapshot(
        phase: MobilePlaybackPhase.playing,
        position: Duration(milliseconds: 5000),
        duration: Duration(milliseconds: 244000),
      ),
    );
    player.emit(
      const MobilePlaybackSnapshot(
        phase: MobilePlaybackPhase.paused,
        position: Duration(milliseconds: 5200),
        duration: Duration(milliseconds: 244000),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(sink.reports, hasLength(2));
    expect(sink.reports[0].state, 'playing');
    expect(sink.reports[0].positionMs, BigInt.from(5000));
    expect(sink.reports[0].durationMs, BigInt.from(244000));
    expect(sink.reports[1].state, 'paused');
  });

  test('回流节流：首快照立即、同相位位置合并到间隔末、相位变化立即', () {
    fakeAsync((async) {
      final source = FakeCommandSource();
      final player = FakeMobileAudioPlayer();
      final sink = FakeHostStateSink();
      _bridge(
        source,
        player,
        sink,
        positionReportInterval: const Duration(milliseconds: 500),
      );

      // 首快照：相位变化（null→playing）立即回流。
      // （broadcast 流投递在微任务级：elapse(0) 冲刷微任务。）
      player.emit(
        const MobilePlaybackSnapshot(
          phase: MobilePlaybackPhase.playing,
          position: Duration(milliseconds: 1000),
          duration: Duration(milliseconds: 244000),
        ),
      );
      async.elapse(Duration.zero);
      expect(sink.reports, hasLength(1));
      expect(sink.reports.single.positionMs, BigInt.from(1000));

      // 同相位位置变化：进入 500ms 合并窗口（窗口内不回流）。
      player.emit(
        const MobilePlaybackSnapshot(
          phase: MobilePlaybackPhase.playing,
          position: Duration(milliseconds: 1400),
          duration: Duration(milliseconds: 244000),
        ),
      );
      async.elapse(Duration.zero);
      expect(sink.reports, hasLength(1));

      // 窗口末：合并回流最新位置。
      async.elapse(const Duration(milliseconds: 500));
      expect(sink.reports, hasLength(2));
      expect(sink.reports.last.positionMs, BigInt.from(1400));

      // 相位变化：绕过节流立即回流。
      player.emit(
        const MobilePlaybackSnapshot(
          phase: MobilePlaybackPhase.paused,
          position: Duration(milliseconds: 1600),
          duration: Duration(milliseconds: 244000),
        ),
      );
      async.elapse(Duration.zero);
      expect(sink.reports, hasLength(3));
      expect(sink.reports.last.state, 'paused');
    });
  });

  test('离散事件：ended/error 回流并携带代次', () async {
    final source = FakeCommandSource();
    final player = FakeMobileAudioPlayer();
    final sink = FakeHostStateSink();
    _bridge(source, player, sink);

    player.emitEnded(BigInt.from(9));
    player.emitFailed(BigInt.from(9), '解码失败');
    await Future<void>.delayed(Duration.zero);

    expect(sink.events, hasLength(2));
    expect(sink.events[0].kind, 'ended');
    expect(sink.events[0].generation, BigInt.from(9));
    expect(sink.events[1].kind, 'error');
    expect(sink.events[1].message, '解码失败');
  });

  test('源容错：lagged 继续消费，流关闭退出循环', () async {
    final source = FakeCommandSource();
    final player = FakeMobileAudioPlayer();
    final sink = FakeHostStateSink();
    final bridge = _bridge(source, player, sink);

    // pump 的 next() 以 lagged 异常完成（积压丢失但流仍有效）。
    bridge.start();
    await Future<void>.delayed(Duration.zero);
    source.failWith('host player stream lagged, skipped 3 commands');
    await Future<void>.delayed(Duration.zero);

    // 继续：新指令仍被消费。
    await Future<void>.delayed(Duration.zero);
    source.emit(HostPlayerCommandDto_Pause());
    await Future<void>.delayed(Duration.zero);
    expect(player.calls, ['pause']);

    // 流关闭：后续指令不再消费。
    await Future<void>.delayed(Duration.zero);
    source.failWith('receiving on an empty and closed channel');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    source.emit(HostPlayerCommandDto_Resume());
    await Future<void>.delayed(Duration.zero);
    expect(player.calls, ['pause'], reason: '循环已退出，resume 不应被消费');
  });

  test('FFI-R03：lagged 后重同步，把当前快照回灌 Rust watch', () async {
    final source = FakeCommandSource();
    final player = FakeMobileAudioPlayer();
    final sink = FakeHostStateSink();
    final bridge = _bridge(source, player, sink);
    bridge.start();
    await Future<void>.delayed(Duration.zero);

    // 宿主真实状态：playing（经快照监听已缓存为最新快照）。
    player.emit(
      const MobilePlaybackSnapshot(
        phase: MobilePlaybackPhase.playing,
        position: Duration(milliseconds: 8000),
        duration: Duration(milliseconds: 244000),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final reportsBefore = sink.reports.length;

    // 积压丢失（流仍有效）：应触发一次重同步回灌，而非静默继续。
    source.failWith('host player stream lagged, skipped 5 commands');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      sink.reports.length,
      reportsBefore + 1,
      reason: 'lagged 后应回灌当前快照对齐 Rust watch',
    );
    expect(sink.reports.last.state, 'playing');
    expect(sink.reports.last.positionMs, BigInt.from(8000));

    // 重同步后泵仍存活：后续指令正常消费。
    source.emit(HostPlayerCommandDto_Pause());
    await Future<void>.delayed(Duration.zero);
    expect(player.calls, contains('pause'));
  });

  test('FFI-R06：单条命令执行失败不杀死泵，后续指令继续消费', () async {
    final source = FakeCommandSource();
    final player = FakeMobileAudioPlayer();
    final sink = FakeHostStateSink();
    final bridge = _bridge(source, player, sink);
    bridge.start();
    await Future<void>.delayed(Duration.zero);

    player.throwOnPause = true;
    source.emit(HostPlayerCommandDto_Pause());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(player.calls, isNot(contains('pause')), reason: 'pause 已失败');

    // 泵未随单条命令失败退出：后续 Play 正常执行。
    source.emit(
      HostPlayerCommandDto_Play(
        url: 'https://example.com/next.mp3',
        generation: BigInt.from(3),
        headers: const [],
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(player.played, hasLength(1));
    expect(player.played.single.url, 'https://example.com/next.mp3');
  });

  test('FFI-R06：dispose 可等待，停泵且不再向已释放播放器派发', () async {
    final source = FakeCommandSource();
    final player = FakeMobileAudioPlayer();
    final sink = FakeHostStateSink();
    final bridge = _bridge(source, player, sink);
    bridge.start();
    await Future<void>.delayed(Duration.zero);

    await bridge.dispose(pumpExitTimeout: const Duration(milliseconds: 100));
    expect(player.disposed, isTrue, reason: 'dispose 应等待播放器释放完成');

    // dispose 后到达的指令不得派发到已释放的播放器。
    source.emit(
      HostPlayerCommandDto_Play(
        url: 'https://example.com/late.mp3',
        generation: BigInt.from(4),
        headers: const [],
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(player.played, isEmpty, reason: 'dispose 后挂起指令不得再派发');

    // dispose 后快照不再回流（订阅已取消）。
    final reportsBefore = sink.reports.length;
    player.emit(
      const MobilePlaybackSnapshot(
        phase: MobilePlaybackPhase.playing,
        position: Duration(milliseconds: 100),
        duration: Duration(milliseconds: 1000),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(sink.reports.length, reportsBefore, reason: '订阅已取消，不再回流');
  });
}

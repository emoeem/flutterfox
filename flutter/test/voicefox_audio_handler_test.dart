/// §10.2 audio_service handler 专项单测（Phase 4，04 矩阵第 9 行缺口）。
///
/// 覆盖 VoicefoxAudioHandler 纯 Dart 可测面（fake MobileAudioPlayer +
/// 真 AppModel，不触平台通道；BaseAudioHandler 构造与快照/中断映射在
/// 纯 Dart 测试环境可驱动，评审探针实跑实证）：
/// - 音频焦点中断：begin → 记录在播并暂停让焦；end 且抢占前在播 → 恢复；
///   抢占期间通知栏/耳机手动暂停（handler.pause()）→ end 不覆盖用户意图
///   （Phase 4 守卫修复：pause() 非自动发起即清恢复标记）；抢占前未在播
///   → end 不恢复；
/// - MediaItem 映射：真源 AppModel 曲目元数据 + coverUrl=null 不伪造
///   artUri；无曲目 app 名兜底；
/// - 相位 → AudioProcessingState 映射（idle/stopped→idle、loading→loading、
///   playing/paused→ready + playing 标志）；
/// - 播控命令映射：play→resume（audio_service 无 URL 语义）、pause/seek/
///   setSpeed/stop 直通。
///
/// 如实登记（本文件不测，也测不到）：configureAudioService 的
/// becomingNoisy 拔耳机暂停与 AudioSession.instance 焦点配置挂平台通道，
/// 单测不可达；coverUrl 空串/解析失败两档无测试注入入口
/// （debugSetPlaybackSong 硬编码 coverUrl=null，app_model.dart debugSet*
/// 全清单无写入口）；Android 真机通知/锁屏/耳机蓝牙/焦点实响/后台生命周期
/// 由 P1-06 环境阻断维持「未验证」（04 矩阵），不因单测全绿改判。
library;

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicefox_flutter/src/app_model.dart';
import 'package:voicefox_flutter/src/playback/mobile_audio_player.dart';
import 'package:voicefox_flutter/src/playback/voicefox_audio_handler.dart';

/// fake 播放器：记录调用序列（resume/play 区分两条通道），快照经
/// [emitSnapshot] 手工注入。
class _FakePlayer implements MobileAudioPlayer {
  final List<String> calls = [];
  final _snapshots = StreamController<MobilePlaybackSnapshot>.broadcast();
  final _events = StreamController<MobilePlaybackEvent>.broadcast();

  void emitSnapshot(MobilePlaybackPhase phase) {
    _snapshots.add(
      MobilePlaybackSnapshot(
        phase: phase,
        position: Duration.zero,
        duration: const Duration(milliseconds: 244000),
      ),
    );
  }

  @override
  bool get playing => false;

  @override
  BigInt get generation => BigInt.zero;

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
    calls.add('play(url)');
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek:${position.inMilliseconds}');

  @override
  Future<void> setVolume(double volume) async => calls.add('setVolume');

  @override
  Future<void> setSpeed(double speed) async => calls.add('setSpeed:$speed');

  @override
  Future<void> dispose() async {
    await _snapshots.close();
    await _events.close();
  }
}

/// 每用例独立 AppModel + fake 播放器 + handler（handler.dispose 只取消
/// 播放器订阅、不移除 model 监听，跨用例共享会堆叠监听污染断言）。
class _Fixture {
  _Fixture({bool withSong = true}) {
    if (withSong) {
      model.debugSetPlaybackSong(
        id: 's1',
        source: 'netease',
        name: '夜航',
        singer: '测试歌手',
        state: 'paused',
        positionMs: 0,
        durationMs: 244000,
      );
    }
    player = _FakePlayer();
    handler = VoicefoxAudioHandler(model: model, player: player);
    addTearDown(handler.dispose);
  }

  final model = AppModel();
  late final _FakePlayer player;
  late final VoicefoxAudioHandler handler;

  /// 让快照相位回流到 handler.playbackState（broadcast 流过微任务即达）。
  Future<void> emitPhase(MobilePlaybackPhase phase) async {
    player.emitSnapshot(phase);
    await pumpEventQueue();
  }
}

void main() {
  group('音频焦点中断（§10.2）', () {
    test('begin 记录在播并暂停让出焦点', () async {
      final fixture = _Fixture();
      await fixture.emitPhase(MobilePlaybackPhase.playing);
      expect(fixture.handler.playbackState.value.playing, isTrue);

      await fixture.handler.onInterruptionEvent(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      expect(fixture.player.calls, ['pause']);
    });

    test('end 且抢占前在播 → 恢复（不丢 shouldResume 语义）', () async {
      final fixture = _Fixture();
      await fixture.emitPhase(MobilePlaybackPhase.playing);

      await fixture.handler.onInterruptionEvent(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      await fixture.handler.onInterruptionEvent(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(fixture.player.calls, ['pause', 'resume']);
    });

    test('抢占期间手动暂停（通知栏/耳机路径）→ end 不覆盖用户意图', () async {
      final fixture = _Fixture();
      await fixture.emitPhase(MobilePlaybackPhase.playing);

      await fixture.handler.onInterruptionEvent(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      // 用户在抢占期间手动暂停（Phase 4 守卫修复：非自动发起清恢复标记）。
      await fixture.handler.pause();
      await fixture.handler.onInterruptionEvent(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(fixture.player.calls, [
        'pause',
        'pause',
      ], reason: '系统恢复事件不得覆盖抢占期间的手动暂停');
    });

    test('抢占前未在播 → end 不恢复', () async {
      final fixture = _Fixture();
      await fixture.emitPhase(MobilePlaybackPhase.paused);

      await fixture.handler.onInterruptionEvent(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      await fixture.handler.onInterruptionEvent(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(
        fixture.player.calls.where((c) => c == 'resume'),
        isEmpty,
        reason: '抢占前未在播，end 不得恢复',
      );
    });
  });

  group('MediaItem 映射（真源 AppModel 快照）', () {
    test('曲目在位：元数据逐字段映射，coverUrl=null 不伪造 artUri', () async {
      final fixture = _Fixture();
      final item = fixture.handler.mediaItem.value!;
      expect(item.id, 's1');
      expect(item.title, '夜航');
      expect(item.artist, '测试歌手');
      expect(item.duration, const Duration(milliseconds: 244000));
      expect(item.artUri, isNull, reason: 'coverUrl=null 不伪造封面 URL');
    });

    test('无曲目兜底：app 名兜底，不伪造曲目信息', () async {
      final fixture = _Fixture(withSong: false);
      final item = fixture.handler.mediaItem.value!;
      expect(item.id, 'voicefox-now-playing');
      expect(item.title, 'voicefox');
      expect(item.artist, isNull);
      expect(item.duration, isNull);
      expect(item.artUri, isNull);
    });
  });

  group('快照相位 → AudioProcessingState 映射', () {
    test('idle/stopped→idle、loading→loading、playing/paused→ready+标志', () async {
      final fixture = _Fixture();
      final cases = <MobilePlaybackPhase, AudioProcessingState>{
        MobilePlaybackPhase.idle: AudioProcessingState.idle,
        MobilePlaybackPhase.stopped: AudioProcessingState.idle,
        MobilePlaybackPhase.loading: AudioProcessingState.loading,
        MobilePlaybackPhase.playing: AudioProcessingState.ready,
        MobilePlaybackPhase.paused: AudioProcessingState.ready,
      };
      for (final entry in cases.entries) {
        await fixture.emitPhase(entry.key);
        expect(
          fixture.handler.playbackState.value.processingState,
          entry.value,
          reason: '${entry.key.name} → ${entry.value.name}',
        );
      }
      // playing 标志只跟随 playing 相位。
      await fixture.emitPhase(MobilePlaybackPhase.playing);
      expect(fixture.handler.playbackState.value.playing, isTrue);
      await fixture.emitPhase(MobilePlaybackPhase.paused);
      expect(fixture.handler.playbackState.value.playing, isFalse);
    });
  });

  group('播控命令映射（通知栏/锁屏/耳机 → MobileAudioPlayer）', () {
    test('play 映射 resume（audio_service 无 URL 语义），其余直通', () async {
      final fixture = _Fixture();
      await fixture.handler.play();
      await fixture.handler.pause();
      await fixture.handler.seek(const Duration(seconds: 12));
      await fixture.handler.setSpeed(1.5);
      await fixture.handler.stop();
      expect(fixture.player.calls, [
        'resume',
        'pause',
        'seek:12000',
        'setSpeed:1.5',
        'stop',
      ]);
    });
  });
}

// Voicefox adapter: implements the myune AudioBackend seam against AppModel.
// Newly written for voicefox, not vendored.
import 'dart:async';

import '../app_model.dart';
import '../bridge/lib.dart' as bridge;
import 'mpv_audio_kit_shim.dart';

/// Bridges the vendored myune UI's playback seam to voicefox's AppModel.
///
/// Mapping notes (gaps are documented, not silently faked):
/// - `open(path)` resolves the path against queue/local songs by id; a path
///   that matches nothing is played as a synthesized local SongDto.
/// - `setVolume` is a no-op: voicefox FFI has no volume command yet
///   (Rust-side addition, tracked as a separate unit).
/// - Visualiser streams (pcm/fft) stay silent; the analysis page handles it.
class AppModelAudioBackend implements AudioBackend {
  AppModelAudioBackend(this.model) {
    model.addListener(_onModelChanged);
    _onModelChanged();
  }

  final AppModel model;

  final _position = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _errors = StreamController<MpvPlayerError>.broadcast();

  bool _disposed = false;
  String? _lastState;

  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<Duration> get durationStream => _duration.stream;
  @override
  Stream<bool> get completedStream => _completed.stream;
  @override
  Stream<MpvPlayerError> get errorStream => _errors.stream;
  @override
  Stream<PcmFrame> get pcmStream => const Stream<PcmFrame>.empty();
  @override
  Stream<FftFrame> get fftStream => const Stream<FftFrame>.empty();
  @override
  Stream<List<Device>> get audioDevicesStream => Stream<List<Device>>.value(
    const [Device(name: 'auto', description: '系统默认')],
  );
  @override
  Stream<Device> get audioDeviceStream =>
      Stream<Device>.value(const Device(name: 'auto', description: '系统默认'));

  void _onModelChanged() {
    if (_disposed) return;
    final p = model.state.playback;
    _position.add(_ms(p.positionMs));
    _duration.add(_ms(p.durationMs));
    _playing.add(p.state == 'playing');
    if (_lastState != null && _lastState != p.state && p.state == 'stopped') {
      _completed.add(true);
    }
    _lastState = p.state;
  }

  static Duration _ms(BigInt ms) => Duration(milliseconds: ms.toInt());

  @override
  Duration get position => _ms(model.state.playback.positionMs);
  @override
  Duration get duration => _ms(model.state.playback.durationMs);
  @override
  bool get playing => model.state.playback.state == 'playing';
  @override
  List<Device> get audioDevices => const [
    Device(name: 'auto', description: '系统默认'),
  ];

  @override
  Playlist get playlist => Playlist(
    items: [for (final song in model.state.queue) Media(song.id)],
    index: model.state.queueIndex,
  );

  /// Resolve a myune file path to a voicefox SongDto (queue first, then the
  /// local library; unknown paths fall back to a synthesized local entry).
  bridge.SongDto? _resolve(String path) {
    for (final song in model.state.queue) {
      if (song.id == path) return song;
    }
    for (final song in model.state.localSongs) {
      if (song.id == path) return song;
    }
    return null;
  }

  @override
  Future<void> open(String path, {bool play = true}) async {
    final song = _resolve(path);
    if (song != null) {
      await model.playSong(song);
      return;
    }
    final name = path.split(RegExp(r'[/\\]')).last;
    await model.playSong(
      bridge.SongDto(
        id: path,
        source: 'local',
        name: name,
        singer: '',
        artistId: null,
        albumName: '',
        albumId: null,
        durationMs: BigInt.zero,
        coverUrl: null,
      ),
    );
  }

  @override
  Future<void> openAll(List<String> paths, {bool play = true}) async {
    final songs = <bridge.SongDto>[];
    for (final path in paths) {
      final song =
          _resolve(path) ??
          bridge.SongDto(
            id: path,
            source: 'local',
            name: path.split(RegExp(r'[/\\]')).last,
            singer: '',
            artistId: null,
            albumName: '',
            albumId: null,
            durationMs: BigInt.zero,
            coverUrl: null,
          );
      songs.add(song);
    }
    if (songs.isEmpty) return;
    await model.playSongs(songs, index: 0);
  }

  @override
  Future<void> add(String path) async {
    final song = _resolve(path);
    if (song != null) await model.queueAdd(song);
  }

  @override
  Future<void> remove(int index) async {
    if (index >= 0 && index < model.state.queue.length) {
      await model.dispatch(bridge.FfiCommand.queueRemove(index: index));
    }
  }

  @override
  Future<void> stop() => model.dispatch(const bridge.FfiCommand.stop());

  @override
  Future<void> pause() {
    if (model.state.playback.state == 'playing') return model.toggle();
    return Future.value();
  }

  @override
  Future<void> play() {
    if (model.state.playback.state != 'playing') return model.toggle();
    return Future.value();
  }

  @override
  Future<void> seek(Duration position) =>
      model.seekMs(BigInt.from(position.inMilliseconds));

  @override
  Future<void> setVolume(double volume) async {
    // myune 的音量滑杆 → voicefox 的 SetVolume（立即作用于 mpv）。
    await model.setVolume(volume.round().clamp(0, 100));
  }

  @override
  Future<void> setVolumeGain(double gain) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setReplayGain(ReplayGainSettings settings) async {}

  @override
  Future<void> setAudioDevice(Device device) async {}

  @override
  Future<void> setMediaSession(MediaSession? session) async {}

  @override
  Future<void> updateAudioEffects(
    AudioEffects Function(AudioEffects) update,
  ) async {}

  @override
  Future<void> setSpectrum(SpectrumSettings settings) async {}

  @override
  Future<void> setAudioExclusive(bool exclusive) async {}

  @override
  Future<void> setAudioNullUntimed(bool enabled) async {}

  @override
  Future<void> setAudioStreamSilence(bool enabled) async {}

  @override
  Future<void> setGapless(Gapless mode) async {}

  @override
  Future<void> setPrefetchPlaylist(bool enabled) async {}

  @override
  Future<void> setRawProperty(String name, String value) async {}

  @override
  Future<void> setAudioClientName(String name) async {}

  @override
  Future<void> dispose() async {
    _disposed = true;
    model.removeListener(_onModelChanged);
  }
}

/// Attach a voicefox AppModel as the active audio backend for the vendored
/// myune UI. Call once after the AppModel is bootstrapped.
void attachVoicefoxAudioBackend(AppModel model) {
  activeAudioBackend = AppModelAudioBackend(model);
}

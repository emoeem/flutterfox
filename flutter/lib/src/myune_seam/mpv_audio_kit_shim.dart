// Vendored-adjacent shim for voicefox.
// The vendored myune_music UI (Apache-2.0, xiaobaimc/myune_music @
// 5188867b2f986e79260d8191c0c659bc1d2216ad) is written against
// `package:mpv_audio_kit/mpv_audio_kit.dart`. voicefox plays audio through its
// own Rust core, so this file recreates the *minimal* mpv_audio_kit-compatible
// type surface and forwards every playback verb to a pluggable
// [AudioBackend]. The UI code stays untouched; only its import line changes.
//
// License note: this file is newly written for voicefox, not vendored.
// The snake_case named parameters below mirror upstream mpv_audio_kit's API;
// renaming them would break the vendored call sites.
// ignore_for_file: non_constant_identifier_names
import 'dart:async';

/// One media entry of the player playlist.
class Media {
  Media(this.uri);

  final String uri;
}

/// Audio output device descriptor.
class Device {
  const Device({required this.name, required this.description});

  final String name;
  final String description;
}

/// Gapless playback mode (mpv_audio_kit enum subset).
class Gapless {
  const Gapless._(this.value);

  final String value;

  static const weak = Gapless._('weak');
  static const yes = Gapless._('yes');
  static const no = Gapless._('no');

  @override
  String toString() => value;
}

/// Configuration accepted by the vendored constructor call sites.
class PlayerConfiguration {
  const PlayerConfiguration({this.autoPlay = false, this.resumePlayback = false});

  final bool autoPlay;
  final bool resumePlayback;
}

/// Haas effect middle-source selector.
class HaasSource {
  const HaasSource._(this.value);

  final String value;

  static const mid = HaasSource._('mid');
  static const side = HaasSource._('side');
  static const left = HaasSource._('left');
  static const right = HaasSource._('right');
}

/// RNN noise-reduction model settings (arnndn filter).
class ArnndnSettings {
  const ArnndnSettings({this.enabled = false, this.model});

  final bool enabled;
  final String? model;
}

/// Audio output state enum (mpv_audio_kit subset).
class AudioOutputState {
  const AudioOutputState._(this.value);

  final String value;

  static const active = AudioOutputState._('active');
  static const starting = AudioOutputState._('starting');
  static const failed = AudioOutputState._('failed');
  static const removed = AudioOutputState._('removed');
}

/// EBU R128 loudness filter settings.
class Ebur128 {
  const Ebur128({this.enabled = false, this.metadata = false});

  final bool enabled;
  final bool metadata;

  Ebur128 copyWith({bool? enabled, bool? metadata}) => Ebur128(
        enabled: enabled ?? this.enabled,
        metadata: metadata ?? this.metadata,
      );
}

/// One named audio-effect group. The vendored UI turns effects on/off through
/// `update<Effect>((m) => m.copyWith(...))`; the shim accepts the union of all
/// named arguments the call sites use and stores the intent per effect key.
/// Actual DSP wiring belongs to the backend, not the UI.
class EffectsSetting {
  const EffectsSetting({this.enabled = false});

  final bool enabled;

  EffectsSetting copyWith({
    bool? enabled,
    double? strength,
    double? range,
    double? m,
    double? delay,
    double? drymix,
    double? level_in,
    double? level_out,
    double? side_gain,
    HaasSource? middle_source,
    double? mlev,
    double? slev,
    double? frequency,
    double? g,
    double? limit,
    double? threshold,
    double? dry,
    double? wet,
    double? in_gain,
    double? out_gain,
    String? delays,
    String? decays,
    int? order,
  }) =>
      EffectsSetting(enabled: enabled ?? this.enabled);
}

class AudioEffects {
  const AudioEffects({
    this.custom = const [],
    this.ebur128 = const Ebur128(),
    this.arnndn,
    this.settings = const {},
  });

  final List<String> custom;
  final Ebur128 ebur128;
  final ArnndnSettings? arnndn;
  final Map<String, EffectsSetting> settings;

  AudioEffects copyWith({
    List<String>? custom,
    Ebur128? ebur128,
    ArnndnSettings? arnndn,
    Map<String, EffectsSetting>? settings,
  }) =>
      AudioEffects(
        custom: custom ?? this.custom,
        ebur128: ebur128 ?? this.ebur128,
        arnndn: arnndn ?? this.arnndn,
        settings: settings ?? this.settings,
      );

  AudioEffects updateEbur128(Ebur128 Function(Ebur128) update) =>
      copyWith(ebur128: update(ebur128));

  AudioEffects updateEbur(Ebur128 Function(Ebur128) update) =>
      updateEbur128(update);

  AudioEffects _update(String key, EffectsSetting Function(EffectsSetting) fn) {
    final next = Map<String, EffectsSetting>.from(settings);
    next[key] = fn(next[key] ?? const EffectsSetting());
    return copyWith(settings: next);
  }

  AudioEffects updateAcompressor(EffectsSetting Function(EffectsSetting) fn) => _update('acompressor', fn);
  AudioEffects updateAcrusher(EffectsSetting Function(EffectsSetting) fn) => _update('acrusher', fn);
  AudioEffects updateAdeclip(EffectsSetting Function(EffectsSetting) fn) => _update('adeclip', fn);
  AudioEffects updateAecho(EffectsSetting Function(EffectsSetting) fn) => _update('aecho', fn);
  AudioEffects updateAemphasis(EffectsSetting Function(EffectsSetting) fn) => _update('aemphasis', fn);
  AudioEffects updateAexciter(EffectsSetting Function(EffectsSetting) fn) => _update('aexciter', fn);
  AudioEffects updateAfftdn(EffectsSetting Function(EffectsSetting) fn) => _update('afftdn', fn);
  AudioEffects updateAgate(EffectsSetting Function(EffectsSetting) fn) => _update('agate', fn);
  AudioEffects updateAlimiter(EffectsSetting Function(EffectsSetting) fn) => _update('alimiter', fn);
  AudioEffects updateAsoftclip(EffectsSetting Function(EffectsSetting) fn) => _update('asoftclip', fn);
  AudioEffects updateAsubboost(EffectsSetting Function(EffectsSetting) fn) => _update('asubboost', fn);
  AudioEffects updateAtilt(EffectsSetting Function(EffectsSetting) fn) => _update('atilt', fn);
  AudioEffects updateBass(EffectsSetting Function(EffectsSetting) fn) => _update('bass', fn);
  AudioEffects updateCrossfeed(EffectsSetting Function(EffectsSetting) fn) => _update('crossfeed', fn);
  AudioEffects updateCrystalizer(EffectsSetting Function(EffectsSetting) fn) => _update('crystalizer', fn);
  AudioEffects updateDeesser(EffectsSetting Function(EffectsSetting) fn) => _update('deesser', fn);
  AudioEffects updateExtrastereo(EffectsSetting Function(EffectsSetting) fn) => _update('extrastereo', fn);
  AudioEffects updateHaas(EffectsSetting Function(EffectsSetting) fn) => _update('haas', fn);
  AudioEffects updateHighpass(EffectsSetting Function(EffectsSetting) fn) => _update('highpass', fn);
  AudioEffects updateLowpass(EffectsSetting Function(EffectsSetting) fn) => _update('lowpass', fn);
  AudioEffects updateStereotools(EffectsSetting Function(EffectsSetting) fn) => _update('stereotools', fn);
  AudioEffects updateStereowiden(EffectsSetting Function(EffectsSetting) fn) => _update('stereowiden', fn);
  AudioEffects updateTiltshelf(EffectsSetting Function(EffectsSetting) fn) => _update('tiltshelf', fn);
  AudioEffects updateTreble(EffectsSetting Function(EffectsSetting) fn) => _update('treble', fn);
  AudioEffects updateVirtualbass(EffectsSetting Function(EffectsSetting) fn) => _update('virtualbass', fn);
}

/// Spectrum generator settings (mpv_audio_kit SpectrumSettings subset).
class SpectrumSettings {
  const SpectrumSettings({
    this.fftSize = 2048,
    this.bandCount = 64,
    this.emitInterval = const Duration(milliseconds: 33),
    this.minDb = -90,
    this.maxDb = -20,
  });

  final int fftSize;
  final int bandCount;
  final Duration emitInterval;
  final double minDb;
  final double maxDb;
}

/// ReplayGain mode enum (mpv_audio_kit subset).
class ReplayGain {
  const ReplayGain._(this.value);

  final String value;

  static const no = ReplayGain._('no');
  static const track = ReplayGain._('track');
  static const album = ReplayGain._('album');
}

class ReplayGainSettings {
  const ReplayGainSettings({
    required this.mode,
    this.preamp = 0.0,
    this.fallback = 0.0,
    this.clip = false,
  });

  final ReplayGain mode;
  final double preamp;
  final double fallback;
  final bool clip;
}

/// Loudness scan progress state (mpv_audio_kit subset).
class LoudnessScanState {
  const LoudnessScanState._(this.value);

  final String value;

  static const ready = LoudnessScanState._('ready');
  static const scanning = LoudnessScanState._('scanning');
  static const unavailable = LoudnessScanState._('unavailable');
}

class LoudnessScan {
  const LoudnessScan({
    required this.state,
    this.integrated,
    this.truePeak,
    this.samplePeak,
  });

  final LoudnessScanState state;
  final double? integrated;
  final double? truePeak;
  final double? samplePeak;
}

/// Interleaved PCM frame pushed to the analysis widgets.
class PcmFrame {
  const PcmFrame({this.samples = const []});

  final List<double> samples;
}

/// FFT band frame pushed to the spectrum widgets.
class FftFrame {
  const FftFrame({this.bands = const []});

  final List<double> bands;
}

/// Media session command enum stand-in.
class MediaSessionCommand {
  const MediaSessionCommand(this.name);

  final String name;

  @override
  String toString() => name;
}

class MediaSessionCommandNext extends MediaSessionCommand {
  const MediaSessionCommandNext() : super('next');
}

class MediaSessionCommandPrevious extends MediaSessionCommand {
  const MediaSessionCommandPrevious() : super('previous');
}

class CoverArt {
  const CoverArt({this.bytes, this.mimeType});

  final List<int>? bytes;
  final String? mimeType;
}

class MediaSessionArtwork {
  const MediaSessionArtwork._();

  static const embedded = MediaSessionArtwork._();

  static MediaSessionArtwork custom(CoverArt art) => MediaSessionArtwork._();
}

/// System media session descriptor passed to setMediaSession.
class MediaSession {
  const MediaSession({
    required this.appName,
    required this.title,
    this.artist,
    this.album,
    this.artwork = MediaSessionArtwork.embedded,
    this.autoApplyPlaylistNavigation = true,
  });

  final String appName;
  final String title;
  final String? artist;
  final String? album;
  final MediaSessionArtwork artwork;
  final bool autoApplyPlaylistNavigation;
}

/// Error type surfaced on the error stream.
class MpvPlayerError implements Exception {
  const MpvPlayerError(this.message, {this.prefix = '', this.text = ''});

  final String message;
  final String prefix;
  final String text;

  @override
  String toString() => 'MpvPlayerError: $message';
}

/// Structured log error with an `ao`/`vo`/… prefix (mpv_audio_kit subset).
class MpvLogError extends MpvPlayerError {
  const MpvLogError(super.message, {required super.prefix, super.text = ''});
}

/// Snapshot of playlist state read through `player.state`.
class Playlist {
  const Playlist({this.items = const [], this.index = 0});

  final List<Media> items;
  final int index;

  /// Alias kept for voicefox-side adapters that read [index].
  int get currentIndex => index;
}

/// Snapshot of player state read through `player.state`.
class PlayerState {
  const PlayerState({
    this.playlist = const Playlist(),
    this.duration = Duration.zero,
    this.position = Duration.zero,
    this.playing = false,
    this.audioDevices = const [],
    this.volume = 1.0,
    this.pitch = 1.0,
    this.rate = 1.0,
  });

  final Playlist playlist;
  final Duration duration;
  final Duration position;
  final bool playing;
  final List<Device> audioDevices;
  final double volume;
  final double pitch;
  final double rate;

  Map<String, Object?> toJson() => {
        'duration': duration.inMilliseconds,
        'position': position.inMilliseconds,
        'playing': playing,
        'volume': volume,
        'pitch': pitch,
        'rate': rate,
      };
}

/// The playback engine seam. voicefox implements this against AppModel;
/// the vendored myune UI drives it exactly like it drove mpv_audio_kit.
abstract class AudioBackend {
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;
  Stream<Duration> get durationStream;
  Stream<bool> get completedStream;
  Stream<MpvPlayerError> get errorStream;
  /// Optional visualiser data; the analysis page tolerates absence.
  Stream<PcmFrame> get pcmStream;
  Stream<FftFrame> get fftStream;
  Stream<List<Device>> get audioDevicesStream;
  Stream<Device> get audioDeviceStream;

  Duration get position;
  Duration get duration;
  bool get playing;
  Playlist get playlist;
  List<Device> get audioDevices;

  Future<void> open(String path, {bool play});
  Future<void> openAll(List<String> paths, {bool play});
  Future<void> add(String path);
  Future<void> remove(int index);
  Future<void> stop();
  Future<void> pause();
  Future<void> play();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setVolumeGain(double gain);
  Future<void> setPitch(double pitch);
  Future<void> setRate(double rate);
  Future<void> setReplayGain(ReplayGainSettings settings);
  Future<void> setAudioDevice(Device device);
  Future<void> setMediaSession(MediaSession? session);
  Future<void> updateAudioEffects(AudioEffects Function(AudioEffects) update);
  Future<void> setSpectrum(SpectrumSettings settings);
  Future<void> setAudioExclusive(bool exclusive);
  Future<void> setAudioNullUntimed(bool enabled);
  Future<void> setAudioStreamSilence(bool enabled);
  Future<void> setGapless(Gapless mode);
  Future<void> setPrefetchPlaylist(bool enabled);
  Future<void> setRawProperty(String name, String value);
  Future<void> setAudioClientName(String name);
  Future<void> dispose();
}

/// Backend that does nothing but keeps streams alive. Used until the host
/// injects a real backend (and as the safe default in widget tests).
class NoopAudioBackend implements AudioBackend {
  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();
  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();
  @override
  Stream<Duration> get durationStream => const Stream<Duration>.empty();
  @override
  Stream<bool> get completedStream => const Stream<bool>.empty();
  @override
  Stream<MpvPlayerError> get errorStream => const Stream<MpvPlayerError>.empty();
  @override
  Stream<PcmFrame> get pcmStream => const Stream<PcmFrame>.empty();
  @override
  Stream<FftFrame> get fftStream => const Stream<FftFrame>.empty();
  @override
  Stream<List<Device>> get audioDevicesStream =>
      Stream<List<Device>>.value(const []);
  @override
  Stream<Device> get audioDeviceStream =>
      Stream<Device>.value(const Device(name: 'auto', description: 'Auto'));

  @override
  Duration get position => Duration.zero;
  @override
  Duration get duration => Duration.zero;
  @override
  bool get playing => false;
  @override
  Playlist get playlist => const Playlist();
  @override
  List<Device> get audioDevices => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) return Future<void>.value();
    return super.noSuchMethod(invocation);
  }
}

/// Where the currently active backend lives. Set once during bootstrap
/// (before any vendored UI is built).
AudioBackend activeAudioBackend = NoopAudioBackend();

/// mpv_audio_kit's Player, reimplemented as a facade over [activeAudioBackend].
class Player {
  Player({PlayerConfiguration configuration = const PlayerConfiguration()});

  AudioBackend get _backend => activeAudioBackend;

  PlayerStream get stream => PlayerStream._(_backend);
  PlayerState get state => PlayerState(
        playlist: _backend.playlist,
        duration: _backend.duration,
        position: _backend.position,
        playing: _backend.playing,
        audioDevices: _backend.audioDevices,
      );

  Future<void> open(Media media, {bool play = false}) =>
      _backend.open(media.uri, play: play);
  Future<void> openAll(List<Media> media, {bool play = false}) =>
      _backend.openAll(media.map((m) => m.uri).toList(), play: play);
  Future<void> add(Media media) => _backend.add(media.uri);
  Future<void> remove(int index) => _backend.remove(index);
  Future<void> stop() => _backend.stop();
  Future<void> pause() => _backend.pause();
  Future<void> play() => _backend.play();
  Future<void> seek(Duration position) => _backend.seek(position);
  Future<void> setVolume(double volume) => _backend.setVolume(volume);
  Future<void> setVolumeGain(double gain) => _backend.setVolumeGain(gain);
  Future<void> setPitch(double pitch) => _backend.setPitch(pitch);
  Future<void> setRate(double rate) => _backend.setRate(rate);
  Future<void> setReplayGain(ReplayGainSettings settings) =>
      _backend.setReplayGain(settings);
  Future<void> setAudioDevice(Device device) => _backend.setAudioDevice(device);
  Future<void> setMediaSession(MediaSession? session) =>
      _backend.setMediaSession(session);
  Future<void> updateAudioEffects(
    AudioEffects Function(AudioEffects) update,
  ) =>
      _backend.updateAudioEffects(update);
  Future<void> setSpectrum(SpectrumSettings settings) =>
      _backend.setSpectrum(settings);
  Future<void> setAudioExclusive(bool exclusive) =>
      _backend.setAudioExclusive(exclusive);
  Future<void> setAudioNullUntimed(bool enabled) =>
      _backend.setAudioNullUntimed(enabled);
  Future<void> setAudioStreamSilence(bool enabled) =>
      _backend.setAudioStreamSilence(enabled);
  Future<void> setGapless(Gapless mode) => _backend.setGapless(mode);
  Future<void> setPrefetchPlaylist(bool enabled) =>
      _backend.setPrefetchPlaylist(enabled);
  Future<void> setRawProperty(String name, String value) =>
      _backend.setRawProperty(name, value);
  Future<void> setAudioClientName(String name) =>
      _backend.setAudioClientName(name);
  Future<void> dispose() => _backend.dispose();
}

/// mpv_audio_kit's PlayerStream, reimplemented over [AudioBackend] streams.
class PlayerStream {
  PlayerStream._(this._backend);

  final AudioBackend _backend;

  Stream<Duration> get position => _backend.positionStream;
  Stream<bool> get playing => _backend.playingStream;
  Stream<Duration> get duration => _backend.durationStream;
  Stream<bool> get completed => _backend.completedStream;
  Stream<MpvPlayerError> get error => _backend.errorStream;
  Stream<List<Device>> get audioDevices => _backend.audioDevicesStream;
  Stream<Device> get audioDevice => _backend.audioDeviceStream;
  Stream<Playlist> get playlist => Stream<Playlist>.value(_backend.playlist);
  Stream<MediaSessionCommand> get mediaSessionCommands =>
      const Stream<MediaSessionCommand>.empty();
  Stream<FftFrame> get fft => _backend.fftStream;
  Stream<PcmFrame> get pcm => _backend.pcmStream;
  Stream<LoudnessScan> get loudness => const Stream<LoudnessScan>.empty();
  Stream<double> get loudnessMeter => const Stream<double>.empty();
  Stream<AudioOutputState> get audioOutputState =>
      const Stream<AudioOutputState>.empty();
}

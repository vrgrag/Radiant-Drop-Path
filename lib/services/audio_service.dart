import 'package:audioplayers/audioplayers.dart';
import 'save_service.dart';

/// Thin wrapper around audioplayers for background music (single looping
/// player) and one-shot sound effects (short-lived low-latency players).
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _music = AudioPlayer(playerId: 'flux-music');
  String? _currentMusicAsset;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    // Our sound files are declared in pubspec under the top-level `sounds/`
    // directory (asset keys like `sounds/foo.mp3`). audioplayers' AudioCache
    // otherwise prepends `assets/`, which would make every path fail to load.
    AudioCache.instance.prefix = '';
    // iOS defaults to the `playback` category, which overrides the Ring/Silent
    // switch and stops whatever the user was listening to. A game should stay
    // in the background of the system audio instead.
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient)),
      );
    } catch (_) {
      // Non-fatal - fall back to the plugin defaults.
    }
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.setVolume(musicVolume);
    _initialized = true;
  }

  bool get musicEnabled => SaveService.instance.musicEnabled;
  bool get sfxEnabled => SaveService.instance.sfxEnabled;
  double get musicVolume => SaveService.instance.musicVolume;
  double get sfxVolume => SaveService.instance.sfxVolume;

  Future<void> playMusic(String asset) async {
    if (_currentMusicAsset == asset) return;
    _currentMusicAsset = asset;
    if (!musicEnabled) return;
    try {
      await _music.stop();
      await _music.setVolume(musicVolume);
      await _music.play(AssetSource(asset));
    } catch (_) {
      // Ignore playback errors (e.g. missing codec on some emulators).
    }
  }

  Future<void> refreshMusicState() async {
    if (!musicEnabled) {
      await _music.pause();
    } else if (_currentMusicAsset != null) {
      await _music.resume();
    }
  }

  /// Applies a new music volume to the live background player immediately.
  Future<void> setMusicVolume(double v) async {
    try {
      await _music.setVolume(v.clamp(0.0, 1.0));
    } catch (_) {
      // Ignore - volume is re-applied on next playMusic anyway.
    }
  }

  Future<void> stopMusic() async {
    _currentMusicAsset = null;
    await _music.stop();
  }

  /// Called when the app goes to background / is minimised.
  /// Pauses the music without clearing the current track so it can resume.
  Future<void> pauseForBackground() async {
    try {
      await _music.pause();
    } catch (_) {}
  }

  /// Called when the app returns to the foreground.
  Future<void> resumeFromBackground() async {
    if (!musicEnabled || _currentMusicAsset == null) return;
    try {
      await _music.resume();
    } catch (_) {}
  }

  Future<void> playSfx(String asset, {double volume = 0.9}) async {
    if (!sfxEnabled) return;
    final effectiveVolume = (volume * sfxVolume).clamp(0.0, 1.0);
    if (effectiveVolume <= 0) return;
    try {
      final player = AudioPlayer(playerId: 'sfx-${DateTime.now().microsecondsSinceEpoch}');
      await player.setReleaseMode(ReleaseMode.release);
      await player.setVolume(effectiveVolume);
      await player.play(AssetSource(asset));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (_) {
      // Ignore playback errors.
    }
  }
}

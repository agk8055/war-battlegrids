import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_settings_provider.dart';

class AudioService {
  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _isStoppedForMatch = false;
  
  // A larger circular pool is the most robust way to handle rapid SFX on Android
  final List<AudioPlayer> _pool = [];
  static const int _poolSize = 10;
  int _nextPlayerIndex = 0;
  
  final Ref _ref;

  AudioService(this._ref) {
    _musicPlayer.setReleaseMode(ReleaseMode.loop);
    _initPool();
  }

  void _initPool() {
    for (int i = 0; i < _poolSize; i++) {
      final p = AudioPlayer();
      // Use lowLatency mode which maps to SoundPool on Android (ideal for SFX)
      p.setPlayerMode(PlayerMode.lowLatency);
      _pool.add(p);
    }
  }

  /// Pre-warming the assets helps Android's native cache
  Future<void> preloadSfx(List<String> paths) async {
    for (final path in paths) {
      try {
        // Just triggering a load into the native cache
        final source = AssetSource(path);
        await _pool[0].setSource(source); 
      } catch (e) {
        debugPrint('AudioService: Preload failed for $path: $e');
      }
    }
  }

  Future<void> playMainTheme() async {
    final settings = _ref.read(gameSettingsProvider);
    if (!settings.musicEnabled || _isStoppedForMatch) return;
    
    // If it's already playing, just ensure volume is correct and return
    if (_musicPlayer.state == PlayerState.playing) {
      await _musicPlayer.setVolume(settings.musicVolume);
      return;
    }
    
    try {
      // Ensure we are stopped before starting fresh
      await _musicPlayer.stop();
      await _musicPlayer.setVolume(settings.musicVolume);
      await _musicPlayer.play(AssetSource('audio/Crown_of_the_Morning_Sky.mp3'));
    } catch (e) {
      debugPrint('AudioService: Failed to play main theme: $e');
    }
  }

  Future<void> stopMusic() async {
    await _musicPlayer.stop();
  }

  Future<void> stopMusicForMatch() async {
    _isStoppedForMatch = true;
    await stopMusic();
  }

  Future<void> resumeMusicAfterMatch() async {
    _isStoppedForMatch = false;
    await playMainTheme();
  }

  void playSfx(String path) {
    final settings = _ref.read(gameSettingsProvider);
    if (!settings.sfxEnabled) return;

    // Get the next player in the rotation
    final player = _pool[_nextPlayerIndex];
    _nextPlayerIndex = (_nextPlayerIndex + 1) % _poolSize;

    // Set volume and play. On Android, using a fresh play call on a 
    // rotating pool is the most reliable way to avoid the "stuck at end" issue.
    player.setVolume(settings.sfxVolume);
    player.stop().then((_) {
      player.play(AssetSource(path));
    });
  }

  void _applySettings(GameSettings settings) {
    if (settings.musicEnabled) {
      if (!_isStoppedForMatch) {
        if (_musicPlayer.state != PlayerState.playing) {
          playMainTheme();
        } else {
          _musicPlayer.setVolume(settings.musicVolume);
        }
      }
    } else {
      if (_musicPlayer.state == PlayerState.playing) {
        _musicPlayer.pause();
      }
    }
    
    // We set SFX volume per-play to ensure it's always current
  }

  void dispose() {
    _musicPlayer.dispose();
    for (final p in _pool) {
      p.dispose();
    }
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService(ref);
  
  ref.listen(gameSettingsProvider, (previous, next) {
    if (previous?.musicEnabled != next.musicEnabled || 
        previous?.musicVolume != next.musicVolume ||
        previous?.sfxEnabled != next.sfxEnabled ||
        previous?.sfxVolume != next.sfxVolume) {
      service._applySettings(next);
    }
  }, fireImmediately: true);

  ref.onDispose(() => service.dispose());
  return service;
});

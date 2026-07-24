import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_settings_provider.dart';

import '../../core/constants/app_assets.dart';

class AudioService with WidgetsBindingObserver {
  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _isStoppedForMatch = false;
  bool _wasPlayingBeforePause = false;
  
  // A larger circular pool is the most robust way to handle rapid SFX on Android
  final List<AudioPlayer> _pool = [];
  static const int _poolSize = 10;
  int _nextPlayerIndex = 0;
  
  final Ref _ref;

  AudioService(this._ref) {
    _musicPlayer.setReleaseMode(ReleaseMode.loop);
    _initPool();
    WidgetsBinding.instance.addObserver(this);
  }

  void _initPool() {
    for (int i = 0; i < _poolSize; i++) {
      final p = AudioPlayer();
      // Use lowLatency mode which maps to SoundPool on Android (ideal for SFX)
      p.setPlayerMode(PlayerMode.lowLatency);
      _pool.add(p);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App is in background or screen off
      if (_musicPlayer.state == PlayerState.playing) {
        _wasPlayingBeforePause = true;
        _musicPlayer.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App is back in foreground
      if (_wasPlayingBeforePause && !_isStoppedForMatch) {
        final settings = _ref.read(gameSettingsProvider);
        if (settings.musicEnabled) {
          _musicPlayer.resume();
        }
      }
      _wasPlayingBeforePause = false;
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
      await _musicPlayer.play(AssetSource(AppAssets.mainThemePath));
    } catch (e) {
      debugPrint('AudioService: Failed to play main theme: $e');
    }
  }

  Future<void> stopMusic() async {
    try {
      await _musicPlayer.stop();
    } catch (e) {
      debugPrint('AudioService: Failed to stop music: $e');
    }
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

    // Set volume and play.
    player.setVolume(settings.sfxVolume);
    player.stop().then((_) {
      try {
        player.play(AssetSource(path));
      } catch (e) {
        debugPrint('AudioService: Failed to play SFX $path: $e');
      }
    }).catchError((e) {
      debugPrint('AudioService: Error stopping player before SFX $path: $e');
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
    WidgetsBinding.instance.removeObserver(this);
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

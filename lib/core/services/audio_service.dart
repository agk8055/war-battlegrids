import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_settings_provider.dart';

class AudioService {
  final AudioPlayer _musicPlayer = AudioPlayer();
  final Ref _ref;

  AudioService(this._ref) {
    _musicPlayer.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> playMainTheme() async {
    final settings = _ref.read(gameSettingsProvider);
    if (!settings.musicEnabled) return;
    
    await _musicPlayer.setVolume(settings.musicVolume);
    await _musicPlayer.play(AssetSource('audio/Crown_of_the_Morning_Sky.mp3'));
  }

  Future<void> stopMusic() async {
    await _musicPlayer.stop();
  }

  void _applySettings(GameSettings settings) {
    if (settings.musicEnabled) {
      if (_musicPlayer.state != PlayerState.playing) {
        playMainTheme();
      } else {
        _musicPlayer.setVolume(settings.musicVolume);
      }
    } else {
      if (_musicPlayer.state == PlayerState.playing) {
        _musicPlayer.pause();
      }
    }
  }

  void dispose() {
    _musicPlayer.dispose();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService(ref);
  
  // Listen to settings changes and apply them to the service
  ref.listen(gameSettingsProvider, (previous, next) {
    if (previous?.musicEnabled != next.musicEnabled || 
        previous?.musicVolume != next.musicVolume) {
      service._applySettings(next);
    }
  }, fireImmediately: true);

  ref.onDispose(() => service.dispose());
  return service;
});

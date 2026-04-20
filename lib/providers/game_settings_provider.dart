import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/enums/game_mode.dart';

class GameSettings {
  final GameMode mode;
  final String selectedMapPath;
  final String player1Name;
  final String player2Name;
  final int kingdomAttackThreshold;
  final bool musicEnabled;
  final double musicVolume;

  GameSettings({
    this.mode = GameMode.story,
    this.selectedMapPath = '25x25_map.tmx',
    this.player1Name = 'PLAYER 1',
    this.player2Name = 'PLAYER 2',
    this.kingdomAttackThreshold = 100, // Default threshold
    this.musicEnabled = true,
    this.musicVolume = 0.5,
  });

  GameSettings copyWith({
    GameMode? mode,
    String? selectedMapPath,
    String? player1Name,
    String? player2Name,
    int? kingdomAttackThreshold,
    bool? musicEnabled,
    double? musicVolume,
  }) {
    return GameSettings(
      mode: mode ?? this.mode,
      selectedMapPath: selectedMapPath ?? this.selectedMapPath,
      player1Name: player1Name ?? this.player1Name,
      player2Name: player2Name ?? this.player2Name,
      kingdomAttackThreshold: kingdomAttackThreshold ?? this.kingdomAttackThreshold,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      musicVolume: musicVolume ?? this.musicVolume,
    );
  }
}

class GameSettingsNotifier extends Notifier<GameSettings> {
  static const _keyMusicEnabled = 'music_enabled';
  static const _keyMusicVolume = 'music_volume';

  @override
  GameSettings build() {
    _loadSettings();
    return GameSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final musicEnabled = prefs.getBool(_keyMusicEnabled) ?? true;
    final musicVolume = prefs.getDouble(_keyMusicVolume) ?? 0.5;

    state = state.copyWith(
      musicEnabled: musicEnabled,
      musicVolume: musicVolume,
    );
  }

  Future<void> setMusicEnabled(bool enabled) async {
    state = state.copyWith(musicEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMusicEnabled, enabled);
  }

  Future<void> setMusicVolume(double volume) async {
    state = state.copyWith(musicVolume: volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMusicVolume, volume);
  }

  void setMode(GameMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setSelectedMap(String mapPath) {
    state = state.copyWith(selectedMapPath: mapPath);
  }

  void setPlayerNames(String p1, String p2) {
    state = state.copyWith(player1Name: p1, player2Name: p2);
  }

  void setKingdomAttackThreshold(int threshold) {
    state = state.copyWith(kingdomAttackThreshold: threshold);
  }
}

final gameSettingsProvider = NotifierProvider<GameSettingsNotifier, GameSettings>(() {
  return GameSettingsNotifier();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/enums/game_mode.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class GameSettings {
  final GameMode mode;
  final String selectedMapPath;
  final String player1Name;
  final String player2Name;
  final String player1Symbol;
  final String player2Symbol;
  final int kingdomAttackThreshold;
  final bool musicEnabled;
  final double musicVolume;
  final bool sfxEnabled;
  final double sfxVolume;

  GameSettings({
    this.mode = GameMode.story,
    this.selectedMapPath = '25x25_map.tmx',
    this.player1Name = 'PLAYER 1',
    this.player2Name = 'PLAYER 2',
    this.player1Symbol = 'assets/symbols/fire.png',
    this.player2Symbol = 'assets/icons/eagle.png',
    this.kingdomAttackThreshold = 100,
    this.musicEnabled = true,
    this.musicVolume = 0.5,
    this.sfxEnabled = true,
    this.sfxVolume = 0.7,
  });

  GameSettings copyWith({
    GameMode? mode,
    String? selectedMapPath,
    String? player1Name,
    String? player2Name,
    String? player1Symbol,
    String? player2Symbol,
    int? kingdomAttackThreshold,
    bool? musicEnabled,
    double? musicVolume,
    bool? sfxEnabled,
    double? sfxVolume,
  }) {
    return GameSettings(
      mode: mode ?? this.mode,
      selectedMapPath: selectedMapPath ?? this.selectedMapPath,
      player1Name: player1Name ?? this.player1Name,
      player2Name: player2Name ?? this.player2Name,
      player1Symbol: player1Symbol ?? this.player1Symbol,
      player2Symbol: player2Symbol ?? this.player2Symbol,
      kingdomAttackThreshold: kingdomAttackThreshold ?? this.kingdomAttackThreshold,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      musicVolume: musicVolume ?? this.musicVolume,
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      sfxVolume: sfxVolume ?? this.sfxVolume,
    );
  }
}

class GameSettingsNotifier extends Notifier<GameSettings> {
  static const _keyMusicEnabled = 'music_enabled';
  static const _keyMusicVolume = 'music_volume';
  static const _keySfxEnabled = 'sfx_enabled';
  static const _keySfxVolume = 'sfx_volume';
  static const _keyKingdomName = 'kingdom_name';
  static const _keyKingdomSymbol = 'kingdom_symbol';

  @override
  GameSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    
    final musicEnabled = prefs.getBool(_keyMusicEnabled) ?? true;
    final musicVolume = prefs.getDouble(_keyMusicVolume) ?? 0.5;
    final sfxEnabled = prefs.getBool(_keySfxEnabled) ?? true;
    final sfxVolume = prefs.getDouble(_keySfxVolume) ?? 0.7;
    
    final savedName = prefs.getString(_keyKingdomName);
    final savedSymbol = prefs.getString(_keyKingdomSymbol);

    return GameSettings(
      musicEnabled: musicEnabled,
      musicVolume: musicVolume,
      sfxEnabled: sfxEnabled,
      sfxVolume: sfxVolume,
      player1Name: savedName ?? 'PLAYER 1',
      player1Symbol: savedSymbol ?? 'assets/symbols/fire.png',
    );
  }

  Future<void> setMusicEnabled(bool enabled) async {
    state = state.copyWith(musicEnabled: enabled);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_keyMusicEnabled, enabled);
  }

  Future<void> setMusicVolume(double volume) async {
    state = state.copyWith(musicVolume: volume);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble(_keyMusicVolume, volume);
  }

  Future<void> setSfxEnabled(bool enabled) async {
    state = state.copyWith(sfxEnabled: enabled);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_keySfxEnabled, enabled);
  }

  Future<void> setSfxVolume(double volume) async {
    state = state.copyWith(sfxVolume: volume);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble(_keySfxVolume, volume);
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

  void setPlayerSymbols(String s1, String s2) {
    state = state.copyWith(player1Symbol: s1, player2Symbol: s2);
  }
}

final gameSettingsProvider = NotifierProvider<GameSettingsNotifier, GameSettings>(() {
  return GameSettingsNotifier();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_assets.dart';
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
  final int player1Color;
  final int player2Color;
  final int kingdomAttackThreshold;
  final bool musicEnabled;
  final double musicVolume;
  final bool sfxEnabled;
  final double sfxVolume;

  GameSettings({
    this.mode = GameMode.story,
    this.selectedMapPath = AppAssets.defaultMap,
    this.player1Name = 'PLAYER 1',
    this.player2Name = 'PLAYER 2',
    this.player1Symbol = AppAssets.fire,
    this.player2Symbol = AppAssets.eagle,
    this.player1Color = 0xFF2196F3, // Colors.blue
    this.player2Color = 0xFFF44336, // Colors.red
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
    int? player1Color,
    int? player2Color,
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
      player1Color: player1Color ?? this.player1Color,
      player2Color: player2Color ?? this.player2Color,
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
      player1Symbol: savedSymbol ?? AppAssets.fire,
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

  Future<void> setPlayer1Name(String name) async {
    state = state.copyWith(player1Name: name);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_keyKingdomName, name);
  }

  Future<void> setPlayer1Symbol(String symbol) async {
    state = state.copyWith(player1Symbol: symbol);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_keyKingdomSymbol, symbol);
  }

  void setKingdomAttackThreshold(int threshold) {
    state = state.copyWith(kingdomAttackThreshold: threshold);
  }

  void setPlayerSymbols(String s1, String s2) {
    state = state.copyWith(player1Symbol: s1, player2Symbol: s2);
  }

  void setPlayerColors(int c1, int c2) {
    state = state.copyWith(player1Color: c1, player2Color: c2);
  }
}

final gameSettingsProvider = NotifierProvider<GameSettingsNotifier, GameSettings>(() {
  return GameSettingsNotifier();
});

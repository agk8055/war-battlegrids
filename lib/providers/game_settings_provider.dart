import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/enums/game_mode.dart';

class GameSettings {
  final GameMode mode;
  final String selectedMapPath;
  final String player1Name;
  final String player2Name;
  final int kingdomAttackThreshold;

  GameSettings({
    this.mode = GameMode.story,
    this.selectedMapPath = '25x25_map.tmx',
    this.player1Name = 'PLAYER 1',
    this.player2Name = 'PLAYER 2',
    this.kingdomAttackThreshold = 100, // Default threshold
  });

  GameSettings copyWith({
    GameMode? mode,
    String? selectedMapPath,
    String? player1Name,
    String? player2Name,
    int? kingdomAttackThreshold,
  }) {
    return GameSettings(
      mode: mode ?? this.mode,
      selectedMapPath: selectedMapPath ?? this.selectedMapPath,
      player1Name: player1Name ?? this.player1Name,
      player2Name: player2Name ?? this.player2Name,
      kingdomAttackThreshold: kingdomAttackThreshold ?? this.kingdomAttackThreshold,
    );
  }
}

class GameSettingsNotifier extends Notifier<GameSettings> {
  @override
  GameSettings build() {
    return GameSettings();
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

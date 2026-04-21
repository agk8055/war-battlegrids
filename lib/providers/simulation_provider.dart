import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../simulation/game_simulation.dart';
import '../campaign/campaign_manager.dart';
import '../campaign/data/battle_configs.dart';
import '../core/models/level_config.dart';
import 'game_settings_provider.dart';
import '../core/enums/game_mode.dart';

/// Provider for the full game simulation instance.
final simulationProvider = NotifierProvider<SimulationNotifier, GameSimulation>(
  () {
    return SimulationNotifier();
  },
);

class SimulationNotifier extends Notifier<GameSimulation> {
  @override
  GameSimulation build() {
    final settings = ref.watch(gameSettingsProvider);
    
    if (settings.mode == GameMode.multiplayer) {
      return GameSimulation(
        config: LevelConfig(
          boardWidth: 25,
          boardHeight: 25,
          playerKingdomAttackThreshold: settings.kingdomAttackThreshold,
          aiKingdomAttackThreshold: settings.kingdomAttackThreshold,
        ),
      );
    }

    final campaignState = ref.watch(campaignProvider);
    final kingdomId = campaignState.selectedKingdomId;

    if (kingdomId != null) {
      final battleConfig = kBattleConfigs[kingdomId];
      if (battleConfig != null) {
        return GameSimulation(config: battleConfig.levelConfig);
      }
    }

    return GameSimulation();
  }

  /// Attempts to place a unit and updates state if successful.
  /// Returns a record: (success, captureOccurred)
  (bool, bool) placeUnit(int x, int y) {
    final result = state.placeUnit(x, y);
    if (result.$1) {
      // Force riverpod to trigger a rebuild by assigning a genuinely new instance
      state = state.clone();
    }
    return result;
  }

  /// Resets the current simulation to its initial state based on the current config.
  void reset() {
    state = GameSimulation(config: state.config);
  }
}


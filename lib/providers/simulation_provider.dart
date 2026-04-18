import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../simulation/game_simulation.dart';
import '../campaign/campaign_manager.dart';
import '../campaign/data/battle_configs.dart';

/// Provider for the full game simulation instance.
final simulationProvider = NotifierProvider<SimulationNotifier, GameSimulation>(
  () {
    return SimulationNotifier();
  },
);

class SimulationNotifier extends Notifier<GameSimulation> {
  @override
  GameSimulation build() {
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
  bool placeUnit(int x, int y) {
    bool success = state.placeUnit(x, y);
    if (success) {
      // Force riverpod to trigger a rebuild by assigning a genuinely new instance
      state = state.clone();
    }
    return success;
  }

  /// Resets the current simulation to its initial state based on the current config.
  void reset() {
    state = GameSimulation(config: state.config);
  }
}


import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../simulation/game_simulation.dart';

/// Provider for the full game simulation instance.
final simulationProvider = NotifierProvider<SimulationNotifier, GameSimulation>(
  () {
    return SimulationNotifier();
  },
);

class SimulationNotifier extends Notifier<GameSimulation> {
  @override
  GameSimulation build() {
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
}

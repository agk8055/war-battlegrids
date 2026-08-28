import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../simulation/game_simulation.dart';
import '../campaign/campaign_manager.dart';
import '../campaign/data/battle_configs.dart';
import '../core/models/level_config.dart';
import 'game_settings_provider.dart';
import '../core/enums/game_mode.dart';
import '../core/enums/connection_type.dart';
import 'bluetooth_provider.dart';
import 'online_provider.dart';
import 'turn_provider.dart';
import '../core/enums/turn.dart';

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
      int width = 25;
      int height = 25;
      
      if (settings.selectedMapPath.contains('15x15')) {
        width = 15;
        height = 15;
      }

      return GameSimulation(
        config: LevelConfig(
          boardWidth: width,
          boardHeight: height,
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
    final connectionType = ref.read(connectionTypeProvider);

    if (connectionType == ConnectionType.bluetooth) {
      final bluetoothState = ref.read(bluetoothProvider);
      if (bluetoothState.status == BluetoothStatus.connected) {
        final myTurn = bluetoothState.isHost ? Turn.player : Turn.ai;
        if (state.currentTurn != myTurn) return (false, false);
        
        final result = state.placeUnit(x, y);
        if (result.$1) {
          ref.read(bluetoothProvider.notifier).sendMove(x, y);
          state = state.clone();
        }
        return result;
      }
    } else if (connectionType == ConnectionType.online) {
      final onlineState = ref.read(onlineProvider);
      if (onlineState.status == OnlineStatus.connected) {
        final myTurn = onlineState.isHost ? Turn.player : Turn.ai;
        if (state.currentTurn != myTurn) return (false, false);
        
        final result = state.placeUnit(x, y);
        if (result.$1) {
          ref.read(onlineProvider.notifier).sendMove(x, y);
          state = state.clone();
        }
        return result;
      }
    }

    final result = state.placeUnit(x, y);
    if (result.$1) {
      state = state.clone();
    }
    return result;
  }

  /// Skips the current turn and updates state.
  void skipTurn() {
    state.skipTurn();
    state = state.clone();
  }

  /// Explicitly marks the game as a Draw / Stalemate.
  void declareDraw() {
    state.declareDraw();
    state = state.clone();
  }

  /// Places a unit from a peer without sending it back.
  (bool, bool) placeUnitFromPeer(int x, int y) {
    final connectionType = ref.read(connectionTypeProvider);
    Turn? peerTurn;

    if (connectionType == ConnectionType.bluetooth) {
      final bluetoothState = ref.read(bluetoothProvider);
      peerTurn = bluetoothState.isHost ? Turn.ai : Turn.player;
    } else if (connectionType == ConnectionType.online) {
      final onlineState = ref.read(onlineProvider);
      peerTurn = onlineState.isHost ? Turn.ai : Turn.player;
    }
    
    if (peerTurn == null || state.currentTurn != peerTurn) {
      return (false, false);
    }

    final result = state.placeUnit(x, y);
    if (result.$1) {
      state = state.clone();
    }
    return result;
  }

  /// Resets the current simulation to its initial state based on the current config.
  void reset() {
    state = GameSimulation(config: state.config);
  }
}



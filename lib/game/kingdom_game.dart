import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../campaign/campaign_manager.dart';
import '../../campaign/data/battle_configs.dart';
import '../../providers/turn_provider.dart';
import '../../providers/simulation_provider.dart';
import '../../providers/game_settings_provider.dart';
import '../../simulation/ai/ai_strategy.dart';

import '../core/enums/turn.dart';
import '../core/enums/game_mode.dart';
import '../core/enums/game_phase.dart';
import 'board/board_component.dart';

class KingdomGame extends FlameGame with ScaleDetector {
  final WidgetRef ref;
  late BoardComponent boardComponent;

  double _startScale = 1.0;

  KingdomGame(this.ref);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final simulation = ref.read(simulationProvider);
    final settings = ref.read(gameSettingsProvider);

    // Create the board visualization
    boardComponent = BoardComponent(
      simulationBoard: simulation.board,
      cellSize: 40.0,
      mapPath: settings.selectedMapPath,
      onCellTapped: _handleCellTapped,
    );

    // Default 1.0 scale to maintain tappable tile sizes. (Rely on panning)
    final fitScale = 1.0;

    boardComponent.scale = Vector2.all(fitScale);
    _startScale = fitScale;

    // Center the properly scaled board loosely
    boardComponent.position = Vector2(
      (size.x - (boardComponent.size.x * fitScale)) / 2,
      (size.y - (boardComponent.size.y * fitScale)) / 2,
    );

    add(boardComponent);
    
    // Ensure it's clamped immediately
    _clampPosition();
  }

  void _handleCellTapped(int x, int y) {
    final notifier = ref.read(simulationProvider.notifier);
    final simulationState = ref.read(simulationProvider);
    final settings = ref.read(gameSettingsProvider);

    // Prevent tap if game is over or AI is thinking
    if (simulationState.currentPhase == GamePhase.gameOver) return;
    
    // In story mode, prevent tap if it's AI turn
    if (settings.mode == GameMode.story && simulationState.currentTurn == Turn.ai) {
      return;
    }

    final success = notifier.placeUnit(x, y);

    if (success) {
      boardComponent.syncWithSimulation(ref.read(simulationProvider).board);
      
      if (settings.mode == GameMode.story) {
        _checkAITurn();
      }
    }
  }

  void _checkAITurn() async {
    final simulationState = ref.read(simulationProvider);
    if (simulationState.currentPhase == GamePhase.gameOver) return;

    if (simulationState.currentTurn == Turn.ai) {
      // Set UI to thinking state
      ref.read(aiStateProvider.notifier).setThinking();

      // Get AI strategy from battle config
      final campaignState = ref.read(campaignProvider);
      final kingdomId = campaignState.selectedKingdomId;
      final strategy = (kingdomId != null) 
          ? (kBattleConfigs[kingdomId]?.aiStrategy ?? AIStrategy.fromType(AIStrategyType.basic)) 
          : AIStrategy.fromType(AIStrategyType.basic);

      // Offload AI calculation to Background Isolate
      final bestMove = await AIManager.calculateNextMove(simulationState, strategy);

      // Add a slight artificial delay so the AI doesn't feel instantaneous, giving the player a moment to process the board.
      await Future.delayed(const Duration(milliseconds: 600));

      ref.read(aiStateProvider.notifier).setIdle();

      if (bestMove != null) {
        final notifier = ref.read(simulationProvider.notifier);
        final success = notifier.placeUnit(bestMove.$1, bestMove.$2);
        if (success) {
          boardComponent.syncWithSimulation(ref.read(simulationProvider).board);
        }
      }
    }
  }

  /// Force a visual sync from the outside (useful if AI takes a turn)
  void forceSync() {
    boardComponent.syncWithSimulation(ref.read(simulationProvider).board);
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    _startScale = boardComponent.scale.x;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    // 1. Panning
    boardComponent.position += info.delta.global;

    // 2. Zooming (pinch)
    if (info.pointerCount > 1) {
      // Calculate the new scale, clamped to reasonable bounds
      double newScale = _startScale * info.scale.global.x;
      newScale = newScale.clamp(0.5, 4.0); // Slightly more zoom freedom
      boardComponent.scale = Vector2.all(newScale);
    }

    // 3. Clamping - Ensure board doesn't fly off screen
    _clampPosition();
  }

  void _clampPosition() {
    final scaledWidth = boardComponent.width * boardComponent.scale.x;
    final scaledHeight = boardComponent.height * boardComponent.scale.y;

    // X-Axis Clamping
    if (scaledWidth > size.x) {
      // Board is wider than screen: clamp between (size.x - scaledWidth) and 0
      boardComponent.x = boardComponent.x.clamp(size.x - scaledWidth, 0);
    } else {
      // Board is narrower: keep it centered or at least within view
      boardComponent.x = boardComponent.x.clamp(0, size.x - scaledWidth);
    }

    // Y-Axis Clamping
    if (scaledHeight > size.y) {
      // Board is taller than screen
      boardComponent.y = boardComponent.y.clamp(size.y - scaledHeight, 0);
    } else {
      // Board is shorter
      boardComponent.y = boardComponent.y.clamp(0, size.y - scaledHeight);
    }
  }
}

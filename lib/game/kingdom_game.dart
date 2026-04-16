import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/simulation_provider.dart';
import '../providers/turn_provider.dart';
import '../core/enums/turn.dart';
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

    // Create the board visualization
    boardComponent = BoardComponent(
      simulationBoard: simulation.board,
      cellSize: 40.0,
      onCellTapped: _handleCellTapped,
    );

    // Default 1.0 scale to maintain tappable tile sizes. (Rely on panning)
    final fitScale = 1.0;
    
    boardComponent.scale = Vector2.all(fitScale);
    _startScale = fitScale;

    // Center the properly scaled board loosely
    boardComponent.position = Vector2(
      (size.x - (boardComponent.size.x * fitScale)) / 2,
      (size.y - (boardComponent.size.y * fitScale)) / 2 + 50,
    );

    add(boardComponent);
  }

  void _handleCellTapped(int x, int y) {
    final notifier = ref.read(simulationProvider.notifier);
    final simulationState = ref.read(simulationProvider);

    // Prevent tap if game is over or AI is thinking
    if (simulationState.currentPhase == GamePhase.gameOver) return;
    if (simulationState.currentTurn == Turn.ai) return;

    final success = notifier.placeUnit(x, y);

    if (success) {
      boardComponent.syncWithSimulation(ref.read(simulationProvider).board);
      _checkAITurn();
    }
  }

  void _checkAITurn() async {
    final simulationState = ref.read(simulationProvider);
    if (simulationState.currentPhase == GamePhase.gameOver) return;

    if (simulationState.currentTurn == Turn.ai) {
      // Set UI to thinking state
      ref.read(aiStateProvider.notifier).setThinking();

      // Offload AI calculation to Background Isolate (Depth 2 for faster, slightly more beatable play)
      final bestMove = await AIManager.calculateNextMove(simulationState, 2);

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
    // Panning
    boardComponent.position += info.delta.global;

    // Zooming (pinch)
    if (info.pointerCount > 1) {
      // Calculate the new scale, clamped to reasonable bounds
      double newScale = _startScale * info.scale.global.x;
      newScale = newScale.clamp(0.3, 3.0);
      boardComponent.scale = Vector2.all(newScale);
    }
  }
}

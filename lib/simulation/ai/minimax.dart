import 'dart:math';
import '../game_simulation.dart';

import '../../core/enums/game_phase.dart';
import 'evaluator.dart';

class MinimaxAI {
  /// Calculates the best legally available move for the AI using Minimax with Alpha-Beta pruning.
  /// Returns the coordinates (x, y) to place a piece, or null if no moves are available.
  static (int, int)? getBestMove(GameSimulation sim, int maxDepth) {
    int bestScore = -9999999;
    (int, int)? bestMove;

    final availableMoves = sim.board.getAvailableCells(allowZones: true);

    // 20% chance to make a completely random mistake to make it beatable
    if (availableMoves.isNotEmpty && Random().nextDouble() < 0.20) {
      final randMove = availableMoves[Random().nextInt(availableMoves.length)];
      if (_cloneSimulation(sim).placeUnit(randMove.$1, randMove.$2)) {
        return randMove;
      }
    }

    // Alpha-beta pruning bounds
    int alpha = -9999999;
    int beta = 9999999;

    for (final move in availableMoves) {
      // Clone game simulation state completely for branching
      final GameSimulation simClone = _cloneSimulation(sim);

      // Attempt the move
      bool valid = simClone.placeUnit(move.$1, move.$2);
      if (!valid)
        continue; // Move was illegal (e.g. into enemy palace without unlock)

      // Recursively evaluate the new board state as the Opposing player (Player)
      int score = _minimax(simClone, maxDepth - 1, alpha, beta, false);

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }

      alpha = max(alpha, bestScore);
      if (beta <= alpha) break; // Prune
    }

    // Fallback pseudo-random move if all branches are completely neutral (score 0),
    // to give it variety, though MiniMax usually finds a "best" edge move early.
    if (bestMove == null && availableMoves.isNotEmpty) {
      for (final m in availableMoves) {
        final testClone = _cloneSimulation(sim);
        if (testClone.placeUnit(m.$1, m.$2)) {
          return m;
        }
      }
    }

    return bestMove;
  }

  static int _minimax(
    GameSimulation sim,
    int depth,
    int alpha,
    int beta,
    bool isMaximizingPlayer,
  ) {
    if (depth == 0 || sim.currentPhase == GamePhase.gameOver) {
      return HeuristicEvaluator.evaluate(sim);
    }

    final availableMoves = sim.board.getAvailableCells(allowZones: true);

    if (isMaximizingPlayer) {
      int maxEval = -9999999;
      for (final move in availableMoves) {
        final GameSimulation simClone = _cloneSimulation(sim);
        if (!simClone.placeUnit(move.$1, move.$2)) continue;

        int eval = _minimax(simClone, depth - 1, alpha, beta, false);
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) break;
      }
      // If no valid moves were found, return static evaluation
      if (maxEval == -9999999) return HeuristicEvaluator.evaluate(sim);
      return maxEval;
    } else {
      int minEval = 9999999;
      for (final move in availableMoves) {
        final GameSimulation simClone = _cloneSimulation(sim);
        if (!simClone.placeUnit(move.$1, move.$2)) continue;

        int eval = _minimax(simClone, depth - 1, alpha, beta, true);
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) break;
      }
      if (minEval == 9999999) return HeuristicEvaluator.evaluate(sim);
      return minEval;
    }
  }

  /// Deep clones a simulation instance so we can branch without destroying real state.
  static GameSimulation _cloneSimulation(GameSimulation original) {
    final clone = GameSimulation(config: original.config);
    // Copy Board
    for (int y = 0; y < original.board.height; y++) {
      for (int x = 0; x < original.board.width; x++) {
        clone.board.setCell(x, y, original.board.getCell(x, y));
      }
    }
    // Copy Game State
    clone.currentPhase = original.currentPhase;
    clone.currentTurn = original.currentTurn;
    clone.playerScore = original.playerScore;
    clone.aiScore = original.aiScore;
    clone.playerKingdomAttackUnlocked = original.playerKingdomAttackUnlocked;
    clone.aiKingdomAttackUnlocked = original.aiKingdomAttackUnlocked;

    return clone;
  }
}

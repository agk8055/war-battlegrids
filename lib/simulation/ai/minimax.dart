import 'dart:math';
import '../game_simulation.dart';
import '../board.dart';
import '../../core/enums/game_phase.dart';
import '../../core/enums/turn.dart';
import 'evaluator.dart';
import 'zobrist_hash.dart';

class TranspositionEntry {
  final int score;
  final int depth;
  final int type; // 0: exact, 1: lower bound, 2: upper bound

  TranspositionEntry(this.score, this.depth, this.type);
}

class MinimaxAI {
  static final Map<int, TranspositionEntry> _transpositionTable = {};

  /// Calculates the best legally available move for the AI using Minimax with Alpha-Beta pruning.
  /// Returns the coordinates (x, y) to place a piece, or null if no moves are available.
  static (int, int)? getBestMove(GameSimulation sim, int maxDepth) {
    ZobristHash.initialize(sim.board.width, sim.board.height);
    _transpositionTable.clear();

    int bestScore = -9999999;
    (int, int)? bestMove;

    // Use restricted moves for performance
    final availableMoves = sim.board.getRestrictedAvailableCells(radius: 2, allowZones: true);
    
    // Sort moves to improve pruning (simple heuristic: center-first or just distance-based)
    _sortMoves(availableMoves, sim.board);

    // 10% chance to make a mistake (reduced from 20%)
    if (availableMoves.isNotEmpty && Random().nextDouble() < 0.10) {
      final randMove = availableMoves[Random().nextInt(availableMoves.length)];
      final simClone = _cloneSimulation(sim);
      if (simClone.placeUnit(randMove.$1, randMove.$2)) {
        return randMove;
      }
    }

    int alpha = -9999999;
    int beta = 9999999;

    for (final move in availableMoves) {
      final GameSimulation simClone = _cloneSimulation(sim);

      if (!simClone.placeUnit(move.$1, move.$2)) continue;

      int score = _minimax(simClone, maxDepth - 1, alpha, beta, false);

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }

      alpha = max(alpha, bestScore);
      if (beta <= alpha) break;
    }

    if (bestMove == null && availableMoves.isNotEmpty) {
      return availableMoves.first;
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
    int hash = ZobristHash.computeHash(sim.board, isMaximizingPlayer);
    final entry = _transpositionTable[hash];
    if (entry != null && entry.depth >= depth) {
      if (entry.type == 0) return entry.score;
      if (entry.type == 1) alpha = max(alpha, entry.score);
      else if (entry.type == 2) beta = min(beta, entry.score);

      if (alpha >= beta) return entry.score;
    }

    if (depth == 0 || sim.currentPhase == GamePhase.gameOver) {
      return HeuristicEvaluator.evaluate(sim);
    }

    final availableMoves = sim.board.getRestrictedAvailableCells(radius: 2, allowZones: true);
    _sortMoves(availableMoves, sim.board);

    int originalAlpha = alpha;

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
      
      _storeEntry(hash, maxEval, depth, originalAlpha, beta);
      return maxEval == -9999999 ? HeuristicEvaluator.evaluate(sim) : maxEval;
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

      _storeEntry(hash, minEval, depth, originalAlpha, beta);
      return minEval == 9999999 ? HeuristicEvaluator.evaluate(sim) : minEval;
    }
  }

  static void _storeEntry(int hash, int score, int depth, int alpha, int beta) {
    int type = 0;
    if (score <= alpha) type = 2;
    else if (score >= beta) type = 1;
    _transpositionTable[hash] = TranspositionEntry(score, depth, type);
  }

  static void _sortMoves(List<(int, int)> moves, Board board) {
    // Basic move ordering: prefer cells closer to the center
    final centerX = board.width / 2;
    final centerY = board.height / 2;

    moves.sort((a, b) {
      final dxA = a.$1 - centerX;
      final dyA = a.$2 - centerY;
      final distA = dxA * dxA + dyA * dyA;

      final dxB = b.$1 - centerX;
      final dyB = b.$2 - centerY;
      final distB = dxB * dxB + dyB * dyB;

      return distA.compareTo(distB);
    });
  }

  /// Deep clones a simulation instance so we can branch without destroying real state.
  static GameSimulation _cloneSimulation(GameSimulation original) {
    return original.clone();
  }
}

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
  static final Map<int, List<(int, int)>> _killerMoves = {};

  /// Calculates the best legally available move for the AI using Minimax with Alpha-Beta pruning,
  /// PVS (Principal Variation Search), and Killer Heuristic.
  static (int, int)? getBestMove(GameSimulation sim, int maxDepth) {
    ZobristHash.initialize(sim.board.width, sim.board.height);
    _transpositionTable.clear();
    _killerMoves.clear();

    int bestScore = -9999999;
    (int, int)? bestMove;

    final availableMoves = sim.board.getRestrictedAvailableCells(radius: 2, allowZones: false);
    _sortMoves(availableMoves, sim.board, maxDepth);

    // 10% chance to make a mistake
    if (availableMoves.isNotEmpty && Random().nextDouble() < 0.10) {
      final randMove = availableMoves[Random().nextInt(availableMoves.length)];
      final simClone = _cloneSimulation(sim);
      if (simClone.placeUnit(randMove.$1, randMove.$2)) {
        return randMove;
      }
    }

    int alpha = -9999999;
    int beta = 9999999;

    bool firstMove = true;
    for (final move in availableMoves) {
      final GameSimulation simClone = _cloneSimulation(sim);
      if (!simClone.placeUnit(move.$1, move.$2)) continue;

      int score;
      if (firstMove) {
        score = _minimax(simClone, maxDepth - 1, alpha, beta, false);
        firstMove = false;
      } else {
        // Null window search
        score = _minimax(simClone, maxDepth - 1, alpha, alpha + 1, false);
        if (score > alpha && score < beta) {
          score = _minimax(simClone, maxDepth - 1, alpha, beta, false);
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }

      alpha = max(alpha, bestScore);
      if (beta <= alpha) break;
    }

    return bestMove ?? (availableMoves.isNotEmpty ? availableMoves.first : null);
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

    final availableMoves = sim.board.getRestrictedAvailableCells(radius: 2, allowZones: false);
    _sortMoves(availableMoves, sim.board, depth);

    int originalAlpha = alpha;
    bool firstMove = true;

    if (isMaximizingPlayer) {
      int maxEval = -9999999;
      for (final move in availableMoves) {
        final GameSimulation simClone = _cloneSimulation(sim);
        if (!simClone.placeUnit(move.$1, move.$2)) continue;

        int eval;
        if (firstMove) {
          eval = _minimax(simClone, depth - 1, alpha, beta, false);
          firstMove = false;
        } else {
          eval = _minimax(simClone, depth - 1, alpha, alpha + 1, false);
          if (eval > alpha && eval < beta) {
            eval = _minimax(simClone, depth - 1, alpha, beta, false);
          }
        }

        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) {
          _storeKillerMove(move, depth);
          break;
        }
      }
      
      _storeEntry(hash, maxEval, depth, originalAlpha, beta);
      return maxEval == -9999999 ? HeuristicEvaluator.evaluate(sim) : maxEval;
    } else {
      int minEval = 9999999;
      for (final move in availableMoves) {
        final GameSimulation simClone = _cloneSimulation(sim);
        if (!simClone.placeUnit(move.$1, move.$2)) continue;

        int eval;
        if (firstMove) {
          eval = _minimax(simClone, depth - 1, alpha, beta, true);
          firstMove = false;
        } else {
          eval = _minimax(simClone, depth - 1, beta - 1, beta, true);
          if (eval < beta && eval > alpha) {
            eval = _minimax(simClone, depth - 1, alpha, beta, true);
          }
        }

        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) {
          _storeKillerMove(move, depth);
          break;
        }
      }

      _storeEntry(hash, minEval, depth, originalAlpha, beta);
      return minEval == 9999999 ? HeuristicEvaluator.evaluate(sim) : minEval;
    }
  }

  static void _storeKillerMove((int, int) move, int depth) {
    _killerMoves.putIfAbsent(depth, () => []);
    final killers = _killerMoves[depth]!;
    if (!killers.contains(move)) {
      killers.insert(0, move);
      if (killers.length > 2) killers.removeLast();
    }
  }

  static void _storeEntry(int hash, int score, int depth, int alpha, int beta) {
    int type = 0;
    if (score <= alpha) type = 2;
    else if (score >= beta) type = 1;
    _transpositionTable[hash] = TranspositionEntry(score, depth, type);
  }

  static void _sortMoves(List<(int, int)> moves, Board board, int depth) {
    final centerX = board.width / 2;
    final centerY = board.height / 2;
    final killers = _killerMoves[depth] ?? [];

    moves.sort((a, b) {
      // Killer moves first
      final aIsKiller = killers.contains(a);
      final bIsKiller = killers.contains(b);
      if (aIsKiller && !bIsKiller) return -1;
      if (!aIsKiller && bIsKiller) return 1;

      // Then center-first
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

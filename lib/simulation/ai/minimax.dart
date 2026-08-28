import 'dart:math';
import '../game_simulation.dart';
import '../board.dart';
import '../rules.dart';
import '../../core/enums/game_phase.dart';
import '../../core/enums/turn.dart';
import '../../core/enums/cell_state.dart';
import '../../core/utils/capture_utils.dart';
import 'evaluator.dart';
import 'zobrist_hash.dart';
import 'ai_strategy.dart';

class TranspositionEntry {
  final int score;
  final int depth;
  final int type; // 0: exact, 1: lower bound, 2: upper bound

  TranspositionEntry(this.score, this.depth, this.type);
}

class ThreatMove {
  final (int, int) coord;
  final int severity; // Higher is more urgent/valuable

  ThreatMove(this.coord, this.severity);
}

/*
 * STATIC STATE ISOLATION:
 * The _transpositionTable and _killerMoves are static for performance but are 
 * explicitly cleared at the start of every getBestMove call to ensure 
 * isolation between different moves and campaign battles.
 * 
 * IMPORTANT: RuleEngine and other callers must always enter through 
 * getBestMove and never call _minimax directly to guarantee this clean state.
 */
class MinimaxAI {
  static const int _maxTableSize = 100000;
  static final Map<int, TranspositionEntry> _transpositionTable = {};
  static final Map<int, List<(int, int)>> _killerMoves = {};

  /// Calculates the best legally available move for the AI using Minimax with Alpha-Beta pruning,
  /// PVS (Principal Variation Search), Killer Heuristic, and Threat-Space Search (TSS).
  static (int, int)? getBestMove(GameSimulation sim, AIStrategy strategy) {
    if (ZobristHash.initialize(sim.board.width, sim.board.height)) {
      sim.board.recalculateHash();
    }
    _transpositionTable.clear();
    _killerMoves.clear();

    final int maxDepth = strategy.searchDepth;
    int bestScore = -9999999;
    (int, int)? bestMove;

    final availableMoves = _generateCandidateMoves(sim, maxDepth, strategy);

    int alpha = -9999999;
    int beta = 9999999;

    for (final move in availableMoves) {
      final GameSimulation simClone = _cloneSimulation(sim);
      if (!simClone.placeUnit(move.$1, move.$2).$1) continue;

      int score = _minimax(simClone, maxDepth - 1, alpha, beta, false, strategy);

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
    AIStrategy strategy,
  ) {
    int hash = ZobristHash.computeHash(sim.board.currentHash, isMaximizingPlayer);
    final entry = _transpositionTable[hash];
    if (entry != null && entry.depth >= depth) {
      if (entry.type == 0) return entry.score;
      if (entry.type == 1) {
        alpha = max(alpha, entry.score);
      } else if (entry.type == 2) {
        beta = min(beta, entry.score);
      }

      if (alpha >= beta) return entry.score;
    }

    if (depth <= 0 || sim.currentPhase == GamePhase.gameOver || sim.currentPhase == GamePhase.draw) {
      return HeuristicEvaluator.evaluate(sim, strategy);
    }

    final availableMoves = _generateCandidateMoves(sim, depth, strategy);

    int originalAlpha = alpha;
    bool firstMove = true;

    if (isMaximizingPlayer) {
      int maxEval = -9999999;
      for (final move in availableMoves) {
        final GameSimulation simClone = _cloneSimulation(sim);
        if (!simClone.placeUnit(move.$1, move.$2).$1) continue;

        int eval;
        if (firstMove) {
          eval = _minimax(simClone, depth - 1, alpha, beta, false, strategy);
          firstMove = false;
        } else {
          eval = _minimax(simClone, depth - 1, alpha, alpha + 1, false, strategy);
          if (eval > alpha && eval < beta) {
            eval = _minimax(simClone, depth - 1, alpha, beta, false, strategy);
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
      return maxEval == -9999999 ? HeuristicEvaluator.evaluate(sim, strategy) : maxEval;
    } else {
      int minEval = 9999999;
      for (final move in availableMoves) {
        final GameSimulation simClone = _cloneSimulation(sim);
        if (!simClone.placeUnit(move.$1, move.$2).$1) continue;

        int eval;
        if (firstMove) {
          eval = _minimax(simClone, depth - 1, alpha, beta, true, strategy);
          firstMove = false;
        } else {
          eval = _minimax(simClone, depth - 1, beta - 1, beta, true, strategy);
          if (eval < beta && eval > alpha) {
            eval = _minimax(simClone, depth - 1, alpha, beta, true, strategy);
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
      return minEval == 9999999 ? HeuristicEvaluator.evaluate(sim, strategy) : minEval;
    }
  }

  /// Threat-Space Search (TSS) move generation with fallback.
  static List<(int, int)> _generateCandidateMoves(GameSimulation sim, int depth, AIStrategy strategy) {
    final rawMoves = sim.board.getRestrictedAvailableCells(radius: 2, allowZones: false);
    final List<ThreatMove> threats = [];

    final currentTurn = sim.currentTurn;
    final opponentTurn = currentTurn == Turn.player ? Turn.ai : Turn.player;
    
    final attackerState = currentTurn == Turn.player ? CellState.player : CellState.ai;
    final defenderState = currentTurn == Turn.player ? CellState.ai : CellState.player;

    for (final move in rawMoves) {
      // 0. Validity Check (Don't score illegal moves)
      final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, attackUnlocked)) {
        continue;
      }

      int severity = 0;

      // Temporarily place to check for immediate captures
      sim.board.setCell(move.$1, move.$2, attackerState);
      try {
        final captureResult = CaptureUtils.getCapturedUnits(sim.board, move, currentTurn);
        if (captureResult.capturedCells.isNotEmpty) {
          int enemyCount = 0;
          for (final c in captureResult.capturedCells) {
            if (sim.board.getCell(c.$1, c.$2) == defenderState) enemyCount++;
          }

          severity += 100 + (enemyCount * 10);
          
          // Double Threat Logic (Immediate)
          if (strategy.prioritizeDoubleThreats && enemyCount >= 2) {
            severity += 150;
          }
        }

        // Fork Logic: A move is a fork if it is adjacent to multiple separate enemy groups
        // that are now vulnerable. Local check is faster than board-wide search.
        if (strategy.focusOnForks) {
           int adjacentEnemyGroups = _countAdjacentEnemyGroups(sim.board, move.$1, move.$2, defenderState);
           if (adjacentEnemyGroups >= 2) {
             severity += 120;
           }
        }

        // Defensive Logic: Check if opponent could capture here next turn
        // Instead of heavy BFS, check if opponent has neighbors here
        if (strategy.avoidHangingPieces) {
           if (_isAdjacentToState8Way(sim.board, move.$1, move.$2, defenderState)) {
             severity -= 50; // Discourage placing adjacent to enemies unless it captures
           }
        }

      } finally {
        sim.board.setCell(move.$1, move.$2, CellState.empty); // Reset
      }

      // Defense Threat: Would the opponent capture if they moved here?
      sim.board.setCell(move.$1, move.$2, defenderState);
      try {
        final enemyCaptureResult = CaptureUtils.getCapturedUnits(sim.board, move, opponentTurn);
        if (enemyCaptureResult.capturedCells.isNotEmpty) {
          int oppEnemyCount = 0;
          final myState = currentTurn == Turn.player ? CellState.player : CellState.ai;
          for (final c in enemyCaptureResult.capturedCells) {
             if (sim.board.getCell(c.$1, c.$2) == myState) oppEnemyCount++;
          }
          severity += 80 + (oppEnemyCount * 5);
        }
      } finally {
        sim.board.setCell(move.$1, move.$2, CellState.empty); // Reset
      }

      // 3. Sigil/Win Threat (Kingdom Attack)
      if (_isSigilThreat(sim, move, currentTurn)) {
        severity += strategy.sigilWeight;
      }
      
      if (_isSigilThreat(sim, move, opponentTurn)) {
        severity += (strategy.sigilWeight * 1.3).toInt();
      }

      if (severity > 0) {
        threats.add(ThreatMove(move, severity));
      }
    }

    if (threats.isEmpty) {
      // Fallback to radius-based center-prioritized moves (Quiet positions)
      // We still filter for validity in the fallback
      final validRawMoves = rawMoves.where((m) {
        final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
        return GameRules.isValidPlacement(sim.board, m.$1, m.$2, currentTurn, attackUnlocked);
      }).toList();

      _sortMoves(validRawMoves, sim.board, depth);
      return validRawMoves;
    }

    // Sort by severity
    threats.sort((a, b) => b.severity.compareTo(a.severity));
    
    final List<(int, int)> sortedMoves = threats.map((t) => t.coord).toList();
    
    // Inject Killer moves at the top
    final killers = _killerMoves[depth] ?? [];
    for (final killer in killers.reversed) {
      if (sortedMoves.contains(killer)) {
        sortedMoves.remove(killer);
        sortedMoves.insert(0, killer);
      } else {
        // If killer is valid but not a "threat", it still gets high priority
        final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
        if (GameRules.isValidPlacement(sim.board, killer.$1, killer.$2, currentTurn, attackUnlocked)) {
          sortedMoves.insert(0, killer);
        }
      }
    }

    return sortedMoves;
  }

  static bool _isSigilThreat(GameSimulation sim, (int, int) move, Turn turn) {
    // A move is a sigil threat if it would complete a win condition OR is near the palace during an attack.
    final isPlayer = turn == Turn.player;
    final attackUnlocked = isPlayer ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    
    final board = sim.board;
    final palStartX = isPlayer ? board.aiPalaceStartX : board.playerPalaceStartX;
    final palEndX = isPlayer ? board.aiPalaceEndX : board.playerPalaceEndX;
    final palStartY = isPlayer ? board.aiPalaceStartY : board.playerPalaceStartY;
    final palEndY = isPlayer ? board.aiPalaceEndY : board.playerPalaceEndY;

    // 1. Proximity to Target Palace (Offensive)
    if (_isAdjacentToPalace(move.$1, move.$2, palStartX, palEndX, palStartY, palEndY)) {
      return true;
    }

    // 2. Immediate Win Check (Critical Offensive)
    if (attackUnlocked) {
      final state = turn == Turn.player ? CellState.player : CellState.ai;
      final original = board.getCell(move.$1, move.$2);
      board.setCell(move.$1, move.$2, state);
      final wins = GameRules.checkWinCondition(board, turn, kingdomAttackUnlocked: true);
      board.setCell(move.$1, move.$2, original);
      if (wins.isWin) return true;
    }

    // 3. Defensive Blocking (Anti-Blockade)
    // If we are evaluating the opponent's turn, check if this move would block their win-path
    if (!isPlayer && sim.playerKingdomAttackUnlocked) {
       // If player is attacking AI, and this cell is below AI Palace, it's a defensive sigil
       if (move.$2 > board.aiPalaceEndY && move.$2 < board.height / 2) {
          return true;
       }
    }

    return false;
  }

  static bool _isAdjacentToPalace(int x, int y, int palStartX, int palEndX, int palStartY, int palEndY) {
    if (x >= palStartX - 1 && x <= palEndX + 1 && y >= palStartY - 1 && y <= palEndY + 1) {
      // Ensure it's not inside the palace itself (though rawMoves should exclude that)
      if (x >= palStartX && x <= palEndX && y >= palStartY && y <= palEndY) return false;
      return true;
    }
    return false;
  }

  static void _storeKillerMove((int, int) move, int depth) {
    _killerMoves.putIfAbsent(depth, () => []);
    final killers = _killerMoves[depth]!;
    if (!killers.contains(move)) {
      killers.insert(0, move);
      if (killers.length > 2) {
        killers.removeLast();
      }
    }
  }

  static void _storeEntry(int hash, int score, int depth, int alpha, int beta) {
    int type = 0;
    if (score <= alpha) {
      type = 2;
    } else if (score >= beta) {
      type = 1;
    }
    
    if (_transpositionTable.length >= _maxTableSize) {
      _transpositionTable.remove(_transpositionTable.keys.first);
    }
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

  static int _countAdjacentEnemyGroups(Board board, int x, int y, CellState enemyState) {
    int count = 0;
    final Set<(int, int)> visited = {};
    final neighbors = [
      (x, y - 1), (x, y + 1), (x - 1, y), (x + 1, y),
    ];
    
    for (final neighbor in neighbors) {
      if (neighbor.$1 >= 0 && neighbor.$1 < board.width && neighbor.$2 >= 0 && neighbor.$2 < board.height) {
        if (board.getCell(neighbor.$1, neighbor.$2) == enemyState && !visited.contains(neighbor)) {
          count++;
          // Basic flood fill to mark this group as "seen" locally
          _markGroup(board, neighbor, enemyState, visited);
        }
      }
    }
    return count;
  }

  static void _markGroup(Board board, (int, int) start, CellState state, Set<(int, int)> visited) {
    final List<(int, int)> stack = [start];
    while (stack.isNotEmpty) {
      final curr = stack.removeLast();
      if (visited.contains(curr)) continue;
      visited.add(curr);
      
      final neighbors = [
        (curr.$1, curr.$2 - 1), (curr.$1, curr.$2 + 1), (curr.$1 - 1, curr.$2), (curr.$1 + 1, curr.$2),
      ];
      for (final n in neighbors) {
        if (n.$1 >= 0 && n.$1 < board.width && n.$2 >= 0 && n.$2 < board.height) {
          if (board.getCell(n.$1, n.$2) == state) stack.add(n);
        }
      }
    }
  }

  /// Deep clones a simulation instance so we can branch without destroying real state.
  static GameSimulation _cloneSimulation(GameSimulation original) {
    return original.clone();
  }

  static bool _isAdjacentToState8Way(Board board, int x, int y, CellState state) {
    final dirs = [
      (x, y - 1), (x, y + 1), (x - 1, y), (x + 1, y),
      (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1), (x + 1, y + 1),
    ];
    for (var dir in dirs) {
      if (dir.$1 >= 0 && dir.$1 < board.width && dir.$2 >= 0 && dir.$2 < board.height) {
        if (board.getCell(dir.$1, dir.$2) == state) {
          return true;
        }
      }
    }
    return false;
  }
}

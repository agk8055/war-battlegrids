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
    if (availableMoves.isEmpty) return null;

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

    return bestMove ?? availableMoves.first;
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
    if (availableMoves.isEmpty) {
      return HeuristicEvaluator.evaluate(sim, strategy);
    }

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

  /// Threat-Space Search (TSS) move generation with comprehensive ordering.
  static List<(int, int)> _generateCandidateMoves(GameSimulation sim, int depth, AIStrategy strategy) {
    final currentTurn = sim.currentTurn;
    final isPlayer = currentTurn == Turn.player;
    final attackUnlocked = isPlayer ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final activeCondition = isPlayer ? sim.playerActiveWinCondition : sim.aiActiveWinCondition;

    final rawMoves = sim.board.getRestrictedAvailableCells(
      radius: 2,
      allowZones: attackUnlocked,
    );

    final List<ThreatMove> threats = [];
    final opponentTurn = isPlayer ? Turn.ai : Turn.player;
    final oppAttackUnlocked = isPlayer ? sim.aiKingdomAttackUnlocked : sim.playerKingdomAttackUnlocked;
    final oppActiveCondition = isPlayer ? sim.aiActiveWinCondition : sim.playerActiveWinCondition;

    final attackerState = isPlayer ? CellState.player : CellState.ai;
    final defenderState = isPlayer ? CellState.ai : CellState.player;

    for (final move in rawMoves) {
      if (!GameRules.isValidPlacement(
        sim.board,
        move.$1,
        move.$2,
        currentTurn,
        attackUnlocked,
        activeCondition: activeCondition,
      )) {
        continue;
      }

      int severity = 0;

      // 1. Immediate Win Check (Maximum urgency)
      if (attackUnlocked) {
        sim.board.setCell(move.$1, move.$2, attackerState);
        final winCheck = GameRules.checkWinCondition(
          sim.board,
          currentTurn,
          kingdomAttackUnlocked: true,
          activeCondition: activeCondition,
        );
        sim.board.setCell(move.$1, move.$2, CellState.empty);
        if (winCheck.isWin && (winCheck.blockage?.contains(move) ?? true)) {
          severity += 20000;
        }
      }

      // 2. Opponent Immediate Win Block (Critical defense)
      if (oppAttackUnlocked) {
        sim.board.setCell(move.$1, move.$2, defenderState);
        final oppWinCheck = GameRules.checkWinCondition(
          sim.board,
          opponentTurn,
          kingdomAttackUnlocked: true,
          activeCondition: oppActiveCondition,
        );
        sim.board.setCell(move.$1, move.$2, CellState.empty);
        if (oppWinCheck.isWin && (oppWinCheck.blockage?.contains(move) ?? true)) {
          severity += 15000;
        }
      }

      // 3. Capture Evaluation
      sim.board.setCell(move.$1, move.$2, attackerState);
      try {
        final captureResult = CaptureUtils.getCapturedUnits(sim.board, move, currentTurn);
        if (captureResult.capturedCells.isNotEmpty) {
          if (captureResult.capturerTurn == currentTurn) {
            int enemyCount = 0;
            for (final c in captureResult.capturedCells) {
              if (sim.board.getCell(c.$1, c.$2) == defenderState) enemyCount++;
            }

            severity += 200 + (enemyCount * 40);

            // Double threat bonus
            if (strategy.prioritizeDoubleThreats && enemyCount >= 2) {
              severity += 150;
            }

            // Threshold unlock bonus
            final myScore = isPlayer ? sim.playerScore : sim.aiScore;
            final threshold = isPlayer
                ? sim.config.playerKingdomAttackThreshold
                : sim.config.aiKingdomAttackThreshold;
            if (!attackUnlocked && (myScore + enemyCount * 10) >= threshold) {
              severity += 600; // Unlocks Kingdom Attack!
            }
          } else {
            // Suicidal entrapment
            severity -= 1500;
          }
        }

        // Fork logic
        if (strategy.focusOnForks) {
          final adjacentEnemyGroups = _countAdjacentEnemyGroups(sim.board, move.$1, move.$2, defenderState);
          if (adjacentEnemyGroups >= 2) {
            severity += 120;
          }
        }
      } finally {
        sim.board.setCell(move.$1, move.$2, CellState.empty);
      }

      // 4. Opponent Threat Defense (Stopping enemy captures)
      sim.board.setCell(move.$1, move.$2, defenderState);
      try {
        final enemyCaptureResult = CaptureUtils.getCapturedUnits(sim.board, move, opponentTurn);
        if (enemyCaptureResult.capturedCells.isNotEmpty && enemyCaptureResult.capturerTurn == opponentTurn) {
          int oppEnemyCount = 0;
          for (final c in enemyCaptureResult.capturedCells) {
            if (sim.board.getCell(c.$1, c.$2) == attackerState) oppEnemyCount++;
          }
          severity += 100 + (oppEnemyCount * 25);
        }
      } finally {
        sim.board.setCell(move.$1, move.$2, CellState.empty);
      }

      // 5. Blockade / Sigil Proximity
      if (_isSigilThreat(sim, move, currentTurn)) {
        severity += strategy.sigilWeight;
      }
      if (_isSigilThreat(sim, move, opponentTurn)) {
        severity += (strategy.sigilWeight * 1.5).toInt();
      }

      // 6. Multi-Tier Blockade Defense (Palace corners & chain cuts)
      if (oppAttackUnlocked && strategy.anticipateBlockades) {
        final targetPalaceMinY = isPlayer ? sim.board.playerPalaceStartY : sim.board.playableMinY;
        final leftCornerX = isPlayer ? sim.board.playerPalaceStartX - 1 : sim.board.aiPalaceStartX - 1;
        final rightCornerX = isPlayer ? sim.board.playerPalaceEndX + 1 : sim.board.aiPalaceEndX + 1;

        if (move.$2 == targetPalaceMinY && (move.$1 == leftCornerX || move.$1 == rightCornerX)) {
          severity += strategy.flankDefenseWeight * 3;
        }

        // Parallel chain cuts in central columns
        final midCol = (sim.board.playableMinX + sim.board.playableMaxX) ~/ 2;
        if (move.$1 >= midCol - 1 && move.$1 <= midCol + 1 && _isAdjacentToState8Way(sim.board, move.$1, move.$2, defenderState)) {
          severity += strategy.chainCuttingWeight * 2;
        }
      }

      // 7. Chain Connectivity & Anchor bonuses
      final neighborCount = _countFriendly8WayNeighbors(sim.board, move.$1, move.$2, attackerState);
      if (neighborCount > 0) {
        severity += neighborCount * 15;
      }

      // Edge Anchor bonus
      if (move.$1 == sim.board.playableMinX || move.$1 == sim.board.playableMaxX) {
        severity += 25;
      }

      if (severity > 0) {
        threats.add(ThreatMove(move, severity));
      }
    }

    if (threats.isEmpty) {
      final validRawMoves = rawMoves.where((m) {
        return GameRules.isValidPlacement(
          sim.board,
          m.$1,
          m.$2,
          currentTurn,
          attackUnlocked,
          activeCondition: activeCondition,
        );
      }).toList();

      _sortMoves(validRawMoves, sim.board, depth);
      return validRawMoves;
    }

    // Sort moves descending by severity
    threats.sort((a, b) => b.severity.compareTo(a.severity));

    final List<(int, int)> sortedMoves = threats.map((t) => t.coord).toList();

    // Inject killer moves
    final killers = _killerMoves[depth] ?? [];
    for (final killer in killers.reversed) {
      if (sortedMoves.contains(killer)) {
        sortedMoves.remove(killer);
        sortedMoves.insert(0, killer);
      } else {
        if (GameRules.isValidPlacement(
          sim.board,
          killer.$1,
          killer.$2,
          currentTurn,
          attackUnlocked,
          activeCondition: activeCondition,
        )) {
          sortedMoves.insert(0, killer);
        }
      }
    }

    return sortedMoves;
  }

  static bool _isSigilThreat(GameSimulation sim, (int, int) move, Turn turn) {
    final isPlayer = turn == Turn.player;
    final board = sim.board;
    final palStartX = isPlayer ? board.playerPalaceStartX : board.aiPalaceStartX;
    final palEndX = isPlayer ? board.playerPalaceEndX : board.aiPalaceEndX;
    final palStartY = isPlayer ? board.playerPalaceStartY : board.aiPalaceStartY;
    final palEndY = isPlayer ? board.playerPalaceEndY : board.aiPalaceEndY;

    // Proximity to Palace perimeter
    if (_isAdjacentToPalace(move.$1, move.$2, palStartX, palEndX, palStartY, palEndY)) {
      return true;
    }

    return false;
  }

  static bool _isAdjacentToPalace(int x, int y, int palStartX, int palEndX, int palStartY, int palEndY) {
    if (x >= palStartX - 1 && x <= palEndX + 1 && y >= palStartY - 1 && y <= palEndY + 1) {
      if (x >= palStartX && x <= palEndX && y >= palStartY && y <= palEndY) return false;
      return true;
    }
    return false;
  }

  static int _countFriendly8WayNeighbors(Board board, int x, int y, CellState friendlyState) {
    int count = 0;
    final dirs = [
      (x, y - 1), (x, y + 1), (x - 1, y), (x + 1, y),
      (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1), (x + 1, y + 1),
    ];
    for (final d in dirs) {
      if (board.isWithinPlayableArea(d.$1, d.$2)) {
        final st = board.getCell(d.$1, d.$2);
        if (st == friendlyState || st == CellState.capturedGrid) count++;
      }
    }
    return count;
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
      final aIsKiller = killers.contains(a);
      final bIsKiller = killers.contains(b);
      if (aIsKiller && !bIsKiller) return -1;
      if (!aIsKiller && bIsKiller) return 1;

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
      if (board.isWithinPlayableArea(neighbor.$1, neighbor.$2)) {
        if (board.getCell(neighbor.$1, neighbor.$2) == enemyState && !visited.contains(neighbor)) {
          count++;
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
        if (board.isWithinPlayableArea(n.$1, n.$2)) {
          if (board.getCell(n.$1, n.$2) == state) stack.add(n);
        }
      }
    }
  }

  static bool _isAdjacentToState8Way(Board board, int x, int y, CellState state) {
    final dirs = [
      (x, y - 1), (x, y + 1), (x - 1, y), (x + 1, y),
      (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1), (x + 1, y + 1),
    ];
    for (final d in dirs) {
      if (board.isWithinPlayableArea(d.$1, d.$2)) {
        if (board.getCell(d.$1, d.$2) == state) return true;
      }
    }
    return false;
  }

  static GameSimulation _cloneSimulation(GameSimulation original) {
    return original.clone();
  }
}

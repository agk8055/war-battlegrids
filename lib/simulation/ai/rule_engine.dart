import '../game_simulation.dart';
import '../../core/enums/turn.dart';
import '../../core/enums/cell_state.dart';
import '../../core/utils/capture_utils.dart';
import '../rules.dart';
import 'minimax.dart';
import 'ai_strategy.dart';

class RuleEngine {
  /// NOTE: All simulated placements in this file use direct [setCell] 
  /// mutations. These are temporary simulations that intentionally 
  /// bypass Zobrist hash updates to save time. The MinimaxAI handles 
  /// hashing independently.

  /// Entry point for the hybrid AI.
  /// Runs through rule-based heuristics first. Fallback to Minimax if no rule applies.
  static (int, int)? getBestMove(GameSimulation sim, AIStrategy strategy) {
    final candidates = sim.board.getRestrictedAvailableCells(radius: 2, allowZones: false);

    if (strategy.useRuleWinInstantly) {
      final winMove = _findWinningMove(sim, candidates);
      if (winMove != null) return winMove;
    }

    if (strategy.useRuleImmediateCapture) {
      final immediateCapture = _findImmediateCapture(sim, candidates);
      if (immediateCapture != null) return immediateCapture;
    }

    if (strategy.useRuleBlocking) {
      final blockMove = _findBlockingMove(sim, candidates);
      if (blockMove != null) return blockMove;
    }

    if (strategy.useRuleDoubleThreat) {
      final doubleThreat = _findDoubleThreat(sim, candidates);
      if (doubleThreat != null) return doubleThreat;
    }

    if (strategy.useRuleSigil) {
      // 4. Kingdom Attack unlock & Sigil threatened
      final sigilMove = _findSigilMove(sim, candidates);
      if (sigilMove != null) return sigilMove;
    }

    // 5. Fallback: Minimax PVS
    return MinimaxAI.getBestMove(sim, strategy);
  }

  /// 0. Win instantly if the condition is met.
  static (int, int)? _findWinningMove(GameSimulation sim, List<(int, int)> candidates) {
    final currentTurn = sim.currentTurn;
    final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    if (!attackUnlocked) return null;

    final attackerState = currentTurn == Turn.player ? CellState.player : CellState.ai;

    for (final move in candidates) {
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, attackUnlocked)) {
        continue;
      }
      
      final original = sim.board.getCell(move.$1, move.$2);
      sim.board.setCell(move.$1, move.$2, attackerState);
      final wins = GameRules.checkWinCondition(sim.board, currentTurn, kingdomAttackUnlocked: true);
      sim.board.setCell(move.$1, move.$2, original);

      if (wins.isWin) return move;
    }
    return null;
  }

  /// 1. Finds a move that captures opponent units immediately.
  /// Returns the move that captures the maximum number of units.
  static (int, int)? _findImmediateCapture(GameSimulation sim, List<(int, int)> candidates) {
    final currentTurn = sim.currentTurn;
    final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final attackerState = currentTurn == Turn.player ? CellState.player : CellState.ai;

    (int, int)? bestMove;
    int maxCaptures = 0;

    for (final move in candidates) {
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, attackUnlocked)) {
        continue;
      }

      sim.board.setCell(move.$1, move.$2, attackerState);
      try {
        final result = CaptureUtils.getCapturedUnits(sim.board, move, currentTurn);
        if (result.capturedCells.isNotEmpty && result.capturerTurn == currentTurn) {
           int enemyCount = 0;
           final defState = currentTurn == Turn.player ? CellState.ai : CellState.player;
           for (final c in result.capturedCells) {
              if (sim.board.getCell(c.$1, c.$2) == defState) enemyCount++;
           }
           if (enemyCount > maxCaptures) {
             maxCaptures = enemyCount;
             bestMove = move;
           }
        }
      } finally {
        sim.board.setCell(move.$1, move.$2, CellState.empty);
      }
    }

    return bestMove;
  }

  /// 2. Finds a move to block an opponent's capture on their next turn.
  /// Returns a valid placement for us that stops the maximum opponent captures.
  static (int, int)? _findBlockingMove(GameSimulation sim, List<(int, int)> candidates) {
    final currentTurn = sim.currentTurn;
    final opponentTurn = currentTurn == Turn.player ? Turn.ai : Turn.player;
    final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final opponentAttackUnlocked = opponentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    
    final oppState = opponentTurn == Turn.player ? CellState.player : CellState.ai;
    final myState = currentTurn == Turn.player ? CellState.player : CellState.ai;

    (int, int)? bestBlock;
    int maxThreatened = 0;

    for (final move in candidates) {
      // Must be a spot the opponent could validly play
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, opponentTurn, opponentAttackUnlocked)) {
        continue;
      }

      // Check if opponent placing here threatens our pieces
      sim.board.setCell(move.$1, move.$2, oppState);
      int potentialCaptures = 0;
      try {
        final result = CaptureUtils.getCapturedUnits(sim.board, move, opponentTurn);
        if (result.capturerTurn == opponentTurn) {
          for (final c in result.capturedCells) {
            if (sim.board.getCell(c.$1, c.$2) == myState) {
              potentialCaptures++;
            }
          }
        }
      } finally {
        sim.board.setCell(move.$1, move.$2, CellState.empty);
      }

      // If it blocks a capture AND we can legally place our piece there
      if (potentialCaptures > maxThreatened) {
        if (GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, attackUnlocked)) {
          // Safety verification check: will this piece just be captured right back next turn?
          bool getsCaptured = false;
          sim.board.setCell(move.$1, move.$2, myState);
          try {
            // Check if placing our piece here immediately gets entrapped/captured
            final selfResult = CaptureUtils.getCapturedUnits(sim.board, move, currentTurn);
            if (selfResult.capturedCells.isNotEmpty && selfResult.capturerTurn == opponentTurn) {
              getsCaptured = true;
            }

            if (!getsCaptured) {
              final orthogonalDirs = [
                (move.$1, move.$2 - 1), (move.$1, move.$2 + 1),
                (move.$1 - 1, move.$2), (move.$1 + 1, move.$2),
              ];
              for (final oppMove in orthogonalDirs) {
                if (oppMove.$1 < 0 || oppMove.$1 >= sim.board.width || oppMove.$2 < 0 || oppMove.$2 >= sim.board.height) continue;
                if (sim.board.getCell(oppMove.$1, oppMove.$2) != CellState.empty) continue;
                if (!GameRules.isValidPlacement(sim.board, oppMove.$1, oppMove.$2, opponentTurn, opponentAttackUnlocked)) continue;
                
                sim.board.setCell(oppMove.$1, oppMove.$2, oppState);
                final oppResult = CaptureUtils.getCapturedUnits(sim.board, oppMove, opponentTurn);
                sim.board.setCell(oppMove.$1, oppMove.$2, CellState.empty);
                if (oppResult.capturerTurn == opponentTurn && oppResult.capturedCells.contains(move)) {
                  getsCaptured = true;
                  break;
                }
              }
            }
          } finally {
            sim.board.setCell(move.$1, move.$2, CellState.empty);
          }

          if (!getsCaptured) {
            maxThreatened = potentialCaptures;
            bestBlock = move;
          }
        }
      }
    }

    return bestBlock;
  }

  /// 3. Finds a move that creates a double threat (fork).
  static (int, int)? _findDoubleThreat(GameSimulation sim, List<(int, int)> candidates) {
    final currentTurn = sim.currentTurn;
    final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final attackerState = currentTurn == Turn.player ? CellState.player : CellState.ai;

    for (final move in candidates) {
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, attackUnlocked)) {
        continue;
      }

      int capturingNextMovesCount = 0;
      sim.board.setCell(move.$1, move.$2, attackerState);
      try {
        final orthogonalDirs = [
          (move.$1, move.$2 - 1), (move.$1, move.$2 + 1),
          (move.$1 - 1, move.$2), (move.$1 + 1, move.$2),
        ];
        for(final nextMove in orthogonalDirs) {
           if (nextMove.$1 < 0 || nextMove.$1 >= sim.board.width || nextMove.$2 < 0 || nextMove.$2 >= sim.board.height) continue;
           if (sim.board.getCell(nextMove.$1, nextMove.$2) != CellState.empty) continue;
           if (!GameRules.isValidPlacement(sim.board, nextMove.$1, nextMove.$2, currentTurn, attackUnlocked)) continue;
           
           sim.board.setCell(nextMove.$1, nextMove.$2, attackerState);
           final nextResult = CaptureUtils.getCapturedUnits(sim.board, nextMove, currentTurn);
           sim.board.setCell(nextMove.$1, nextMove.$2, CellState.empty);
           
           if (nextResult.capturedCells.isNotEmpty && nextResult.capturerTurn == currentTurn) {
             capturingNextMovesCount++;
           }
        }
      } finally {
        sim.board.setCell(move.$1, move.$2, CellState.empty);
      }

      // If we have >= 2 future capturing moves, the opponent can only block one.
      if (capturingNextMovesCount >= 2) {
         return move;
      }
    }

    return null;
  }

  /// 4. If Kingdom Attack is unlocked, finds a move that threatens the opponent's sigil.
  /// Actively prioritizes moves that build a contiguous U-shaped blockade.
  static (int, int)? _findSigilMove(GameSimulation sim, List<(int, int)> candidates) {
    final isPlayer = sim.currentTurn == Turn.player;
    final attackUnlocked = isPlayer ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    
    if (!attackUnlocked) return null;

    final board = sim.board;
    final palStartX = isPlayer ? board.aiPalaceStartX : board.playerPalaceStartX;
    final palEndX = isPlayer ? board.aiPalaceEndX : board.playerPalaceEndX;
    final palStartY = isPlayer ? board.aiPalaceStartY : board.playerPalaceStartY;
    final palEndY = isPlayer ? board.aiPalaceEndY : board.playerPalaceEndY;

    (int, int)? bestMove;
    int bestScore = -1;

    for (final move in candidates) {
      if (!GameRules.isValidPlacement(board, move.$1, move.$2, sim.currentTurn, attackUnlocked)) {
        continue;
      }

      if (_isAdjacentToPalace(move.$1, move.$2, palStartX, palEndX, palStartY, palEndY)) {
        int score = 0;
        final myState = isPlayer ? CellState.player : CellState.ai;
        
        // Count friendly neighbors to encourage a contiguous wall (U-Shape)
        final adjacentDirs = [
          (move.$1, move.$2 - 1), (move.$1, move.$2 + 1), 
          (move.$1 - 1, move.$2), (move.$1 + 1, move.$2),
        ];

        for (final dir in adjacentDirs) {
          if (dir.$1 >= 0 && dir.$1 < board.width && dir.$2 >= 0 && dir.$2 < board.height) {
            if (board.getCell(dir.$1, dir.$2) == myState) {
               // Higher weight for orthogonal vs diagonal if we want, but 8-way is good for contiguous feel.
               score += 5; 
            }
          }
        }
        
        if (score > bestScore) {
          bestScore = score;
          bestMove = move;
        }
      }
    }

    return bestMove;
  }



  static bool _isAdjacentToPalace(int x, int y, int palStartX, int palEndX, int palStartY, int palEndY) {
    if (x >= palStartX - 1 && x <= palEndX + 1 && y >= palStartY - 1 && y <= palEndY + 1) {
      if (x >= palStartX && x <= palEndX && y >= palStartY && y <= palEndY) return false;
      return true;
    }
    return false;
  }
}

import '../game_simulation.dart';
import '../../core/enums/turn.dart';
import '../../core/enums/cell_state.dart';
import '../../core/utils/capture_utils.dart';
import '../rules.dart';
import 'minimax.dart';
import 'ai_strategy.dart';

class RuleEngine {
  /// Entry point for the hybrid AI.
  /// Runs through rule-based heuristics first. Fallback to Minimax if no rule applies.
  static (int, int)? getBestMove(GameSimulation sim, AIStrategy strategy) {
    if (strategy.useRuleWinInstantly) {
      final winMove = _findWinningMove(sim);
      if (winMove != null) return winMove;
    }

    if (strategy.useRuleImmediateCapture) {
      final immediateCapture = _findImmediateCapture(sim);
      if (immediateCapture != null) return immediateCapture;
    }

    if (strategy.useRuleBlocking) {
      final blockMove = _findBlockingMove(sim);
      if (blockMove != null) return blockMove;
    }

    if (strategy.useRuleDoubleThreat) {
      final doubleThreat = _findDoubleThreat(sim);
      if (doubleThreat != null) return doubleThreat;
    }

    if (strategy.useRuleSigil) {
      // 4. Kingdom Attack unlock & Sigil threatened
      final sigilMove = _findSigilMove(sim);
      if (sigilMove != null) return sigilMove;
    }

    // 5. Fallback: Minimax PVS
    return MinimaxAI.getBestMove(sim, strategy);
  }

  /// 0. Win instantly if the condition is met.
  static (int, int)? _findWinningMove(GameSimulation sim) {
    final currentTurn = sim.currentTurn;
    final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    if (!attackUnlocked) return null;

    final rawMoves = sim.board.getRestrictedAvailableCells(radius: 2, allowZones: false);
    final attackerState = currentTurn == Turn.player ? CellState.player : CellState.ai;

    for (final move in rawMoves) {
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, attackUnlocked)) {
        continue;
      }
      
      final original = sim.board.getCell(move.$1, move.$2);
      sim.board.setCell(move.$1, move.$2, attackerState);
      final wins = GameRules.checkWinCondition(sim.board, currentTurn, kingdomAttackUnlocked: true);
      sim.board.setCell(move.$1, move.$2, original);

      if (wins) return move;
    }
    return null;
  }

  /// 1. Finds a move that captures opponent units immediately.
  /// Returns the move that captures the maximum number of units.
  static (int, int)? _findImmediateCapture(GameSimulation sim) {
    final currentTurn = sim.currentTurn;
    final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final rawMoves = sim.board.getRestrictedAvailableCells(radius: 2, allowZones: false);
    final attackerState = currentTurn == Turn.player ? CellState.player : CellState.ai;

    (int, int)? bestMove;
    int maxCaptures = 0;

    for (final move in rawMoves) {
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, attackUnlocked)) {
        continue;
      }

      sim.board.setCell(move.$1, move.$2, attackerState);
      try {
        final captures = CaptureUtils.getCapturedUnits(sim.board, move, currentTurn);
        if (captures.length > maxCaptures) {
          maxCaptures = captures.length;
          bestMove = move;
        }
      } finally {
        sim.board.setCell(move.$1, move.$2, CellState.empty);
      }
    }

    return bestMove;
  }

  /// 2. Finds a move to block an opponent's capture on their next turn.
  /// Returns a valid placement for us that stops the maximum opponent captures.
  static (int, int)? _findBlockingMove(GameSimulation sim) {
    final currentTurn = sim.currentTurn;
    final opponentTurn = currentTurn == Turn.player ? Turn.ai : Turn.player;
    final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final opponentAttackUnlocked = opponentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    
    final rawMoves = sim.board.getRestrictedAvailableCells(radius: 2, allowZones: false);
    final defenderState = opponentTurn == Turn.player ? CellState.player : CellState.ai;

    (int, int)? bestBlock;
    int maxThreatened = 0;

    for (final move in rawMoves) {
      // Must be a spot the opponent could validly play
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, opponentTurn, opponentAttackUnlocked)) {
        continue;
      }

      // Check if opponent placing here threatens our pieces
      sim.board.setCell(move.$1, move.$2, defenderState);
      int potentialCaptures = 0;
      try {
        potentialCaptures = CaptureUtils.getCapturedUnits(sim.board, move, opponentTurn).length;
      } finally {
        sim.board.setCell(move.$1, move.$2, CellState.empty);
      }

      // If it blocks a capture AND we can legally place our piece there
      if (potentialCaptures > maxThreatened) {
        if (GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, attackUnlocked)) {
          // Safety verification check: will this piece just be captured right back next turn?
          bool getsCaptured = false;
          final myState = currentTurn == Turn.player ? CellState.player : CellState.ai;
          sim.board.setCell(move.$1, move.$2, myState);
          try {
             final oppRawMoves = sim.board.getRestrictedAvailableCells(radius: 2, allowZones: false);
             for (final oppMove in oppRawMoves) {
                if (!GameRules.isValidPlacement(sim.board, oppMove.$1, oppMove.$2, opponentTurn, opponentAttackUnlocked)) continue;
                sim.board.setCell(oppMove.$1, oppMove.$2, defenderState);
                final oppCaptures = CaptureUtils.getCapturedUnits(sim.board, oppMove, opponentTurn);
                sim.board.setCell(oppMove.$1, oppMove.$2, CellState.empty);
                if (oppCaptures.contains(move)) {
                    getsCaptured = true;
                    break;
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
  static (int, int)? _findDoubleThreat(GameSimulation sim) {
    final currentTurn = sim.currentTurn;
    final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final attackerState = currentTurn == Turn.player ? CellState.player : CellState.ai;
    final rawMoves = sim.board.getRestrictedAvailableCells(radius: 2, allowZones: false);

    for (final move in rawMoves) {
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, attackUnlocked)) {
        continue;
      }

      int capturingNextMovesCount = 0;
      sim.board.setCell(move.$1, move.$2, attackerState);
      try {
        final nextRawMoves = sim.board.getRestrictedAvailableCells(radius: 2, allowZones: false);
        for(final nextMove in nextRawMoves) {
           if (!GameRules.isValidPlacement(sim.board, nextMove.$1, nextMove.$2, currentTurn, attackUnlocked)) continue;
           
           sim.board.setCell(nextMove.$1, nextMove.$2, attackerState);
           final nextCaptures = CaptureUtils.getCapturedUnits(sim.board, nextMove, currentTurn);
           sim.board.setCell(nextMove.$1, nextMove.$2, CellState.empty);
           
           if (nextCaptures.isNotEmpty) {
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
  static (int, int)? _findSigilMove(GameSimulation sim) {
    final isPlayer = sim.currentTurn == Turn.player;
    final attackUnlocked = isPlayer ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    
    if (!attackUnlocked) return null;

    final rawMoves = sim.board.getRestrictedAvailableCells(radius: 2, allowZones: false);
    
    final board = sim.board;
    final palStartX = isPlayer ? board.aiPalaceStartX : board.playerPalaceStartX;
    final palEndX = isPlayer ? board.aiPalaceEndX : board.playerPalaceEndX;
    final palStartY = isPlayer ? board.aiPalaceStartY : board.playerPalaceStartY;
    final palEndY = isPlayer ? board.aiPalaceEndY : board.playerPalaceEndY;

    for (final move in rawMoves) {
      if (!GameRules.isValidPlacement(board, move.$1, move.$2, sim.currentTurn, attackUnlocked)) {
        continue;
      }

      // 1. Proximity Check
      if (_isAdjacentToPalace(move.$1, move.$2, palStartX, palEndX, palStartY, palEndY)) {
        return move;
      }

      // 2. Immediate Win Check
      final state = isPlayer ? CellState.player : CellState.ai;
      final original = board.getCell(move.$1, move.$2);
      board.setCell(move.$1, move.$2, state);
      final wins = GameRules.checkWinCondition(board, sim.currentTurn, kingdomAttackUnlocked: true);
      board.setCell(move.$1, move.$2, original);
      
      if (wins) {
        return move;
      }
    }

    return null;
  }



  static bool _isAdjacentToPalace(int x, int y, int palStartX, int palEndX, int palStartY, int palEndY) {
    if (x >= palStartX - 1 && x <= palEndX + 1 && y >= palStartY - 1 && y <= palEndY + 1) {
      if (x >= palStartX && x <= palEndX && y >= palStartY && y <= palEndY) return false;
      return true;
    }
    return false;
  }
}

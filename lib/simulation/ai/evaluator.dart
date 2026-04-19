import '../../core/enums/cell_state.dart';
import '../../core/enums/turn.dart';
import '../../core/enums/game_phase.dart';
import '../../core/constants/board_constants.dart';

import '../game_simulation.dart';

class HeuristicEvaluator {
  static const int winScore = 1000000;
  static const int captureWeight = 100;
  static const int palaceDefendWeight = 10; // Reduced from 20 to prevent "inner layer" hugging
  static const int palaceAttackWeight = 50; // Increased from 30
  static const int blockadeProximityWeight = 40; // New: Encourage connecting pieces

  /// Evaluates the current game state from the perspective of the AI.
  static int evaluate(GameSimulation simulation) {
    int score = 0;

    if (simulation.currentPhase == GamePhase.gameOver) {
      // If Game Over and it's player's turn, AI just moved and WON.
      return simulation.currentTurn == Turn.player ? winScore : -winScore;
    }

    score += (simulation.aiScore - simulation.playerScore) * captureWeight;

    final board = simulation.board;
    final isAIAttackUnlocked = simulation.aiKingdomAttackUnlocked;
    final isPlayerAttackUnlocked = simulation.playerKingdomAttackUnlocked;

    for (int y = board.playableMinY; y <= board.playableMaxY; y++) {
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        final cell = board.getCell(x, y);
        if (cell == CellState.empty || cell == CellState.capturedGrid || cell == CellState.obstacle) continue;

        if (cell == CellState.ai) {
          // OFFENSE: Attacking Player Palace
          if (_isAdjacentToPalace(x, y, board.playerPalaceStartX, board.playerPalaceEndX, board.playerPalaceStartY, board.playerPalaceEndY)) {
            score += palaceAttackWeight;
          }

          // DEFENSE: Blocking Player progress towards AI Palace
          if (isPlayerAttackUnlocked) {
            // If player is attacking AI palace (at the top), AI should block cells BELOW its palace
            if (y > board.aiPalaceEndY && y < board.height / 2) {
               if (_isAdjacentToState8Way(simulation, x, y, CellState.player)) {
                 score += 80; // High priority to block player pieces
               }
            }
          }

          // CONNECTIVITY: Encourage forming a continuous wall (U-shape)
          if (isAIAttackUnlocked) {
            if (_isAdjacentToState8Way(simulation, x, y, CellState.ai) || 
                _isAdjacentToState8Way(simulation, x, y, CellState.capturedGrid)) {
              score += blockadeProximityWeight;
            }
          }

        } else if (cell == CellState.player) {
          // Penalize player proximity to AI Palace
          if (_isAdjacentToPalace(x, y, board.aiPalaceStartX, board.aiPalaceEndX, board.aiPalaceStartY, board.aiPalaceEndY)) {
            score -= (palaceAttackWeight * 1.5).toInt();
          }

          // Penalize player blockade connections
          if (isPlayerAttackUnlocked) {
            if (_isAdjacentToState8Way(simulation, x, y, CellState.player)) {
               score -= blockadeProximityWeight;
            }
          }
        }
      }
    }

    return score;
  }

  static bool _isAdjacentToPalace(int x, int y, int palStartX, int palEndX, int palStartY, int palEndY) {
    // Check if (x,y) is exactly on the outer perimeter of the given rectangle
    // Left side
    if (x == palStartX - 1 && y >= palStartY && y <= palEndY) return true;
    // Right side
    if (x == palEndX + 1 && y >= palStartY && y <= palEndY) return true;
    // Top side
    if (y == palStartY - 1 && x >= palStartX && x <= palEndX) return true;
    // Bottom side
    if (y == palEndY + 1 && x >= palStartX && x <= palEndX) return true;

    return false;
  }

  static bool _isAdjacentToState8Way(GameSimulation simulation, int x, int y, CellState state) {
    final dirs = [
      (x, y - 1), (x, y + 1), (x - 1, y), (x + 1, y),
      (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1), (x + 1, y + 1),
    ];
    for (var dir in dirs) {
      if (dir.$1 >= 0 && dir.$1 < simulation.board.width && dir.$2 >= 0 && dir.$2 < simulation.board.height) {
        if (simulation.board.getCell(dir.$1, dir.$2) == state) {
          return true;
        }
      }
    }
    return false;
  }
}

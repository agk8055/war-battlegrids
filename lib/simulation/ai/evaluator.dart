import '../../core/enums/cell_state.dart';
import '../../core/enums/turn.dart';
import '../../core/enums/game_phase.dart';
import '../../core/constants/board_constants.dart';

import '../game_simulation.dart';

class HeuristicEvaluator {
  static const int winScore = 100000;
  static const int captureWeight = 100;
  static const int palaceDefendWeight = 20;
  static const int palaceAttackWeight = 30;

  /// Evaluates the current game state from the perspective of the AI.
  /// Positive scores favor the AI, negative scores favor the Player.
  static int evaluate(GameSimulation simulation) {
    int score = 0;

    // 1. Check Win Conditions (Hard overrides)
    if (simulation.currentPhase == GamePhase.gameOver) {
      if (simulation.currentTurn == Turn.player) {
         // It was the AI's turn that ended the game (since currentTurn switches after a move)
         // Wait, currentTurn tells us whose turn it is NOW. So the PREVIOUS player moved.
         // Effectively, if Game Over, and it's player's turn, AI just moved and WON.
         return winScore;
      } else {
         return -winScore;
      }
    }

    // 2. Base Resource Advantage (Scores)
    score += simulation.aiScore * captureWeight;
    score -= simulation.playerScore * captureWeight;

    // 3. Positional Advantage
    // Scan board for strategic piece placements
    for (int y = 0; y < simulation.board.height; y++) {
      for (int x = 0; x < simulation.board.width; x++) {
        final cell = simulation.board.getCell(x, y);
        
        if (cell == CellState.ai) {
          // Defense: Is AI anchoring itself to its own palace?
          if (_isAdjacentToPalace(x, y, simulation.board.aiPalaceStartX, simulation.board.aiPalaceEndX, simulation.board.aiPalaceStartY, simulation.board.aiPalaceEndY)) {
            score += palaceDefendWeight;
          }
          // Offense: Is AI building a blockade around Player palace?
          if (_isAdjacentToPalace(x, y, simulation.board.playerPalaceStartX, simulation.board.playerPalaceEndX, simulation.board.playerPalaceStartY, simulation.board.playerPalaceEndY)) {
             score += palaceAttackWeight;
          }

          // Anti-Blockage Defense: Actively block player pieces during kingdom attack
          if (simulation.playerKingdomAttackUnlocked) {
             if (y <= simulation.board.height ~/ 2 && _isAdjacentToState8Way(simulation, x, y, CellState.player)) {
                 score += 60;
             }
          }
        } 
        else if (cell == CellState.player) {
          // Inverse for player
          if (_isAdjacentToPalace(x, y, simulation.board.playerPalaceStartX, simulation.board.playerPalaceEndX, simulation.board.playerPalaceStartY, simulation.board.playerPalaceEndY)) {
            score -= palaceDefendWeight;
          }
          if (_isAdjacentToPalace(x, y, simulation.board.aiPalaceStartX, simulation.board.aiPalaceEndX, simulation.board.aiPalaceStartY, simulation.board.aiPalaceEndY)) {
             score -= palaceAttackWeight;
          }

          // Penalize AI if player is encroaching and building walls during kingdom attack
          if (simulation.playerKingdomAttackUnlocked) {
             if (y <= simulation.board.height ~/ 2) {
                 score -= 10;
                 if (_isAdjacentToState8Way(simulation, x, y, CellState.player)) {
                     score -= 15;
                 }
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

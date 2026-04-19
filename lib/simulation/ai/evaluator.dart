import '../../core/enums/cell_state.dart';
import '../../core/enums/turn.dart';
import '../../core/enums/game_phase.dart';
import '../../core/constants/board_constants.dart';

import '../game_simulation.dart';
import '../board.dart';
import 'ai_strategy.dart';

import '../../core/utils/capture_utils.dart';
import '../../core/utils/board_utils.dart';

class HeuristicEvaluator {
  static const int winScore = 1000000;

  /// Evaluates the current game state from the perspective of the AI.
  static int evaluate(GameSimulation simulation, AIStrategy strategy) {
    int score = 0;

    if (simulation.currentPhase == GamePhase.gameOver) {
      // If Game Over and it's player's turn, AI just moved and WON.
      return simulation.currentTurn == Turn.player ? winScore : -winScore;
    }

    score += (simulation.aiScore - simulation.playerScore) * strategy.captureWeight;

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
            score += strategy.palaceAttackWeight;
          }

          // DEFENSE: Blocking Player progress towards AI Palace
          if (isPlayerAttackUnlocked) {
            if (y > board.aiPalaceEndY && y < board.height / 2) {
               if (_isAdjacentToState8Way(simulation, x, y, CellState.player)) {
                 score += strategy.palaceDefendWeight * 8;
               }
            }
          }

          // CONNECTIVITY & BLOCKADE (Align with GameRules anchors)
          if (isAIAttackUnlocked) {
            if (_isAdjacentToState8Way(simulation, x, y, CellState.ai) || 
                _isAdjacentToState8Way(simulation, x, y, CellState.capturedGrid)) {
              score += strategy.connectivityWeight;
            }
            
            // BRIDGING: Reward being near other AI pieces even if not touching (close gaps)
            if (strategy.connectivityWeight > 0) {
              if (_hasBridgePotential(board, x, y, CellState.ai)) {
                score += (strategy.connectivityWeight * 0.5).toInt();
              }
            }

            // AI Anchor Proximity (Winning path)
            if (x == board.playableMinX || (y == board.playableMaxY && x < board.playerPalaceStartX)) {
              score += strategy.connectivityWeight * 2;
            }
            if (x == board.playableMaxX || (y == board.playableMaxY && x > board.playerPalaceEndX)) {
              score += strategy.connectivityWeight * 2;
            }

            // EDGE/CORNER BONUS: Reward placing near boundaries as they act as natural walls for captures
            if (x == board.playableMinX || x == board.playableMaxX || 
                y == board.playableMinY || y == board.playableMaxY) {
              score += 20; // Small bonus for boundary usage
            }
          }

          // ZONE DOMINANCE
          if (strategy.zoneControlWeight > 0) {
            if (y > board.height / 2) {
              score += strategy.zoneControlWeight;
            }
          }

        } else if (cell == CellState.player) {
          // Penalize player proximity to AI Palace
          if (_isAdjacentToPalace(x, y, board.aiPalaceStartX, board.aiPalaceEndX, board.aiPalaceStartY, board.aiPalaceEndY)) {
            score -= (strategy.palaceAttackWeight * 1.5).toInt();
          }

          // Penalize player blockade anchors
          if (isPlayerAttackUnlocked) {
            if (x == board.playableMinX || (y == board.playableMinY && x < board.aiPalaceStartX)) {
              score -= strategy.connectivityWeight;
            }
            if (x == board.playableMaxX || (y == board.playableMinY && x > board.aiPalaceEndX)) {
              score -= strategy.connectivityWeight;
            }
          }
        } else if (cell == CellState.empty) {
          // TERRITORY: Reward AI for controlling empty space that is hard for the player to reach
          // or near the player palace.
          if (strategy.zoneControlWeight > 0) {
            bool nearAI = _isAdjacentToState8Way(simulation, x, y, CellState.ai);
            bool nearPlayer = _isAdjacentToState8Way(simulation, x, y, CellState.player);
            if (nearAI && !nearPlayer) {
              score += 5; // Small bonus for controlled empty space
            }
          }
        }
      }
    }

    return score;
  }

  static bool _hasBridgePotential(Board board, int x, int y, CellState state) {
    // Check radius 2 for other pieces of the same state to bridge gaps
    for (int dy = -2; dy <= 2; dy++) {
      for (int dx = -2; dx <= 2; dx++) {
        if (dx == 0 && dy == 0) continue;
        final nx = x + dx;
        final ny = y + dy;
        if (nx >= 0 && nx < board.width && ny >= 0 && ny < board.height) {
          if (board.getCell(nx, ny) == state) return true;
        }
      }
    }
    return false;
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

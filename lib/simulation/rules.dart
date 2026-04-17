import '../core/enums/cell_state.dart';
import '../core/enums/turn.dart';
import '../core/constants/game_constants.dart';
import '../core/constants/board_constants.dart';
import 'board.dart';

class GameRules {
  /// Checks if an attempted placement is structurally valid on the board.
  static bool isValidPlacement(
    Board board,
    int x,
    int y,
    Turn turn,
    bool kingdomAttackUnlocked,
  ) {
    // Must be within the designated playable area
    if (!board.isWithinPlayableArea(x, y)) {
      return false;
    }

    final cell = board.getCell(x, y);

    // Can only place on an empty cell or a zone cell. Cannot place on an existing unit, captured grid, or obstacle.
    if (cell == CellState.player ||
        cell == CellState.ai ||
        cell == CellState.playerSigil ||
        cell == CellState.aiSigil ||
        cell == CellState.capturedGrid ||
        cell == CellState.obstacle) {
      return false;
    }

    // Cannot deploy in your OWN zone. It acts intrinsically as your units.
    if (turn == Turn.player && cell == CellState.playerZone) {
      return false;
    }
    if (turn == Turn.ai && cell == CellState.aiZone) {
      return false;
    }

    // If Kingdom attack is NOT unlocked, we cannot place inside the opponent's Kingdom Zone.
    if (!kingdomAttackUnlocked) {
      if (turn == Turn.player && cell == CellState.aiZone) {
        return false;
      }
      if (turn == Turn.ai && cell == CellState.playerZone) {
        return false;
      }

      // We also cannot place a piece that would COMPLETE a blockage around the opponent's kingdom!
      final originalState = board.getCell(x, y);
      board.setCell(
        x,
        y,
        turn == Turn.player ? CellState.player : CellState.ai,
      );
      final wouldCompleteBlockage = checkWinCondition(
        board,
        turn,
        kingdomAttackUnlocked: true,
      );
      board.setCell(x, y, originalState);

      if (wouldCompleteBlockage) {
        return false;
      }
    }

    return true;
  }

  /// Calculates the score earned for capturing a list of units.
  static int calculateCaptureScore(int numberOfUnitsCaptured) {
    return numberOfUnitsCaptured * kCapturePointsValue;
  }

  /// Checks if the win condition has been met.
  /// Checks if the win condition has been met by entirely surrounding the opponent's palace.
  static bool checkWinCondition(
    Board board,
    Turn currentTurn, {
    required bool kingdomAttackUnlocked,
  }) {
    if (!kingdomAttackUnlocked) return false;

    // Use Topological Blockade Logic
    // Winning condition: The attacking player forms a continuous horizontal wall
    // separating the target Palace's top/bottom from its escape route.

    final attackerState = currentTurn == Turn.player
        ? CellState.player
        : CellState.ai;
    final isTargetingAI = currentTurn == Turn.player;

    final leftX = isTargetingAI ? board.aiPalaceStartX : board.playerPalaceStartX;
    final rightX = isTargetingAI ? board.aiPalaceEndX : board.playerPalaceEndX;

    bool isLeftAnchor((int, int) coord) {
      if (coord.$1 == board.playableMinX) return true; // Touches playable left edge
      if (isTargetingAI) {
        return coord.$2 == board.playableMinY &&
            coord.$1 < leftX; // Touches Top Edge to the left
      } else {
        return coord.$2 == board.playableMaxY &&
            coord.$1 < leftX; // Touches Bottom Edge to the left
      }
    }

    bool isRightAnchor((int, int) coord) {
      if (coord.$1 == board.playableMaxX)
        return true; // Touches playable right edge
      if (isTargetingAI) {
        return coord.$2 == board.playableMinY &&
            coord.$1 > rightX; // Touches Top Edge to the right
      } else {
        return coord.$2 == board.playableMaxY &&
            coord.$1 > rightX; // Touches Bottom Edge to the right
      }
    }

    final visited = <(int, int)>{};

    for (int y = 0; y < board.height; y++) {
      for (int x = 0; x < board.width; x++) {
        // Any piece owned by the attacker, or any grid they have captured (scorched earth acts as a wall for them too!)
        final state = board.getCell(x, y);
        if ((state == attackerState || state == CellState.capturedGrid) &&
            !visited.contains((x, y))) {
          final queue = <(int, int)>[(x, y)];
          visited.add((x, y));

          bool touchesLeft = false;
          bool touchesRight = false;

          while (queue.isNotEmpty) {
            final curr = queue.removeAt(0);

            if (isLeftAnchor(curr)) touchesLeft = true;
            if (isRightAnchor(curr)) touchesRight = true;

            if (touchesLeft && touchesRight) {
              return true;
            }

            // Check 8-way neighbors (Orthogonal + Diagonal) to allow diagonal blockades!
            final dirs = [
              (curr.$1, curr.$2 - 1),
              (curr.$1, curr.$2 + 1),
              (curr.$1 - 1, curr.$2),
              (curr.$1 + 1, curr.$2),
              (curr.$1 - 1, curr.$2 - 1),
              (curr.$1 + 1, curr.$2 - 1),
              (curr.$1 - 1, curr.$2 + 1),
              (curr.$1 + 1, curr.$2 + 1),
            ];

            for (final dir in dirs) {
              if (dir.$1 >= board.playableMinX &&
                  dir.$1 <= board.playableMaxX &&
                  dir.$2 >= board.playableMinY &&
                  dir.$2 <= board.playableMaxY) {
                final neighborState = board.getCell(dir.$1, dir.$2);
                if ((neighborState == attackerState ||
                        neighborState == CellState.capturedGrid) &&
                    !visited.contains(dir)) {
                  visited.add(dir);
                  queue.add(dir);
                }
              }
            }
          }
        }
      }
    }

    return false;
  }
}

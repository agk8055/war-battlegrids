import '../enums/cell_state.dart';
import '../enums/turn.dart';
import '../../simulation/board.dart';
import 'board_utils.dart';

class CaptureUtils {
  /// Evaluates if placing a piece at [placedCoord] by [turn] results in any enemy
  /// unit captures. Returns a list of coordinates of captured units.
  /// 
  /// A group of units is captured if its entire perimeter is enclosed by enemy pieces.
  static List<(int, int)> getCapturedUnits(Board board, (int, int) placedCoord, Turn turn) {
    final CellState enemyState = turn == Turn.player ? CellState.ai : CellState.player;
    final List<(int, int)> captured = [];

    // Check adjacent cells for enemy units
    final neighbors = BoardUtils.getAdjacentCoordinates(
      placedCoord.$1, 
      placedCoord.$2, 
      board.width, 
      board.height
    );

    for (final neighbor in neighbors) {
      if (board.getCell(neighbor.$1, neighbor.$2) == enemyState) {
        // If this enemy is not already marked as captured, check its group
        if (!captured.contains(neighbor)) {
          final groupResult = _checkGroupCapture(board, neighbor, enemyState);
          if (groupResult != null) {
            captured.addAll(groupResult);
          }
        }
      }
    }

    return captured;
  }

  /// Finds the contiguous group of units of the same [state] starting at [startCoord].
  /// Returns the group's coordinates IF it is fully captured, otherwise returns null.
  /// It is captured ONLY if its perimeter consists entirely of enemy pieces (4-sides rule, walls do not count as enemies).
  static List<(int, int)>? _checkGroupCapture(Board board, (int, int) startCoord, CellState state) {
    final Set<(int, int)> group = {};
    final List<(int, int)> toCheck = [startCoord];
    bool hasLiberty = false;

    while (toCheck.isNotEmpty) {
      final current = toCheck.removeLast();
      if (group.contains(current)) continue;
      
      group.add(current);

      // We need to check all 4 theoretical sides (up, down, left, right).
      final allDirCoords = [
        (current.$1, current.$2 - 1),
        (current.$1, current.$2 + 1),
        (current.$1 - 1, current.$2),
        (current.$1 + 1, current.$2),
      ];

      for (final neighbor in allDirCoords) {
        if (_isOutOfBounds(neighbor, board.width, board.height)) {
          // The edge of the board acts as a solid capturing wall!
          // It does NOT grant a liberty.
          continue;
        }

        final cell = board.getCell(neighbor.$1, neighbor.$2);
        
        // Define what constitutes an enemy zone for the current state
        final enemyZone = state == CellState.player ? CellState.aiZone : CellState.playerZone;
        final friendlyZone = state == CellState.player ? CellState.playerZone : CellState.aiZone;

        if (cell == state) {
          if (!group.contains(neighbor) && !toCheck.contains(neighbor)) {
            toCheck.add(neighbor); // Part of the contiguous group
          }
        } else if (cell == friendlyZone) {
          // Touching your OWN palace means you are connected to your massive anchored kingdom!
          // We can treat this as an ultimate liberty (immune to capture while touching own base).
          hasLiberty = true;
        } else if (cell == enemyZone) {
          // Touching the ENEMY palace acts as if an enemy unit is blocking this side!
          // So it does NOT grant a liberty, it acts as a capturing wall.
        } else if (cell == CellState.empty) {
          // Found an empty space, so it has a standard liberty
          hasLiberty = true;
        }
        // If it's pure enemy (CellState.player vs ai), it acts as a capturing wall, granting no liberty.
      }
    }

    if (hasLiberty) {
      return null;
    }

    return group.toList();
  }

  static bool _isOutOfBounds((int, int) coord, int width, int height) {
    return coord.$1 < 0 || coord.$1 >= width || coord.$2 < 0 || coord.$2 >= height;
  }
}

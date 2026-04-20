import '../enums/cell_state.dart';
import '../enums/turn.dart';
import '../../simulation/board.dart';
import 'board_utils.dart';

class CaptureUtils {
  /// Evaluates if placing a piece at [placedCoord] by [turn] results in any enemy
  /// unit or territory captures. Returns a list of coordinates of captured cells.
  /// 
  /// A region (enemy units + empty cells) is captured if it is fully enclosed by 
  /// the attacker's pieces or the playable battlefield boundaries.
  static List<(int, int)> getCapturedUnits(Board board, (int, int) placedCoord, Turn turn) {
    final CellState attackerState = turn == Turn.player ? CellState.player : CellState.ai;
    final CellState attackerZone = turn == Turn.player ? CellState.playerZone : CellState.aiZone;
    final List<(int, int)> captured = [];

    // Check adjacent cells
    final allNeighbors = [
      (placedCoord.$1, placedCoord.$2 - 1),
      (placedCoord.$1, placedCoord.$2 + 1),
      (placedCoord.$1 - 1, placedCoord.$2),
      (placedCoord.$1 + 1, placedCoord.$2),
    ];

    for (final neighbor in allNeighbors) {
      if (!board.isWithinPlayableArea(neighbor.$1, neighbor.$2)) continue;

      final cell = board.getCell(neighbor.$1, neighbor.$2);
      
      // If the neighbor is NOT the attacker's color and NOT the attacker's zone, 
      // and NOT already captured, check if it's enclosed.
      if (cell != attackerState && cell != attackerZone && cell != CellState.obstacle) {
        if (!captured.any((c) => c.$1 == neighbor.$1 && c.$2 == neighbor.$2)) {
          final groupResult = _checkGroupCapture(board, neighbor, attackerState, attackerZone);
          if (groupResult != null) {
            captured.addAll(groupResult);
          }
        }
      }
    }

    return captured;
  }

  /// Finds the contiguous group of non-attacker units starting at [startCoord].
  /// Returns the group's coordinates IF it is fully captured, otherwise returns null.
  /// It is captured IF it cannot reach the owner's kingdom zone.
  static List<(int, int)>? _checkGroupCapture(Board board, (int, int) startCoord, CellState attackerState, CellState attackerZone) {
    final Set<(int, int)> group = {};
    final List<(int, int)> toCheck = [startCoord];
    bool hasLiberty = false;

    // The owner of the starting cell is the one who needs to reach their own zone
    // If starting cell is empty, the "owner" zone that grants liberty is the enemy's zone
    // Wait, if it's empty space, it should be captured if it can't reach EITHER palace?
    // No, if it's empty, it can be captured by anyone.
    // If it reaches AI Palace, Player can't capture it. If it reaches Player Palace, AI can't capture it.
    
    final aiZone = CellState.aiZone;
    final playerZone = CellState.playerZone;

    while (toCheck.isNotEmpty) {
      final current = toCheck.removeLast();
      if (group.contains(current)) continue;
      
      group.add(current);

      final allDirCoords = [
        (current.$1, current.$2 - 1),
        (current.$1, current.$2 + 1),
        (current.$1 - 1, current.$2),
        (current.$1 + 1, current.$2),
      ];

      for (final neighbor in allDirCoords) {
        if (!board.isWithinPlayableArea(neighbor.$1, neighbor.$2)) {
          // Boundary acts as a liberty
          hasLiberty = true;
          continue;
        }

        final cell = board.getCell(neighbor.$1, neighbor.$2);
        
        if (cell == attackerState || cell == attackerZone) {
          // Hit the attacker's wall
          continue;
        }

        if (cell == aiZone || cell == playerZone) {
          // Touching ANY kingdom zone provides liberty for the territory?
          // No, only the "friendly" zone.
          // If the attacker is Player, then touching AI Palace grants liberty (AI protects it).
          // If the attacker is AI, then touching Player Palace grants liberty (Player protects it).
          final enemyZone = attackerState == CellState.player ? CellState.aiZone : CellState.playerZone;
          if (cell == enemyZone) {
            hasLiberty = true;
          }
          continue;
        }

        if (cell == CellState.obstacle) {
          // Obstacles are walls
          continue;
        }

        // Otherwise, it's an empty cell, enemy unit, or capturedGrid
        if (!group.contains(neighbor) && !toCheck.contains(neighbor)) {
          toCheck.add(neighbor);
        }
      }
    }

    if (hasLiberty) {
      return null;
    }

    // A captured group MUST contain at least one enemy unit. 
    // Capturing purely empty space without enemy units is not allowed.
    final defenderState = attackerState == CellState.player ? CellState.ai : CellState.player;
    bool containsEnemy = false;
    for (final coord in group) {
      if (board.getCell(coord.$1, coord.$2) == defenderState) {
        containsEnemy = true;
        break;
      }
    }

    if (!containsEnemy) {
      return null;
    }

    return group.toList();
  }

  static bool _isOutOfBounds((int, int) coord, int width, int height) {
    return coord.$1 < 0 || coord.$1 >= width || coord.$2 < 0 || coord.$2 >= height;
  }
}

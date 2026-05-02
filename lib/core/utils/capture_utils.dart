import '../enums/cell_state.dart';
import '../enums/turn.dart';
import '../../simulation/board.dart';
import 'board_utils.dart';

class CaptureResult {
  final List<(int, int)> capturedCells;
  final Set<((int, int), (int, int))> linkages;
  CaptureResult(this.capturedCells, this.linkages);
}

class CaptureUtils {
  /// Evaluates if placing a piece at [placedCoord] by [turn] results in any enemy
  /// unit or territory captures. Returns a CaptureResult containing 
  /// captured cells and blockage linkages.
  static CaptureResult getCapturedUnits(Board board, (int, int) placedCoord, Turn turn) {
    final CellState attackerState = turn == Turn.player ? CellState.player : CellState.ai;
    final CellState attackerZone = turn == Turn.player ? CellState.playerZone : CellState.aiZone;
    final List<(int, int)> captured = [];
    final Set<((int, int), (int, int))> linkages = {};

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
          final group = _checkGroupCapture(board, neighbor, attackerState, attackerZone);
          if (group != null) {
            captured.addAll(group);
            // Identify blockage for this group
            _addBlockageLinkages(board, group, attackerState, attackerZone, linkages);
          }
        }
      }
    }

    return CaptureResult(captured, linkages);
  }

  /// Finds the contiguous group of non-attacker units starting at [startCoord].
  /// Returns the group's coordinates IF it is fully captured, otherwise returns null.
  /// It is captured IF it cannot reach the owner's kingdom zone.
  static List<(int, int)>? _checkGroupCapture(Board board, (int, int) startCoord, CellState attackerState, CellState attackerZone) {
    final Set<(int, int)> group = {};
    final List<(int, int)> toCheck = [startCoord];
    bool hasLiberty = false;

    // The owner of the starting cell is the one who needs to reach their own zone
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

  /// Generates linkages between 8-way adjacent cells in the provided set.
  static Set<((int, int), (int, int))> getLinkagesFromBlockage(List<(int, int)> blockageCells) {
    final Set<((int, int), (int, int))> linkages = {};
    for (int i = 0; i < blockageCells.length; i++) {
      for (int j = i + 1; j < blockageCells.length; j++) {
        final b1 = blockageCells[i];
        final b2 = blockageCells[j];
        
        final dx = (b1.$1 - b2.$1).abs();
        final dy = (b1.$2 - b2.$2).abs();
        
        if (dx <= 1 && dy <= 1) {
          if (b1.$1 < b2.$1 || (b1.$1 == b2.$1 && b1.$2 < b2.$2)) {
            linkages.add((b1, b2));
          } else {
            linkages.add((b2, b1));
          }
        }
      }
    }
    return linkages;
  }

  /// Adds linkages between adjacent attacker pieces that form the blockage for the given group.
  static void _addBlockageLinkages(
    Board board, 
    List<(int, int)> group, 
    CellState attackerState, 
    CellState attackerZone,
    Set<((int, int), (int, int))> linkages,
  ) {
    final Set<(int, int)> blockage = {};
    for (final coord in group) {
      final neighbors = [
        (coord.$1, coord.$2 - 1),
        (coord.$1, coord.$2 + 1),
        (coord.$1 - 1, coord.$2),
        (coord.$1 + 1, coord.$2),
      ];
      for (final n in neighbors) {
        if (!board.isWithinPlayableArea(n.$1, n.$2)) continue;
        final state = board.getCell(n.$1, n.$2);
        if (state == attackerState || state == attackerZone) {
          blockage.add(n);
        }
      }
    }

    linkages.addAll(getLinkagesFromBlockage(blockage.toList()));
  }

  static bool _isOutOfBounds((int, int) coord, int width, int height) {
    return coord.$1 < 0 || coord.$1 >= width || coord.$2 < 0 || coord.$2 >= height;
  }
}

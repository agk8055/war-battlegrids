import '../core/enums/cell_state.dart';
import '../core/enums/turn.dart';
import '../core/enums/win_condition_type.dart';
import '../core/constants/game_constants.dart';
import '../core/constants/board_constants.dart';
import 'board.dart';

class WinResult {
  final bool isWin;
  final List<(int, int)>? blockage;
  WinResult(this.isWin, [this.blockage]);
}

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

      if (wouldCompleteBlockage.isWin) {
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
  static WinResult checkWinCondition(
    Board board,
    Turn currentTurn, {
    required bool kingdomAttackUnlocked,
  }) {
    if (!kingdomAttackUnlocked) return WinResult(false);

    // Check for actual U-shaped win
    final uWon = _findBlockade(board, currentTurn, {AnchorType.topLeft, AnchorType.topRight}, includeKingdom: false, includeEmpty: false);
    if (uWon.isWin) return uWon;

    // If not won by U-shape, is a U-shape STILL POSSIBLE?
    final uPossible = _findBlockade(board, currentTurn, {AnchorType.topLeft, AnchorType.topRight}, includeKingdom: false, includeEmpty: true);
    if (uPossible.isWin) return WinResult(false); // If a U-shape is possible, you MUST win that way.

    // U-shape is impossible. Check for actual Parallel win.
    final pWon = _findBlockade(board, currentTurn, {AnchorType.leftEdge, AnchorType.rightEdge}, includeKingdom: false, includeEmpty: false);
    if (pWon.isWin) return pWon;

    // If not won by Parallel, is a Parallel STILL POSSIBLE?
    final pPossible = _findBlockade(board, currentTurn, {AnchorType.leftEdge, AnchorType.rightEdge}, includeKingdom: false, includeEmpty: true);
    if (pPossible.isWin) return WinResult(false); // If a Parallel is possible, you MUST win that way.

    // Both U-shape and Parallel are impossible. Check for Kingdom-assisted win.
    return _findBlockade(board, currentTurn, {AnchorType.leftEdge, AnchorType.rightEdge, AnchorType.topLeft, AnchorType.topRight}, includeKingdom: true, includeEmpty: false, requireKingdom: true);
  }

  static WinResult _findBlockade(
    Board board, 
    Turn currentTurn, 
    Set<AnchorType> requiredAnchors, 
    {required bool includeKingdom, required bool includeEmpty, bool requireKingdom = false}
  ) {
    final attackerState = currentTurn == Turn.player ? CellState.player : CellState.ai;
    final attackerZone = currentTurn == Turn.player ? CellState.playerZone : CellState.aiZone;
    final isAttackingAI = currentTurn == Turn.player;

    final leftPalaceX = isAttackingAI ? board.aiPalaceStartX : board.playerPalaceStartX;
    final rightPalaceX = isAttackingAI ? board.aiPalaceEndX : board.playerPalaceEndX;
    final palaceY = isAttackingAI ? board.playableMinY : board.playableMaxY;

    AnchorType? getAnchorType(int x, int y) {
      if (x == board.playableMinX) return AnchorType.leftEdge;
      if (x == board.playableMaxX) return AnchorType.rightEdge;
      if (y == palaceY) {
        if (x < leftPalaceX) return AnchorType.topLeft;
        if (x > rightPalaceX) return AnchorType.topRight;
      }
      return null;
    }

    final visited = <(int, int)>{};

    for (int y = board.playableMinY; y <= board.playableMaxY; y++) {
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        final state = board.getCell(x, y);
        bool isWallPart = (state == attackerState || state == CellState.capturedGrid);
        if (includeKingdom && state == attackerZone) isWallPart = true;
        if (includeEmpty && state == CellState.empty) isWallPart = true;

        if (isWallPart && !visited.contains((x, y))) {
          final groupVisited = <(int, int)>{};
          final queue = <(int, int)>[(x, y)];
          visited.add((x, y));
          groupVisited.add((x, y));

          final foundAnchors = <AnchorType>{};
          bool usesKingdom = false;

          while (queue.isNotEmpty) {
            final curr = queue.removeAt(0);

            final anchor = getAnchorType(curr.$1, curr.$2);
            if (anchor != null) foundAnchors.add(anchor);
            
            if (board.getCell(curr.$1, curr.$2) == attackerZone) {
              usesKingdom = true;
            }

            // Check 8-way neighbors
            final dirs = [
              (curr.$1, curr.$2 - 1), (curr.$1, curr.$2 + 1), (curr.$1 - 1, curr.$2), (curr.$1 + 1, curr.$2),
              (curr.$1 - 1, curr.$2 - 1), (curr.$1 + 1, curr.$2 - 1), (curr.$1 - 1, curr.$2 + 1), (curr.$1 + 1, curr.$2 + 1),
            ];

            for (final dir in dirs) {
              if (board.isWithinPlayableArea(dir.$1, dir.$2)) {
                final neighborState = board.getCell(dir.$1, dir.$2);
                bool isNeighborWall = (neighborState == attackerState || neighborState == CellState.capturedGrid);
                if (includeKingdom && neighborState == attackerZone) isNeighborWall = true;
                if (includeEmpty && neighborState == CellState.empty) isNeighborWall = true;

                if (isNeighborWall && !visited.contains(dir)) {
                  visited.add(dir);
                  groupVisited.add(dir);
                  queue.add(dir);
                }
              }
            }
          }

          if (requireKingdom && !usesKingdom) continue;

          // Check if the connected group satisfies the required anchor combination
          if (requiredAnchors.every((a) => foundAnchors.contains(a))) {
            return WinResult(true, groupVisited.toList());
          }
          
          // Special case for Kingdom-assisted: any TWO distinct anchors from the set
          if (requireKingdom && foundAnchors.length >= 2) {
            return WinResult(true, groupVisited.toList());
          }
        }
      }
    }

    return WinResult(false);
  }

  /// Checks if the board is full and no moves are possible.
  static bool checkDraw(Board board, bool playerAttackUnlocked, bool aiAttackUnlocked) {
    for (int y = board.playableMinY; y <= board.playableMaxY; y++) {
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        if (isValidPlacement(board, x, y, Turn.player, playerAttackUnlocked)) return false;
        if (isValidPlacement(board, x, y, Turn.ai, aiAttackUnlocked)) return false;
      }
    }
    return true;
  }

  /// Checks if a specific win condition is still structurally possible for a player.
  static bool isWinConditionPossible(Board board, Turn turn, WinConditionType type) {
    switch (type) {
      case WinConditionType.uShape:
        return _findBlockade(board, turn, {AnchorType.topLeft, AnchorType.topRight}, includeKingdom: false, includeEmpty: true).isWin;
      case WinConditionType.parallel:
        return _findBlockade(board, turn, {AnchorType.leftEdge, AnchorType.rightEdge}, includeKingdom: false, includeEmpty: true).isWin;
      case WinConditionType.kingdomAssisted:
        return _findBlockade(board, turn, {AnchorType.leftEdge, AnchorType.rightEdge, AnchorType.topLeft, AnchorType.topRight}, includeKingdom: true, includeEmpty: true, requireKingdom: true).isWin;
    }
  }
}

enum AnchorType { leftEdge, rightEdge, topLeft, topRight }

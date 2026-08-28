import '../core/enums/cell_state.dart';
import '../core/enums/turn.dart';
import '../core/enums/win_condition_type.dart';
import '../core/constants/game_constants.dart';
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

  /// Checks if a cell is deployable ONLY IF kingdom attack / siege is unlocked,
  /// but currently blocked because siege points are not met (e.g. completing a winning blockade).
  /// Kingdom zone tiles are excluded so kingdom colors and palace overlays remain untouched.
  static bool isPlacementBlockedBySiege(
    Board board,
    int x,
    int y,
    Turn turn,
    bool kingdomAttackUnlocked,
  ) {
    if (kingdomAttackUnlocked) return false;
    if (!board.isWithinPlayableArea(x, y)) return false;

    final cell = board.getCell(x, y);
    // Only regular empty tiles are subject to the siege-blocked overlay
    if (cell != CellState.empty) return false;

    // Check if placing a piece here would complete a winning blockade
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
    board.setCell(x, y, cell);

    return wouldCompleteBlockage.isWin;
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

    // 1. Check for actual U-shaped win
    final uWon = _findBlockade(
      board,
      currentTurn,
      {AnchorType.topLeft, AnchorType.topRight},
      includeKingdom: false,
      includeEmpty: false,
    );
    if (uWon.isWin) return uWon;

    // 2. Check for actual Parallel win
    final pWon = _findBlockade(
      board,
      currentTurn,
      {AnchorType.leftEdge, AnchorType.rightEdge},
      includeKingdom: false,
      includeEmpty: false,
    );
    if (pWon.isWin) return pWon;

    // 3. Check for actual Kingdom-assisted win
    return _findBlockade(
      board,
      currentTurn,
      {AnchorType.leftEdge, AnchorType.rightEdge, AnchorType.topLeft, AnchorType.topRight},
      includeKingdom: true,
      includeEmpty: false,
      requireKingdom: true,
    );
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
          final groupVisited = <(int, int)>[];
          final queue = <(int, int)>[(x, y)];
          visited.add((x, y));
          groupVisited.add((x, y));

          final foundAnchors = <AnchorType>{};
          bool usesKingdom = false;
          int head = 0;

          while (head < queue.length) {
            final curr = queue[head++];

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
            return WinResult(true, groupVisited);
          }
          
          // Special case for Kingdom-assisted: any TWO distinct anchors from the set
          if (requireKingdom && foundAnchors.length >= 2) {
            return WinResult(true, groupVisited);
          }
        }
      }
    }

    return WinResult(false);
  }

  /// Checks if a player has any valid placement moves available on the board.
  static bool hasValidMoves(Board board, Turn turn, bool kingdomAttackUnlocked) {
    for (int y = board.playableMinY; y <= board.playableMaxY; y++) {
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        if (isValidPlacement(board, x, y, turn, kingdomAttackUnlocked)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Checks if neither player has any valid moves remaining (e.g. board is full,
  /// or remaining tiles cannot be deployed to because neither player has enough siege points).
  static bool checkDraw(Board board, bool playerAttackUnlocked, bool aiAttackUnlocked) {
    final playerHasMoves = hasValidMoves(board, Turn.player, playerAttackUnlocked);
    final aiHasMoves = hasValidMoves(board, Turn.ai, aiAttackUnlocked);
    return !playerHasMoves && !aiHasMoves;
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

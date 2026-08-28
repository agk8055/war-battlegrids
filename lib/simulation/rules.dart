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

enum _WinCategory { uShape, parallel, gapBreach, kingdomAssisted }

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

      // We also cannot place a piece that would COMPLETE an offensive winning blockage around the opponent's kingdom!
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

      if (wouldCompleteBlockage.isWin &&
          (wouldCompleteBlockage.blockage?.contains((x, y)) ?? false)) {
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

    // Check if placing a piece here would complete a winning blockade against the opponent
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

    return wouldCompleteBlockage.isWin &&
        (wouldCompleteBlockage.blockage?.contains((x, y)) ?? false);
  }

  /// Calculates the score earned for capturing a list of units.
  static int calculateCaptureScore(int numberOfUnitsCaptured) {
    return numberOfUnitsCaptured * kCapturePointsValue;
  }

  /// Checks if the win condition has been met by entirely blockading / encircling the opponent's palace.
  static WinResult checkWinCondition(
    Board board,
    Turn currentTurn, {
    required bool kingdomAttackUnlocked,
    WinConditionType? activeCondition,
  }) {
    if (!kingdomAttackUnlocked) return WinResult(false);

    // 1. Check for actual U-shaped win
    final uWon = _findBlockade(
      board,
      currentTurn,
      _WinCategory.uShape,
      includeKingdom: false,
      includeEmpty: false,
    );
    if (uWon.isWin) return uWon;

    // Parallel win condition is ONLY enabled when U-shape is blocked / no longer possible
    // (e.g. opponent covered their kingdom / blocked access to the palace flanks)
    final isUShapePossible = isWinConditionPossible(board, currentTurn, WinConditionType.uShape);
    if (!isUShapePossible) {
      // 2. Check for actual Parallel win
      final pWon = _findBlockade(
        board,
        currentTurn,
        _WinCategory.parallel,
        includeKingdom: false,
        includeEmpty: false,
      );
      if (pWon.isWin) return pWon;

      // 3. Check for End / Gap breach win (breaching to the opponent's boundary through gaps/sides)
      final gapWon = _findBlockade(
        board,
        currentTurn,
        _WinCategory.gapBreach,
        includeKingdom: false,
        includeEmpty: false,
      );
      if (gapWon.isWin) return gapWon;

      // Kingdom-assisted win is ONLY enabled when Parallel is also not possible
      final isParallelPossible = isWinConditionPossible(board, currentTurn, WinConditionType.parallel);
      if (!isParallelPossible) {
        // 4. Check for actual Kingdom-assisted win
        return _findBlockade(
          board,
          currentTurn,
          _WinCategory.kingdomAssisted,
          includeKingdom: true,
          includeEmpty: false,
          requireKingdom: true,
        );
      }
    }

    return WinResult(false);
  }

  static WinResult _findBlockade(
    Board board, 
    Turn currentTurn, 
    _WinCategory category,
    {required bool includeKingdom, required bool includeEmpty, bool requireKingdom = false}
  ) {
    final attackerState = currentTurn == Turn.player ? CellState.player : CellState.ai;
    final attackerZone = currentTurn == Turn.player ? CellState.playerZone : CellState.aiZone;
    final isAttackingAI = currentTurn == Turn.player;

    final oppLeftPalaceX = isAttackingAI ? board.aiPalaceStartX : board.playerPalaceStartX;
    final oppRightPalaceX = isAttackingAI ? board.aiPalaceEndX : board.playerPalaceEndX;
    final oppPalaceBoundaryY = isAttackingAI ? board.playableMinY : board.playableMaxY;

    AnchorType? getAnchorType(int x, int y) {
      if (x == board.playableMinX) return AnchorType.leftEdge;
      if (x == board.playableMaxX) return AnchorType.rightEdge;
      if (y == oppPalaceBoundaryY) {
        if (x < oppLeftPalaceX) return AnchorType.topLeft;
        if (x > oppRightPalaceX) return AnchorType.topRight;
        // Reached opponent's boundary between palace markers (e.g. gap in kingdom or palace flank)
        return AnchorType.endGap;
      }
      return null;
    }

    final visited = <(int, int)>{};

    for (int y = board.playableMinY; y <= board.playableMaxY; y++) {
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        final state = board.getCell(x, y);
        bool isWallPart = (state == attackerState);
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
                bool isNeighborWall = (neighborState == attackerState);
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

          // A real blockade must contain at least one attacker unit (or attacker zone if allowed)
          if (!includeEmpty) {
            bool hasAttackerPiece = false;
            for (final coord in groupVisited) {
              final cState = board.getCell(coord.$1, coord.$2);
              if (cState == attackerState || (includeKingdom && cState == attackerZone)) {
                hasAttackerPiece = true;
                break;
              }
            }
            if (!hasAttackerPiece) continue;
          }

          final reachesOpponentEnd = foundAnchors.contains(AnchorType.topLeft) ||
              foundAnchors.contains(AnchorType.topRight) ||
              foundAnchors.contains(AnchorType.endGap);

          // Evaluate win by category
          switch (category) {
            case _WinCategory.uShape:
              // U-shape requires connecting both flanks of the opponent palace (or through end gaps)
              final hasLeftFlank = foundAnchors.contains(AnchorType.topLeft) || foundAnchors.contains(AnchorType.endGap);
              final hasRightFlank = foundAnchors.contains(AnchorType.topRight) || foundAnchors.contains(AnchorType.endGap);
              if (hasLeftFlank && hasRightFlank && foundAnchors.length >= 2) {
                return WinResult(true, groupVisited);
              }
              break;

            case _WinCategory.parallel:
              // Parallel requires connecting left and right edges
              if (foundAnchors.contains(AnchorType.leftEdge) && foundAnchors.contains(AnchorType.rightEdge)) {
                final midY = (board.playableMinY + board.playableMaxY) / 2.0;
                bool isOffensiveWall = false;
                if (isAttackingAI) {
                  // Attacking AI (at top): Wall separates AI palace if it's placed towards AI's side or middle (y < playerPalaceStartY)
                  isOffensiveWall = groupVisited.any((c) => c.$2 < board.playerPalaceStartY && c.$2 <= midY + 1);
                } else {
                  // Attacking Player (at bottom): Wall separates Player palace if it's placed towards Player's side or middle (y > aiPalaceEndY + 1 && y >= midY - 1)
                  isOffensiveWall = groupVisited.any((c) => c.$2 > board.aiPalaceEndY + 1 && c.$2 >= midY - 1);
                }
                if (isOffensiveWall) {
                  return WinResult(true, groupVisited);
                }
              }
              break;

            case _WinCategory.gapBreach:
              // Breaching the opponent's boundary through the gap or flank combined with a board side
              if (reachesOpponentEnd) {
                if (foundAnchors.contains(AnchorType.leftEdge) || foundAnchors.contains(AnchorType.rightEdge)) {
                  return WinResult(true, groupVisited);
                }
              }
              break;

            case _WinCategory.kingdomAssisted:
              // Kingdom-assisted: uses own kingdom zone and reaches the opponent's boundary/anchors
              if (requireKingdom && usesKingdom && reachesOpponentEnd && foundAnchors.length >= 2) {
                return WinResult(true, groupVisited);
              }
              break;
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
        return _findBlockade(board, turn, _WinCategory.uShape, includeKingdom: false, includeEmpty: true).isWin;
      case WinConditionType.parallel:
        return _findBlockade(board, turn, _WinCategory.parallel, includeKingdom: false, includeEmpty: true).isWin;
      case WinConditionType.kingdomAssisted:
        return _findBlockade(board, turn, _WinCategory.kingdomAssisted, includeKingdom: true, includeEmpty: true, requireKingdom: true).isWin;
    }
  }
}

enum AnchorType { leftEdge, rightEdge, topLeft, topRight, endGap }

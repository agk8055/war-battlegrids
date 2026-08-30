import '../game_simulation.dart';
import '../board.dart';
import '../../core/enums/turn.dart';
import '../../core/enums/cell_state.dart';
import '../../core/enums/win_condition_type.dart';
import '../../core/utils/capture_utils.dart';
import '../rules.dart';
import 'minimax.dart';
import 'ai_strategy.dart';
import 'evaluator.dart';

class RuleEngine {
  /// Entry point for the hybrid tactical AI.
  /// Evaluates urgent tactical rules in strict priority order based on game stage and strategy.
  static (int, int)? getBestMove(GameSimulation sim, AIStrategy strategy) {
    final allowZones = sim.currentTurn == Turn.ai
        ? sim.aiKingdomAttackUnlocked
        : sim.playerKingdomAttackUnlocked;
    final candidates = sim.board.getRestrictedAvailableCells(radius: 2, allowZones: allowZones);

    final isAIUnlocked = sim.aiKingdomAttackUnlocked;
    final isPlayerUnlocked = sim.playerKingdomAttackUnlocked;
    final stage = _getGameStage(isAIUnlocked, isPlayerUnlocked);

    // 0. URGENT OFFENSE: Immediate Win Check
    if (strategy.useRuleWinInstantly && isAIUnlocked) {
      final winMove = _findWinningMove(sim, candidates);
      if (winMove != null) return winMove;
    }

    // 1. CRITICAL DEFENSE: Block Opponent's 1-Move Lethal Win
    if (isPlayerUnlocked) {
      final blockWinMove = _findBlockOpponentWinMove(sim, candidates);
      if (blockWinMove != null) return blockWinMove;
    }

    // 2. GLORY THRESHOLD HUNTING: Capture that unlocks Kingdom Attack immediately
    if (strategy.useRuleImmediateCapture && !isAIUnlocked) {
      final thresholdUnlockCapture = _findThresholdUnlockingCapture(sim, candidates);
      if (thresholdUnlockCapture != null) return thresholdUnlockCapture;
    }

    // 3. MULTI-TIER BLOCKADE DEFENSE: Proactive flank guarding and chain cutting
    if (strategy.anticipateBlockades && isPlayerUnlocked) {
      final tierDefenseMove = _findMultiTierBlockadeDefense(sim, candidates, strategy);
      if (tierDefenseMove != null) return tierDefenseMove;
    }

    // 4. SITUATIONAL HIGH-VALUE CAPTURES
    if (strategy.useRuleImmediateCapture) {
      final immediateCapture = _findImmediateCapture(sim, candidates);
      if (immediateCapture != null) {
        // In Stage 1 (Pre-Siege Race) or Stage 2A (Emergency Defense), high-value captures take precedence
        if (stage == GameStage.preSiegeRace || stage == GameStage.emergencyDefense) {
          return immediateCapture;
        }
      }
    }

    // 5. TACTICAL DEFENSE: Rescue Friendly Pieces & Block Opponent Captures
    if (strategy.useRuleBlocking) {
      final rescueMove = _findRescueMove(sim, candidates);
      if (rescueMove != null) return rescueMove;

      final blockMove = _findBlockingMove(sim, candidates);
      if (blockMove != null) return blockMove;
    }

    // 6. TACTICAL OFFENSE: Double Threat (Fork)
    if (strategy.useRuleDoubleThreat) {
      final doubleThreat = _findDoubleThreat(sim, candidates);
      if (doubleThreat != null) return doubleThreat;
    }

    // 7. STRATEGIC BLOCKADE & PALACE BREACH (Kingdom Attack phase)
    if (strategy.useRuleSigil && isAIUnlocked) {
      final blockadeMove = _findBlockadeAdvanceMove(sim, candidates);
      if (blockadeMove != null) return blockadeMove;
    }

    // 8. DEEP SEARCH FALLBACK: Minimax with Threat-Space Search & PVS
    return MinimaxAI.getBestMove(sim, strategy);
  }

  static GameStage _getGameStage(bool aiUnlocked, bool playerUnlocked) {
    if (!aiUnlocked && !playerUnlocked) return GameStage.preSiegeRace;
    if (!aiUnlocked && playerUnlocked) return GameStage.emergencyDefense;
    if (aiUnlocked && !playerUnlocked) return GameStage.siegeAssault;
    return GameStage.dualSiegeEndgame;
  }

  /// 0. Win instantly if any valid move completes the active win condition tier.
  static (int, int)? _findWinningMove(GameSimulation sim, List<(int, int)> candidates) {
    final currentTurn = sim.currentTurn;
    final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    if (!attackUnlocked) return null;

    final attackerState = currentTurn == Turn.player ? CellState.player : CellState.ai;
    final activeCondition = currentTurn == Turn.player ? sim.playerActiveWinCondition : sim.aiActiveWinCondition;

    for (final move in candidates) {
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, attackUnlocked, activeCondition: activeCondition)) {
        continue;
      }

      final original = sim.board.getCell(move.$1, move.$2);
      sim.board.setCell(move.$1, move.$2, attackerState);
      final wins = GameRules.checkWinCondition(
        sim.board,
        currentTurn,
        kingdomAttackUnlocked: true,
        activeCondition: activeCondition,
      );
      sim.board.setCell(move.$1, move.$2, original);

      if (wins.isWin && (wins.blockage?.contains(move) ?? true)) {
        return move;
      }
    }
    return null;
  }

  /// 1. Blocks the opponent if they have a move that would immediately win on their next turn.
  static (int, int)? _findBlockOpponentWinMove(GameSimulation sim, List<(int, int)> candidates) {
    final currentTurn = sim.currentTurn;
    final oppTurn = currentTurn == Turn.player ? Turn.ai : Turn.player;
    final oppAttackUnlocked = oppTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;

    if (!oppAttackUnlocked) return null;

    final oppState = oppTurn == Turn.player ? CellState.player : CellState.ai;
    final oppActiveCondition = oppTurn == Turn.player ? sim.playerActiveWinCondition : sim.aiActiveWinCondition;
    final myAttackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final myActiveCondition = currentTurn == Turn.player ? sim.playerActiveWinCondition : sim.aiActiveWinCondition;

    for (final move in candidates) {
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, oppTurn, oppAttackUnlocked, activeCondition: oppActiveCondition)) {
        continue;
      }

      final original = sim.board.getCell(move.$1, move.$2);
      sim.board.setCell(move.$1, move.$2, oppState);
      final oppWin = GameRules.checkWinCondition(
        sim.board,
        oppTurn,
        kingdomAttackUnlocked: true,
        activeCondition: oppActiveCondition,
      );
      sim.board.setCell(move.$1, move.$2, original);

      if (oppWin.isWin && (oppWin.blockage?.contains(move) ?? true)) {
        if (GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, myAttackUnlocked, activeCondition: myActiveCondition)) {
          return move;
        }
      }
    }
    return null;
  }

  /// 2. Finds a capture that immediately crosses the threshold to unlock Kingdom Attack.
  static (int, int)? _findThresholdUnlockingCapture(GameSimulation sim, List<(int, int)> candidates) {
    final currentTurn = sim.currentTurn;
    final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final currentScore = currentTurn == Turn.player ? sim.playerScore : sim.aiScore;
    final threshold = currentTurn == Turn.player
        ? sim.config.playerKingdomAttackThreshold
        : sim.config.aiKingdomAttackThreshold;

    final attackerState = currentTurn == Turn.player ? CellState.player : CellState.ai;
    final defenderState = currentTurn == Turn.player ? CellState.ai : CellState.player;
    final activeCondition = currentTurn == Turn.player ? sim.playerActiveWinCondition : sim.aiActiveWinCondition;

    for (final move in candidates) {
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, attackUnlocked, activeCondition: activeCondition)) {
        continue;
      }

      sim.board.setCell(move.$1, move.$2, attackerState);
      try {
        final result = CaptureUtils.getCapturedUnits(sim.board, move, currentTurn);
        if (result.capturedCells.isNotEmpty && result.capturerTurn == currentTurn) {
          int enemyCount = 0;
          for (final c in result.capturedCells) {
            if (sim.board.getCell(c.$1, c.$2) == defenderState) enemyCount++;
          }
          if (currentScore + (enemyCount * 10) >= threshold) {
            return move; // Unlocks Kingdom Attack!
          }
        }
      } finally {
        sim.board.setCell(move.$1, move.$2, CellState.empty);
      }
    }
    return null;
  }

  /// 3. Multi-Tier Blockade Defense:
  /// Proactively counters the opponent's active blockade tier (Full U, Half U, or Parallel).
  static (int, int)? _findMultiTierBlockadeDefense(
    GameSimulation sim,
    List<(int, int)> candidates,
    AIStrategy strategy,
  ) {
    final board = sim.board;
    final isPlayer = sim.currentTurn == Turn.player;
    final oppTier = isPlayer ? sim.aiActiveWinCondition : sim.playerActiveWinCondition;
    final myAttackUnlocked = isPlayer ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final myActiveCondition = isPlayer ? sim.playerActiveWinCondition : sim.aiActiveWinCondition;

    // AI palace anchors to protect (when AI is defending at top)
    final targetPalaceMinY = isPlayer ? board.playerPalaceStartY : board.playableMinY;
    final leftCornerX = isPlayer ? board.playerPalaceStartX - 1 : board.aiPalaceStartX - 1;
    final rightCornerX = isPlayer ? board.playerPalaceEndX + 1 : board.aiPalaceEndX + 1;

    switch (oppTier) {
      case WinConditionType.fullUShape:
        // Tier 1 Defense: Deny the palace flanks. If opponent occupies or is near one flank,
        // AI secures the opposite flank to break the Full U-Shape condition!
        final leftFlankCoord = (leftCornerX, targetPalaceMinY);
        final rightFlankCoord = (rightCornerX, targetPalaceMinY);

        // Check if left corner is empty and legal
        if (candidates.contains(leftFlankCoord) &&
            GameRules.isValidPlacement(board, leftFlankCoord.$1, leftFlankCoord.$2, sim.currentTurn, myAttackUnlocked, activeCondition: myActiveCondition)) {
          // If player has a piece near right corner, grabbing left corner breaks Full U!
          if (_hasPlayerPieceNear(board, rightCornerX, targetPalaceMinY)) {
            return leftFlankCoord;
          }
        }

        // Check right corner
        if (candidates.contains(rightFlankCoord) &&
            GameRules.isValidPlacement(board, rightFlankCoord.$1, rightFlankCoord.$2, sim.currentTurn, myAttackUnlocked, activeCondition: myActiveCondition)) {
          if (_hasPlayerPieceNear(board, leftCornerX, targetPalaceMinY)) {
            return rightFlankCoord;
          }
        }
        break;

      case WinConditionType.halfUShape:
        // Tier 2 Defense: Player is connecting Left Edge -> Right Palace Flank OR Right Edge -> Left Palace Flank.
        // AI places in the open palace corner or cuts the diagonal midpoint.
        final openLeft = (leftCornerX, targetPalaceMinY);
        final openRight = (rightCornerX, targetPalaceMinY);

        if (candidates.contains(openLeft) &&
            GameRules.isValidPlacement(board, openLeft.$1, openLeft.$2, sim.currentTurn, myAttackUnlocked, activeCondition: myActiveCondition)) {
          return openLeft;
        }
        if (candidates.contains(openRight) &&
            GameRules.isValidPlacement(board, openRight.$1, openRight.$2, sim.currentTurn, myAttackUnlocked, activeCondition: myActiveCondition)) {
          return openRight;
        }
        break;

      case WinConditionType.parallel:
        // Tier 3 Defense: Player is connecting across columns from Left Edge to Right Edge.
        // AI finds candidate moves that intersect the player's horizontal chain across the central columns.
        final midCol = (board.playableMinX + board.playableMaxX) ~/ 2;
        for (final move in candidates) {
          if (move.$1 >= midCol - 1 && move.$1 <= midCol + 1) {
            if (_isAdjacentToPlayer8Way(board, move.$1, move.$2) &&
                GameRules.isValidPlacement(board, move.$1, move.$2, sim.currentTurn, myAttackUnlocked, activeCondition: myActiveCondition)) {
              return move; // Sever the parallel chain!
            }
          }
        }
        break;

      case WinConditionType.kingdomAssisted:
        break;
    }

    return null;
  }

  static bool _hasPlayerPieceNear(Board board, int targetX, int targetY) {
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final nx = targetX + dx;
        final ny = targetY + dy;
        if (board.isWithinPlayableArea(nx, ny)) {
          final cell = board.getCell(nx, ny);
          if (cell == CellState.player || cell == CellState.capturedGrid) return true;
        }
      }
    }
    return false;
  }

  static bool _isAdjacentToPlayer8Way(Board board, int x, int y) {
    final dirs = [
      (x, y - 1), (x, y + 1), (x - 1, y), (x + 1, y),
      (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1), (x + 1, y + 1),
    ];
    for (final d in dirs) {
      if (board.isWithinPlayableArea(d.$1, d.$2)) {
        final st = board.getCell(d.$1, d.$2);
        if (st == CellState.player || st == CellState.capturedGrid) return true;
      }
    }
    return false;
  }

  /// 4. Finds a move that captures opponent units immediately.
  static (int, int)? _findImmediateCapture(GameSimulation sim, List<(int, int)> candidates) {
    final currentTurn = sim.currentTurn;
    final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final attackerState = currentTurn == Turn.player ? CellState.player : CellState.ai;
    final defenderState = currentTurn == Turn.player ? CellState.ai : CellState.player;
    final activeCondition = currentTurn == Turn.player ? sim.playerActiveWinCondition : sim.aiActiveWinCondition;

    (int, int)? bestMove;
    int maxCaptures = 0;

    for (final move in candidates) {
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, attackUnlocked, activeCondition: activeCondition)) {
        continue;
      }

      sim.board.setCell(move.$1, move.$2, attackerState);
      try {
        final result = CaptureUtils.getCapturedUnits(sim.board, move, currentTurn);
        if (result.capturedCells.isNotEmpty && result.capturerTurn == currentTurn) {
          int enemyCount = 0;
          for (final c in result.capturedCells) {
            if (sim.board.getCell(c.$1, c.$2) == defenderState) enemyCount++;
          }
          if (enemyCount > maxCaptures) {
            maxCaptures = enemyCount;
            bestMove = move;
          }
        }
      } finally {
        sim.board.setCell(move.$1, move.$2, CellState.empty);
      }
    }

    return bestMove;
  }

  /// 5a. Finds a move that rescues friendly pieces that have only 1 liberty (in Atari).
  static (int, int)? _findRescueMove(GameSimulation sim, List<(int, int)> candidates) {
    final currentTurn = sim.currentTurn;
    final myState = currentTurn == Turn.player ? CellState.player : CellState.ai;
    final oppTurn = currentTurn == Turn.player ? Turn.ai : Turn.player;
    final myAttackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final myActiveCondition = currentTurn == Turn.player ? sim.playerActiveWinCondition : sim.aiActiveWinCondition;

    for (final move in candidates) {
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, myAttackUnlocked, activeCondition: myActiveCondition)) {
        continue;
      }

      final original = sim.board.getCell(move.$1, move.$2);
      sim.board.setCell(move.$1, move.$2, myState);
      bool savesGroup = false;

      try {
        final selfCheck = CaptureUtils.getCapturedUnits(sim.board, move, currentTurn);
        if (selfCheck.capturedCells.isEmpty || selfCheck.capturerTurn == currentTurn) {
          sim.board.setCell(move.$1, move.$2, CellState.empty);
          final oppCheck = CaptureUtils.getCapturedUnits(sim.board, move, oppTurn);
          if (oppCheck.capturedCells.isNotEmpty && oppCheck.capturerTurn == oppTurn) {
            savesGroup = true;
          }
          sim.board.setCell(move.$1, move.$2, myState);
        }
      } finally {
        sim.board.setCell(move.$1, move.$2, original);
      }

      if (savesGroup) {
        return move;
      }
    }
    return null;
  }

  /// 5b. Finds a move to block an opponent's capture on their next turn.
  static (int, int)? _findBlockingMove(GameSimulation sim, List<(int, int)> candidates) {
    final currentTurn = sim.currentTurn;
    final opponentTurn = currentTurn == Turn.player ? Turn.ai : Turn.player;
    final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final opponentAttackUnlocked = opponentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final myActiveCondition = currentTurn == Turn.player ? sim.playerActiveWinCondition : sim.aiActiveWinCondition;

    final oppState = opponentTurn == Turn.player ? CellState.player : CellState.ai;
    final myState = currentTurn == Turn.player ? CellState.player : CellState.ai;

    (int, int)? bestBlock;
    int maxThreatened = 0;

    for (final move in candidates) {
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, opponentTurn, opponentAttackUnlocked)) {
        continue;
      }

      sim.board.setCell(move.$1, move.$2, oppState);
      int potentialCaptures = 0;
      try {
        final result = CaptureUtils.getCapturedUnits(sim.board, move, opponentTurn);
        if (result.capturerTurn == opponentTurn) {
          for (final c in result.capturedCells) {
            if (sim.board.getCell(c.$1, c.$2) == myState) {
              potentialCaptures++;
            }
          }
        }
      } finally {
        sim.board.setCell(move.$1, move.$2, CellState.empty);
      }

      if (potentialCaptures > maxThreatened) {
        if (GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, attackUnlocked, activeCondition: myActiveCondition)) {
          bool getsCaptured = false;
          sim.board.setCell(move.$1, move.$2, myState);
          try {
            final selfResult = CaptureUtils.getCapturedUnits(sim.board, move, currentTurn);
            if (selfResult.capturedCells.isNotEmpty && selfResult.capturerTurn == opponentTurn) {
              getsCaptured = true;
            }
          } finally {
            sim.board.setCell(move.$1, move.$2, CellState.empty);
          }

          if (!getsCaptured) {
            maxThreatened = potentialCaptures;
            bestBlock = move;
          }
        }
      }
    }

    return bestBlock;
  }

  /// 6. Finds a move that creates a double threat (fork).
  static (int, int)? _findDoubleThreat(GameSimulation sim, List<(int, int)> candidates) {
    final currentTurn = sim.currentTurn;
    final attackUnlocked = currentTurn == Turn.player ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    final attackerState = currentTurn == Turn.player ? CellState.player : CellState.ai;
    final myActiveCondition = currentTurn == Turn.player ? sim.playerActiveWinCondition : sim.aiActiveWinCondition;

    for (final move in candidates) {
      if (!GameRules.isValidPlacement(sim.board, move.$1, move.$2, currentTurn, attackUnlocked, activeCondition: myActiveCondition)) {
        continue;
      }

      int capturingNextMovesCount = 0;
      sim.board.setCell(move.$1, move.$2, attackerState);
      try {
        final orthogonalDirs = [
          (move.$1, move.$2 - 1), (move.$1, move.$2 + 1),
          (move.$1 - 1, move.$2), (move.$1 + 1, move.$2),
        ];
        for (final nextMove in orthogonalDirs) {
          if (!sim.board.isWithinPlayableArea(nextMove.$1, nextMove.$2)) continue;
          if (sim.board.getCell(nextMove.$1, nextMove.$2) != CellState.empty) continue;
          if (!GameRules.isValidPlacement(sim.board, nextMove.$1, nextMove.$2, currentTurn, attackUnlocked, activeCondition: myActiveCondition)) continue;

          sim.board.setCell(nextMove.$1, nextMove.$2, attackerState);
          final nextResult = CaptureUtils.getCapturedUnits(sim.board, nextMove, currentTurn);
          sim.board.setCell(nextMove.$1, nextMove.$2, CellState.empty);

          if (nextResult.capturedCells.isNotEmpty && nextResult.capturerTurn == currentTurn) {
            capturingNextMovesCount++;
          }
        }
      } finally {
        sim.board.setCell(move.$1, move.$2, CellState.empty);
      }

      if (capturingNextMovesCount >= 2) {
        return move;
      }
    }

    return null;
  }

  /// 7. Strategic Blockade & Palace Breach Move:
  static (int, int)? _findBlockadeAdvanceMove(GameSimulation sim, List<(int, int)> candidates) {
    final isPlayer = sim.currentTurn == Turn.player;
    final attackUnlocked = isPlayer ? sim.playerKingdomAttackUnlocked : sim.aiKingdomAttackUnlocked;
    if (!attackUnlocked) return null;

    final board = sim.board;
    final activeTier = isPlayer ? sim.playerActiveWinCondition : sim.aiActiveWinCondition;
    final myState = isPlayer ? CellState.player : CellState.ai;

    (int, int)? bestMove;
    int bestScore = 0;

    for (final move in candidates) {
      if (!GameRules.isValidPlacement(board, move.$1, move.$2, sim.currentTurn, attackUnlocked, activeCondition: activeTier)) {
        continue;
      }

      int score = 0;
      final x = move.$1;
      final y = move.$2;

      // 1. Proximity to opponent palace flanks or breach inside palace
      if (isPlayer) {
        if (y == board.playableMinY && (x < board.aiPalaceStartX || x > board.aiPalaceEndX)) {
          score += 25;
        }
        if (x >= board.aiPalaceStartX && x <= board.aiPalaceEndX && y >= board.aiPalaceStartY && y <= board.aiPalaceEndY) {
          score += 35;
        }
      } else {
        if (y == board.playableMaxY && (x < board.playerPalaceStartX || x > board.playerPalaceEndX)) {
          score += 25;
        }
        if (x >= board.playerPalaceStartX && x <= board.playerPalaceEndX && y >= board.playerPalaceStartY && y <= board.playerPalaceEndY) {
          score += 35;
        }
      }

      // 2. Count 8-way friendly connections to extend chains
      final adjacentDirs = [
        (x, y - 1), (x, y + 1), (x - 1, y), (x + 1, y),
        (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1), (x + 1, y + 1),
      ];

      int friendlyNeighbors = 0;
      for (final dir in adjacentDirs) {
        if (board.isWithinPlayableArea(dir.$1, dir.$2)) {
          final st = board.getCell(dir.$1, dir.$2);
          if (st == myState || st == CellState.capturedGrid) {
            friendlyNeighbors++;
          }
        }
      }

      score += friendlyNeighbors * 8;

      if (score > bestScore && friendlyNeighbors > 0) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }
}

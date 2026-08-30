import '../../core/enums/cell_state.dart';
import '../../core/enums/turn.dart';
import '../../core/enums/game_phase.dart';
import '../../core/enums/win_condition_type.dart';

import '../game_simulation.dart';
import '../board.dart';
import 'ai_strategy.dart';

enum GameStage {
  preSiegeRace,      // Stage 1: Both locked (Focus on captures & territory)
  emergencyDefense,  // Stage 2A: Opponent unlocked, AI locked (Focus on multi-tier defense & threshold hunting)
  siegeAssault,      // Stage 2B: AI unlocked, Opponent locked (Focus on active blockade conversion)
  dualSiegeEndgame,  // Stage 3: Both unlocked (Sudden death attack & defense)
}

class HeuristicEvaluator {
  static const int winScore = 1000000;

  /// Evaluates the current game state from the perspective of the AI based on game stage and tactical situation.
  static int evaluate(GameSimulation simulation, AIStrategy strategy) {
    if (simulation.currentPhase == GamePhase.gameOver) {
      return simulation.winner == Turn.ai ? winScore : -winScore;
    }

    if (simulation.currentPhase == GamePhase.draw) {
      return 0;
    }

    final isAIAttackUnlocked = simulation.aiKingdomAttackUnlocked;
    final isPlayerAttackUnlocked = simulation.playerKingdomAttackUnlocked;
    final stage = _determineGameStage(isAIAttackUnlocked, isPlayerAttackUnlocked);

    int score = 0;

    // 1. Stage-Dependent Glory & Score Momentum
    score += _evaluateScoreMomentum(simulation, stage, strategy);

    // 2. Multi-Tier Blockade Prevention (Counter Opponent's Active Win Tier)
    score -= _evaluateMultiTierOpponentThreat(simulation, stage, strategy);

    // 3. Active Win Condition Tier Alignment for AI
    score += _evaluateAIBlockadeProgress(simulation, stage, strategy);

    // 4. Board-wide Piece, Liberty & Tactical Encirclement Analysis
    score += _evaluateTacticalBoard(simulation, strategy);

    return score;
  }

  static GameStage _determineGameStage(bool aiUnlocked, bool playerUnlocked) {
    if (!aiUnlocked && !playerUnlocked) return GameStage.preSiegeRace;
    if (!aiUnlocked && playerUnlocked) return GameStage.emergencyDefense;
    if (aiUnlocked && !playerUnlocked) return GameStage.siegeAssault;
    return GameStage.dualSiegeEndgame;
  }

  /// Evaluates capture score difference and progress toward unlocking Kingdom Attack.
  static int _evaluateScoreMomentum(
    GameSimulation simulation,
    GameStage stage,
    AIStrategy strategy,
  ) {
    int score = (simulation.aiScore - simulation.playerScore) * strategy.captureWeight;
    final aiThreshold = simulation.config.aiKingdomAttackThreshold;
    final playerThreshold = simulation.config.playerKingdomAttackThreshold;

    switch (stage) {
      case GameStage.preSiegeRace:
        // Race to unlock Kingdom Attack first
        if (aiThreshold > 0) {
          final aiProgress = (simulation.aiScore / aiThreshold).clamp(0.0, 1.0);
          score += (aiProgress * strategy.gloryHuntWeight * 2).toInt();
          // Massive bonus if 1 capture away from unlock
          if (simulation.aiScore + 10 >= aiThreshold) {
            score += strategy.gloryHuntWeight * 3;
          }
        }
        break;

      case GameStage.emergencyDefense:
        // Desperately hunt for captures to gain siege counter-offensive power
        score -= 1500; // Inherent situational danger
        if (aiThreshold > 0) {
          final neededPoints = aiThreshold - simulation.aiScore;
          if (neededPoints <= 10) {
            score += strategy.gloryHuntWeight * 4; // Crucial capture needed!
          } else {
            final aiProgress = (simulation.aiScore / aiThreshold).clamp(0.0, 1.0);
            score += (aiProgress * strategy.gloryHuntWeight * 2).toInt();
          }
        }
        break;

      case GameStage.siegeAssault:
        score += 1500; // Sole siege advantage
        // Prevent player from unlocking
        if (playerThreshold > 0 && simulation.playerScore + 10 >= playerThreshold) {
          score -= 300; // Player is close to unlocking, caution advised
        }
        break;

      case GameStage.dualSiegeEndgame:
        // Both can win; score difference matters less than blockade paths
        score += (simulation.aiScore - simulation.playerScore) * (strategy.captureWeight ~/ 2);
        break;
    }

    return score;
  }

  /// Multi-Tier Opponent Threat Evaluation:
  /// Evaluates and penalizes the player's progress across Tier 1 (Full U), Tier 2 (Half U), and Tier 3 (Parallel).
  /// Rewards AI for occupying bottleneck defense tiles and cutting connection chains.
  static int _evaluateMultiTierOpponentThreat(
    GameSimulation simulation,
    GameStage stage,
    AIStrategy strategy,
  ) {
    final board = simulation.board;
    final playerActiveTier = simulation.playerActiveWinCondition;
    final isPlayerUnlocked = simulation.playerKingdomAttackUnlocked;

    // Determine defense multiplier based on stage and strategy
    double defenseMultiplier = 1.0;
    if (isPlayerUnlocked) {
      defenseMultiplier = 3.5;
      if (stage == GameStage.emergencyDefense) defenseMultiplier = 4.5;
    }

    int threatScore = 0;

    // Inspect player and AI pieces at key defense coordinates
    bool playerHasLeftEdge = false;
    bool playerHasRightEdge = false;
    bool playerHasAIPalaceLeftCorner = false;
    bool playerHasAIPalaceRightCorner = false;

    bool aiGuardsLeftCorner = false;
    bool aiGuardsRightCorner = false;

    int playerPiecesNearAIPalace = 0;
    final midY = (board.playableMinY + board.playableMaxY) / 2.0;

    // Scan the board
    for (int y = board.playableMinY; y <= board.playableMaxY; y++) {
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        final cell = board.getCell(x, y);

        if (cell == CellState.player || cell == CellState.capturedGrid) {
          if (x == board.playableMinX) playerHasLeftEdge = true;
          if (x == board.playableMaxX) playerHasRightEdge = true;

          if (y == board.playableMinY) {
            if (x < board.aiPalaceStartX) playerHasAIPalaceLeftCorner = true;
            if (x > board.aiPalaceEndX) playerHasAIPalaceRightCorner = true;
          }

          if (_isNearAIPalace(board, x, y)) {
            playerPiecesNearAIPalace++;
          }
        } else if (cell == CellState.ai || cell == CellState.capturedGrid) {
          if (y == board.playableMinY && x < board.aiPalaceStartX) aiGuardsLeftCorner = true;
          if (y == board.playableMinY && x > board.aiPalaceEndX) aiGuardsRightCorner = true;
        }
      }
    }

    // Baseline proximity threat
    threatScore += (playerPiecesNearAIPalace * strategy.palaceDefendWeight * defenseMultiplier).toInt();

    // Flank Guarding Reward (AI holding palace corners structurally denies Full U-Shape)
    if (aiGuardsLeftCorner) threatScore -= (strategy.flankDefenseWeight * defenseMultiplier * 1.5).toInt();
    if (aiGuardsRightCorner) threatScore -= (strategy.flankDefenseWeight * defenseMultiplier * 1.5).toInt();

    // Tier-Specific Threat Analysis
    switch (playerActiveTier) {
      case WinConditionType.fullUShape:
        // Tier 1: Player needs both palace flanks (Left Corner AND Right Corner)
        if (playerHasAIPalaceLeftCorner && playerHasAIPalaceRightCorner) {
          // LETHAL FULL-U THREAT! Both flanks anchored!
          threatScore += (strategy.flankDefenseWeight * defenseMultiplier * 8).toInt();
        } else if (playerHasAIPalaceLeftCorner || playerHasAIPalaceRightCorner) {
          // 1 Flank anchored: high threat
          threatScore += (strategy.flankDefenseWeight * defenseMultiplier * 3).toInt();
        }
        break;

      case WinConditionType.halfUShape:
        // Tier 2: Player needs Left Edge -> Right Corner OR Right Edge -> Left Corner
        final leftToRight = playerHasLeftEdge && playerHasAIPalaceRightCorner;
        final rightToLeft = playerHasRightEdge && playerHasAIPalaceLeftCorner;
        if (leftToRight || rightToLeft) {
          threatScore += (strategy.chainCuttingWeight * defenseMultiplier * 7).toInt();
        } else {
          threatScore += (strategy.chainCuttingWeight * defenseMultiplier * 2).toInt();
        }
        break;

      case WinConditionType.parallel:
        // Tier 3: Player needs Left Edge -> Right Edge across the battlefield
        if (playerHasLeftEdge && playerHasRightEdge) {
          threatScore += (strategy.chainCuttingWeight * defenseMultiplier * 6).toInt();
        } else if (playerHasLeftEdge || playerHasRightEdge) {
          threatScore += (strategy.chainCuttingWeight * defenseMultiplier * 2).toInt();
        }
        break;

      case WinConditionType.kingdomAssisted:
        if (playerHasAIPalaceLeftCorner || playerHasAIPalaceRightCorner) {
          threatScore += (strategy.palaceDefendWeight * defenseMultiplier * 4).toInt();
        }
        break;
    }

    return threatScore;
  }

  /// Evaluates how effectively the AI is advancing its active win condition tier.
  static int _evaluateAIBlockadeProgress(
    GameSimulation simulation,
    GameStage stage,
    AIStrategy strategy,
  ) {
    final board = simulation.board;
    final activeTier = simulation.aiActiveWinCondition;
    final isAIAttackUnlocked = simulation.aiKingdomAttackUnlocked;

    final weight = isAIAttackUnlocked
        ? strategy.sigilWeight
        : (strategy.sigilWeight * 0.35).toInt();
    if (weight <= 0) return 0;

    int tierScore = 0;
    bool hasLeftAnchor = false;
    bool hasRightAnchor = false;
    bool hasPlayerPalaceLeftFlank = false;
    bool hasPlayerPalaceRightFlank = false;
    int palaceAdjacentCount = 0;
    int palaceBreachCount = 0;

    for (int y = board.playableMinY; y <= board.playableMaxY; y++) {
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        final cell = board.getCell(x, y);
        final isAIPart = (cell == CellState.ai || cell == CellState.capturedGrid);

        if (!isAIPart) continue;

        if (x == board.playableMinX) hasLeftAnchor = true;
        if (x == board.playableMaxX) hasRightAnchor = true;

        if (y == board.playableMaxY) {
          if (x < board.playerPalaceStartX) hasPlayerPalaceLeftFlank = true;
          if (x > board.playerPalaceEndX) hasPlayerPalaceRightFlank = true;
        }

        if (_isNearPlayerPalace(board, x, y)) {
          palaceAdjacentCount++;
        }

        if (cell == CellState.ai && _isInsidePlayerPalace(board, x, y)) {
          palaceBreachCount++;
        }
      }
    }

    switch (activeTier) {
      case WinConditionType.fullUShape:
        if (hasPlayerPalaceLeftFlank) tierScore += weight;
        if (hasPlayerPalaceRightFlank) tierScore += weight;
        if (hasPlayerPalaceLeftFlank && hasPlayerPalaceRightFlank) {
          tierScore += (weight * 3).toInt(); // Ready to close U-shape!
        }
        tierScore += palaceAdjacentCount * (strategy.palaceAttackWeight ~/ 2);
        tierScore += palaceBreachCount * strategy.palaceAttackWeight;
        break;

      case WinConditionType.halfUShape:
        final leftToRightFlank = hasLeftAnchor && hasPlayerPalaceRightFlank;
        final rightToLeftFlank = hasRightAnchor && hasPlayerPalaceLeftFlank;
        if (leftToRightFlank || rightToLeftFlank) {
          tierScore += (weight * 2.5).toInt();
        } else {
          if (hasLeftAnchor || hasRightAnchor) tierScore += weight ~/ 2;
          if (hasPlayerPalaceLeftFlank || hasPlayerPalaceRightFlank) tierScore += weight ~/ 2;
        }
        break;

      case WinConditionType.parallel:
        if (hasLeftAnchor && hasRightAnchor) {
          tierScore += (weight * 2.2).toInt();
        } else if (hasLeftAnchor || hasRightAnchor) {
          tierScore += weight ~/ 2;
        }
        break;

      case WinConditionType.kingdomAssisted:
        if (hasPlayerPalaceLeftFlank || hasPlayerPalaceRightFlank || (hasLeftAnchor && hasRightAnchor)) {
          tierScore += (weight * 2.0).toInt();
        }
        break;
    }

    return tierScore;
  }

  /// Evaluates board-wide tactical factors: group liberties (Atari), 8-way connectivity, bridging, and zone control.
  static int _evaluateTacticalBoard(GameSimulation simulation, AIStrategy strategy) {
    final board = simulation.board;
    int tacticalScore = 0;

    final Set<(int, int)> visitedAI = {};
    final Set<(int, int)> visitedPlayer = {};
    final midY = (board.playableMinY + board.playableMaxY) / 2.0;

    for (int y = board.playableMinY; y <= board.playableMaxY; y++) {
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        final cell = board.getCell(x, y);

        if (cell == CellState.ai) {
          // Zone dominance (pushing forward into player territory)
          if (strategy.zoneControlWeight > 0 && y >= midY) {
            tacticalScore += (strategy.zoneControlWeight * (1 + (y - midY) / 2)).toInt();
          }

          // 8-Way Connectivity to friendly pieces / captured grids
          final neighborConnections = _count8WayNeighbors(board, x, y, CellState.ai, CellState.capturedGrid);
          if (neighborConnections > 0) {
            tacticalScore += neighborConnections * (strategy.connectivityWeight ~/ 2);
          }

          // Bridging potential
          if (strategy.connectivityWeight > 0 && _hasBridgePotential(board, x, y, CellState.ai)) {
            tacticalScore += strategy.connectivityWeight ~/ 3;
          }

          // Group Liberties / Atari Detection
          if (!visitedAI.contains((x, y))) {
            final group = <(int, int)>[];
            final liberties = _calculateGroupLiberties(board, (x, y), CellState.ai, CellState.aiZone, group, visitedAI);

            if (liberties == 1) {
              // In Atari: high danger
              tacticalScore -= 240 * group.length;
            } else if (liberties == 2) {
              tacticalScore -= 50 * group.length;
            } else if (liberties >= 4) {
              tacticalScore += 20 * group.length;
            }
          }

        } else if (cell == CellState.player) {
          // Player Group Liberties / Capture Opportunities
          if (!visitedPlayer.contains((x, y))) {
            final group = <(int, int)>[];
            final liberties = _calculateGroupLiberties(board, (x, y), CellState.player, CellState.playerZone, group, visitedPlayer);

            if (liberties == 1) {
              // Opponent in Atari: high reward capture target!
              tacticalScore += 220 * group.length;
            } else if (liberties == 2) {
              tacticalScore += 60 * group.length;
            }
          }
        }
      }
    }

    return tacticalScore;
  }

  static int _calculateGroupLiberties(
    Board board,
    (int, int) startCoord,
    CellState pieceState,
    CellState factionZone,
    List<(int, int)> outGroup,
    Set<(int, int)> visitedTracker,
  ) {
    final Set<(int, int)> group = {};
    final Set<(int, int)> liberties = {};
    final List<(int, int)> queue = [startCoord];
    group.add(startCoord);
    visitedTracker.add(startCoord);

    int head = 0;
    while (head < queue.length) {
      final curr = queue[head++];

      final orthogonal = [
        (curr.$1, curr.$2 - 1),
        (curr.$1, curr.$2 + 1),
        (curr.$1 - 1, curr.$2),
        (curr.$1 + 1, curr.$2),
      ];

      for (final n in orthogonal) {
        if (!board.isWithinPlayableArea(n.$1, n.$2)) {
          liberties.add(n);
          continue;
        }

        final state = board.getCell(n.$1, n.$2);

        if (state == pieceState) {
          if (!group.contains(n)) {
            group.add(n);
            visitedTracker.add(n);
            queue.add(n);
          }
        } else if (state == factionZone) {
          liberties.add(n);
          liberties.add((-1, -1));
        } else if (state == CellState.empty) {
          liberties.add(n);
        }
      }
    }

    outGroup.addAll(group);
    return liberties.length;
  }

  static int _count8WayNeighbors(
    Board board,
    int x,
    int y,
    CellState state1,
    CellState state2,
  ) {
    int count = 0;
    final dirs = [
      (x, y - 1), (x, y + 1), (x - 1, y), (x + 1, y),
      (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1), (x + 1, y + 1),
    ];
    for (final dir in dirs) {
      if (board.isWithinPlayableArea(dir.$1, dir.$2)) {
        final st = board.getCell(dir.$1, dir.$2);
        if (st == state1 || st == state2) count++;
      }
    }
    return count;
  }

  static bool _hasBridgePotential(Board board, int x, int y, CellState state) {
    final offsets = [
      (-2, 0), (2, 0), (0, -2), (0, 2),
      (-1, -2), (1, -2), (-1, 2), (1, 2),
      (-2, -1), (-2, 1), (2, -1), (2, 1),
    ];
    for (final off in offsets) {
      final nx = x + off.$1;
      final ny = y + off.$2;
      if (board.isWithinPlayableArea(nx, ny) && board.getCell(nx, ny) == state) {
        return true;
      }
    }
    return false;
  }

  static bool _isNearPlayerPalace(Board board, int x, int y) {
    return x >= board.playerPalaceStartX - 1 &&
        x <= board.playerPalaceEndX + 1 &&
        y >= board.playerPalaceStartY - 1 &&
        y <= board.playerPalaceEndY + 1;
  }

  static bool _isInsidePlayerPalace(Board board, int x, int y) {
    return x >= board.playerPalaceStartX &&
        x <= board.playerPalaceEndX &&
        y >= board.playerPalaceStartY &&
        y <= board.playerPalaceEndY;
  }

  static bool _isNearAIPalace(Board board, int x, int y) {
    return x >= board.aiPalaceStartX - 1 &&
        x <= board.aiPalaceEndX + 1 &&
        y >= board.aiPalaceStartY - 1 &&
        y <= board.aiPalaceEndY + 1;
  }
}

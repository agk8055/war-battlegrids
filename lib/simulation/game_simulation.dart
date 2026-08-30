import '../core/enums/cell_state.dart';
import '../core/enums/game_phase.dart';
import '../core/enums/turn.dart';
import '../core/enums/win_condition_type.dart';
import '../core/models/level_config.dart';
import '../core/models/battle_stats.dart';
import '../core/utils/capture_utils.dart';
import 'board.dart';
import 'rules.dart';

class GameSimulation {
  Board board;
  final LevelConfig config;
  GamePhase currentPhase = GamePhase.placement;
  Turn currentTurn = Turn.player;

  int playerScore = 0;
  int aiScore = 0;

  bool playerKingdomAttackUnlocked = false;
  bool aiKingdomAttackUnlocked = false;

  WinConditionType playerActiveWinCondition = WinConditionType.fullUShape;
  WinConditionType aiActiveWinCondition = WinConditionType.fullUShape;

  Turn? winner;
  WinConditionType? winningConditionType;

  // Match statistics tracking
  DateTime startTime;
  DateTime? endTime;

  int playerMoves = 0;
  int aiMoves = 0;

  int playerCapturedUnits = 0;
  int aiCapturedUnits = 0;

  int playerCaptureEvents = 0;
  int aiCaptureEvents = 0;

  int playerMaxCombo = 0;
  int aiMaxCombo = 0;

  (int, int)? lastPlacedCoord;
  List<(int, int)> lastCapturedCells = [];
  Set<((int, int), (int, int))> lastNewLinkages = {};
  Turn? lastMovedTurn;

  GameSimulation({LevelConfig? config, DateTime? startTime})
    : config = config ?? LevelConfig.standard(),
      startTime = startTime ?? DateTime.now(),
      board = Board(
        width: (config ?? LevelConfig.standard()).boardWidth,
        height: (config ?? LevelConfig.standard()).boardHeight,
      );

  /// Attempts to place a unit for the current turn at the given coordinates.
  /// Returns a record: (success, captureOccurred)
  (bool, bool) placeUnit(int x, int y) {
    if (currentPhase == GamePhase.gameOver || currentPhase == GamePhase.draw) return (false, false);

    final isPlayer = currentTurn == Turn.player;
    final attackUnlocked = isPlayer
        ? playerKingdomAttackUnlocked
        : aiKingdomAttackUnlocked;
    final activeCondition = isPlayer
        ? playerActiveWinCondition
        : aiActiveWinCondition;

    if (!GameRules.isValidPlacement(
      board,
      x,
      y,
      currentTurn,
      attackUnlocked,
      activeCondition: activeCondition,
    )) {
      return (false, false); // Invalid move
    }

    lastPlacedCoord = (x, y);
    lastCapturedCells = [];
    lastNewLinkages = {};
    lastMovedTurn = currentTurn;

    // Place the piece
    final pieceState = isPlayer ? CellState.player : CellState.ai;
    board.setCell(x, y, pieceState);

    if (isPlayer) {
      playerMoves++;
    } else {
      aiMoves++;
    }

    // Evaluate Captures
    final captureResult = CaptureUtils.getCapturedUnits(board, (
      x,
      y,
    ), currentTurn);
    
    bool captureOccurred = false;
    if (captureResult.capturedCells.isNotEmpty) {
      _handleCaptures(captureResult.capturedCells, capturerTurn: captureResult.capturerTurn);
      board.linkages.addAll(captureResult.linkages);
      lastCapturedCells = List.from(captureResult.capturedCells);
      lastNewLinkages = Set.from(captureResult.linkages);
      lastMovedTurn = captureResult.capturerTurn;
      captureOccurred = true;
    }

    // Evaluate Win Condition
    final isKingdomAttackUnlocked = isPlayer
        ? playerKingdomAttackUnlocked
        : aiKingdomAttackUnlocked;
    final winResult = GameRules.checkWinCondition(
      board,
      currentTurn,
      kingdomAttackUnlocked: isKingdomAttackUnlocked,
      activeCondition: activeCondition,
    );
    
    if (winResult.isWin) {
      if (winResult.blockage != null) {
        final winLinkages = CaptureUtils.getLinkagesFromBlockage(winResult.blockage!);
        board.linkages.addAll(winLinkages);
        lastNewLinkages.addAll(winLinkages);
      }
      currentPhase = GamePhase.gameOver;
      winner = currentTurn;
      winningConditionType = isPlayer ? playerActiveWinCondition : aiActiveWinCondition;
      endTime = DateTime.now();
      // Do NOT switch turns if game is over
      return (true, captureOccurred);
    }

    // Evaluate Draw Condition
    if (GameRules.checkDraw(
      board,
      playerKingdomAttackUnlocked,
      aiKingdomAttackUnlocked,
      playerActiveCondition: playerActiveWinCondition,
      aiActiveCondition: aiActiveWinCondition,
    )) {
      currentPhase = GamePhase.draw;
      winner = null; // No winner
      endTime = DateTime.now();
      return (true, captureOccurred);
    }

    // Update active win conditions for both players
    _updateActiveWinConditions();

    // Switch turns
    currentTurn = isPlayer ? Turn.ai : Turn.player;
    return (true, captureOccurred);
  }

  /// Skips the current turn and switches to the other player.
  /// Returns true if the game continues, false if it results in a draw.
  bool skipTurn() {
    if (currentPhase == GamePhase.gameOver || currentPhase == GamePhase.draw) return false;

    currentTurn = (currentTurn == Turn.player) ? Turn.ai : Turn.player;

    // After skipping, check if the NEW current player also has no moves.
    // If neither can move, it's a draw.
    if (GameRules.checkDraw(
      board,
      playerKingdomAttackUnlocked,
      aiKingdomAttackUnlocked,
      playerActiveCondition: playerActiveWinCondition,
      aiActiveCondition: aiActiveWinCondition,
    )) {
      currentPhase = GamePhase.draw;
      winner = null;
      endTime = DateTime.now();
      return false;
    }

    return true;
  }

  /// Explicitly marks the game as a Draw / Stalemate.
  void declareDraw() {
    currentPhase = GamePhase.draw;
    winner = null;
    endTime = DateTime.now();
  }

  void _updateActiveWinConditions() {
    playerActiveWinCondition = GameRules.getActiveWinCondition(board, Turn.player);
    aiActiveWinCondition = GameRules.getActiveWinCondition(board, Turn.ai);
  }

  void _handleCaptures(List<(int, int)> capturedCoords, {required Turn capturerTurn}) {
    int enemyUnitsCount = 0;
    final victimState = capturerTurn == Turn.player ? CellState.ai : CellState.player;

    // Mark cells as captured and count only victim units for points
    for (final coord in capturedCoords) {
      if (board.getCell(coord.$1, coord.$2) == victimState) {
        enemyUnitsCount++;
      }
      board.setCell(coord.$1, coord.$2, CellState.capturedGrid);
    }

    if (capturerTurn == Turn.player) {
      playerCaptureEvents++;
      playerCapturedUnits += enemyUnitsCount;
      if (enemyUnitsCount > playerMaxCombo) {
        playerMaxCombo = enemyUnitsCount;
      }
    } else {
      aiCaptureEvents++;
      aiCapturedUnits += enemyUnitsCount;
      if (enemyUnitsCount > aiMaxCombo) {
        aiMaxCombo = enemyUnitsCount;
      }
    }

    final pointsGained = GameRules.calculateCaptureScore(enemyUnitsCount);

    if (capturerTurn == Turn.player) {
      playerScore += pointsGained;
      if (playerScore >= config.playerKingdomAttackThreshold &&
          !playerKingdomAttackUnlocked) {
        playerKingdomAttackUnlocked = true;
        currentPhase = GamePhase.kingdomAttack;
      }
    } else {
      aiScore += pointsGained;
      if (aiScore >= config.aiKingdomAttackThreshold &&
          !aiKingdomAttackUnlocked) {
        aiKingdomAttackUnlocked = true;
        currentPhase = GamePhase.kingdomAttack;
      }
    }
  }

  /// Calculates the grid territory percentages controlled by each side.
  (double, double) calculateTerritoryPercentages() {
    int playerCells = 0;
    int aiCells = 0;
    int playableCells = 0;

    for (int y = board.playableMinY; y <= board.playableMaxY; y++) {
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        playableCells++;
        final cell = board.getCell(x, y);
        if (cell == CellState.player || cell == CellState.playerZone) {
          playerCells++;
        } else if (cell == CellState.ai || cell == CellState.aiZone) {
          aiCells++;
        }
      }
    }

    if (playableCells == 0) return (50.0, 50.0);

    final totalOccupied = playerCells + aiCells;
    if (totalOccupied == 0) return (50.0, 50.0);

    final pPct = (playerCells / totalOccupied) * 100;
    final aPct = (aiCells / totalOccupied) * 100;
    return (pPct, aPct);
  }

  /// Generates the complete BattleStats model for the post battle screen.
  BattleStats generateBattleStats() {
    final finishTime = endTime ?? DateTime.now();
    final duration = finishTime.difference(startTime);
    final (playerTerritory, aiTerritory) = calculateTerritoryPercentages();
    final totalTurns = playerMoves + aiMoves;

    final isPlayerWinner = winner == Turn.player;
    final badges = <TacticalBadge>[];

    if (isPlayerWinner) {
      if (!aiKingdomAttackUnlocked) {
        badges.add(const TacticalBadge(
          type: TacticalBadgeType.grandStrategist,
          title: 'Grand Strategist',
          description: 'Achieved victory without allowing the enemy to unlock Kingdom Attack.',
          icon: '🛡️',
        ));
      }
      if (totalTurns <= 24 && totalTurns > 0) {
        badges.add(const TacticalBadge(
          type: TacticalBadgeType.blitzkrieg,
          title: 'Blitzkrieg Command',
          description: 'Decisive conquest completed in under 25 total turns.',
          icon: '⚡',
        ));
      }
      if (playerTerritory >= 58.0) {
        badges.add(const TacticalBadge(
          type: TacticalBadgeType.ironWall,
          title: 'Iron Sovereign',
          description: 'Held overwhelming grid territory control (>58%).',
          icon: '🏰',
        ));
      }
      if (playerMaxCombo >= 3) {
        badges.add(TacticalBadge(
          type: TacticalBadgeType.masterEncirclement,
          title: 'Master of Encirclement',
          description: 'Trapped $playerMaxCombo enemy units in a single grand tactical strike.',
          icon: '⚔️',
        ));
      }
      if (playerKingdomAttackUnlocked) {
        badges.add(const TacticalBadge(
          type: TacticalBadgeType.siegeBreaker,
          title: 'Siege Breaker',
          description: 'Breached the enemy perimeter through royal kingdom assault.',
          icon: '👑',
        ));
      }
      if (aiCapturedUnits == 0 && totalTurns >= 6) {
        badges.add(const TacticalBadge(
          type: TacticalBadgeType.flawlessDefense,
          title: 'Impenetrable Guard',
          description: 'Conceded zero unit captures during the entire battle.',
          icon: '🎖️',
        ));
      }
    }

    return BattleStats(
      duration: duration,
      startTime: startTime,
      endTime: finishTime,
      totalTurns: totalTurns,
      playerMoves: playerMoves,
      opponentMoves: aiMoves,
      playerScore: playerScore,
      opponentScore: aiScore,
      playerCapturedUnits: playerCapturedUnits,
      opponentCapturedUnits: aiCapturedUnits,
      playerCaptureEvents: playerCaptureEvents,
      opponentCaptureEvents: aiCaptureEvents,
      playerMaxCombo: playerMaxCombo,
      opponentMaxCombo: aiMaxCombo,
      playerTerritoryPercent: playerTerritory,
      opponentTerritoryPercent: aiTerritory,
      winConditionType: winningConditionType,
      winner: winner,
      isDraw: currentPhase == GamePhase.draw,
      playerSiegeBreached: playerKingdomAttackUnlocked,
      opponentSiegeBreached: aiKingdomAttackUnlocked,
      earnedBadges: badges,
    );
  }

  /// Creates a deep copy of the GameSimulation state.
  /// This is critical for both the AI Minimax isolates and Riverpod immutable state updates.
  GameSimulation clone() {
    final cloned = GameSimulation(config: config, startTime: startTime);
    cloned.board = board.clone(); // Utilizing Board's existing deep copy
    cloned.currentPhase = currentPhase;
    cloned.currentTurn = currentTurn;
    cloned.playerScore = playerScore;
    cloned.aiScore = aiScore;
    cloned.playerKingdomAttackUnlocked = playerKingdomAttackUnlocked;
    cloned.aiKingdomAttackUnlocked = aiKingdomAttackUnlocked;
    cloned.playerActiveWinCondition = playerActiveWinCondition;
    cloned.aiActiveWinCondition = aiActiveWinCondition;
    cloned.winner = winner;
    cloned.winningConditionType = winningConditionType;
    cloned.endTime = endTime;
    cloned.playerMoves = playerMoves;
    cloned.aiMoves = aiMoves;
    cloned.playerCapturedUnits = playerCapturedUnits;
    cloned.aiCapturedUnits = aiCapturedUnits;
    cloned.playerCaptureEvents = playerCaptureEvents;
    cloned.aiCaptureEvents = aiCaptureEvents;
    cloned.playerMaxCombo = playerMaxCombo;
    cloned.aiMaxCombo = aiMaxCombo;
    cloned.lastPlacedCoord = lastPlacedCoord;
    cloned.lastCapturedCells = List.from(lastCapturedCells);
    cloned.lastNewLinkages = Set.from(lastNewLinkages);
    cloned.lastMovedTurn = lastMovedTurn;
    return cloned;
  }
}


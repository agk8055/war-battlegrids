import '../core/enums/cell_state.dart';
import '../core/enums/game_phase.dart';
import '../core/enums/turn.dart';
import '../core/enums/win_condition_type.dart';
import '../core/models/level_config.dart';
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

  WinConditionType playerActiveWinCondition = WinConditionType.uShape;
  WinConditionType aiActiveWinCondition = WinConditionType.uShape;

  Turn? winner;

  GameSimulation({LevelConfig? config})
    : config = config ?? LevelConfig.standard(),
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

    if (!GameRules.isValidPlacement(board, x, y, currentTurn, attackUnlocked)) {
      return (false, false); // Invalid move
    }

    // Place the piece
    final pieceState = isPlayer ? CellState.player : CellState.ai;
    board.setCell(x, y, pieceState);

    // Evaluate Captures
    final captureResult = CaptureUtils.getCapturedUnits(board, (
      x,
      y,
    ), currentTurn);
    
    bool captureOccurred = false;
    if (captureResult.capturedCells.isNotEmpty) {
      _handleCaptures(captureResult.capturedCells);
      board.linkages.addAll(captureResult.linkages);
      captureOccurred = true;
    }

    // Evaluate Win Condition
    final winResult = GameRules.checkWinCondition(
      board,
      currentTurn,
      kingdomAttackUnlocked: attackUnlocked,
    );
    
    if (winResult.isWin) {
      if (winResult.blockage != null) {
        board.linkages.addAll(CaptureUtils.getLinkagesFromBlockage(winResult.blockage!));
      }
      currentPhase = GamePhase.gameOver;
      winner = currentTurn;
      // Do NOT switch turns if game is over
      return (true, captureOccurred);
    }

    // Evaluate Draw Condition
    if (GameRules.checkDraw(board, playerKingdomAttackUnlocked, aiKingdomAttackUnlocked)) {
      currentPhase = GamePhase.draw;
      winner = null; // No winner
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
    if (GameRules.checkDraw(board, playerKingdomAttackUnlocked, aiKingdomAttackUnlocked)) {
      currentPhase = GamePhase.draw;
      winner = null;
      return false;
    }

    return true;
  }

  void _updateActiveWinConditions() {
    // Player
    if (playerActiveWinCondition == WinConditionType.uShape) {
      if (!GameRules.isWinConditionPossible(board, Turn.player, WinConditionType.uShape)) {
        playerActiveWinCondition = WinConditionType.parallel;
      }
    }
    if (playerActiveWinCondition == WinConditionType.parallel) {
      if (!GameRules.isWinConditionPossible(board, Turn.player, WinConditionType.parallel)) {
        playerActiveWinCondition = WinConditionType.kingdomAssisted;
      }
    }

    // AI
    if (aiActiveWinCondition == WinConditionType.uShape) {
      if (!GameRules.isWinConditionPossible(board, Turn.ai, WinConditionType.uShape)) {
        aiActiveWinCondition = WinConditionType.parallel;
      }
    }
    if (aiActiveWinCondition == WinConditionType.parallel) {
      if (!GameRules.isWinConditionPossible(board, Turn.ai, WinConditionType.parallel)) {
        aiActiveWinCondition = WinConditionType.kingdomAssisted;
      }
    }
  }

  void _handleCaptures(List<(int, int)> capturedCoords) {
    int enemyUnitsCount = 0;
    final enemyState = currentTurn == Turn.player ? CellState.ai : CellState.player;

    // Mark cells as captured and count only enemy units for points
    for (final coord in capturedCoords) {
      if (board.getCell(coord.$1, coord.$2) == enemyState) {
        enemyUnitsCount++;
      }
      board.setCell(coord.$1, coord.$2, CellState.capturedGrid);
    }

    final pointsGained = GameRules.calculateCaptureScore(enemyUnitsCount);

    if (currentTurn == Turn.player) {
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

  /// Creates a deep copy of the GameSimulation state.
  /// This is critical for both the AI Minimax isolates and Riverpod immutable state updates.
  GameSimulation clone() {
    final cloned = GameSimulation(config: config);
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
    return cloned;
  }
}

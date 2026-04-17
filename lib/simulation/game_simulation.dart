import '../core/enums/cell_state.dart';
import '../core/enums/game_phase.dart';
import '../core/enums/turn.dart';
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

  GameSimulation({LevelConfig? config})
    : config = config ?? LevelConfig.standard(),
      board = Board(
        width: (config ?? LevelConfig.standard()).boardWidth,
        height: (config ?? LevelConfig.standard()).boardHeight,
      );

  /// Attempts to place a unit for the current turn at the given coordinates.
  /// Returns true if the move was successful and valid.
  bool placeUnit(int x, int y) {
    if (currentPhase == GamePhase.gameOver) return false;

    final isPlayer = currentTurn == Turn.player;
    final attackUnlocked = isPlayer
        ? playerKingdomAttackUnlocked
        : aiKingdomAttackUnlocked;

    if (!GameRules.isValidPlacement(board, x, y, currentTurn, attackUnlocked)) {
      return false; // Invalid move
    }

    // Place the piece
    final pieceState = isPlayer ? CellState.player : CellState.ai;
    board.setCell(x, y, pieceState);

    // Evaluate Captures
    final capturedCoords = CaptureUtils.getCapturedUnits(board, (
      x,
      y,
    ), currentTurn);
    if (capturedCoords.isNotEmpty) {
      _handleCaptures(capturedCoords);
    }

    // Evaluate Win Condition
    if (GameRules.checkWinCondition(
      board,
      currentTurn,
      kingdomAttackUnlocked: attackUnlocked,
    )) {
      currentPhase = GamePhase.gameOver;
      return true;
    }

    // Switch turns
    currentTurn = isPlayer ? Turn.ai : Turn.player;
    return true;
  }

  void _handleCaptures(List<(int, int)> capturedCoords) {
    // Instead of making them empty, mark them as permanently captured!
    for (final coord in capturedCoords) {
      board.setCell(coord.$1, coord.$2, CellState.capturedGrid);
    }

    final pointsGained = GameRules.calculateCaptureScore(capturedCoords.length);

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
    return cloned;
  }
}

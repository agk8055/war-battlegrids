import 'package:flutter_test/flutter_test.dart';
import 'package:war/core/enums/cell_state.dart';
import 'package:war/core/enums/turn.dart';
import 'package:war/core/enums/game_phase.dart';
import 'package:war/core/enums/win_condition_type.dart';
import 'package:war/core/models/level_config.dart';
import 'package:war/simulation/board.dart';
import 'package:war/simulation/rules.dart';
import 'package:war/simulation/game_simulation.dart';
import 'package:war/simulation/ai/ai_strategy.dart';
import 'package:war/simulation/ai/rule_engine.dart';
import 'package:war/simulation/ai/evaluator.dart';

void main() {
  group('Siege Overlay & Placement Rules', () {
    late Board board;

    setUp(() {
      board = Board(width: 15, height: 15);
      board.setPlayableArea(3, 3, 11, 11);
      board.setPalaceZones(
        aiStartX: 6,
        aiEndX: 8,
        aiStartY: 3,
        aiEndY: 4,
        playerStartX: 6,
        playerEndX: 8,
        playerStartY: 10,
        playerEndY: 11,
      );
    });

    test('Kingdom zone tiles are never marked as siege-blocked for overlay (retain kingdom colors)', () {
      // AI palace zone (6, 3) must not be marked as siege-blocked for overlay
      expect(
        GameRules.isPlacementBlockedBySiege(board, 6, 3, Turn.player, false),
        isFalse,
      );
      // Player palace zone (6, 10) must not be marked as siege-blocked for overlay
      expect(
        GameRules.isPlacementBlockedBySiege(board, 6, 10, Turn.player, false),
        isFalse,
      );
    });

    test('Normal playable empty cell without winning threat is not siege blocked', () {
      expect(
        GameRules.isPlacementBlockedBySiege(board, 5, 5, Turn.player, false),
        isFalse,
      );
      expect(
        GameRules.isValidPlacement(board, 5, 5, Turn.player, false),
        isTrue,
      );
    });

    test('Obstacles and occupied cells are not siege blocked', () {
      board.setCell(5, 5, CellState.obstacle);
      expect(
        GameRules.isPlacementBlockedBySiege(board, 5, 5, Turn.player, false),
        isFalse,
      );

      board.setCell(5, 6, CellState.player);
      expect(
        GameRules.isPlacementBlockedBySiege(board, 5, 6, Turn.player, false),
        isFalse,
      );
    });

    test('Draw condition triggers when no valid placements exist for either player', () {
      // Fill all playable non-palace cells with units
      for (int y = board.playableMinY; y <= board.playableMaxY; y++) {
        for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
          final cell = board.getCell(x, y);
          if (cell != CellState.playerZone && cell != CellState.aiZone) {
            board.setCell(x, y, CellState.capturedGrid);
          }
        }
      }

      // When siege is locked for both, neither can deploy into the opponent's palace zone
      expect(GameRules.hasValidMoves(board, Turn.player, false), isFalse);
      expect(GameRules.hasValidMoves(board, Turn.ai, false), isFalse);
      expect(GameRules.checkDraw(board, false, false), isTrue);

      // If player unlocks siege, player can deploy in AI palace, so not a draw
      expect(GameRules.hasValidMoves(board, Turn.player, true), isTrue);
      expect(GameRules.checkDraw(board, true, false), isFalse);
    });

    test('Captured grid chains across anchors do not falsely prevent AI from deploying', () {
      // Simulate player captures that created a line of capturedGrid across the board
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        board.setCell(x, 7, CellState.capturedGrid);
      }

      // AI has not unlocked kingdom attack yet
      expect(GameRules.hasValidMoves(board, Turn.ai, false), isTrue);

      // AI should be able to deploy at empty positions that are not completing an actual AI winning blockade
      expect(GameRules.isValidPlacement(board, 5, 5, Turn.ai, false), isTrue);
      expect(GameRules.isValidPlacement(board, 7, 8, Turn.ai, false), isTrue);
    });

    test('AI successfully finds and places moves after player unlocks Kingdom Attack / Siege points', () {
      final sim = GameSimulation(
        config: const LevelConfig(
          boardWidth: 15,
          boardHeight: 15,
          playerKingdomAttackThreshold: 20,
          aiKingdomAttackThreshold: 20,
        ),
      );

      // Set player siege unlocked (as if player earned 20 Glory points)
      sim.playerScore = 20;
      sim.playerKingdomAttackUnlocked = true;
      sim.currentPhase = GamePhase.kingdomAttack;
      sim.currentTurn = Turn.ai;

      // Set some units on board
      sim.board.setCell(5, 5, CellState.player);
      sim.board.setCell(5, 6, CellState.ai);

      // Verify AI has valid moves
      expect(GameRules.hasValidMoves(sim.board, Turn.ai, sim.aiKingdomAttackUnlocked), isTrue);

      // RuleEngine should find a valid best move
      final strategy = AIStrategy.fromType(AIStrategyType.basic);
      final bestMove = RuleEngine.getBestMove(sim, strategy);
      expect(bestMove, isNotNull);

      // AI placing this move should succeed
      final (success, _) = sim.placeUnit(bestMove!.$1, bestMove.$2);
      expect(success, isTrue);
      expect(sim.currentTurn, equals(Turn.player));
    });

    test('HeuristicEvaluator awards positive winScore when AI wins and negative when player wins', () {
      final sim = GameSimulation();
      final strategy = AIStrategy.fromType(AIStrategyType.basic);

      // AI wins
      sim.currentPhase = GamePhase.gameOver;
      sim.winner = Turn.ai;
      expect(HeuristicEvaluator.evaluate(sim, strategy), equals(HeuristicEvaluator.winScore));

      // Player wins
      sim.winner = Turn.player;
      expect(HeuristicEvaluator.evaluate(sim, strategy), equals(-HeuristicEvaluator.winScore));
    });

    test('Players can cover their own kingdom without needing siege points', () {
      // AI placing a defensive line in front of AI palace (e.g. at y = 5)
      for (int x = board.playableMinX; x < board.playableMaxX; x++) {
        board.setCell(x, 5, CellState.ai);
      }

      // AI should be able to place the final tile to complete the defensive line in front of AI palace
      // even with aiKingdomAttackUnlocked = false
      expect(
        GameRules.isValidPlacement(board, board.playableMaxX, 5, Turn.ai, false),
        isTrue,
      );
      expect(
        GameRules.isPlacementBlockedBySiege(board, board.playableMaxX, 5, Turn.ai, false),
        isFalse,
      );

      // And completing this defensive wall does NOT trigger a win for AI
      board.setCell(board.playableMaxX, 5, CellState.ai);
      final aiWin = GameRules.checkWinCondition(board, Turn.ai, kingdomAttackUnlocked: true);
      expect(aiWin.isWin, isFalse);

      // Similarly, Player placing a defensive line in front of Player palace (at y = 9)
      for (int x = board.playableMinX; x < board.playableMaxX; x++) {
        board.setCell(x, 9, CellState.player);
      }

      // Player should be able to place the final tile without siege points
      expect(
        GameRules.isValidPlacement(board, board.playableMaxX, 9, Turn.player, false),
        isTrue,
      );
      expect(
        GameRules.isPlacementBlockedBySiege(board, board.playableMaxX, 9, Turn.player, false),
        isFalse,
      );

      // And completing this defensive wall does NOT trigger a win for Player
      board.setCell(board.playableMaxX, 9, CellState.player);
      final playerWin = GameRules.checkWinCondition(board, Turn.player, kingdomAttackUnlocked: true);
      expect(playerWin.isWin, isFalse);
    });

    test('Parallel win condition is NOT enabled when U-shape is still possible', () {
      // Board is open, U-shape is still possible around AI palace
      expect(GameRules.isWinConditionPossible(board, Turn.player, WinConditionType.uShape), isTrue);

      // Player builds a parallel line across row 7
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        board.setCell(x, 7, CellState.player);
      }

      // Even with siege unlocked, parallel line alone does NOT win while U-shape is possible
      final winAttempt = GameRules.checkWinCondition(board, Turn.player, kingdomAttackUnlocked: true);
      expect(winAttempt.isWin, isFalse);
    });

    test('Parallel win condition IS enabled when opponent blocks U-shape', () {
      // AI covers row 5 completely (blocking access to AI palace and U-shape)
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        board.setCell(x, 5, CellState.ai);
      }
      expect(GameRules.isWinConditionPossible(board, Turn.player, WinConditionType.uShape), isFalse);

      // Player builds a parallel line across row 7
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        board.setCell(x, 7, CellState.player);
      }

      // Now with U-shape blocked and siege unlocked, Player achieves parallel win!
      final winUnlocked = GameRules.checkWinCondition(board, Turn.player, kingdomAttackUnlocked: true);
      expect(winUnlocked.isWin, isTrue);

      // Without siege unlocked, win condition returns false
      final winLocked = GameRules.checkWinCondition(board, Turn.player, kingdomAttackUnlocked: false);
      expect(winLocked.isWin, isFalse);
    });

    test('Attacking player achieves win by breaching top boundary through gap / flank', () {
      // Opponent (AI) covered row 5, but there is a gap on the top edge at (x=5, y=3)
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        if (x != 5) board.setCell(x, 5, CellState.ai);
      }
      // Player builds a line from left edge (3, 6) up through the gap to (5, 3)
      board.setCell(3, 6, CellState.player);
      board.setCell(4, 5, CellState.player);
      board.setCell(5, 4, CellState.player);
      board.setCell(5, 3, CellState.player); // Reaches top boundary at x=5 (left of AI palace at 6..8)

      // Touches leftEdge at (3,6) and top boundary at (5,3)
      final winResult = GameRules.checkWinCondition(board, Turn.player, kingdomAttackUnlocked: true);
      expect(winResult.isWin, isTrue);
    });

    test('Full GameSimulation: Opponent covers kingdom, player parallel block wins with siege ready', () {
      final sim = GameSimulation(
        config: const LevelConfig(
          boardWidth: 15,
          boardHeight: 15,
          playerKingdomAttackThreshold: 20,
          aiKingdomAttackThreshold: 20,
        ),
      );
      sim.board.setPlayableArea(3, 3, 11, 11);
      sim.board.setPalaceZones(
        aiStartX: 6,
        aiEndX: 8,
        aiStartY: 3,
        aiEndY: 4,
        playerStartX: 6,
        playerEndX: 8,
        playerStartY: 10,
        playerEndY: 11,
      );

      // AI covers its kingdom defensively across row 5
      for (int x = 3; x <= 11; x++) {
        sim.board.setCell(x, 5, CellState.ai);
      }

      // Player has siege ready (playerKingdomAttackUnlocked = true)
      sim.playerScore = 30;
      sim.playerKingdomAttackUnlocked = true;
      sim.currentPhase = GamePhase.kingdomAttack;
      sim.currentTurn = Turn.player;

      // Player builds parallel line at row 7 from x=3 to 10
      for (int x = 3; x < 11; x++) {
        sim.board.setCell(x, 7, CellState.player);
      }

      // Player places final tile at (11, 7)
      final (success, _) = sim.placeUnit(11, 7);
      expect(success, isTrue);
      expect(sim.currentPhase, equals(GamePhase.gameOver));
      expect(sim.winner, equals(Turn.player));
    });

    test('Half U-Shape: When opponent covers only one side (e.g. left side), parallel line does NOT win prematurely', () {
      // Opponent (AI) covers left side and middle of kingdom: row 5 from x=3 to x=9
      // Leaving x=10 and x=11 open on the right flank!
      for (int x = 3; x <= 9; x++) {
        board.setCell(x, 5, CellState.ai);
      }

      // U-shape / half U-shape is STILL possible because the right flank (x=10, 11) is open!
      expect(GameRules.isWinConditionPossible(board, Turn.player, WinConditionType.uShape), isTrue);

      // Player builds a horizontal line across row 7 from x=3 to 11
      for (int x = 3; x <= 11; x++) {
        board.setCell(x, 7, CellState.player);
      }

      // Parallel block win condition CANNOT be activated yet because hitting the right end (half U-shape) is possible!
      final winAttempt = GameRules.checkWinCondition(board, Turn.player, kingdomAttackUnlocked: true);
      expect(winAttempt.isWin, isFalse);

      // Player now extends upward from (11, 7) through (11, 5), (11, 4), and hits the right top end at (11, 3)
      board.setCell(11, 6, CellState.player);
      board.setCell(11, 5, CellState.player);
      board.setCell(11, 4, CellState.player);
      board.setCell(11, 3, CellState.player); // Reaches topRight anchor at y=3, x=11 (> aiPalaceEndX=8)

      // Now Player has completed the half U-shape (leftEdge to topRight) and wins!
      final halfUWin = GameRules.checkWinCondition(board, Turn.player, kingdomAttackUnlocked: true);
      expect(halfUWin.isWin, isTrue);
    });
  });
}



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

    test('Parallel and Half-U moves do NOT trigger siege block when Full U-shape is still possible', () {
      // Board is open, Full U-shape is still possible around AI palace
      expect(GameRules.isWinConditionPossible(board, Turn.player, WinConditionType.fullUShape), isTrue);
      expect(GameRules.getActiveWinCondition(board, Turn.player), equals(WinConditionType.fullUShape));

      // Player builds a parallel line across row 7 (from x=3 to 10)
      for (int x = board.playableMinX; x < board.playableMaxX; x++) {
        board.setCell(x, 7, CellState.player);
      }

      // The final tile of the parallel wall (11, 7) MUST NOT be blocked by siege because Full U is the active condition!
      expect(
        GameRules.isPlacementBlockedBySiege(board, board.playableMaxX, 7, Turn.player, false),
        isFalse,
      );
      expect(
        GameRules.isValidPlacement(board, board.playableMaxX, 7, Turn.player, false),
        isTrue,
      );

      // Even placing at (11, 7) with siege unlocked does NOT win while Full U-shape is possible
      board.setCell(board.playableMaxX, 7, CellState.player);
      final winAttempt = GameRules.checkWinCondition(board, Turn.player, kingdomAttackUnlocked: true);
      expect(winAttempt.isWin, isFalse);
    });

    test('Full U-shape move DOES trigger siege block when siege points are locked', () {
      // Player sets up a Full U-shape encirclement missing only (9, 3) (topRight flank)
      board.setCell(5, 3, CellState.player); // topLeft flank (x < 6)
      board.setCell(5, 4, CellState.player);
      board.setCell(5, 5, CellState.player);
      board.setCell(6, 5, CellState.player);
      board.setCell(7, 5, CellState.player);
      board.setCell(8, 5, CellState.player);
      board.setCell(9, 5, CellState.player);
      board.setCell(9, 4, CellState.player);

      // (9, 3) would complete the Full U-shape (topRight flank, x > 8, y = 3)
      expect(
        GameRules.isPlacementBlockedBySiege(board, 9, 3, Turn.player, false),
        isTrue,
      );
      expect(
        GameRules.isValidPlacement(board, 9, 3, Turn.player, false),
        isFalse,
      );

      // Once siege is unlocked, placing at (9, 3) wins the game!
      board.setCell(9, 3, CellState.player);
      final winResult = GameRules.checkWinCondition(board, Turn.player, kingdomAttackUnlocked: true);
      expect(winResult.isWin, isTrue);
    });

    test('Half U-shape win condition activates ONLY when Full U-shape is not possible', () {
      // Opponent blocks top-left flank at (5, 3) and (5, 4), making Full U-shape impossible
      board.setCell(5, 3, CellState.ai);
      board.setCell(5, 4, CellState.ai);
      board.setCell(4, 3, CellState.ai);
      board.setCell(3, 3, CellState.ai);

      // Full U is impossible, but Half U (leftEdge to topRight) is possible
      expect(GameRules.isWinConditionPossible(board, Turn.player, WinConditionType.fullUShape), isFalse);
      expect(GameRules.isWinConditionPossible(board, Turn.player, WinConditionType.halfUShape), isTrue);
      expect(GameRules.getActiveWinCondition(board, Turn.player), equals(WinConditionType.halfUShape));

      // Player builds Half U path from leftEdge (3, 7) around to (9, 4)
      board.setCell(3, 7, CellState.player);
      board.setCell(4, 7, CellState.player);
      board.setCell(5, 7, CellState.player);
      board.setCell(6, 7, CellState.player);
      board.setCell(7, 7, CellState.player);
      board.setCell(8, 7, CellState.player);
      board.setCell(9, 7, CellState.player);
      board.setCell(9, 6, CellState.player);
      board.setCell(9, 5, CellState.player);
      board.setCell(9, 4, CellState.player);

      // With Half U active, (9, 3) would complete Half U-shape to topRight: blocked by siege!
      expect(
        GameRules.isPlacementBlockedBySiege(board, 9, 3, Turn.player, false),
        isTrue,
      );

      // Meanwhile, parallel moves do NOT trigger siege block because Half U is active!
      expect(
        GameRules.isPlacementBlockedBySiege(board, 11, 7, Turn.player, false),
        isFalse,
      );

      // Completing Half U with siege unlocked wins!
      board.setCell(9, 3, CellState.player);
      final halfUWin = GameRules.checkWinCondition(board, Turn.player, kingdomAttackUnlocked: true);
      expect(halfUWin.isWin, isTrue);
    });

    test('Parallel win condition activates ONLY when Half U-shape is ALSO not possible', () {
      // AI covers row 5 completely (blocking access to both flanks of AI palace)
      for (int x = board.playableMinX; x <= board.playableMaxX; x++) {
        board.setCell(x, 5, CellState.ai);
      }
      expect(GameRules.isWinConditionPossible(board, Turn.player, WinConditionType.fullUShape), isFalse);
      expect(GameRules.isWinConditionPossible(board, Turn.player, WinConditionType.halfUShape), isFalse);
      expect(GameRules.isWinConditionPossible(board, Turn.player, WinConditionType.parallel), isTrue);
      expect(GameRules.getActiveWinCondition(board, Turn.player), equals(WinConditionType.parallel));

      // Player builds a parallel line across row 7 from x=3 to 10
      for (int x = board.playableMinX; x < board.playableMaxX; x++) {
        board.setCell(x, 7, CellState.player);
      }

      // Now with Parallel active, final tile (11, 7) IS blocked by siege!
      expect(
        GameRules.isPlacementBlockedBySiege(board, board.playableMaxX, 7, Turn.player, false),
        isTrue,
      );
      expect(
        GameRules.isValidPlacement(board, board.playableMaxX, 7, Turn.player, false),
        isFalse,
      );

      // Now with siege unlocked, Player achieves parallel win!
      board.setCell(board.playableMaxX, 7, CellState.player);
      final winUnlocked = GameRules.checkWinCondition(board, Turn.player, kingdomAttackUnlocked: true);
      expect(winUnlocked.isWin, isTrue);

      // Without siege unlocked, win condition returns false
      final winLocked = GameRules.checkWinCondition(board, Turn.player, kingdomAttackUnlocked: false);
      expect(winLocked.isWin, isFalse);
    });

    test('Full GameSimulation: Progression through win condition tiers', () {
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

      // Initially active condition is fullUShape
      expect(sim.playerActiveWinCondition, equals(WinConditionType.fullUShape));

      // AI blocks top-left flank
      for (int y = 3; y <= 5; y++) {
        sim.board.setCell(3, y, CellState.ai);
        sim.board.setCell(4, y, CellState.ai);
        sim.board.setCell(5, y, CellState.ai);
      }

      // AI places a move to trigger updateActiveWinConditions
      sim.currentTurn = Turn.ai;
      sim.placeUnit(11, 11);

      // Now player condition automatically transitioned to halfUShape
      expect(sim.playerActiveWinCondition, equals(WinConditionType.halfUShape));

      // AI now also blocks right flank (covering row 5 completely)
      for (int x = 3; x <= 11; x++) {
        sim.board.setCell(x, 5, CellState.ai);
      }

      // AI places a move
      sim.currentTurn = Turn.ai;
      sim.placeUnit(10, 11);

      // Now player condition automatically transitioned to parallel!
      expect(sim.playerActiveWinCondition, equals(WinConditionType.parallel));

      // Player unlocks siege
      sim.playerScore = 30;
      sim.playerKingdomAttackUnlocked = true;
      sim.currentPhase = GamePhase.kingdomAttack;
      sim.currentTurn = Turn.player;

      // Player builds parallel line at row 7
      for (int x = 3; x < 11; x++) {
        sim.board.setCell(x, 7, CellState.player);
      }

      // Player places final tile at (11, 7) and wins via parallel!
      final (success, _) = sim.placeUnit(11, 7);
      expect(success, isTrue);
      expect(sim.currentPhase, equals(GamePhase.gameOver));
      expect(sim.winner, equals(Turn.player));
      expect(sim.winningConditionType, equals(WinConditionType.parallel));
    });
  });
}




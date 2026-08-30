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
import 'package:war/simulation/ai/minimax.dart';

void main() {
  group('AI Rules & Tactics Tests', () {
    late GameSimulation sim;

    setUp(() {
      sim = GameSimulation(
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
    });

    test('AI executes immediate winning move when Kingdom Attack is unlocked', () {
      sim.aiKingdomAttackUnlocked = true;
      sim.currentTurn = Turn.ai;

      // Set up an almost complete U-shape around player palace:
      // Player palace is at x: 6..8, y: 10..11.
      // AI needs to encircle player palace flanks from left anchor to right anchor.
      // Left anchor at (5, 11)
      sim.board.setCell(5, 11, CellState.ai);
      sim.board.setCell(5, 10, CellState.ai);
      sim.board.setCell(5, 9, CellState.ai);
      sim.board.setCell(6, 9, CellState.ai);
      sim.board.setCell(7, 9, CellState.ai);
      sim.board.setCell(8, 9, CellState.ai);
      sim.board.setCell(9, 9, CellState.ai);
      sim.board.setCell(9, 10, CellState.ai);
      // Winning tile is (9, 11) to close the U-shape!

      final bestMove = RuleEngine.getBestMove(sim, AIStrategy.fromType(AIStrategyType.master));
      expect(bestMove, equals((9, 11)));
    });

    test('AI BLOCKS opponent immediate winning move when player has Kingdom Attack unlocked', () {
      sim.playerKingdomAttackUnlocked = true;
      sim.aiKingdomAttackUnlocked = false;
      sim.currentTurn = Turn.ai;

      // Player is 1 move away from completing U-shape around AI palace (x: 6..8, y: 3..4).
      // Player has pieces on (5, 3), (5, 4), (5, 5), (6, 5), (7, 5), (8, 5), (9, 5), (9, 4).
      // If player places at (9, 3), player wins immediately!
      sim.board.setCell(5, 3, CellState.player);
      sim.board.setCell(5, 4, CellState.player);
      sim.board.setCell(5, 5, CellState.player);
      sim.board.setCell(6, 5, CellState.player);
      sim.board.setCell(7, 5, CellState.player);
      sim.board.setCell(8, 5, CellState.player);
      sim.board.setCell(9, 5, CellState.player);
      sim.board.setCell(9, 4, CellState.player);

      // AI's turn: AI MUST block at (9, 3) to prevent defeat!
      final bestMove = RuleEngine.getBestMove(sim, AIStrategy.fromType(AIStrategyType.master));
      expect(bestMove, equals((9, 3)));
    });

    test('AI executes immediate capture to gain points toward Kingdom Attack threshold', () {
      sim.currentTurn = Turn.ai;
      sim.aiKingdomAttackUnlocked = false;

      // Surround a single player stone at (6, 6) on 3 sides
      sim.board.setCell(6, 6, CellState.player);
      sim.board.setCell(6, 5, CellState.ai);
      sim.board.setCell(5, 6, CellState.ai);
      sim.board.setCell(7, 6, CellState.ai);
      // The remaining liberty to capture is (6, 7)

      final bestMove = RuleEngine.getBestMove(sim, AIStrategy.fromType(AIStrategyType.basic));
      expect(bestMove, equals((6, 7)));

      // Perform the move and verify capture occurs
      final (placed, captured) = sim.placeUnit(bestMove!.$1, bestMove.$2);
      expect(placed, isTrue);
      expect(captured, isTrue);
      expect(sim.aiScore, equals(10));
    });

    test('AI rescues friendly unit in Atari (1 liberty left)', () {
      sim.currentTurn = Turn.ai;

      // AI unit at (6, 6) is surrounded on 3 sides by Player units
      sim.board.setCell(6, 6, CellState.ai);
      sim.board.setCell(6, 5, CellState.player);
      sim.board.setCell(5, 6, CellState.player);
      sim.board.setCell(7, 6, CellState.player);
      // The only liberty to save the AI piece is (6, 7)

      final bestMove = RuleEngine.getBestMove(sim, AIStrategy.fromType(AIStrategyType.defensive));
      expect(bestMove, equals((6, 7)));
    });

    test('AI respects siege lock when Kingdom Attack is locked and chooses legal tactical move', () {
      sim.currentTurn = Turn.ai;
      sim.aiKingdomAttackUnlocked = false;

      // Set up AI pieces that almost form a U-shape around player palace
      sim.board.setCell(5, 11, CellState.ai);
      sim.board.setCell(5, 10, CellState.ai);
      sim.board.setCell(5, 9, CellState.ai);
      sim.board.setCell(6, 9, CellState.ai);
      sim.board.setCell(7, 9, CellState.ai);
      sim.board.setCell(8, 9, CellState.ai);
      sim.board.setCell(9, 9, CellState.ai);
      sim.board.setCell(9, 10, CellState.ai);

      // (9, 11) is siege-blocked because AI has not unlocked Kingdom Attack yet!
      expect(
        GameRules.isValidPlacement(sim.board, 9, 11, Turn.ai, false),
        isFalse,
      );

      final bestMove = RuleEngine.getBestMove(sim, AIStrategy.fromType(AIStrategyType.master));
      expect(bestMove, isNotNull);
      // Must NOT be the siege-blocked tile
      expect(bestMove, isNot(equals((9, 11))));
      // Must be a valid legal placement
      expect(
        GameRules.isValidPlacement(sim.board, bestMove!.$1, bestMove.$2, Turn.ai, false),
        isTrue,
      );
    });

    test('AI can deploy inside player palace zone once Kingdom Attack is unlocked', () {
      sim.currentTurn = Turn.ai;
      sim.aiKingdomAttackUnlocked = true;

      // Player palace is at x: 6..8, y: 10..11
      // Surround player palace front
      sim.board.setCell(5, 10, CellState.ai);
      sim.board.setCell(5, 11, CellState.ai);
      sim.board.setCell(6, 9, CellState.ai);
      sim.board.setCell(7, 9, CellState.ai);
      sim.board.setCell(8, 9, CellState.ai);
      sim.board.setCell(9, 10, CellState.ai);
      sim.board.setCell(9, 11, CellState.ai);

      // Placing inside player palace (e.g. 7, 10) is valid when unlocked
      expect(
        GameRules.isValidPlacement(sim.board, 7, 10, Turn.ai, true),
        isTrue,
      );
    });

    test('All 6 AI strategies generate valid non-null moves from an opening board', () {
      final strategies = [
        AIStrategyType.basic,
        AIStrategyType.doubleThreat,
        AIStrategyType.defensive,
        AIStrategyType.aggressive,
        AIStrategyType.forkExpert,
        AIStrategyType.master,
      ];

      for (final stratType in strategies) {
        final testSim = GameSimulation(
          config: const LevelConfig(
            boardWidth: 15,
            boardHeight: 15,
            playerKingdomAttackThreshold: 20,
            aiKingdomAttackThreshold: 20,
          ),
        );
        testSim.board.setPlayableArea(3, 3, 11, 11);
        testSim.board.setPalaceZones(
          aiStartX: 6,
          aiEndX: 8,
          aiStartY: 3,
          aiEndY: 4,
          playerStartX: 6,
          playerEndX: 8,
          playerStartY: 10,
          playerEndY: 11,
        );
        // Player plays first move
        testSim.placeUnit(7, 7);

        // AI's turn
        expect(testSim.currentTurn, equals(Turn.ai));
        final strategy = AIStrategy.fromType(stratType);
        final move = RuleEngine.getBestMove(testSim, strategy);

        expect(move, isNotNull, reason: "Strategy ${strategy.displayName} must return a move");
        expect(
          GameRules.isValidPlacement(testSim.board, move!.$1, move.$2, Turn.ai, false),
          isTrue,
          reason: "Strategy ${strategy.displayName} move ($move) must be legally valid",
        );
      }
    });
  });
}

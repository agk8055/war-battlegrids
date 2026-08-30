import 'package:flutter_test/flutter_test.dart';
import 'package:war/core/enums/cell_state.dart';
import 'package:war/core/enums/turn.dart';
import 'package:war/core/enums/win_condition_type.dart';
import 'package:war/core/models/level_config.dart';
import 'package:war/simulation/rules.dart';
import 'package:war/simulation/game_simulation.dart';
import 'package:war/simulation/ai/ai_strategy.dart';
import 'package:war/simulation/ai/rule_engine.dart';
import 'package:war/simulation/ai/evaluator.dart';

void main() {
  group('Stage-Aware AI & Multi-Tier Blockade Prevention Tests', () {
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

    test('Stage 1 (Pre-Siege): AI prioritizes threshold-unlocking capture over passive placement', () {
      sim.currentTurn = Turn.ai;
      sim.aiScore = 10; // Threshold is 20, 1 capture needed to unlock!
      sim.aiKingdomAttackUnlocked = false;

      // Single player piece at (6, 6) in Atari (surrounded on 3 sides)
      sim.board.setCell(6, 6, CellState.player);
      sim.board.setCell(6, 5, CellState.ai);
      sim.board.setCell(5, 6, CellState.ai);
      sim.board.setCell(7, 6, CellState.ai);
      // Capture move is (6, 7)

      final strategy = AIStrategy.fromType(AIStrategyType.aggressive);
      final bestMove = RuleEngine.getBestMove(sim, strategy);

      expect(bestMove, equals((6, 7)));

      // Perform the move and verify siege unlocks
      final (placed, captured) = sim.placeUnit(bestMove!.$1, bestMove.$2);
      expect(placed, isTrue);
      expect(captured, isTrue);
      expect(sim.aiScore, equals(20));
      expect(sim.aiKingdomAttackUnlocked, isTrue);
    });

    test('Stage 2A: AI denies palace flank to structurally break Full U-Shape blockade', () {
      sim.playerKingdomAttackUnlocked = true;
      sim.aiKingdomAttackUnlocked = false;
      sim.currentTurn = Turn.ai;

      // AI palace is at x: 6..8, y: 3..4.
      // Left corner is (5, 3), Right corner is (9, 3).
      // Player has pieces near right corner: (9, 4), (9, 5), (8, 5), (7, 5).
      sim.board.setCell(9, 4, CellState.player);
      sim.board.setCell(9, 5, CellState.player);
      sim.board.setCell(8, 5, CellState.player);
      sim.board.setCell(7, 5, CellState.player);

      // Player active condition is fullUShape
      expect(sim.playerActiveWinCondition, equals(WinConditionType.fullUShape));

      final strategy = AIStrategy.fromType(AIStrategyType.master);
      final bestMove = RuleEngine.getBestMove(sim, strategy);

      // AI master / defensive strategy should claim the left flank (5, 3) to break Full U!
      expect(bestMove, equals((5, 3)));
    });

    test('Stage 2A: When Full U-Shape is broken, player downgrades to Half U-Shape', () {
      // AI completely occupies and locks down left palace flank (x: 3..5, y: 3..5)
      for (int y = 3; y <= 5; y++) {
        for (int x = 3; x <= 5; x++) {
          sim.board.setCell(x, y, CellState.ai);
        }
      }

      // Full U-Shape should no longer be possible for Player
      final isFullUPossible = GameRules.isWinConditionPossible(sim.board, Turn.player, WinConditionType.fullUShape);
      expect(isFullUPossible, isFalse);

      // Active condition falls back to Half U-Shape
      final activeCondition = GameRules.getActiveWinCondition(sim.board, Turn.player);
      expect(activeCondition, equals(WinConditionType.halfUShape));
    });

    test('Stage 2A: AI cuts Parallel blockade chain across central columns', () {
      sim.playerKingdomAttackUnlocked = true;
      sim.aiKingdomAttackUnlocked = false;
      sim.currentTurn = Turn.ai;

      // Both palace flanks blocked so player is on Parallel tier
      sim.board.setCell(5, 3, CellState.ai);
      sim.board.setCell(9, 3, CellState.ai);

      // Player active condition is parallel
      sim.playerActiveWinCondition = WinConditionType.parallel;

      // Player has established pieces on left edge: (3, 7), (4, 7), (5, 7), (6, 7)
      sim.board.setCell(3, 7, CellState.player);
      sim.board.setCell(4, 7, CellState.player);
      sim.board.setCell(5, 7, CellState.player);
      sim.board.setCell(6, 7, CellState.player);

      final strategy = AIStrategy.fromType(AIStrategyType.defensive);
      final bestMove = RuleEngine.getBestMove(sim, strategy);

      expect(bestMove, isNotNull);
      // Move should intercept or sever near the central columns (7, 7) or (7, 6) or adjacent
      expect(
        GameRules.isValidPlacement(sim.board, bestMove!.$1, bestMove.$2, Turn.ai, false),
        isTrue,
      );
    });

    test('Stage 2B (Siege Assault): AI with unlocked siege advances active blockade to victory', () {
      sim.aiKingdomAttackUnlocked = true;
      sim.playerKingdomAttackUnlocked = false;
      sim.currentTurn = Turn.ai;

      // AI forms chain around player palace (x: 6..8, y: 10..11)
      sim.board.setCell(5, 11, CellState.ai);
      sim.board.setCell(5, 10, CellState.ai);
      sim.board.setCell(5, 9, CellState.ai);
      sim.board.setCell(6, 9, CellState.ai);
      sim.board.setCell(7, 9, CellState.ai);
      sim.board.setCell(8, 9, CellState.ai);
      sim.board.setCell(9, 9, CellState.ai);
      sim.board.setCell(9, 10, CellState.ai);

      final strategy = AIStrategy.fromType(AIStrategyType.aggressive);
      final bestMove = RuleEngine.getBestMove(sim, strategy);

      // Winning move at (9, 11) closes the U-shape!
      expect(bestMove, equals((9, 11)));

      final (placed, captured) = sim.placeUnit(bestMove!.$1, bestMove.$2);
      expect(placed, isTrue);
      expect(sim.winner, equals(Turn.ai));
    });

    test('Stage 3 (Dual Siege): AI prioritizes blocking opponent lethal win over advancing own blockade', () {
      sim.aiKingdomAttackUnlocked = true;
      sim.playerKingdomAttackUnlocked = true;
      sim.currentTurn = Turn.ai;

      // AI has a few pieces deployed
      sim.board.setCell(5, 10, CellState.ai);
      sim.board.setCell(5, 9, CellState.ai);

      // Player is 1 move away from completing U-shape around AI palace at (9, 3)
      sim.board.setCell(5, 3, CellState.player);
      sim.board.setCell(5, 4, CellState.player);
      sim.board.setCell(5, 5, CellState.player);
      sim.board.setCell(6, 5, CellState.player);
      sim.board.setCell(7, 5, CellState.player);
      sim.board.setCell(8, 5, CellState.player);
      sim.board.setCell(9, 5, CellState.player);
      sim.board.setCell(9, 4, CellState.player);

      final strategy = AIStrategy.fromType(AIStrategyType.master);
      final bestMove = RuleEngine.getBestMove(sim, strategy);

      // AI MUST block at (9, 3) to prevent instant defeat!
      expect(bestMove, equals((9, 3)));
    });

    test('Difficulty Scaling: Defensive and Master strategies anticipate flank threats', () {
      final defensive = AIStrategy.fromType(AIStrategyType.defensive);
      final master = AIStrategy.fromType(AIStrategyType.master);
      final basic = AIStrategy.fromType(AIStrategyType.basic);

      expect(defensive.anticipateBlockades, isTrue);
      expect(master.anticipateBlockades, isTrue);
      expect(basic.anticipateBlockades, isFalse);

      expect(master.flankDefenseWeight, greaterThan(basic.flankDefenseWeight));
      expect(master.chainCuttingWeight, greaterThan(basic.chainCuttingWeight));
      expect(master.captureWeight, greaterThan(basic.captureWeight));
    });
  });
}

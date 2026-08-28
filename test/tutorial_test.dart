import 'package:flutter_test/flutter_test.dart';
import 'package:war/core/enums/cell_state.dart';
import 'package:war/core/enums/turn.dart';
import 'package:war/core/utils/capture_utils.dart';
import 'package:war/simulation/board.dart';
import 'package:war/simulation/rules.dart';

void main() {
  group('Combat Tutorial Mechanics Tests', () {
    late Board board;

    setUp(() {
      // 15x15 Northern Forest Map configuration (Exact IsKingdom tiles from map)
      board = Board(width: 15, height: 15);
      board.setPlayableArea(3, 3, 11, 11);
      board.setPalaceZones(
        aiStartX: 7,
        aiEndX: 8,
        aiStartY: 3,
        aiEndY: 3,
        playerStartX: 6,
        playerEndX: 7,
        playerStartY: 11,
        playerEndY: 11,
      );
    });

    test('Step 2 Deployment: Frontline cell (7, 7) is playable and valid', () {
      expect(board.isWithinPlayableArea(7, 7), isTrue);
      expect(GameRules.isValidPlacement(board, 7, 7, Turn.player, false), isTrue);

      // Player deploys
      board.setCell(7, 7, CellState.player);
      expect(board.getCell(7, 7), equals(CellState.player));

      // Opponent counters at (7, 6)
      expect(board.isWithinPlayableArea(7, 6), isTrue);
      expect(GameRules.isValidPlacement(board, 7, 6, Turn.ai, false), isTrue);
      board.setCell(7, 6, CellState.ai);
      expect(board.getCell(7, 6), equals(CellState.ai));
    });

    test('Step 3 Flanking & Capture: Surrounding enemy piece triggers capture and linkages', () {
      // Enemy piece at (7, 6)
      board.setCell(7, 6, CellState.ai);

      // Friendly surrounding pieces at (6, 6), (7, 5), (7, 7)
      board.setCell(6, 6, CellState.player);
      board.setCell(7, 5, CellState.player);
      board.setCell(7, 7, CellState.player);

      // Final flank strike at (8, 6)
      board.setCell(8, 6, CellState.player);

      final captureResult = CaptureUtils.getCapturedUnits(board, (8, 6), Turn.player);
      expect(captureResult.capturedCells, contains((7, 6)));
      expect(captureResult.capturedCells.length, equals(1));
    });

    test('Step 4 & 5 Siege & Victory Strike: Blockade around Citadel triggers win when unlocked', () {
      // Near-victory blockade scenario surrounding North Citadel (7..8, 3)
      board.setCell(6, 3, CellState.player);
      board.setCell(6, 4, CellState.player);
      board.setCell(7, 4, CellState.player);
      board.setCell(8, 4, CellState.player);
      board.setCell(9, 4, CellState.player);

      // Without Kingdom Attack unlocked, placement that wins is blocked by siege
      board.setCell(9, 3, CellState.player);
      final winBeforeUnlock = GameRules.checkWinCondition(board, Turn.player, kingdomAttackUnlocked: false);
      expect(winBeforeUnlock.isWin, isFalse);

      // With Kingdom Attack unlocked, completing the blockade seals victory
      final winAfterUnlock = GameRules.checkWinCondition(board, Turn.player, kingdomAttackUnlocked: true);
      expect(winAfterUnlock.isWin, isTrue);
    });
  });
}

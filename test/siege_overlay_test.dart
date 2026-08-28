import 'package:flutter_test/flutter_test.dart';
import 'package:war/core/enums/cell_state.dart';
import 'package:war/core/enums/turn.dart';
import 'package:war/simulation/board.dart';
import 'package:war/simulation/rules.dart';

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
  });
}

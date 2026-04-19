import 'package:flutter_test/flutter_test.dart';
import 'package:war/simulation/board.dart';
import 'package:war/simulation/game_simulation.dart';
import 'package:war/core/utils/capture_utils.dart';
import 'package:war/core/enums/cell_state.dart';
import 'package:war/core/enums/turn.dart';

void main() {
  test('Unit at playable boundary should be captured if surrounded on 3 sides', () {
    final board = Board(width: 10, height: 10);
    board.setPlayableArea(1, 1, 8, 8);
    board.setCell(1, 5, CellState.ai);
    board.setCell(1, 4, CellState.player);
    board.setCell(2, 5, CellState.player);
    board.setCell(1, 6, CellState.player);

    final captured = CaptureUtils.getCapturedUnits(board, (1, 6), Turn.player);
    expect(captured, contains((1, 5)));
  });

  test('Territory capture and scoring: surrounding empty cells and enemy units', () {
    final sim = GameSimulation();
    sim.board.resize(10, 10);
    sim.board.setPlayableArea(0, 0, 9, 9);
    // Set dummy palace positions to avoid checkWinCondition issues with uninitialized bounds
    sim.board.aiPalaceStartX = 4; sim.board.aiPalaceEndX = 5; sim.board.aiPalaceStartY = 0; sim.board.aiPalaceEndY = 0;
    sim.board.playerPalaceStartX = 4; sim.board.playerPalaceEndX = 5; sim.board.playerPalaceStartY = 9; sim.board.playerPalaceEndY = 9;
    
    sim.currentTurn = Turn.player;

    /*
      Layout:
      (0,0) P  (1,0) P  (2,0) P  (3,0) P
      (0,1) P  (1,1) E  (2,1) A  (3,1) . (to be placed by P)
      (0,2) P  (1,2) P  (2,2) P  (3,2) P
    */

    sim.board.setCell(0, 0, CellState.player);
    sim.board.setCell(1, 0, CellState.player);
    sim.board.setCell(2, 0, CellState.player);
    sim.board.setCell(3, 0, CellState.player);

    sim.board.setCell(0, 1, CellState.player);
    sim.board.setCell(1, 1, CellState.empty);
    sim.board.setCell(2, 1, CellState.ai);
    // (3,1) is empty

    sim.board.setCell(0, 2, CellState.player);
    sim.board.setCell(1, 2, CellState.player);
    sim.board.setCell(2, 2, CellState.player);
    sim.board.setCell(3, 2, CellState.player);

    // Turn is player. Place at (3,1) to complete the loop.
    final success = sim.placeUnit(3, 1);
    expect(success, isTrue, reason: 'Placement should be valid');

    // Verify coordinates (1,1) and (2,1) are capturedGrid
    expect(sim.board.getCell(1, 1), CellState.capturedGrid, reason: 'Empty cell should be captured');
    expect(sim.board.getCell(2, 1), CellState.capturedGrid, reason: 'AI unit should be captured');

    // Verify points: Only 1 AI unit captured, so 10 points.
    expect(sim.playerScore, 10, reason: 'Only the AI unit should count for points, not the empty cell');
  });

  test('Unit touching friendly kingdom zone should NOT be captured', () {
    final board = Board(width: 10, height: 10);
    board.setPlayableArea(0, 0, 9, 9);
    board.setCell(5, 5, CellState.ai);
    board.setCell(5, 4, CellState.aiZone);
    board.setCell(4, 5, CellState.player);
    board.setCell(6, 5, CellState.player);
    board.setCell(5, 6, CellState.player);

    final captured = CaptureUtils.getCapturedUnits(board, (5, 6), Turn.player);
    expect(captured, isEmpty);
  });

  test('Enemy unit touching MY kingdom zone should BE captured if surrounded on 3 sides', () {
    final board = Board(width: 10, height: 10);
    board.setPlayableArea(0, 0, 9, 9);
    board.setCell(5, 5, CellState.ai);
    board.setCell(5, 4, CellState.playerZone);
    board.setCell(4, 5, CellState.player);
    board.setCell(6, 5, CellState.player);
    board.setCell(5, 6, CellState.player);

    final captured = CaptureUtils.getCapturedUnits(board, (5, 6), Turn.player);
    expect(captured, contains((5, 5)));
  });

  test('Unit surrounded by 3 enemies and 1 capturedGrid should NOT be captured', () {
    final sim = GameSimulation();
    sim.board.resize(10, 10);
    sim.board.setPlayableArea(0, 0, 9, 9);
    
    // AI unit at (5, 5)
    sim.board.setCell(5, 5, CellState.ai);
    
    // Captured Grid at (5, 4)
    sim.board.setCell(5, 4, CellState.capturedGrid);

    // Player units on 3 sides
    sim.board.setCell(4, 5, CellState.player); 
    sim.board.setCell(6, 5, CellState.player); 
    sim.board.setCell(5, 6, CellState.player);

    final captured = CaptureUtils.getCapturedUnits(sim.board, (5, 6), Turn.player);
    expect(captured, isEmpty, reason: 'capturedGrid should grant liberty');
  });
}

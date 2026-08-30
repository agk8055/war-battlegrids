import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war/core/enums/cell_state.dart';
import 'package:war/core/enums/turn.dart';
import 'package:war/game/board/linkages_layer_component.dart';
import 'package:war/simulation/board.dart';
import 'package:war/simulation/game_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Capture Chain Reaction & Linkages Layer Tests', () {
    test('GameSimulation tracks lastPlacedCoord, lastCapturedCells, and lastNewLinkages', () {
      final sim = GameSimulation();
      // Setup surrounding player units around (7, 6)
      sim.board.setCell(7, 6, CellState.ai);
      sim.board.setCell(6, 6, CellState.player);
      sim.board.setCell(7, 5, CellState.player);
      sim.board.setCell(7, 7, CellState.player);

      // Place final enclosing unit at (8, 6)
      final result = sim.placeUnit(8, 6);
      expect(result.$1, isTrue); // Placement success
      expect(result.$2, isTrue); // Capture occurred

      expect(sim.lastPlacedCoord, equals((8, 6)));
      expect(sim.lastCapturedCells, contains((7, 6)));
      expect(sim.lastNewLinkages.isNotEmpty, isTrue);
      expect(sim.lastMovedTurn, equals(Turn.player));
    });

    test('LinkagesLayerComponent initializes and syncs linkages without error', () {
      final board = Board(width: 15, height: 15);
      final layer = LinkagesLayerComponent(
        cellSize: 40.0,
        simulationBoard: board,
        playerColor: Colors.blue,
        opponentColor: Colors.red,
      );

      final newLinks = {
        ((6, 6), (7, 5)),
        ((7, 5), (8, 6)),
        ((8, 6), (7, 7)),
        ((7, 7), (6, 6)),
      };

      layer.syncLinkages(
        newLinks,
        newLinkages: newLinks,
        lastPlacedCoord: (8, 6),
        capturedCells: [(7, 6)],
        capturerColor: Colors.blue,
      );

      // Simulate a few animation update frames
      layer.update(0.05);
      layer.update(0.10);
      layer.update(0.15);
      layer.update(0.50);

      expect(layer.simulationBoard, equals(board));
    });

    test('Red unit deployed into pre-enclosed Blue pocket is immediately captured by Blue', () {
      final sim = GameSimulation();
      // Blue (Player) units deployed in a cross (+) around empty (7, 6)
      sim.board.setCell(6, 6, CellState.player);
      sim.board.setCell(8, 6, CellState.player);
      sim.board.setCell(7, 5, CellState.player);
      sim.board.setCell(7, 7, CellState.player);

      expect(sim.board.getCell(7, 6), equals(CellState.empty));
      expect(sim.playerScore, equals(0));

      // AI's turn (Red)
      sim.currentTurn = Turn.ai;

      // Red deploys into the middle cell (7, 6)
      final result = sim.placeUnit(7, 6);
      expect(result.$1, isTrue); // Placement successful
      expect(result.$2, isTrue); // Capture occurred!

      // Cell at (7, 6) must now be capturedGrid
      expect(sim.board.getCell(7, 6), equals(CellState.capturedGrid));

      // Player (Blue) gets the score (+10 points) and stats
      expect(sim.playerScore, equals(10));
      expect(sim.playerCapturedUnits, equals(1));
      expect(sim.aiScore, equals(0));
      expect(sim.aiCapturedUnits, equals(0));

      // Capturer tracking
      expect(sim.lastCapturedCells, contains((7, 6)));
      expect(sim.lastMovedTurn, equals(Turn.player)); // Blue was the capturer
      expect(sim.lastNewLinkages.isNotEmpty, isTrue);
    });

    test('Blue unit deployed into pre-enclosed Red pocket is immediately captured by Red', () {
      final sim = GameSimulation();
      // Red (AI) units deployed in a cross (+) around empty (5, 5)
      sim.board.setCell(4, 5, CellState.ai);
      sim.board.setCell(6, 5, CellState.ai);
      sim.board.setCell(5, 4, CellState.ai);
      sim.board.setCell(5, 6, CellState.ai);

      expect(sim.board.getCell(5, 5), equals(CellState.empty));
      expect(sim.aiScore, equals(0));

      // Player's turn (Blue)
      sim.currentTurn = Turn.player;

      // Blue deploys into the middle cell (5, 5)
      final result = sim.placeUnit(5, 5);
      expect(result.$1, isTrue); // Placement successful
      expect(result.$2, isTrue); // Capture occurred!

      // Cell at (5, 5) must now be capturedGrid
      expect(sim.board.getCell(5, 5), equals(CellState.capturedGrid));

      // AI (Red) gets the score (+10 points) and stats
      expect(sim.aiScore, equals(10));
      expect(sim.aiCapturedUnits, equals(1));
      expect(sim.playerScore, equals(0));
      expect(sim.playerCapturedUnits, equals(0));

      // Capturer tracking
      expect(sim.lastCapturedCells, contains((5, 5)));
      expect(sim.lastMovedTurn, equals(Turn.ai)); // Red was the capturer
      expect(sim.lastNewLinkages.isNotEmpty, isTrue);
    });
  });
}

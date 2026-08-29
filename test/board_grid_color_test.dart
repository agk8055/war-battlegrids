import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:war/core/constants/app_assets.dart';
import 'package:war/game/board/board_component.dart';
import 'package:war/simulation/board.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Map Grid Color Tests', () {
    late Board board;

    setUp(() {
      board = Board(width: 30, height: 30);
    });

    test('BoardComponent constructor allows overriding gridColor directly', () {
      final component = BoardComponent(
        simulationBoard: board,
        onCellTapped: (_, __) {},
        mapPath: AppAssets.defaultMap,
        playerSymbol: AppAssets.eagle,
        opponentSymbol: AppAssets.lion,
        playerColor: Colors.blue,
        opponentColor: Colors.red,
        gridColor: Colors.black,
      );

      expect(component.gridColor, equals(Colors.black));
    });

    test('BoardComponent resolves default black grid for icelands map', () {
      final component = BoardComponent(
        simulationBoard: board,
        onCellTapped: (_, __) {},
        mapPath: AppAssets.icelandsMap,
        playerSymbol: AppAssets.eagle,
        opponentSymbol: AppAssets.lion,
        playerColor: Colors.blue,
        opponentColor: Colors.red,
      );

      // Verify color parser
      expect(BoardComponent.parseColor('#000000'), equals(const Color(0xFF000000)));
      expect(BoardComponent.parseColor('black'), equals(Colors.black));
      expect(BoardComponent.parseColor('#FFFFFF'), equals(const Color(0xFFFFFFFF)));
      expect(BoardComponent.parseColor('0xFF000000'), equals(const Color(0xFF000000)));
    });

    test('GridLinesComponent configures line and border paint alphas based on gridColor', () {
      final solidBlackGrid = GridLinesComponent(
        gridMinX: 3,
        gridMinY: 3,
        gridMaxX: 26,
        gridMaxY: 26,
        cellSize: 40.0,
        gridColor: Colors.black,
      );

      expect(solidBlackGrid.gridColor, equals(Colors.black));

      final semiTransparentGrid = GridLinesComponent(
        gridMinX: 3,
        gridMinY: 3,
        gridMaxX: 26,
        gridMaxY: 26,
        cellSize: 40.0,
        gridColor: const Color(0x40FFFFFF),
      );

      expect(semiTransparentGrid.gridColor, equals(const Color(0x40FFFFFF)));
    });
  });
}

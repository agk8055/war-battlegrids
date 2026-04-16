import 'package:flame/components.dart';
import '../../simulation/board.dart';
import 'cell_component.dart';

class BoardComponent extends PositionComponent {
  final Board simulationBoard;
  final void Function(int x, int y) onCellTapped;
  final double cellSize;

  late List<List<CellComponent>> _cellGrid;

  BoardComponent({
    required this.simulationBoard,
    required this.onCellTapped,
    this.cellSize = 40.0,
  }) {
    size = Vector2(simulationBoard.width * cellSize, simulationBoard.height * cellSize);
  }

  @override
  Future<void> onLoad() async {
    _cellGrid = List.generate(
      simulationBoard.height,
      (y) => List.generate(
        simulationBoard.width,
        (x) {
          final cell = CellComponent(
            gridX: x,
            gridY: y,
            initialState: simulationBoard.getCell(x, y),
            onTapCell: onCellTapped,
            size: Vector2.all(cellSize),
            position: Vector2(x * cellSize, y * cellSize),
          );
          add(cell);
          return cell;
        },
      ),
    );
  }

  /// Syncs the Flame visual board with the Simulation board data.
  void syncWithSimulation(Board currentBoard) {
    for (int y = 0; y < currentBoard.height; y++) {
      for (int x = 0; x < currentBoard.width; x++) {
        _cellGrid[y][x].updateState(currentBoard.getCell(x, y));
      }
    }
  }
}

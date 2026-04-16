import '../core/enums/cell_state.dart';
import '../core/constants/board_constants.dart';

class Board {
  final int width;
  final int height;
  late List<List<CellState>> _grid; // Y, X format for rows/cols

  Board({this.width = kBoardWidth, this.height = kBoardHeight}) {
    _initializeGrid();
  }

  void _initializeGrid() {
    _grid = List.generate(
      height,
      (y) => List.generate(
        width,
        (x) {
          if (y >= kPlayerPalaceStartY && y <= kPlayerPalaceEndY && 
              x >= kPlayerPalaceStartX && x <= kPlayerPalaceEndX) {
            return CellState.playerZone;
          } else if (y >= kAIPalaceStartY && y <= kAIPalaceEndY && 
                     x >= kAIPalaceStartX && x <= kAIPalaceEndX) {
            return CellState.aiZone;
          }
          return CellState.empty;
        },
      ),
    );
  }

  /// Gets the current state of a cell.
  CellState getCell(int x, int y) {
    if (_isOutOfBounds(x, y)) throw Exception("Out of bounds: $x, $y");
    return _grid[y][x];
  }

  /// Sets the state of a cell.
  void setCell(int x, int y, CellState state) {
    if (_isOutOfBounds(x, y)) throw Exception("Out of bounds: $x, $y");
    _grid[y][x] = state;
  }

  bool _isOutOfBounds(int x, int y) {
    return x < 0 || x >= width || y < 0 || y >= height;
  }

  /// Creates a deep copy of the board, useful for the Minimax AI.
  Board clone() {
    final clonedBoard = Board(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        clonedBoard.setCell(x, y, getCell(x, y));
      }
    }
    return clonedBoard;
  }

  /// Returns all empty cells, optionally excluding zone cells.
  List<(int, int)> getAvailableCells({bool allowZones = false}) {
    final List<(int, int)> emptyCells = [];
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final cell = getCell(x, y);
        if (cell == CellState.empty) {
          emptyCells.add((x, y));
        } else if (allowZones && (cell == CellState.playerZone || cell == CellState.aiZone)) {
          emptyCells.add((x, y));
        }
      }
    }
    return emptyCells;
  }
}

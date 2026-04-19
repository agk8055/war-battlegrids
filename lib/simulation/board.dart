import '../core/enums/cell_state.dart';
import '../core/constants/board_constants.dart';

class Board {
  int width;
  int height;
  late List<List<CellState>> _grid; // Y, X format for rows/cols

  // Playable Area Boundaries (inclusive)
  int playableMinX = 0;
  int playableMaxX = 0;
  int playableMinY = 0;
  int playableMaxY = 0;

  // Dynamic Palace Boundaries
  int aiPalaceStartX = 0;
  int aiPalaceEndX = 0;
  int aiPalaceStartY = 0;
  int aiPalaceEndY = 0;

  int playerPalaceStartX = 0;
  int playerPalaceEndX = 0;
  int playerPalaceStartY = 0;
  int playerPalaceEndY = 0;

  Board({
    this.width = kDefaultBoardWidth,
    this.height = kDefaultBoardHeight,
  }) {
    playableMaxX = width - 1;
    playableMaxY = height - 1;
    _initializeGrid();
  }

  void _initializeGrid() {
    _grid = List.generate(
      height,
      (y) => List.generate(
        width,
        (x) => CellState.empty,
      ),
    );
  }

  /// Resizes the board and clears the grid.
  void resize(int newWidth, int newHeight) {
    width = newWidth;
    height = newHeight;
    playableMinX = 0;
    playableMinY = 0;
    playableMaxX = width - 1;
    playableMaxY = height - 1;
    _initializeGrid();
  }

  /// Sets the playable area boundaries.
  void setPlayableArea(int minX, int minY, int maxX, int maxY) {
    playableMinX = minX;
    playableMinY = minY;
    playableMaxX = maxX;
    playableMaxY = maxY;
  }

  /// Sets the palace zones and updates the grid states.
  void setPalaceZones({
    required int aiStartX,
    required int aiEndX,
    required int aiStartY,
    required int aiEndY,
    required int playerStartX,
    required int playerEndX,
    required int playerStartY,
    required int playerEndY,
  }) {
    aiPalaceStartX = aiStartX;
    aiPalaceEndX = aiEndX;
    aiPalaceStartY = aiStartY;
    aiPalaceEndY = aiEndY;
    playerPalaceStartX = playerStartX;
    playerPalaceEndX = playerEndX;
    playerPalaceStartY = playerStartY;
    playerPalaceEndY = playerEndY;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (y >= aiPalaceStartY && y <= aiPalaceEndY && 
            x >= aiPalaceStartX && x <= aiPalaceEndX) {
          _grid[y][x] = CellState.aiZone;
        } else if (y >= playerPalaceStartY && y <= playerPalaceEndY && 
                   x >= playerPalaceStartX && x <= playerPalaceEndX) {
          _grid[y][x] = CellState.playerZone;
        }
      }
    }
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

  /// Checks if a coordinate is within the interactive playable battlefield.
  bool isWithinPlayableArea(int x, int y) {
    return x >= playableMinX && x <= playableMaxX && 
           y >= playableMinY && y <= playableMaxY;
  }

  /// Creates a deep copy of the board, useful for the Minimax AI.
  Board clone() {
    final clonedBoard = Board(width: width, height: height);
    
    // Copy Playable Area
    clonedBoard.playableMinX = playableMinX;
    clonedBoard.playableMaxX = playableMaxX;
    clonedBoard.playableMinY = playableMinY;
    clonedBoard.playableMaxY = playableMaxY;

    // Copy Palace Boundaries
    clonedBoard.aiPalaceStartX = aiPalaceStartX;
    clonedBoard.aiPalaceEndX = aiPalaceEndX;
    clonedBoard.aiPalaceStartY = aiPalaceStartY;
    clonedBoard.aiPalaceEndY = aiPalaceEndY;

    clonedBoard.playerPalaceStartX = playerPalaceStartX;
    clonedBoard.playerPalaceEndX = playerPalaceEndX;
    clonedBoard.playerPalaceStartY = playerPalaceStartY;
    clonedBoard.playerPalaceEndY = playerPalaceEndY;

    for (int y = 0; y < height; y++) {
      clonedBoard._grid[y] = List<CellState>.from(_grid[y]);
    }
    return clonedBoard;
  }

  /// Returns all empty cells, optionally excluding zone cells, restricted to the playable area.
  List<(int, int)> getAvailableCells({bool allowZones = false}) {
    final List<(int, int)> emptyCells = [];
    for (int y = playableMinY; y <= playableMaxY; y++) {
      for (int x = playableMinX; x <= playableMaxX; x++) {
        final cell = getCell(x, y);
        if (cell == CellState.empty) {
          emptyCells.add((x, y));
        } else if (cell == CellState.obstacle) {
          // Obstacles are not available
          continue;
        } else if (allowZones && (cell == CellState.playerZone || cell == CellState.aiZone)) {
          emptyCells.add((x, y));
        }
      }
    }
    return emptyCells;
  }

  /// Returns empty cells that are within [radius] steps of any existing piece.
  /// This significantly reduces the move space for the Minimax algorithm.
  List<(int, int)> getRestrictedAvailableCells({int radius = 2, bool allowZones = false}) {
    final List<(int, int)> restrictedCells = [];
    final List<(int, int)> occupiedCells = [];

    // First, find all occupied cells
    for (int y = playableMinY; y <= playableMaxY; y++) {
      for (int x = playableMinX; x <= playableMaxX; x++) {
        final cell = getCell(x, y);
        if (cell == CellState.player || 
            cell == CellState.ai || 
            cell == CellState.capturedGrid) {
          occupiedCells.add((x, y));
        }
      }
    }

    // If board is empty, return cells near the center or just use the first available ones
    if (occupiedCells.isEmpty) {
      // Return a small set of cells near the center
      int centerX = (playableMinX + playableMaxX) ~/ 2;
      int centerY = (playableMinY + playableMaxY) ~/ 2;
      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          int nx = centerX + dx;
          int ny = centerY + dy;
          if (isWithinPlayableArea(nx, ny)) {
            final cell = getCell(nx, ny);
            if (cell == CellState.empty || (allowZones && (cell == CellState.playerZone || cell == CellState.aiZone))) {
              restrictedCells.add((nx, ny));
            }
          }
        }
      }
      if (restrictedCells.isNotEmpty) return restrictedCells;
      return getAvailableCells(allowZones: allowZones);
    }

    // For each occupied cell, look at its neighbors within [radius]
    final Set<(int, int)> visited = {};
    for (final (ox, oy) in occupiedCells) {
      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          if (dx == 0 && dy == 0) continue;
          
          int nx = ox + dx;
          int ny = oy + dy;
          
          if (isWithinPlayableArea(nx, ny) && !visited.contains((nx, ny))) {
            visited.add((nx, ny));
            final cell = getCell(nx, ny);
            if (cell == CellState.empty || (allowZones && (cell == CellState.playerZone || cell == CellState.aiZone))) {
              restrictedCells.add((nx, ny));
            }
          }
        }
      }
    }

    return restrictedCells;
  }
}

import '../core/enums/cell_state.dart';
import '../core/constants/board_constants.dart';
import 'ai/zobrist_hash.dart';

class Board {
  int width;
  int height;
  late List<List<CellState>> _grid; // Y, X format for rows/cols
  int currentHash = 0;

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

  /// Connections between cells that form a blockage.
  /// Each entry is a pair of adjacent coordinates.
  Set<((int, int), (int, int))> linkages = {};

  Board({
    this.width = kDefaultBoardWidth,
    this.height = kDefaultBoardHeight,
  }) {
    playableMinX = kPlayableBoundary;
    playableMinY = kPlayableBoundary;
    playableMaxX = width - 1 - kPlayableBoundary;
    playableMaxY = height - 1 - kPlayableBoundary;
    ZobristHash.initialize(width, height);
    _initializeGrid();
    linkages = {};
  }

  void _initializeGrid() {
    currentHash = 0;
    _grid = List.generate(
      height,
      (y) => List.generate(
        width,
        (x) => CellState.empty,
      ),
    );
    linkages = {};
  }

  /// Resizes the board and clears the grid.
  void resize(int newWidth, int newHeight) {
    width = newWidth;
    height = newHeight;
    playableMinX = kPlayableBoundary;
    playableMinY = kPlayableBoundary;
    playableMaxX = width - 1 - kPlayableBoundary;
    playableMaxY = height - 1 - kPlayableBoundary;
    ZobristHash.initialize(width, height);
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
          setCell(x, y, CellState.aiZone);
        } else if (y >= playerPalaceStartY && y <= playerPalaceEndY && 
                   x >= playerPalaceStartX && x <= playerPalaceEndX) {
          setCell(x, y, CellState.playerZone);
        }
      }
    }
  }

  /// Gets the current state of a cell.
  CellState getCell(int x, int y) {
    if (_isOutOfBounds(x, y)) throw Exception("Out of bounds: $x, $y");
    return _grid[y][x];
  }

  /// Sets the state of a cell and updates the incremental Zobrist hash.
  void setCell(int x, int y, CellState state) {
    if (_isOutOfBounds(x, y)) throw Exception("Out of bounds: $x, $y");
    
    final oldState = _grid[y][x];
    if (oldState == state) return;

    // Incremental Zobrist update: XOR out the old piece and XOR in the new one.
    // Safety check for initialization is required since this can be called before the Zobrist table is fully ready during load.
    if (ZobristHash.isInitialized) {
      if (oldState != CellState.empty) {
        currentHash ^= ZobristHash.getTableValue(x, y, width, oldState.index);
      }
      if (state != CellState.empty) {
        currentHash ^= ZobristHash.getTableValue(x, y, width, state.index);
      }
    }

    _grid[y][x] = state;
  }

  /// Recalculates the full hash, used when the Zobrist table is reinitialized.
  void recalculateHash() {
    currentHash = 0;
    if (!ZobristHash.isInitialized) return;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final state = _grid[y][x];
        if (state != CellState.empty) {
          currentHash ^= ZobristHash.getTableValue(x, y, width, state.index);
        }
      }
    }
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
    
    // Copy hash
    clonedBoard.currentHash = currentHash;

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

    // Copy linkages
    clonedBoard.linkages = Set.from(linkages);

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

    // If allowZones is enabled, also ensure cells adjacent to/inside the opponent's palace boundary are evaluated
    if (allowZones) {
      for (int y = playerPalaceStartY; y <= playerPalaceEndY; y++) {
        for (int x = playerPalaceStartX; x <= playerPalaceEndX; x++) {
          if (isWithinPlayableArea(x, y) && !visited.contains((x, y))) {
            visited.add((x, y));
            final cell = getCell(x, y);
            if (cell == CellState.playerZone || cell == CellState.empty) {
              restrictedCells.add((x, y));
            }
          }
        }
      }
      for (int y = aiPalaceStartY; y <= aiPalaceEndY; y++) {
        for (int x = aiPalaceStartX; x <= aiPalaceEndX; x++) {
          if (isWithinPlayableArea(x, y) && !visited.contains((x, y))) {
            visited.add((x, y));
            final cell = getCell(x, y);
            if (cell == CellState.aiZone || cell == CellState.empty) {
              restrictedCells.add((x, y));
            }
          }
        }
      }
    }

    return restrictedCells;
  }
}

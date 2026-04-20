import 'dart:ui';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import '../../simulation/board.dart';
import '../../core/enums/cell_state.dart';
import '../../core/constants/board_constants.dart';
import 'cell_component.dart';

class BoardComponent extends PositionComponent {
  final Board simulationBoard;
  final void Function(int x, int y) onCellTapped;
  final double cellSize;
  final String mapPath;
  final String playerSymbol;
  final String opponentSymbol;
  final Color playerColor;
  final Color opponentColor;

  late List<List<CellComponent>> _cellGrid;
  late TiledComponent tiledComponent;

  BoardComponent({
    required this.simulationBoard,
    required this.onCellTapped,
    required this.mapPath,
    required this.playerSymbol,
    required this.opponentSymbol,
    required this.playerColor,
    required this.opponentColor,
    this.cellSize = 40.0,
  }) {
    // Initial size based on simulation board
    size = Vector2(
      simulationBoard.width * cellSize,
      simulationBoard.height * cellSize,
    );
  }

  @override
  Future<void> onLoad() async {
    // 1. Load the Tiled Map
    // Setting destTileSize to cellSize (40.0) automatically handles scaling
    // from the native 64x64 to our 40x40 grid.
    // Custom Images instance with assets/tiles/ prefix allows loading images 
    // from assets/tiles/images/ as referenced in the .tsx files.
    tiledComponent = await TiledComponent.load(
      mapPath,
      Vector2.all(cellSize),
      images: Images(prefix: 'assets/tiles/'),
    );

    add(tiledComponent);

    final tileMap = tiledComponent.tileMap.map;
    
    // Ensure simulation board matches map size
    if (simulationBoard.width != tileMap.width || simulationBoard.height != tileMap.height) {
      simulationBoard.resize(tileMap.width, tileMap.height);
    }
    
    // Set Playable Area: 3 rows/cols from EACH side
    simulationBoard.setPlayableArea(
      kPlayableBoundary, 
      kPlayableBoundary, 
      tileMap.width - 1 - kPlayableBoundary, 
      tileMap.height - 1 - kPlayableBoundary
    );

    // 2. Parse Map Properties to Simulation Board
    _parseMapProperties();

    // 3. Generate Interaction Grid (CellComponents)
    // ONLY add interactive cells within the playable boundaries
    _cellGrid = List.generate(
      simulationBoard.height,
      (y) => List.generate(simulationBoard.width, (x) {
        // Only make cells inside the playable area interactive
        final isPlayable = x >= simulationBoard.playableMinX && 
                          x <= simulationBoard.playableMaxX && 
                          y >= simulationBoard.playableMinY && 
                          y <= simulationBoard.playableMaxY;

        final cell = CellComponent(
          gridX: x,
          gridY: y,
          initialState: simulationBoard.getCell(x, y),
          onTapCell: isPlayable ? onCellTapped : (x, y) {}, // Disable tap for non-playable
          playerSymbol: playerSymbol,
          opponentSymbol: opponentSymbol,
          playerColor: playerColor,
          opponentColor: opponentColor,
          size: Vector2.all(cellSize),
          position: Vector2(x * cellSize, y * cellSize),
        );
        add(cell);
        return cell;
      }),
    );

    // 4. Add Visual Grid Border over the playable region
    add(GridLinesComponent(
      gridMinX: simulationBoard.playableMinX,
      gridMinY: simulationBoard.playableMinY,
      gridMaxX: simulationBoard.playableMaxX,
      gridMaxY: simulationBoard.playableMaxY,
      cellSize: cellSize,
    ));
  }

  void _parseMapProperties() {
    final tileMap = tiledComponent.tileMap.map;

    List<(int, int)> aiKingdomTiles = [];
    List<(int, int)> playerKingdomTiles = [];

    for (var layer in tileMap.layers) {
      if (layer is TileLayer) {
        final data = layer.data;
        if (data == null) continue;

        for (int y = 0; y < tileMap.height; y++) {
          for (int x = 0; x < tileMap.width; x++) {
            final gid = data[y * tileMap.width + x];
            if (gid == 0) continue;

            final tile = tileMap.tileByGid(gid);
            if (tile == null) continue;

            final isKingdom =
                tile.properties.getValue<bool>('IsKingdom') ?? false;
            final isObstacle =
                tile.properties.getValue<bool>('isObstacle') ?? false;

            if (isObstacle) {
              simulationBoard.setCell(x, y, CellState.obstacle);
            } else if (isKingdom) {
              // Store ALL kingdom tiles to find the bounds
              if (y < tileMap.height / 2) {
                aiKingdomTiles.add((x, y));
              } else {
                playerKingdomTiles.add((x, y));
              }
            }
          }
        }
      }
    }

    // Determine Palace Bounds
    if (aiKingdomTiles.isNotEmpty) {
      int minX = aiKingdomTiles.map((e) => e.$1).reduce((a, b) => a < b ? a : b);
      int maxX = aiKingdomTiles.map((e) => e.$1).reduce((a, b) => a > b ? a : b);
      int minY = aiKingdomTiles.map((e) => e.$2).reduce((a, b) => a < b ? a : b);
      int maxY = aiKingdomTiles.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
      
      // Update simulation board with AI Palace
      simulationBoard.aiPalaceStartX = minX;
      simulationBoard.aiPalaceEndX = maxX;
      simulationBoard.aiPalaceStartY = minY;
      simulationBoard.aiPalaceEndY = maxY;
    }

    if (playerKingdomTiles.isNotEmpty) {
      int minX = playerKingdomTiles.map((e) => e.$1).reduce((a, b) => a < b ? a : b);
      int maxX = playerKingdomTiles.map((e) => e.$1).reduce((a, b) => a > b ? a : b);
      int minY = playerKingdomTiles.map((e) => e.$2).reduce((a, b) => a < b ? a : b);
      int maxY = playerKingdomTiles.map((e) => e.$2).reduce((a, b) => a > b ? a : b);

      // Update simulation board with Player Palace
      simulationBoard.playerPalaceStartX = minX;
      simulationBoard.playerPalaceEndX = maxX;
      simulationBoard.playerPalaceStartY = minY;
      simulationBoard.playerPalaceEndY = maxY;
    }

    // Re-apply palace zones to the grid
    simulationBoard.setPalaceZones(
      aiStartX: simulationBoard.aiPalaceStartX,
      aiEndX: simulationBoard.aiPalaceEndX,
      aiStartY: simulationBoard.aiPalaceStartY,
      aiEndY: simulationBoard.aiPalaceEndY,
      playerStartX: simulationBoard.playerPalaceStartX,
      playerEndX: simulationBoard.playerPalaceEndX,
      playerStartY: simulationBoard.playerPalaceStartY,
      playerEndY: simulationBoard.playerPalaceEndY,
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

class GridLinesComponent extends PositionComponent {
  final int gridMinX;
  final int gridMinY;
  final int gridMaxX;
  final int gridMaxY;
  final double cellSize;

  final Paint _gridPaint = Paint()
    ..color = const Color(0x40FFFFFF) // Semi-transparent white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.5;

  final Paint _borderPaint = Paint()
    ..color = const Color(0x80FFFFFF) // Slightly more opaque border
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  GridLinesComponent({
    required this.gridMinX,
    required this.gridMinY,
    required this.gridMaxX,
    required this.gridMaxY,
    required this.cellSize,
  }) {
    position = Vector2(gridMinX * cellSize, gridMinY * cellSize);
    size = Vector2(
      (gridMaxX - gridMinX + 1) * cellSize,
      (gridMaxY - gridMinY + 1) * cellSize,
    );
    priority = 10; // Ensure it's drawn above cells
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final widthInCells = gridMaxX - gridMinX + 1;
    final heightInCells = gridMaxY - gridMinY + 1;

    // Draw vertical lines
    for (int i = 0; i <= widthInCells; i++) {
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, heightInCells * cellSize),
        _gridPaint,
      );
    }

    // Draw horizontal lines
    for (int i = 0; i <= heightInCells; i++) {
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(widthInCells * cellSize, i * cellSize),
        _gridPaint,
      );
    }

    // Draw Outer Border
    canvas.drawRect(
      Rect.fromLTWH(0, 0, widthInCells * cellSize, heightInCells * cellSize),
      _borderPaint,
    );
  }
}

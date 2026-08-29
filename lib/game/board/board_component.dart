import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
import '../../simulation/board.dart';
import '../../simulation/rules.dart';
import '../../core/enums/cell_state.dart';
import '../../core/enums/turn.dart';
import '../../core/constants/board_constants.dart';
import 'cell_component.dart';

class BoardComponent extends PositionComponent {
  Board simulationBoard;
  final void Function(int x, int y) onCellTapped;
  final double cellSize;
  final String mapPath;
  final String playerSymbol;
  final String opponentSymbol;
  final Color playerColor;
  final Color opponentColor;
  final Color? gridColor;

  List<List<CellComponent>> _cellGrid = [];
  TiledComponent? tiledComponent;

  BoardComponent({
    required this.simulationBoard,
    required this.onCellTapped,
    required this.mapPath,
    required this.playerSymbol,
    required this.opponentSymbol,
    required this.playerColor,
    required this.opponentColor,
    this.cellSize = 40.0,
    this.gridColor,
  }) {
    // Initial size based on simulation board
    size = Vector2(
      simulationBoard.width * cellSize,
      simulationBoard.height * cellSize,
    );
  }

  @override
  Future<void> onLoad() async {
    // 1. Load the Tiled Map with Try-Catch Fallback
    try {
      final loadedTiledComponent = await TiledComponent.load(
        mapPath,
        Vector2.all(cellSize),
        images: Images(prefix: 'assets/tiles/'),
      );
      tiledComponent = loadedTiledComponent;
      add(loadedTiledComponent);
      size = loadedTiledComponent.size; // Ensure our size matches the loaded map content

      final tileMap = loadedTiledComponent.tileMap.map;
      
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
    } catch (e) {
      debugPrint('BoardComponent Warning: Could not load map "$mapPath": $e');
      simulationBoard.setPlayableArea(
        kPlayableBoundary,
        kPlayableBoundary,
        simulationBoard.width - 1 - kPlayableBoundary,
        simulationBoard.height - 1 - kPlayableBoundary,
      );
    }

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

        final isBlocked = isPlayable && GameRules.isPlacementBlockedBySiege(
          simulationBoard,
          x,
          y,
          Turn.player,
          false,
        );

        final cell = CellComponent(
          gridX: x,
          gridY: y,
          simulationBoard: simulationBoard,
          initialState: simulationBoard.getCell(x, y),
          onTapCell: isPlayable ? onCellTapped : (x, y) {}, // Disable tap for non-playable
          playerSymbol: playerSymbol,
          opponentSymbol: opponentSymbol,
          playerColor: playerColor,
          opponentColor: opponentColor,
          size: Vector2.all(cellSize),
          position: Vector2(x * cellSize, y * cellSize),
        );
        if (isBlocked) {
          cell.updateState(simulationBoard.getCell(x, y), isSiegeBlocked: true);
        }
        add(cell);
        return cell;
      }),
    );

    // 4. Add Visual Grid Border over the playable region with resolved map grid color
    add(GridLinesComponent(
      gridMinX: simulationBoard.playableMinX,
      gridMinY: simulationBoard.playableMinY,
      gridMaxX: simulationBoard.playableMaxX,
      gridMaxY: simulationBoard.playableMaxY,
      cellSize: cellSize,
      gridColor: _resolveGridColor(),
    ));

    // 5. Add Palace Overlays
    _addPalaceOverlays();
  }

  Color _resolveGridColor() {
    if (gridColor != null) {
      return gridColor!;
    }

    if (tiledComponent != null) {
      final tileMap = tiledComponent!.tileMap.map;
      
      // Try to read gridColor / GridColor / grid_color from TMX map properties
      final dynamic rawColor = tileMap.properties.getValue('gridColor') ??
          tileMap.properties.getValue('GridColor') ??
          tileMap.properties.getValue('grid_color');

      if (rawColor != null) {
        final parsed = parseColor(rawColor.toString());
        if (parsed != null) return parsed;
      }
    }

    // Default per-map overrides if not explicitly defined in TMX properties
    if (mapPath.contains('iceland') || mapPath == AppAssets.icelandsMap) {
      return Colors.black;
    }

    return const Color(0xFFFFFFFF);
  }

  static Color? parseColor(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed == 'black') return Colors.black;
    if (trimmed == 'white') return Colors.white;
    if (trimmed == 'red') return Colors.red;
    if (trimmed == 'blue') return Colors.blue;
    if (trimmed == 'green') return Colors.green;
    if (trimmed == 'transparent') return Colors.transparent;

    final hex = trimmed.replaceAll('#', '').replaceAll('0x', '');
    if (hex.length == 6) {
      final intVal = int.tryParse('FF$hex', radix: 16);
      if (intVal != null) return Color(intVal);
    } else if (hex.length == 8) {
      final intVal = int.tryParse(hex, radix: 16);
      if (intVal != null) return Color(intVal);
    } else if (hex.length == 3) {
      final expanded = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
      final intVal = int.tryParse('FF$expanded', radix: 16);
      if (intVal != null) return Color(intVal);
    }
    return null;
  }

  void _addPalaceOverlays() {
    // AI Palace
    if (simulationBoard.aiPalaceStartX != 0 || simulationBoard.aiPalaceEndX != 0) {
      add(PalaceOverlayComponent(
        startX: simulationBoard.aiPalaceStartX,
        endX: simulationBoard.aiPalaceEndX,
        startY: simulationBoard.aiPalaceStartY,
        endY: simulationBoard.aiPalaceEndY,
        cellSize: cellSize,
        symbolAsset: opponentSymbol,
        color: opponentColor,
      ));
    }

    // Player Palace
    if (simulationBoard.playerPalaceStartX != 0 || simulationBoard.playerPalaceEndX != 0) {
      add(PalaceOverlayComponent(
        startX: simulationBoard.playerPalaceStartX,
        endX: simulationBoard.playerPalaceEndX,
        startY: simulationBoard.playerPalaceStartY,
        endY: simulationBoard.playerPalaceEndY,
        cellSize: cellSize,
        symbolAsset: playerSymbol,
        color: playerColor,
      ));
    }
  }

  void _parseMapProperties() {
    if (tiledComponent == null) return;
    final tileMap = tiledComponent!.tileMap.map;

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

  /// Syncs the Flame visual board with the Simulation board data and siege restrictions.
  void syncWithSimulation(
    Board currentBoard, {
    Turn effectiveTurn = Turn.player,
    bool kingdomAttackUnlocked = false,
  }) {
    simulationBoard = currentBoard;
    if (_cellGrid.isEmpty) return;
    for (int y = 0; y < currentBoard.height; y++) {
      for (int x = 0; x < currentBoard.width; x++) {
        if (y < _cellGrid.length && x < _cellGrid[y].length) {
          final isBlocked = GameRules.isPlacementBlockedBySiege(
            currentBoard,
            x,
            y,
            effectiveTurn,
            kingdomAttackUnlocked,
          );
          _cellGrid[y][x].updateState(
            currentBoard.getCell(x, y),
            isSiegeBlocked: isBlocked,
            currentBoard: currentBoard,
          );
        }
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
  final Color gridColor;

  late final Paint _gridPaint;
  late final Paint _borderPaint;

  GridLinesComponent({
    required this.gridMinX,
    required this.gridMinY,
    required this.gridMaxX,
    required this.gridMaxY,
    required this.cellSize,
    Color? gridColor,
  }) : gridColor = gridColor ?? const Color(0x40FFFFFF) {
    position = Vector2(gridMinX * cellSize, gridMinY * cellSize);
    size = Vector2(
      (gridMaxX - gridMinX + 1) * cellSize,
      (gridMaxY - gridMinY + 1) * cellSize,
    );
    priority = 10; // Ensure it's drawn above cells

    final double lineAlpha = (this.gridColor.a == 1.0) ? 0.35 : this.gridColor.a;
    final double borderAlpha = (this.gridColor.a == 1.0) ? 0.75 : (this.gridColor.a * 2.0).clamp(0.0, 1.0);

    _gridPaint = Paint()
      ..color = this.gridColor.withValues(alpha: lineAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    _borderPaint = Paint()
      ..color = this.gridColor.withValues(alpha: borderAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
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

class PalaceOverlayComponent extends PositionComponent {
  final int startX;
  final int endX;
  final int startY;
  final int endY;
  final double cellSize;
  final String symbolAsset;
  final Color color;

  PalaceOverlayComponent({
    required this.startX,
    required this.endX,
    required this.startY,
    required this.endY,
    required this.cellSize,
    required this.symbolAsset,
    required this.color,
  }) {
    position = Vector2(startX * cellSize, startY * cellSize);
    size = Vector2(
      (endX - startX + 1) * cellSize,
      (endY - startY + 1) * cellSize,
    );
  }

  @override
  Future<void> onLoad() async {
    // Add the Border
    add(RectangleComponent(
      size: size,
      paint: Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    ));

    // Add the Symbol in the center using safe sprite loader
    final sprite = await AppAssets.loadSpriteSafely(symbolAsset);
    if (sprite != null) {
      final symbolSize = size.y * 0.6;
      add(SpriteComponent(
        sprite: sprite,
        size: Vector2.all(symbolSize),
        position: size / 2,
        anchor: Anchor.center,
        paint: Paint()..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
      ));
    }
  }
}

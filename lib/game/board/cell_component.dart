import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../../core/enums/cell_state.dart';
import '../../simulation/board.dart';
import '../kingdom_game.dart';

class CellComponent extends PositionComponent with TapCallbacks, HasGameRef<KingdomGame> {
  final int gridX;
  final int gridY;
  final CellState initialState;
  final void Function(int x, int y) onTapCell;
  final String playerSymbol;
  final String opponentSymbol;
  final Color playerColor;
  final Color opponentColor;

  late CellState _currentState;
  Sprite? _playerSprite;
  Sprite? _opponentSprite;
  Sprite? _linkSprite;

  CellComponent({
    required this.gridX,
    required this.gridY,
    required this.initialState,
    required this.onTapCell,
    required this.playerSymbol,
    required this.opponentSymbol,
    required this.playerColor,
    required this.opponentColor,
    required Vector2 size,
    required Vector2 position,
  }) : super(size: size, position: position) {
    _currentState = initialState;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _playerSprite = await Sprite.load(playerSymbol);
    _opponentSprite = await Sprite.load(opponentSymbol);
    _linkSprite = await Sprite.load('assets/icons/link.png');
  }

  void updateState(CellState newState) {
    _currentState = newState;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    Paint paint = Paint()..style = PaintingStyle.fill;
    
    // Draw base tile
    switch (_currentState) {
      case CellState.player:
        paint.color = playerColor.withValues(alpha: 0.4); 
        break;
      case CellState.ai:
        paint.color = opponentColor.withValues(alpha: 0.4);
        break;
      case CellState.playerZone:
        paint.color = playerColor.withValues(alpha: 0.2);
        break;
      case CellState.aiZone:
        paint.color = opponentColor.withValues(alpha: 0.2);
        break;
      case CellState.capturedGrid:
        paint.color = Colors.black.withValues(alpha: 0.5);
        break;
      case CellState.obstacle:
        paint.color = Colors.orange.withValues(alpha: 0.1);
        break;
      default:
        paint.color = Colors.transparent;
        break;
    }

    // Draw the tile slightly smaller than size to create grid lines
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.x - 2, size.y - 2),
      paint,
    );

    // Render Linkages (Drawn before symbols to be "under")
    _renderLinkages(canvas);

    // If there is a unit on this tile, draw the symbol (sigil)
    if (_currentState == CellState.player && _playerSprite != null) {
      _playerSprite!.render(
        canvas,
        position: Vector2(size.x * 0.15, size.y * 0.15),
        size: Vector2(size.x * 0.7, size.y * 0.7),
        overridePaint: Paint()..colorFilter = ColorFilter.mode(playerColor, BlendMode.srcIn),
      );
    } else if (_currentState == CellState.ai && _opponentSprite != null) {
      _opponentSprite!.render(
        canvas,
        position: Vector2(size.x * 0.15, size.y * 0.15),
        size: Vector2(size.x * 0.7, size.y * 0.7),
        overridePaint: Paint()..colorFilter = ColorFilter.mode(opponentColor, BlendMode.srcIn),
      );
    }
  }

  void _renderLinkages(Canvas canvas) {
    if (_linkSprite == null) return;

    final board = gameRef.simulationBoard;
    final currentCoord = (gridX, gridY);

    // To avoid double-drawing, we only draw links to neighbors that are "after" us in grid order
    final neighbors = [
      (gridX + 1, gridY),     // Right
      (gridX, gridY + 1),     // Bottom
      (gridX + 1, gridY + 1), // Bottom-Right Diagonal
      (gridX - 1, gridY + 1), // Bottom-Left Diagonal
    ];

    for (final neighbor in neighbors) {
      if (neighbor.$1 < 0 || neighbor.$1 >= board.width || neighbor.$2 < 0 || neighbor.$2 >= board.height) continue;
      if (!board.isWithinPlayableArea(neighbor.$1, neighbor.$2)) continue;

      final neighborState = board.getCell(neighbor.$1, neighbor.$2);
      // Only draw links if both cells are occupied by a unit or a kingdom zone
      if (_currentState == CellState.empty || _currentState == CellState.capturedGrid || _currentState == CellState.obstacle) continue;
      if (neighborState == CellState.empty || neighborState == CellState.capturedGrid || neighborState == CellState.obstacle) continue;

      // Check if there's a linkage between current and neighbor
      final pair = (currentCoord.$1 < neighbor.$1 || (currentCoord.$1 == neighbor.$1 && currentCoord.$2 < neighbor.$2))
          ? (currentCoord, neighbor)
          : (neighbor, currentCoord);

      if (board.linkages.contains(pair)) {
        // Calculate the vector to the neighbor
        final dx = (neighbor.$1 - gridX).toDouble();
        final dy = (neighbor.$2 - gridY).toDouble();
        
        // Calculate distance and angle in radians
        final distance = sqrt(dx * dx + dy * dy) * size.x;
        final double angle = atan2(dy, dx);

        // Determine player color based on current state
        // (Blockage cells have the same color)
        final bool isPlayer = _currentState == CellState.player || _currentState == CellState.playerZone;
        final Color linkColor = isPlayer ? playerColor : opponentColor;

        // Position at the center of the current cell
        final double centerX = size.x / 2;
        final double centerY = size.y / 2;
        
        // Scale the link icon: 
        // Height (along the link): spans the distance between centers
        // Width (perpendicular): 40% of cell size
        final double linkThickness = size.x * 0.4;

        canvas.save();
        canvas.translate(centerX, centerY);
        canvas.rotate(angle);
        
        // Render the link icon stretched from center (0,0) to center of neighbor (distance, 0)
        _linkSprite!.render(
          canvas,
          position: Vector2(0, -linkThickness / 2),
          size: Vector2(distance, linkThickness),
          overridePaint: Paint()..colorFilter = ColorFilter.mode(linkColor, BlendMode.srcIn),
        );
        
        canvas.restore();
      }
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    onTapCell(gridX, gridY);
  }
}

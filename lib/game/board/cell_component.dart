import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
import '../../core/enums/cell_state.dart';
import '../../simulation/board.dart';

class CellComponent extends PositionComponent with TapCallbacks {
  final int gridX;
  final int gridY;
  Board simulationBoard;
  final CellState initialState;
  final void Function(int x, int y) onTapCell;
  final String playerSymbol;
  final String opponentSymbol;
  final Color playerColor;
  final Color opponentColor;

  late CellState _currentState;
  bool _isSiegeBlocked = false;
  Sprite? _playerSprite;
  Sprite? _opponentSprite;

  CellComponent({
    required this.gridX,
    required this.gridY,
    required this.simulationBoard,
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
    priority = 0; // Base tile rendering under linkages (priority 5)
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _playerSprite = await AppAssets.loadSpriteSafely(playerSymbol);
    _opponentSprite = await AppAssets.loadSpriteSafely(opponentSymbol);

    // Add Symbol overlay child component to render unit sigil on top of linkages
    add(CellSymbolComponent(this));
  }

  void updateState(CellState newState, {bool isSiegeBlocked = false, Board? currentBoard}) {
    _currentState = newState;
    _isSiegeBlocked = isSiegeBlocked;
    if (currentBoard != null) {
      simulationBoard = currentBoard;
    }
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

    final tileRect = Rect.fromLTWH(1, 1, size.x - 2, size.y - 2);

    // Draw the tile slightly smaller than size to create grid lines
    canvas.drawRect(
      tileRect,
      paint,
    );

    // If siege blocked on an empty tile, draw a reverse circular gradient with red border
    if (_isSiegeBlocked && _currentState == CellState.empty) {
      // 1. Reverse circular gradient (transparent center fading outward to edges)
      final reverseGradientPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = const RadialGradient(
          center: Alignment.center,
          radius: 0.72,
          colors: [
            Color(0x00FF1744), // Clear in center
            Color(0x15FF1744),
            Color(0x55FF1744), // Fades into edges
          ],
          stops: [0.0, 0.4, 1.0],
        ).createShader(tileRect);

      canvas.drawRect(tileRect, reverseGradientPaint);

      // 2. Red border around the tile
      final redBorderPaint = Paint()
        ..color = const Color(0xB3FF1744)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawRect(
        Rect.fromLTWH(1.5, 1.5, size.x - 3, size.y - 3),
        redBorderPaint,
      );
    }
  }

  /// Renders the unit sigil sprite on top of the link rings.
  void renderSymbol(Canvas canvas) {
    if (_currentState == CellState.player) {
      if (_playerSprite != null) {
        _playerSprite!.render(
          canvas,
          position: Vector2(size.x * 0.15, size.y * 0.15),
          size: Vector2(size.x * 0.7, size.y * 0.7),
          overridePaint: Paint()..colorFilter = ColorFilter.mode(playerColor, BlendMode.srcIn),
        );
      } else {
        // Fallback vector shape if sprite fails
        canvas.drawCircle(
          Offset(size.x / 2, size.y / 2),
          size.x * 0.25,
          Paint()..color = playerColor,
        );
      }
    } else if (_currentState == CellState.ai) {
      if (_opponentSprite != null) {
        _opponentSprite!.render(
          canvas,
          position: Vector2(size.x * 0.15, size.y * 0.15),
          size: Vector2(size.x * 0.7, size.y * 0.7),
          overridePaint: Paint()..colorFilter = ColorFilter.mode(opponentColor, BlendMode.srcIn),
        );
      } else {
        // Fallback vector shape if sprite fails
        canvas.drawCircle(
          Offset(size.x / 2, size.y / 2),
          size.x * 0.25,
          Paint()..color = opponentColor,
        );
      }
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    onTapCell(gridX, gridY);
  }
}

/// Child component attached to CellComponent that renders the unit sigil
/// with priority 10 (above LinkagesLayerComponent's priority 5).
class CellSymbolComponent extends PositionComponent {
  final CellComponent cell;

  CellSymbolComponent(this.cell) {
    priority = 10;
    size = cell.size;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    cell.renderSymbol(canvas);
  }
}

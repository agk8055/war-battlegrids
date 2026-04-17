import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../../core/enums/cell_state.dart';

class CellComponent extends PositionComponent with TapCallbacks {
  final int gridX;
  final int gridY;
  final CellState initialState;
  final void Function(int x, int y) onTapCell;

  late CellState _currentState;

  CellComponent({
    required this.gridX,
    required this.gridY,
    required this.initialState,
    required this.onTapCell,
    required Vector2 size,
    required Vector2 position,
  }) : super(size: size, position: position) {
    _currentState = initialState;
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
      case CellState.empty:
        // Make empty tiles transparent so we can see the Tiled map
        paint.color = Colors.transparent;
        break;
      case CellState.playerZone:
        paint.color = Colors.blue.withValues(alpha: 0.2);
        break;
      case CellState.aiZone:
        paint.color = Colors.red.withValues(alpha: 0.2);
        break;
      case CellState.player:
        paint.color = Colors.blue.withValues(alpha: 0.7); 
        break;
      case CellState.ai:
        paint.color = Colors.red.withValues(alpha: 0.7);
        break;
      case CellState.capturedGrid:
        paint.color = Colors.black.withValues(alpha: 0.5);
        break;
      case CellState.obstacle:
        // Obstacles are handled by Tiled map visuals, but we can highlight them if needed
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

    // If there is a unit on this tile, draw a circle (sigil) over the base tile
    if (_currentState == CellState.player || _currentState == CellState.ai) {
      Paint unitPaint = Paint()
        ..color = _currentState == CellState.player ? Colors.cyanAccent : Colors.orangeAccent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 3, unitPaint);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    onTapCell(gridX, gridY);
  }
}

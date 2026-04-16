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
        paint.color = Colors.grey.shade800;
        break;
      case CellState.playerZone:
        paint.color = Colors.blue.shade900.withValues(alpha: 0.5);
        break;
      case CellState.aiZone:
        paint.color = Colors.red.shade900.withValues(alpha: 0.5);
        break;
      case CellState.player:
        paint.color = Colors.blue; 
        break;
      case CellState.ai:
        paint.color = Colors.red;
        break;
      case CellState.capturedGrid:
        paint.color = Colors.black87; // Dark burned/used tile
        break;
      default:
        paint.color = Colors.grey.shade800;
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
  void onTapDown(TapDownEvent event) {
    onTapCell(gridX, gridY);
  }
}
